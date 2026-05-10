/* upd7201.h — NEC µPD7201 Multiprotocol Serial Communications Controller
 *
 * The µPD7201 is functionally a Z80-SIO clone (per NEC datasheet and
 * MAME's z80sio.cpp which implements both via i8274_device base).
 * Two independent channels (A, B). Each channel has:
 *   - TX register (write-only data)
 *   - RX register (read-only data)
 *   - Command register (write-only) — programs WR0..WR7 via pointer
 *   - Status register (read-only) — RR0..RR2
 *
 * Memory map on the FPS-3000 SBC (4 word-addressed slots, byte-paired):
 *   0xF70010 = Channel A data
 *   0xF70012 = Channel A control/status
 *   0xF70014 = Channel B data
 *   0xF70016 = Channel B control/status
 *
 * The FPS-3000 ROM doesn't currently exercise the SIO, but we
 * emulate it properly so downstream firmware (e.g., the Bomem app
 * running atop RSX-11M+ via this AP) can use it. Channel A is wired
 * to stdin/stdout for console behavior.
 */
#ifndef UPD7201_H
#define UPD7201_H

#include <stdint.h>
#include <stdio.h>

#define SIO_NUM_WR  8
#define SIO_NUM_RR  3

typedef struct {
    /* Per-channel write registers WR0..WR7 (control/mode programming) */
    uint8_t  wr[2][SIO_NUM_WR];
    /* Per-channel read registers RR0..RR2 (status) */
    uint8_t  rr[2][SIO_NUM_RR];
    /* Pointer into WR/RR set by writing to register 0 */
    uint8_t  reg_ptr[2];
    /* TX/RX FIFO depth-1 for simplicity */
    uint8_t  tx_data[2];
    uint8_t  tx_pending[2];
    uint8_t  rx_data[2];
    uint8_t  rx_pending[2];
    /* Channel A console hookup: TX to stdout, RX from stdin (non-blocking) */
    int      console_chan;     /* which channel maps to console (0 = A) */
    int      console_enable;
    FILE    *log_fp;
} upd7201_t;

/* RR0 status bits */
#define SIO_RR0_RX_CHAR_AVAIL   0x01
#define SIO_RR0_INT_PENDING     0x02
#define SIO_RR0_TX_BUFFER_EMPTY 0x04
#define SIO_RR0_DCD             0x08
#define SIO_RR0_SYNC_HUNT       0x10
#define SIO_RR0_CTS             0x20
#define SIO_RR0_TX_UNDERRUN     0x40
#define SIO_RR0_BREAK           0x80

void upd7201_init(upd7201_t *s, FILE *log);
void upd7201_reset(upd7201_t *s);

uint8_t upd7201_read (upd7201_t *s, int chan, int is_data);
void    upd7201_write(upd7201_t *s, int chan, int is_data, uint8_t val);

/* Tick — push pending TX to console; pull from stdin if available */
void    upd7201_tick(upd7201_t *s, uint32_t cycles);

int     upd7201_irq_pending(const upd7201_t *s);

#endif
