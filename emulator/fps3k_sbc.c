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

/* Small big-endian RAM readers, used by FPS3K_RTOSDUMP.  Bounds-clamped so a
 * garbage pointer in a half-initialised structure cannot walk off the array. */
static uint16_t rd16(uint32_t a) {
    if (a + 1 >= RAM_SIZE) return 0;
    return (uint16_t)((ram[a] << 8) | ram[a + 1]);
}
static uint32_t rd32(uint32_t a) {
    if (a + 3 >= RAM_SIZE) return 0;
    return ((uint32_t)ram[a] << 24) | ((uint32_t)ram[a + 1] << 16)
         | ((uint32_t)ram[a + 2] << 8) | (uint32_t)ram[a + 3];
}
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
 * panel-bus DMA path.  Sized 1 MB, which is ample: self-test phase $29xx
 * walks $400000-$403FFF -- exactly 16 KB, 4,098 addresses, stride 4, in
 * 65,581 accesses of which 65,570 are 32-bit.  An earlier version of this
 * comment said "the test only touches the first few words", which understated
 * it by three orders of magnitude. */
#define CHASSIS_MEM_BASE  0x400000
/* Op $3's address arithmetic, which is now known exactly:
 *
 *   $F04D72  lsr.l  #$14,d1        ; page  = index >> 20      -> MODE2
 *   $F04D7E  andi.l #$fffff,d1     ; offset = index & $FFFFF   (LONGWORDS)
 *   $F04D84  lsl.l  #$2,d1         ;        -> byte offset, up to $3FFFFC
 *   $F04D88  cmpa.l #$400000,a1    ; DEAD -- can never be true, see below
 *   $F04D96  move.l (a1,d1.l),...  ; else read $400000 + offset
 *
 * So $E58 holds a LONGWORD INDEX, not a byte address: bits 0-19 index within a
 * page and bits 20+ select the page written to MODE2.
 *
 * THE COMPARISON IS UNREACHABLE (2026-07-30).  Note this very comment already says
 * the byte offset runs "up to $3FFFFC" -- which is four bytes SHORT of $400000, so the
 * bge can never fire.  The absolute, un-windowed access it guards is dead code on both
 * arms: $F04DA0 on the read, $F04E14 on the write.  The contradiction was sitting inside
 * a single comment block; nobody drew the conclusion.
 *
 * Consequences: the comparison establishes NOTHING about the window extent, so the
 * reasoning below stands only on its own terms; and the reachable range is
 * $400000-$7FFFFC, which CONTAINS the host mailbox at $70001C.  A chassis model has to
 * decide whether a large-offset access aliases the mailbox, is decoded elsewhere, or
 * faults -- the firmware never issues an index that large, so it does not say.
 *
 * That bound does NOT establish a 4 MB window.  It bounds the computed OFFSET;
 * whether the hardware answers across the whole range is a separate question, and
 * a 4 MB window at $400000 would swallow the mailbox at $70001C -- so the extent
 * is at most 3 MB and this 1 MB is an unforced choice, not a derived one.
 * Self-test phase $29xx only ever walks 16 KB (the first 4,096 longwords of page
 * 0), so nothing in the firmware pins the size either. */
#define CHASSIS_MEM_SIZE  (1u << 20)        /* 1 MB -- see above, not derived */
static uint8_t  chassis_mem[CHASSIS_MEM_SIZE];
static uint8_t  chassis_written[CHASSIS_MEM_SIZE];
static FILE    *chassis_uninit_fp = NULL;
static uint64_t chassis_mem_reads, chassis_mem_writes, chassis_mem_berrs;
/* FPS3K_CHASSIS_CMD: place an RDHC command record in chassis memory.
 *
 * $F052F8 clears MODE2 to select page 0 and sets a0 = $400000, then
 * $F05322 does move.l (a0)+,d1 -- so RDHC reads its command record out of the
 * CHASSIS MEMORY WINDOW, not out of SBC RAM.  The record is a self-contained
 * sequence of longwords whose first is the command number 1..4 (see
 * refs_extracted/versabus_access_map.md, "RDHC's host interface is four
 * commands").  With chassis_mem zero-filled the number reads 0, which
 * $F05324's cmpi.l/ble rejects, so RDHC has never executed a single command in
 * any emulator run.  This hook supplies one.
 *
 * Format: comma-separated 32-bit hex longwords, laid down from $400000.
 *   FPS3K_CHASSIS_CMD=1,1              -> cmd 1, channel 1
 *   FPS3K_CHASSIS_CMD=4,10,5330,...    -> cmd 4 (CPLOAD), count, 'S0', ... */
