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
    reg &= 7;
    switch (reg) {
        case 0: case 1:
            /* Reading CR returns 0 per datasheet (CR registers are write-only) */
            return 0;
        case 2: {
            /* Status register read */
            uint8_t s = p->status;
            /* Reading status doesn't clear it — that requires read-status
             * followed by read-counter per chip semantics */
            return s;
        }
        case 3: case 5: case 7: {
            /* Timer counter MSB read (1, 2, 3) */
            int t = (reg - 3) / 2;
            return (p->counter[t] >> 8) & 0xFF;
        }
        case 4: case 6: {
            /* Timer counter LSB read (1, 2 — placement varies) */
            int t = (reg - 4) / 2;
            return p->counter[t] & 0xFF;
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
            /* LSB write — triggers loading of timer 1 latch (or counter, per CR) */
            p->latch[0] = ((uint16_t)p->msb_buffer << 8) | val;
            if (p->cr[0] & 0x10) {  /* preset mode bit */
                p->counter[0] = p->latch[0];
            }
            if (p->log_fp) fprintf(p->log_fp, "[PTM] T1 latch <- %04X\n", p->latch[0]);
            break;
        }
        case 4:
            p->msb_buffer = val;
            break;
        case 5:
            p->latch[1] = ((uint16_t)p->msb_buffer << 8) | val;
            if (p->cr[1] & 0x10) p->counter[1] = p->latch[1];
            if (p->log_fp) fprintf(p->log_fp, "[PTM] T2 latch <- %04X\n", p->latch[1]);
            break;
        case 6:
            p->msb_buffer = val;
            break;
        case 7:
            p->latch[2] = ((uint16_t)p->msb_buffer << 8) | val;
            if (p->cr[2] & 0x10) p->counter[2] = p->latch[2];
            if (p->log_fp) fprintf(p->log_fp, "[PTM] T3 latch <- %04X\n", p->latch[2]);
            break;
    }
}

void mc6840_tick(mc6840_t *p, uint32_t cpu_cycles) {
    /* Tick down each running timer */
    for (int t = 0; t < 3; t++) {
        if (p->cr[t] & 0x01) continue;          /* CR bit 0 = halt */
        /* Use prescaler if CR bit 1 set; otherwise tick on every cycle */
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
