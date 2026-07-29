/* fps3k_sbc.c — FPS-3000 SBC emulator (M68KVM02-3 VERSAmodule monoboard)
 *
 * Models:
 *   - MC68000 @ 8 MHz (Musashi core)
 *   - 128 KB RAM at $000000-$01FFFF, supervisor stack at $01FFD0
 *   - 64 KB ROM at $F00000-$F0FFFF (FPS-3000 firmware)
 *   - Reset overlay: ROM aliased at $000000 for first fetches (until VBR remap)
 *   - MC6840 PTM at $F70001-$F7000F (odd-byte MOVEP)  [stub]
 *   - NEC µPD7201 dual UART at $F70010-$F70017       [chan A console]
 *   - Board status/control reg at $F70018-$F7001A    [stub]
 *   - VERSAmodule control reg at $01FFF0             [stub]
 *
 *   - AP I/F  at $FF0000-$FF00FF (VersaBUS chassis side)
 *   - XLTR    at $FF0200-$FF025F
 *   - Mailbox at $700000-$700020
 *
 * The chassis-side stubs (versabus.c) satisfy the ROM's probes — bit 14
 * (ready) of FF0000 auto-sets after opcode writes, XLTR_STATUS_IRQ
 * auto-sets bit 15 after a 0x400 arm — so the panel-cmd send/wait loops
 * terminate, the boot diagnostics complete, and the RTOS comes up.
 *
 * Usage:
 *   fps3k_sbc -rom <firmware.bin> [opts]
 *   Options:
 *     -trace <file>      CPU PC trace (one address per line)
 *     -bus <file>        Detailed VersaBUS access log
 *     -cycles <n>        Run this many cycles then stop (default: forever)
 *     -breakpc <addr>    Halt when PC hits this address (octal/hex/decimal)
 *     -dump <file>       Write final SBC RAM contents to file
 *     -v                 Verbose
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>
#include <unistd.h>
#include <signal.h>
#include "musashi/m68k.h"
#include "versabus.h"
#include "host_sim.h"

static host_sim_t host_sim;
static void on_apif_consumed(void *ctx) { host_sim_byte_consumed((host_sim_t *)ctx); }

#define RAM_SIZE  (128 * 1024)        /* 0x000000-0x01FFFF */
#define ROM_SIZE  (64  * 1024)        /* 0xF00000-0xF0FFFF */
#define ROM_BASE  0xF00000

static uint8_t  ram[RAM_SIZE];

/* Exposed so versabus.c can apply its boot-complete gate (vector $128). */
uint8_t *versabus_ram_ptr(void) { return ram; }
/* Written-ness tracking.  FPS3K_UNINIT logs every read of a RAM byte the
 * CPU has never written -- the complete set of values this firmware
 * consumes but does not produce, which is exactly what a chassis model
 * owes it.  $105E, $10AA and the CHANNEL_SELECT $28 readback were each
 * found by hand; this finds the rest. */
static uint8_t  ram_written[RAM_SIZE];
static FILE    *uninit_fp = NULL;
uint8_t *host_sim_get_ram_ptr(void) { return ram; }

/* Chassis-side memory backing for $400000-$4FFFFF (1 MB).  When
 * XLTR_DATA_HI selects an active page (e.g. 0, 0x40), reads and
 * writes round-trip to this buffer.  Phase 0x1900 (F09776) writes
 * a long pattern and reads it back; later phases use it for the
 * panel-bus DMA path.  Sized small (1 MB) since the test only
 * touches the first few words. */
#define CHASSIS_MEM_BASE  0x400000
#define CHASSIS_MEM_SIZE  (1u << 20)        /* 1 MB */
static uint8_t  chassis_mem[CHASSIS_MEM_SIZE];
static uint64_t chassis_mem_reads, chassis_mem_writes, chassis_mem_berrs;
static uint8_t  rom[ROM_SIZE];

static int      reset_overlay = 1;     /* ROM aliased at 0x000000 until first stack-pop */
static int      overlay_fetches_remaining = 8;   /* serve initial vectors from ROM */
static int      verbose = 0;
static FILE    *trace_fp = NULL;
static FILE    *bus_fp   = NULL;
static uint32_t breakpc  = 0xFFFFFFFFu;
static volatile int stop_now = 0;

