import reportlab.rl_config as _rl
_rl.invariant = 1   # reproducible output: no embedded timestamps
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
W, H = A4
M = 14*mm

def hdr(c, t, sub):
    c.setFont("Helvetica-Bold", 13); c.drawString(M, H-M-2, t)
    c.setFont("Helvetica", 7.4); c.setFillGray(0.35)
    c.drawString(M, H-M-14, sub); c.setFillGray(0)
    c.setLineWidth(0.6); c.line(M, H-M-19, W-M, H-M-19)
    return H-M-30

def sect(c, y, t):
    c.setFont("Helvetica-Bold", 8.6); c.drawString(M, y, t); return y-11

def row(c, y, cols, xs, bold=False, gray=None):
    c.setFont("Helvetica-Bold" if bold else "Courier", 6.9)
    if gray is not None: c.setFillGray(gray)
    for x, t in zip(xs, cols): c.drawString(x, y, t)
    c.setFillGray(0); return y-8.4

def note(c, y, t, ital=True):
    c.setFont("Helvetica-Oblique" if ital else "Helvetica", 6.8)
    c.setFillGray(0.3); c.drawString(M, y, t); c.setFillGray(0); return y-9

c = canvas.Canvas("refs_extracted/versabus_address_map.pdf", pagesize=A4)

# ---------------- page 1 ----------------
y = hdr(c, "FPS-3000 SBC — VersaBus address map",
        "Derived from FPS3K_U11_U12_JOIN.bin + emulator measurement. Supersedes the 2026-07 edition; see PDF_ERRATA.md for what changed.")
y = sect(c, y, "Windows")
X = [M, M+95, M+205]
y = row(c, y, ["range", "device", "contents"], X, bold=True)
for r in [("$FF0000-$FF001F", "AP I/F", "command reg + bulk data port (see below)"),
          ("$FF0040-$FF00BF", "AP I/F", "four 32-byte channel windows, $FF0040+$20*N"),
          ("$FF0200-$FF021B", "XLTR", "mode / select / counter / data / status / IRQ mask"),
          ("$FF0230-$FF025F", "XLTR", "three MC68153-style BIMs, 4 channels each"),
          ("$70001C/$700020", "mailbox", "host->SBC / SBC->host, one 32-bit word each way"),
          ("$400000-$4FFFFF", "chassis", "paged memory window; MODE2 = addr bits 20-31")]:
    y = row(c, y, list(r), X)
y -= 4

y = sect(c, y, "AP I/F command window  $FF0000-$FF001F")
X = [M, M+52, M+80, M+150]
y = row(c, y, ["offset", "addr", "dir", "role"], X, bold=True)
for r in [("+$00", "$FF0000", "R/W", "command reg; $8004/$8005 out. Reads <=0 mean END OF STREAM"),
          ("+$04", "$FF0004", "R", "bit 0 = port ready; polled before every transfer (F04B22)"),
          ("+$08", "$FF0008", "R/W", "BULK DATA PORT, bidirectional - three modes, below"),
          ("+$0E", "$FF000E", "W", "panel command / argument staging")]:
    y = row(c, y, list(r), X)
y -= 3
y = note(c, y, "$FF0008 mode is chosen by the latched opcode $E5C and bit 5 of the chassis response byte:")
X2 = [M+6, M+90, M+150]
y = row(c, y, ["$E5C / bit5", "direction", "content"], X2, bold=True)
for r in [("$00 / 0", "in", "ASCII S-record text, two characters per 16-bit word"),
          ("$28 / -", "in", "binary, word -> staging buffer at $E58"),
          ("$00 / 1", "out", "binary, staging buffer -> port (this is the WCS upload)")]:
    y = row(c, y, list(r), X2)
y -= 3
y = note(c, y, "All three use the same handshake: STATUS_IRQ <- $400, poll bit 15, STATUS_IRQ <- 0.")
y -= 5

