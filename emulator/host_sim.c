/* host_sim.c — host-side S-record sender.
 *
 * Pretends to be a PDP-11 (or VAX) writing through the AP I/F card
 * (slot 11 of the FPS-3000 chassis).  We don't model a separate host
 * bus — we directly drive the chassis-side state of the AP I/F card
 * and raise the level-5 autovector IRQ on the VERSAbus.
 *
 * One byte per IRQ exchange:
 *   1. Place ASCII S-record character in $FF0048 (CH1 data port A)
 *   2. Set status bit at $FF004A and copy at $FF004E (the L5 ISR
 *      reads all three)
 *   3. Pulse VERSAbus IRQ level 5
 *   4. Wait until SBC reads $FF0048 (host_sim_byte_consumed clears
 *      the pending flag), then send next byte.
 */

#include "host_sim.h"
#include "versabus.h"
#include <string.h>
#include <stdlib.h>

extern void m68k_set_irq(unsigned int level);
extern void versabus_inject_apif_byte(uint8_t byte_lo, uint8_t byte_hi, uint8_t status);

void host_sim_init(host_sim_t *h, const char *srec_path, FILE *log) {
    memset(h, 0, sizeof *h);
    h->log_fp = log;
    h->interbyte_delay = 2048;   /* cycles between bytes — give SBC time to handle IRQ */
    if (!srec_path) return;
    h->srec_fp = fopen(srec_path, "r");
    if (!h->srec_fp) {
        fprintf(stderr, "[host] cannot open %s\n", srec_path);
        return;
    }
    h->enabled = 1;
    if (h->log_fp) {
        fprintf(h->log_fp, "[host] enabled, file=%s\n", srec_path);
    }
    fprintf(stderr, "[host] simulator armed with %s\n", srec_path);
}

void host_sim_close(host_sim_t *h) {
    if (h->srec_fp) {
        fclose(h->srec_fp);
        h->srec_fp = NULL;
    }
    h->enabled = 0;
}

/* Returns next ASCII character to send (or -1 at EOF). Reads a line
 * at a time, terminating each record with CR (or LF — accept both). */
static int host_sim_next_byte(host_sim_t *h) {
    if (!h->srec_fp) return -1;
    /* Need a fresh line? */
    if (h->line_pos >= h->line_len) {
        if (!fgets(h->line, sizeof h->line, h->srec_fp)) {
            return -1;
        }
        /* Strip trailing CR/LF, then append \r as the line terminator
         * the SLC parser expects. */
        size_t n = strlen(h->line);
        while (n > 0 && (h->line[n-1] == '\n' || h->line[n-1] == '\r')) {
            h->line[--n] = '\0';
        }
        h->line[n++] = '\r';
        h->line[n]   = '\0';
        h->line_len  = (int)n;
        h->line_pos  = 0;
        h->records_sent++;
    }
    return (unsigned char)h->line[h->line_pos++];
}

/* Don't start sending until the SBC has finished its self-test +
 * RTOS init.  The gate is that the firmware has ENABLED the host
 * channel on the BIM (CR $FF0254: IRE set, level != 0) — that is what
 * physically permits the interrupt to reach the CPU.
 *
 * The old gate was 'vector $128 == F05DD6', which fires too early: the
 * RTOS installs that vector at task-creation time, before the TCBIO1I
 * task body runs.  A trace shows F05DB8 (the CR write) and F05D00 (the
 * task body) never execute at all, so the previous model was injecting
 * an interrupt into a task that had not initialised.
 * Until then, our IRQs would land on F0A27A panic or F00896 generic
 * (which doesn't post the right ASQ event for TCBRDHC). */
extern uint8_t *host_sim_get_ram_ptr(void);

static int sbc_ready(void) {
    extern uint8_t *host_sim_get_ram_ptr(void);
    uint8_t *ram = host_sim_get_ram_ptr();
    if (!ram) return 0;
    uint32_t v128 = ((uint32_t)ram[0x128] << 24) | ((uint32_t)ram[0x129] << 16)
                  | ((uint32_t)ram[0x12A] << 8)  |  (uint32_t)ram[0x12B];
    /* Faithful gate: the BIM channel must be enabled. */
    if (!versabus_bim_enabled(BIM_HOST_UNIT, BIM_HOST_CH)) return 0;
    return v128 == 0xF05DD6;
}

void host_sim_tick(host_sim_t *h, uint32_t cycles) {
    if (!h->enabled) return;
    if (h->pending) return;                        /* SBC hasn't consumed yet */
    if (!sbc_ready()) return;                      /* wait for RTOS init */
    if (h->delay_remaining > 0) {
        if ((int)cycles < h->delay_remaining) h->delay_remaining -= cycles;
        else h->delay_remaining = 0;
        return;
    }

    int b = host_sim_next_byte(h);
    if (b < 0) {
        if (h->enabled && h->log_fp) {
            fprintf(h->log_fp, "[host] EOF reached, %d bytes sent across %d records\n",
                    h->bytes_sent, h->records_sent);
        }
        h->enabled = 0;
        return;
    }

    /* Queue the byte on the chassis side.  When the SBC processes
     * the level-5 IRQ, its ISR sends panel-cmd 0x281 ("give me a
     * byte"), and the chassis responder pulls our queued byte into
     * the channel-1 data ports. */
    versabus_chassis_queue_byte((uint8_t)b);
    /* Set the host-attention bit in mailbox + AP I/F status so the
     * level-5 ISR takes the right path. */
    versabus_inject_apif_byte((uint8_t)b, (uint8_t)b, 0x4F);
    h->pending = 1;
    h->bytes_sent++;
    if (h->log_fp) {
        fprintf(h->log_fp, "[host] queue byte 0x%02X ('%c') #%d\n",
                b, (b >= 32 && b < 127) ? b : '.', h->bytes_sent);
    }
    /* Assert the host channel's device-interrupt input on the BIM.  The
     * BIM decides the request level from its control register; we no
     * longer pick one.  (BIM2 ch2 = CR $FF0254, VR $FF025C.) */
    /* The BIM decides the level from its control register; asserting the
     * channel returns it.  The literal 5 that used to be here was wrong:
     * the firmware programs this channel for level 7. */
    {
        int lvl = versabus_bim_assert(BIM_HOST_UNIT, BIM_HOST_CH);
        m68k_set_irq(lvl ? lvl : 5);
    }
    h->delay_remaining = h->interbyte_delay;
}

void host_sim_byte_consumed(host_sim_t *h) {
    h->pending = 0;
}
