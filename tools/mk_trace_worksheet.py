import reportlab.rl_config as _rl
_rl.invariant = 1   # reproducible output: no embedded timestamps
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
W,H=A4; M=14*mm
c=canvas.Canvas("refs_extracted/versabus_trace_worksheet.pdf",pagesize=A4)
def top(t,sub):
    c.setFont("Helvetica-Bold",12.5); c.drawString(M,H-M-2,t)
    c.setFont("Helvetica",7.2); c.setFillGray(0.35); c.drawString(M,H-M-13,sub); c.setFillGray(0)
    c.line(M,H-M-18,W-M,H-M-18); return H-M-29
def chk(y,t):
    c.setFont("Helvetica-Bold",9); c.drawString(M,y,t); return y-11
def para(y,t):
    c.setFont("Helvetica",7.1)
    for line in t.split("\n"): c.drawString(M,y,line); y-=8.6
    return y-2
def note(y,t):
    c.setFont("Helvetica-Oblique",6.7); c.setFillGray(0.32)
    for line in t.split("\n"): c.drawString(M,y,line); y-=8.2
    c.setFillGray(0); return y-2
def tbl(y,hdrs,xs,rows,blanks=0,rowh=11):
    c.setFont("Helvetica-Bold",6.8)
    for x,h in zip(xs,hdrs): c.drawString(x,y,h)
    y-=3; c.setLineWidth(0.4); c.line(M,y,W-M,y); y-=8
    c.setFont("Courier",6.8)
    for r in rows:
        for x,t in zip(xs,r): c.drawString(x,y,t)
        y-=rowh
    c.setLineWidth(0.25); c.setStrokeGray(0.6)
    for _ in range(blanks):
        c.line(M,y+2,W-M,y+2); y-=rowh
    c.line(M,y+2,W-M,y+2); c.setStrokeGray(0); c.setLineWidth(0.6)
    return y-4

# ---- page 1 ----
y=top("FPS-3000 — VersaBus card trace worksheet",
 "For the V-BUS XLTR (612-4803-400-G) and AP I/F (612-4448-401-F). Rebuilt 2026-07-29; supersedes the earlier edition.")
y=note(y,"Every expectation is a PREDICTION from the SBC firmware, not an observation. Where a check disagrees, the board wins -\nrecord what you find. Sources: refs_extracted/versabus_access_map.md, MC68153 datasheet, versabus_pinout.md.")
y-=2
y=chk(y,"Check 0 — the phase beacon: read the machine's own self-test progress")
y=para(y,"Costs nothing and needs no debugger. Every power-on self-test writes  phase<<8 | subtest  to CHANNEL_SELECT")
y=para(y,"($FF0204) before it runs. Scope, latch or read that register during reset: the LAST value before a hang names")
y=para(y,"the failing subtest. The suite runs $0100 through $2903 on a healthy machine and ends in the RTOS idle loop.")
y=tbl(y,["beacon","what it was testing when it stopped"],[M,M+70],
 [("$01xx  (105)","CPU flags / arithmetic - fails before any chassis access"),
  ("$02xx  (6)","$1FFF1 bit 6 <-> $F70019 bit 3 inverse wiring"),
  ("$0300  (1)","ROM decode"),("$0400  (1)","RAM address decode / byte lanes"),
  ("$0500  (1)","board status not reaching (x & $3F31) == $3F11"),
  ("$06xx  (8)","VMOD control register pattern round-trip"),
  ("$0700  (1)","short-I/O window at $F82000 must BUS ERROR"),
  ("$08xx  (4)","I/O channel"),("$09xx  (5)","MC6840 PTM, its IRQ path, or $1FFF1 bit 7 gating"),
  ("$1000  (1)","address-space boundary map"),("$11xx-$14xx","panel-bus interrupts and vectors"),
  ("$15xx  (6)","CHANNEL_SELECT must be a clean read/write register"),
  ("$1600  (1)","XLTR register file, or the BIM population bit"),
  ("$17xx  (4)","DATA_HI page gating on the $400000 window"),
  ("$18xx  (4)","XLTR mode/page register $FF0216"),
  ("$19xx  (5)","XLTR data register $FF0214"),
  ("$1Axx  (4)","XLTR status/IRQ $FF0218 + panel command port"),
  ("$20xx-$23xx","RAM test, FIRST pass: $000400-$01F000"),
  ("$24xx-$27xx","RAM test, SECOND pass: $010000-$01F000 = the WCS staging buffer"),
  ("$28xx  (26)","CHASSIS MEMORY test - 65k window accesses despite few beacon subtests"),
  ("$29xx  (32768)","CHASSIS MEMORY test via the $400000 paged window (131k accesses), PTM alongside")],rowh=9.2)
