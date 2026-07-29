/* versabus.c — implementation of all SBC peripheral stubs + access logger. */

#include "versabus.h"
#include "mc6840.h"
#include "upd7201.h"
#include "musashi/m68k.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* From Musashi — assert IRQ level synchronously when chassis fires */
extern void m68k_set_irq(unsigned int level);

/* XLTR MODE0 fields used by the panel-status handshake (Path B).  The
 * chassis returns a 5-bit response code in bits 0-4 and raises bit 11
 * (valid); the SBC's handler acknowledges by setting bit 10. */
#define MODE0_RESP_VALID  (1u << 11)
#define MODE0_RESP_ACK    (1u << 10)
#define MODE0_RESP_MASK   0xFFu   /* bit 7 selects the dispatcher; bits 0-4 are the code */

static FILE *log_fp = NULL;
static int   verbose = 0;
static mc6840_t  ptm_dev;
static upd7201_t sio_dev;

/* AP I/F state */
static struct {
    uint16_t cmd_status;       /* 0xFF0000 — bit 14 = ready, bit 13 = error */
    uint16_t cmd_arg_lo;
    uint16_t cmd_arg_hi;
    uint16_t ch_data[4][2];    /* [chan][A=0,B=1] — channel data ports */
    uint16_t last_opcode;
    uint64_t cmd_count;        /* count of commands issued */
} apif;

/* XLTR state */
static struct {
    uint16_t mode0;
    uint16_t mode1;
    uint16_t mode2;
    uint16_t channel_select;
    uint16_t counter;
    uint16_t data_lo;
    uint16_t data_hi;
    uint16_t status_irq;       /* bit 15 = ready/done; arm by writing 0x400 */
    uint16_t irq_mask;
    uint16_t ch_config[4];     /* CH1..CH4 config regs */
    uint16_t arm_pending;      /* set when 0x400 written to status_irq; auto-completes next read */
    uint32_t busy_ticks;       /* decrements on each versabus_tick; while >0 chassis is "engaged" */
    /* Generic backing store for the whole XLTR window.  The phase
     * 0x1600 self-test walks $210..$24E writing patterns and reading
     * back, so every register in the block must round-trip. */
    uint16_t raw[0x30];        /* 48 words covering $200..$25F */
} xltr;

/* 0x700000 mailbox state */
static struct {
    uint32_t host_status;      /* 0x70001C — host writes, SBC reads */
    uint32_t sbc_reply;        /* 0x700020 — SBC writes, host reads */
} mailbox;

/* (MC6840 PTM and µPD7201 SIO state lives in mc6840_t / upd7201_t,
 * defined in their respective .c files and shared via ptm_dev / sio_dev.) */

/* Board status/control register (M68KVM02 PAL-decoded) */
static uint32_t board_status;
static void bim_reset(void);   /* defined with the BIM model below */
int versabus_seq_chsel(uint16_t *out);          /* scripted chassis responses */
static int versabus_seq_take(uint8_t *code);

/* Which BIM channel's handler is currently running.  The panel-command
 * spins live in two tiers: task-context ones (F04530, F056B8) park at
 * IPL 0 and a level-6 BIM0 ch0 interrupt wakes them, but the five
 * per-channel ones (F05E86, F068D8, F072F0, F07CF0, F086F0, one per
 * channel task on the $A00 stride) park INSIDE a level-7 ISR having
 * never returned, so only a fresh level-7 edge reaches them.  The
 * response therefore has to come back on the channel whose handler
 * issued the command. */
static int      bim_in_service_unit = -1, bim_in_service_ch = -1;

/* Count of $D0 checkpoint markers the SBC has written to $1FFF1. */
static int      vmod_d0_writes;
static int      vmod_d0_ack;      /* checkpoint indication consumed */
static int      srec_exhausted;  /* S-record source ran out */
static uint64_t seq_gap_left;     /* cycles until the next scripted command */
static uint64_t seq_gap_cycles(void) {
    const char *e = getenv("FPS3K_SEQGAP");
    return e ? strtoull(e, NULL, 0) : 20000000ull;
}

/* VERSAmodule control register */
static uint16_t vmod_ctrl;

/* Chassis-side IRQ source: phase 0x1300 panel-bus interrupt test fires
 * a vectored IRQ when SBC writes bits 0..2 of $1FFF1 with bit 7 set.
 * Cleared on IACK. */
static int      chassis_irq_pending;
static int      chassis_irq_vector;
static int      chassis_irq_level = 4;

/* ============== logging helpers ============== */

static const char *apif_offset_name(uint32_t addr) {
    switch (addr) {
        case APIF_CMD_STATUS:  return "APIF_CMD_STATUS";
        case APIF_CMD_ARG_LO:  return "APIF_CMD_ARG_LO";
        case APIF_CMD_ARG_HI:  return "APIF_CMD_ARG_HI";
        case APIF_CH1_DATA_A:  return "APIF_CH1_DATA_A";
        case APIF_CH1_DATA_B:  return "APIF_CH1_DATA_B";
        case APIF_CH2_DATA_A:  return "APIF_CH2_DATA_A";
        case APIF_CH2_DATA_B:  return "APIF_CH2_DATA_B";
        case APIF_CH3_DATA_A:  return "APIF_CH3_DATA_A";
        case APIF_CH3_DATA_B:  return "APIF_CH3_DATA_B";
        case APIF_CH4_DATA_A:  return "APIF_CH4_DATA_A";
        case APIF_CH4_DATA_B:  return "APIF_CH4_DATA_B";
        default:               return "APIF_unknown";
    }
}
static const char *xltr_offset_name(uint32_t addr) {
    switch (addr) {
        case XLTR_MODE0:           return "XLTR_MODE0";
        case XLTR_MODE1:           return "XLTR_MODE1";
        case XLTR_CHANNEL_SELECT:  return "XLTR_CHANNEL_SELECT";
        case XLTR_COUNTER:         return "XLTR_COUNTER";
        case XLTR_MODE2:           return "XLTR_MODE2";
        case XLTR_DATA_LO:         return "XLTR_DATA_LO";
        case XLTR_DATA_HI:         return "XLTR_DATA_HI";
        case XLTR_STATUS_IRQ:      return "XLTR_STATUS_IRQ";
        case XLTR_IRQ_MASK:        return "XLTR_IRQ_MASK";
        case XLTR_CH1_CONFIG:      return "XLTR_CH1_CONFIG";
        case XLTR_CH2_CONFIG:      return "XLTR_CH2_CONFIG";
        case XLTR_CH3_CONFIG:      return "XLTR_CH3_CONFIG";
        case XLTR_CH4_CONFIG:      return "XLTR_CH4_CONFIG";
        default:                   return "XLTR_unknown";
    }
}
static const char *device_class(uint32_t addr) {
    if (addr >= APIF_BASE && addr < APIF_END) return "APIF";
    if (addr >= XLTR_BASE && addr < XLTR_END) return "XLTR";
    if (addr >= MAILBOX_BASE && addr < MAILBOX_END) return "MAILBOX";
    if (addr >= PTM_BASE && addr < PTM_END) return "PTM";
    if (addr >= UART_BASE && addr < UART_END) return "UART";
    if (addr >= BOARD_STATUS_BASE && addr < BOARD_STATUS_END) return "BOARD_STATUS";
    if (addr == VMOD_CTRL || addr == VMOD_CTRL+1) return "VMOD_CTRL";
    return "UNKNOWN";
}

/* Pretty-print panel-command codes */
static const char *chassis_panel_cmd_name(uint16_t cmd) {
    switch (cmd) {
        case 0x258: return "PCMD_CH1_RESET";
        case 0x259: return "PCMD_CH1_INIT";
        case 0x25A: return "PCMD_CH1_ACK";
        case 0x25B: return "PCMD_CH1_FLUSH";
        case 0x25C: return "PCMD_RESET_STATUS";
        case 0x25D: return "PCMD_CH1_CONFIG";
        case 0x25E: return "PCMD_CH2_CONFIG";
        case 0x25F: return "PCMD_CH3_CONFIG";
        case 0x260: return "PCMD_CH4_CONFIG";
        case 0x269: return "PCMD_ERROR_ABORT";
        case 0x26A: return "PCMD_TIMEOUT_ABORT";
        case 0x26B: return "PCMD_CH_ABORT";
        case 0x26C: return "PCMD_RELEASE";
        case 0x26E: return "PCMD_CH1_TCB_FAIL";
        case 0x271: return "PCMD_CH4_TCB_FAIL";
        case 0x276: return "PCMD_INIT_STEP1";
        case 0x277: return "PCMD_INIT_STEP2";
        case 0x278: return "PCMD_INIT_STEP3";
        case 0x279: return "PCMD_INIT_STEP4";
        case 0x27A: return "PCMD_INIT_STEP5";
        case 0x27B: return "PCMD_INIT_STEP6";
        case 0x27D: return "PCMD_INIT_STEP8";
        case 0x27E: return "PCMD_TCBIO1I_INIT_FAIL";
        case 0x27F: return "PCMD_TCBIO1I_DATA_FAIL";
        case 0x280: return "PCMD_TCBIO1I_RUN_FAIL";
        case 0x281: return "PCMD_HOST_REQUEST";
        case 0x282: return "PCMD_HOST_NULL";
        case 0x29E: return "PCMD_RTOS_29E";
        case 0x29F: return "PCMD_RTOS_29F";
        default:    return NULL;
    }
}

