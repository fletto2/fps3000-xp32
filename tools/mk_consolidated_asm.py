#!/usr/bin/env python3
"""Build fps3k.asm - the single consolidated FPS-3000 disassembly.

Input : fps3k_custom_annotated.asm  (frozen; its own generator reads a
        /tmp file and cannot be rerun - see CLAUDE.md)
Output: fps3k.asm

Supersedes fps3k_clean.asm.  Symbol tables here are corrected against the
2026-07-29 findings; the old cleaner's names for the AP I/F channel ports
and several $E5x/$E6x globals were wrong.
"""
import re, datetime

IN  = 'fps3k_custom_annotated.asm'
OUT = 'fps3k.asm'

# ---- AP I/F + XLTR, corrected -------------------------------------------
# The channel window is NOT write/readA/status/readB.  +$08 and +$0A are the
# high and low halves of one 32-bit data register; +$0E is a command/trigger.
IO = {
    0x0000:'APIF_CMD_STATUS',     # $8004/$8005 out; reads <=0 = END OF STREAM
    0x0004:'APIF_READY',          # bit 0 = port ready, polled before transfers
    0x0008:'APIF_BULK_DATA',      # bidirectional: S-record ASCII / binary in / binary out
    0x000E:'APIF_PANEL_CMD',
    0x0010:'APIF_CMD_ARG_HI',
    0x0044:'APIF_CH1_WRITE', 0x0048:'APIF_CH1_DATA_HI', 0x004A:'APIF_CH1_DATA_LO', 0x004E:'APIF_CH1_CMD',
    0x0064:'APIF_CH2_WRITE', 0x0068:'APIF_CH2_DATA_HI', 0x006A:'APIF_CH2_DATA_LO', 0x006E:'APIF_CH2_CMD',
    0x0084:'APIF_CH3_WRITE', 0x0088:'APIF_CH3_DATA_HI', 0x008A:'APIF_CH3_DATA_LO', 0x008E:'APIF_CH3_CMD',
    0x00A4:'APIF_CH4_WRITE', 0x00A8:'APIF_CH4_DATA_HI', 0x00AA:'APIF_CH4_DATA_LO', 0x00AE:'APIF_CH4_CMD',
    0x0200:'XLTR_MODE0', 0x0202:'XLTR_MODE1', 0x0204:'XLTR_CHANNEL_SELECT',
    0x020C:'XLTR_COUNTER', 0x0210:'XLTR_MODE2_PAGE', 0x0214:'XLTR_DATA_LO',
    0x0216:'XLTR_DATA_HI', 0x0218:'XLTR_STATUS_IRQ', 0x021A:'XLTR_IRQ_MASK',
    # $FF0230-$FF025F are BIM registers, not "channel config"
    0x0230:'BIM0_CR0', 0x0232:'BIM0_CR1', 0x0234:'BIM0_CR2', 0x0236:'BIM0_CR3',
    0x0238:'BIM0_VR0', 0x023A:'BIM0_VR1', 0x023C:'BIM0_VR2', 0x023E:'BIM0_VR3',
    0x0240:'BIM1_CR0', 0x0242:'BIM1_CR1', 0x0244:'BIM1_CR2_XP1', 0x0246:'BIM1_CR3_XP2',
    0x0248:'BIM1_VR0', 0x024A:'BIM1_VR1', 0x024C:'BIM1_VR2_XP1', 0x024E:'BIM1_VR3_XP2',
    0x0250:'BIM2_CR0_XP3', 0x0252:'BIM2_CR1_XP4', 0x0254:'BIM2_CR2_IO1', 0x0256:'BIM2_CR3',
    0x0258:'BIM2_VR0_XP3', 0x025A:'BIM2_VR1_XP4', 0x025C:'BIM2_VR2_IO1', 0x025E:'BIM2_VR3',
}