y=note(y,"(n) = number of subtests in that phase, measured. 30 phases exist: $01-$09, $10-$1A, $20-$29 (BCD, plus $1A).")
y=note(y,"PHASE $29 IS 99.4% OF THE RUN (32,768 of 32,967 beacon writes). The beacon SITTING in $29xx is NORMAL, not a hang.")
y=note(y,"Reaching $24xx but hanging in $25xx-$27xx = good low RAM, bad WCS staging RAM. That split is the useful one.")
y=note(y,"Beacon observed: ______________   Boot completes to idle loop? Y / N")
y-=4
y=chk(y,"Check 1 — identify the three BIM packages")
y=para(y,"Look for three 40-pin DIPs. MC68153 is expected; any part with the same pinout is equally consistent.")
y=para(y,"The parts survey did NOT find them - this is a genuine open question, not a formality.")
y=tbl(y,["package ref","part number as marked","date code","pin 1 OK?"],[M,M+70,M+200,M+270],[],blanks=3)
y=note(y,"Confirm before trusting: pin 3 = CS, pins 38/39/40 = A1/A2/A3, pins 28,29,32-37 = D0-D7, pin 18 = CLK, pin 4 = DTACK.")
c.setFont("Helvetica",6); c.setFillGray(0.45); c.drawString(M,12*mm,"page 1 of 4"); c.setFillGray(0); c.showPage()

# ---- page 2 ----
y=top("Check 2-4 — interrupt level, daisy chain, address decode","")
y=chk(y,"Check 2 — the interrupt level")
y=para(y,"The firmware writes $5F to five channel control registers and $5E to one. Per the MC68153 datasheet bits 0-2")
y=para(y,"choose which IRQ output the chip asserts, so $5F = IRQ7 and $5E = IRQ6. Buzz the pins and the question closes.")
y=tbl(y,["BIM IRQ pin","signal","VersaBus P1 pin","connected? Y/N","notes"],[M,M+58,M+100,M+165,M+225],
 [("8","IRQ1*","87","",""),("12","IRQ2*","88","",""),("13","IRQ3*","89","",""),
  ("14","IRQ4*","90","",""),("15","IRQ5*","91","",""),("16","IRQ6*","92","",""),
  ("17","IRQ7*","93","","")])
y=note(y,"Prediction: pin 17 wired on the BIMs at $FF0240 and $FF0250; pin 16 on the one at $FF0230. If IRQ5* is the connected\npin instead, the datasheet reading is wrong. Either result is useful - record which pins go anywhere at all.")
y-=3
y=chk(y,"Check 3 — the IACK daisy chain")
y=para(y,"Five enabled channels request the same level, so IACKIN*/IACKOUT* decides who wins a tie. Establish the order.")
y=tbl(y,["from","pin","to","pin","connected?"],[M,M+110,M+140,M+250,M+280],
 [("BIM ___ IACKOUT*","7","BIM ___ IACKIN*","6",""),
  ("BIM ___ IACKOUT*","7","BIM ___ IACKIN*","6",""),
  ("VersaBus IACKIN","","first BIM IACKIN*","6",""),
  ("last BIM IACKOUT*","7","VersaBus / next card","","")])
y=note(y,"Record the physical left-to-right order on the card as well as the electrical order.")
y-=3
y=chk(y,"Check 4 — address decode and chip select")
y=para(y,"Each BIM answers a 16-byte window; A1-A3 select the register inside, so A4 and above decode into CS.")
y=tbl(y,["window","registers","A6","A5","A4","which package has this CS?"],[M,M+95,M+165,M+185,M+205,M+230],
 [("$FF0230-$FF023F","BIM0  CR0-3, VR0-3","0","1","1",""),
  ("$FF0240-$FF024F","BIM1  CR0-3, VR0-3","1","0","0",""),
  ("$FF0250-$FF025F","BIM2  CR0-3, VR0-3","1","0","1",""),
  ("$FF0200-$FF021B","XLTR control file","0","0","0","")])