static void log_access(const char *op, uint32_t addr, uint32_t val, int size) {
    if (!log_fp) return;
    const char *cls = device_class(addr);
    const char *name = "";
    if (addr >= APIF_BASE && addr < APIF_END) name = apif_offset_name(addr);
    else if (addr >= XLTR_BASE && addr < XLTR_END) name = xltr_offset_name(addr);
    else if (addr == MAILBOX_HOST_STATUS) name = "MAILBOX_HOST_STATUS";
    else if (addr == MAILBOX_SBC_REPLY)   name = "MAILBOX_SBC_REPLY";

    fprintf(log_fp, "[%-12s] %s %d-byte %06X = %08X  %s",
            cls, op, size, addr, val, name);
    if (getenv("FPS3K_BUSPC"))
        fprintf(log_fp, " @%06X", m68k_get_reg(NULL, M68K_REG_PPC));

    /* For panel-cmd-related writes, decode the panel cmd */
    if ((addr == APIF_CMD_ARG_HI ||
         addr == APIF_CMD_ARG_LO ||
         addr == XLTR_CHANNEL_SELECT) && size == 2) {
        const char *pn = chassis_panel_cmd_name((uint16_t)val);
        if (pn) fprintf(log_fp, "  ; %s", pn);
    }
    if (addr == APIF_CMD_STATUS && size == 2) {
        if (val == 0x8004) fprintf(log_fp, "  ; REQUEST-TRANSFER");
        else if (val == 0x8005) fprintf(log_fp, "  ; CONTINUE-TRANSFER");
    }
    fprintf(log_fp, "\n");
    fflush(log_fp);
}

void versabus_init(FILE *trace_log, int verb) {
    log_fp = trace_log;
    verbose = verb;
    memset(&apif, 0, sizeof apif);
    memset(&xltr, 0, sizeof xltr);
    bim_reset();
    memset(&mailbox, 0, sizeof mailbox);
    mc6840_init(&ptm_dev, log_fp);
    upd7201_init(&sio_dev, log_fp);
    /* Default board-status, derived from ROMChecksumTest's expected
     * pattern: (F70018 word) & 0x3F31 == 0x3F11, plus the F08728
     * poll requires bit 4 of F70019 set + bit 5 clear:
     *   F70018 = 0x3F (bits 0..5 set, bits 6..7 clear)
     *   F70019 = 0x11 (bit 0 set, bit 4 set, others clear)
     * Mask 0x3F31 doesn't probe bit 4, but the F08728 poll does.
     * In big-endian uint32: bytes [F70018, F70019, F7001A, F7001B]
     * → board_status = 0x3F11_xx_xx (xx = unused upper bytes set 0). */
    board_status = 0x3F110000;
    vmod_ctrl = 0;
    /* AP I/F: start with ready=1 (bit 14) so first read shows ready */
    apif.cmd_status = (1u << 14);
}

void versabus_close(void) { /* no resources to free */ }

int versabus_is_device(uint32_t addr) {
    return  (addr >= APIF_BASE && addr < APIF_END)
         || (addr >= XLTR_BASE && addr < XLTR_END)
         || (addr >= MAILBOX_BASE && addr < MAILBOX_END)
         || (addr >= PTM_BASE && addr < PTM_END)
         || (addr >= UART_BASE && addr < UART_END)
         || (addr >= BOARD_STATUS_BASE && addr < BOARD_STATUS_END)
         || (addr == VMOD_CTRL || addr == VMOD_CTRL+1);
}

/* ============== AP I/F handler ============== */

/* Host-side injection state */
static void  (*apif_consumed_cb)(void *ctx) = NULL;
static void   *apif_consumed_ctx = NULL;
static uint8_t apif_inj_status = 0;

void versabus_inject_apif_byte(uint8_t a, uint8_t b, uint8_t status) {
    apif.ch_data[0][0] = a;        /* surfaces at $FF0048 (CH1 data A) */
    apif.ch_data[0][1] = b;        /* surfaces at $FF004E (CH1 data B) */
    apif_inj_status    = status;   /* surfaces at $FF004A read */
    /* Indicate "host has data" via cmd_status bit 14 (ready flag) */
    apif.cmd_status   |= (1u << 14);
    /* TCBIO1I ISR (F05DD6) reads $70001C and tests bit 29 ("host
     * needs attention").  Set it so the ISR proceeds into the byte-
     * receive path. */
    mailbox.host_status |= (1u << 29);
    /* TCBIO1I at F05E2C takes this same word, swaps it and masks #3 —
     * i.e. bits 16-17 are a payload/class field that must read 1 for the
     * reply at F05E40 to be written.  FPS3K_MBOX ORs extra bits in so
     * that field can be driven. */
    {
        const char *e = getenv("FPS3K_MBOX");
        if (e) mailbox.host_status = (uint32_t)strtoul(e, NULL, 16);
    }
}

void versabus_set_apif_consumed_cb(void (*cb)(void *ctx), void *ctx) {
    apif_consumed_cb  = cb;
    apif_consumed_ctx = ctx;
}

static void apif_notify_consumed(void) {
    if (apif_consumed_cb) apif_consumed_cb(apif_consumed_ctx);
}

/* Last panel command written to $FF000E by the SBC — the chassis
 * uses this to decide what response to produce when the SBC kicks
 * off the operation by writing 0x8004 to $FF0000. */
static uint16_t last_panel_cmd;

/* Pending byte from host_sim to deliver via panel-cmd response.
 * When the chassis is asked "give me next byte" (panel cmd 0x281
 * after a host-attention IRQ), the byte is loaded into the channel
 * data ports as part of the chassis ack. */
static int      panel_byte_queued;
static uint8_t  panel_byte_value;

void versabus_chassis_queue_byte(uint8_t b) {
    panel_byte_value  = b;
    panel_byte_queued = 1;
}
int  versabus_chassis_byte_queued(void) {
    return panel_byte_queued;
}

static void chassis_process_panel_cmd(uint16_t cmd) {
    if (log_fp) fprintf(log_fp, "[CHASSIS] panel cmd 0x%03X (%s)\n",
                        cmd, chassis_panel_cmd_name(cmd));

    switch (cmd) {
    case 0x276: case 0x277: case 0x278: case 0x279:
    case 0x27A: case 0x27B: case 0x27D:
        /* Init steps — chassis just acks success. */
        break;

    case 0x269: case 0x26C:
        /* RELEASE / ABORT — chassis releases its lock, acks. */
        break;

    case 0x281:
        /* SBC asking for next host byte.  If we have one queued from
         * host_sim, deliver it via channel-1 data ports. */
        if (panel_byte_queued) {
            apif.ch_data[0][0] = panel_byte_value;        /* $FF0048 */
            apif.ch_data[0][1] = panel_byte_value;        /* $FF004E */
            apif_inj_status    = 0x4F;                    /* $FF004A */
            /* Advance the host-side queue — apif_notify_consumed
             * is called from the channel-data read paths. */
        } else {
            apif.ch_data[0][0] = 0;
            apif.ch_data[0][1] = 0;
            apif_inj_status    = 0;
        }
        break;

    case 0x282:
        /* "Re-sync" / "give me byte again" — same as 0x281 but
         * doesn't advance the host's stream pointer.  We deliver
         * the same byte without consuming. */
        if (panel_byte_queued) {
            apif.ch_data[0][0] = panel_byte_value;
            apif.ch_data[0][1] = panel_byte_value;
            apif_inj_status    = 0x4F;
        }
        break;

    default:
        /* The Am29116 SUBRC panel codes run $258-$27D (38 codes: TORIA
         * $258-$25F, TODRA $260-$27D).  None of them has a data
         * side-effect we model, so they need no case here — they fall
         * through to the common ack below, same as any other code.  An
         * earlier version had an empty `if (cmd >= 0x258 && cmd <= 0x260)`
         * block here, which did nothing and implied a 9-code range that
         * matched neither the comment nor the hardware. */
        break;
    }
    /* All commands ack via cmd_status: bit 14 = ready, bit 13 = error.
     * For now nothing produces an error. */
    apif.cmd_status |= (1u << 14);
    apif.cmd_status &= ~(1u << 13);
}

