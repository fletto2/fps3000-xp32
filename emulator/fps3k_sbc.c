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

#define RAM_SIZE  (128 * 1024)        /* 0x000000-0x01FFFF */
#define ROM_SIZE  (64  * 1024)        /* 0xF00000-0xF0FFFF */
#define ROM_BASE  0xF00000

static uint8_t  ram[RAM_SIZE];
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

static uint8_t bus_read8(uint32_t a) {
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

    if (a < RAM_SIZE) return ram[a];
    if (a >= ROM_BASE && a < ROM_BASE + ROM_SIZE) return rom[a - ROM_BASE];

    if (versabus_is_device(a)) {
        return versabus_read(a, 1) & 0xFF;
    }

    if (verbose) fprintf(stderr, "[bus] R8  unmapped %06X\n", a);
    return 0xFF;
}

static void bus_write8(uint32_t a, uint8_t v) {
    a &= 0xFFFFFFu;

    if (a < RAM_SIZE) {
        ram[a] = v;
        return;
    }
    if (a >= ROM_BASE && a < ROM_BASE + ROM_SIZE) {
        if (verbose) fprintf(stderr, "[bus] W8 ROM-write %06X <- %02X (ignored)\n", a, v);
        return;
    }
    if (versabus_is_device(a)) {
        versabus_write(a, v, 1);
        return;
    }
    if (verbose) fprintf(stderr, "[bus] W8  unmapped %06X <- %02X\n", a, v);
}

/* Musashi memory access entry points */
unsigned int m68k_read_memory_8 (unsigned int a) {
    if (versabus_is_device(a)) return versabus_read(a, 1) & 0xFF;
    return bus_read8(a);
}
unsigned int m68k_read_memory_16(unsigned int a) {
    if (versabus_is_device(a)) return versabus_read(a, 2) & 0xFFFF;
    return ((unsigned)bus_read8(a) << 8) | bus_read8(a+1);
}
unsigned int m68k_read_memory_32(unsigned int a) {
    if (versabus_is_device(a)) return versabus_read(a, 4);
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
    if (versabus_is_device(a)) { versabus_write(a, v, 1); return; }
    bus_write8(a, v);
}
void m68k_write_memory_16(unsigned int a, unsigned int v) {
    if (versabus_is_device(a)) { versabus_write(a, v, 2); return; }
    bus_write8(a,   (v >> 8) & 0xFF);
    bus_write8(a+1, v & 0xFF);
}
void m68k_write_memory_32(unsigned int a, unsigned int v) {
    if (versabus_is_device(a)) { versabus_write(a, v, 4); return; }
    bus_write8(a,   (v >> 24) & 0xFF);
    bus_write8(a+1, (v >> 16) & 0xFF);
    bus_write8(a+2, (v >>  8) & 0xFF);
    bus_write8(a+3,  v        & 0xFF);
}

/* ============== misc Musashi callbacks ============== */

int m68k_irq_callback(int level) {
    /* No external IRQs from stubs — autovector if any */
    m68k_set_irq(0);
    (void)level;
    return M68K_INT_ACK_AUTOVECTOR;
}

void cpu_pulse_reset(void) {}
void cpu_set_fc(unsigned int fc) { (void)fc; }

/* Musashi's M68K_INSTRUCTION_CALLBACK is wired to call this symbol. */
void instr_hook_callback(unsigned int pc) {
    total_instr++;
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
    }

    fprintf(stderr, "\n[done] %llu cycles, %llu instructions\n",
            (unsigned long long)total_cycles,
            (unsigned long long)total_instr);
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

    if (trace_fp && trace_fp != stderr) fclose(trace_fp);
    if (bus_fp   && bus_fp   != stderr) fclose(bus_fp);
    versabus_close();
    return 0;
}