# ---- SBC RAM globals, corrected -----------------------------------------
RAM = {
    0x000400:'g_sched_save_d0', 0x000800:'g_ctx_save',
    0x000C00:'g_tcb_chain_ptr', 0x000C08:'g_saved_sp',
    0x000C36:'g_apif_base',     0x000C3A:'g_apif_ptr', 0x000C66:'g_current_tcb',
    0x000E58:'g_xfer_addr_hi',  0x000E5A:'g_xfer_addr_lo',   # 32-bit destination
    0x000E5C:'g_opcode_latch',  0x000E5E:'g_opcode_lo',      # $28 = bulk transfer
    0x000E60:'g_xp_channel',    0x000E62:'g_xp_channel_lo',  # XP channel 1-4
    0x000E64:'g_xfer_count_hi', 0x000E66:'g_xfer_count_lo',  # 32-bit word count
    0x000E68:'g_data_param_hi', 0x000E6A:'g_data_param_lo',  # -> d3 of PanelSendAndWait
    0x000E6E:'g_last_panel_arg',
    0x000E70:'g_chassis_data_hi',0x000E72:'g_chassis_data_lo',# code $3 read/write data
    0x000E74:'g_result',        # returned to the chassis via CHANNEL_SELECT
    0x000E7A:'g_slot_index',    # codes $A/$C, range-checked 0..$C
    0x000E86:'g_response_word', 0x000E87:'g_response_byte',  # b7 dispatcher, b6/b5 modifiers
    0x00101E:'g_regfile',       # 16 longwords, $101E-$105D
    0x00105E:'g_ac_count',      # installed-AC count, chassis-supplied
    0x001062:'g_task_channel',  # each XP task writes its own number
    0x001064:'g_channel_mask',  # shared bitmask, all four tasks and/or into it
    0x001066:'g_ch_block',      # 4 x 3 words, stride 6
    0x001080:'g_ch_ptr_table', 0x0010A0:'g_ch_word_array',
    0x0010AA:'g_io1_gate',      # TCBIO1I dispatches on this; chassis-supplied
    0x01FFF0:'VMOD_CTRL',       0x01FFF1:'VMOD_CTRL_LO',
}

# ---- task regions, from the TDTI table at $F0A600 ------------------------
REGIONS = [(0xF04488,0xF045FF,'pre-task init - outside every TDTI region; runs before tasks exist'),
           (0xF04600,0xF05CFF,'TCBRDHC  - master dispatch, panel cmds, SLC loader'),
           (0xF05D00,0xF05EFF,'TCBIO1I  - host link, mailbox $70001C/$700020'),
           (0xF05F00,0xF068FF,'TCBXP4I  - XP-32 channel 4  (shifted $18 off the $A00 grid)'),
           (0xF06900,0xF072FF,'TCBXP3I  - XP-32 channel 3'),
           (0xF07300,0xF07CFF,'TCBXP2I  - XP-32 channel 2'),
           (0xF07D00,0xF086FF,'TCBXP1I  - XP-32 channel 1  (the template the other three copy)'),
           (0xF08700,0xF08CFF,'MainInit - self-test dispatcher, two checkpoints'),
           (0xF08D00,0xF09BFF,'Self-test suite - phases $0100-$2903'),
           (0xF09C00,0xF0A5FF,'Reset entry, Phase2Init, RTOSKernelInit, TDTI'),
           (0xF0A600,0xF0A825,'TDTI task definition table, $C0 per entry'),
           (0xF0A826,0xF0FFFF,'free ROM - the monitor is patched here')]