static uint64_t total_cycles = 0;
static uint64_t total_instr  = 0;

/* ============== bus ============== */

/* FPS3K_DMA10AA=<hex> makes reads of $10A8-$10AB return that longword,
 * modelling the chassis writing it as a VersaBus master.  TCBIO1I
 * dispatches on $10AA at F05E12 and no executed code ever stores a
 * nonzero value there, so if the transfer completes under this
 * injection, off-board delivery is the mechanism. */
/* FPS3K_POKE="addr=word,addr=word,..." (hex) makes reads of those RAM
 * words return the given value, modelling values the chassis supplies
 * that this ROM never writes -- $105E (channel count) and $10AA are both
 * in that class. */
static int poke_lookup(uint32_t a, uint8_t *out) {
    const char *e = getenv("FPS3K_POKE");
    if (!e) return 0;
    char buf[512];
    snprintf(buf, sizeof buf, "%s", e);
    for (char *t = strtok(buf, ","); t; t = strtok(NULL, ",")) {
        char *eq = strchr(t, '=');
        if (!eq) continue;
        *eq = 0;
        uint32_t base = (uint32_t)strtoul(t, NULL, 16);
        uint32_t val  = (uint32_t)strtoul(eq + 1, NULL, 16);
        if (a == base)     { *out = (uint8_t)(val >> 8); return 1; }
        if (a == base + 1) { *out = (uint8_t)(val & 0xFF); return 1; }
    }
    return 0;
}

/* Only inject once the RTOS is up.  $10AA lies in the RAM the power-on
 * diagnostics walk, so a location that reads back a constant regardless of
 * what was written fails a pattern test -- with the injection active from
 * reset the machine hangs in the diagnostics at F09904 and never reaches
 * the scheduler.  The boot-complete gate is the same one host_sim uses:
 * vector $128 holding F05DD6 means TCBIO1I has started. */
static int dma10aa_active(uint32_t *out) {
    const char *e = getenv("FPS3K_DMA10AA");
    if (!e) return 0;
    uint32_t v128 = ((uint32_t)ram[0x128] << 24) | ((uint32_t)ram[0x129] << 16)
                  | ((uint32_t)ram[0x12A] << 8)  |  (uint32_t)ram[0x12B];
    /* FPS3K_DMA10AA_FROM_RESET=1 reproduces the pre-fix behaviour, for
     * checking older results against.  It hangs the diagnostics. */
    if (v128 != 0xF05DD6 && !getenv("FPS3K_DMA10AA_FROM_RESET")) return 0;
    *out = (uint32_t)strtoul(e, NULL, 16);
    return 1;
}