static uint16_t apif_read(uint32_t addr) {
    /* FPS3K_DATAIN: the bulk data-in port at $FF0008 hands back an
     * incrementing pattern, so the destination decode can be checked
     * against a RAM dump. */
    if (addr == 0xFF0008 && getenv("FPS3K_DATAIN")) {
        static uint16_t n = 0x1000;
        return n++;
    }
    /* FPS3K_SREC=<file> serves the file's text through $FF0008 as two
     * ASCII characters per 16-bit word, which is how the firmware's
     * S-record front end at F04B22 reads it (F04B8A compares against
     * $5330 = "S0"). */
    /* $FF0004 bit 0 is the port-ready flag the firmware polls at F04B22
     * and F05A22 before every transfer.  With an S-record source
     * configured, data is always available. */
    if (addr == 0xFF0004 && getenv("FPS3K_SREC"))
        return srec_exhausted ? 0x0000 : 0x0001;   /* bit 0 = data available */

    /* END OF STREAM.  SRecordDataHandler's reject/drain loop at F05218
     * reads $FF0000 and exits when it is <= 0 as a signed word, so the
     * chassis says "nothing more" by clearing it.  Without this the drain
     * never terminates -- which is exactly what the first S-record runs
     * did.  Documented in versabus_access_map.md. */
    if (addr == APIF_CMD_STATUS && srec_exhausted) return 0x0000;

    if (addr == 0xFF0008) {
        const char *fn = getenv("FPS3K_SREC");
        if (fn) {
            static FILE *sf; static int done;
            if (!sf && !done) { sf = fopen(fn, "rb"); if (!sf) done = 1; }
            if (sf) {
                int c1 = fgetc(sf), c2 = fgetc(sf);
                if (c1 == EOF) { fclose(sf); sf = NULL; done = 1;
                                 srec_exhausted = 1; return 0; }
                if (c2 == EOF) c2 = 0x0A;
                return (uint16_t)((c1 << 8) | c2);
            }
        }
    }
    if (addr == APIF_CMD_STATUS || addr == APIF_CMD_STATUS+1) {
        /* When the ROM polls after writing 0x8004/0x8005, we automatically
         * advance the state to "ready, no error" so the loop terminates. */
        uint16_t v = apif.cmd_status;
        if (apif.last_opcode == 0x8004 || apif.last_opcode == 0x8005) {
            apif.cmd_status |= (1u << 14);   /* set ready */
            apif.cmd_status &= ~(1u << 13);  /* clear error */
        }
        return v;
    }
    if (addr == APIF_CMD_ARG_LO) return apif.cmd_arg_lo;
    if (addr == APIF_CMD_ARG_HI) return apif.cmd_arg_hi;
    /* CH1 status word at $FF004A — used by host_sim to flag "byte ready" */
    if (addr == 0xFF004A) return apif_inj_status;
    if (addr == APIF_CH1_DATA_A || addr == APIF_CH1_DATA_B) {
        int bx = (addr - APIF_CH1_DATA_A) / 6;
        uint16_t v = apif.ch_data[0][bx & 1];
        /* SBC has consumed the byte — clear our queued byte and let
         * host_sim post the next one. */
        if (addr == APIF_CH1_DATA_A) {
            panel_byte_queued = 0;
            apif_notify_consumed();
        }
        return v;
    }
    /* Per-channel data ports */
    for (int c = 0; c < 4; c++) {
        uint32_t base = APIF_CH1_DATA_A + c * 0x20;
        if (addr == base) return apif.ch_data[c][0];
        if (addr == base + 6) return apif.ch_data[c][1];
    }
    return 0;
}

/* True when the XLTR has been armed for DMA AND chassis is gated
 * to deny SBC access (DATA_HI != 0).  Phase 0x1A00 verifies the
 * full truth table:
 *   stage 0 (DATA_HI=0x80, armed)   → BERR
 *   stage 1 (DATA_HI=0x80, !armed)  → no BERR (mem access)
 *   stage 2 (DATA_HI=0,    armed)   → no BERR (chassis idle)
 * So the BERR condition is "armed AND DATA_HI != 0". */
int versabus_apif_dma_busy(void) {
    return xltr.arm_pending && xltr.data_hi != 0;
}

static void apif_write(uint32_t addr, uint16_t val) {
    if (addr == APIF_CMD_STATUS || addr == APIF_CMD_STATUS+1) {
        apif.last_opcode = val;
        apif.cmd_count++;
        apif.cmd_status &= ~((1u << 14) | (1u << 13));  /* clear ready+error */
        /* REQUEST-TRANSFER (0x8004) — chassis processes the panel
         * cmd queued at $FF000E and produces an ack. */
        if (val == 0x8004) {
            chassis_process_panel_cmd(last_panel_cmd);
            /* The chassis answers a panel command by returning a status
             * code and interrupting on BIM0 ch0.  $14 is D2_FIN, the
             * finalize code; it is the one code whose meaning we know, so
             * it is what we return until the others are decoded. */
            versabus_arm_panel_response(0x14, 400);
        }
        /* CONTINUE-TRANSFER (0x8005) — re-fire current cmd with the
         * same args (used to fetch successive bytes in a stream). */
        if (val == 0x8005) {
            chassis_process_panel_cmd(last_panel_cmd);
        }
        return;
    }
    if (addr == APIF_CMD_ARG_LO) {
        apif.cmd_arg_lo = val;
        last_panel_cmd  = val;        /* SBC stages panel cmd here */
        return;
    }
    if (addr == APIF_CMD_ARG_HI) { apif.cmd_arg_hi = val; return; }
    /* Per-channel data ports — writes ignored (these are read-only status from AP) */
}

/* ============== XLTR handler ============== */

static uint16_t xltr_read(uint32_t addr) {
    /* FPS3K_CHSEL_RD=<hex> makes CHANNEL_SELECT read back that value
     * instead of what the SBC last wrote.  F04A84 reads this register
     * and the bulk-transfer loop at F04AE2 only runs when it reads $28,
     * so this is how the chassis would signal "bulk transfer pending". */
    if (addr == XLTR_CHANNEL_SELECT) {
        uint16_t sv;
        if (versabus_seq_chsel(&sv)) return sv;
        const char *e = getenv("FPS3K_CHSEL_RD");
        if (e) return (uint16_t)strtoul(e, NULL, 16);
    }
    /* Special-case the registers with side effects */
    if (addr == XLTR_STATUS_IRQ) {
        if (xltr.arm_pending) {
            xltr.status_irq |= (1u << 15);
            xltr.arm_pending = 0;
        }
        xltr.raw[(addr - XLTR_BASE) / 2] = xltr.status_irq;
        return xltr.status_irq;
    }
    /* Default: return raw backing store (handles $200..$25F uniformly) */
    int idx = (addr - XLTR_BASE) / 2;
    if (idx >= 0 && idx < (int)(sizeof xltr.raw / sizeof xltr.raw[0])) {
        return xltr.raw[idx];
    }
    return 0;
}

/* ============== MC68153-style BIMs ($FF0230-$FF025F) ==============
 *
 * Layout confirmed against the MC68153 datasheet and against what the
 * firmware writes (see refs_extracted/versabus_access_map.md):
 *   CR0..CR3 at base+$0,+$2,+$4,+$6   VR0..VR3 at base+$8,+$A,+$C,+$E
 *   CRn controls INTn.  CR bits 0-2 = request level (0 disables the
 *   channel outright), bit 4 = IRE.
 * The firmware programs BIM2 ch2 (CR $FF0254 = $5F, VR $FF025C = $4A)
 * for the TCBIO1I host link: level 7, vector $4A -> $128 -> F05DD6.
 * We previously hard-coded level 5 and vector 0x4A, which was wrong on
 * both counts. */
static struct {
    uint8_t cr[BIM_CH];
    uint8_t vr[BIM_CH];
    int     req[BIM_CH];       /* device interrupt input asserted */
} bim[BIM_COUNT];