y = sect(c, y, "AP I/F channel windows  $FF0040 + $20*N   [CORRECTED]")
X = [M, M+50, M+108, M+166, M+224, M+282]
y = row(c, y, ["offset", "ch 1", "ch 2", "ch 3", "ch 4", "role"], X, bold=True)
for r in [("+$04", "$FF0044", "$FF0064", "$FF0084", "$FF00A4", "write port"),
          ("+$08", "$FF0048", "$FF0068", "$FF0088", "$FF00A8", "32-bit data, HIGH half"),
          ("+$0A", "$FF004A", "$FF006A", "$FF008A", "$FF00AA", "32-bit data, LOW half"),
          ("+$0E", "$FF004E", "$FF006E", "$FF008E", "$FF00AE", "command/trigger ($8000 fires)")]:
    y = row(c, y, list(r), X)
y -= 3
y = note(c, y, "+$08 and +$0A are one 32-bit register, not data+status: BLK_XFR (F05B0E) reads both each pass; TCBXP1I writes $0000001B across")
y = note(c, y, "the pair at F07EC6 then $8000 to +$0E. Eight Am29705 16x4 two-port RAMs give exactly 32 bits.")
y = note(c, y, "CORRECTION: an earlier edition said $FF0048 is NEVER READ. It is - by the channel ISR, as $48(a5) with a5=$FF0000, so no")
y = note(c, y, "absolute-address scan sees it. Reads only happen once a channel BIM interrupt is raised, which is why they were missed.")
y -= 5

y = sect(c, y, "What one channel transaction looks like on a trace   [MEASURED]")
X2 = [M, M+56, M+150]
y = row(c, y, ["PC", "cycle", "meaning"], X2, bold=True)
for r in [("F07EEE", "RD +$0E", "read command reg  -> RAM $1066"),
          ("F07EF6", "RD +$08", "read data HIGH    -> RAM $1068"),
          ("F07EFE", "RD +$0A", "read data LOW     -> RAM $106A"),
          ("F07F10", "WR BIM CR $4F", "IRE cleared: mute this channel for the transfer"),
          ("F07F18", "WR +$08 = $0000", "write data HIGH back"),
          ("F07F1E", "WR +$0A = d0", "write data LOW back"),
          ("F07F22", "WR +$0E = $8004", "REQUEST-TRANSFER"),
          ("F07F2E", "RD +$0E (poll)", "spin, 1000-iteration timeout in d5")]:
    y = row(c, y, list(r), X2)
y -= 3
y = note(c, y, "Addresses are XP1I's; the other three channels are byte-identical copies at -$A00, -$1400, -$1E00. XP4I has this ISR too.")
y = note(c, y, "The SEPARATE $8000 path (data pair <- $0000001B, then $8000) exists ONLY in XP1I/2/3 and needs command-reg bits 15,14,11 set.")
y -= 5

y = sect(c, y, "SBC RAM the chassis interacts with")
X3 = [M, M+70, M+140]
y = row(c, y, ["address", "owner", "role"], X3, bold=True)
for r in [("$105E", "written by CPU", "count of channels with a NONZERO command reg; probe at $F0A202"),
          ("$1062 / $1064", "shared", "scan state, all four XP tasks"),
          ("$1066-$106A", "XP1I", "ISR snapshot: {command, data HI, data LO}"),
          ("$106C-$1070", "XP2I", "same, stride 6"),
          ("$1072-$1076", "XP3I", "same"),
          ("$1078-$107C", "XP4I", "same"),
          ("$107E / $1080", "shared", "scan state"),
          ("$10A0-$10A6", "cmd-1 handler", "per-channel flag, (ch-1)*2, ch 1-4 ONLY"),
          ("$10AA", "NOT WRITABLE BY CPU", "TCBIO1I dispatches on it; needs ch 6, which $105E forbids"),
          ("$10000-$1FFFF", "S-record staging", "one 4K x 128-bit WCS bank")]:
    y = row(c, y, list(r), X3)