static uint8_t  cmd_record[256];
static uint32_t cmd_record_len;

/* The record is NOT written into chassis_mem.  Self-test phase $29 at $F096AC
 * walks and WRITES 131,148 chassis addresses, so anything staged there before
 * the run is overwritten long before RDHC looks -- the first attempt did
 * exactly that and RDHC read a command number of 0.  Serving it from a private
 * buffer, and only after the RTOS is up, keeps the self-test's own
 * write-then-read-back patterns intact. */
static void chassis_cmd_preload(void) {
    const char *spec = getenv("FPS3K_CHASSIS_CMD");
    if (!spec) return;
    uint32_t off = 0;
    const char *p = spec;
    while (*p && off + 4 <= sizeof cmd_record) {
        char *end;
        unsigned long v = strtoul(p, &end, 16);
        if (end == p) break;
        cmd_record[off + 0] = (uint8_t)(v >> 24);
        cmd_record[off + 1] = (uint8_t)(v >> 16);
        cmd_record[off + 2] = (uint8_t)(v >> 8);
        cmd_record[off + 3] = (uint8_t)v;
        off += 4;
        p = end;
        while (*p == ',' || *p == ' ') p++;
    }
    cmd_record_len = off;
    fprintf(stderr, "[chassis-cmd] %u longwords served at $400000 once the "
                    "RTOS is up\n", off / 4);
}

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
    /* Gate on boot completion, for exactly the reason FPS3K_DMA10AA is gated:
     * the power-on diagnostics walk all of RAM writing a pattern and reading it
     * back, so ANY location forced to read a constant fails a pattern test and
     * the machine hangs in the diagnostics.  Measured: FPS3K_POKE=10A0=0002
     * ended the boot at F098FC (the address-uniqueness test) instead of F00FCC
     * (the RTOS idle loop), and every downstream measurement read as "the hook
     * had no effect" when in fact the machine never booted.  This defect was
     * fixed once for DMA10AA and left in place here.
     * FPS3K_POKE_FROM_RESET=1 restores the old behaviour for comparison. */
    if (!getenv("FPS3K_POKE_FROM_RESET")) {
        uint32_t v128 = ((uint32_t)ram[0x128] << 24) | ((uint32_t)ram[0x129] << 16)
                      | ((uint32_t)ram[0x12A] << 8)  |  (uint32_t)ram[0x12B];
        if (v128 != 0xF05DD6) return 0;
    }
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

/* FPS3K_POKEONCE="addr=word,..." -- same syntax as FPS3K_POKE, but performs a
 * REAL RAM WRITE, ONCE, when the boot-complete gate first opens.
 *
 * FPS3K_POKE overrides every READ of its addresses, forever.  That models a
 * value the chassis continuously supplies, and it is the wrong shape for a
 * value the chassis SETS at one moment.  Measured: forcing RDHC's saved PC
 * (TCB+$FC at $1F3FC) with FPS3K_POKE does release it from the bra . at
 * $F056B8 -- spin iterations fall 182,124 -> 20 and execution reaches $F056BA
 * -- but the machine then collapses (RTOS idle 3,661 -> 8), because the kernel
 * can never save a NEW pc for the task: every context switch reads the forced
 * value back.  A hook that forces a value is not a model of an event that sets
 * one.
 *
 * This writes once and then leaves the memory alone, so the kernel's own
 * save/restore continues to work afterwards.  Unset (the default) nothing
 * happens and no write occurs. */