/* Datasheet reset state: "The control registers are reset to all zeroes
 * and the Vector Registers are set to a value of $0F.  This vector value
 * is the uninitialized vector for the MC68000." */
static void bim_reset(void) {
    for (int u = 0; u < BIM_COUNT; u++)
        for (int c = 0; c < BIM_CH; c++) {
            bim[u].cr[c] = 0x00;
            bim[u].vr[c] = 0x0F;
            bim[u].req[c] = 0;
        }
}

/* Known CR bits, from the MC68153 datasheet:
 *   bits 0-2  L0-L2, interrupt request level (0 disables the channel)
 *   bit 4     IRE, interrupt enable
 *   bit 7     F, flag ("Flag (F) is located in bit position 7")
 * IRAC (interrupt auto-clear) is bit 5, inferred from Motorola's own
 * VERSAdos drivers: MPCCDRV.SA programs its BIM with BIM_SET = $3B (bit
 * 5 set) and rewrites that value inside the interrupt handler under the
 * comment "Clear the interrupt at the BIM #1", which is the re-arm IRAC=1
 * forces.  The FPS firmware writes $5F (bit 5 CLEAR) to $FF0254 once at
 * task start and never re-arms.  So auto-clear is off on this machine and
 * a channel stays armed after acknowledgement, which is what the code
 * below does.  FAC is the remaining candidate for bit 6; X/IN is unlocated. */

#define BIM_CR_LEVEL(c)  ((c) & 0x07)
#define BIM_CR_IRE(c)    (((c) >> 4) & 1)

static int bim_decode(uint32_t addr, int *unit, int *reg) {
    if (addr < BIM_BASE || addr >= BIM_END) return 0;
    uint32_t off = addr - BIM_BASE;
    *unit = (int)(off / 0x10);
    *reg  = (int)((off % 0x10) / 2);   /* 0-3 = CR0-3, 4-7 = VR0-3 */
    return (*unit < BIM_COUNT);
}

/* Experiment: FPS3K_HOSTLVL overrides the level the host channel
 * (BIM2 ch2) requests.  $5F decodes to level 7, but the board's IRQ pin
 * wiring is unverified (Check 2 in the trace worksheet).  If the real
 * level is below 6, BIM0 ch0 can preempt the host ISR and F04930 gets to
 * run, which is what the design appears to need. */
static int bim_level_of(int unit, int ch) {
    uint8_t cr = bim[unit].cr[ch];
    int lvl = BIM_CR_LEVEL(cr);
    if (unit == BIM_HOST_UNIT && ch == BIM_HOST_CH) {
        const char *e = getenv("FPS3K_HOSTLVL");
        if (e && lvl) lvl = (int)strtoul(e, NULL, 0) & 7;
    }
    return lvl;
}

int versabus_bim_assert(int unit, int ch) {
    if (unit < 0 || unit >= BIM_COUNT || ch < 0 || ch >= BIM_CH) return 0;
    bim[unit].req[ch] = 1;
    uint8_t cr = bim[unit].cr[ch];
    if (!BIM_CR_IRE(cr)) return 0;
    return bim_level_of(unit, ch);
}

void versabus_bim_clear(int unit, int ch) {
    if (unit < 0 || unit >= BIM_COUNT || ch < 0 || ch >= BIM_CH) return;
    bim[unit].req[ch] = 0;
}

int versabus_bim_enabled(int unit, int ch) {
    if (unit < 0 || unit >= BIM_COUNT || ch < 0 || ch >= BIM_CH) return 0;
    uint8_t cr = bim[unit].cr[ch];
    return BIM_CR_IRE(cr) && BIM_CR_LEVEL(cr);
}

int versabus_bim_pending_level(void) {
    int best = 0;
    for (int u = 0; u < BIM_COUNT; u++)
        for (int c = 0; c < BIM_CH; c++) {
            if (!bim[u].req[c]) continue;
            uint8_t cr = bim[u].cr[c];
            if (!BIM_CR_IRE(cr)) continue;
            int lvl = bim_level_of(u, c);
            if (lvl > best) best = lvl;
        }
    return best;
}

int versabus_bim_iack(int level) {
    /* Datasheet: on a level match the interrupter supplies its vector.
     * Among several requesters at the same level, "preference is given to
     * the highest number requester, that is, INT3 has highest priority
     * and INT0 has lowest".  That rule covers channels WITHIN one chip.
     *
     * Ordering BETWEEN the three chips is decided on the real card by the
     * IACKIN / IACKOUT daisy chain, whose wiring we have not traced (it is
     * Check 3 in refs_extracted/versabus_trace_worksheet.pdf).  Scanning
     * unit 2 first is a placeholder, not a derived rule.  It only matters
     * when two chips request the same level in the same cycle. */
    for (int u = BIM_COUNT - 1; u >= 0; u--)
        for (int c = BIM_CH - 1; c >= 0; c--) {
            if (!bim[u].req[c]) continue;
            uint8_t cr = bim[u].cr[c];
            if (!BIM_CR_IRE(cr)) continue;
            if (bim_level_of(u, c) != level) continue;
            if (log_fp)
                fprintf(log_fp, "[BIM] IACK L%d -> unit %d ch %d vector $%02X\n",
                        level, u, c, bim[u].vr[c]);
            bim_in_service_unit = u; bim_in_service_ch = c;
            /* Drop the request once acknowledged.  Without this the input
             * latches high forever and versabus_bim_pending_level() keeps
             * reporting the level, so a caller trusting the BIM alone would
             * see a permanently asserted line.
             *
             * IRAC (bit 5) is CLEAR in the $5F this firmware writes, so
             * the chip does not auto-clear IRE on acknowledgement and the
             * channel stays armed.  Nothing to do here.  A firmware that
             * sets bit 5 would need IRE cleared at this point. */
            bim[u].req[c] = 0;
            /* Release the IRQ line now.  The datasheet's Figure 10 shows
             * IRQX negated at the end of the acknowledge cycle, and the
             * CPU needs to see that deassertion: a level-7 request only
             * re-triggers on a fresh <7-to-7 edge, so if the line never
             * drops, a later response on the same channel is silently
             * swallowed.  Without this the SBC parks in `bra .` forever. */
            m68k_set_irq(0);
            return bim[u].vr[c];
        }
    return -1;
}