y -= 5

y = sect(c, y, "XLTR control file  $FF0200-$FF021B")
X = [M, M+58, M+120]
y = row(c, y, ["addr", "name", "established behaviour"], X, bold=True)
for r in [("$FF0200", "MODE0", "bits 0-7 chassis response byte; b10 ack, b11 valid. Low byte reads 0 when idle"),
          ("$FF0202", "MODE1", "b7 busy (tested 15x), b12 enable (set 8x), b14 control (cleared 12x), b15 arms chassis op"),
          ("$FF0204", "CHANNEL_SELECT", "BIDIRECTIONAL: chassis presents args, SBC returns results from $E74"),
          ("$FF020C", "COUNTER", "operational value $4 (7 sites); $1/$FF are boot-diagnostic only; readable"),
          ("$FF0210", "MODE2", "chassis page select = address bits 20-31 of the $400000 window"),
          ("$FF0214", "DATA_LO", "used by phase $1900 chassis-memory data test"),
          ("$FF0216", "DATA_HI", "mode/page reg, NOT a command reg; gates $400000 access. Resting value $C0"),
          ("$FF0218", "STATUS_IRQ", "arm $400 / poll b15 / clear 0.  b4 = BIM POPULATION (16 vs 24 regs)"),
          ("$FF021A", "IRQ_MASK", "reads $FFF. Bits 5,4,3,2 = XP channels 1,2,3,4 (PanelErrorMaskTable F05C4C)")]:
    y = row(c, y, list(r), X)
c.setFont("Helvetica", 6); c.setFillGray(0.45)
c.drawString(M, 12*mm, "page 1 of 2")
c.showPage()

# ---------------- page 2 ----------------
y = hdr(c, "FPS-3000 SBC — interrupts, protocol, bring-up",
        "Companion to page 1. Every claim here is either read from the ROM or measured in the emulator.")

y = sect(c, y, "BIM channels  $FF0230-$FF025F   (CR n at +0/+2/+4/+6, VR n at +8/+A/+C/+E)")
X = [M, M+48, M+86, M+124, M+166, M+210, M+262]
y = row(c, y, ["BIM.ch", "CR", "value", "VR", "vector", "handler", "owner"], X, bold=True)
for r in [("0.0", "$FF0230", "$5E", "$FF0238", "$41 -> $104", "F04930", "TCBRDHC"),
          ("1.2", "$FF0244", "$5F", "$FF024C", "$45 -> $114", "F07EE6", "TCBXP1I"),
          ("1.3", "$FF0246", "$5F", "$FF024E", "$46 -> $118", "F074E6", "TCBXP2I"),
          ("2.0", "$FF0250", "$5F", "$FF0258", "$47 -> $11C", "F06AE6", "TCBXP3I"),
          ("2.1", "$FF0252", "$5F", "$FF025A", "$48 -> $120", "F060CE", "TCBXP4I"),
          ("2.2", "$FF0254", "$5F", "$FF025C", "$4A -> $128", "F05DD6", "TCBIO1I")]:
    y = row(c, y, list(r), X)
y -= 3
y = note(c, y, "CR bits: 0-2 = IRQ level (0 disables), 4 = IRE enable, 5 = IRAC auto-clear (off), 7 = Flag. $4F = $5F with IRE cleared -")
y = note(c, y, "PanelSendAndWait writes it to suppress a channel's interrupt during a transfer. $4F has NO connection to $FF004A.")
y -= 5