static uint8_t bus_read8(uint32_t a) {
    {
        uint8_t pv;
        if (a < 0x20000 && poke_lookup(a, &pv)) return pv;
    }
    {
        uint32_t dv;
        if (a >= 0x10AA && a <= 0x10AD && dma10aa_active(&dv))
            return (uint8_t)(dv >> (8 * (3 - (a - 0x10AA))));
    }
    a &= 0xFFFFFFu;

    /* Reset overlay: ROM aliased at 0x000000 for the first 8 byte-fetches
     * (4-byte SP + 4-byte PC at reset). After that, low memory is normal RAM. */
    if (reset_overlay && a < ROM_SIZE) {
        if (overlay_fetches_remaining > 0) {
            overlay_fetches_remaining--;
            if (overlay_fetches_remaining == 0) {
                if (verbose) fprintf(stderr, "[bus] reset-overlay disabled\n");
                reset_overlay = 0;
            }
            return rom[a];
        }
        reset_overlay = 0;
    }

    /* AP I/F BERRs when chassis DMA is in progress.  Phase 0x1A00
     * (F09832) verifies: arm XLTR via STATUS_IRQ=0x400, then
     * intentionally read $FF000E to trigger BERR. */
    if (a >= 0xFF0000 && a < 0xFF0100 && versabus_apif_dma_busy()) {
        if (verbose) fprintf(stderr, "[bus] R8 BERR (DMA busy) %06X\n", a);
        m68k_pulse_bus_error();
        return 0xFF;
    }

    /* Device check FIRST — VMOD_CTRL at $1FFF0 lives inside the RAM
     * range but is a device, so it must intercept before the RAM read. */
    if (versabus_is_device(a)) {
        if (getenv("FPS3K_PCLOG") && a >= 0xFF0000 && a <= 0xFF00FF)
            fprintf(stderr, "[PCLOG] rd %06X from PC=%06X\n",
                    a, m68k_get_reg(NULL, M68K_REG_PPC));
        return versabus_read(a, 1) & 0xFF;
    }

    if (a < RAM_SIZE) {
        if (uninit_fp && !ram_written[a])
            fprintf(uninit_fp, "%05X %06X\n", a, m68k_get_reg(NULL, M68K_REG_PPC));
        return ram[a];
    }
    if (a >= ROM_BASE && a < ROM_BASE + ROM_SIZE) return rom[a - ROM_BASE];

    /* Chassis-routed memory: backed by chassis_mem when not BERR'd.
     * BERR is gated by XLTR_DATA_HI bit 5 (see below). */
    if (a >= CHASSIS_MEM_BASE && a < CHASSIS_MEM_BASE + CHASSIS_MEM_SIZE) {
        if (!(versabus_xltr_data_hi() & 0x20)) {
            chassis_mem_reads++;
            /* FPS3K_LOGCHASSIS=1 logs this window.  It is intercepted here,
             * BEFORE versabus_read(), so log_access() never sees it -- which
             * is why every per-phase analysis built from the bus log showed
             * phases $20-$29 touching nothing but board status, and why
             * phase $29 was mislabelled a timed test when it walks 131k
             * chassis addresses.  Off by default: a full boot emits ~262k
             * lines. */
            if (getenv("FPS3K_LOGCHASSIS"))
                fprintf(stderr, "[CHASSIS-MEM ] RD 1-byte %06X = %02X @%06X\n",
                        a, chassis_mem[a - CHASSIS_MEM_BASE],
                        m68k_get_reg(NULL, M68K_REG_PPC));
            return chassis_mem[a - CHASSIS_MEM_BASE];
        }
        chassis_mem_berrs++;
    }

    /* Per M68KVM02 manual Figure 2, anything outside the populated
     * regions bus-errors:
     *   - $020000-$EFFFFF: VERSAbus long I/O (no devices in our chassis
     *     except $700000-$70003F mailbox)
     *   - $F10000-$F6FFFF: VERSAbus (long I/O extension)
     *   - $F80000-$F81FFF: I/O Channel (no boards)
     *   - $F82000-$FEFFFF: VERSAbus short I/O (off-board peripherals)
     *   - $F7001B: illegal high byte of status reg
     *
     * The two MemBusProbe walks (chsel 0x700 and 0x1000) expect to hit
     * BERR somewhere in these ranges. */
    int berr = 0;
    if (a == 0xF7001B) berr = 1;
    else if (a >= 0xF80000 && a < 0xF82000) berr = 1;
    else if (a >= 0xF10000 && a < 0xF70000) berr = 1;
    else if (a >= 0x020000 && a < 0xF00000) {
        /* Long I/O: mailbox at $700000 is always populated.  The
         * $400000-$4FFFFF chassis-routed window is gated by
         * XLTR_DATA_HI: phase 0x1700 (F09602) verifies that with
         * DATA_HI=0 the address routes to a chassis device (no BERR),
         * and with DATA_HI != 0 the chassis denies access (BERR). */
        if (a >= MAILBOX_BASE && a < MAILBOX_END) {
            /* mailbox: never BERR */
        } else if (a >= 0x400000 && a < 0x500000) {
            /* Chassis-routed page: bit 5 of XLTR_DATA_HI selects an
             * unpopulated page (BERR).  Other DATA_HI values (0, 0x40,
             * etc.) route to populated chassis memory (no BERR).
             * Established by phase 0x1700 (BERR on DATA_HI=0x20) and
             * phase 0x1800 (no BERR on DATA_HI=0 or 0x40). */
            berr = (versabus_xltr_data_hi() & 0x20) ? 1 : 0;
        } else {
            berr = 1;
        }
    }
    if (berr) {
        if (verbose) fprintf(stderr, "[bus] R8  bus-error %06X\n", a);
        m68k_pulse_bus_error();
        return 0xFF;
    }

    if (verbose) fprintf(stderr, "[bus] R8  unmapped %06X\n", a);
    return 0xFF;
}