# ---- sites worth a note, from this session's analysis --------------------
NOTES = {
 0xF04930:'chassis response handler (vector $41). Latches MODE0 -> $E86, sets ack b10,',
 0xF04A6E:'  then btst #7,$E87 picks the dispatcher: 0 -> this 16-entry table at F05102',
 0xF05102:'16-entry jump table, index = (response & $F) << 2. All 4EFA jmp d16(pc).',
 0xF04A84:'code $0: read CHANNEL_SELECT back. $28 -> bulk transfer, else 0..$10 -> $E5C',
 0xF04AE2:'INBOUND bulk: arm STATUS_IRQ $400, poll b15, clear, move.w $FF0008 -> (a1)+',
 0xF04C50:'OUTBOUND bulk: same port, opposite direction. Selected by $E87 bit 5.',
 0xF04B22:'S-RECORD receiver: two ASCII chars per word from $FF0008, "S0"=$5330',
 0xF04CF2:'code $1: load destination address half; bit 6 picks high/low',
 0xF04D20:'code $2: load word count half; bit 6 picks high/low',
 0xF04D4E:'code $3: paged chassis-memory access. MODE2 <- addr>>20; (addr & $FFFFF)<<2 + $400000',
 0xF04EE4:'code $5: arg 0 reports $105E (AC count); arg N selects channel N',
 0xF04F3A:'code $7: clear IRE (bit 4) of BIM0 CR0 - the chassis can mute the dispatcher',
 0xF050F8:'code $F: return from interrupt - the only slot that unwinds the frame',
 0xF051A2:'SRecordDataHandler. a1 seeds $10; F051DC adds $10000, so RECORD ADDRESSES',
 0xF051DC:'  ARE OFFSETS. Usable record range $0000-$FFEF -> lands $10010-$1FFFF.',
 0xF0520E:'the store, guarded by the $10000-$1FFFF check on the COMPUTED address',
 0xF05218:'REJECT path: drains $FF0008 until APIF_CMD_STATUS reads <= 0 (end of stream)',
 0xF05224:'  ...and only then issues PCMD_CH1_ACK. This is the REJECT exit, not success.',
 0xF05230:'SRecordParseLoop: d4 counts the record body down; at d4 == 1 the last byte',
 0xF05250:'  (the CHECKSUM) is read into d2 -- and DISCARDED. addq, rts, no comparison.',
 0xF05254:'  SUCCESS exit. The firmware does NOT validate S-record checksums; the',
 0xF056BA:'PanelSendAndWait. a3 = this channel BIM CR: $4F on entry (IRE off), $5F on exit.',
 0xF0572C:'  dispatch on d0 = the latched opcode, into the 42-slot table below',
 0xF05BA4:'42-slot dispatch table. FIVE identical copies exist, one per task region;',
 0xF05C4C:'  PanelErrorMaskTable: channel -> IRQ_MASK bit (ch1..4 = bits 5,4,3,2)',
 0xF05DD6:'TCBIO1I ISR. Reads mailbox $70001C; payload is bits 16-17 of that word.',
 0xF05E40:'  reply: mailbox word with bit 1 set, written to $700020',
 0xF08732:'btst #5,$F70019 - if SET, skip the ENTIRE self-test suite',
 0xF0891C:'PollBoardStatus: bit 4 set AND bit 5 set -> abandon the suite',
 0xF08DF8:'BoardStatusPoll_3F11 - polls (status & $3F31) == $3F11. NEVER reads ROM.',
 0xF098EC:'phase $2000: RAM address uniqueness, move.l a0,(a0)+ over $0-$10000',
 0xF046E0:'4-entry table: XP channel -> BIM control register ($244,$246,$250,$252)',
 # ---- remaining MainInit / self-test blocks ----
 0xF08B5C:'phase $0100 tail: bit-manipulation test. 9 bset.b, 5 bclr.b, 1 bchg.b, 1 asl.l,',
 0xF08B88:'  each guarded by the $F0F0F0F0 error flag and a PollBoardStatus call.',
 0xF08832:'SECOND CHECKPOINT: $1FFF0 <- $D0, then the board-status branch that selects',
 0xF08854:'  the next block -- bit4 clear + bit5 clear -> block 2, bit4 clear + bit5 set',
 0xF0885A:'  -> block 3. See "Control flow and the two checkpoints" in the access map.',
 0xF099EE:'register data-path test: propagate a value d0 -> d1 -> d2 -> d3 -> d4 and',
 0xF09A52:'  check it survives. Not a RAM verify despite sitting beside the RAM tests.',
 # ---- RMS68K segment management ----
 0xF09D98:'SEGMENT TABLE SEARCH: 10-byte entries -- flags byte at +1, start longword at',
 0xF09DA4:'  +2, end longword at +6. Walks until d6, testing whether d2 falls in a range.',
 0xF09DB6:'  On no-match, bsr F0A306, the shared error path.',
 0xF09E88:'builds the !GST global segment table (tag $21475354) ...',
 0xF09ECE:'  ... and the !UST user segment table (tag $21555354)',
 0xF0A306:'SHARED ERROR PATH. Saves context to $800 (g_ctx_save). Reached two ways:',
 0xF0A30E:'  by direct bsr from the allocator, and as the "BE" bus-error recovery target',
 # ---- RMS68K bus-error recovery convention ----
 0xF0A44A:'BUS-ERROR GUARD: pea <recovery>(pc) then move.w #$4245,-(a7). $4245 is ASCII',
 0xF0A44E:'  "BE" -- the RMS68K bus error return flag (rms68k_source.SA: PEA KILLER(PC) /',
 0xF0A452:'  MOVE.W #\'BE\',-(A7)). The kernel handler finds the marker on the stack and',
 0xF0A456:'  resumes at the address below it instead of panicking. Five app sites: F09D0E,',
 0xF0A468:'  F0A290, F0A39E, F0A414, F0A44A; plus F00D02/F01F06/F03E40 in the kernel.',
 # ---- XP task startup (TCBXP1I is the template; the other three copy it) ----
 0xF07DC2:'XP task startup: a chain of guarded RMS68K syscalls. Each step tests the',
 0xF07DC8:'  result and, on failure, loads a PANEL CODE IDENTIFYING THE STEP and aborts',
 0xF07DD6:'  via the local panel issuer. $26E = step 1/2, $270 = step 3, $271 = step 4/5.',
 0xF07DDE:'  trap #1 with d0 = $4C. RMS68K directive numbers seen here: $4C, $2B, $13,',
 0xF07DF6:'  $11 and $0F. Only $0F is identified: 15 = TERM, terminate task, per the',
 0xF07E00:'  RMS68K source. Note this confirms $26E-$271 are per-STEP, not per-channel.',
 # ---- RTOSKernelInit ----
 0xF0A146:'RTOSKernelInit vector fill: install the panic catch-all F0A27A across every',
 0xF0A150:'  user vector $124-$3FF -- EXCEPT $230 (vector 140), which is stepped over and',
 0xF0A15E:'  keeps the RMS68K generic handler F00896. Whatever raises vector 140 is meant',
 0xF0A160:'  to be serviced, not panicked on; which device that is, is not established.',
 0xF0A164:'BIM programming: zero six control registers, then load ten vector registers',
 0xF0A18E:'  with $41-$4A. Each task later enables its own channel by writing $5F (or $5E',
 0xF0A1CA:'  for BIM0 ch0) to its CR -- see the BIM channel table in the access map.',
 # ---- TCBRDHC host command interface: 4-way dispatch on a 3-bit code ----
 0xF05344:'HOST COMMAND DISPATCH: andi #7,d1; subq #1; mulu #6; jmp (F05358,d1.w).',
 0xF05358:'  4-entry jump table, jmp abs.l per entry. Codes 1-4 only; 5-7 fall into code',
 0xF05370:'  cmd 1: attach/configure a channel. Defaults d4 from $E62, validates',
 0xF05384:'    1 <= channel <= $105E, then $1080[ch] = &$101E, $10A0[ch] = 2, and',
 0xF053B6:'    builds the ASQ name from $48585030 = "HXP0" + channel',
 0xF054A2:'  cmd 2: register-file copy to/from $101E. Descriptor = direction, index,',
 0xF054D4:'    count; the exg a1,a0 makes one loop serve both directions',
 0xF054E8:'  cmd 3: same shape, block at $E8A',
 0xF05502:'  cmd 4: start a transfer - load count into $E64, then bset #4 on DATA_HI',
 0xF05678:'  shared exit: restore MODE2 from the stack (every handler saves it on entry)',
 0xF05684:'  moveq #$F,d0 / trap #1 - RMS68K directive $F',
 # ---- self-test phase entry points (d6 = phase, written to CHANNEL_SELECT) ----
 0xF08C4A:'phase $0200: VMOD bit 6 <-> board-status bit 3 inverse wiring',
 0xF08D1A:'phase $0300: ROM readback walk $F00000-$F10000',
 0xF08D5E:'phase $0400: RAMAddressingTest - no aliasing between $8000 and $10000',
 0xF08DF8:'phase $0500: BoardStatusPoll_3F11 - (status & $3F31) == $3F11. NEVER reads ROM.',
 0xF08E2E:'phase $0600: VMOD longword pattern walk, 8 patterns from F08E8C',
 0xF08F1C:'phase $0700: short-I/O probe at $F82001 - the BUS ERROR is the expected result',
 0xF08F70:'phase $0800: IOChannelDiagnostic',
 0xF0905A:'phase $0900: PTM interrupt test - vector $150, all three timers latch $0FFF',
 0xF08EAC:'phase $1000: MemBusProbe - address-space boundary map',
 0xF0918C:'phase $1100: panel bus, VMOD bit 4 -> board-status bit 1',
 0xF09236:'phase $1200: level-2 chassis interrupt via vector $14C',
 0xF09338:'phase $1300: dual-vector interrupt, vectors $148 and $140',
 0xF093CE:'phase $1400: panel-bus interrupt with board-status confirmation',
 0xF094F0:'phase $1500: CHANNEL_SELECT must be a clean read/write register',
 0xF09518:'phase $1600: XLTR register file walk. STATUS_IRQ b4 = BIM population (16 vs 24)',
 0xF09602:'phase $1700: $400000 window access gating via DATA_HI - expects BERR',
 0xF096AC:'ChassisProbe_Read: ONE read then four NOPs. The padding exists because a 68000',
 0xF096B8:'ChassisProbe_Write: ONE write then four NOPs - same reason: a bus error is',
 0xF096C4:'phase $1800: $400000 gating, second pass with other DATA_HI values',
 0xF09776:'phase $1900: chassis memory data lines, $55555555 / $AAAA5555',
 0xF09832:'phase $1A00: AP I/F window, STATUS_IRQ and COUNTER',
 0xF098EC:'phase $2000: RAM address uniqueness, move.l a0,(a0)+ over $0-$10000',
 0xF09AD6:'phase $2200: chassis block move, $400000 for $4000 bytes, 4 passes',
 0xF09B20:'phase $2300: chassis A14 decode - $400000 and $404000 must be distinct',
 0xF04500:'PanelIOConfigure copy 1/7 - pre-task init. Seven BYTE-IDENTICAL copies of',
 0xF04530:'  this 50-byte routine exist: F04500 F05688 F05E56 F068A8 F072C0 F07CC0 F086C0,',
 0xF05688:'PanelIOConfigure copy 2/7 - TCBRDHC. ...one per task region plus this pre-task one.',
 0xF05E56:'PanelIOConfigure copy 3/7 - TCBIO1I (this one spins inside a level-7 ISR)',
 0xF068A8:'PanelIOConfigure copy 4/7 - TCBXP4I',
 0xF072C0:'PanelIOConfigure copy 5/7 - TCBXP3I',
 0xF07CC0:'PanelIOConfigure copy 6/7 - TCBXP2I',
 0xF086C0:'PanelIOConfigure copy 7/7 - TCBXP1I',
}

