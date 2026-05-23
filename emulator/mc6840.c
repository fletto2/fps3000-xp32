/* mc6840.c — Motorola MC6840 PTM emulation. */

#include "mc6840.h"
#include <string.h>

void mc6840_init(mc6840_t *p, FILE *log) {
    memset(p, 0, sizeof *p);
    p->log_fp = log;
    p->cr2_select_cr1 = 1;
    /* Default: timers paused (CR bit 0 = 1 puts timer in preset state) */
    for (int i = 0; i < 3; i++) p->cr[i] = 0x01;
}

void mc6840_reset(mc6840_t *p) {
    mc6840_init(p, p->log_fp);
}

uint8_t mc6840_read(mc6840_t *p, int reg) {
    /* MC6840 register layout (per datasheet):
     *   0  (read) — undefined / 0
     *   1  (read) — Status register
     *   2/4/6 (read) — Tn counter MSB; latches LSB into output buffer
     *   3/5/7 (read) — Tn LSB output buffer (last latched LSB)
     *   2/4/6 (write) — Tn MSB latch buffer
     *   3/5/7 (write) — Tn LSB latch (and write to counter/latch)
     *   0    (write) — CR1 (if CR2[0]=1) else CR3
     *   1    (write) — CR2
     */
    reg &= 7;
    switch (reg) {
        case 0:
            return 0;
        case 1:
            return p->status;
        case 2: case 4: case 6: {
            int t = (reg - 2) / 2;
            p->lsb_out[t] = p->counter[t] & 0xFF;
            /* Per datasheet: reading counter MSB after status read
             * clears the corresponding IRQ flag.  We approximate by
             * always clearing on counter-MSB read. */
            p->status &= ~(1u << t);
            /* Recompute composite IRQ */
            if (!(p->status & 0x07)) p->status &= ~0x80;
            return (p->counter[t] >> 8) & 0xFF;
        }
        case 3: case 5: case 7: {
            int t = (reg - 3) / 2;
            return p->lsb_out[t];
        }
    }
    return 0;
}

void mc6840_write(mc6840_t *p, int reg, uint8_t val) {
    reg &= 7;
    switch (reg) {
        case 0:
            /* CR1 or CR3 depending on CR2[0] */
            if (p->cr2_select_cr1) p->cr[0] = val;
            else                   p->cr[2] = val;
            if (p->log_fp) fprintf(p->log_fp, "[PTM] CR%d <- %02X\n",
                                   p->cr2_select_cr1 ? 1 : 3, val);
            break;
        case 1:
            p->cr[1] = val;
            p->cr2_select_cr1 = (val & 0x01) ? 1 : 0;
            if (p->log_fp) fprintf(p->log_fp, "[PTM] CR2 <- %02X (select=%s)\n",
                                   val, p->cr2_select_cr1 ? "CR1" : "CR3");
            break;
        case 2:
            /* Write MSB buffer — actually loaded into timer 1 latch on LSB write */
            p->msb_buffer = val;
            break;
        case 3: {
            /* LSB write — completes the 16-bit latch write (MSB+LSB).
             * Counter is always loaded from latch on this write (per
             * datasheet: timer is in preset state during init, counter
             * loaded; in run state, counter is loaded on next clock). */
            p->latch[0] = ((uint16_t)p->msb_buffer << 8) | val;
            p->counter[0] = p->latch[0];
            if (p->log_fp) fprintf(p->log_fp, "[PTM] T1 latch <- %04X\n", p->latch[0]);
            break;
        }
        case 4:
            p->msb_buffer = val;
            break;
        case 5:
            p->latch[1] = ((uint16_t)p->msb_buffer << 8) | val;
            p->counter[1] = p->latch[1];
            if (p->log_fp) fprintf(p->log_fp, "[PTM] T2 latch <- %04X\n", p->latch[1]);
            break;
        case 6:
            p->msb_buffer = val;
            break;
        case 7:
            p->latch[2] = ((uint16_t)p->msb_buffer << 8) | val;
            p->counter[2] = p->latch[2];
            if (p->log_fp) fprintf(p->log_fp, "[PTM] T3 latch <- %04X\n", p->latch[2]);
            break;
    }
}

void mc6840_tick(mc6840_t *p, uint32_t cpu_cycles) {
    /* Per MC6840 datasheet, CR2 bit 0 is the reg-0 address select
     * (1 = CR1 visible at reg 0, 0 = CR3) — NOT a master reset.
     * Each timer's internal reset is its OWN CRn bit 0.  Default
     * "halted" state (CRn = 0x01) means that timer is held in
     * preset state and does not count. */
    for (int t = 0; t < 3; t++) {
        if (p->cr[t] & 0x01) continue;           /* CRn bit 0 = reset → halted */
        uint32_t to_decr = cpu_cycles;
        if (p->cr[t] & 0x02) to_decr /= 8;       /* very rough prescale */
        if (p->counter[t] >= to_decr) {
            p->counter[t] -= to_decr;
        } else {
            p->status |= (1u << t);              /* IRQ flag */
            p->status |= 0x80;                   /* composite IRQ */
            /* Reload from latch (continuous mode) */
            p->counter[t] = p->latch[t];
            if (p->log_fp) fprintf(p->log_fp, "[PTM] T%d expired; status=%02X\n",
                                   t+1, p->status);
        }
    }
}

int mc6840_irq_pending(const mc6840_t *p) {
    /* IRQ pending if any timer flag set AND its CR bit 6 (IRQ enable) set */
    for (int t = 0; t < 3; t++)
        if ((p->status & (1u << t)) && (p->cr[t] & 0x40)) return 1;
    return 0;
}
