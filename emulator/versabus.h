/* versabus.h — VersaBUS-side device-trace + stubs for the FPS-3000 SBC.
 *
 * The SBC's view of the chassis: AP I/F (0xFF0000-0xFF00FF), XLTR
 * (0xFF0200-0xFF025F), and a mailbox region at 0x700000-0x700020.
 * Plus on-board MC6840 PTM (0xF70001-0xF7000F) and µPD7201 UART
 * (0xF70010-0xF70017), plus the M68KVM02 board-status register
 * (0xF70018-0xF7001A) and VERSAmodule control register (0x01FFF0).
 *
 * The stubs satisfy the ROM's probes — bits 14/13 of FF0000
 * autoset/autoclear so the panel-cmd poll loop terminates, channel
 * data ports return zero so RTOSKernelInit's channel-count loop
 * sees zero channels active, etc.
 *
 * Every access is logged to a file with full address + value +
 * symbolic name where known.
 */
#ifndef VERSABUS_H
#define VERSABUS_H

#include <stdint.h>
#include <stdio.h>

/* ---- AP I/F register block (0xFF0000-0xFF00FF) ---- */
#define APIF_BASE      0xFF0000
#define APIF_END       0xFF0100

#define APIF_CMD_STATUS    0xFF0000   /* opcode write (0x8004/0x8005); status read (b14=ready, b13=err) */
#define APIF_CMD_ARG_LO    0xFF000E
#define APIF_CMD_ARG_HI    0xFF0010
#define APIF_CH1_DATA_A    0xFF0048
#define APIF_CH1_DATA_B    0xFF004E
#define APIF_CH2_DATA_A    0xFF0068
#define APIF_CH2_DATA_B    0xFF006E
#define APIF_CH3_DATA_A    0xFF0088
#define APIF_CH3_DATA_B    0xFF008E
#define APIF_CH4_DATA_A    0xFF00A8
#define APIF_CH4_DATA_B    0xFF00AE

/* ---- XLTR register block (0xFF0200-0xFF025F) ---- */
#define XLTR_BASE      0xFF0200
#define XLTR_END       0xFF0260

#define XLTR_MODE0          0xFF0200
#define XLTR_MODE1          0xFF0202
#define XLTR_CHANNEL_SELECT 0xFF0204
#define XLTR_COUNTER        0xFF020C
#define XLTR_MODE2          0xFF0210
#define XLTR_DATA_LO        0xFF0214
#define XLTR_DATA_HI        0xFF0216
#define XLTR_STATUS_IRQ     0xFF0218
#define XLTR_IRQ_MASK       0xFF021A
#define XLTR_CH1_CONFIG     0xFF0244
#define XLTR_CH2_CONFIG     0xFF0246
#define XLTR_CH3_CONFIG     0xFF0250
#define XLTR_CH4_CONFIG     0xFF0252

/* ---- 0x700000 mailbox ---- */
#define MAILBOX_BASE   0x700000
#define MAILBOX_END    0x700040

#define MAILBOX_HOST_STATUS 0x70001C   /* host writes; SBC reads. b29 = host-needs-attention */
#define MAILBOX_SBC_REPLY   0x700020   /* SBC writes; host reads */

/* ---- MC6840 PTM (odd bytes only — uses MOVEP) ---- */
#define PTM_BASE       0xF70000
#define PTM_END        0xF70010

/* ---- NEC µPD7201 dual UART ---- */
#define UART_BASE      0xF70010
#define UART_END       0xF70018

/* ---- M68KVM02 board status/control register (PAL-decoded, 28 bits) ---- */
#define BOARD_STATUS_BASE  0xF70018
#define BOARD_STATUS_END   0xF7001C

/* ---- VERSAmodule control register ---- */
#define VMOD_CTRL          0x01FFF0

/* ----------------- public API ----------------- */

void versabus_init(FILE *trace_log, int verbose);
void versabus_close(void);

/* Bus access — return value, write side-effects */
uint32_t versabus_read(uint32_t addr, int size);    /* size = 1, 2, or 4 bytes */
void     versabus_write(uint32_t addr, uint32_t val, int size);

/* True if address belongs to a memory-mapped device (vs RAM/ROM) */
int      versabus_is_device(uint32_t addr);

/* Tick — drives any time-based device state (PTM, UART) */
void     versabus_tick(uint32_t cycles);

/* IRQ inquiry — non-zero if PTM IRQ pending */
int      versabus_ptm_irq_pending(void);
/* As above, gated by bit 7 of $1FFF1 (chassis-level enable) */
int      versabus_ptm_irq_gated(void);

/* Chassis-side vectored IRQ: pending when SBC has just written
 * a control bit that arms the panel-bus interrupter (phase 0x1300).
 * Ack returns the vector and clears the pending flag. */
int      versabus_chassis_irq_pending(void);
int      versabus_chassis_irq_ack(void);

/* Returns the current XLTR_DATA_HI value — used by the SBC bus
 * subsystem to gate BERR for chassis-routed long I/O addresses. */
unsigned versabus_xltr_data_hi(void);
unsigned versabus_xltr_data_lo(void);

/* Non-zero when XLTR is armed for DMA — AP I/F belongs to chassis */
int      versabus_apif_dma_busy(void);

/* Host-simulator hooks — host_sim drives these to push bytes into the
 * AP I/F state from the chassis side, and gets notified when the SBC
 * has consumed (read) the byte. */
void     versabus_inject_apif_byte(uint8_t a, uint8_t b, uint8_t status);
void     versabus_set_apif_consumed_cb(void (*cb)(void *ctx), void *ctx);

/* Queue a byte for delivery via the panel-command pull path
 * (PCMD_HOST_GET_BYTE = 0x281).  Called by host_sim. */
void     versabus_chassis_queue_byte(uint8_t b);
int      versabus_chassis_byte_queued(void);

/* For introspection / display */
void     versabus_dump_state(FILE *out);

#endif /* VERSABUS_H */