src = open(IN).read().split('\n')
out = []
stamp = datetime.date.today().isoformat()
out += [
 '; ============================================================================',
 '; FPS-3000 Control Processor firmware - consolidated disassembly',
 f'; FPS3K_U11_U12_JOIN.bin   MD5 47f133c1c2bab61f887e7e2a92a43dac   built {stamp}',
 '; ============================================================================',
 ';',
 '; THE file to read. Supersedes fps3k_clean.asm. Built by',
 '; tools/mk_consolidated_asm.py from fps3k_custom_annotated.asm.',
 ';',
 '; Symbol names are corrected against the 2026-07-29 findings. Where an',
 '; earlier name was wrong it is NOT preserved, because a half-renamed file is',
 '; worse than either name alone. The notable corrections:',
 ';',
 ';   AP I/F channel window is not write/readA/status/readB.',
 ';     +$08 / +$0A are the HIGH and LOW halves of one 32-bit data register',
 ';     +$0E is a command/trigger register ($8000 fires it)',
 ';     $FF0048 is never read anywhere in this ROM',
 ';   $FF0008 is a bidirectional bulk port with three modes (see F04AE2/F04C50/F04B22)',
 ';   $FF0230-$FF025F are BIM registers, not per-channel config',
 ';   $E60 is the XP channel number, not an S-record count',
 ';   $E64 is a transfer word count, not an expected panel response',
 ';   $E74 is the result register returned to the chassis via CHANNEL_SELECT',
 ';   $E86/$E87 hold the latched chassis response, not a "channel mode"',
 ';   F08DF8 is BoardStatusPoll_3F11, not ROMChecksumTest - it never reads ROM',
 ';',
 '; Task region boundaries are from the ROM\'s own TDTI table at $F0A600, so',
 '; they are authoritative rather than heuristic.',
 ';',
 '; ANNOTATIONS: lines beginning ";>>>>" are Monte Carlo pass output and are',
 '; NOT verified. Lines beginning ";### " are this session\'s findings, each',
 '; traceable to refs_extracted/versabus_access_map.md.',
 '; ============================================================================',
 '']