static void bus_write8(uint32_t a, uint8_t v) {
    a &= 0xFFFFFFu;
    /* Any write establishes DRAM parity, including a write of zero.  This
     * used to be gated on v != 0, which made every stack pop of a zero byte
     * look like a read of untouched memory: it reported 302,649 such reads,
     * 253,883 of them in the stack page $1Fxxx alone, and the top offender
     * was a movem.l (a7)+ pop.  The gate is the bug, not the firmware. */
    if (a < RAM_SIZE) ram_written[a] = 1;
    /* FPS3K_VECWATCH: report writes to the exception vector table.  It used
     * to watch only $128-$12B, TCBIO1I's vector, because that is the one a
     * re-entrant ISR once corrupted -- producing an instruction fetch from
     * $FF0048 that was misread as a data access and caused a retracted
     * finding.  Watching the WHOLE table turns that from a one-off diagnosis
     * into a standing check: any write here after the RTOS is up is
     * suspicious, and a run that reports none cannot be producing
     * vector-corruption artifacts.  Set FPS3K_VECWATCH=post to report only
     * writes after TCBIO1I's vector is installed. */
    if (a < 0x400) {
        const char *vw = getenv("FPS3K_VECWATCH");
        if (vw) {
            int post = (vw[0] == 'p');
            uint32_t v128 = ((uint32_t)ram[0x128] << 24) | ((uint32_t)ram[0x129] << 16)
                          | ((uint32_t)ram[0x12A] << 8)  |  (uint32_t)ram[0x12B];
            if (!post || v128 == 0xF05DD6)
                fprintf(stderr, "[VECWATCH] write %06X <- %02X from PC=%06X\n",
                        a, v, m68k_get_reg(NULL, M68K_REG_PPC));
        }
    }

    /* FPS3K_RAMWATCH=<hex addr> logs every CPU write to that longword.
     * $10AA is read by TCBIO1I at F05E12 and — per a full-ROM search —
     * written nowhere, which is the evidence for the chassis DMAing it
     * in as a bus master.  This watchpoint tests that from the other
     * side: if the CPU never writes it either, the value can only come
     * from off-board. */
    {
        const char *rw = getenv("FPS3K_RAMWATCH");
        if (rw) {
            uint32_t w = (uint32_t)strtoul(rw, NULL, 16);
            if (a >= w && a <= w + 3)
                fprintf(stderr, "[RAMWATCH] write %06X <- %02X from PC=%06X\n",
                        a, v, m68k_get_reg(NULL, M68K_REG_PPC));
        }
    }

    /* Device check FIRST — VMOD_CTRL at $1FFF0 lives inside RAM range. */
    if (versabus_is_device(a)) {
        versabus_write(a, v, 1);
        return;
    }
    if (a < RAM_SIZE) {
        ram[a] = v;
        return;
    }
    if (a >= ROM_BASE && a < ROM_BASE + ROM_SIZE) {
        if (verbose) fprintf(stderr, "[bus] W8 ROM-write %06X <- %02X (ignored)\n", a, v);
        return;
    }

    /* Chassis memory: write through when not BERR'd */
    if (a >= CHASSIS_MEM_BASE && a < CHASSIS_MEM_BASE + CHASSIS_MEM_SIZE) {
        if (!(versabus_xltr_data_hi() & 0x20)) {
            chassis_mem_writes++; chassis_mem[a - CHASSIS_MEM_BASE] = v;
            if (getenv("FPS3K_LOGCHASSIS"))
                fprintf(stderr, "[CHASSIS-MEM ] WR 1-byte %06X = %02X @%06X\n",
                        a, v, m68k_get_reg(NULL, M68K_REG_PPC));
            return;
        }
    }

    /* BERR for unmapped/denied addresses (mirror of bus_read8 logic) */
    int berr = 0;
    if (a == 0xF7001B) berr = 1;
    else if (a >= 0xF80000 && a < 0xF82000) berr = 1;
    else if (a >= 0xF10000 && a < 0xF70000) berr = 1;
    else if (a >= 0x020000 && a < 0xF00000) {
        if (a >= MAILBOX_BASE && a < MAILBOX_END) {
            /* mailbox: never BERR */
        } else if (a >= 0x400000 && a < 0x500000) {
            berr = (versabus_xltr_data_hi() & 0x20) ? 1 : 0;
        } else {
            berr = 1;
        }
    }
    if (berr) {
        if (verbose) fprintf(stderr, "[bus] W8 bus-error %06X <- %02X\n", a, v);
        m68k_pulse_bus_error();
        return;
    }
    if (verbose) fprintf(stderr, "[bus] W8  unmapped %06X <- %02X\n", a, v);
}

