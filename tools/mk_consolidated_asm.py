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
_NOTE_PAIRS = [
 # ---- the chassis command language: all 16 operations ----
 (0xF05102,'THE CHASSIS COMMAND TABLE, all 16 entries now decoded (was 2 of 16).'),
 (0xF05102,'  The command byte is the LOW BYTE OF XLTR_MODE0, saved at $E86/$E87:'),
 (0xF05102,'    bits 0-3 operation (this table)     bit 5 direction (0 write, 1 read)'),
 (0xF05102,'    bit 4 auto-increment $E7A           bit 6 half select of a 32-bit param'),
 (0xF05102,'    bit 7 selects the OTHER dispatcher $F0495C'),
 (0xF05102,'  So $01/$41 were always op 1 with bit 6 clear/set (address low/high),'),
 (0xF05102,'  and $02/$42 op 2 for the count.  The operations:'),
 (0xF05102,'    $0 F04A84 validate/arm transfer      $8 F04F52 CH1 reset when idle'),
 (0xF05102,'    $1 F04CF2 set address half           $9 F04FA0 set third param $E68/$E6A'),
 (0xF05102,'    $2 F04D20 set count half             $A F04FBA read word array $1064'),
 (0xF05102,'    $3 F04D4E read CHASSIS memory        $B F05002 return staging base $10010'),
 (0xF05102,'    $4 F04E3A validate channel $E60      $C F0502C read long array $1020'),
 (0xF05102,'    $5 F04EE4 validate CHANNEL_SELECT    $D F05092 validate chsel 0..$F'),
 (0xF05102,'    $6 F04F30 read/WRITE SBC RAM         $E F050CA CLEAR BUSY (MODE1 bit 7)'),
 (0xF05102,'    $7 F04F3A mask BIM0 ch0 (IRE)        $F F050F8 end of conversation (RTE)'),
 (0xF05102,'  op $E is the XPRUN clear-busy primitive; op $B is the S-record staging'),
 (0xF05102,'  base, so the chassis can ASK where microcode goes; and op $F is $F050F8,'),
 (0xF05102,'  whose exit stub $F050FC is exactly what !IDV gives for RDHC.'),
 (0xF04D70,'OP $3 -- THE SBC READS CHASSIS MEMORY.  page = addr >> $14 into MODE2'),
 (0xF04D70,'  ($FF0210), offset = (addr & $FFFFF) << 2, read through the $400000'),
 (0xF04D70,'  window.  So MODE2 is the PAGE REGISTER for that window and the window'),
 (0xF04D70,'  is longword-addressed.  This is the SBC read path into System Common'),
 (0xF04D70,'  Memory -- the one direction of the data path that had no mechanism.'),
 (0xF04EC0,'OP $6 WRITE ARM -- THIS IS HOW $10AA GETS WRITTEN.  The chassis sets an'),
 (0xF04EC0,'  address with op $1 and issues op $6; the SBC\'s OWN CPU does the store.'),
 (0xF04EC0,'  Demonstrated: FPS3K_SEQ="01:10AA,06:0002" ->'),
 (0xF04EC0,'    [RAMWATCH] write 0010AA <- 00 from PC=F04EC0'),
 (0xF04EC0,'    [RAMWATCH] write 0010AB <- 02 from PC=F04EC0'),
 (0xF04EC0,'  This SUPERSEDES the bus-master conclusion: that argument\'s premises were'),
 (0xF04EC0,'  right but it was too narrow.  Prior watchpoints missed this because'),
 (0xF04EC0,'  RDHC\'s dispatcher was never driven with op $6 -- the instrument could'),
 (0xF04EC0,'  not fire.  Note $F05E12 reads $10AA as a LONGWORD against 2 while op $6'),
 (0xF04EC0,'  writes 16 bits, so the chassis must target $10AC to set the gate.'),
 (0xF04EB8,'OP $6 READ ARM: bit 5 set returns SBC RAM at $E58 to the chassis in $E74.'),
 # ---- what the eight structures actually hold, read out of RAM ----
 (0xF09F70,'!IDV is the INTERRUPT-DEVICE TABLE and it is the whole IRQ wiring of the'),
 (0xF09F70,'  machine in 84 bytes: six 14-byte records from +$08, each'),
 (0xF09F70,'  {vector word, TCB pointer, ISR entry, ISR exit}.  Measured:'),
 (0xF09F70,'    $45 $1E900 XP1I F07EE6 F07F08     $48 $1EF00 XP4I F060CE F060F0'),
 (0xF09F70,'    $46 $1EB00 XP2I F074E6 F07508     $4A $1F100 IO1I F05DD6 F05E4C'),
 (0xF09F70,'    $47 $1ED00 XP3I F06AE6 F06B08     $41 $1F300 RDHC F04930 F050FC'),
 (0xF09F70,'  The entry column matches the six handlers assembled by hand from the BIM'),
 (0xF09F70,'  vector registers.  The exit column is new -- and $F05E4C in it is the'),
 (0xF09F70,'  address already independently named ISRExit, which pins the field.'),
 (0xF09FA2,'!PAT is a FREE-LIST, not a table: +$04 is a first-record pointer (a third'),
 (0xF09FA2,'  header shape), records chained through their first longword at stride'),
 (0xF09FA2,'  $1E with $FFFFFFFF at +$04.  $1F714 -> ... -> $1F7E6 -> NULL, 8 records,'),
 (0xF09FA2,'  8*$1E + $14 = 254 of the 256-byte page.  The WHOLE page is free, i.e.'),
 (0xF09FA2,'  nothing has ever taken a record from it in any configuration reached.'),
 (0xF09EBE,'!UST is the ASQ NAME REGISTRY.  Rich header: +$0A pages, +$0C record size,'),
 (0xF09EBE,'  +$0E records in use, +$10 first record at base+$14.  Nine $16-byte'),
 (0xF09EBE,'  (task name, ASQ name) pairs: XP1I/AXP1 XP1I/HXP1 XP2I/AXP2 XP2I/HXP2'),
 (0xF09EBE,'  XP3I/AXP3 XP3I/HXP3 XP4I/AXP4 XP4I/HXP4 IO1I/HIO1.  2+2+2+2+1+0 = 9 --'),
 (0xF09EBE,'  a THIRD independent confirmation of the per-task ASQ counts, and the'),
 (0xF09EBE,'  first that is a plain readable list rather than an inference.'),
 (0xF09E78,'!GST uses the same rich header with $D-byte records and ZERO in use.'),
 (0xF09EFE,'Of the eight structures, four are populated (!UST, !IDV, !PAT free list,'),
 (0xF09EFE,'  !VCT) and four are allocated-but-unused (!GST, !IOV, !UDR, $1F500).'),
 # ---- the two untagged structures ----
 (0xF09F1C,'!VCT BUILD.  a2 = $28 (the exception vector table); the loop writes ONE'),
 (0xF09F1C,'  BYTE PER VECTOR up to $400, and the 10 bytes of $FF written just above'),
 (0xF09F1C,'  cover vectors 0-9.  So byte k of the block at $1FA00 IS vector number k.'),
 (0xF09F26,'  $FF marks a vector that differs from the reference handler in a4.'),
 (0xF09F26,'  Later the kernel at $F0226A (directive $4C, connect vector) overwrites'),
 (0xF09F26,'  each connected byte with the OWNING TASK NUMBER.  Measured: $41->6 RDHC,'),
 (0xF09F26,'  $45->1 XP1I, $46->2, $47->3, $48->4, $4A->5 IO1I, and the four orphan'),
 (0xF09F26,'  BIM vectors $42/$43/$44/$49 read 0.  This is the !VCT instance, untagged,'),
 (0xF09F26,'  and it fixes the task numbering the ROM never states: XP1I=1 .. RDHC=6.'),
 (0xF0A030,'RECORD POOL, the other untagged structure ($0C30 -> $1F500).  Instead of a'),
 (0xF0A030,'  marker tag this site writes a two-pointer header: first = base+8, and'),
 (0xF0A030,'  last = first + ((size*256 - 8) div $1A) * $1A -- a divu/mulu pair that'),
 (0xF0A030,'  rounds DOWN to whole $1A-byte records.  One page gives 9 records,'),
 (0xF0A030,'  first=$1F508 last=$1F5F2, which is what RAM holds.  Untagged and'),
 (0xF0A030,'  unchanged in every configuration reached so far; by elimination it is'),
 (0xF0A030,'  !CCB or !DLY, and the $1A record size is the discriminator.'),
 # ---- the RTOS page allocator (TRAP #0 directive $04), 8 sites ----
 (0xF09E78,'ALLOCATOR SITE 1/8 -- TRAP #0 directive $04 is the RTOS PAGE ALLOCATOR.'),
 (0xF09E78,'  Size (in 256-byte pages) goes in via a0; the block comes back in a0.'),
 (0xF09E78,'  Each of the eight sites then: registers the pointer in a directory slot,'),
 (0xF09E78,'  stamps the marker tag at +$00, and writes end = base + (size<<8) - 1 at +$04.'),
 (0xF09E78,'  THIS IS WHY every RTOS structure sits at a $1Fx00 boundary and the TCBs'),
 (0xF09E78,'  stride by $200: the allocation unit is 256 bytes.  -> $0C20, tag !GST'),
 (0xF09EBE,'ALLOCATOR SITE 2/8 -> slot $0C24, tag !UST ($F09ECE), observed $1FB00'),
 (0xF09EFE,'ALLOCATOR SITE 3/8 -> slot $0C66, NO tag stamped, observed $1FA00'),
 (0xF09F42,'ALLOCATOR SITE 4/8 -> slot $0C6A, tag !IOV ($F09F52), observed $1F900'),
 (0xF09F70,'ALLOCATOR SITE 5/8 -> slot $0C6E, tag !IDV ($F09F80), observed $1F800'),
 (0xF09FA2,'ALLOCATOR SITE 6/8 -> slot $0C2C, tag !PAT ($F09FB2), observed $1F700'),
 (0xF09FF0,'ALLOCATOR SITE 7/8 -> slot $0C28, tag !UDR ($F0A000), observed $1F600'),
 (0xF0A020,'ALLOCATOR SITE 8/8 -> slot $0C30, NO tag stamped, observed $1F500'),
 (0xF09F3C,'The beq guard: a zero size means the structure is not created at all.'),
 (0xF09F3C,'  That is the configuration knob -- all eight sizes are pc-relative ROM'),
 (0xF09F3C,'  constants, so the structure inventory is fixed at build time.'),
 # ---- 2026-07-29 second pass: task structure, RTOS surface, channel path ----
 (0xF0A332,'BulkClear: zeroes (d2 << 8) bytes ending at a0, working downward. The loop'),
 (0xF0A33C,'  body is here -- this is the address CLAUDE.md cites for the $10AA zeros;'),
 (0xF0A33C,'  it is not a separate routine. $F0A1D2 is the same shape.'),
 (0xF05652,'issues directives $29 and $2A as a MATCHED PAIR with a stack-built PB (word'),
 (0xF05664,'  $0002, zero longword, d1). RDHC-exclusive; called twice; purpose still open.'),
 (0xF07F56,'post-poll: btst #$D,d4 -- bit 13 = transfer ERROR -> $269 abort + spin.'),
 (0xF07F84,'CHANNEL COMMAND DISPATCH: lsl.w #2,d0 / lea $F083FC,a4 / jmp (a4,d0.w).'),
 (0xF083FC,'42 x 4-byte DISPATCH TABLE, $F083FC-$F084A3 -- the exact twin of RDHC\'s'),
 (0xF083FC,'  PanelStatusDispatchTable at $F05BA4-$F05C4B: same 42 entries, same 4-byte'),
 (0xF083FC,'  stubs, same d0<<2 index, same 4 handlers. Indexed by d0 -- which'),
 (0xF083FC,'  on the acknowledged path is the RETURN VALUE of the trap #1 at $F07F0E'),
 (0xF083FC,'  (directive $0F), NOT a channel command word: all three d0 writes between'),
 (0xF083FC,'  there and here sit on the timeout or error paths. Sixteen indices'),
 (0xF08400,'  onto 4 handlers: $F0810A x10, $F0826A x9, $F08366 x9, $F07F90 x1, and'),
 (0xF08404,'  13 rts entries with no handler. Measured d0 = $0E and $10, so only two'),
 (0xF08408,'  of the 42 indices are exercised. An earlier note said 16 entries and 3'),
 (0xF0840C,'  handlers -- that read only the first 16 and assumed the size from the'),
 (0xF08410,'  WRONG table ($F05102 is the 16-entry one).'),
 (0xF0810A,'channel dispatch handler A -- 9 of the 16 codes land here.'),
 (0xF08366,'channel dispatch handler B -- codes 8 and 9.'),
 (0xF0826A,'dispatch handler C -- indices 1 and 10. NOT executed: needs directive $0F'),
 (0xF0826A,'  to return 1 or 10, which is a KERNEL condition -- no chassis model reaches it.'),
 (0xF0891C,'SELF-TEST CHECKPOINT -- the MOST-CALLED routine in the ROM, 65 calls, all'),
 (0xF0891C,'  from the init/test region: once per subtest. Reads board status $F70018,'),
 (0xF08936,'  tests d7 (the $F0F0F0F0 error flag) and on failure CLEARS VMOD ctrl bit 6'),
 (0xF08940,'  at $1FFF1 and writes $1000 to XLTR MODE1. This is where a failed subtest'),
 (0xF08946,'  becomes externally visible; the beacon at $FF0204 says WHICH subtest.'),
 (0xF04500,'PANEL-COMMAND ISSUER, copy 1 of 8. All 8 are byte-identical over 48 bytes:'),
 (0xF04506,'  stash d0 at $E6E, cmd -> $FF000E, MODE1 b14 clr / b12 set, MODE0 b10 clr,'),
 (0xF04530,'  CHANNEL_SELECT <- d0, then "bra ." -- escape only via F04930 rewriting the PC.'),
 (0xF0467E,'6-entry x 8-byte NAME TABLE: XP1I XP2I XP3I XP4I USER USER. Used by directive $12.'),
 (0xF046B0,"RDHC's directive-$01 block (NOT base+$14 as the other five tasks use)."),
 (0xF046E0,'BIM CR TABLE: $244 $246 $250 $252 = XP1I..XP4I control registers, channel order.'),
 (0xF046F0,'RDHC ENTRY (TDTI +$1C). Prologue is 3 calls: $01, $4C, then $13 -- no ASQ attach.'),
 (0xF04730,'RDHC enables its OWN BIM at LEVEL 6 ($5E). This is why it can never preempt a'),
 (0xF04736,'  level-7 channel ISR -- the deadlock behind the $281 stall. Set by the ROM, not straps.'),
 (0xF04774,'directive $0B, PB at $F04614 (RDHC header +$14). RDHC-exclusive.'),
 (0xF047C0,'directive $0D, PB at $F04630 (RDHC header +$30). RDHC-exclusive.'),
 (0xF04854,'directive $12 x5 from the name table above: XP4I, XP3I, XP2I, XP1I, then USER.'),
 (0xF04884,'  RDHC is the ONLY code in this ROM that addresses the XP tasks by name.'),
 (0xF050FC,'ISR EXIT SEQUENCE, five of six tasks: move #$0C,ccr / trap #1 / moveq #$0F,d0'),
 (0xF050FC,'  / trap #1. RDHC is the exception -- it traps then jmp back into its own code.'),
 (0xF050FC,'ISR EXIT STUB (task descriptor +$10): move #$0C,ccr / trap #1. Identical in all 6'),
 (0xF05100,'  tasks. NOT directive-numbered -- the CCR is the argument; d0 is never loaded.'),
 (0xF053B6,"move.l #'HXP0',d1 then add.b d4,d1 -> HXP1..HXP4. RDHC BUILDS the queue name."),
 (0xF05688,'panel-command issuer, copy 2 of 8 (the "PanelIOCommand processor").'),
 (0xF05DD6,'TCBIO1I ISR. Two arms, selected by mailbox bit 29 at $F05DF8.'),
 (0xF05DF8,'  bit 29 SET -> $F05DFA, issues $281 PCMD_HOST_REQUEST and DEADLOCKS in the spin.'),
 (0xF05E12,'  bit 29 CLEAR -> dispatch on $10AA: 0 -> $282 PCMD_HOST_NULL, 2 -> reply path.'),
 (0xF05E2C,'  reply path: swap + andi #3 on the mailbox word. Class bits 16-17 must read 1;'),
 (0xF05E40,'  0, 2 and 3 write nothing. Verified: class 1 -> reply $00010002 to $700020.'),
 (0xF05E4C,'TCBIO1I ISR exit stub (descriptor +$10).'),
 (0xF05E56,'panel-command issuer, copy 3 of 8 -- the one TCBIO1I calls from inside its ISR.'),
 (0xF05E86,'  THE SPIN. At level 7 the level-6 responder F04930 can never break it: measured'),
 (0xF07D00,'TASK DESCRIPTOR = the whole prologue\'s parameter block. +$08 vector, +$0C ISR'),
 (0xF07D14,'  entry, +$10 ISR exit stub (directive $4C); +$14 directive-$01 block (name,'),
 (0xF07D2C,'  flags, STCK, $190 stack); +$2C and +$36 two 10-byte ASQ entries (AXP1/HXP1).'),
 (0xF07DF6,'PRESENCE GATE: cmpi.w #<own channel>,$105E / blt skip. $105E is the count of'),
 (0xF07DFE,'  channels the chassis presents, written by the CPU at $F0A224. Task n runs if count>=n.'),
 (0xF07E42,'jsr to the channel scan at $F08616.'),
 (0xF07E4C,'command-word dispatch, bit 15 (on $1066 = the ISR\'s snapshot of $FF004E).'),
 (0xF07E86,'  bit 14. Reaching the $8000 path needs bits 15, 14 AND 11 -- verified by sweep.'),
 (0xF07EB6,'  bit 11, the last gate.'),
 (0xF07EC0,'$8000 PATH: data pair <- $0000001B, then $8000 to the command port. Present in'),
 (0xF07ED0,'  XP1I/2/3 only -- 3 sites in the whole ROM. XP4I has no bit-11 test and no $8000.'),
 (0xF07EE6,'XP1I CHANNEL ISR. Snapshots the channel into its 6-byte RAM block:'),
 (0xF07EF6,'  $4E->$1066, $48->$1068, $4A->$106A. NOTE: $FF0048 IS READ, here, as $48(a5).'),
 (0xF07F08,'XP1I ISR exit stub (descriptor +$10).'),
 (0xF07F22,'  then BIM CR $4F (IRE clear), data pair, $8004 REQUEST-TRANSFER, poll.'),
 (0xF08616,'CHANNEL SCAN: move.w $4E(a2,d4.l),d2 / btst #15 / btst #14 / add $20 to d4 /'),
 (0xF0861E,'  loop while d3 <= $105E. Confirms $20 stride and $105E as the channel count.'),
 (0xF086C0,'panel-command issuer, copy 7 of 8 -- the jsr target all over XP1I.'),
 (0xF09BB6,'diagnostics RAM-pattern table: 00000000 FFFFFFFF 55555555 AAAAAAAA.'),
 (0xF0A164,'BIM PROGRAMMING: clears 6 CRs, then writes TEN vector registers $41-$4A across'),
 (0xF0A18E,'  all three BIMs. Six channels are enabled; $42,$43,$44,$49 are vectored but'),
 (0xF0A1CA,'  disabled and have NO handler in any task descriptor.'),
 (0xF0A202,'CHANNEL-PRESENT PROBE: read $FF004E/$6E/$8E/$AE, count the nonzero ones,'),
 (0xF0A224,'  store to $105E. This is the CPU writing $105E -- it is not chassis DMA.'),
 (0xF0A57E,'panel-command issuer, copy 8 of 8 -- THE PANIC PATH. All nine CPU-exception'),
 (0xF0A57E,'  handlers at $F0A23A bra.w here with their code in d0, so the last value at'),
 (0xF0A57E,'  $FF000E names the exception: $29E bus error .. $2A6 catch-all. NOT the TCB'),
 (0xF0A57E,'  table -- that is $F0A600.'),
 (0xF0A600,'TDTI TABLE. Per entry: name +$04, entry point +$1C, region start/end high words'),
 (0xF0A620,'  at +$20/+$22, PROG marker +$40. The six regions partition $F04600-$F086FF exactly.'),
 (0xF04930,'chassis response handler (vector $41). Latches MODE0 -> $E86, sets ack b10,'),
 (0xF04A6E,'  then btst #7,$E87 picks the dispatcher: 0 -> this 16-entry table at F05102'),
 (0xF05102,'16-entry jump table, index = (response & $F) << 2. All 4EFA jmp d16(pc).'),
 (0xF04A84,'code $0: read CHANNEL_SELECT back. $28 -> bulk transfer, else 0..$10 -> $E5C'),
 (0xF04AE2,'INBOUND bulk: arm STATUS_IRQ $400, poll b15, clear, move.w $FF0008 -> (a1)+'),
 (0xF04C50,'OUTBOUND bulk: same port, opposite direction. Selected by $E87 bit 5.'),
 (0xF04B22,'S-RECORD receiver: two ASCII chars per word from $FF0008, "S0"=$5330'),
 (0xF04CF2,'code $1: load destination address half; bit 6 picks high/low'),
 (0xF04D20,'code $2: load word count half; bit 6 picks high/low'),
 (0xF04D4E,'code $3: paged chassis-memory access. MODE2 <- addr>>20; (addr & $FFFFF)<<2 + $400000'),
 (0xF04EE4,'code $5: arg 0 reports $105E (AC count); arg N selects channel N'),
 (0xF04F3A,'code $7: clear IRE (bit 4) of BIM0 CR0 - the chassis can mute the dispatcher'),
 (0xF050F8,'code $F: return from interrupt - the only slot that unwinds the frame'),
 (0xF051A2,'SRecordDataHandler. a1 seeds $10; F051DC adds $10000, so RECORD ADDRESSES'),
 (0xF051DC,'  ARE OFFSETS. Usable record range $0000-$FFEF -> lands $10010-$1FFFF.'),
 (0xF0520E,'the store, guarded by the $10000-$1FFFF check on the COMPUTED address'),
 (0xF05218,'REJECT path: drains $FF0008 until APIF_CMD_STATUS reads <= 0 (end of stream)'),
 (0xF05224,'  ...and only then issues PCMD_CH1_ACK. This is the REJECT exit, not success.'),
 (0xF05230,'SRecordParseLoop: d4 counts the record body down; at d4 == 1 the last byte'),
 (0xF05250,'  (the CHECKSUM) is read into d2 -- and DISCARDED. addq, rts, no comparison.'),
 (0xF05254,'  SUCCESS exit. The firmware does NOT validate S-record checksums; the'),
 (0xF056BA,'PanelSendAndWait. a3 = this channel BIM CR: $4F on entry (IRE off), $5F on exit.'),
 (0xF0572C,'  dispatch on d0 = the latched opcode, into the 42-slot table below'),
 (0xF05BA4,'42-slot dispatch table. FIVE identical copies exist, one per task region;'),
 (0xF05C4C,'  PanelErrorMaskTable: channel -> IRQ_MASK bit (ch1..4 = bits 5,4,3,2)'),
 (0xF05DD6,'TCBIO1I ISR. Reads mailbox $70001C; payload is bits 16-17 of that word.'),
 (0xF05E40,'  reply: mailbox word with bit 1 set, written to $700020'),
 (0xF08732,'btst #5,$F70019 - if SET, skip the ENTIRE self-test suite'),
 (0xF0891C,'PollBoardStatus: bit 4 set AND bit 5 set -> abandon the suite'),
 (0xF08DF8,'BoardStatusPoll_3F11 - polls (status & $3F31) == $3F11. NEVER reads ROM.'),
 (0xF098EC,'phase $2000: RAM address uniqueness, move.l a0,(a0)+ over $0-$10000'),
 (0xF046E0,'4-entry table: XP channel -> BIM control register ($244,$246,$250,$252)'),
 # ---- remaining MainInit / self-test blocks ----
 (0xF08B5C,'phase $0100 tail: bit-manipulation test. 9 bset.b, 5 bclr.b, 1 bchg.b, 1 asl.l,'),
 (0xF08B88,'  each guarded by the $F0F0F0F0 error flag and a PollBoardStatus call.'),
 (0xF08832,'SECOND CHECKPOINT: $1FFF0 <- $D0, then the board-status branch that selects'),
 (0xF08854,'  the next block -- bit4 clear + bit5 clear -> block 2, bit4 clear + bit5 set'),
 (0xF0885A,'  -> block 3. See "Control flow and the two checkpoints" in the access map.'),
 (0xF099EE,'register data-path test: propagate a value d0 -> d1 -> d2 -> d3 -> d4 and'),
 (0xF09A52,'  check it survives. Not a RAM verify despite sitting beside the RAM tests.'),
 # ---- RMS68K segment management ----
 (0xF09D98,'SEGMENT TABLE SEARCH: 10-byte entries -- flags byte at +1, start longword at'),
 (0xF09DA4,'  +2, end longword at +6. Walks until d6, testing whether d2 falls in a range.'),
 (0xF09DB6,'  On no-match, bsr F0A306, the shared error path.'),
 (0xF09E88,'builds the !GST global segment table (tag $21475354) ...'),
 (0xF09ECE,'  ... and the !UST user segment table (tag $21555354)'),
 (0xF0A306,'SHARED ERROR PATH. Saves context to $800 (g_ctx_save). Reached two ways:'),
 (0xF0A30E,'  by direct bsr from the allocator, and as the "BE" bus-error recovery target'),
 # ---- RMS68K bus-error recovery convention ----
 (0xF0A44A,'BUS-ERROR GUARD: pea <recovery>(pc) then move.w #$4245,-(a7). $4245 is ASCII'),
 (0xF0A44E,'  "BE" -- the RMS68K bus error return flag (rms68k_source.SA: PEA KILLER(PC) /'),
 (0xF0A452,'  MOVE.W #\'BE\',-(A7)). The kernel handler finds the marker on the stack and'),
 (0xF0A456,'  resumes at the address below it instead of panicking. Five app sites: F09D0E,'),
 (0xF0A468,'  F0A290, F0A39E, F0A414, F0A44A; plus F00D02/F01F06/F03E40 in the kernel.'),
 # ---- XP task startup (TCBXP1I is the template; the other three copy it) ----
 (0xF07DC2,'XP task startup: a chain of guarded RMS68K syscalls. Each step tests the'),
 (0xF07DC8,'  result and, on failure, loads a PANEL CODE IDENTIFYING THE STEP and aborts'),
 (0xF07DD6,'  via the local panel issuer. $26E = step 1/2, $270 = step 3, $271 = step 4/5.'),
 (0xF07DDE,'  trap #1 with d0 = $4C. RMS68K directive numbers seen here: $4C, $2B, $13,'),
 (0xF07DF6,'  $11 and $0F. RETRACTED: "$0F = 15 = TERM (terminate task)" is a numeric'),
 (0xF07DF6,'  coincidence with the RMS68K source and does not fit. $0F is called exactly'),
 (0xF07DF6,'  once per task, at the TAIL OF THE ISR-EXIT PATH in five of six tasks --'),
 (0xF07DF6,'  terminating the task there would end it on its first interrupt.'),
 (0xF07E00,'  RMS68K source. Note this confirms $26E-$271 are per-STEP, not per-channel.'),
 # ---- RTOSKernelInit ----
 (0xF0A146,'RTOSKernelInit vector fill: install the panic catch-all F0A27A across every'),
 (0xF0A150,'  user vector $124-$3FF -- EXCEPT $230 (vector 140), which is stepped over and'),
 (0xF0A15E,'  keeps the RMS68K generic handler F00896. Whatever raises vector 140 is meant'),
 (0xF0A160,'  to be serviced, not panicked on; which device that is, is not established.'),
 (0xF0A164,'BIM programming: zero six control registers, then load ten vector registers'),
 (0xF0A18E,'  with $41-$4A. Each task later enables its own channel by writing $5F (or $5E'),
 (0xF0A1CA,'  for BIM0 ch0) to its CR -- see the BIM channel table in the access map.'),
 # ---- TCBRDHC host command interface: 4-way dispatch on a 3-bit code ----
 (0xF05344,'HOST COMMAND DISPATCH: andi #7,d1; subq #1; mulu #6; jmp (F05358,d1.w).'),
 (0xF05358,'  4-entry jump table, jmp abs.l per entry. Codes 1-4 only; 5-7 fall into code'),
 (0xF05370,'  cmd 1: attach/configure a channel. Defaults d4 from $E62, validates'),
 (0xF05384,'    1 <= channel <= $105E, then $1080[ch] = &$101E, $10A0[ch] = 2, and'),
 (0xF053B6,'    builds the ASQ name from $48585030 = "HXP0" + channel'),
 (0xF054A2,'  cmd 2: register-file copy to/from $101E. Descriptor = direction, index,'),
 (0xF054D4,'    count; the exg a1,a0 makes one loop serve both directions'),
 (0xF054E8,'  cmd 3: same shape, block at $E8A'),
 (0xF05502,'  cmd 4: start a transfer - load count into $E64, then bset #4 on DATA_HI'),
 (0xF05678,'  shared exit: restore MODE2 from the stack (every handler saves it on entry)'),
 (0xF05684,'  moveq #$F,d0 / trap #1 - RMS68K directive $F'),
 # ---- self-test phase entry points (d6 = phase, written to CHANNEL_SELECT) ----
 (0xF08C4A,'phase $0200: VMOD bit 6 <-> board-status bit 3 inverse wiring'),
 (0xF08D1A,'phase $0300: ROM readback walk $F00000-$F10000'),
 (0xF08D5E,'phase $0400: RAMAddressingTest - no aliasing between $8000 and $10000'),
 (0xF08DF8,'phase $0500: BoardStatusPoll_3F11 - (status & $3F31) == $3F11. NEVER reads ROM.'),
 (0xF08E2E,'phase $0600: VMOD longword pattern walk, 8 patterns from F08E8C'),
 (0xF08F1C,'phase $0700: short-I/O probe at $F82001 - the BUS ERROR is the expected result'),
 (0xF08F70,'phase $0800: IOChannelDiagnostic'),
 (0xF0905A,'phase $0900: PTM interrupt test - vector $150, all three timers latch $0FFF'),
 (0xF08EAC,'phase $1000: MemBusProbe - address-space boundary map'),
 (0xF0918C,'phase $1100: panel bus, VMOD bit 4 -> board-status bit 1'),
 (0xF09236,'phase $1200: level-2 chassis interrupt via vector $14C'),
 (0xF09338,'phase $1300: dual-vector interrupt, vectors $148 and $140'),
 (0xF093CE,'phase $1400: panel-bus interrupt with board-status confirmation'),
 (0xF094F0,'phase $1500: CHANNEL_SELECT must be a clean read/write register'),
 (0xF09518,'phase $1600: XLTR register file walk. STATUS_IRQ b4 = BIM population (16 vs 24)'),
 (0xF09602,'phase $1700: $400000 window access gating via DATA_HI - expects BERR'),
 (0xF096AC,'ChassisProbe_Read: ONE read then four NOPs. The padding exists because a 68000'),
 (0xF096B8,'ChassisProbe_Write: ONE write then four NOPs - same reason: a bus error is'),
 (0xF096C4,'phase $1800: $400000 gating, second pass with other DATA_HI values'),
 (0xF09776,'phase $1900: chassis memory data lines, $55555555 / $AAAA5555'),
 (0xF09832,'phase $1A00: AP I/F window, STATUS_IRQ and COUNTER'),
 (0xF098EC,'phase $2000: RAM address uniqueness, move.l a0,(a0)+ over $0-$10000'),
 (0xF09AD6,'phase $2200: chassis block move, $400000 for $4000 bytes, 4 passes'),
 (0xF09B20,'phase $2300: chassis A14 decode - $400000 and $404000 must be distinct'),
 (0xF04500,'PanelIOConfigure copy 1/7 - pre-task init. Seven BYTE-IDENTICAL copies of'),
 (0xF04530,'  this 50-byte routine exist: F04500 F05688 F05E56 F068A8 F072C0 F07CC0 F086C0,'),
 (0xF05688,'PanelIOConfigure copy 2/7 - TCBRDHC. ...one per task region plus this pre-task one.'),
 (0xF05E56,'PanelIOConfigure copy 3/7 - TCBIO1I (this one spins inside a level-7 ISR)'),
 (0xF068A8,'PanelIOConfigure copy 4/7 - TCBXP4I'),
 (0xF072C0,'PanelIOConfigure copy 5/7 - TCBXP3I'),
 (0xF07CC0,'PanelIOConfigure copy 6/7 - TCBXP2I'),
 (0xF086C0,'PanelIOConfigure copy 7/7 - TCBXP1I'),
]

