/* host_sim.h — Simulates a host computer (PDP-11/VAX) feeding S-records
 * over the AP I/F into the SBC.
 *
 * On real hardware the host's AP I/F card has a separate set of host-
 * visible registers (HMA, WC, CTRL, FN, LITES, RSTAP per FPS-100 DRIVER.MAC)
 * that translate into the SBC-side register block at $FF0000.  In
 * emulation we don't model the host's own bus — we just inject the
 * register-state changes the chassis would expose to the SBC and
 * raise the level-5 autovector IRQ that signals "host attention".
 *
 * The SBC handles the IRQ at F07EE6 (autovec L5):
 *   reads $FF004E → $1066 (RAM)
 *   reads $FF0048 → $1068 (RAM)
 *   reads $FF004A → $106A (RAM)
 *   posts an RMS68K ASQ event so TCBRDHC wakes from its TRAP #1 dir $13
 *
 * The host_sim drives one byte per IRQ exchange: write byte to
 * $FF0048, wait for SBC to consume (detected when SBC reads $FF0048),
 * then send next byte. */

#ifndef HOST_SIM_H
#define HOST_SIM_H

#include <stdint.h>
#include <stdio.h>

typedef struct {
    FILE    *srec_fp;          /* S-record file being uploaded */
    char     line[256];
    int      line_len;
    int      line_pos;         /* next character to send */
    int      enabled;
    int      pending;          /* set when byte placed in AP I/F, cleared when SBC reads */
    int      bytes_sent;
    int      records_sent;
    int      interbyte_delay;  /* ticks to wait between bytes */
    int      delay_remaining;
    FILE    *log_fp;
} host_sim_t;

void host_sim_init(host_sim_t *h, const char *srec_path, FILE *log);
void host_sim_close(host_sim_t *h);

/* Called once per main-loop iteration — drives the byte-by-byte
 * upload to the SBC. */
void host_sim_tick(host_sim_t *h, uint32_t cycles);

/* Called from versabus when the SBC reads CH1 data — clears pending
 * so host_sim_tick can post the next byte. */
void host_sim_byte_consumed(host_sim_t *h);

#endif