/* Musashi memory access entry points.  Word and long accesses might
 * span device-vs-RAM boundaries (e.g. VMOD_CTRL is just 2 bytes at
 * $1FFF0-1; a long write at $1FFF0 covers RAM at $1FFF2-3 too).
 * To avoid mishandling, word/long accesses go byte-by-byte through
 * bus_read8/bus_write8 except when the entire range is a single
 * device that benefits from atomic access (we keep the optimization
 * for fully-aligned device accesses). */
unsigned int m68k_read_memory_8 (unsigned int a) {
    return bus_read8(a);
}
unsigned int m68k_read_memory_16(unsigned int a) {
    if (getenv("FPS3K_PCLOG") && a >= 0xFF0040 && a <= 0xFF00FF)
        fprintf(stderr, "[PCLOG] rd %06X from PC=%06X\n",
                a, m68k_get_reg(NULL, M68K_REG_PPC));
    /* AP I/F BERR when XLTR DMA is in progress (chassis owns AP I/F bus).
     * Phase 0x1A00 (F09832) deliberately reads while armed to verify. */
    if (a >= 0xFF0000 && a < 0xFF0100 && versabus_apif_dma_busy()) {
        m68k_pulse_bus_error();
        return 0xFFFF;
    }
    /* Chassis shadow: with XLTR_DATA_HI=0, word reads at $400002 of
     * the chassis-routed window return XLTR_DATA_LO regardless of
     * what was written to chassis memory.  Phase 0x1900 stage 4
     * (F097F4+) verifies this. */
    if (a == 0x400002 && (versabus_xltr_data_hi() == 0)) {
        return versabus_xltr_data_lo() & 0xFFFF;
    }
    if (versabus_is_device(a) && versabus_is_device(a+1)) {
        return versabus_read(a, 2) & 0xFFFF;
    }
    return ((unsigned)bus_read8(a) << 8) | bus_read8(a+1);
}
unsigned int m68k_read_memory_32(unsigned int a) {
    if (versabus_is_device(a) && versabus_is_device(a+1)
        && versabus_is_device(a+2) && versabus_is_device(a+3)) {
        return versabus_read(a, 4);
    }
    return ((unsigned)bus_read8(a)   << 24)
         | ((unsigned)bus_read8(a+1) << 16)
         | ((unsigned)bus_read8(a+2) <<  8)
         |  (unsigned)bus_read8(a+3);
}
unsigned int m68k_read_disassembler_8 (unsigned int a) { return bus_read8(a); }
unsigned int m68k_read_disassembler_16(unsigned int a) {
    return ((unsigned)bus_read8(a) << 8) | bus_read8(a+1);
}
unsigned int m68k_read_disassembler_32(unsigned int a) {
    return ((unsigned)bus_read8(a)   << 24)
         | ((unsigned)bus_read8(a+1) << 16)
         | ((unsigned)bus_read8(a+2) <<  8)
         |  (unsigned)bus_read8(a+3);
}
void m68k_write_memory_8 (unsigned int a, unsigned int v) {
    bus_write8(a, v);
}
void m68k_write_memory_16(unsigned int a, unsigned int v) {
    /* With XLTR_DATA_HI=0, word writes to chassis-window word $400000
     * are ignored (long writes still go through).  Phase 0x1900 stage 2
     * verifies this. */
    if (a == 0x400000 && (versabus_xltr_data_hi() == 0)) {
        return;
    }
    if (versabus_is_device(a) && versabus_is_device(a+1)) {
        versabus_write(a, v, 2); return;
    }
    bus_write8(a,   (v >> 8) & 0xFF);
    bus_write8(a+1, v & 0xFF);
}
void m68k_write_memory_32(unsigned int a, unsigned int v) {
    if (versabus_is_device(a) && versabus_is_device(a+1)
        && versabus_is_device(a+2) && versabus_is_device(a+3)) {
        versabus_write(a, v, 4); return;
    }
    bus_write8(a,   (v >> 24) & 0xFF);
    bus_write8(a+1, (v >> 16) & 0xFF);
    bus_write8(a+2, (v >>  8) & 0xFF);
    bus_write8(a+3,  v        & 0xFF);
}

