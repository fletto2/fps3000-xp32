/* mc6840.h — Motorola MC6840 Programmable Timer Module
 *
 * 3 independent 16-bit timers with control/status/latch registers.
 * Datasheet-accurate enough to satisfy the FPS-3000 SBC's PTMInit
 * routine and any code that polls timer status.
 *
 * The PTM is at 0xF70001-0xF7000F on odd byte boundaries (the SBC
 * uses MOVEP for register access, which reads/writes 4 bytes from
 * alternating odd-byte addresses).
 *
 * Register map (addressed via MOVEP, so 0xF70001 + 2*reg):
 *   reg 0: CR1 (or CR3 if CR2[0]=0) — control timer 1 / 3
 *   reg 1: CR2                       — control timer 2
 *   reg 2: STATUS / TIMER1 MSB write — status read / latch MSB
 *   reg 3: TIMER1 counter MSB read / TIMER1 latch LSB write
 *   reg 4: TIMER2 LSB                — counter LSB
 *   reg 5: TIMER2 LSB
 *   reg 6: TIMER3 MSB
 *   reg 7: TIMER3 LSB
 *
 * Per the MC6840 datasheet, register 0 selects between CR1 and CR3
 * based on CR2 bit 0.
 */
#ifndef MC6840_H
#define MC6840_H

#include <stdint.h>
#include <stdio.h>

typedef struct {
    /* Per-timer state */
    uint16_t latch[3];      /* programmed initial value */
    uint16_t counter[3];    /* current count */
    uint8_t  cr[3];         /* control register per timer */
    uint8_t  status;        /* shared status; bit 0..2 = T1..T3 IRQ; bit 7 = composite */
    uint8_t  msb_buffer;    /* MSB write latch (timers are written MSB first, then LSB triggers load) */
    int      cr2_select_cr1; /* if true, register 0 is CR1; else CR3 */
    /* Internal: count of ticks elapsed since last reset for each timer */
    uint64_t ticks[3];
    /* For introspection */
    FILE    *log_fp;
} mc6840_t;

void mc6840_init(mc6840_t *p, FILE *log);
void mc6840_reset(mc6840_t *p);

uint8_t mc6840_read(mc6840_t *p, int reg);
void    mc6840_write(mc6840_t *p, int reg, uint8_t val);

/* Tick the timers by N CPU cycles. Each timer divides the input
 * clock per its CR. Default: timers count down on every CPU cycle. */
void    mc6840_tick(mc6840_t *p, uint32_t cpu_cycles);

/* True if any timer's interrupt is pending and unmasked. */
int     mc6840_irq_pending(const mc6840_t *p);

#endif