static void xltr_write(uint32_t addr, uint16_t val) {
    int bu, br;
    if (bim_decode(addr, &bu, &br)) {
        /* 8-bit register on the low byte of the word slot */
        if (br < 4) bim[bu].cr[br]     = (uint8_t)val;
        else        bim[bu].vr[br - 4] = (uint8_t)val;
        if (log_fp)
            fprintf(log_fp, "[BIM] unit %d %s%d <- $%02X\n",
                    bu, br < 4 ? "CR" : "VR", br < 4 ? br : br - 4, (uint8_t)val);
        /* fall through so the raw shadow still round-trips on read */
    }
    int idx = (addr - XLTR_BASE) / 2;
    if (idx < 0 || idx >= (int)(sizeof xltr.raw / sizeof xltr.raw[0])) return;

    /* Update raw backing first so subsequent reads round-trip */
    xltr.raw[idx] = val;

    /* Track the named-register shadow state used by the dump_state
     * pretty-printer and external IRQ logic */
    switch (addr) {
        case XLTR_MODE0:          xltr.mode0 = val; break;
        case XLTR_MODE1:
            /* Setting bit 15 (0x8000) arms a chassis operation —
             * the chassis becomes "engaged" for a short window
             * before reporting ready.  Phase 0x1A00 handshake at
             * F087C2 wants to see bit 4 of board status drop, while
             * F08846 wants it to come back up after engage completes. */
            if ((val & 0x8000) && !(xltr.mode1 & 0x8000)) {
                xltr.busy_ticks = 4096;
            }
            xltr.mode1 = val;
            break;
        case XLTR_CHANNEL_SELECT:
            xltr.channel_select = val;
            /* The SBC issues a panel command by clearing MODE0 bit 10,
             * writing the command code here, then parking in `bra .` at
             * F05E86.  The chassis answers with a status code and an
             * interrupt, and the handler rewrites the saved PC to step
             * the CPU past the spin.  Arm that response now. */
            /* The trigger is the CHANNEL_SELECT write itself with MODE0
             * bit 10 (response-acknowledge) already clear — that is the
             * Path-B handshake as documented, and it covers both call
             * sites.  Gating on a $258-range command code here was wrong:
             * PanelIOConfigure_25A (F05688) writes an *argument* to
             * $FF000E, not a command code, so its spin at F056B8 was never
             * answered and the machine stalled one step further on. */
            if (log_fp)
                fprintf(log_fp, "[PANEL] CHANNEL_SELECT <- $%04X, mode0=$%04X, arm=%s\n",
                        val, xltr.mode0,
                        (xltr.mode0 & MODE0_RESP_ACK) ? "no (ACK set)" : "yes");
            /* Only a real panel command gets a response.  PanelIOConfigure
             * sets MODE1 bit 12 (bset #$c at F056A0) before writing
             * CHANNEL_SELECT; the self-test register walks write MODE1 =
             * $2000 with bit 12 clear.  Without this gate the model armed
             * a response during phase $1600 and put a code into MODE0's
             * low byte, which F09590-F09598 checks must be zero -- the
             * chassis model was failing the firmware's own test. */
            if ((xltr.mode1 & 0x1000) && !(xltr.mode0 & MODE0_RESP_ACK)) {
                /* FPS3K_RESP overrides the returned status code, so the
                 * 0..$14 code space can be swept experimentally. */
                const char *e = getenv("FPS3K_RESP");
                versabus_arm_panel_response(e ? (uint8_t)strtoul(e, NULL, 0) : 0x14, 400);
            }
            break;
        case XLTR_COUNTER:        xltr.counter = val; break;
        case XLTR_MODE2:          xltr.mode2 = val; break;
        case XLTR_DATA_LO:        xltr.data_lo = val; break;
        case XLTR_DATA_HI:        xltr.data_hi = val; break;
        case XLTR_STATUS_IRQ:
            if (val == 0x0000) {
                xltr.status_irq = 0;
                xltr.arm_pending = 0;
            } else if (val == 0x0400) {
                /* Store the arm bit in status_irq so subsequent
                 * reads can show it alongside the auto-set ready bit
                 * (phase 0x1600 self-test verifies status & 0x610 == 0x400) */
                xltr.status_irq = 0x0400;
                xltr.arm_pending = 1;
            } else {
                xltr.status_irq = val;
            }
            break;
        case XLTR_IRQ_MASK:       xltr.irq_mask = val; break;
        case XLTR_CH1_CONFIG:     xltr.ch_config[0] = val; break;
        case XLTR_CH2_CONFIG:     xltr.ch_config[1] = val; break;
        case XLTR_CH3_CONFIG:     xltr.ch_config[2] = val; break;
        case XLTR_CH4_CONFIG:     xltr.ch_config[3] = val; break;
    }
}

/* ============== mailbox handler ============== */

static uint32_t mailbox_read(uint32_t addr, int size) {
    if (addr == MAILBOX_HOST_STATUS) return mailbox.host_status;
    if (addr == MAILBOX_SBC_REPLY)   return mailbox.sbc_reply;
    return 0;
}

static void mailbox_write(uint32_t addr, uint32_t val, int size) {
    if (addr == MAILBOX_HOST_STATUS) { mailbox.host_status = val; return; }
    if (addr == MAILBOX_SBC_REPLY)   { mailbox.sbc_reply = val; return; }
}

/* ============== PTM (MC6840) handler — delegated to mc6840.c ============== */

static uint8_t ptm_read(uint32_t addr) {
    /* PTM at odd byte addresses 0xF70001 + 2*reg; reg index 0..7 */
    int reg = ((addr - 0xF70001) / 2) & 7;
    return mc6840_read(&ptm_dev, reg);
}

static void ptm_write(uint32_t addr, uint8_t val) {
    int reg = ((addr - 0xF70001) / 2) & 7;
    mc6840_write(&ptm_dev, reg, val);
}

/* ============== SIO (NEC µPD7201) handler — delegated to upd7201.c ============== */

/* Register layout, per Motorola's own VERSAdos source for this board —
 * verdos06/SDLCPRI/NEC7201.EQ (~/src/claude/versados/rms68k_source.SA:6963):
 *
 *     NEC7201 EQU $F70011        <- ODD base: chip sits on D0-D7 / LDS
 *     ch A data    = base+0 = $F70011      (NECWRDA / NECRDDA)
 *     ch B data    = base+2 = $F70013      (NECWRDB / NECRDDB)
 *     ch A control = base+4 = $F70015      (NECWR0A / NECRD0A)
 *     ch B control = base+6 = $F70017      (NECWR0B / NECRD0B)
 *
 * Corroborated by verdos06/_root/NEC7201.EQ (same file, line 12156), which
 * states the layout relatively: CREG/SREG = 0, DREG = -4, i.e. data sits
 * four below control.  Cross-checked against the board's other 8-bit
 * peripheral: the ROM drives the MC6840 PTM at $F70001/$F70003 (F09176
 * PTMInit), also odd, and bit-tests board status at odd $F70019.  The
 * MVME101 map in the Motorola handbook spells the convention out:
 * "On-board I/O Registers (Only odd addresses used)".
 *
 * Two consequences the previous version of this function got wrong, and
 * which made the emulator agree with an unrunnable monitor:
 *
 *   1. Registers are grouped by FUNCTION (both data, then both control),
 *      NOT interleaved per channel.  Old code computed chan = slot/2,
 *      is_data = !(slot&1), which is the interleaved layout.
 *   2. Only ODD addresses decode.  Old code did slot = (addr-base)/2 with
 *      an even base, so integer division silently accepted both lanes.
 *      A byte access to an even address asserts UDS only, this chip never
 *      answers, and the board's bus timeout raises BERR.  Modelling that
 *      strictly is what turns a wrong-lane bug into a visible failure
 *      instead of a silent pass. */
#define SIO_REG_BASE  0xF70011u

/* From Musashi — raise BERR when no device answers the cycle. */
extern void m68k_pulse_bus_error(void);

static int sio_decode(uint32_t addr, int *chan, int *is_data) {
    if (!(addr & 1)) return 0;                        /* even byte: UDS only */
    if (addr < SIO_REG_BASE || addr > SIO_REG_BASE + 6) return 0;
    int slot = (int)((addr - SIO_REG_BASE) / 2);      /* 0..3 */
    *chan    = slot & 1;                              /* 0 = A, 1 = B */
    *is_data = (slot < 2);
    return 1;
}

static void sio_no_dtack(const char *op, uint32_t addr) {
    if (log_fp)
        fprintf(log_fp, "[SIO] BERR: no DTACK on %s at %06X — the uPD7201 "
                        "decodes odd bytes only ($F70011/13/15/17)\n", op, addr);
    if (verbose)
        fprintf(stderr, "[SIO] BERR: no DTACK on %s at %06X\n", op, addr);
    m68k_pulse_bus_error();
}

static uint8_t sio_read(uint32_t addr) {
    int chan, is_data;
    if (!sio_decode(addr, &chan, &is_data)) {
        sio_no_dtack("read", addr);
        return 0xFF;                                  /* floating bus */
    }
    return upd7201_read(&sio_dev, chan, is_data);
}

static void sio_write(uint32_t addr, uint8_t val) {
    int chan, is_data;
    if (!sio_decode(addr, &chan, &is_data)) {
        sio_no_dtack("write", addr);
        return;
    }
    upd7201_write(&sio_dev, chan, is_data, val);
}

/* ============== board status ============== */

/* The VERSAmodule Status Register at F70018-F7001A reports chassis
 * state.  IOChannelDiagnostic (ROM phase 8, F08F70+) walks 4 stages
 * of (bit7 of $1FFF1, bit1 of $1FFF0) ∈ {(0,0),(0,1),(1,0),(1,1)}
 * and expects bit 3 of $F70019 to be 1 in the first three cases and
 * 0 in the fourth — i.e.,
 *
 *      bit3 of board status = NOT (bit7 of VMOD+1  AND  bit1 of VMOD)
 *
 * This matches FPS-100/FPS-164-style chassis-busy semantics where two
 * control lines (a "request enable" + a "go strobe") AND together to
 * assert chassis-busy.  Compare DRIVER.MAC (FPS-100): host raises
 * HDMAST (bit 0 of CTRL) AND a transfer-direction bit, chassis pulls
 * a "ready" line LOW until the transfer completes.  Same shape, two
 * inputs feed an AND-NOT to produce the "ready" line.
 *
 * Per Motorola M68KVM02 manual: VMOD_CTRL at 0x01FFF0 is "Control
 * Register image only — register not directly accessible."  Writes
 * go through chassis-mediated VERSAbus interrupter logic.  The
 * chassis exposes its handshake state via bit 3 of board status. */