/* ============== misc Musashi callbacks ============== */

int m68k_irq_callback(int level) {
    /* Level 5: TCBIO1I host-link interrupt — vector $128 = #74,
     * handler F05DD6.  Set up by RTOSKernelInit at task creation. */
    extern host_sim_t host_sim;

    /* Vectored interrupt from a BIM: the interrupter supplies the vector
     * during the IACK cycle (MC68153 datasheet, Figure 6).  Ask the
     * modelled BIM rather than returning a constant — the firmware
     * programs BIM2 ch2 with CR $5F (level 7) and VR $4A, so both the
     * level and the vector come from hardware state, not from us. */
    /* Any BIM channel requesting this level supplies its vector.  This
     * must not be conditional on host_sim: the host link is only one of
     * the five channels the firmware enables, and gating on it would
     * leave every other BIM source unacknowledged. */
    {
        int vec = versabus_bim_iack(level);
        if (vec >= 0) return vec;
    }
    if (level == 5 && host_sim.pending) {
        /* Do NOT clear host_sim.pending here.  The host's byte is consumed
         * when the SBC *reads* the data port, which versabus.c already
         * reports via apif_notify_consumed() on a read of $FF0048.  Clearing
         * it at interrupt-acknowledge time was premature in two ways: it let
         * host_sim queue the next byte before the ISR had read the current
         * one, and it de-asserted a level-triggered line early. */
        return 0x4A;   /* vec #74, byte addr $128 */
    }

    /* Two level-4 IRQ sources on this board:
     *   - MC6840 PTM (system tick post-RTOS, or phase-9 self-test)
     *   - Panel-bus chassis interrupter (phase 0x1300/0x1400)
     *
     * For PTM: phase 9 installs a vectored handler at vector 0x54
     * ($150 = F0911E).  The RTOS, on the other hand, uses auto-
     * vectoring for its system tick — at init time it overwrites
     * vector $150 with F0A27A (panic catch-all).
     *
     * Heuristic: peek at vector $150 — if it still points to F0911E
     * we're in self-test mode (return vectored 0x54).  Otherwise
     * the RTOS is running and PTM should auto-vector to its level-4
     * handler at vec $70 = F00EC8. */
    if (level >= 4 && versabus_chassis_irq_pending()) {
        int v = versabus_chassis_irq_ack();
        if (!versabus_ptm_irq_pending()) m68k_set_irq(0);
        /* Same heuristic for chassis: vector 0x50 ($140) becomes a
         * panic post-RTOS-init.  Auto-vector instead. */
        uint32_t vec140 = ((uint32_t)ram[0x140] << 24) | ((uint32_t)ram[0x141] << 16)
                        | ((uint32_t)ram[0x142] << 8)  |  (uint32_t)ram[0x143];
        if (vec140 == 0xF0A27A) return M68K_INT_ACK_AUTOVECTOR;
        return v;
    }
    if (level >= 4 && versabus_ptm_irq_pending()) {
        uint32_t vec150 = ((uint32_t)ram[0x150] << 24) | ((uint32_t)ram[0x151] << 16)
                        | ((uint32_t)ram[0x152] << 8)  |  (uint32_t)ram[0x153];
        if (vec150 == 0xF0911E) return 0x54;          /* phase-9 test */
        return M68K_INT_ACK_AUTOVECTOR;                /* RTOS system tick */
    }
    m68k_set_irq(0);
    return M68K_INT_ACK_AUTOVECTOR;
}

void cpu_pulse_reset(void) {}
void cpu_set_fc(unsigned int fc) { (void)fc; }

