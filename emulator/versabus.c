/* versabus.c — implementation of all SBC peripheral stubs + access logger. */

#include "versabus.h"
#include "mc6840.h"
#include "upd7201.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

/* VERSAmodule control register */
static uint16_t vmod_ctrl;

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
static const char *panel_cmd_name(uint16_t cmd) {
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

    /* For panel-cmd-related writes, decode the panel cmd */
    if ((addr == APIF_CMD_ARG_HI ||
         addr == APIF_CMD_ARG_LO ||
         addr == XLTR_CHANNEL_SELECT) && size == 2) {
        const char *pn = panel_cmd_name((uint16_t)val);
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
    memset(&mailbox, 0, sizeof mailbox);
    mc6840_init(&ptm_dev, log_fp);
    upd7201_init(&sio_dev, log_fp);
    /* Default board-status: bit 4 (offset F70019) = 1 (ready),
     * bit 5 = 0 (no error). The MainInit polls F70019 bit 4 in a
     * tight loop; if bit 5 is set it takes the error path. */
    board_status = 0x00100000;  /* byte at F70019 = 0x10 → bit 4 set, bit 5 clear */
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

static uint16_t apif_read(uint32_t addr) {
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
    if (addr == APIF_CH1_DATA_A || addr == APIF_CH1_DATA_B) {
        int bx = (addr - APIF_CH1_DATA_A) / 6;
        return apif.ch_data[0][bx & 1];
    }
    /* Per-channel data ports */
    for (int c = 0; c < 4; c++) {
        uint32_t base = APIF_CH1_DATA_A + c * 0x20;
        if (addr == base) return apif.ch_data[c][0];
        if (addr == base + 6) return apif.ch_data[c][1];
    }
    return 0;
}

static void apif_write(uint32_t addr, uint16_t val) {
    if (addr == APIF_CMD_STATUS || addr == APIF_CMD_STATUS+1) {
        apif.last_opcode = val;
        apif.cmd_count++;
        /* On REQUEST-TRANSFER (0x8004) or CONTINUE-TRANSFER (0x8005),
         * mark not-ready momentarily so the poll loop sees one not-ready
         * before we set ready. */
        apif.cmd_status &= ~((1u << 14) | (1u << 13));  /* clear ready+error */
        return;
    }
    if (addr == APIF_CMD_ARG_LO) { apif.cmd_arg_lo = val; return; }
    if (addr == APIF_CMD_ARG_HI) { apif.cmd_arg_hi = val; return; }
    /* Per-channel data ports — writes ignored (these are read-only status from AP) */
}

/* ============== XLTR handler ============== */

static uint16_t xltr_read(uint32_t addr) {
    switch (addr) {
        case XLTR_MODE0:          return xltr.mode0;
        case XLTR_MODE1:          return xltr.mode1;
        case XLTR_CHANNEL_SELECT: return xltr.channel_select;
        case XLTR_COUNTER:        return xltr.counter;
        case XLTR_MODE2:          return xltr.mode2;
        case XLTR_DATA_LO:        return xltr.data_lo;
        case XLTR_DATA_HI:        return xltr.data_hi;
        case XLTR_STATUS_IRQ:
            /* If 0x400 was written (arm), automatically signal completion
             * by setting bit 15 (ready/done) on the next read. */
            if (xltr.arm_pending) {
                xltr.status_irq |= (1u << 15);
                xltr.arm_pending = 0;
            }
            return xltr.status_irq;
        case XLTR_IRQ_MASK:       return xltr.irq_mask;
        case XLTR_CH1_CONFIG:     return xltr.ch_config[0];
        case XLTR_CH2_CONFIG:     return xltr.ch_config[1];
        case XLTR_CH3_CONFIG:     return xltr.ch_config[2];
        case XLTR_CH4_CONFIG:     return xltr.ch_config[3];
    }
    return 0;
}

static void xltr_write(uint32_t addr, uint16_t val) {
    switch (addr) {
        case XLTR_MODE0:          xltr.mode0 = val; return;
        case XLTR_MODE1:          xltr.mode1 = val; return;
        case XLTR_CHANNEL_SELECT: xltr.channel_select = val; return;
        case XLTR_COUNTER:        xltr.counter = val; return;
        case XLTR_MODE2:          xltr.mode2 = val; return;
        case XLTR_DATA_LO:        xltr.data_lo = val; return;
        case XLTR_DATA_HI:        xltr.data_hi = val; return;
        case XLTR_STATUS_IRQ:
            if (val == 0x0000) {
                /* Clear */
                xltr.status_irq = 0;
                xltr.arm_pending = 0;
            } else if (val == 0x0400) {
                /* Arm — next read returns ready/done */
                xltr.arm_pending = 1;
            } else {
                xltr.status_irq = val;
            }
            return;
        case XLTR_IRQ_MASK:       xltr.irq_mask = val; return;
        case XLTR_CH1_CONFIG:     xltr.ch_config[0] = val; return;
        case XLTR_CH2_CONFIG:     xltr.ch_config[1] = val; return;
        case XLTR_CH3_CONFIG:     xltr.ch_config[2] = val; return;
        case XLTR_CH4_CONFIG:     xltr.ch_config[3] = val; return;
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

static uint8_t sio_read(uint32_t addr) {
    /* 4 byte slots in 8-byte region: A-data, A-ctrl, B-data, B-ctrl
     * mapped at 0xF70010, 0xF70012, 0xF70014, 0xF70016 (word-aligned).
     * The SBC uses word reads so each register is one 16-bit slot. */
    int slot = (addr - UART_BASE) / 2;        /* 0..3 */
    int chan = slot / 2;                       /* 0..1 */
    int is_data = !(slot & 1);
    return upd7201_read(&sio_dev, chan, is_data);
}

static void sio_write(uint32_t addr, uint8_t val) {
    int slot = (addr - UART_BASE) / 2;
    int chan = slot / 2;
    int is_data = !(slot & 1);
    upd7201_write(&sio_dev, chan, is_data, val);
}

/* ============== board status ============== */

static uint32_t board_status_read(uint32_t addr) {
    int byte_off = addr - BOARD_STATUS_BASE;
    return (board_status >> ((3 - byte_off) * 8)) & 0xFF;
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
        val = board_status_read(addr);
    }
    else if (addr == VMOD_CTRL || addr == VMOD_CTRL+1) {
        val = (addr == VMOD_CTRL) ? (vmod_ctrl >> 8) : (vmod_ctrl & 0xFF);
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
        if (addr == VMOD_CTRL) vmod_ctrl = (vmod_ctrl & 0xFF) | ((val & 0xFF) << 8);
        else                   vmod_ctrl = (vmod_ctrl & 0xFF00) | (val & 0xFF);
    }
}

void versabus_tick(uint32_t cycles) {
    mc6840_tick(&ptm_dev, cycles);
    upd7201_tick(&sio_dev, cycles);
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