y=note(y,"A4 and A5 alone do NOT separate the windows: BIM1 and the XLTR file both read A4=0, A5=0. A6 is the deciding bit.")
c.setFont("Helvetica",6); c.setFillGray(0.45); c.drawString(M,12*mm,"page 2 of 4"); c.setFillGray(0); c.showPage()

# ---- page 3 ----
y=top("Check 5-6 — register layout, interrupt sources","")
y=chk(y,"Check 5 — register layout confirmation")
y=para(y,"Inferred from firmware writes: CRn and VRn are the same channel. If the board disagrees, the whole")
y=para(y,"channel-to-task mapping in the access map is wrong.")
y=tbl(y,["offset","A3","A2","A1","register","channel","firmware writes"],[M,M+45,M+65,M+85,M+110,M+165,M+205],
 [("+$0","0","0","0","CR0","ch0","$5E or $5F or $00"),
  ("+$2","0","0","1","CR1","ch1","$00"),
  ("+$4","0","1","0","CR2","ch2","$5F"),
  ("+$6","0","1","1","CR3","ch3","$5F or $00"),
  ("+$8","1","0","0","VR0","ch0","vector number"),
  ("+$A","1","0","1","VR1","ch1","vector number"),
  ("+$C","1","1","0","VR2","ch2","vector number"),
  ("+$E","1","1","1","VR3","ch3","vector number")],rowh=9.5)
y=note(y,"The address arrives as A01-A03 and reaches the BIM as A1-A3 (pins 38,39,40). Confirm no swap: reversed A1/A3 would\nexchange the CR and VR halves and everything above would still look self-consistent.")
y-=3
y=chk(y,"Check 6 — who drives the device interrupt inputs")
y=para(y,"The four INT inputs are what the chassis pulls to request service. Tracing them backwards names each task's owner.")
y=tbl(y,["BIM","INT pin","name","firmware owner (predicted)","what actually drives it"],[M,M+40,M+80,M+120,M+250],
 [("BIM1","23","INT2","TCBXP1I  (XP-32 channel 1)",""),
  ("BIM1","24","INT3","TCBXP2I",""),
  ("BIM2","19","INT0","TCBXP3I",""),
  ("BIM2","22","INT1","TCBXP4I",""),
  ("BIM2","23","INT2","TCBIO1I  (host link)",""),
  ("BIM0","19","INT0","TCBRDHC, vector $41","")])
y=note(y,"The last row matters most. Vector $41 reaches F04930, the handler that receives the chassis command stream -\nwhatever drives BIM0 INT0 is the chassis's request line for SBC service.")
c.setFont("Helvetica",6); c.setFillGray(0.45); c.drawString(M,12*mm,"page 3 of 4"); c.setFillGray(0); c.showPage()

# ---- page 4 ----
y=top("Check 7-8 — AP I/F windows, the Am29116 pair","")
y=chk(y,"Check 7 — AP I/F channel windows   [CORRECTED - the earlier edition had three of four roles wrong]")
y=para(y,"Four windows on a 32-byte stride. The card carries eight Am29705 16x4 TWO-PORT RAMs = 32 bits of width.")
y=tbl(y,["offset","ch1","ch2","ch3","ch4","role"],[M,M+42,M+95,M+148,M+201,M+254],
 [("+$04","$FF0044","$FF0064","$FF0084","$FF00A4","write port"),
  ("+$08","$FF0048","$FF0068","$FF0088","$FF00A8","32-bit data, HIGH half"),
  ("+$0A","$FF004A","$FF006A","$FF008A","$FF00AA","32-bit data, LOW half"),
  ("+$0E","$FF004E","$FF006E","$FF008E","$FF00AE","command/trigger, $8000 fires")])
y=note(y,"+$08 and +$0A are ONE 32-bit register, not data + status. $FF0048 is never read by the ROM. Do NOT look for a '$4F\nstatus value' - that came from our own emulator, not the hardware, and the earlier edition was wrong to ask.")
y-=2
y=tbl(y,["question","finding"],[M,M+230],
 [("Am29705 designators (expect 8)",""),
  ("Do all four channels share them, or silicon per channel?",""),
  ("Ribbon connector 1: pin count / signals",""),
  ("Ribbon connector 2: pin count / signals",""),
  ("Which pins carry the host-side 32-bit path?","")])
