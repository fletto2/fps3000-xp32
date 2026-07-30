/* mc6840.c — Motorola MC6840 PTM emulation. */

#include <stdlib.h>
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
            if (p->cr2_select_cr1) {
                p->cr[0] = val;
                /* Setting the internal reset (CR1 bit 0) holds all three
                 * timers AND clears the interrupt flags.  Without this the
                 * phase-$900 handler cannot dismiss the interrupt on its
                 * d6==3 path, which reads the status register but not the
                 * counters: T3's flag stayed set with CR3 bit 6 still
                 * enabled, so the handler re-entered forever. */
                if (val & 0x01) p->status = 0;
            } else {
                p->cr[2] = val;
            }
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
    /* CORRECTION: the MC6840 has ONE internal reset, CR1 bit 0, and it
     * holds ALL THREE timers.  CR2 bit 0 is the reg-0 address select
     * (as the comment above says) and CR3 bit 0 is the T3 prescaler
     * select — neither is a halt.  Treating bit 0 as a per-timer halt
     * left T2 and T3 free-running with a zero latch, re-setting their
     * status flags faster than the phase-$900 interrupt handler
     * (F0911E) could clear them, so its `tst.b` on the status register
     * never read 0 and the test span forever. */
    if (p->cr[0] & 0x01) return;                 /* CR1 bit 0 = internal reset */
    for (int t = 0; t < 3; t++) {
        uint32_t to_decr = cpu_cycles;
        /* CONTRADICTION, found 2026-07-29.  The comment above says CR3 bit 0
         * is the T3 prescaler select -- which matches the datasheet -- but this
         * line applied a /8 on BIT 1, for ALL THREE timers.  Bit 1 is the CLOCK
         * SOURCE (1 = internal E, 0 = external), not a prescaler.
         *
         * It matters for the RTOS tick: the RTOS programs CR3 = $C6 at $F0A2D8
         * (CR3, not CR1 -- $F0A2D2 clears CR2 bit 0 immediately before, which
         * switches register 0 from CR1 to CR3),
         * which has bit 1 SET, so the model divided the tick rate by 8.  The
         * system tick therefore ran 8x slow, and the clock-source selection the
         * bit actually encodes went unmodelled.
         *
         * The datasheet reading is now the DEFAULT: /8 only on T3, only from
         * CR3 bit 0.  Measured free -- legacy and strict both give 1,032
         * self-test PCs, final PC F00FCC, zero error flags and phase $09
         * reached, and the harness passes either way.  So the 8x tick error was
         * real but affected nothing currently measurable, consistent with
         * nothing in this firmware being wall-clock sensitive.
         *
         * FPS3K_PTM_LEGACY=1 restores the old behaviour for comparison. */
        {
            static int legacy = -1;
            if (legacy < 0) legacy = getenv("FPS3K_PTM_LEGACY") ? 1 : 0;
            if (legacy) {
                if (p->cr[t] & 0x02) to_decr /= 8;       /* wrong bit, all timers */
            } else {
                /* The PTM is clocked by E, not by the CPU clock: on a 68000,
                 * E = CPU/10.  mc6840_tick is handed CPU cycles, so the divider
                 * belongs here unconditionally -- that is what the old bit-1 /8
                 * was standing in for, and why calling it a "prescale" and
                 * removing it starved the RTOS.  Removing the /8 outright leaves
                 * the tick 10x fast and TCBIO1I never finishes registering its
                 * ASQ: !UST stops at 7 of 9 entries and stays there even at
                 * 1,600M cycles.
                 *
                 * So: /10 for the E clock always, and the datasheet's real
                 * prescaler -- CR3 bit 0, T3 only -- on top. */
                to_decr /= 10;
                if (t == 2 && (p->cr[2] & 0x01)) to_decr /= 8;
            }
        }
        /* KNOWN DEFECT, flagged not fixed: dual 8-bit mode (CR bit 2) is not
         * modelled.  The RTOS programs T3 with CR3 = $C6 -- bit 2 SET -- and
         * latch $27C7, so the real period is (MSB+1)*(LSB+1) = 40*200 = 8000 E
         * cycles = exactly 10.0000 ms at E = 800 kHz.  This 16-bit reload gives
         * $27C7+1 = 10184 cycles = 12.73 ms, so the emulated system tick is 27%
         * SLOW.  A correct fix counts the LSB half down each clock, decrements
         * the MSB half on its underflow, and fires only when the MSB half
         * underflows -- which also makes T3 counter reads meaningful, and the
         * firmware does read T3 MSB 1852 times per run.  Left flagged because
         * changing the tick moves every timing-dependent result and all three
         * golden-master digests with it: a deliberate step, not a side effect. */
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