static uint32_t board_status_read(uint32_t addr) {
    /* FPS3K_BSTAT19 forces the $F70019 byte.  F08732 does
     * btst #5,$F70019 and skips the ENTIRE self-test suite when the bit
     * is set, so the value here decides whether the diagnostic region
     * F08D00-F09BFF runs at all. */
    /* NOTE: forcing a constant here breaks the dynamic bit relationships
     * the model implements (e.g. bit 3 must track the inverse of VMOD
     * bit 6, which HardwareInit checks directly), so a constant override
     * makes the self-tests fail for the wrong reason.  FPS3K_BSTAT19_CLR
     * clears bits in the *computed* value instead, which is the right way
     * to open the bit-5 self-test gate. */
    int byte_off = addr - BOARD_STATUS_BASE;

    /* F7001B is ILLEGAL per Motorola Figure 2 — handled in bus_read8 */
    if (addr == 0xF7001B) {
        if (log_fp) fprintf(log_fp, "[BOARD_STATUS] illegal access at F7001B\n");
        return 0xFF;
    }

    uint32_t live = board_status;

    if (byte_off == 1) {
        /* F70019 bit 4 — chassis "idle/ready" line.
         *
         * The chassis goes "engaged" (bit 4 = 0) briefly when the SBC
         * writes XLTR_MODE1 = 0x8000 (transition to bit 15 set).
         * After a short window (busy_ticks decrements to 0) the
         * chassis reports "ready" (bit 4 = 1) again.
         *
         * Phase 9 wait at F087C2 reads bit 4 immediately after the
         * write — sees 0 (busy) and advances.  Phase 0x1A00 wait at
         * F08846 reads after the busy window expires — sees 1 (done).
         *
         * Also held LOW while mode1 bit 15 is set (operation outstanding). */
        if ((xltr.mode1 & 0x8000) && xltr.busy_ticks > 0) {
            live &= ~0x00100000;  /* engaged → bit 4 clear */
        } else {
            live |=  0x00100000;  /* ready → bit 4 set */
        }
    }
    if (byte_off == 1) {
        /* F70019 chassis-state bits.  vmod_ctrl is big-endian:
         *   $1FFF0 = HIGH byte, $1FFF1 = LOW byte
         *
         * The chassis publishes inverted images of VMOD_CTRL+1
         * control bits in the low nibble of board status:
         *
         *   bit 1 of $F70019 = NOT (bit 4 of $1FFF1)
         *   bit 2 of $F70019 = NOT (bit 5 of $1FFF1)   [presumed]
         *   bit 3 of $F70019 = NOT (bit 6 of $1FFF1
         *                           OR (bit 7 of $1FFF1
         *                               AND bit 1 of $1FFF0))
         *
         * Phase 0x1100 (PanelBusDiagnostic at F0918C) confirms the
         * bit 4 → bit 1 mapping: F091EC tests bit 1 of $F70019
         * after `bset bit 4 of $1FFF1`, expects 0; F09224 tests bit 1
         * after `bclr bit 4 of $1FFF1`, expects 1.
         *
         * Phase 0x800 (IOChannelDiagnostic at F08F70) confirms the
         * bit 3 NAND-style logic: see truth table comment in CL.
         *
         * The two-input AND form (bit7+bit1) matches FPS-100 driver
         * pattern (DRIVER.MAC: HDMAST + WRTHOST gating). */
        uint8_t byte_1FFF0 = (vmod_ctrl >> 8) & 0xFF;
        uint8_t byte_1FFF1 =  vmod_ctrl       & 0xFF;
        int b0_1FFF1 = (byte_1FFF1 >> 0) & 1;
        int b3_1FFF1 = (byte_1FFF1 >> 3) & 1;
        int b4_1FFF1 = (byte_1FFF1 >> 4) & 1;
        int b5_1FFF1 = (byte_1FFF1 >> 5) & 1;
        int b6_1FFF1 = (byte_1FFF1 >> 6) & 1;
        int b7_1FFF1 = (byte_1FFF1 >> 7) & 1;
        int b0_1FFF0 = (byte_1FFF0 >> 0) & 1;
        int b1_1FFF0 = (byte_1FFF0 >> 1) & 1;

        /* Bit 5 of $F70019: tracks bit 6 of $1FFF1 directly (not inverted).
         * Phase boundary uses bit 5 to signal "end of test" — F088EE
         * checks bit 5 to decide Phase2Init vs loop-back.  After all
         * MainInit phases the SBC writes 0xD0 to $1FFF0 (high byte),
         * which sets bit 6 of $1FFF1 (= 0xD0 high nibble bit 6 = 1)
         * — this is the chassis "tests done, advance" indicator. */
        /* Note: bit 6 of $1FFF1 is the same line that drives the
         * inverted bit 3 of $F70019 — they are the same chassis
         * signal observed at two different bit positions. */
        /* Bit 5 was modelled as tracking bit 6 of $1FFF1.  That cannot be
         * right: MainInit writes $50 to $1FFF0 at F08720 (setting bit 6
         * of $1FFF1), waits for board bit 4, then at F08732 reads bit 5
         * and SKIPS the entire diagnostic suite if it is set.  A direct
         * bit-6 mirror would make the firmware always skip its own
         * self-tests, leaving F08D00-F09BFF permanently dead.
         *
         * Bit 7 fits both uses: the pre-test write $50 has bit 7 clear
         * (run the tests) and the post-test write $D0 at F087AA has bit 7
         * set, which is what F088EE then reads to advance to Phase2Init.
         * FPS3K_BSTAT19_B5 forces the bit for experiments. */
        {
            const char *e = getenv("FPS3K_BSTAT19_B5");
            /* Bit 5 is an INDEPENDENT chassis line, not derived from
             * VMOD at all.  The pattern table at F08E8C settles it: every
             * one of the eight patterns has bit 6 of $1FFF1 clear, but
             * bit 7 varies ($9F, $9A set it).  So a bit-6 mirror blocks
             * the F08732 gate and a bit-7 mirror makes PollBoardStatus
             * abort mid-test on the second pattern.  Neither can be
             * right.  Read as a chassis status line -- 0 = no fault, run
             * diagnostics -- it satisfies both sites. */
            /* bit 5 = bit 7 AND bit 6 of $1FFF1.  Checked against every
             * site that reads it:
             *   $50 (bits 6,4)  gate at F08732      -> 0, run the tests
             *   $9F,$9A         F08E2E patterns     -> 0, no spurious abort
             *   $D0 (bits 7,6,4) checkpoint F087AA  -> 1, advance
             * A single-bit mirror cannot satisfy all three; this can. */
            /* bit 5 selects which test block runs next, so it cannot be a
             * combinational function of VMOD: F087C6/F08854 want it CLEAR
             * after the first checkpoint (run block 2) and SET after the
             * second (run block 3).  The SBC marks each checkpoint by
             * writing $D0 to $1FFF1 (F087AA, F08832), so the chassis
             * tracking those is the behaviour that fits. */
            int b5 = e ? (int)strtoul(e, NULL, 0) & 1 : (vmod_d0_writes >= 2 && !vmod_d0_ack);
            if (b5) live |=  0x00200000;
            else    live &= ~0x00200000;
        }

        /* Bit 1: NOT(bit4) OR (bit5 AND NOT bit0_of_1FFF0).
         * Phase 0x1100 tests bit 4 alone (bit 5 = bit 0 of $1FFF0 = 0):
         *   bit 1 = NOT(bit 4).
         * Phase 0x1200 stage 0 sets bit 5 with bit 4 set, bit 0 = 0:
         *   bit 1 = NOT(1) OR (1 AND 1) = 1.  ✓
         * Phase 0x1200 stage 3 also sets bit 0 of $1FFF0:
         *   bit 1 = NOT(1) OR (1 AND 0) = 0.  ✓
         * Three-input combinational logic — same shape as bit-3 NAND. */
        int b1_drive = (!b4_1FFF1) | (b5_1FFF1 & !b0_1FFF0);
        if (b1_drive) live |= 0x00020000; else live &= ~0x00020000;
        /* Bit 2: NOT(bit5) OR (bit3 AND bit0) of $1FFF1.
         * Phase 0x1400 stage 3 (F09480, chsel 0x1403) verifies the
         * second term: with bit 5 still set from earlier phases, bit 2
         * is clear unless bit 3 AND bit 0 of $1FFF1 are both asserted.
         * Same FPS-100 "primary line + override" pattern as bit 1. */
        int b2_drive = (!b5_1FFF1) | (b3_1FFF1 & b0_1FFF1);
        if (b2_drive) live |= 0x00040000; else live &= ~0x00040000;
        /* Bit 3: NAND-style chassis-busy from bit 6 OR (bit 7 AND bit 1) */
        int chassis_busy = b6_1FFF1 | (b7_1FFF1 & b1_1FFF0);
        if (!chassis_busy) live |= 0x00080000; else live &= ~0x00080000;
    }
    return (live >> ((3 - byte_off) * 8)) & 0xFF;
}
static void board_status_write(uint32_t addr, uint32_t val) {
    int byte_off = addr - BOARD_STATUS_BASE;
    uint32_t mask = 0xFFu << ((3 - byte_off) * 8);
    board_status = (board_status & ~mask) | ((val & 0xFF) << ((3 - byte_off) * 8));
}