def io_name(off):
    return IO.get(off)

cur_region = None
n_notes = n_io = n_ram = 0
for line in src:
    m = re.match(r'^\s*(f0[0-9a-f]{4}):', line)
    if m:
        addr = int(m.group(1), 16)
        for lo, hi, name in REGIONS:
            if lo <= addr <= hi and (lo, hi) != cur_region:
                cur_region = (lo, hi)
                out += ['', '; ' + '='*76,
                        f'; ${lo:06X}-${hi:06X}   {name}',
                        '; ' + '='*76]
                break
        if addr in NOTES:
            out.append(';### ' + NOTES[addr]); n_notes += 1
    # symbol substitution on IO offsets written as $xxx(aN)
    def sub_io(mm):
        # Only 3-digit displacements >= $200 are safe to name: those are the
        # XLTR/BIM file, and no other base register in this firmware is
        # indexed that far.  Short displacements like $8(a5) or $4e(a2) are
        # ambiguous -- the base may be a channel window, a TCB, or a stack
        # frame -- so they are left alone rather than mislabelled.
        global n_io
        off = int(mm.group(1), 16)
        if off < 0x200: return mm.group(0)
        nm = io_name(off)
        if nm: n_io += 1; return f'{mm.group(0)}  [{nm}]'
        return mm.group(0)
    line = re.sub(r'\$([0-9a-f]{3})\(a[0-7]\)', sub_io, line)
    def sub_abs(mm):
        global n_io
        v = int(mm.group(1), 16)
        nm = IO.get(v & 0xFFFF)
        if nm and (v & 0xFF0000) == 0xFF0000: n_io += 1; return f'{mm.group(0)}  [{nm}]'
        return mm.group(0)
    line = re.sub(r'\$(ff0[0-9a-f]{3})\b', sub_abs, line)
    def sub_ram(mm):
        global n_ram
        v = int(mm.group(1), 16)
        nm = RAM.get(v)
        if nm: n_ram += 1; return f'{mm.group(0)}  [{nm}]'
        return mm.group(0)
    line = re.sub(r'\$([0-9a-f]{4,6})\.l\b', sub_ram, line)
    out.append(line)

open(OUT, 'w').write('\n'.join(out))
print(f'wrote {OUT}: {len(out)} lines, {n_notes} finding notes, {n_io} I/O symbols, {n_ram} RAM symbols')