static void pokeonce_apply(uint8_t *ram) {
    static int done;
    const char *e = getenv("FPS3K_POKEONCE");
    if (done || !e) return;
    done = 1;
    char buf[512];
    snprintf(buf, sizeof buf, "%s", e);
    for (char *tk = strtok(buf, ","); tk; tk = strtok(NULL, ",")) {
        char *eq = strchr(tk, '=');
        if (!eq) continue;
        *eq = 0;
        uint32_t a = (uint32_t)strtoul(tk, NULL, 16);
        uint32_t v = (uint32_t)strtoul(eq + 1, NULL, 16);
        if (a + 1 >= 0x20000) continue;
        ram[a]     = (uint8_t)(v >> 8);
        ram[a + 1] = (uint8_t)(v & 0xFF);
        fprintf(stderr, "[POKEONCE] $%05X <- $%04X (one-time write)\n", a, v);
    }
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
        if (cmd_record_len && a - CHASSIS_MEM_BASE < cmd_record_len) {
            uint32_t v128 = ((uint32_t)ram[0x128] << 24) | ((uint32_t)ram[0x129] << 16)
                          | ((uint32_t)ram[0x12A] << 8)  |  (uint32_t)ram[0x12B];
            if (v128 == 0xF05DD6) {          /* RTOS up: tasks have connected */
                chassis_mem_reads++;
                return cmd_record[a - CHASSIS_MEM_BASE];
            }
        }
        if (!(versabus_xltr_data_hi() & 0x20)) {
            /* FPS3K_CHASSIS_UNINIT=<file>: log reads of chassis memory that
             * has not been written this run.  The same question the SBC-side
             * FPS3K_UNINIT answers: chassis_mem is a zero-filled array, but a
             * real MAIN DATA card powers up random, so a diagnostic that reads
             * before writing could pass here and fail on iron. */
            if (chassis_uninit_fp && !chassis_written[a - CHASSIS_MEM_BASE])
                fprintf(chassis_uninit_fp, "%06X %06X\n", a,
                        m68k_get_reg(NULL, M68K_REG_PPC));
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
            /* Accepts "<addr>" (one longword, the original form) or
             * "<lo>-<hi>" (inclusive range).  It used to be strtoul() alone,
             * which parsed "1FE00-1FE28" as $1FE00 and silently discarded the
             * range -- so a sweep over a 40-byte structure reported writes to
             * its first 4 bytes only, and the untouched remainder read as a
             * finding rather than as the matcher being too narrow. */
            char *end = NULL;
            uint32_t w = (uint32_t)strtoul(rw, &end, 16);
            uint32_t hi = (end && *end == '-')
                          ? (uint32_t)strtoul(end + 1, NULL, 16) : w + 3;
            if (a >= w && a <= hi)
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
            chassis_written[a - CHASSIS_MEM_BASE] = 1;
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
/* FPS3K_ACCESSLOG=<file>: every data access at the CPU boundary, with its TRUE
 * WIDTH and the PC that made it.
 *
 * The existing -bus log records accesses AFTER decomposition: m68k_*_memory_32
 * fans out into four bus_*8 calls, and versabus_write() is only called with a
 * width when the whole span happens to be device space.  So one 32-bit write to
 * $FF0210 shows up as separate $FF0210 and $FF0212 entries -- which is exactly
 * how a phantom register at $FF0212 came to be catalogued and then had to be
 * argued away from log ordering.  Logging here, before any splitting, makes the
 * width a recorded fact instead of an inference.
 *
 * Execution coverage comes from -trace (the PC list); this covers reads and
 * writes across the WHOLE address space, RAM included, not just devices. */
static FILE *acc_fp = NULL;

static void acc_init(void) {
    static int tried;
    if (tried) return;
    tried = 1;
    const char *f = getenv("FPS3K_ACCESSLOG");
    if (f) {
        acc_fp = fopen(f, "w");
        if (acc_fp) fprintf(acc_fp, "# op width addr value pc\n");
    }
}

static void acc_log(char op, int width, uint32_t a, uint32_t v) {
    if (!acc_fp) return;
    fprintf(acc_fp, "%c %d %06X %08X %06X\n", op, width, a, v,
            m68k_get_reg(NULL, M68K_REG_PPC));
}

unsigned int m68k_read_memory_8 (unsigned int a) {
    acc_init();
    if (acc_fp) { unsigned r = bus_read8(a); acc_log('R', 1, a, r); return r; }
    return bus_read8(a);
}
static unsigned int m68k_read_memory_16_impl(unsigned int a) {
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
    /* Phase $19xx names BIT 4, not "data_hi is zero":
     *   $1903  $216 = $10  ->  expect chassis memory  ($5555)
     *   $1904  $216 = $00  ->  expect XLTR_DATA_LO    ($AAAA)
     * and $FF0216 RESTS AT $C0, so bit 4 is clear in normal service while
     * data_hi != 0 -- the two conditions disagree exactly where it matters. */
    /* Phase $19xx names BIT 4 as the 16-bit-access enable:
     *   $1903  $216 = $10  ->  word read at $400002 gives chassis memory
     *   $1904  $216 = $00  ->  it gives XLTR_DATA_LO
     * but bit 4 ALONE is the wrong condition here, because this early return
     * would then swallow the word probes of the BERR phases: $17xx sets $216 =
     * $20 and requires a FAULT, and bit 4 is clear in that value.  `data_hi ==
     * 0` used to avoid that by accident.  The two mechanisms are independent in
     * hardware and only sequential in this model, so gate on bit 4 clear AND no
     * BERR armed (bit 5 clear), which satisfies $19xx and $17xx together. */
    if (a == 0x400002 && !(versabus_xltr_data_hi() & 0x30)) {
        return versabus_xltr_data_lo() & 0xFFFF;
    }
    if (versabus_is_device(a) && versabus_is_device(a+1)) {
        return versabus_read(a, 2) & 0xFFFF;
    }
    return ((unsigned)bus_read8(a) << 8) | bus_read8(a+1);
}
static unsigned int m68k_read_memory_32_impl(unsigned int a) {
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
    acc_init(); acc_log('W', 1, a, v);
    bus_write8(a, v);
}
static void m68k_write_memory_16_impl(unsigned int a, unsigned int v) {
    /* With XLTR_DATA_HI=0, word writes to chassis-window word $400000
     * are ignored (long writes still go through).  Phase 0x1900 stage 2
     * verifies this. */
    /* Same bit, the write half: phase $1901 sets $216 = $10 and requires the
     * word write to TAKE EFFECT ($AAAA5555); phase $1902 clears it and requires
     * the write to be IGNORED ($55555555). */
    /* Same reasoning as the $400002 read shadow above: bit 4 clear (16-bit
     * access disabled) AND bit 5 clear (no bus error armed). */
    if (a == 0x400000 && !(versabus_xltr_data_hi() & 0x30)) {
        return;
    }
    if (versabus_is_device(a) && versabus_is_device(a+1)) {
        versabus_write(a, v, 2); return;
    }
    bus_write8(a,   (v >> 8) & 0xFF);
    bus_write8(a+1, v & 0xFF);
}
static void m68k_write_memory_32_impl(unsigned int a, unsigned int v) {
    if (versabus_is_device(a) && versabus_is_device(a+1)
        && versabus_is_device(a+2) && versabus_is_device(a+3)) {
        versabus_write(a, v, 4); return;
    }
    bus_write8(a,   (v >> 24) & 0xFF);
    bus_write8(a+1, (v >> 16) & 0xFF);
    bus_write8(a+2, (v >>  8) & 0xFF);
    bus_write8(a+3,  v        & 0xFF);
}


/* Width-aware wrappers.  The bodies above are untouched; these only record the
 * access at its TRUE width before any decomposition.  The byte callbacks reach
 * bus_*8 directly rather than through these, so nothing is logged twice. */
unsigned int m68k_read_memory_16(unsigned int a) {
    acc_init();
    unsigned int r = m68k_read_memory_16_impl(a);
    acc_log('R', 2, a, r);
    return r;
}
unsigned int m68k_read_memory_32(unsigned int a) {
    acc_init();
    unsigned int r = m68k_read_memory_32_impl(a);
    acc_log('R', 4, a, r);
    return r;
}
void m68k_write_memory_16(unsigned int a, unsigned int v) {
    acc_init(); acc_log('W', 2, a, v);
    m68k_write_memory_16_impl(a, v);
}
void m68k_write_memory_32(unsigned int a, unsigned int v) {
    acc_init(); acc_log('W', 4, a, v);
    m68k_write_memory_32_impl(a, v);
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
          /* d0 and d1 added 2026-07-29: the XP channel dispatch at $F07F84
           * indexes on d0, and the hook logged a1/d2/d4/d5 only -- so the one
           * register the dispatch depends on was the one it could not show. */
          fprintf(stderr, "[REG] pc=%06X d0=%08X d1=%08X a1=%08X d2=%08X "
                          "d4=%08X d5=%08X\n",
                  pc, m68k_get_reg(NULL,M68K_REG_D0), m68k_get_reg(NULL,M68K_REG_D1),
                  m68k_get_reg(NULL,M68K_REG_A1), m68k_get_reg(NULL,M68K_REG_D2),
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
    { const char *u = getenv("FPS3K_CHASSIS_UNINIT");
      if (u) chassis_uninit_fp = fopen(u, "w"); }

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
        /* The fourth column qualifies the claim.  RESP/SEQ was previously
         * reported as "IGNORED", which is FALSE and cost real analysis time:
         * with both set, MODE0 was measured carrying $0001 and $0426 (scripted)
         * AND $0094 and $0494 (FPS3K_RESP, the latter with the valid bit).  The
         * sequence wins only WHILE it has entries; once exhausted, FPS3K_RESP
         * is what continues to be delivered.  The other three pairs are left as
         * written -- they have not been measured, and weakening an unverified
         * warning is as wrong as overstating one. */
        static const char *const conflicts[][4] = {
            { "FPS3K_RESP",     "FPS3K_SEQ",     "the MODE0 response code",
              "the scripted codes are delivered FIRST, then FPS3K_RESP once the "
              "sequence is exhausted -- not ignored" },
            { "FPS3K_CHSEL_RD", "FPS3K_SEQ",     "the CHANNEL_SELECT readback", NULL },
            { "FPS3K_RESP",     "FPS3K_INJECT",  "MODE0 + the BIM0 ch0 request", NULL },
            { "FPS3K_MBOX",     "FPS3K_APIF_LEGACY", "mailbox.host_status", NULL },
        };
        for (size_t k = 0; k < sizeof conflicts / sizeof conflicts[0]; k++) {
            if (!(getenv(conflicts[k][0]) && getenv(conflicts[k][1])))
                continue;
            if (conflicts[k][3])
                fprintf(stderr, "[WARN] %s and %s both set (shared state: %s): %s\n",
                        conflicts[k][0], conflicts[k][1], conflicts[k][2],
                        conflicts[k][3]);
            else
                fprintf(stderr,
                        "[WARN] %s and %s both set: %s wins, %s is IGNORED "
                        "(shared state: %s)\n",
                        conflicts[k][0], conflicts[k][1], conflicts[k][1],
                        conflicts[k][0], conflicts[k][2]);
        }
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
    chassis_cmd_preload();
    m68k_pulse_reset();

    fprintf(stderr, "[init] M68000 reset; PC=%06X SP=%06X\n",
            m68k_get_reg(NULL, M68K_REG_PC),
            m68k_get_reg(NULL, M68K_REG_SP));

    signal(SIGINT, sigint_handler);

    /* Run loop */
    while (!stop_now && total_cycles < max_cycles) {
        /* One-time RAM writes, applied the first time the boot gate opens --
         * vector $128 holding F05DD6 means TCBIO1I has started.  Same gate the
         * other injections use, for the same reason: the power-on diagnostics
         * walk RAM and any value planted before them is either overwritten or
         * fails a pattern test. */
        {
            uint32_t v128 = ((uint32_t)ram[0x128] << 24) | ((uint32_t)ram[0x129] << 16)
                          | ((uint32_t)ram[0x12A] << 8)  |  (uint32_t)ram[0x12B];
            if (v128 == 0xF05DD6) pokeonce_apply(ram);
        }
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

    /* FPS3K_RTOSDUMP: decode the RMS68K state out of RAM and print it.
     *
     * Everything here is a readout, not an inference.  Directive $04 is a
     * 256-byte page allocator whose eight structure sites register their
     * blocks in a directory at $0C20/$0C24/$0C66/$0C6A/$0C6E/$0C2C/$0C28/
     * $0C30; !IDV holds the complete interrupt wiring as {vector, TCB, ISR
     * entry, ISR exit}; $1FA00 is !VCT, one byte per exception vector holding
     * the owning task number; !UST is the ASQ name registry.  Derivation is in
     * refs_extracted/versabus_access_map.md. */
    if (getenv("FPS3K_RTOSDUMP")) {
        static const uint32_t slots[8] = { 0x0C20, 0x0C24, 0x0C66, 0x0C6A,
                                           0x0C6E, 0x0C2C, 0x0C28, 0x0C30 };
        uint32_t heap_lo = 0x20000;
        fprintf(stderr, "\n=== RMS68K state (decoded from RAM) ===\n");
        fprintf(stderr, "structure directory (TRAP #0 directive $04, page allocator):\n");
        for (int k = 0; k < 8; k++) {
            uint32_t b = rd32(slots[k]);
            if (b < 0x20000 && b) {
                char tag[5] = { 0 };
                for (int j = 0; j < 4; j++) {
                    uint8_t c = ram[b + j];
                    tag[j] = (c >= 32 && c < 127) ? (char)c : '.';
                }
                fprintf(stderr, "  $%04X -> $%05X  %s\n", slots[k], b, tag);
                if (b < heap_lo) heap_lo = b;
            } else {
                fprintf(stderr, "  $%04X -> $%05X  (not allocated)\n", slots[k], b);
            }
        }
        /* tasks: TCBs stride $200 downward from the lowest structure */
        fprintf(stderr, "tasks (TCB: name +$10, ASQ/stack block +$138, "
                        "saved SP +$13C; vector and handler come from !IDV below):\n");
        /* TCBs continue the same downward heap, starting one page-pair below
         * the lowest structure, each $200 (two pages).  Walk down while the
         * '!TCB' tag is present. */
        for (uint32_t t = heap_lo - 0x200; t >= 0x1000 && ram[t] == '!'; t -= 0x200) {
            uint32_t blk = rd32(t + 0x138);
            fprintf(stderr, "  $%05X  %c%c%c%c  block=$%05X  sp=$%05X\n", t,
                    ram[t + 0x10], ram[t + 0x11], ram[t + 0x12], ram[t + 0x13],
                    blk, rd32(t + 0x13C));
            if (blk && blk < heap_lo) heap_lo = blk;
        }
        /* !IDV: the interrupt wiring */
        {
            uint32_t idv = rd32(0x0C6E);
            if (idv && idv < 0x20000) {
                fprintf(stderr, "!IDV interrupt table @ $%05X "
                                "{vector, TCB, ISR entry, ISR exit}:\n", idv);
                for (int k = 0; k < 6; k++) {
                    uint32_t e = idv + 8 + k * 14;
                    uint16_t v = rd16(e);
                    if (!v) break;
                    uint32_t tcb = rd32(e + 2);
                    fprintf(stderr, "  vec $%02X  TCB $%05X %c%c%c%c  "
                                    "in $%06X  out $%06X   !VCT owner=%u\n",
                            v, tcb,
                            ram[tcb + 0x10], ram[tcb + 0x11],
                            ram[tcb + 0x12], ram[tcb + 0x13],
                            rd32(e + 6), rd32(e + 10),
                            ram[rd32(0x0C66) + v]);
                }
            }
        }
        /* !VCT: every owned vector, including any not in !IDV */
        {
            uint32_t vct = rd32(0x0C66);
            fprintf(stderr, "!VCT owned vectors @ $%05X (byte[vector] = task):", vct);
            int n = 0;
            for (int v = 0; v < 256; v++) {
                uint8_t o = ram[vct + v];
                if (!o || o == 0xFF) continue;          /* unowned / not-default */
                if (o & 0x80) {
                    /* high bit set: a map flag byte, not a task number.  $BF
                     * (bit 6 cleared from $FF) appears at vector $2D; what
                     * clears it is $F012E6 in the kernel and is not yet known. */
                    fprintf(stderr, " $%02X=flags:$%02X", v, o);
                } else {
                    fprintf(stderr, " $%02X->task%u", v, o);
                }
                n++;
            }
            fprintf(stderr, "%s\n", n ? "" : "  (none)");
        }
        /* !UST: the ASQ registry */
        {
            uint32_t ust = rd32(0x0C24);
            if (ust && ust < 0x20000) {
                uint16_t rsz = rd16(ust + 0x0C), used = rd16(ust + 0x0E);
                fprintf(stderr, "!UST ASQ registry @ $%05X  %u of %u records "
                                "of $%X bytes:", ust, used,
                        (unsigned)((rd16(ust + 0x0A) * 256 - 0x14) / (rsz ? rsz : 1)),
                        rsz);
                for (int k = 0; k < used && k < 32; k++) {
                    uint32_t e = ust + 0x14 + k * rsz;
                    fprintf(stderr, "  %c%c%c%c/%c%c%c%c",
                            ram[e], ram[e+1], ram[e+2], ram[e+3],
                            ram[e+8], ram[e+9], ram[e+10], ram[e+11]);
                }
                fprintf(stderr, "\n");
            }
        }
        fprintf(stderr, "heap: top $1FE00, bottom $%05X (%u pages handed out)"
                        "  ->  microcode staging buffer usable range "
                        "$10000-$%05X (%u bytes)\n",
                heap_lo, (0x1FE00 - heap_lo) / 256,
                heap_lo - 1, heap_lo - 0x10000);
        fprintf(stderr, "=== end RMS68K state ===\n");
    }

    fprintf(stderr, "\n[done] %llu cycles, %llu instructions\n",
            (unsigned long long)total_cycles,
            (unsigned long long)total_instr);
    fprintf(stderr, "[done] chassis window $400000: %llu reads, %llu writes, %llu BERR\n",
            (unsigned long long)chassis_mem_reads, (unsigned long long)chassis_mem_writes,
            (unsigned long long)chassis_mem_berrs);
    /* Instrumentation inventory.
     *
     * Three measurements this session came back EMPTY for instrumental
     * reasons rather than machine ones: the bus log does not record the
     * $400000 window, FPS3K_LOGCHASSIS writes to stderr while -bus redirects
     * only the bus file, and two hooks silently overrode each other.  An
     * empty result that looks like a finding is the expensive failure, so the
     * run now states what was instrumented and where each channel went. */
    {
        static const char *const hooks[] = {
            "FPS3K_CHANNELS","FPS3K_CHCMD","FPS3K_XPIRQ","FPS3K_DMA10AA",
            "FPS3K_DMA10AA_FROM_RESET","FPS3K_MBOX","FPS3K_SEQ","FPS3K_SEQGAP",
            "FPS3K_RESP","FPS3K_RESP_INSVC","FPS3K_CHSEL_RD","FPS3K_SREC",
            "FPS3K_DATAIN","FPS3K_INJECT","FPS3K_HOSTLVL","FPS3K_POKE",
            "FPS3K_RAMWATCH","FPS3K_VECWATCH","FPS3K_UNINIT",
            "FPS3K_CHASSIS_UNINIT","FPS3K_LOGCHASSIS","FPS3K_BUSPC",
            "FPS3K_BSTAT19_B5","FPS3K_PCLOG","FPS3K_REGLOG","FPS3K_APIF_LEGACY",
            "FPS3K_RTOSDUMP","FPS3K_CHASSIS_CMD","FPS3K_POKE_FROM_RESET",
            "FPS3K_CHSEL_RD_FROM_RESET","FPS3K_MODE1_BUSY","FPS3K_CHACK_DELAY",
            "FPS3K_ACCESSLOG","FPS3K_RESPSEQ",
        };
        int any = 0;
        fprintf(stderr, "[done] hooks active:");
        for (size_t k = 0; k < sizeof hooks / sizeof hooks[0]; k++) {
            const char *v = getenv(hooks[k]);
            if (v) { fprintf(stderr, " %s=%s", hooks[k], *v ? v : "1"); any = 1; }
        }
        fprintf(stderr, "%s\n", any ? "" : " (none - DEFAULT configuration)");
        {
        uint64_t ur, uw;
        versabus_unmapped_counts(&ur, &uw);
        fprintf(stderr, "[done] unmapped chassis accesses: %llu reads, %llu writes"
                        "%s\n", (unsigned long long)ur, (unsigned long long)uw,
                (ur || uw) ? "  <-- A REGION WITH NO CARD MODELLED WAS TOUCHED"
                           : "  (address map complete for this run)");
    }
    fprintf(stderr, "[done] log channels: bus=%s  chassis-mem=%s  "
                        "uninit=%s  chassis-uninit=%s\n",
                bus_path ? bus_path : "(off)",
                getenv("FPS3K_LOGCHASSIS") ? "stderr" : "(off - NOT in the bus log)",
                getenv("FPS3K_UNINIT") ? getenv("FPS3K_UNINIT") : "(off)",
                getenv("FPS3K_CHASSIS_UNINIT") ? getenv("FPS3K_CHASSIS_UNINIT") : "(off)");
    }
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