/* ============== top-level dispatch ============== */

uint32_t versabus_read(uint32_t addr, int size) {
    uint32_t val = 0;

    if (addr >= APIF_BASE && addr < APIF_END) {
        if (size == 2) val = apif_read(addr);
        else if (size == 1) val = apif_read(addr & ~1u) >> ((addr & 1) ? 0 : 8);
        else { val = (apif_read(addr) << 16) | apif_read(addr+2); }
    }
    else if (addr >= XLTR_BASE && addr < XLTR_END) {
        if (size == 2) val = xltr_read(addr);
        else if (size == 1) val = xltr_read(addr & ~1u) >> ((addr & 1) ? 0 : 8);
        else val = (xltr_read(addr) << 16) | xltr_read(addr+2);
    }
    else if (addr >= MAILBOX_BASE && addr < MAILBOX_END) {
        val = mailbox_read(addr, size);
    }
    else if (addr >= PTM_BASE && addr < PTM_END) {
        val = ptm_read(addr) & 0xFF;
    }
    else if (addr >= UART_BASE && addr < UART_END) {
        val = sio_read(addr) & 0xFF;
    }
    else if (addr >= BOARD_STATUS_BASE && addr < BOARD_STATUS_END) {
        if (size == 1) {
            val = board_status_read(addr);
        } else if (size == 2) {
            val = (board_status_read(addr) << 8) | board_status_read(addr+1);
        } else {
            val = (board_status_read(addr) << 24) | (board_status_read(addr+1) << 16)
                | (board_status_read(addr+2) << 8) | board_status_read(addr+3);
        }
    }
    else if (addr == VMOD_CTRL || addr == VMOD_CTRL+1) {
        if (size == 2 && addr == VMOD_CTRL) {
            val = vmod_ctrl;                       /* full word */
        } else if (size == 1 && addr == VMOD_CTRL) {
            val = (vmod_ctrl >> 8) & 0xFF;         /* high byte */
        } else {
            val = vmod_ctrl & 0xFF;                /* low byte */
        }
    }

    log_access("RD", addr, val, size);
    return val;
}

void versabus_write(uint32_t addr, uint32_t val, int size) {
    log_access("WR", addr, val, size);

    if (addr >= APIF_BASE && addr < APIF_END) {
        if (size == 2) apif_write(addr, val);
        /* byte/long writes to APIF: split */
    }
    else if (addr >= XLTR_BASE && addr < XLTR_END) {
        if (size == 2) xltr_write(addr, val);
    }
    else if (addr >= MAILBOX_BASE && addr < MAILBOX_END) {
        mailbox_write(addr, val, size);
    }
    else if (addr >= PTM_BASE && addr < PTM_END) {
        ptm_write(addr, val & 0xFF);
    }
    else if (addr >= UART_BASE && addr < UART_END) {
        sio_write(addr, val & 0xFF);
    }
    else if (addr >= BOARD_STATUS_BASE && addr < BOARD_STATUS_END) {
        board_status_write(addr, val);
    }
    else if (addr == VMOD_CTRL || addr == VMOD_CTRL+1) {
        uint8_t prev_lo = vmod_ctrl & 0xFF;        /* byte at $1FFF1 */
        if (addr == VMOD_CTRL && size == 2) {
            vmod_ctrl = val & 0xFFFF;
        } else if (addr == VMOD_CTRL) {
            vmod_ctrl = (vmod_ctrl & 0x00FF) | ((val & 0xFF) << 8);
        } else {
            vmod_ctrl = (vmod_ctrl & 0xFF00) | (val & 0xFF);
        }
        uint8_t new_lo = vmod_ctrl & 0xFF;
        if (new_lo == 0xD0 && prev_lo != 0xD0) { vmod_d0_writes++; vmod_d0_ack = 0; }
        /* The checkpoint indication is a pulse, not a level.  Block 3
         * opens with clr.w (a5) at F0885A, and if bit 5 stayed latched
         * past that every PollBoardStatus in block 3 would take its
         * bra F088F4 abort (bit 4 set + bit 5 set) and cut the block
         * short -- which is exactly what happened.  Any non-$D0 write to
         * $1FFF1 consumes the indication. */
        else if (new_lo != 0xD0 && vmod_d0_writes >= 2) vmod_d0_ack = 1;
        /* nothing */
        /* Phase 0x1300 (F09338, PanelBusInterruptDiagnostic): writing
         * any of bits 0..2 of $1FFF1 with bit 7 set triggers a level-4
         * vectored IRQ at vector $50 (handler $140 = F093BE).
         * Edge-triggered on transitions of bits 0..2.  This matches
         * FPS-100 driver where setting CTRL register bits arms the
         * interrupter and the chassis pulses an interrupt to the SBC. */
        if ((new_lo & 0x80) && ((new_lo ^ prev_lo) & 0x07) && (new_lo & 0x07)) {
            /* Vector dispatch by bit 3 of $1FFF1.  Phase 0x1400
             * (F093CE) tests both code paths:
             *   stage 1 (chsel 0x1401): bit 3=0 → expects vector 0x50
             *     (handler F094CC sets d2 bit 0 only)
             *   stage 2 (chsel 0x1402): bit 3=1 → expects vector 0x52
             *     (handler F094E4 sets d2 bit 1 directly)
             * The chassis routes the panel-bus interrupt to one of two
             * vectors based on whether bit 3 is asserted. */
            chassis_irq_vector = (new_lo & 0x08) ? 0x52 : 0x50;
            chassis_irq_pending = 1;
            m68k_set_irq(chassis_irq_level);
        }
    }
}

/* ============== panel-status response path ==============
 *
 * The mechanism the firmware has been waiting on.  Vector $41 (BIM0 ch0,
 * level 6) reaches F04930, which does:
 *
 *     move.w  $200(a0),d0        read XLTR_MODE0
 *     bclr.b  #$b,d0             clear bit 11
 *     move.w  d0,$e86.l          keep it as g__channel_mode
 *     bset.b  #$a,d0             set bit 10
 *     move.w  d0,$200(a0)        write back: acknowledge
 *     andi.w  #$1f,d0            5-bit response code
 *     cmpi.w  #$0 / blt          reject below 0
 *     cmpi.w  #$14 / bgt         reject above $14
 *     cmpi.w  #$14 / beq         $14 dispatches to ChannelConfigDispatch
 *
 * So the chassis returns a 5-bit code in XLTR_MODE0 bits 0-4 and raises
 * BIM0 ch0.  Bit 11 reads as the "response valid" flag the handler
 * clears; bit 10 is the acknowledgement it sets on the way out.  Codes
 * run 0..$14, and $14 is the D2_FIN finalize code that
 * PanelStatusDispatchTable documents.
 *
 * Everything above is read off the disassembly.  What the individual
 * codes below $14 mean, and which one belongs to which panel command, is
 * NOT established: this returns a single benign code so the path can be
 * exercised at all. */

static int      panel_resp_armed;      /* response scheduled */
static uint32_t panel_resp_delay;      /* cycles until it lands */
static uint8_t  panel_resp_code;

/* FPS3K_SEQ="code:chsel,code:chsel,..." (hex) scripts the chassis side of
 * the transfer-setup protocol.  Each panel response delivers the next
 * code, and CHANNEL_SELECT reads back that step's value, which is how
 * F04CF2/F04D20 load the 32-bit destination address and word count a
 * half at a time (bit 6 of the code picks the half). */
#define SEQ_MAX 32
static struct { uint8_t code; uint16_t chsel; } seq[SEQ_MAX];
static int seq_len = -1, seq_next = 0, seq_cur = -1;