/* Musashi's M68K_INSTRUCTION_CALLBACK is wired to call this symbol. */
void instr_hook_callback(unsigned int pc) {
    total_instr++;
        { const char *rl = getenv("FPS3K_REGLOG");
      if (rl && pc == (unsigned)strtoul(rl, NULL, 16))
          fprintf(stderr, "[REG] pc=%06X a1=%08X d2=%08X d4=%08X d5=%08X\n",
                  pc, m68k_get_reg(NULL,M68K_REG_A1), m68k_get_reg(NULL,M68K_REG_D2),
                  m68k_get_reg(NULL,M68K_REG_D4), m68k_get_reg(NULL,M68K_REG_D5)); }
    if (trace_fp) {
        /* compact: just hex PC */
        fprintf(trace_fp, "%06X\n", pc);
    }
    if (pc == breakpc) {
        fprintf(stderr, "[break] PC=%06X reached, stopping after %llu instructions\n",
                pc, (unsigned long long)total_instr);
        stop_now = 1;
    }
}

/* Musashi trap-debug hook (referenced from m68kops.c) */
void trap_debug(int t, unsigned v, unsigned vbr, unsigned sp) {
    (void)t; (void)v; (void)vbr; (void)sp;
}

/* ============== signal handler ============== */
static void sigint_handler(int sig) {
    (void)sig;
    stop_now = 1;
    fprintf(stderr, "\n[interrupt] stopping at next instruction boundary\n");
}

/* ============== main ============== */

static void usage(void) {
    fprintf(stderr,
        "Usage: fps3k_sbc -rom <firmware.bin> [options]\n"
        "Options:\n"
        "  -rom <file>        FPS-3000 SBC firmware (64 KB ROM image, mandatory)\n"
        "  -trace <file>      Write CPU PC trace (one hex addr per line)\n"
        "  -bus <file>        Write detailed VersaBUS access log (default: stderr)\n"
        "  -cycles <n>        Stop after n cycles (default: run forever)\n"
        "  -breakpc <addr>    Halt when PC hits this address (hex 0x..)\n"
        "  -dump-ram <file>   On exit, dump SBC RAM (128 KB) to file\n"
        "  -host-srec <file>  Feed an S-record file to the simulated host,\n"
        "                     which pushes it in over the AP I/F byte path\n"
        "  -v                 Verbose\n"
    );
}