y = sect(c, y, "Chassis -> SBC command protocol  (responses arrive on BIM0 ch0)")
X = [M, M+46, M+150, M+250]
y = row(c, y, ["code", "operation", "argument (CHANNEL_SELECT)", "result"], X, bold=True)
for r in [("$0", "latch opcode, execute", "opcode 0..$10, or $28 = bulk", "-"),
          ("$1 / $41", "set address low / high", "address half -> $E58/$E5A", "-"),
          ("$2 / $42", "set count low / high", "count half -> $E64/$E66", "-"),
          ("$3/$43/$63", "chassis mem write/hi/read", "data half -> $E70/$E72", "$E70"),
          ("$5", "arg 0: report AC count", "0, or channel number", "$105E"),
          ("$7", "disable BIM0 ch0 IRQ", "-", "-"),
          ("$9", "set data parameter", "data half -> $E68/$E6A", "-"),
          ("$B", "report $10010", "-", "$E74"),
          ("$F", "return from interrupt", "-", "-")]:
    y = row(c, y, list(r), X)
y -= 3
y = note(c, y, "Bit 7 of the response byte selects the dispatcher (0 = the 16-entry table at F05102). Bit 6 selects the half for the")
y = note(c, y, "loaders. Bit 5 selects direction for code $3 and for the bulk transfer - opposite senses, do not generalise.")
y -= 5

y = sect(c, y, "Microcode upload — verified end to end in one session")
y = note(c, y, "host ASCII S-records -> $FF0008 -> SRecordDataHandler -> staging $10010+ -> $FF0008 -> XLTR -> UNIV FMT -> WCS", ital=False)
y -= 2
y = note(c, y, "S-RECORD ADDRESSES ARE OFFSETS. The handler computes  a1 = $10 + record_address + $10000  (seed at F051A2, add at")
y = note(c, y, "F051DC) and range-checks the RESULT to $10000-$1FFFF. Usable record range $0000-$FFEF -> lands $10010-$1FFFF.")
y = note(c, y, "There is NO SBC-side WCS bank select: the outbound loop carries only source address and count, no destination.")
y = note(c, y, "The chassis is the bus master and places the data; the SBC is a slave conduit and never asserts a transfer request.")
y -= 5

y = sect(c, y, "Bring-up: the self-test phase beacon")
y = note(c, y, "Every power-on self-test writes  phase<<8 | subtest  to $FF0204. Scope or read that register during reset and the", ital=False)
y = note(c, y, "last value before a hang is the failing subtest - no debugger, no serial port needed.", ital=False)
y -= 1
X = [M, M+60, M+150, M+215]
y = row(c, y, ["beacon", "suspect", "beacon", "suspect"], X, bold=True)
pairs = [("$01xx", "CPU flags/arithmetic", "$1000", "address-space boundary map"),
         ("$02xx", "$1FFF1 b6 <-> $F70019 b3", "$11xx-$14xx", "panel-bus IRQs and vectors"),
         ("$0300", "ROM decode", "$1500", "CHANNEL_SELECT read/write"),
         ("$0400", "RAM address decode", "$1600", "XLTR file / BIM population bit"),
         ("$0500", "(status & $3F31) == $3F11", "$17xx-$18xx", "DATA_HI page gating"),
         ("$0600", "VMOD pattern round-trip", "$1900", "chassis memory data lines"),
         ("$0700", "short-I/O must bus-error", "$1A00", "AP I/F window"),
         ("$0800", "I/O channel", "$2000", "RAM address uniqueness"),
         ("$0900", "MC6840 PTM + $1FFF1 b7", "$22xx-$23xx", "chassis bulk / A14 decode")]
for a,b,cc,d in pairs: y = row(c, y, [a,b,cc,d], X)
y -= 3
y = note(c, y, "Six of Motorola's twelve board-status inputs are USER-DEFINED (Table 1, M68KVM02-3 p.2-59). $F70019 bits 1-5 are")
y = note(c, y, "FPS's own wiring and will never appear in a datasheet - infer from firmware, or trace on the board.")
c.setFont("Helvetica", 6); c.setFillGray(0.45)
c.drawString(M, 12*mm, "page 2 of 2")
c.save()
print("written")
