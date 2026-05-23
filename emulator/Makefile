# Makefile for FPS-3000 SBC emulator
#
# Builds an MC68000 emulator for the FPS-3000 SBC (M68KVM02-3 VERSAmodule),
# using Musashi for the CPU core. Models the MC6840 PTM, NEC µPD7201 SIO,
# AP I/F + XLTR + 0x700000 mailbox stubs, plus a CPU PC trace and detailed
# VersaBUS access log.

CC      = gcc
CFLAGS  = -O2 -Wall -Wno-unused-result -Wno-unused-variable -Wno-unused-function \
          -DM68K_EMULATE_020=0 -DM68K_EMULATE_030=0 -DM68K_EMULATE_040=0
LDFLAGS = -lm

MUSASHI_DIR = musashi
MUSASHI_SRC = $(MUSASHI_DIR)/m68kcpu.c \
              $(MUSASHI_DIR)/m68kops.c \
              $(MUSASHI_DIR)/m68kdasm.c

SOFTFLOAT_SRC = $(MUSASHI_DIR)/softfloat/softfloat.c
ifneq ($(wildcard $(SOFTFLOAT_SRC)),)
  MUSASHI_SRC += $(SOFTFLOAT_SRC)
  CFLAGS += -I$(MUSASHI_DIR)/softfloat
endif

CFLAGS += -I$(MUSASHI_DIR)

TARGET = fps3k_sbc
SRC    = fps3k_sbc.c versabus.c mc6840.c upd7201.c host_sim.c

all: $(TARGET)

$(TARGET): $(SRC) versabus.h mc6840.h upd7201.h host_sim.h $(MUSASHI_SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(MUSASHI_SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET) trace.log bus.log ramdump.bin

# Run with logging — common case
run: $(TARGET)
	./$(TARGET) -rom ../FPS3K_U11_U12_JOIN.bin -trace trace.log -bus bus.log

# Limited cycles for fast smoke test
smoke: $(TARGET)
	./$(TARGET) -rom ../FPS3K_U11_U12_JOIN.bin -cycles 100000 -bus bus.log

.PHONY: all clean run smoke