NOTES = {}
for _a, _t in _NOTE_PAIRS:
    NOTES.setdefault(_a, []).append(_t)

src = open(IN).read().split('\n')

# ---------------------------------------------------------------------------
# Label corrections applied to the frozen input.  fps3k_custom_annotated.asm
# is not regenerable (its own input was a temp file), so wrong labels have to
# be fixed here by substitution rather than at the source.
#
# TCBDefinitionTable was attached to $F0A57E, which is the EIGHTH copy of the
# panel-command issuer, not a table.  The real !TCB table is at $F0A600.  The
# original label was not baseless: RTOS init locates the table FROM $F0A57E by
# rounding up to the next 256-byte boundary ($F09D30: lea $F0A57E,a3 /
# move.l a3,d1 / addi.l #$FF,d1 / clr.b d1  ->  $F0A600).  So $F0A57E is the
# search base and $F0A600 is the table; the label conflated them.
RENAME = {'TCBDefinitionTable': 'PanelCmdIssuer_8'}

# Symbol rename first.  Skipped on ";>>>>" lines: those are unverified Monte
# Carlo prose, and renaming a symbol inside a sentence produces gibberish
# rather than a correction.  One such annotation asserts a TCB definition table
# at $F0A57E and is simply wrong; it is left as written, since ";>>>>" already
# means unverified.
src = [l if l.lstrip().startswith(';>>>>')
       else re.sub(r'\bTCBDefinitionTable\b', 'PanelCmdIssuer_8', l)
       for l in src]

