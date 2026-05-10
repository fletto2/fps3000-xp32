/* upd7201.c — NEC µPD7201 SIO emulation, datasheet-aligned. */

#include "upd7201.h"
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/select.h>

void upd7201_init(upd7201_t *s, FILE *log) {
    memset(s, 0, sizeof *s);
    s->log_fp = log;
    s->console_chan = 0;        /* channel A → console */
    s->console_enable = 1;
    /* TX always ready until first write */
    for (int c = 0; c < 2; c++) {
        s->rr[c][0] = SIO_RR0_TX_BUFFER_EMPTY;
    }
    /* Make stdin non-blocking for RX polling */
    int fl = fcntl(0, F_GETFL, 0);
    if (fl >= 0) fcntl(0, F_SETFL, fl | O_NONBLOCK);
}

void upd7201_reset(upd7201_t *s) {
    FILE *log = s->log_fp;
    upd7201_init(s, log);
}

/* Reading a register: register 0 (data) is the RX data path; register 1
 * (control) returns the RR pointed at by reg_ptr. */
uint8_t upd7201_read(upd7201_t *s, int chan, int is_data) {
    chan &= 1;
    if (is_data) {
        if (s->rx_pending[chan]) {
            uint8_t b = s->rx_data[chan];
            s->rx_pending[chan] = 0;
            s->rr[chan][0] &= ~SIO_RR0_RX_CHAR_AVAIL;
            return b;
        }
        return 0xFF;
    }
    /* Control read: returns the RR indexed by reg_ptr */
    uint8_t rr = s->rr[chan][s->reg_ptr[chan] % SIO_NUM_RR];
    s->reg_ptr[chan] = 0;       /* auto-reset to RR0 after read */
    return rr;
}

/* Writing register 0: register-pointer + command bits. Subsequent
 * writes go to the WR register selected by reg_ptr. Register 1 (data)
 * sends a TX byte. */
void upd7201_write(upd7201_t *s, int chan, int is_data, uint8_t val) {
    chan &= 1;
    if (is_data) {
        s->tx_data[chan] = val;
        s->tx_pending[chan] = 1;
        s->rr[chan][0] &= ~SIO_RR0_TX_BUFFER_EMPTY;
        if (s->log_fp) {
            fprintf(s->log_fp, "[SIO%c] TX <- %02X ('%c')\n",
                    'A'+chan, val, (val>=32 && val<127)?val:'.');
        }
        return;
    }

    int rp = s->reg_ptr[chan];
    if (rp == 0) {
        /* WR0 — command + register pointer */
        s->wr[chan][0] = val;
        /* low 3 bits = pointer */
        s->reg_ptr[chan] = val & 0x07;
        /* command bits 3..5: 0=null, 1=hi-bits set, 2=reset RX-int, 3=ch reset, 4=enable RX-int next char, 5=reset-tx-int, 6=err-reset, 7=ret-from-int */
        uint8_t cmd = (val >> 3) & 0x07;
        if (cmd == 3) { /* channel reset */
            s->rx_pending[chan] = 0;
            s->tx_pending[chan] = 0;
            s->rr[chan][0] = SIO_RR0_TX_BUFFER_EMPTY;
        }
        return;
    }
    /* WR1..WR7 — store programmed value, auto-reset pointer */
    if (rp < SIO_NUM_WR) s->wr[chan][rp] = val;
    s->reg_ptr[chan] = 0;
    if (s->log_fp) {
        fprintf(s->log_fp, "[SIO%c] WR%d <- %02X\n", 'A'+chan, rp, val);
    }
}

/* Drain any pending TX to console; poll stdin for RX. */
void upd7201_tick(upd7201_t *s, uint32_t cycles) {
    (void)cycles;
    for (int c = 0; c < 2; c++) {
        if (s->tx_pending[c]) {
            if (c == s->console_chan && s->console_enable) {
                fputc(s->tx_data[c], stdout);
                fflush(stdout);
            }
            s->tx_pending[c] = 0;
            s->rr[c][0] |= SIO_RR0_TX_BUFFER_EMPTY;
        }
    }
    /* Console RX: try non-blocking read on stdin into channel A */
    if (s->console_enable && !s->rx_pending[s->console_chan]) {
        unsigned char buf[1];
        ssize_t n = read(0, buf, 1);
        if (n == 1) {
            int c = s->console_chan;
            s->rx_data[c] = buf[0];
            s->rx_pending[c] = 1;
            s->rr[c][0] |= SIO_RR0_RX_CHAR_AVAIL;
        }
    }
}

int upd7201_irq_pending(const upd7201_t *s) {
    for (int c = 0; c < 2; c++)
        if (s->rr[c][0] & SIO_RR0_INT_PENDING) return 1;
    return 0;
}