y=note(y,"The host-side counterpart card is missing, so its pinout has to come off this card.")
y-=3
y=chk(y,"Check 0b - if the board dies, the panel port names the exception")
y=para(y,"The last word written to $FF000E before a hang is a CPU exception code. Nine of them, from a table at $F0A23A.")
y=para(y,"This costs nothing to watch and immediately separates a bus fault from a stray interrupt.")
y=tbl(y,["code","exception","code","exception"],[M,M+40,M+180,M+220],
 [("$29E","bus error (2)","$2A3","TRAPV (7)"),
  ("$29F","address error (3)","$2A4","privilege violation (8)"),
  ("$2A0","illegal instruction (4)","$2A5","uninitialised interrupt (15)"),
  ("$2A1","divide by zero (5)","$2A6","CATCH-ALL - stray IRQ on any unused vector"),
  ("$2A2","CHK (6)","$2B2","kernel-region fatal stub at $F001A0")],rowh=9.2)
y=note(y,"$2A6 is the one to expect from a wiring fault: it is installed on 182 unused user vectors.")
y=note(y,"Last $FF000E value observed: ______________")
y-=4
y=chk(y,"Check 7c — two predictions this firmware makes that a bus trace can falsify")
y=para(y,"Both follow from decoding alone and neither has been checked against hardware. They are cheap to test and")
y=para(y,"each would settle an open question outright.")
y=para(y,"1. $10AA MUST BE WRITTEN BY SOMETHING OTHER THAN THE CPU. TCBIO1I dispatches on it, but the only code that")
y=para(y,"   writes that array is the host-command-1 handler, which indexes $10A0 by (channel-1)*2 and validates")
y=para(y,"   1 <= channel <= $105E. Reaching $10AA needs channel 6; $105E counts nonzero ports among exactly FOUR.")
y=para(y,"   So the CPU cannot write it. PREDICTION: a bus trace shows a NON-CPU master writing $0010AA. If instead")
y=para(y,"   nothing ever writes it, the host path is dead code in this ROM revision.")
y=para(y,"2. A PANEL COMMAND ISSUED FROM A CHANNEL ISR CANNOT COMPLETE. The issuer ends in bra . and is only released")
y=para(y,"   by the responder on BIM0 ch0, which the firmware programs to LEVEL 6 (CR=$5E), while every channel ISR")
y=para(y,"   runs at LEVEL 7 (CR=$5F) and never lowers SR. PREDICTION: if the chassis answers $281 via BIM0 ch0, the")
y=para(y,"   SBC hangs at $F05E86. If the machine instead works, the response arrives by some other path - find it.")
y=note(y,"Trace result 1: ________________________   Trace result 2: ________________________")
y-=4
y=chk(y,"Check 7b — bus mastership")
y=para(y,"The SBC never asserts a VersaBus transfer request: $1FFF0, the control register half holding Transfer Request and")
y=para(y,"Block Transfer Request, is written $00 every time. So the CHASSIS masters the bus and DMAs into SBC RAM.")
y=tbl(y,["question","finding"],[M,M+230],
 [("Which card drives BR*/BGACK* on P1?",""),
  ("Does the AP I/F or the XLTR contain the DMA address counter?",""),
  ("What writes SBC RAM $10AA and $105E?  (firmware never does)","")])
y-=3
y=chk(y,"Check 8 — the two Am29116 on the XP32 EXEC card")
y=para(y,"The owner counts two; the photo survey read one. Settle it before any PROM comes off - it decides whether a")
y=para(y,"dump holds one instruction stream or two.")
y=tbl(y,["question","why it matters","finding"],[M,M+150,M+250],
 [("How many Am29116 packages?","survey says 1, owner says 2",""),
  ("One shared 16-bit field, or 16 each of the 80?","one dump or two",""),
  ("Carry / status link between them?","cascaded = one 32-bit ALU","")])
c.setFont("Helvetica",6); c.setFillGray(0.45); c.drawString(M,12*mm,"page 4 of 4")
c.save(); print("written")