int main(int argc, char **argv) {
    const char *rom_path     = NULL;
    const char *trace_path   = NULL;
    const char *bus_path     = NULL;
    const char *dump_ram_path = NULL;
    uint64_t    max_cycles   = (uint64_t)-1;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-rom") && i+1 < argc)            rom_path     = argv[++i];
        else if (!strcmp(argv[i], "-trace") && i+1 < argc)     trace_path   = argv[++i];
        else if (!strcmp(argv[i], "-bus") && i+1 < argc)       bus_path     = argv[++i];
        else if (!strcmp(argv[i], "-cycles") && i+1 < argc)    max_cycles   = strtoull(argv[++i], NULL, 0);
        else if (!strcmp(argv[i], "-breakpc") && i+1 < argc)   breakpc      = (uint32_t)strtoul(argv[++i], NULL, 0);
        else if (!strcmp(argv[i], "-dump-ram") && i+1 < argc)  dump_ram_path = argv[++i];
        else if (!strcmp(argv[i], "-host-srec") && i+1 < argc) {
            const char *p = argv[++i];
            host_sim_init(&host_sim, p, NULL);
        }
        else if (!strcmp(argv[i], "-v"))                       verbose      = 1;
        else { usage(); return 1; }
    }
    if (!rom_path) { usage(); return 1; }

    /* Load ROM */
    FILE *f = fopen(rom_path, "rb");
    if (!f) { perror(rom_path); return 1; }
    size_t n = fread(rom, 1, ROM_SIZE, f);
    fclose(f);
    if (n != ROM_SIZE) {
        fprintf(stderr, "WARN: ROM image is %zu bytes, expected %d\n", n, ROM_SIZE);
    }
    { const char *u = getenv("FPS3K_UNINIT");
      if (u) uninit_fp = fopen(u, "w"); }

    /* Hook-conflict check.
     *
     * Four defects this project has hit were hooks silently overriding each
     * other.  The worst case is not a wrong value but a FLAT one: a sweep run
     * with a conflicting hook set returns identical results at every point,
     * and a flat result reads as "this variable has no effect" rather than as
     * a broken experiment.  A sweep of FPS3K_RESP taken with FPS3K_SEQ set did
     * exactly that -- five identical measurements, which became a 17-PC spread
     * once the conflict was removed.
     *
     * Each pair below is (loser, winner, what is shared). */
    {
        static const char *const conflicts[][3] = {
            { "FPS3K_RESP",     "FPS3K_SEQ",     "the MODE0 response code" },
            { "FPS3K_CHSEL_RD", "FPS3K_SEQ",     "the CHANNEL_SELECT readback" },
            { "FPS3K_RESP",     "FPS3K_INJECT",  "MODE0 + the BIM0 ch0 request" },
            { "FPS3K_MBOX",     "FPS3K_APIF_LEGACY", "mailbox.host_status" },
        };
        for (size_t k = 0; k < sizeof conflicts / sizeof conflicts[0]; k++)
            if (getenv(conflicts[k][0]) && getenv(conflicts[k][1]))
                fprintf(stderr,
                        "[WARN] %s and %s both set: %s wins, %s is IGNORED "
                        "(shared state: %s)\n",
                        conflicts[k][0], conflicts[k][1], conflicts[k][1],
                        conflicts[k][0], conflicts[k][2]);
    }
    fprintf(stderr, "[init] ROM loaded: %zu bytes from %s\n", n, rom_path);

    /* Open trace files */
    if (trace_path) {
        trace_fp = fopen(trace_path, "w");
        if (!trace_fp) { perror(trace_path); return 1; }
    }
    if (bus_path) {
        bus_fp = fopen(bus_path, "w");
        if (!bus_fp) { perror(bus_path); return 1; }
    } else {
        bus_fp = stderr;
    }

    versabus_init(bus_fp, verbose);
    if (host_sim.enabled) {
        host_sim.log_fp = bus_fp;
        versabus_set_apif_consumed_cb(on_apif_consumed, &host_sim);
    }

    /* Set up Musashi */
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_init();
    m68k_set_int_ack_callback(m68k_irq_callback);
    m68k_set_instr_hook_callback(instr_hook_callback);
    m68k_pulse_reset();

    fprintf(stderr, "[init] M68000 reset; PC=%06X SP=%06X\n",
            m68k_get_reg(NULL, M68K_REG_PC),
            m68k_get_reg(NULL, M68K_REG_SP));

    signal(SIGINT, sigint_handler);

    /* Run loop */
    while (!stop_now && total_cycles < max_cycles) {
        int n = m68k_execute(1024);
        total_cycles += n;
        versabus_tick(n);
        host_sim_tick(&host_sim, n);
        /* Highest pending interrupt wins.  Host attention (L5) is
         * AP-I/F vectored — takes priority over chassis/PTM (L4). */
        int bim_lvl = versabus_bim_pending_level();

        if (bim_lvl) {
            /* Any BIM channel with a pending request wins, at the level
             * its control register selects.  Covers both the host link
             * (BIM2 ch2) and the panel-status path (BIM0 ch0). */
            m68k_set_irq(bim_lvl);
        } else if (host_sim.pending) {
            m68k_set_irq(5);   /* channel not enabled yet: legacy fallback */
        } else if (versabus_chassis_irq_pending() || versabus_ptm_irq_pending()) {
            m68k_set_irq(4);
        } else {
            m68k_set_irq(0);
        }
    }

    fprintf(stderr, "\n[done] %llu cycles, %llu instructions\n",
            (unsigned long long)total_cycles,
            (unsigned long long)total_instr);
    fprintf(stderr, "[done] chassis window $400000: %llu reads, %llu writes, %llu BERR\n",
            (unsigned long long)chassis_mem_reads, (unsigned long long)chassis_mem_writes,
            (unsigned long long)chassis_mem_berrs);
    fprintf(stderr, "[done] final PC=%06X SR=%04X\n",
            m68k_get_reg(NULL, M68K_REG_PC),
            m68k_get_reg(NULL, M68K_REG_SR));
    fprintf(stderr, "[done] device state:\n");
    versabus_dump_state(stderr);

    if (dump_ram_path) {
        FILE *df = fopen(dump_ram_path, "wb");
        if (df) { fwrite(ram, 1, RAM_SIZE, df); fclose(df);
                  fprintf(stderr, "[done] RAM dumped to %s\n", dump_ram_path); }
        else perror(dump_ram_path);
    }

    host_sim_close(&host_sim);
    if (trace_fp && trace_fp != stderr) fclose(trace_fp);
    if (bus_fp   && bus_fp   != stderr) fclose(bus_fp);
    versabus_close();
    return 0;
}