static void seq_init(void) {
    if (seq_len >= 0) return;
    seq_len = 0;
    const char *e = getenv("FPS3K_SEQ");
    if (!e) return;
    char buf[512];
    snprintf(buf, sizeof buf, "%s", e);
    for (char *t = strtok(buf, ","); t && seq_len < SEQ_MAX; t = strtok(NULL, ",")) {
        char *colon = strchr(t, ':');
        if (!colon) continue;
        *colon = 0;
        seq[seq_len].code  = (uint8_t)strtoul(t, NULL, 16);
        seq[seq_len].chsel = (uint16_t)strtoul(colon + 1, NULL, 16);
        seq_len++;
    }
}

/* Hand out the next scripted code and make it the one CHANNEL_SELECT
 * reports, so the code and its argument stay paired. */
static int versabus_seq_take(uint8_t *code) {
    seq_init();
    if (seq_next >= seq_len) return 0;
    seq_cur = seq_next++;
    *code = seq[seq_cur].code;
    return 1;
}

int versabus_seq_chsel(uint16_t *out) {
    seq_init();
    if (seq_cur < 0 || seq_cur >= seq_len) return 0;
    *out = seq[seq_cur].chsel;
    return 1;
}

void versabus_arm_panel_response(uint8_t code, uint32_t delay_cycles) {
    panel_resp_code  = code & MODE0_RESP_MASK;
    panel_resp_delay = delay_cycles;
    panel_resp_armed = 1;
}

static void panel_resp_tick(uint32_t cycles) {
    /* The handler acknowledges by setting bit 10.  Drop the request and
     * clear both flags so the next command starts clean. */
    if ((xltr.mode0 & MODE0_RESP_ACK) && !panel_resp_armed) {
        xltr.mode0 &= ~(MODE0_RESP_ACK | MODE0_RESP_VALID);
        xltr.raw[(XLTR_MODE0 - XLTR_BASE) / 2] = xltr.mode0;
        versabus_bim_clear(0, 0);
        if (log_fp) fprintf(log_fp, "[PANEL] response acknowledged\n");
        /* A scripted chassis drives its OWN schedule.  The SBC is a bus
         * slave here -- the chassis masters the transfers -- so there is
         * no CPU-side "command complete" to wait for, and two attempts to
         * find one (PC == F04736, then the $FF000E write) both failed.
         * Instead space the commands far enough apart that the SBC has
         * finished; FPS3K_SEQGAP sets the spacing in cycles. */
        seq_init();
        if (seq_next < seq_len) seq_gap_left = seq_gap_cycles();
    }
    if (!panel_resp_armed) return;
    if (panel_resp_delay > cycles) { panel_resp_delay -= cycles; return; }

    {   /* A scripted sequence overrides the fixed response code. */
        uint8_t sc;
        if (versabus_seq_take(&sc)) panel_resp_code = sc;
    }
    xltr.mode0 = (uint16_t)((xltr.mode0 & ~MODE0_RESP_MASK)
                            | panel_resp_code | MODE0_RESP_VALID);
    xltr.raw[(XLTR_MODE0 - XLTR_BASE) / 2] = xltr.mode0;
    panel_resp_armed = 0;
    int u = 0, c = 0;
    if (getenv("FPS3K_RESP_INSVC") && bim_in_service_unit >= 0) {
        u = bim_in_service_unit; c = bim_in_service_ch;
    }
    int lvl = versabus_bim_assert(u, c);
    if (log_fp)
        fprintf(log_fp, "[PANEL] response code $%02X in MODE0, BIM%d ch%d -> level %d\n",
                panel_resp_code, u, c, lvl);
}

/* Experiment hook: FPS3K_INJECT=<code> fires one panel-status response on
 * BIM0 ch0 (TCBRDHC's channel, level 6) once the machine is idle, so the
 * task-context dispatch at F04930 can be driven directly and the 0..$14
 * code space swept.  The host byte path does not read the code, so this
 * is the only way to see what the codes mean. */
static uint64_t inject_countdown;
static int      inject_done;

void versabus_tick(uint32_t cycles) {
    mc6840_tick(&ptm_dev, cycles);
    upd7201_tick(&sio_dev, cycles);
    if (xltr.busy_ticks > cycles) xltr.busy_ticks -= cycles;
    else                          xltr.busy_ticks = 0;
    panel_resp_tick(cycles);

    /* A scripted chassis initiates.  TCBRDHC parks at F04736 waiting to
     * be told what to do, so nothing ever writes CHANNEL_SELECT to arm
     * the first response -- the sequence has to start itself once BIM0
     * ch0 is enabled and the RTOS is up. */
    {
        static uint64_t seq_start;
        seq_init();
        if (seq_len > 0 && !panel_resp_armed && seq_next < seq_len) {
            if (seq_next == 0) {
                if (seq_start < 40000000ull) seq_start += cycles;
                else if (versabus_bim_enabled(0, 0))
                    versabus_arm_panel_response(0, 400);
            } else if (seq_gap_left > cycles) {
                seq_gap_left -= cycles;
            } else if (seq_gap_left) {
                seq_gap_left = 0;
                versabus_arm_panel_response(0, 400);
            }
        }
    }

    if (!inject_done) {
        const char *e = getenv("FPS3K_INJECT");
        if (e) {
            if (inject_countdown < 20000000ull) { inject_countdown += cycles; }
            else if (versabus_bim_enabled(0, 0)) {
                uint8_t code = (uint8_t)strtoul(e, NULL, 0) & MODE0_RESP_MASK;
                xltr.mode0 = (uint16_t)((xltr.mode0 & ~MODE0_RESP_MASK)
                                        | code | MODE0_RESP_VALID);
                xltr.raw[(XLTR_MODE0 - XLTR_BASE) / 2] = xltr.mode0;
                int lvl = versabus_bim_assert(0, 0);
                if (log_fp)
                    fprintf(log_fp, "[INJECT] code $%02X on BIM0 ch0 -> level %d\n", code, lvl);
                inject_done = 1;
            }
        } else inject_done = 1;
    }
}

int versabus_ptm_irq_pending(void) {
    return mc6840_irq_pending(&ptm_dev);
}

int versabus_chassis_irq_pending(void) {
    return chassis_irq_pending;
}
int versabus_chassis_irq_ack(void) {
    int v = chassis_irq_vector;
    chassis_irq_pending = 0;
    return v;
}

unsigned versabus_xltr_data_hi(void) {
    return xltr.data_hi;
}
unsigned versabus_xltr_data_lo(void) {
    return xltr.data_lo;
}

/* PTM IRQ propagation gate: bit 7 of $1FFF1 (VMOD_CTRL+1).
 * Phase 9 (F0905A in ROM) sets bit 7 before arming the PTM IRQ
 * test, and clears it before exiting.  Treating this bit as the
 * chassis-level PTM IRQ enable matches what the ROM assumes. */
int versabus_ptm_irq_gated(void) {
    if (!mc6840_irq_pending(&ptm_dev)) return 0;
    uint8_t byte_1FFF1 = vmod_ctrl & 0xFF;
    return (byte_1FFF1 & 0x80) ? 1 : 0;
}

void versabus_dump_state(FILE *out) {
    fprintf(out, "AP I/F: cmd_status=%04X last_opcode=%04X cmd_count=%lu\n",
            apif.cmd_status, apif.last_opcode, (unsigned long)apif.cmd_count);
    fprintf(out, "        ch_data: [%04X,%04X] [%04X,%04X] [%04X,%04X] [%04X,%04X]\n",
            apif.ch_data[0][0], apif.ch_data[0][1],
            apif.ch_data[1][0], apif.ch_data[1][1],
            apif.ch_data[2][0], apif.ch_data[2][1],
            apif.ch_data[3][0], apif.ch_data[3][1]);
    fprintf(out, "XLTR  : mode0=%04X mode1=%04X mode2=%04X chsel=%04X\n",
            xltr.mode0, xltr.mode1, xltr.mode2, xltr.channel_select);
    fprintf(out, "        data_lo=%04X data_hi=%04X status_irq=%04X mask=%04X\n",
            xltr.data_lo, xltr.data_hi, xltr.status_irq, xltr.irq_mask);
    fprintf(out, "        ch_cfg: %04X %04X %04X %04X\n",
            xltr.ch_config[0], xltr.ch_config[1],
            xltr.ch_config[2], xltr.ch_config[3]);
    fprintf(out, "MAILBOX: host=%08X reply=%08X\n",
            mailbox.host_status, mailbox.sbc_reply);
    fprintf(out, "BOARD : status=%08X  VMOD: ctrl=%04X\n",
            board_status, vmod_ctrl);
}