# Whole-line replacements, keyed on the POST-rename text so the rename cannot
# rewrite the replacements themselves.
LINE_FIX = {
 '; DATA   : 0xF0A57E-0xF0B17E  PanelCmdIssuer_8 + 6\u00d796B TCB entries':
   '; DATA   : 0xF0A600-0xF0A840  the real !TCB table - 6 x $60 entries.\n'
   ';          $F0A57E is PanelCmdIssuer_8, NOT a table.  RTOS init locates the\n'
   ';          table FROM it by rounding up: $F09D30 does lea $F0A57E,a3 /\n'
   ';          move.l a3,d1 / addi.l #$FF,d1 / clr.b d1  ->  $F0A600.  The old\n'
   ';          label conflated the search base with the table.',
 '; Coverage: 22988/47992 bytes as code  (47.9%)':
   '; Coverage: inherited from the frozen input and STALE - see CLAUDE.md',
 '; Instructions decoded: 6485':
   '; Instructions decoded: inherited and STALE - see CLAUDE.md',
}
src = [LINE_FIX.get(l, l) for l in src]

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
 ';     $FF0048 IS read - by the channel ISR at $F07EF6, as $48(a5) with',
 ';     a5=$FF0000. An earlier edition of this header said "never read";',
 ';     that was an absolute-address scan missing the displacement form.',
 ';   $FF0008 is a bidirectional bulk port with three modes (see F04AE2/F04C50/F04B22)',
 ';   $FF0230-$FF025F are BIM registers, not per-channel config',
 ';   $E60 is the XP channel number, not an S-record count',
 ';   $E64 is a transfer word count, not an expected panel response',
 ';   $E74 is the result register returned to the chassis via CHANNEL_SELECT',
 ';   $E86/$E87 hold the latched chassis response, not a "channel mode"',
 ';   F08DF8 is BoardStatusPoll_3F11, not ROMChecksumTest - it never reads ROM',
 ';',
 ';   Added by the second 2026-07-29 pass:',
 ';   $F0A57E is PanelCmdIssuer_8 (copy 8 of 8), NOT TCBDefinitionTable. The',
 ';     real !TCB table is $F0A600; init reaches it by rounding $F0A57E up.',
 ';   $29E-$2A6 are CPU-EXCEPTION reporters, one per class, from a 9-entry',
 ';     table at $F0A23A. All nine bra.w to PanelCmdIssuer_8. If the board',
 ';     dies, the last value at $FF000E names the exception.',
 ';   $105E is a channel-present COUNT written by the CPU at $F0A224, not a',
 ';     chassis DMA target. Each XP task gates on count >= its own channel.',
 ';   The six LIVE TCBs sit at $1E900+$200n - INSIDE the WCS staging buffer.',
 ';     Usable staging is $10000-$1DEFF (~56.75 KB), not the full 64 KB.',
 ';   $F0891C is the self-test checkpoint: 65 calls, one per subtest, and the',
 ';     place a failure becomes visible (clears VMOD bit 6, MODE1 <- $1000).',
 ';   A clean boot issues NO panel command at all - the only $FF000E write is',
 ';     $AAAA, a RAM test pattern. The panel path is error/command-only.',
 ';   Only TRAP #0 and TRAP #1 are used; #2-#15 are free.',
 ';',
 ';   FILE ROLES: fps3k.asm (this file) is the product and the one to read.',
 ';   fps3k_custom.asm is the raw disasm.py output; fps3k_custom_annotated.asm',
 ';   is the frozen build input - it is NOT regenerable (its own input was a',
 ';   temp file), which is why label fixes are applied here by substitution.',
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
            for _n in NOTES[addr]:
                out.append(';### ' + _n); n_notes += 1
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
