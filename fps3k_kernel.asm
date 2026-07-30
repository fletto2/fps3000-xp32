; FPS-3000 custom code disassembly
; ROM    : FPS3K_U11_U12_JOIN.bin
; Base   : 0xF00000
; Range  : 0xF00000-0xF04487  (17544 bytes)
; Method : recursive-descent + reference scan + convergence loop
; Coverage: 14718/17544 bytes as code  (83.9%)
; Instructions decoded: 4473
; DATA   : 0xF0B17E-0xF10000  Zero-fill / ROM checksum word at F0FFFE

; ============================================================
; RMS68K marker tags (4-byte ASCII signatures used by kernel)
; ============================================================
;   !TCB  Task Control Block               (multiple sites in tables)
;   !CCB  Channel Control Block            (0xF03EF0)
;   !ASQ  Application Status Queue         (multiple sites)
;   !TST  Task Status / Test record        (0xF0298C)
;   !DLY  Delay record                     (0xF02D9A)
;   !VCT  Vector / config table            (0xF09C9C, 0xF0011A)
;   !GST  Global System Table              (0xF09E8A)
;   !UST  User System Table                (0xF09ED0)
;   !IOV  I/O Vector                       (0xF09F54)
;   !IDV  Interrupt Descriptor Vector      (0xF09F82)
;   !PAT  Pattern table                    (0xF09FB4)
;   !UDR  User Driver record               (0xF0A002)
;
; 4-letter context tags found in TCB / dispatch tables
;   "EXEC"  Executive identifier
;   "USER"  User-context identifier
;   "STCK"  Stack-context identifier
;   "UPGM"  User Program identifier
;   "PROG"  TCB terminator (end of TCB record)
;   "RDHC"  Master/dispatch task name        (TCBRDHC)
;   "IO1I"  Host I/O channel task name       (TCBIO1I)
;   "XP1I".."XP4I"  XP-32 channel 1-4 task names (TCBXP1I..4I)
;   "AS0f".."AS3f"  Application-Specific function tables

F00000  00 00                   DC.W     0x0000
F00002  00 00                   DC.W     0x0000
F00004  00 f0 9c 00             DC.L     ResetEntry
F00008  00 00                   DC.W     0x0000
F0000A  00 00                   DC.W     0x0000
F0000C  00 00                   DC.W     0x0000
F0000E  00 00                   DC.W     0x0000
F00010  00 00                   DC.W     0x0000
F00012  00 00                   DC.W     0x0000
F00014  00 00                   DC.W     0x0000
F00016  00 00                   DC.W     0x0000
F00018  00 00                   DC.W     0x0000
F0001A  00 00                   DC.W     0x0000
F0001C  00 00                   DC.W     0x0000
F0001E  00 00                   DC.W     0x0000
F00020  00 00                   DC.W     0x0000
F00022  00 00                   DC.W     0x0000
F00024  00 00                   DC.W     0x0000
F00026  00 00                   DC.W     0x0000
F00028  00 00                   DC.W     0x0000
F0002A  00 00                   DC.W     0x0000
F0002C  00 00                   DC.W     0x0000
F0002E  00 00                   DC.W     0x0000
F00030  00 00                   DC.W     0x0000
F00032  00 00                   DC.W     0x0000
F00034  00 00                   DC.W     0x0000
F00036  00 00                   DC.W     0x0000
F00038  00 00                   DC.W     0x0000
F0003A  00 00                   DC.W     0x0000
F0003C  00 00                   DC.W     0x0000
F0003E  00 00                   DC.W     0x0000
F00040  00 00                   DC.W     0x0000
F00042  00 00                   DC.W     0x0000
F00044  00 00                   DC.W     0x0000
F00046  00 00                   DC.W     0x0000
F00048  00 00                   DC.W     0x0000
F0004A  00 00                   DC.W     0x0000
F0004C  00 00                   DC.W     0x0000
F0004E  00 00                   DC.W     0x0000
F00050  00 00                   DC.W     0x0000
F00052  00 00                   DC.W     0x0000
F00054  00 00                   DC.W     0x0000
F00056  00 00                   DC.W     0x0000
F00058  00 00                   DC.W     0x0000
F0005A  00 00                   DC.W     0x0000
F0005C  00 00                   DC.W     0x0000
F0005E  00 00                   DC.W     0x0000
F00060  00 00                   DC.W     0x0000
F00062  00 00                   DC.W     0x0000
F00064  00 00                   DC.W     0x0000
F00066  00 00                   DC.W     0x0000
F00068  00 00                   DC.W     0x0000
F0006A  00 00                   DC.W     0x0000
F0006C  00 00                   DC.W     0x0000
F0006E  00 00                   DC.W     0x0000
F00070  00 00                   DC.W     0x0000
F00072  00 00                   DC.W     0x0000
F00074  00 00                   DC.W     0x0000
F00076  00 00                   DC.W     0x0000
F00078  00 00                   DC.W     0x0000
F0007A  00 00                   DC.W     0x0000
F0007C  00 00                   DC.W     0x0000
F0007E  00 00                   DC.W     0x0000
F00080  00 00                   DC.W     0x0000
F00082  00 00                   DC.W     0x0000
F00084  00 00                   DC.W     0x0000
F00086  00 00                   DC.W     0x0000
F00088  00 00                   DC.W     0x0000
F0008A  00 00                   DC.W     0x0000
F0008C  00 00                   DC.W     0x0000
F0008E  00 00                   DC.W     0x0000
F00090  00 00                   DC.W     0x0000
F00092  00 00                   DC.W     0x0000
F00094  00 00                   DC.W     0x0000
F00096  00 00                   DC.W     0x0000
F00098  00 00                   DC.W     0x0000
F0009A  00 00                   DC.W     0x0000
F0009C  00 00                   DC.W     0x0000
F0009E  00 00                   DC.W     0x0000
F000A0  00 00                   DC.W     0x0000
F000A2  00 00                   DC.W     0x0000
F000A4  00 00                   DC.W     0x0000
F000A6  00 00                   DC.W     0x0000
F000A8  00 00                   DC.W     0x0000
F000AA  00 00                   DC.W     0x0000
F000AC  00 00                   DC.W     0x0000
F000AE  00 00                   DC.W     0x0000
F000B0  00 00                   DC.W     0x0000
F000B2  00 00                   DC.W     0x0000
F000B4  00 00                   DC.W     0x0000
F000B6  00 00                   DC.W     0x0000
F000B8  00 00                   DC.W     0x0000
F000BA  00 00                   DC.W     0x0000
F000BC  00 00                   DC.W     0x0000
F000BE  00 00                   DC.W     0x0000
F000C0  00 00                   DC.W     0x0000
F000C2  00 00                   DC.W     0x0000
F000C4  00 00                   DC.W     0x0000
F000C6  00 00                   DC.W     0x0000
F000C8  00 00                   DC.W     0x0000
F000CA  00 00                   DC.W     0x0000
F000CC  00 00                   DC.W     0x0000
F000CE  00 00                   DC.W     0x0000
F000D0  00 00                   DC.W     0x0000
F000D2  00 00                   DC.W     0x0000
F000D4  00 00                   DC.W     0x0000
F000D6  00 00                   DC.W     0x0000
F000D8  00 00                   DC.W     0x0000
F000DA  00 00                   DC.W     0x0000
F000DC  00 00                   DC.W     0x0000
F000DE  00 00                   DC.W     0x0000
F000E0  00 00                   DC.W     0x0000
F000E2  00 00                   DC.W     0x0000
F000E4  00 00                   DC.W     0x0000
F000E6  00 00                   DC.W     0x0000
F000E8  00 00                   DC.W     0x0000
F000EA  00 00                   DC.W     0x0000
F000EC  00 00                   DC.W     0x0000
F000EE  00 00                   DC.W     0x0000
F000F0  00 00                   DC.W     0x0000
F000F2  00 00                   DC.W     0x0000
F000F4  00 00                   DC.W     0x0000
F000F6  00 00                   DC.W     0x0000
F000F8  00 00                   DC.W     0x0000
F000FA  00 00                   DC.W     0x0000
F000FC  00 00                   DC.W     0x0000
F000FE  00 00                   DC.W     0x0000
F00100  4e f9                   DC.W     0x4ef9
F00102  00 f0                   DC.W     0x00f0
F00104  05 0c                   DC.W     0x050c
F00106  42 6f                   DC.W     0x426f  ; 'Bo'
F00108  00 06                   DC.W     0x0006
F0010A  3d 7c                   DC.W     0x3d7c  ; '=|'
F0010C  00 01                   DC.W     0x0001
F0010E  01 02                   DC.W     0x0102
F00110  4e 73                   DC.W     0x4e73  ; 'Ns'
F00112  4e 75                   DC.W     0x4e75  ; 'Nu'
F00114  4e b9                   DC.W     0x4eb9
F00116  00 f0                   DC.W     0x00f0
F00118  01 86                   DC.W     0x0186
F0011A  21 56 43 54             DC.B     "!VCT"  ; 4 bytes
F0011E  00 f0                   DC.W     0x00f0
F00120  08 96                   DC.W     0x0896
F00122  02 f0                   DC.W     0x02f0
F00124  0a d8                   DC.W     0x0ad8
F00126  04 f0                   DC.W     0x04f0
F00128  0a dc                   DC.W     0x0adc
F0012A  05 f0                   DC.W     0x05f0
F0012C  0a de                   DC.W     0x0ade
F0012E  09 f0                   DC.W     0x09f0
F00130  0a ee                   DC.W     0x0aee
F00132  0a f0                   DC.W     0x0af0
F00134  0a e6                   DC.W     0x0ae6
F00136  0c 00                   DC.W     0x0c00
F00138  00 00                   DC.W     0x0000
F0013A  18 f0                   DC.W     0x18f0
F0013C  09 ea                   DC.W     0x09ea
F0013E  19 00                   DC.W     0x1900
F00140  00 00                   DC.W     0x0000
F00142  1c f0                   DC.W     0x1cf0
F00144  0e c8                   DC.W     0x0ec8
F00146  1d 00                   DC.W     0x1d00
F00148  00 00                   DC.W     0x0000
F0014A  1f 00                   DC.W     0x1f00
F0014C  00 01                   DC.W     0x0001
F0014E  20 f0                   DC.W     0x20f0
F00150  01 ac                   DC.W     0x01ac
F00152  21 f0                   DC.W     0x21f0
F00154  02 62                   DC.W     0x0262
F00156  22 f0                   DC.W     0x22f0
F00158  0a 78                   DC.W     0x0a78
F0015A  30 00                   DC.W     0x3000
F0015C  00 00                   DC.W     0x0000
F0015E  8d f0                   DC.W     0x8df0
F00160  0a 58                   DC.W     0x0a58
F00162  8e f0                   DC.W     0x8ef0
F00164  01 86                   DC.W     0x0186
F00166  8f 00                   DC.W     0x8f00
F00168  00 00                   DC.W     0x0000
F0016A  90 00                   DC.W     0x9000
F0016C  00 00                   DC.W     0x0000
F0016E  91 00                   DC.W     0x9100
F00170  00 00                   DC.W     0x0000
F00172  92 00                   DC.W     0x9200
F00174  00 00                   DC.W     0x0000
F00176  93 f0                   DC.W     0x93f0
F00178  09 dc                   DC.W     0x09dc
F0017A  94 00                   DC.W     0x9400
F0017C  00 00                   DC.W     0x0000
F0017E  00 00                   DC.W     0x0000
F00180  00 00                   DC.W     0x0000

loc_F00182:
F00182  4f ef 00 02             lea.l    $2(a7), a7

loc_F00186:
F00186  48 f8 ff ff 08 08       movem.l  d0-d7/a0-a7, $808.w
F0018C  40 f8 08 06             move.w   sr, $806.w
F00190  21 d7 08 00             move.l   (a7), $800.w
F00194  4e 69                   move     usp, a1
F00196  21 c9 08 48             move.l   a1, $848.w
F0019A  21 f8 00 08 08 4c       move.l   $8.w, $84c.w
F001A0  30 3c 02 b2             move.w   #$2b2, d0
F001A4  4e b9 00 f0 45 00       jsr      $f04500.l

loc_F001AA:
F001AA  60 fe                   bra.b    loc_F001AA
F001AC  3f 17                   DC.W     0x3f17
F001AE  02 17                   DC.W     0x0217
F001B0  00 7f                   DC.W     0x007f
F001B2  54 8f                   DC.W     0x548f
F001B4  66 02                   DC.W     0x6602
F001B6  4e 73                   DC.W     0x4e73  ; 'Ns'
F001B8  e5 88                   lsl.l    #$2, d0
F001BA  6b 00 ff c6             bmi.w    loc_F00182
F001BE  06 80 00 f0 01 d6       addi.l   #loc_F001D6, d0
F001C4  0c 80 00 f0 02 62       cmpi.l   #loc_F00262, d0
F001CA  6c 00 ff b6             bge.w    loc_F00182
F001CE  c1 88                   exg.l    d0, a0
F001D0  2f 10                   move.l   (a0), -(a7)
F001D2  c1 88                   exg.l    d0, a0
F001D4  4e 75                   rts      

loc_F001D6:
F001D6  00 f0                   DC.W     0x00f0
F001D8  01 82                   DC.W     0x0182
F001DA  00 f0                   DC.W     0x00f0
F001DC  06 ea                   DC.W     0x06ea
F001DE  00 f0                   DC.W     0x00f0
F001E0  07 8a                   DC.W     0x078a
F001E2  00 f0                   DC.W     0x00f0
F001E4  07 c2                   DC.W     0x07c2
F001E6  00 f0                   DC.W     0x00f0
F001E8  12 40                   DC.W     0x1240
F001EA  00 f0                   DC.W     0x00f0
F001EC  14 96                   DC.W     0x1496
F001EE  00 f0                   DC.W     0x00f0
F001F0  17 10                   DC.W     0x1710
F001F2  00 f0                   DC.W     0x00f0
F001F4  17 c6                   DC.W     0x17c6
F001F6  00 f0                   DC.W     0x00f0
F001F8  17 5e                   DC.W     0x175e
F001FA  00 f0                   DC.W     0x00f0
F001FC  17 f6                   DC.W     0x17f6
F001FE  00 f0                   DC.W     0x00f0
F00200  26 aa                   DC.W     0x26aa
F00202  00 f0                   DC.W     0x00f0
F00204  15 be                   DC.W     0x15be
F00206  00 f0                   DC.W     0x00f0
F00208  18 78                   DC.W     0x1878
F0020A  00 f0                   DC.W     0x00f0
F0020C  17 00                   DC.W     0x1700
F0020E  00 f0                   DC.W     0x00f0
F00210  08 16                   DC.W     0x0816
F00212  00 f0                   DC.W     0x00f0
F00214  3b 32                   DC.W     0x3b32  ; ';2'
F00216  00 f0                   DC.W     0x00f0
F00218  34 96                   DC.W     0x3496
F0021A  00 f0                   DC.W     0x00f0
F0021C  24 00                   DC.W     0x2400
F0021E  00 f0                   DC.W     0x00f0
F00220  1b 72                   DC.W     0x1b72
F00222  00 f0                   DC.W     0x00f0
F00224  0d a6                   DC.W     0x0da6
F00226  00 f0                   DC.W     0x00f0
F00228  35 66                   DC.W     0x3566  ; '5f'
F0022A  00 f0                   DC.W     0x00f0
F0022C  08 26                   DC.W     0x0826
F0022E  00 f0                   DC.W     0x00f0
F00230  2c 6e                   DC.W     0x2c6e  ; ',n'
F00232  00 f0                   DC.W     0x00f0
F00234  15 da                   DC.W     0x15da
F00236  00 f0                   DC.W     0x00f0
F00238  16 02                   DC.W     0x1602
F0023A  00 f0                   DC.W     0x00f0
F0023C  27 66                   DC.W     0x2766  ; ''f'
F0023E  00 f0                   DC.W     0x00f0
F00240  17 62                   DC.W     0x1762
F00242  00 f0                   DC.W     0x00f0
F00244  14 90                   DC.W     0x1490
F00246  00 f0                   DC.W     0x00f0
F00248  0f 98                   DC.W     0x0f98
F0024A  00 f0                   DC.W     0x00f0
F0024C  21 d0                   DC.W     0x21d0
F0024E  00 f0                   DC.W     0x00f0
F00250  11 08                   DC.W     0x1108
F00252  00 f0                   DC.W     0x00f0
F00254  28 94                   DC.W     0x2894
F00256  00 f0                   DC.W     0x00f0
F00258  01 82                   DC.W     0x0182
F0025A  00 f0                   DC.W     0x00f0
F0025C  10 f2                   DC.W     0x10f2
F0025E  00 f0                   DC.W     0x00f0
F00260  11 98                   DC.W     0x1198

loc_F00262:
F00262  3f 17                   move.w   (a7), -(a7)
F00264  02 2f 00 0c 00 01       andi.b   #$c, $1(a7)
F0026A  02 17 00 7f             andi.b   #$7f, (a7)
F0026E  67 08                   beq.b    loc_F00278
F00270  0c 2f 00 0c 00 01       cmpi.b   #$c, $1(a7)
F00276  67 08                   beq.b    loc_F00280

loc_F00278:
F00278  54 8f                   addq.l   #$2, a7
F0027A  60 00 00 4a             bra.w    loc_F002C6
F0027E  4a fb                   DC.W     0x4afb

loc_F00280:
F00280  58 8f                   addq.l   #$4, a7
F00282  5d 97                   subq.l   #$6, (a7)
F00284  48 e7 ff fe             movem.l  d0-d7/a0-a6, -(a7)
F00288  2a 79 00 00 0c 6e       movea.l  $c6e.l, a5
F0028E  2c 6d 00 04             movea.l  $4(a5), a6
F00292  4b ed 00 08             lea.l    $8(a5), a5
F00296  28 6f 00 3c             movea.l  $3c(a7), a4

loc_F0029A:
F0029A  b9 ed 00 0a             cmpa.l   $a(a5), a4
F0029E  db fc 00 00 00 0e       adda.l   #$e, a5
F002A4  67 04                   beq.b    loc_F002AA
F002A6  bd cd                   cmpa.l   a5, a6
F002A8  64 f0                   bcc.b    loc_F0029A

loc_F002AA:
F002AA  66 16                   bne.b    loc_F002C2
F002AC  2c 6d ff f4             movea.l  -$c(a5), a6
F002B0  41 d6                   lea.l    (a6), a0
F002B2  61 00 29 b8             bsr.w    loc_F02C6C
F002B6  4c df 7f ff             movem.l  (a7)+, d0-d7/a0-a6
F002BA  4f ef 00 04             lea.l    $4(a7), a7
F002BE  4e 73                   rte      
F002C0  60 04                   DC.W     0x6004

loc_F002C2:
F002C2  61 00 fe c2             bsr.w    loc_F00186

loc_F002C6:
F002C6  3f 17                   move.w   (a7), -(a7)
F002C8  02 17 00 7f             andi.b   #$7f, (a7)
F002CC  54 8f                   addq.l   #$2, a7
F002CE  66 00 06 6a             bne.w    loc_F0093A
F002D2  61 00 03 dc             bsr.w    loc_F006B0
F002D6  3d 6e 01 00 00 5c       move.w   $100(a6), $5c(a6)
F002DC  08 38 00 0f 0c 34       btst.b   #$f, $c34.w
F002E2  67 06                   beq.b    loc_F002EA
F002E4  61 00 13 a2             bsr.w    loc_F01688
F002E8  ff 15                   dc.w     $ff15

loc_F002EA:
F002EA  08 2e 00 06 00 29       btst.b   #$6, $29(a6)
F002F0  67 10                   beq.b    loc_F00302
F002F2  22 2e 01 48             move.l   $148(a6), d1
F002F6  08 01 00 01             btst.b   #$1, d1
F002FA  67 06                   beq.b    loc_F00302
F002FC  7e 01                   moveq    #$1, d7
F002FE  61 00 0a 58             bsr.w    loc_F00D58

loc_F00302:
F00302  3d 40 01 00             move.w   d0, $100(a6)
F00306  1d 7c 00 08 01 00       move.b   #$8, $100(a6)
F0030C  42 6e 01 02             clr.w    $102(a6)

loc_F00310:
F00310  02 80 00 00 ff ff       andi.l   #$ffff, d0
F00316  4a 40                   tst.w    d0
F00318  6b 5e                   bmi.b    loc_F00378
F0031A  e5 88                   lsl.l    #$2, d0
F0031C  0c 80 00 00 01 30       cmpi.l   #$130, d0
F00322  6e 00 00 a2             bgt.w    loc_F003C6
F00326  45 f9 00 f0 03 d8       lea.l    loc_F003D8.l, a2
F0032C  d5 c0                   adda.l   d0, a2
F0032E  34 2a 00 02             move.w   $2(a2), d2
F00332  3f 02                   move.w   d2, -(a7)
F00334  08 02 00 07             btst.b   #$7, d2
F00338  67 30                   beq.b    loc_F0036A
F0033A  42 85                   clr.l    d5
F0033C  1a 17                   move.b   (a7), d5
F0033E  2c 08                   move.l   a0, d6
F00340  20 6e 00 36             movea.l  $36(a6), a0
F00344  61 00 14 16             bsr.w    loc_F0175C
F00348  60 08                   bra.b    loc_F00352
F0034A  4e 71                   DC.W     0x4e71  ; 'Nq'
F0034C  54 6e                   DC.W     0x546e  ; 'Tn'
F0034E  01 02                   DC.W     0x0102
F00350  60 60                   DC.W     0x6060  ; '``'

loc_F00352:
F00352  28 46                   movea.l  d6, a4
F00354  08 02 00 06             btst.b   #$6, d2
F00358  67 10                   beq.b    loc_F0036A
F0035A  41 d4                   lea.l    (a4), a0
F0035C  61 00 13 b0             bsr.w    loc_F0170E
F00360  60 06                   bra.b    loc_F00368
F00362  56 6e                   DC.W     0x566e  ; 'Vn'
F00364  01 02                   DC.W     0x0102
F00366  60 4a                   DC.W     0x604a  ; '`J'

loc_F00368:
F00368  2a 48                   movea.l  a0, a5

loc_F0036A:
F0036A  d4 d2                   adda.w   (a2), a2

loc_F0036C:
F0036C  48 79 00 f0 03 b2       pea.l    loc_F003B2.l
F00372  3f 3c 20 00             move.w   #$2000, -(a7)
F00376  4e d2                   jmp      (a2)

loc_F00378:
F00378  24 78 0c 28             movea.l  $c28.w, a2
F0037C  24 0a                   move.l   a2, d2
F0037E  67 46                   beq.b    loc_F003C6
F00380  44 40                   neg.w    d0
F00382  b0 6a 00 04             cmp.w    $4(a2), d0
F00386  6e 3e                   bgt.b    loc_F003C6
F00388  53 80                   subq.l   #$1, d0
F0038A  c0 fc 00 0a             mulu.w   #$a, d0
F0038E  45 f2 00 06             lea.l    $6(a2, d0.w), a2
F00392  4a aa 00 06             tst.l    $6(a2)
F00396  67 2e                   beq.b    loc_F003C6
F00398  08 2a 00 04 00 05       btst.b   #$4, $5(a2)
F0039E  66 08                   bne.b    loc_F003A8
F003A0  22 12                   move.l   (a2), d1
F003A2  b2 ae 00 14             cmp.l    $14(a6), d1
F003A6  66 1e                   bne.b    loc_F003C6

loc_F003A8:
F003A8  3f 2a 00 04             move.w   $4(a2), -(a7)
F003AC  24 6a 00 06             movea.l  $6(a2), a2
F003B0  60 ba                   bra.b    loc_F0036C

loc_F003B2:
F003B2  30 1f                   move.w   (a7)+, d0
F003B4  02 80 00 00 00 0f       andi.l   #$f, d0
F003BA  e3 88                   lsl.l    #$1, d0
F003BC  41 f9 00 f0 06 50       lea.l    loc_F00650.l, a0
F003C2  4e f0 00 00             jmp      (a0, d0.w)

loc_F003C6:
F003C6  3d 7c 00 01 01 02       move.w   #$1, $102(a6)
F003CC  60 00 02 a2             bra.w    loc_F00670
F003D0  3d 7c                   DC.W     0x3d7c  ; '=|'
F003D2  00 01                   DC.W     0x0001
F003D4  01 02                   DC.W     0x0102
F003D6  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F003D8:
F003D8  ff f8                   dc.w     $fff8
F003DA  00 00 15 20             ori.b    #$20, d0
F003DE  1c c0                   move.b   d0, (a6)+
F003E0  16 aa 18 c0             move.b   $18c0(a2), (a3)
F003E4  18 1e                   move.b   (a6)+, d4
F003E6  18 c0                   move.b   d0, (a4)+
F003E8  19 8a                   DC.W     0x198a
F003EA  18 80                   DC.W     0x1880
F003EC  19 8e                   DC.W     0x198e
F003EE  18 c0                   DC.W     0x18c0
F003F0  1a 92                   DC.W     0x1a92
F003F2  1c c0                   DC.W     0x1cc0
F003F4  1b 56                   DC.W     0x1b56
F003F6  18 80                   DC.W     0x1880
F003F8  33 6c                   DC.W     0x336c  ; '3l'
F003FA  00 00                   DC.W     0x0000
F003FC  1c 38                   DC.W     0x1c38
F003FE  1c c0                   DC.W     0x1cc0
F00400  ff d0                   DC.W     0xffd0
F00402  00 00                   DC.W     0x0000
F00404  24 9a                   DC.W     0x249a
F00406  1c 80                   DC.W     0x1c80
F00408  ff c8                   DC.W     0xffc8
F0040A  00 00                   DC.W     0x0000
F0040C  26 28                   DC.W     0x2628  ; '&('
F0040E  0a 82                   DC.W     0x0a82
F00410  2b 24                   DC.W     0x2b24  ; '+$'
F00412  00 03                   DC.W     0x0003
F00414  2b 50                   DC.W     0x2b50  ; '+P'
F00416  00 03                   DC.W     0x0003
F00418  29 e4                   DC.W     0x29e4
F0041A  0a 82                   DC.W     0x0a82
F0041C  28 90                   DC.W     0x2890
F0041E  00 01                   DC.W     0x0001
F00420  28 94                   DC.W     0x2894
F00422  08 c2                   DC.W     0x08c2
F00424  28 1a                   DC.W     0x281a
F00426  00 01                   DC.W     0x0001
F00428  28 3e                   DC.W     0x283e  ; '(>'
F0042A  08 c2                   DC.W     0x08c2
F0042C  28 a2                   DC.W     0x28a2
F0042E  00 01                   DC.W     0x0001
F00430  29 86                   DC.W     0x2986
F00432  00 01                   DC.W     0x0001
F00434  2c de                   DC.W     0x2cde
F00436  08 c0                   DC.W     0x08c0
F00438  29 86                   DC.W     0x2986
F0043A  09 c2                   DC.W     0x09c2
F0043C  27 4a                   DC.W     0x274a  ; ''J'
F0043E  08 80                   DC.W     0x0880
F00440  2c ee                   DC.W     0x2cee
F00442  24 80                   DC.W     0x2480
F00444  2c f8                   DC.W     0x2cf8
F00446  38 80                   DC.W     0x3880
F00448  38 7a                   DC.W     0x387a  ; '8z'
F0044A  0e c0                   DC.W     0x0ec0
F0044C  34 34                   DC.W     0x3434  ; '44'
F0044E  16 c0                   DC.W     0x16c0
F00450  28 7a                   DC.W     0x287a  ; '(z'
F00452  00 01                   DC.W     0x0001
F00454  1f 30                   DC.W     0x1f30
F00456  18 c2                   DC.W     0x18c2
F00458  1f a2                   DC.W     0x1fa2
F0045A  00 00                   DC.W     0x0000
F0045C  22 1e                   DC.W     0x221e
F0045E  00 00                   DC.W     0x0000
F00460  20 d0                   DC.W     0x20d0
F00462  00 00                   DC.W     0x0000
F00464  1f ca                   DC.W     0x1fca
F00466  12 c2                   DC.W     0x12c2
F00468  23 e8                   DC.W     0x23e8
F0046A  00 01                   DC.W     0x0001
F0046C  23 56                   DC.W     0x2356  ; '#V'
F0046E  00 04                   DC.W     0x0004
F00470  ff 60                   DC.W     0xff60
F00472  00 00                   DC.W     0x0000
F00474  ff 5c                   DC.W     0xff5c
F00476  00 00                   DC.W     0x0000
F00478  ff 58                   DC.W     0xff58
F0047A  00 00                   DC.W     0x0000
F0047C  2c d4                   DC.W     0x2cd4
F0047E  0a 80                   DC.W     0x0a80
F00480  2e 7c                   DC.W     0x2e7c  ; '.|'
F00482  08 80                   DC.W     0x0880
F00484  2e 74                   DC.W     0x2e74  ; '.t'
F00486  08 80                   DC.W     0x0880
F00488  2e da                   DC.W     0x2eda
F0048A  0a 80                   DC.W     0x0a80
F0048C  2c be                   DC.W     0x2cbe
F0048E  0a 80                   DC.W     0x0a80
F00490  30 00                   DC.W     0x3000
F00492  00 00                   DC.W     0x0000
F00494  ff 3c                   DC.W     0xff3c
F00496  00 00                   DC.W     0x0000
F00498  ff 38                   DC.W     0xff38
F0049A  00 00                   DC.W     0x0000
F0049C  ff 34                   DC.W     0xff34
F0049E  00 00                   DC.W     0x0000
F004A0  ff 30                   DC.W     0xff30
F004A2  00 00                   DC.W     0x0000
F004A4  35 70                   DC.W     0x3570  ; '5p'
F004A6  06 80                   DC.W     0x0680
F004A8  35 fa                   DC.W     0x35fa
F004AA  00 00                   DC.W     0x0000
F004AC  36 ba                   DC.W     0x36ba
F004AE  00 00                   DC.W     0x0000
F004B0  37 22                   DC.W     0x3722  ; '7"'
F004B2  14 c0                   DC.W     0x14c0
F004B4  ff 1c                   DC.W     0xff1c
F004B6  00 00                   DC.W     0x0000
F004B8  ff 18                   DC.W     0xff18
F004BA  00 00                   DC.W     0x0000
F004BC  ff 14                   DC.W     0xff14
F004BE  00 00                   DC.W     0x0000
F004C0  1e 20                   DC.W     0x1e20
F004C2  08 80                   DC.W     0x0880
F004C4  34 fe                   DC.W     0x34fe
F004C6  00 00                   DC.W     0x0000
F004C8  38 44                   DC.W     0x3844  ; '8D'
F004CA  00 00                   DC.W     0x0000
F004CC  1c 16                   DC.W     0x1c16
F004CE  10 c0                   DC.W     0x10c0
F004D0  1d ae                   DC.W     0x1dae
F004D2  04 80                   DC.W     0x0480
F004D4  fe fc                   DC.W     0xfefc
F004D6  00 00                   DC.W     0x0000
F004D8  2f dc                   DC.W     0x2fdc
F004DA  10 c1                   DC.W     0x10c1
F004DC  30 94                   DC.W     0x3094
F004DE  10 c0                   DC.W     0x10c0
F004E0  30 e6                   DC.W     0x30e6
F004E2  0c c0                   DC.W     0x0cc0
F004E4  31 3c                   DC.W     0x313c  ; '1<'
F004E6  0c c0                   DC.W     0x0cc0
F004E8  31 84                   DC.W     0x3184
F004EA  0c c0                   DC.W     0x0cc0
F004EC  31 d6                   DC.W     0x31d6
F004EE  0c c0                   DC.W     0x0cc0
F004F0  fe e0                   DC.W     0xfee0
F004F2  00 00                   DC.W     0x0000
F004F4  fe dc                   DC.W     0xfedc
F004F6  00 00                   DC.W     0x0000
F004F8  19 84                   DC.W     0x1984
F004FA  1c 80                   DC.W     0x1c80
F004FC  32 b8                   DC.W     0x32b8
F004FE  08 80                   DC.W     0x0880
F00500  33 62                   DC.W     0x3362  ; '3b'
F00502  08 80                   DC.W     0x0880
F00504  fe cc                   DC.W     0xfecc
F00506  00 00                   DC.W     0x0000
F00508  1d 0e                   DC.W     0x1d0e
F0050A  10 c0                   DC.W     0x10c0

loc_F0050C:
F0050C  2e 78 0c 08             movea.l  $c08.w, a7

loc_F00510:
F00510  46 fc 20 00             move.w   #$2000, sr
F00514  61 00 0a ac             bsr.w    loc_F00FC2
F00518  4d f8 0c 08             lea.l    $c08.w, a6

loc_F0051C:
F0051C  22 4e                   movea.l  a6, a1
F0051E  4a a9 00 0c             tst.l    $c(a1)
F00522  67 ec                   beq.b    loc_F00510
F00524  00 7c 07 00             ori.w    #$700, sr
F00528  2c 69 00 0c             movea.l  $c(a1), a6
F0052C  30 2e 00 2c             move.w   $2c(a6), d0
F00530  02 40 ff 00             andi.w   #$ff00, d0
F00534  66 e6                   bne.b    loc_F0051C
F00536  23 6e 00 0c 00 0c       move.l   $c(a6), $c(a1)
F0053C  08 ae 00 04 00 2d       bclr.b   #$4, $2d(a6)
F00542  21 ce 0c 0c             move.l   a6, $c0c.w
F00546  2a 4e                   movea.l  a6, a5
F00548  db fc 00 00 01 00       adda.l   #$100, a5
F0054E  10 2e 00 72             move.b   $72(a6), d0

loc_F00552:
F00552  3f 25                   move.w   -(a5), -(a7)
F00554  32 0d                   move.w   a5, d1
F00556  b0 01                   cmp.b    d1, d0
F00558  66 f8                   bne.b    loc_F00552
F0055A  42 38 0c 5b             clr.b    $c5b.w
F0055E  02 7c f8 ff             andi.w   #$f8ff, sr
F00562  31 f8 0c 54 0c 52       move.w   $c54.w, $c52.w

loc_F00568:
F00568  08 ae 00 06 00 2d       bclr.b   #$6, $2d(a6)
F0056E  66 50                   bne.b    loc_F005C0
F00570  08 2e 00 07 00 2d       btst.b   #$7, $2d(a6)
F00576  66 54                   bne.b    loc_F005CC
F00578  08 ae 00 05 00 2d       bclr.b   #$5, $2d(a6)
F0057E  66 58                   bne.b    loc_F005D8

loc_F00580:
F00580  4a b8 0c 1c             tst.l    $c1c.w
F00584  67 08                   beq.b    loc_F0058E
F00586  2a 6e 00 36             movea.l  $36(a6), a5
F0058A  61 00 01 46             bsr.w    loc_F006D2

loc_F0058E:
F0058E  20 6e 01 3c             movea.l  $13c(a6), a0
F00592  4e 60                   move     a0, usp
F00594  4c ee 3f ff 01 00       movem.l  $100(a6), d0-d7/a0-a5
F0059A  08 38 00 0a 0c 34       btst.b   #$a, $c34.w
F005A0  67 06                   beq.b    loc_F005A8
F005A2  61 00 10 e4             bsr.w    loc_F01688
F005A6  fd 10                   dc.w     $fd10

loc_F005A8:
F005A8  08 ae 00 0f 01 48       bclr.b   #$f, $148(a6)
F005AE  66 06                   bne.b    loc_F005B6
F005B0  2c 6e 01 38             movea.l  $138(a6), a6
F005B4  4e 73                   rte      

loc_F005B6:
F005B6  2c 6e 01 38             movea.l  $138(a6), a6
F005BA  00 7c 80 00             ori.w    #$8000, sr
F005BE  4e 73                   rte      

loc_F005C0:
F005C0  4c ee 7f ff 00 74       movem.l  $74(a6), d0-d7/a0-a6
F005C6  1d 40 00 26             move.b   d0, $26(a6)
F005CA  4e 73                   rte      

loc_F005CC:
F005CC  48 7a ff 3e             pea.l    loc_F0050C(pc)
F005D0  3f 3c 20 00             move.w   #$2000, -(a7)
F005D4  60 00 29 8e             bra.w    loc_F02F64

loc_F005D8:
F005D8  2a 6e 00 40             movea.l  $40(a6), a5
F005DC  7a 42                   moveq    #$42, d5
F005DE  08 2d 00 0b 00 04       btst.b   #$b, $4(a5)
F005E4  67 02                   beq.b    loc_F005E8
F005E6  7a 06                   moveq    #$6, d5

loc_F005E8:
F005E8  2c 2e 01 3c             move.l   $13c(a6), d6
F005EC  9c 85                   sub.l    d5, d6
F005EE  2e 05                   move.l   d5, d7
F005F0  20 6e 00 36             movea.l  $36(a6), a0
F005F4  61 00 11 66             bsr.w    loc_F0175C
F005F8  60 0c                   bra.b    loc_F00606
F005FA  4e 71                   DC.W     0x4e71  ; 'Nq'
F005FC  08 ec                   DC.W     0x08ec
F005FE  00 0a                   DC.W     0x000a
F00600  00 04                   DC.W     0x0004
F00602  60 00                   DC.W     0x6000
F00604  ff 7c                   DC.W     0xff7c

loc_F00606:
F00606  dc 87                   add.l    d7, d6
F00608  28 46                   movea.l  d6, a4
F0060A  39 6e 00 fa ff fa       move.w   $fa(a6), -$6(a4)
F00610  29 6e 00 fc ff fc       move.l   $fc(a6), -$4(a4)
F00616  5d ae 01 3c             subq.l   #$6, $13c(a6)
F0061A  08 2d 00 0b 00 04       btst.b   #$b, $4(a5)
F00620  66 20                   bne.b    loc_F00642
F00622  4c ee 0f ff 01 00       movem.l  $100(a6), d0-d7/a0-a3
F00628  48 ec 0f ff ff be       movem.l  d0-d7/a0-a3, -$42(a4)
F0062E  4c ee 00 07 01 30       movem.l  $130(a6), d0-d2
F00634  48 ec 00 07 ff ee       movem.l  d0-d2, -$12(a4)
F0063A  04 ae 00 00 00 3c 01 3c  subi.l   #$3c, $13c(a6)

loc_F00642:
F00642  2f 6d 00 12 00 02       move.l   $12(a5), $2(a7)
F00648  60 00 ff 36             bra.w    loc_F00580
F0064C  60 00 fe be             bra.w    loc_F0050C

loc_F00650:
F00650  60 08                   bra.b    loc_F0065A
F00652  60 16                   DC.W     0x6016
F00654  60 1a                   DC.W     0x601a
F00656  60 f4                   DC.W     0x60f4
F00658  60 22                   DC.W     0x6022  ; '`"'

loc_F0065A:
F0065A  4a 38 0c 5b             tst.b    $c5b.w
F0065E  66 10                   bne.b    loc_F00670
F00660  61 30                   bsr.b    loc_F00692
F00662  3e ae 00 fa             move.w   $fa(a6), (a7)
F00666  60 00 ff 00             bra.w    loc_F00568
F0066A  4a 6e 01 02             tst.w    $102(a6)
F0066E  67 06                   beq.b    loc_F00676

loc_F00670:
F00670  41 d6                   lea.l    (a6), a0
F00672  61 00 01 88             bsr.w    loc_F007FC

loc_F00676:
F00676  48 7a fe 94             pea.l    loc_F0050C(pc)
F0067A  60 16                   bra.b    loc_F00692
F0067C  3e ae 00 fa             move.w   $fa(a6), (a7)
F00680  48 7a fe e6             pea.l    loc_F00568(pc)
F00684  60 1c                   bra.b    loc_F006A2

loc_F00686:
F00686  41 d6                   lea.l    (a6), a0
F00688  61 00 01 72             bsr.w    loc_F007FC

loc_F0068C:
F0068C  48 7a fe 7e             pea.l    loc_F0050C(pc)
F00690  60 10                   bra.b    loc_F006A2

loc_F00692:
F00692  4a 6e 01 02             tst.w    $102(a6)
F00696  66 04                   bne.b    loc_F0069C
F00698  42 ae 01 00             clr.l    $100(a6)

loc_F0069C:
F0069C  40 c1                   move.w   sr, d1
F0069E  1d 41 00 fb             move.b   d1, $fb(a6)

loc_F006A2:
F006A2  2d 6f 00 06 00 fc       move.l   $6(a7), $fc(a6)
F006A8  1d 7c 00 fa 00 72       move.b   #$fa, $72(a6)
F006AE  4e 75                   rts      

loc_F006B0:
F006B0  48 56                   pea.l    (a6)
F006B2  2c 78 0c 0c             movea.l  $c0c.w, a6
F006B6  48 ee 3f ff 01 00       movem.l  d0-d7/a0-a5, $100(a6)
F006BC  2d 5f 01 38             move.l   (a7)+, $138(a6)
F006C0  4e 69                   move     usp, a1
F006C2  2d 49 01 3c             move.l   a1, $13c(a6)
F006C6  22 78 0c 08             movea.l  $c08.w, a1
F006CA  3d 69 ff fa 00 fa       move.w   -$6(a1), $fa(a6)
F006D0  4e 75                   rts      

loc_F006D2:
F006D2  40 e7                   move.w   sr, -(a7)

loc_F006D4:
F006D4  00 7c 07 00             ori.w    #$700, sr
F006D8  08 38 00 08 0c 34       btst.b   #$8, $c34.w
F006DE  67 06                   beq.b    loc_F006E6
F006E0  61 00 0f a6             bsr.w    loc_F01688
F006E4  dd 08                   addx.b   -(a0), -(a6)

loc_F006E6:
F006E6  4e 73                   rte      

loc_F006E8:
F006E8  40 e7                   move.w   sr, -(a7)
F006EA  00 7c 07 00             ori.w    #$700, sr

loc_F006EE:
F006EE  4a d0                   tas.b    (a0)
F006F0  6b fc                   bmi.b    loc_F006EE
F006F2  30 10                   move.w   (a0), d0
F006F4  e3 48                   lsl.w    #$1, d0
F006F6  e2 40                   asr.w    #$1, d0
F006F8  53 40                   subq.w   #$1, d0
F006FA  30 80                   move.w   d0, (a0)
F006FC  6b 02                   bmi.b    loc_F00700
F006FE  4e 73                   rte      

loc_F00700:
F00700  61 3a                   bsr.b    loc_F0073C
F00702  61 14                   bsr.b    loc_F00718
F00704  08 90 00 0f             bclr.b   #$f, (a0)
F00708  46 df                   move.w   (a7)+, sr
F0070A  2e 78 0c 08             movea.l  $c08.w, a7
F0070E  41 d6                   lea.l    (a6), a0
F00710  61 00 00 ae             bsr.w    loc_F007C0
F00714  60 00 fd f6             bra.w    loc_F0050C

loc_F00718:
F00718  08 ee 00 0d 00 2c       bset.b   #$d, $2c(a6)
F0071E  42 ae 00 20             clr.l    $20(a6)
F00722  20 28 00 02             move.l   $2(a0), d0
F00726  66 06                   bne.b    loc_F0072E
F00728  21 4e 00 02             move.l   a6, $2(a0)
F0072C  4e 75                   rts      

loc_F0072E:
F0072E  2a 40                   movea.l  d0, a5
F00730  20 2d 00 20             move.l   $20(a5), d0
F00734  66 f8                   bne.b    loc_F0072E
F00736  2b 4e 00 20             move.l   a6, $20(a5)
F0073A  4e 75                   rts      

loc_F0073C:
F0073C  10 2e 00 26             move.b   $26(a6), d0
F00740  1d 7c 00 f0 00 26       move.b   #$f0, $26(a6)
F00746  08 ee 00 06 00 2d       bset.b   #$6, $2d(a6)
F0074C  48 ee 7f ff 00 74       movem.l  d0-d7/a0-a6, $74(a6)
F00752  48 e7 01 0c             movem.l  d7/a4-a5, -(a7)
F00756  20 38 0c 08             move.l   $c08.w, d0
F0075A  4b ef 00 10             lea.l    $10(a7), a5
F0075E  90 8d                   sub.l    a5, d0
F00760  0c 80 00 00 00 50       cmpi.l   #$50, d0
F00766  6f 04                   ble.b    loc_F0076C
F00768  61 00 fa 1c             bsr.w    loc_F00186

loc_F0076C:
F0076C  2e 0d                   move.l   a5, d7
F0076E  02 87 00 00 00 ff       andi.l   #$ff, d7
F00774  49 f6 70 00             lea.l    (a6, d7.w), a4
F00778  1d 47 00 72             move.b   d7, $72(a6)

loc_F0077C:
F0077C  38 dd                   move.w   (a5)+, (a4)+
F0077E  55 40                   subq.w   #$2, d0
F00780  6e fa                   bgt.b    loc_F0077C
F00782  4c df 30 80             movem.l  (a7)+, d7/a4-a5
F00786  4e 75                   rts      

loc_F00788:
F00788  40 e7                   move.w   sr, -(a7)
F0078A  00 7c 07 00             ori.w    #$700, sr

loc_F0078E:
F0078E  4a d0                   tas.b    (a0)
F00790  6b fc                   bmi.b    loc_F0078E
F00792  30 10                   move.w   (a0), d0
F00794  e3 48                   lsl.w    #$1, d0
F00796  e2 40                   asr.w    #$1, d0
F00798  52 40                   addq.w   #$1, d0
F0079A  6f 04                   ble.b    loc_F007A0
F0079C  30 80                   move.w   d0, (a0)
F0079E  4e 73                   rte      

loc_F007A0:
F007A0  2f 09                   move.l   a1, -(a7)
F007A2  22 68 00 02             movea.l  $2(a0), a1
F007A6  21 69 00 20 00 02       move.l   $20(a1), $2(a0)
F007AC  08 80 00 0f             bclr.b   #$f, d0
F007B0  30 80                   move.w   d0, (a0)
F007B2  42 a9 00 20             clr.l    $20(a1)
F007B6  08 a9 00 0d 00 2c       bclr.b   #$d, $2c(a1)
F007BC  22 5f                   movea.l  (a7)+, a1
F007BE  4e 73                   rte      

loc_F007C0:
F007C0  40 e7                   move.w   sr, -(a7)
F007C2  08 e8 00 04 00 2d       bset.b   #$4, $2d(a0)
F007C8  66 30                   bne.b    loc_F007FA
F007CA  48 e7 00 60             movem.l  a1-a2, -(a7)
F007CE  43 f8 0c 08             lea.l    $c08.w, a1
F007D2  00 7c 07 00             ori.w    #$700, sr
F007D6  10 28 00 26             move.b   $26(a0), d0

loc_F007DA:
F007DA  24 49                   movea.l  a1, a2
F007DC  22 6a 00 0c             movea.l  $c(a2), a1
F007E0  b3 fc 00 00 00 00       cmpa.l   #$0, a1
F007E6  67 06                   beq.b    loc_F007EE
F007E8  b0 29 00 26             cmp.b    $26(a1), d0
F007EC  63 ec                   bls.b    loc_F007DA

loc_F007EE:
F007EE  21 49 00 0c             move.l   a1, $c(a0)
F007F2  25 48 00 0c             move.l   a0, $c(a2)
F007F6  4c df 06 00             movem.l  (a7)+, a1-a2

loc_F007FA:
F007FA  4e 73                   rte      

loc_F007FC:
F007FC  11 68 00 24 00 26       move.b   $24(a0), $26(a0)
F00802  60 bc                   bra.b    loc_F007C0
F00804  10 28 00 24             move.b   $24(a0), d0
F00808  02 00 00 f0             andi.b   #$f0, d0
F0080C  11 40 00 26             move.b   d0, $26(a0)
F00810  60 ae                   bra.b    loc_F007C0

loc_F00812:
F00812  60 ac                   bra.b    loc_F007C0

loc_F00814:
F00814  40 e7                   move.w   sr, -(a7)
F00816  1d 7c 00 f0 00 25       move.b   #$f0, $25(a6)
F0081C  61 00 ff 1e             bsr.w    loc_F0073C
F00820  60 00 fc ea             bra.w    loc_F0050C

loc_F00824:
F00824  40 e7                   move.w   sr, -(a7)
F00826  08 c7 00 0f             bset.b   #$f, d7
F0082A  31 47 00 2a             move.w   d7, $2a(a0)
F0082E  42 68 00 5c             clr.w    $5c(a0)
F00832  08 e8 00 01 00 29       bset.b   #$1, $29(a0)
F00838  21 7c 45 58 45 43 00 b0  move.l   #$45584543, $b0(a0)
F00840  21 7c 20 20 20 20 00 b4  move.l   #$20202020, $b4(a0)
F00848  3c 28 00 2c             move.w   $2c(a0), d6
F0084C  08 c6 00 07             bset.b   #$7, d6
F00850  31 46 00 2e             move.w   d6, $2e(a0)
F00854  bd c8                   cmpa.l   a0, a6
F00856  67 24                   beq.b    loc_F0087C
F00858  02 46 2d ff             andi.w   #$2dff, d6
F0085C  08 86 00 0a             bclr.b   #$a, d6
F00860  67 04                   beq.b    loc_F00866
F00862  08 86 00 06             bclr.b   #$6, d6

loc_F00866:
F00866  31 46 00 2c             move.w   d6, $2c(a0)
F0086A  11 7c 00 f0 00 26       move.b   #$f0, $26(a0)
F00870  08 06 00 0d             btst.b   #$d, d6
F00874  66 04                   bne.b    loc_F0087A
F00876  61 00 ff 48             bsr.w    loc_F007C0

loc_F0087A:
F0087A  4e 73                   rte      

loc_F0087C:
F0087C  31 46 00 2c             move.w   d6, $2c(a0)
F00880  5c 8f                   addq.l   #$6, a7
F00882  20 3c 00 00 00 0f       move.l   #$f, d0
F00888  31 57 00 fa             move.w   (a7), $fa(a0)
F0088C  21 6f 00 02 00 fc       move.l   $2(a7), $fc(a0)
F00892  60 00 fa 7c             bra.w    loc_F00310

loc_F00896:
F00896  08 38 00 0e 0c 34       btst.b   #$e, $c34.w
F0089C  67 06                   beq.b    loc_F008A4
F0089E  61 00 0d e8             bsr.w    loc_F01688
F008A2  ee 14                   roxr.b   #$7, d4

loc_F008A4:
F008A4  4e 73                   rte      

loc_F008A6:
F008A6  2a 5f                   movea.l  (a7)+, a5
F008A8  61 00 fe 28             bsr.w    loc_F006D2
F008AC  20 5f                   movea.l  (a7)+, a0
F008AE  4e 60                   move     a0, usp
F008B0  4c df 7f ff             movem.l  (a7)+, d0-d7/a0-a6
F008B4  5c 8f                   addq.l   #$6, a7
F008B6  48 e7 80 80             movem.l  d0/a0, -(a7)

loc_F008BA:
F008BA  20 38 0e 48             move.l   $e48.w, d0
F008BE  67 14                   beq.b    loc_F008D4
F008C0  20 40                   movea.l  d0, a0
F008C2  00 50 00 20             ori.w    #$20, (a0)
F008C6  20 78 0c 4e             movea.l  $c4e.w, a0
F008CA  30 28 00 18             move.w   $18(a0), d0
F008CE  08 00 00 01             btst.b   #$1, d0
F008D2  67 e6                   beq.b    loc_F008BA

loc_F008D4:
F008D4  4c df 01 01             movem.l  (a7)+, d0/a0
F008D8  3f 17                   move.w   (a7), -(a7)
F008DA  02 17 00 7f             andi.b   #$7f, (a7)
F008DE  54 8f                   addq.l   #$2, a7
F008E0  66 c2                   bne.b    loc_F008A4
F008E2  4a 38 0c 5b             tst.b    $c5b.w
F008E6  67 bc                   beq.b    loc_F008A4
F008E8  02 7c f8 ff             andi.w   #$f8ff, sr
F008EC  61 00 fd c2             bsr.w    loc_F006B0
F008F0  41 d6                   lea.l    (a6), a0
F008F2  61 00 ff 1e             bsr.w    loc_F00812
F008F6  60 00 fd 94             bra.w    loc_F0068C

loc_F008FA:
F008FA  40 e7                   move.w   sr, -(a7)
F008FC  08 38 00 09 0c 34       btst.b   #$9, $c34.w
F00902  67 06                   beq.b    loc_F0090A
F00904  61 00 0d 82             bsr.w    loc_F01688
F00908  ee 09                   lsr.b    #$7, d1

loc_F0090A:
F0090A  48 e7 ff fe             movem.l  d0-d7/a0-a6, -(a7)
F0090E  4e 69                   move     usp, a1
F00910  2f 09                   move.l   a1, -(a7)
F00912  2f 38 0c 62             move.l   $c62.w, -(a7)
F00916  20 6f 00 46             movea.l  $46(a7), a0
F0091A  2c 68 00 02             movea.l  $2(a0), a6
F0091E  48 56                   pea.l    (a6)
F00920  2f 28 00 06             move.l   $6(a0), -(a7)
F00924  40 c0                   move.w   sr, d0
F00926  02 40 0f ff             andi.w   #$fff, d0
F0092A  3f 00                   move.w   d0, -(a7)
F0092C  22 68 00 0a             movea.l  $a(a0), a1
F00930  30 50                   movea.w  (a0), a0
F00932  2a 6e 00 36             movea.l  $36(a6), a5
F00936  60 00 fd 9c             bra.w    loc_F006D4

loc_F0093A:
F0093A  08 17 00 0d             btst.b   #$d, (a7)
F0093E  66 00 ff 64             bne.w    loc_F008A4
F00942  5c 8f                   addq.l   #$6, a7
F00944  2c 5f                   movea.l  (a7)+, a6
F00946  28 16                   move.l   (a6), d4
F00948  0c 84 21 54 43 42       cmpi.l   #$21544342, d4
F0094E  67 04                   beq.b    loc_F00954
F00950  61 00 f8 34             bsr.w    loc_F00186

loc_F00954:
F00954  4a 40                   tst.w    d0
F00956  67 00 ff 4e             beq.w    loc_F008A6
F0095A  0c 40 00 01             cmpi.w   #$1, d0
F0095E  66 0a                   bne.b    loc_F0096A
F00960  41 d6                   lea.l    (a6), a0
F00962  61 00 23 08             bsr.w    loc_F02C6C
F00966  60 00 ff 3e             bra.w    loc_F008A6

loc_F0096A:
F0096A  0c 40 00 02             cmpi.w   #$2, d0
F0096E  66 00 ff 36             bne.w    loc_F008A6
F00972  4a 81                   tst.l    d1
F00974  66 16                   bne.b    loc_F0098C
F00976  26 02                   move.l   d2, d3
F00978  48 43                   swap     d3
F0097A  34 3c 06 02             move.w   #$602, d2
F0097E  48 42                   swap     d2

loc_F00980:
F00980  41 d6                   lea.l    (a6), a0
F00982  61 00 0c 7c             bsr.w    loc_F01600
F00986  4e 71                   nop      
F00988  60 00 ff 1c             bra.w    loc_F008A6

loc_F0098C:
F0098C  48 42                   swap     d2
F0098E  48 41                   swap     d1
F00990  28 02                   move.l   d2, d4
F00992  26 01                   move.l   d1, d3
F00994  36 02                   move.w   d2, d3
F00996  34 3c 0a 82             move.w   #$a82, d2
F0099A  48 42                   swap     d2
F0099C  34 01                   move.w   d1, d2
F0099E  60 e0                   bra.b    loc_F00980

loc_F009A0:
F009A0  e2 88                   lsr.l    #$1, d0
F009A2  26 00                   move.l   d0, d3
F009A4  54 8f                   addq.l   #$2, a7
F009A6  28 1f                   move.l   (a7)+, d4
F009A8  2c 5f                   movea.l  (a7)+, a6
F009AA  22 16                   move.l   (a6), d1
F009AC  0c 81 21 54 43 42       cmpi.l   #$21544342, d1
F009B2  67 04                   beq.b    loc_F009B8
F009B4  61 00 f7 d0             bsr.w    loc_F00186

loc_F009B8:
F009B8  00 43 f0 00             ori.w    #$f000, d3
F009BC  3d 43 00 5e             move.w   d3, $5e(a6)
F009C0  41 d6                   lea.l    (a6), a0
F009C2  61 00 22 a8             bsr.w    loc_F02C6C
F009C6  4a ae 00 40             tst.l    $40(a6)
F009CA  67 00 fe da             beq.w    loc_F008A6
F009CE  24 3c 0a 02 ff ff       move.l   #$a02ffff, d2
F009D4  48 43                   swap     d3
F009D6  48 44                   swap     d4
F009D8  36 04                   move.w   d4, d3
F009DA  60 a4                   bra.b    loc_F00980
F009DC  2f 08                   DC.W     0x2f08
F009DE  20 78                   DC.W     0x2078  ; ' x'
F009E0  0e 48                   DC.W     0x0e48
F009E2  02 50                   DC.W     0x0250
F009E4  ff df                   DC.W     0xffdf
F009E6  20 5f 4e 73 52 78       DC.B     " _NsRx"  ; 6 bytes
F009EC  0c 5c                   DC.W     0x0c5c
F009EE  0c 78                   DC.W     0x0c78
F009F0  00 64                   DC.W     0x0064
F009F2  0c 5c                   DC.W     0x0c5c
F009F4  6b 24 2f                DC.B     "k$/"  ; 3 bytes
F009F7  09 22                   DC.W     0x0922
F009F9  78 0c                   DC.W     0x780c
F009FB  3a 33                   DC.W     0x3a33  ; ':3'
F009FD  7c 00                   DC.W     0x7c00
F009FF  15 00                   DC.W     0x1500
F00A01  04 33                   DC.W     0x0433
F00A03  7c 00                   DC.W     0x7c00
F00A05  35 00                   DC.W     0x3500
F00A07  04 33                   DC.W     0x0433
F00A09  7c 00                   DC.W     0x7c00
F00A0B  2e 00                   DC.W     0x2e00
F00A0D  04 33                   DC.W     0x0433
F00A0F  7c 00                   DC.W     0x7c00
F00A11  3e 00                   DC.W     0x3e00
F00A13  04 22                   DC.W     0x0422
F00A15  5f 42 78                DC.B     "_Bx"  ; 3 bytes
F00A18  0c 5c                   DC.W     0x0c5c
F00A1A  4e 73                   rte      
F00A1C  4a b8                   DC.W     0x4ab8
F00A1E  0c 78                   DC.W     0x0c78
F00A20  66 10                   DC.W     0x6610
F00A22  00 7c                   DC.W     0x007c
F00A24  70 00                   DC.W     0x7000
F00A26  48 e7                   DC.W     0x48e7
F00A28  ff fe                   DC.W     0xfffe
F00A2A  21 cf                   DC.W     0x21cf
F00A2C  0c 78                   DC.W     0x0c78
F00A2E  46 ef                   DC.W     0x46ef
F00A30  00 3c                   DC.W     0x003c
F00A32  2e 78 0c 78             movea.l  $c78.w, a7
F00A36  00 7c 07 00             ori.w    #$700, sr
F00A3A  10 39 00 f7 00 30       move.b   $f70030.l, d0
F00A40  00 00 00 20             ori.b    #$20, d0
F00A44  13 c0 00 f7 00 30       move.b   d0, $f70030.l
F00A4A  2e 78 0c 78             movea.l  $c78.w, a7
F00A4E  4c df ff ff             movem.l  (a7)+, d0-d7/a0-a7
F00A52  42 b8 0c 78             clr.l    $c78.w
F00A56  4e 73                   rte      
F00A58  48 f8                   DC.W     0x48f8
F00A5A  ff ff                   DC.W     0xffff
F00A5C  08 08                   DC.W     0x0808
F00A5E  31 d7                   DC.W     0x31d7
F00A60  08 06                   DC.W     0x0806
F00A62  21 ef                   DC.W     0x21ef
F00A64  00 02                   DC.W     0x0002
F00A66  08 00                   DC.W     0x0800
F00A68  00 7c                   DC.W     0x007c
F00A6A  07 00                   DC.W     0x0700
F00A6C  4c f8                   DC.W     0x4cf8
F00A6E  ff ff                   DC.W     0xffff
F00A70  08 08                   DC.W     0x0808
F00A72  4e 73                   DC.W     0x4e73  ; 'Ns'
F00A74  61 20                   DC.W     0x6120  ; 'a '

loc_F00A76:
F00A76  61 1e                   bsr.b    loc_F00A96
F00A78  61 1c                   bsr.b    loc_F00A96
F00A7A  61 1a                   bsr.b    loc_F00A96
F00A7C  61 18                   bsr.b    loc_F00A96
F00A7E  61 16                   bsr.b    loc_F00A96
F00A80  61 14                   bsr.b    loc_F00A96
F00A82  61 12                   bsr.b    loc_F00A96
F00A84  61 10                   bsr.b    loc_F00A96
F00A86  61 0e                   bsr.b    loc_F00A96
F00A88  61 0c                   bsr.b    loc_F00A96
F00A8A  61 0a                   bsr.b    loc_F00A96
F00A8C  61 08                   bsr.b    loc_F00A96
F00A8E  61 06                   bsr.b    loc_F00A96
F00A90  61 04                   bsr.b    loc_F00A96
F00A92  61 02                   bsr.b    loc_F00A96
F00A94  4e 71                   nop      

loc_F00A96:
F00A96  3f 2f 00 04             move.w   $4(a7), -(a7)
F00A9A  02 17 00 7f             andi.b   #$7f, (a7)
F00A9E  54 8f                   addq.l   #$2, a7
F00AA0  67 0e                   beq.b    loc_F00AB0
F00AA2  08 2f 00 0d 00 04       btst.b   #$d, $4(a7)
F00AA8  67 00 01 bc             beq.w    loc_F00C66
F00AAC  61 00 f6 d8             bsr.w    loc_F00186

loc_F00AB0:
F00AB0  61 00 fb fe             bsr.w    loc_F006B0
F00AB4  08 38 00 0c 0c 34       btst.b   #$c, $c34.w

loc_F00ABA:
F00ABA  67 0a                   beq.b    loc_F00AC6
F00ABC  40 e7                   move.w   sr, -(a7)
F00ABE  61 00 0b c8             bsr.w    loc_F01688
F00AC2  aa 12                   dc.w     $aa12
F00AC4  54 8f                   addq.l   #$2, a7

loc_F00AC6:
F00AC6  4b fa 00 06             lea.l    loc_F00ACE(pc), a5
F00ACA  60 00 00 a8             bra.w    loc_F00B74

loc_F00ACE:
F00ACE  00 f0                   DC.W     0x00f0
F00AD0  0a 76                   DC.W     0x0a76
F00AD2  00 03                   DC.W     0x0003
F00AD4  00 4c                   DC.W     0x004c
F00AD6  00 02                   DC.W     0x0002
F00AD8  61 50 61 58 61 32 ..    DC.B     "aPaXa2a0a.a,a*a(a&NqNqa"  ; 23 bytes
F00AEF  02 4e                   DC.W     0x024e
F00AF1  71 3f                   DC.W     0x713f  ; 'q?'
F00AF3  2f 00                   DC.W     0x2f00
F00AF5  04 02                   DC.W     0x0402
F00AF7  17 00                   DC.W     0x1700
F00AF9  7f 54                   DC.W     0x7f54
F00AFB  8f 67                   DC.W     0x8f67
F00AFD  50 08                   DC.W     0x5008
F00AFF  2f 00                   DC.W     0x2f00
F00B01  0d 00                   DC.W     0x0d00
F00B03  04 66                   DC.W     0x0466
F00B05  00 02                   DC.W     0x0002
F00B07  0e 58                   DC.W     0x0e58
F00B09  8f 08                   DC.W     0x8f08
F00B0B  97 00                   DC.W     0x9700
F00B0D  0f 4e                   DC.W     0x0f4e
F00B0F  73 3f                   DC.W     0x733f  ; 's?'
F00B11  2f 00                   DC.W     0x2f00
F00B13  04 02                   DC.W     0x0402
F00B15  17 00                   DC.W     0x1700
F00B17  7f 54                   DC.W     0x7f54
F00B19  8f 67                   DC.W     0x8f67
F00B1B  32 08                   DC.W     0x3208
F00B1D  2f 00                   DC.W     0x2f00
F00B1F  0d 00                   DC.W     0x0d00
F00B21  04 67                   DC.W     0x0467
F00B23  00 01                   DC.W     0x0001
F00B25  54 61                   DC.W     0x5461  ; 'Ta'
F00B27  00 f6                   DC.W     0x00f6
F00B29  5e 08                   DC.W     0x5e08
F00B2B  2f 00                   DC.W     0x2f00
F00B2D  0d 00                   DC.W     0x0d00
F00B2F  0c 66                   DC.W     0x0c66
F00B31  00 01                   DC.W     0x0001
F00B33  ce 3f                   DC.W     0xce3f
F00B35  2f 00                   DC.W     0x2f00
F00B37  0c 02                   DC.W     0x0c02
F00B39  17 00                   DC.W     0x1700
F00B3B  7f 54                   DC.W     0x7f54
F00B3D  8f 67                   DC.W     0x8f67
F00B3F  0e 08                   DC.W     0x0e08
F00B41  2f 00                   DC.W     0x2f00
F00B43  0d 00                   DC.W     0x0d00
F00B45  0c 67                   DC.W     0x0c67
F00B47  00 01                   DC.W     0x0001
F00B49  2a 61                   DC.W     0x2a61  ; '*a'
F00B4B  00 f6                   DC.W     0x00f6
F00B4D  3a 61                   DC.W     0x3a61  ; ':a'
F00B4F  00 fb                   DC.W     0x00fb
F00B51  60 08                   DC.W     0x6008
F00B53  38 00                   DC.W     0x3800
F00B55  0b 0c                   DC.W     0x0b0c
F00B57  34 67                   DC.W     0x3467  ; '4g'
F00B59  0a 40                   DC.W     0x0a40
F00B5B  e7 61                   DC.W     0xe761
F00B5D  00 0b                   DC.W     0x000b
F00B5F  2a aa                   DC.W     0x2aaa
F00B61  11 54                   DC.W     0x1154
F00B63  8f 4b                   DC.W     0x8f4b
F00B65  fa 00                   DC.W     0xfa00
F00B67  04 60                   DC.W     0x0460
F00B69  0a 00                   DC.W     0x0a00
F00B6B  f0 0a                   DC.W     0xf00a
F00B6D  ba 00                   DC.W     0xba00
F00B6F  04 00                   DC.W     0x0400
F00B71  48 00                   DC.W     0x4800
F00B73  10 2e                   DC.W     0x102e
F00B75  1f 9e                   DC.W     0x1f9e
F00B77  95 e2                   DC.W     0x95e2
F00B79  8f 0c                   DC.W     0x8f0c
F00B7B  07 00                   DC.W     0x0700
F00B7D  18 6e                   DC.W     0x186e
F00B7F  00 01                   DC.W     0x0001
F00B81  04 32                   DC.W     0x0432
F00B83  2d 00                   DC.W     0x2d00
F00B85  04 34                   DC.W     0x0434
F00B87  2e 00                   DC.W     0x2e00
F00B89  28 03                   DC.W     0x2803
F00B8B  02 67                   DC.W     0x0267
F00B8D  5e 32                   DC.W     0x5e32  ; '^2'
F00B8F  2d 00                   DC.W     0x2d00
F00B91  06 2c                   DC.W     0x062c
F00B93  36 10                   DC.W     0x3610
F00B95  00 22                   DC.W     0x0022
F00B97  07 92                   DC.W     0x0792
F00B99  6d 00                   DC.W     0x6d00
F00B9B  08 e5                   DC.W     0x08e5
F00B9D  89 dc                   DC.W     0x89dc
F00B9F  81 7a                   DC.W     0x817a
F00BA1  04 20                   DC.W     0x0420
F00BA3  6e 00                   DC.W     0x6e00
F00BA5  36 61                   DC.W     0x3661  ; '6a'
F00BA7  00 0b                   DC.W     0x000b
F00BA9  b4 60                   DC.W     0xb460
F00BAB  04 4e                   DC.W     0x044e
F00BAD  71 60                   DC.W     0x7160  ; 'q`'
F00BAF  3c 22                   DC.W     0x3c22  ; '<"'
F00BB1  46 4a                   DC.W     0x464a  ; 'FJ'
F00BB3  91 67                   DC.W     0x9167
F00BB5  36 2a                   DC.W     0x362a  ; '6*'
F00BB7  38 0c                   DC.W     0x380c
F00BB9  08 9a                   DC.W     0x089a
F00BBB  8f 2c                   DC.W     0x8f2c
F00BBD  2e 01                   DC.W     0x2e01
F00BBF  3c 9c                   DC.W     0x3c9c
F00BC1  85 26                   DC.W     0x8526
F00BC3  06 20                   DC.W     0x0620
F00BC5  6e 00                   DC.W     0x6e00
F00BC7  36 61                   DC.W     0x3661  ; '6a'
F00BC9  00 0b                   DC.W     0x000b
F00BCB  92 60                   DC.W     0x9260
F00BCD  04 4e                   DC.W     0x044e
F00BCF  71 60                   DC.W     0x7160  ; 'q`'
F00BD1  1a 28                   DC.W     0x1a28
F00BD3  46 38                   DC.W     0x4638  ; 'F8'
F00BD5  df bf                   DC.W     0xdfbf
F00BD7  f8 0c                   DC.W     0xf80c
F00BD9  08 66                   DC.W     0x0866
F00BDB  f8 2f                   DC.W     0xf82f
F00BDD  11 3f                   DC.W     0x113f
F00BDF  2c ff                   DC.W     0x2cff
F00BE1  fa 3c                   DC.W     0xfa3c
F00BE3  3c 00                   DC.W     0x3c00
F00BE5  01 2d                   DC.W     0x012d
F00BE7  43 01                   DC.W     0x4301
F00BE9  3c 60                   DC.W     0x3c60  ; '<`'
F00BEB  16 42                   DC.W     0x1642
F00BED  86 0c                   DC.W     0x860c
F00BEF  07 00                   DC.W     0x0700
F00BF1  10 6d                   DC.W     0x106d
F00BF3  0e 0c                   DC.W     0x0e0c
F00BF5  07 00                   DC.W     0x0700
F00BF7  11 6e                   DC.W     0x116e
F00BF9  08 2d                   DC.W     0x082d
F00BFB  5f 00                   DC.W     0x5f00
F00BFD  b8 2d                   DC.W     0xb82d
F00BFF  5f 00                   DC.W     0x5f00
F00C01  bc 08                   DC.W     0xbc08
F00C03  2e 00                   DC.W     0x2e00
F00C05  06 00                   DC.W     0x0600
F00C07  29 67                   DC.W     0x2967  ; ')g'
F00C09  14 22                   DC.W     0x1422
F00C0B  2e 01                   DC.W     0x2e01
F00C0D  48 0f                   DC.W     0x480f
F00C0F  01 67                   DC.W     0x0167
F00C11  0c 61                   DC.W     0x0c61
F00C13  00 01                   DC.W     0x0001
F00C15  44 0c                   DC.W     0x440c
F00C17  07 00                   DC.W     0x0700
F00C19  0f 6e                   DC.W     0x0f6e
F00C1B  00 fa                   DC.W     0x00fa
F00C1D  6a 4a                   DC.W     0x6a4a  ; 'jJ'
F00C1F  06 66                   DC.W     0x0666
F00C21  00 fa                   DC.W     0x00fa
F00C23  64 0c                   DC.W     0x640c
F00C25  07 00                   DC.W     0x0700
F00C27  0f 6e                   DC.W     0x0f6e
F00C29  30 43                   DC.W     0x3043  ; '0C'
F00C2B  f8 0c                   DC.W     0xf80c
F00C2D  9a 0c                   DC.W     0x9a0c
F00C2F  31 00                   DC.W     0x3100
F00C31  02 70                   DC.W     0x0270
F00C33  00 66                   DC.W     0x0066
F00C35  0c 48                   DC.W     0x0c48
F00C37  7a fa                   DC.W     0x7afa
F00C39  54 3f                   DC.W     0x543f  ; 'T?'
F00C3B  3c 20                   DC.W     0x3c20  ; '< '
F00C3D  00 60                   DC.W     0x0060
F00C3F  00 01                   DC.W     0x0001
F00C41  82 3d                   DC.W     0x823d
F00C43  40 01                   DC.W     0x4001
F00C45  00 3d                   DC.W     0x003d
F00C47  7c 00                   DC.W     0x7c00
F00C49  01 01                   DC.W     0x0101
F00C4B  02 e7                   DC.W     0x02e7
F00C4D  8f 1d                   DC.W     0x8f1d
F00C4F  47 01                   DC.W     0x4701
F00C51  00 42                   DC.W     0x0042
F00C53  2e 00                   DC.W     0x2e00
F00C55  fb 60                   DC.W     0xfb60
F00C57  00 fa                   DC.W     0x00fa
F00C59  2e 4a                   DC.W     0x2e4a  ; '.J'
F00C5B  46 66                   DC.W     0x4666  ; 'Ff'
F00C5D  00 fa                   DC.W     0x00fa
F00C5F  28 41                   DC.W     0x2841  ; '(A'
F00C61  d6 61                   DC.W     0xd661
F00C63  00 fb                   DC.W     0x00fb
F00C65  c0 20                   DC.W     0xc020
F00C67  1f 04                   DC.W     0x1f04
F00C69  80 00                   DC.W     0x8000
F00C6B  f0 0a                   DC.W     0xf00a
F00C6D  76 60                   DC.W     0x7660  ; 'v`'
F00C6F  00 fd                   DC.W     0x00fd
F00C71  30 20                   DC.W     0x3020  ; '0 '
F00C73  1f 50                   DC.W     0x1f50
F00C75  8f 60                   DC.W     0x8f60
F00C77  02 20                   DC.W     0x0220
F00C79  1f 04                   DC.W     0x1f04
F00C7B  80 00                   DC.W     0x8000
F00C7D  f0 0a                   DC.W     0xf00a
F00C7F  ba 60                   DC.W     0xba60
F00C81  00 fd                   DC.W     0x00fd
F00C83  1e 7e                   DC.W     0x1e7e
F00C85  1c 24                   DC.W     0x1c24
F00C87  2e 01                   DC.W     0x2e01
F00C89  48 08                   DC.W     0x4808
F00C8B  02 00                   DC.W     0x0200
F00C8D  1d 66                   DC.W     0x1d66
F00C8F  16 08                   DC.W     0x1608
F00C91  02 00                   DC.W     0x0200
F00C93  1c 66                   DC.W     0x1c66
F00C95  64 08                   DC.W     0x6408
F00C97  02 00                   DC.W     0x0200
F00C99  1b 66                   DC.W     0x1b66
F00C9B  4c 4c                   DC.W     0x4c4c  ; 'LL'
F00C9D  ee 7f                   DC.W     0xee7f
F00C9F  ff 01                   DC.W     0xff01
F00CA1  00 60                   DC.W     0x0060
F00CA3  00 00                   DC.W     0x0000
F00CA5  ae 7a                   DC.W     0xae7a
F00CA7  04 2c                   DC.W     0x042c
F00CA9  2e 01                   DC.W     0x2e01
F00CAB  50 20                   DC.W     0x5020  ; 'P '
F00CAD  6e 00                   DC.W     0x6e00
F00CAF  36 61                   DC.W     0x3661  ; '6a'
F00CB1  00 0a                   DC.W     0x000a
F00CB3  aa 60                   DC.W     0xaa60
F00CB5  04 4e                   DC.W     0x044e
F00CB7  71 60                   DC.W     0x7160  ; 'q`'
F00CB9  26 7e                   DC.W     0x267e  ; '&~'
F00CBB  1d 20                   DC.W     0x1d20
F00CBD  46 26                   DC.W     0x4626  ; 'F&'
F00CBF  10 28                   DC.W     0x1028
F00CC1  2e 01                   DC.W     0x2e01
F00CC3  54 b7                   DC.W     0x54b7
F00CC5  84 08                   DC.W     0x8408
F00CC7  02 00                   DC.W     0x0200
F00CC9  1c 66                   DC.W     0x1c66
F00CCB  0c c8                   DC.W     0x0cc8
F00CCD  ae 01                   DC.W     0xae01
F00CCF  4c 67                   DC.W     0x4c67  ; 'Lg'
F00CD1  0e 2d                   DC.W     0x0e2d
F00CD3  43 01                   DC.W     0x4301
F00CD5  54 60                   DC.W     0x5460  ; 'T`'
F00CD7  22 52                   DC.W     0x2252  ; '"R'
F00CD9  87 c8                   DC.W     0x87c8
F00CDB  ae 01                   DC.W     0xae01
F00CDD  4c 67                   DC.W     0x4c67  ; 'Lg'
F00CDF  1a 08                   DC.W     0x1a08
F00CE1  02 00                   DC.W     0x0200
F00CE3  1b 67                   DC.W     0x1b67
F00CE5  00 f9                   DC.W     0x00f9
F00CE7  a0 52                   DC.W     0xa052
F00CE9  6e 01                   DC.W     0x6e01
F00CEB  58 20                   DC.W     0x5820  ; 'X '
F00CED  2e 01                   DC.W     0x2e01
F00CEF  58 b0                   DC.W     0x58b0
F00CF1  6e 01                   DC.W     0x6e01
F00CF3  58 62                   DC.W     0x5862  ; 'Xb'
F00CF5  00 f9                   DC.W     0x00f9
F00CF7  90 7e                   DC.W     0x907e
F00CF9  1b 48                   DC.W     0x1b48
F00CFB  7a f9                   DC.W     0x7af9
F00CFD  8a 60                   DC.W     0x8a60
F00CFF  58 0c                   DC.W     0x580c
F00D01  6f 42                   DC.W     0x6f42  ; 'oB'
F00D03  45 00                   DC.W     0x4500
F00D05  12 67                   DC.W     0x1267
F00D07  04 61                   DC.W     0x0461
F00D09  00 f4                   DC.W     0x00f4
F00D0B  7c df                   DC.W     0x7cdf
F00D0D  fc 00                   DC.W     0xfc00
F00D0F  00 00                   DC.W     0x0000
F00D11  14 4e                   DC.W     0x144e
F00D13  75 2e                   DC.W     0x752e  ; 'u.'
F00D15  81 2f                   DC.W     0x812f
F00D17  0e 2c                   DC.W     0x0e2c
F00D19  78 0c                   DC.W     0x780c
F00D1B  0c bd                   DC.W     0x0cbd
F00D1D  fc 00                   DC.W     0xfc00
F00D1F  00 00                   DC.W     0x0000
F00D21  00 67                   DC.W     0x0067
F00D23  2a 08                   DC.W     0x2a08
F00D25  2f 00                   DC.W     0x2f00
F00D27  0d 00                   DC.W     0x0d00
F00D29  0e 66                   DC.W     0x0e66
F00D2B  22 08                   DC.W     0x2208
F00D2D  2e 00                   DC.W     0x2e00
F00D2F  06 00                   DC.W     0x0600
F00D31  29 67                   DC.W     0x2967  ; ')g'
F00D33  1a 12                   DC.W     0x1a12
F00D35  2e 01                   DC.W     0x2e01
F00D37  48 02                   DC.W     0x4802
F00D39  01 00                   DC.W     0x0100
F00D3B  38 67                   DC.W     0x3867  ; '8g'
F00D3D  10 08                   DC.W     0x1008
F00D3F  ee 00                   DC.W     0xee00
F00D41  0f 01                   DC.W     0x0f01
F00D43  48 2c                   DC.W     0x482c  ; 'H,'
F00D45  5f 22                   DC.W     0x5f22  ; '_"'
F00D47  1f 08                   DC.W     0x1f08
F00D49  97 00                   DC.W     0x9700
F00D4B  0f 4e                   DC.W     0x0f4e
F00D4D  73 2c                   DC.W     0x732c  ; 's,'
F00D4F  5f 22                   DC.W     0x5f22  ; '_"'
F00D51  1f 2f                   DC.W     0x1f2f
F00D53  38 0c                   DC.W     0x380c
F00D55  36 4e                   DC.W     0x364e  ; '6N'
F00D57  75 40                   DC.W     0x7540  ; 'u@'
F00D59  e7 61                   DC.W     0xe761
F00D5B  00 f9                   DC.W     0x00f9
F00D5D  e0 24                   DC.W     0xe024
F00D5F  3c 0c                   DC.W     0x3c0c
F00D61  08 00                   DC.W     0x0800
F00D63  00 34                   DC.W     0x0034
F00D65  2e 00                   DC.W     0x2e00
F00D67  10 26                   DC.W     0x1026
F00D69  2e 00                   DC.W     0x2e00
F00D6B  12 28                   DC.W     0x1228
F00D6D  2e 00                   DC.W     0x2e00
F00D6F  16 38                   DC.W     0x1638
F00D71  07 e1                   DC.W     0x07e1
F00D73  4c 18                   DC.W     0x4c18
F00D75  3c 00                   DC.W     0x3c00
F00D77  03 41                   DC.W     0x0341
F00D79  ee 01                   DC.W     0xee01
F00D7B  40 61                   DC.W     0x4061  ; '@a'
F00D7D  00 08                   DC.W     0x0008
F00D7F  3e 60                   DC.W     0x3e60  ; '>`'
F00D81  18 08                   DC.W     0x1808
F00D83  ae 00                   DC.W     0xae00
F00D85  06 00                   DC.W     0x0600
F00D87  29 4c                   DC.W     0x294c  ; ')L'
F00D89  ee 7f                   DC.W     0xee7f
F00D8B  ff 00                   DC.W     0xff00
F00D8D  74 08                   DC.W     0x7408
F00D8F  ae 00                   DC.W     0xae00
F00D91  06 00                   DC.W     0x0600
F00D93  2d 1d                   DC.W     0x2d1d
F00D95  40 00                   DC.W     0x4000
F00D97  26 4e                   DC.W     0x264e  ; '&N'
F00D99  73 08                   DC.W     0x7308
F00D9B  ee 00                   DC.W     0xee00
F00D9D  0a 00                   DC.W     0x0a00
F00D9F  2c 60                   DC.W     0x2c60  ; ',`'
F00DA1  00 f7                   DC.W     0x00f7
F00DA3  6a 40                   DC.W     0x6a40  ; 'j@'
F00DA5  e7 45                   DC.W     0xe745
F00DA7  f8 0c                   DC.W     0xf80c
F00DA9  aa 08                   DC.W     0xaa08
F00DAB  c7 00                   DC.W     0xc700
F00DAD  06 08                   DC.W     0x0608
F00DAF  ec 00                   DC.W     0xec00
F00DB1  06 00                   DC.W     0x0600
F00DB3  73 08                   DC.W     0x7308
F00DB5  2c 00                   DC.W     0x2c00
F00DB7  02 00                   DC.W     0x0200
F00DB9  29 67                   DC.W     0x2967  ; ')g'
F00DBB  16 08                   DC.W     0x1608
F00DBD  c7 00                   DC.W     0xc700
F00DBF  05 60                   DC.W     0x0560
F00DC1  10 22                   DC.W     0x1022
F00DC3  07 c2                   DC.W     0x07c2
F00DC5  fc 00                   DC.W     0xfc00
F00DC7  16 45                   DC.W     0x1645
F00DC9  f8 0c                   DC.W     0xf80c
F00DCB  aa 28                   DC.W     0xaa28
F00DCD  4e 19                   DC.W     0x4e19
F00DCF  47 00                   DC.W     0x4700
F00DD1  73 2a                   DC.W     0x732a  ; 's*'
F00DD3  72 10                   DC.W     0x7210
F00DD5  00 bb                   DC.W     0x00bb
F00DD7  ce 67                   DC.W     0xce67
F00DD9  00 00                   DC.W     0x0000
F00DDB  b0 24                   DC.W     0xb024
F00DDD  3c 1c                   DC.W     0x3c1c
F00DDF  87 00                   DC.W     0x8700
F00DE1  00 34                   DC.W     0x0034
F00DE3  32 10                   DC.W     0x3210
F00DE5  0e 26                   DC.W     0x0e26
F00DE7  32 10                   DC.W     0x3210
F00DE9  10 36                   DC.W     0x1036
F00DEB  07 08                   DC.W     0x0708
F00DED  2c 00                   DC.W     0x2c00
F00DEF  0f 00                   DC.W     0x0f00
F00DF1  28 67                   DC.W     0x2867  ; '(g'
F00DF3  04 08                   DC.W     0x0408
F00DF5  c3 00                   DC.W     0xc300
F00DF7  07 e1                   DC.W     0x07e1
F00DF9  4b 16                   DC.W     0x4b16
F00DFB  2c 00                   DC.W     0x2c00
F00DFD  24 28                   DC.W     0x2428  ; '$('
F00DFF  0c 2a                   DC.W     0x0c2a
F00E01  2c 00                   DC.W     0x2c00
F00E03  14 2c                   DC.W     0x142c
F00E05  2c 00                   DC.W     0x2c00
F00E07  70 3c                   DC.W     0x703c  ; 'p<'
F00E09  2c 01                   DC.W     0x2c01
F00E0B  00 2e                   DC.W     0x002e
F00E0D  2c 01                   DC.W     0x2c01
F00E0F  02 3e                   DC.W     0x023e
F00E11  2c 01                   DC.W     0x2c01
F00E13  20 20                   DC.W     0x2020  ; '  '
F00E15  2c 01                   DC.W     0x2c01
F00E17  22 30                   DC.W     0x2230  ; '"0'
F00E19  3c 03                   DC.W     0x3c03
F00E1B  00 08                   DC.W     0x0008
F00E1D  32 00                   DC.W     0x3200
F00E1F  0d 10                   DC.W     0x0d10
F00E21  14 67                   DC.W     0x1467
F00E23  06 42                   DC.W     0x0642
F00E25  40 10                   DC.W     0x4010
F00E27  32 10                   DC.W     0x3210
F00E29  15 08                   DC.W     0x1508
F00E2B  03 00                   DC.W     0x0300
F00E2D  0e 67                   DC.W     0x0e67
F00E2F  14 3c                   DC.W     0x143c
F00E31  2c 00                   DC.W     0x2c00
F00E33  2a 2e                   DC.W     0x2a2e  ; '*.'
F00E35  2c 00                   DC.W     0x2c00
F00E37  28 3e                   DC.W     0x283e  ; '(>'
F00E39  2c 00                   DC.W     0x2c00
F00E3B  b0 48                   DC.W     0xb048
F00E3D  40 30                   DC.W     0x4030  ; '@0'
F00E3F  2c 00                   DC.W     0x2c00
F00E41  b2 48                   DC.W     0xb248
F00E43  40 22                   DC.W     0x4022  ; '@"'
F00E45  40 4a                   DC.W     0x404a  ; '@J'
F00E47  b2 10                   DC.W     0xb210
F00E49  0e 66                   DC.W     0x0e66
F00E4B  14 20                   DC.W     0x1420
F00E4D  2d 00                   DC.W     0x2d00
F00E4F  40 67                   DC.W     0x4067  ; '@g'
F00E51  34 26                   DC.W     0x3426  ; '4&'
F00E53  40 34                   DC.W     0x4034  ; '@4'
F00E55  2b 00                   DC.W     0x2b00
F00E57  06 48                   DC.W     0x0648
F00E59  43 36                   DC.W     0x4336  ; 'C6'
F00E5B  2b 00                   DC.W     0x2b00
F00E5D  08 48                   DC.W     0x0848
F00E5F  43 41                   DC.W     0x4341  ; 'CA'
F00E61  f2 10                   DC.W     0xf210
F00E63  08 61                   DC.W     0x0861
F00E65  00 f8                   DC.W     0x00f8
F00E67  82 4a                   DC.W     0x824a
F00E69  b2 10                   DC.W     0xb210
F00E6B  00 67                   DC.W     0x0067
F00E6D  18 48                   DC.W     0x1848
F00E6F  e7 40                   DC.W     0xe740
F00E71  28 41                   DC.W     0x2841  ; '(A'
F00E73  d5 61                   DC.W     0xd561
F00E75  00 07                   DC.W     0x0007
F00E77  62 60                   DC.W     0x6260  ; 'b`'
F00E79  32 4c                   DC.W     0x324c  ; '2L'
F00E7B  df 14                   DC.W     0xdf14
F00E7D  02 20                   DC.W     0x0220
F00E7F  72 10                   DC.W     0x7210
F00E81  08 61                   DC.W     0x0861
F00E83  00 f9                   DC.W     0x00f9
F00E85  04 1e                   DC.W     0x041e
F00E87  2c 00                   DC.W     0x2c00
F00E89  73 08                   DC.W     0x7308
F00E8B  07 00                   DC.W     0x0700
F00E8D  06 66                   DC.W     0x0666
F00E8F  1a 2d                   DC.W     0x1a2d
F00E91  7c 00                   DC.W     0x7c00
F00E93  00 00                   DC.W     0x0000
F00E95  01 01                   DC.W     0x0101
F00E97  00 e7                   DC.W     0x00e7
F00E99  4f 1d                   DC.W     0x4f1d
F00E9B  47 01                   DC.W     0x4701
F00E9D  00 42                   DC.W     0x0042
F00E9F  2e 00                   DC.W     0x2e00
F00EA1  fb 41                   DC.W     0xfb41
F00EA3  fa f7                   DC.W     0xfaf7
F00EA5  e2 2f                   DC.W     0xe22f
F00EA7  48 00                   DC.W     0x4800
F00EA9  02 4e                   DC.W     0x024e
F00EAB  73 4c                   DC.W     0x734c  ; 'sL'
F00EAD  df 14                   DC.W     0xdf14
F00EAF  02 02                   DC.W     0x0202
F00EB1  2c 00                   DC.W     0x2c00
F00EB3  0f 00                   DC.W     0x0f00
F00EB5  73 08                   DC.W     0x7308
F00EB7  f2 00                   DC.W     0xf200
F00EB9  0c 10                   DC.W     0x0c10
F00EBB  14 52                   DC.W     0x1452
F00EBD  72 10                   DC.W     0x7210
F00EBF  12 08                   DC.W     0x1208
F00EC1  ec 00                   DC.W     0xec00
F00EC3  0b 00                   DC.W     0x0b00
F00EC5  2c 4e                   DC.W     0x2c4e  ; ',N'
F00EC7  73 48                   DC.W     0x7348  ; 'sH'
F00EC9  e7 c0                   DC.W     0xe7c0
F00ECB  c0 20                   DC.W     0xc020
F00ECD  78 0c                   DC.W     0x780c
F00ECF  3a 11                   DC.W     0x3a11
F00ED1  7c 00                   DC.W     0x7c00
F00ED3  00 00                   DC.W     0x0000
F00ED5  02 20                   DC.W     0x0220
F00ED7  78 0c                   DC.W     0x780c
F00ED9  4e 08                   DC.W     0x4e08
F00EDB  f8 00                   DC.W     0xf800
F00EDD  07 0c                   DC.W     0x070c
F00EDF  5a 32                   DC.W     0x5a32  ; 'Z2'
F00EE1  3c 01                   DC.W     0x3c01
F00EE3  00 10                   DC.W     0x0010
F00EE5  28 00                   DC.W     0x2800
F00EE7  03 10                   DC.W     0x0310
F00EE9  28 00                   DC.W     0x2800
F00EEB  0d 42                   DC.W     0x0d42
F00EED  81 32                   DC.W     0x8132
F00EEF  38 0c                   DC.W     0x380c
F00EF1  56 d3                   DC.W     0x56d3
F00EF3  b8 0c                   DC.W     0xb80c
F00EF5  42 20                   DC.W     0x4220  ; 'B '
F00EF7  38 0c                   DC.W     0x380c
F00EF9  42 04                   DC.W     0x4204
F00EFB  80 05                   DC.W     0x8005
F00EFD  26 5c                   DC.W     0x265c  ; '&\'
F00EFF  00 6b                   DC.W     0x006b
F00F01  3a 52                   DC.W     0x3a52  ; ':R'
F00F03  b8 0c                   DC.W     0xb80c
F00F05  3e 21                   DC.W     0x3e21  ; '>!'
F00F07  c0 0c                   DC.W     0xc00c
F00F09  42 20                   DC.W     0x4220  ; 'B '
F00F0B  3c 05                   DC.W     0x3c05
F00F0D  26 5c                   DC.W     0x265c  ; '&\'
F00F0F  00 22                   DC.W     0x0022
F00F11  78 0c                   DC.W     0x780c
F00F13  2c 40                   DC.W     0x2c40  ; ',@'
F00F15  e7 00                   DC.W     0xe700
F00F17  7c 07                   DC.W     0x7c07
F00F19  00 20                   DC.W     0x0020
F00F1B  69 00                   DC.W     0x6900
F00F1D  0c 22                   DC.W     0x0c22
F00F1F  08 67                   DC.W     0x0867
F00F21  08 91                   DC.W     0x0891
F00F23  a8 00                   DC.W     0xa800
F00F25  08 20                   DC.W     0x0820
F00F27  50 60                   DC.W     0x5060  ; 'P`'
F00F29  f4 46                   DC.W     0xf446
F00F2B  df 20                   DC.W     0xdf20
F00F2D  69 00                   DC.W     0x6900
F00F2F  08 22                   DC.W     0x0822
F00F31  08 67                   DC.W     0x0867
F00F33  08 91                   DC.W     0x0891
F00F35  a8 00                   DC.W     0xa800
F00F37  08 20                   DC.W     0x0820
F00F39  50 60                   DC.W     0x5060  ; 'P`'
F00F3B  f4 22                   DC.W     0xf422
F00F3D  78 0c                   DC.W     0x780c
F00F3F  2c 4a                   DC.W     0x2c4a  ; ',J'
F00F41  a9 00                   DC.W     0xa900
F00F43  0c 67                   DC.W     0x0c67
F00F45  14 30                   DC.W     0x1430
F00F47  2f 00                   DC.W     0x2f00
F00F49  10 02                   DC.W     0x1002
F00F4B  40 27                   DC.W     0x4027  ; '@''
F00F4D  ff 00                   DC.W     0xff00
F00F4F  40 20                   DC.W     0x4020  ; '@ '
F00F51  00 22                   DC.W     0x0022
F00F53  38 0c                   DC.W     0x380c
F00F55  42 61                   DC.W     0x4261  ; 'Ba'
F00F57  00 01                   DC.W     0x0001
F00F59  d0 4c                   DC.W     0xd04c
F00F5B  df 03                   DC.W     0xdf03
F00F5D  03 08                   DC.W     0x0308
F00F5F  38 00                   DC.W     0x3800
F00F61  0d 0c                   DC.W     0x0d0c
F00F63  34 67                   DC.W     0x3467  ; '4g'
F00F65  06 61                   DC.W     0x0661
F00F67  00 07                   DC.W     0x0007
F00F69  20 ff                   DC.W     0x20ff
F00F6B  13 53                   DC.W     0x1353
F00F6D  78 0c                   DC.W     0x780c
F00F6F  52 6e                   DC.W     0x526e  ; 'Rn'
F00F71  10 08                   DC.W     0x1008
F00F73  f8 00                   DC.W     0xf800
F00F75  07 0c                   DC.W     0x070c
F00F77  5b 3f                   DC.W     0x5b3f  ; '[?'
F00F79  17 02                   DC.W     0x1702
F00F7B  17 00                   DC.W     0x1700
F00F7D  7f 54                   DC.W     0x7f54
F00F7F  8f 67                   DC.W     0x8f67
F00F81  02 4e                   DC.W     0x024e
F00F83  73 02                   DC.W     0x7302
F00F85  7c f8                   DC.W     0x7cf8
F00F87  ff 61                   DC.W     0xff61
F00F89  00 f7                   DC.W     0x00f7
F00F8B  26 41                   DC.W     0x2641  ; '&A'
F00F8D  d6 61                   DC.W     0xd661
F00F8F  00 f8                   DC.W     0x00f8
F00F91  6c 60                   DC.W     0x6c60  ; 'l`'
F00F93  00 f6                   DC.W     0x00f6
F00F95  f8 40                   DC.W     0xf840
F00F97  e7 2f                   DC.W     0xe72f
F00F99  08 20                   DC.W     0x0820
F00F9B  78 0c                   DC.W     0x780c
F00F9D  4e 42                   DC.W     0x4e42  ; 'NB'
F00F9F  81 42                   DC.W     0x8142
F00FA1  38 0c                   DC.W     0x380c
F00FA3  5a 03                   DC.W     0x5a03
F00FA5  08 00                   DC.W     0x0800
F00FA7  0d 30                   DC.W     0x0d30
F00FA9  01 e0                   DC.W     0x01e0
F00FAB  49 44                   DC.W     0x4944  ; 'ID'
F00FAD  41 d2                   DC.W     0x41d2
F00FAF  78 0c                   DC.W     0x780c
F00FB1  58 e4                   DC.W     0x58e4
F00FB3  49 d2                   DC.W     0x49d2
F00FB5  b8 0c                   DC.W     0xb80c
F00FB7  42 4a                   DC.W     0x424a  ; 'BJ'
F00FB9  38 0c                   DC.W     0x380c
F00FBB  5a 66                   DC.W     0x5a66  ; 'Zf'
F00FBD  e0 20                   DC.W     0xe020
F00FBF  5f 4e                   DC.W     0x5f4e  ; '_N'
F00FC1  73 72                   DC.W     0x7372  ; 'sr'
F00FC3  01 d2                   DC.W     0x01d2
F00FC5  78 0c                   DC.W     0x780c
F00FC7  56 d2                   DC.W     0x56d2
F00FC9  b8 0c                   DC.W     0xb80c
F00FCB  42 22                   DC.W     0x4222  ; 'B"'
F00FCD  78 0c                   DC.W     0x780c
F00FCF  2c 47                   DC.W     0x2c47  ; ',G'
F00FD1  e9 00                   DC.W     0xe900
F00FD3  08 24                   DC.W     0x0824
F00FD5  53 20                   DC.W     0x5320  ; 'S '
F00FD7  0a 67                   DC.W     0x0a67
F00FD9  0c 4a                   DC.W     0x0c4a
F00FDB  aa 00                   DC.W     0xaa00
F00FDD  04 66                   DC.W     0x0466
F00FDF  08 26                   DC.W     0x0826
F00FE1  92 60                   DC.W     0x9260
F00FE3  00 00                   DC.W     0x0000
F00FE5  8c 4e                   DC.W     0x8c4e
F00FE7  75 b2                   DC.W     0x75b2
F00FE9  aa 00                   DC.W     0xaa00
F00FEB  08 6d                   DC.W     0x086d
F00FED  f8 61                   DC.W     0xf861
F00FEF  00 ff                   DC.W     0x00ff
F00FF1  a6 b2                   DC.W     0xa6b2
F00FF3  aa 00                   DC.W     0xaa00
F00FF5  08 6d                   DC.W     0x086d
F00FF7  ee 26                   DC.W     0xee26
F00FF9  92 2a                   DC.W     0x922a
F00FFB  6a 00                   DC.W     0x6a00
F00FFD  04 08                   DC.W     0x0408
F00FFF  2d 00                   DC.W     0x2d00
F01001  07 00                   DC.W     0x0700
F01003  2d 66                   DC.W     0x2d66  ; '-f'
F01005  6a 08                   DC.W     0x6a08
F01007  aa 00                   DC.W     0xaa00
F01009  00 00                   DC.W     0x0000
F0100B  15 24                   DC.W     0x1524
F0100D  2a 00                   DC.W     0x2a00
F0100F  0c d4                   DC.W     0x0cd4
F01011  aa 00                   DC.W     0xaa00
F01013  08 3e                   DC.W     0x083e
F01015  2a 00                   DC.W     0x2a00
F01017  14 67                   DC.W     0x1467
F01019  3e 08                   DC.W     0x3e08
F0101B  2a 00                   DC.W     0x2a00
F0101D  0e 00                   DC.W     0x0e00
F0101F  14 67                   DC.W     0x1467
F01021  0c 52                   DC.W     0x0c52
F01023  6a 00                   DC.W     0x6a00
F01025  1a 08                   DC.W     0x1a08
F01027  c7 00                   DC.W     0xc700
F01029  00 61                   DC.W     0x0061
F0102B  00 00                   DC.W     0x0000
F0102D  e0 08                   DC.W     0xe008
F0102F  2a 00                   DC.W     0x2a00
F01031  0d 00                   DC.W     0x0d00
F01033  14 66                   DC.W     0x1466
F01035  42 08                   DC.W     0x4208
F01037  2a 00                   DC.W     0x2a00
F01039  0c 00                   DC.W     0x0c00
F0103B  14 67                   DC.W     0x1467
F0103D  10 08                   DC.W     0x1008
F0103F  ad 00                   DC.W     0xad00
F01041  0e 00                   DC.W     0x0e00
F01043  2c 66                   DC.W     0x2c66  ; ',f'
F01045  1c 08                   DC.W     0x1c08
F01047  ed 00                   DC.W     0xed00
F01049  03 00                   DC.W     0x0300
F0104B  2d 60                   DC.W     0x2d60  ; '-`'
F0104D  1a 08                   DC.W     0x1a08
F0104F  ad 00                   DC.W     0xad00
F01051  09 00                   DC.W     0x0900
F01053  2c 67                   DC.W     0x2c67  ; ',g'
F01055  12 60                   DC.W     0x1260
F01057  0a 42                   DC.W     0x0a42
F01059  ad 00                   DC.W     0xad00
F0105B  58 08                   DC.W     0x5808
F0105D  ad 00                   DC.W     0xad00
F0105F  0e 00                   DC.W     0x0e00
F01061  2c 41                   DC.W     0x2c41  ; ',A'
F01063  d5 61                   DC.W     0xd561
F01065  00 f7                   DC.W     0x00f7
F01067  96 08                   DC.W     0x9608
F01069  07 00                   DC.W     0x0700
F0106B  00 66                   DC.W     0x0066
F0106D  00 ff                   DC.W     0x00ff
F0106F  66 61                   DC.W     0x6661  ; 'fa'
F01071  00 00                   DC.W     0x0000
F01073  7e 60                   DC.W     0x7e60  ; '~`'
F01075  00 ff                   DC.W     0x00ff
F01077  5e 48                   DC.W     0x5e48  ; '^H'
F01079  e7 41                   DC.W     0xe741
F0107B  50 24                   DC.W     0x5024  ; 'P$'
F0107D  38 0c                   DC.W     0x380c
F0107F  3e 26                   DC.W     0x3e26  ; '>&'
F01081  01 36                   DC.W     0x0136
F01083  38 0c                   DC.W     0x380c
F01085  40 48                   DC.W     0x4048  ; '@H'
F01087  43 28                   DC.W     0x4328  ; 'C('
F01089  01 48                   DC.W     0x0148
F0108B  44 34                   DC.W     0x4434  ; 'D4'
F0108D  3c 0a                   DC.W     0x3c0a
F0108F  04 08                   DC.W     0x0408
F01091  07 00                   DC.W     0x0700
F01093  0a 67                   DC.W     0x0a67
F01095  0c 34                   DC.W     0x0c34
F01097  3c 10                   DC.W     0x3c10
F01099  04 38                   DC.W     0x0438
F0109B  2a 00                   DC.W     0x2a00
F0109D  16 2a                   DC.W     0x162a
F0109F  2a 00                   DC.W     0x2a00
F010A1  18 48                   DC.W     0x1848
F010A3  42 08                   DC.W     0x4208
F010A5  2a 00                   DC.W     0x2a00
F010A7  0c 00                   DC.W     0x0c00
F010A9  14 67                   DC.W     0x1467
F010AB  32 48                   DC.W     0x3248  ; '2H'
F010AD  e7 1c                   DC.W     0xe71c
F010AF  00 7a                   DC.W     0x007a
F010B1  02 2c                   DC.W     0x022c
F010B3  2a 00                   DC.W     0x2a00
F010B5  10 20                   DC.W     0x1020
F010B7  6d 00                   DC.W     0x6d00
F010B9  36 61                   DC.W     0x3661  ; '6a'
F010BB  00 06                   DC.W     0x0006
F010BD  a0 60                   DC.W     0xa060
F010BF  08 4e                   DC.W     0x084e
F010C1  71 4c                   DC.W     0x714c  ; 'qL'
F010C3  df 00                   DC.W     0xdf00
F010C5  38 60                   DC.W     0x3860  ; '8`'
F010C7  16 4c                   DC.W     0x164c
F010C9  df 00                   DC.W     0xdf00
F010CB  70 26                   DC.W     0x7026  ; 'p&'
F010CD  2a 00                   DC.W     0x2a00
F010CF  10 48                   DC.W     0x1048
F010D1  43 36                   DC.W     0x4336  ; 'C6'
F010D3  02 06                   DC.W     0x0206
F010D5  82 04                   DC.W     0x8204
F010D7  80 00                   DC.W     0x8000
F010D9  00 34                   DC.W     0x0034
F010DB  2a 00                   DC.W     0x2a00
F010DD  10 41                   DC.W     0x1041
F010DF  d5 61                   DC.W     0xd561
F010E1  00 04                   DC.W     0x0004
F010E3  f6 4e                   DC.W     0xf64e
F010E5  71 4c                   DC.W     0x714c  ; 'qL'
F010E7  df 0a                   DC.W     0xdf0a
F010E9  82 52                   DC.W     0x8252
F010EB  81 60                   DC.W     0x8160
F010ED  00 ff                   DC.W     0x00ff
F010EF  7a 40                   DC.W     0x7a40  ; 'z@'
F010F1  e7 00                   DC.W     0xe700
F010F3  7c 07                   DC.W     0x7c07
F010F5  00 24                   DC.W     0x0024
F010F7  a9 00                   DC.W     0xa900
F010F9  04 25                   DC.W     0x0425
F010FB  7c ff                   DC.W     0x7cff
F010FD  ff ff                   DC.W     0xffff
F010FF  ff 00                   DC.W     0xff00
F01101  04 23                   DC.W     0x0423
F01103  4a 00                   DC.W     0x4a00
F01105  04 4e                   DC.W     0x044e
F01107  73 4f                   DC.W     0x734f  ; 'sO'
F01109  ef 00                   DC.W     0xef00
F0110B  02 49                   DC.W     0x0249
F0110D  e9 00                   DC.W     0xe900
F0110F  08 20                   DC.W     0x0820
F01111  4c 20                   DC.W     0x4c20  ; 'L '
F01113  14 67                   DC.W     0x1467
F01115  08 28                   DC.W     0x0828
F01117  40 b4                   DC.W     0x40b4
F01119  ac 00                   DC.W     0xac00
F0111B  08 6c                   DC.W     0x086c
F0111D  f2 25                   DC.W     0xf225
F0111F  42 00                   DC.W     0x4200
F01121  08 24                   DC.W     0x0824
F01123  80 20                   DC.W     0x8020
F01125  8a 4e                   DC.W     0x8a4e
F01127  75 22                   DC.W     0x7522  ; 'u"'
F01129  78 0c                   DC.W     0x780c
F0112B  2c 41                   DC.W     0x2c41  ; ',A'
F0112D  e9 00                   DC.W     0xe900
F0112F  0c 3f                   DC.W     0x0c3f
F01131  00 46                   DC.W     0x0046
F01133  fc 27                   DC.W     0xfc27
F01135  00 22                   DC.W     0x0022
F01137  48 4a                   DC.W     0x484a  ; 'HJ'
F01139  91 66                   DC.W     0x9166
F0113B  02 4e                   DC.W     0x024e
F0113D  73 20                   DC.W     0x7320  ; 's '
F0113F  51 b2                   DC.W     0x51b2
F01141  a8 00                   DC.W     0xa800
F01143  08 6d                   DC.W     0x086d
F01145  f0 b0                   DC.W     0xf0b0
F01147  68 00                   DC.W     0x6800
F01149  1c 6c                   DC.W     0x1c6c
F0114B  ea 2f                   DC.W     0xea2f
F0114D  28 00                   DC.W     0x2800
F0114F  10 3f                   DC.W     0x103f
F01151  28 00                   DC.W     0x2800
F01153  1c 42                   DC.W     0x1c42
F01155  68 00                   DC.W     0x6800
F01157  1a 20                   DC.W     0x1a20
F01159  28 00                   DC.W     0x2800
F0115B  08 52                   DC.W     0x0852
F0115D  68 00                   DC.W     0x6800
F0115F  1a d0                   DC.W     0x1ad0
F01161  a8 00                   DC.W     0xa800
F01163  0c b2                   DC.W     0x0cb2
F01165  80 6c                   DC.W     0x806c
F01167  f4 21                   DC.W     0xf421
F01169  40 00                   DC.W     0x4000
F0116B  08 42                   DC.W     0x0842
F0116D  80 30                   DC.W     0x8030
F0116F  28 00                   DC.W     0x2800
F01171  1a 22                   DC.W     0x1a22
F01173  28 00                   DC.W     0x2800
F01175  16 08                   DC.W     0x1608
F01177  28 00                   DC.W     0x2800
F01179  0e 00                   DC.W     0x0e00
F0117B  14 66                   DC.W     0x1466
F0117D  16 22                   DC.W     0x1622
F0117F  90 22                   DC.W     0x9022
F01181  78 0c                   DC.W     0x780c
F01183  2c 20                   DC.W     0x2c20  ; ', '
F01185  a9 00                   DC.W     0xa900
F01187  04 23                   DC.W     0x0423
F01189  48 00                   DC.W     0x4800
F0118B  04 21                   DC.W     0x0421
F0118D  7c ff                   DC.W     0x7cff
F0118F  ff ff                   DC.W     0xffff
F01191  ff 00                   DC.W     0xff00
F01193  04 4e                   DC.W     0x044e
F01195  73 40                   DC.W     0x7340  ; 's@'
F01197  e7 48                   DC.W     0xe748
F01199  e7 10                   DC.W     0xe710
F0119B  70 20                   DC.W     0x7020  ; 'p '
F0119D  09 22                   DC.W     0x0922
F0119F  78 0c                   DC.W     0x780c
F011A1  2c 47                   DC.W     0x2c47  ; ',G'
F011A3  e9 00                   DC.W     0xe900
F011A5  0c 46                   DC.W     0x0c46
F011A7  fc 27                   DC.W     0xfc27
F011A9  00 24                   DC.W     0x0024
F011AB  4b 26                   DC.W     0x4b26  ; 'K&'
F011AD  13 67                   DC.W     0x1367
F011AF  24 26                   DC.W     0x2426  ; '$&'
F011B1  43 b4                   DC.W     0x43b4
F011B3  ab 00                   DC.W     0xab00
F011B5  16 66                   DC.W     0x1666
F011B7  f2 24                   DC.W     0xf224
F011B9  93 4a                   DC.W     0x934a
F011BB  41 6a                   DC.W     0x416a  ; 'Aj'
F011BD  2c 26                   DC.W     0x2c26  ; ',&'
F011BF  a9 00                   DC.W     0xa900
F011C1  04 23                   DC.W     0x0423
F011C3  4b 00                   DC.W     0x4b00
F011C5  04 27                   DC.W     0x0427
F011C7  7c ff                   DC.W     0x7cff
F011C9  ff ff                   DC.W     0xffff
F011CB  ff 00                   DC.W     0xff00
F011CD  04 4c                   DC.W     0x044c
F011CF  df 0e                   DC.W     0xdf0e
F011D1  08 4e                   DC.W     0x084e
F011D3  73 4a                   DC.W     0x734a  ; 'sJ'
F011D5  41 6b                   DC.W     0x416b  ; 'Ak'
F011D7  f6 26                   DC.W     0xf626
F011D9  29 00                   DC.W     0x2900
F011DB  04 66                   DC.W     0x0466
F011DD  06 54                   DC.W     0x0654
F011DF  af 00                   DC.W     0xaf00
F011E1  12 60                   DC.W     0x1260
F011E3  ea 26                   DC.W     0xea26
F011E5  43 23                   DC.W     0x4323  ; 'C#'
F011E7  53 00                   DC.W     0x5300
F011E9  04 46                   DC.W     0x0446
F011EB  ef 00                   DC.W     0xef00
F011ED  10 42                   DC.W     0x1042
F011EF  ab 00                   DC.W     0xab00
F011F1  04 27                   DC.W     0x0427
F011F3  40 00                   DC.W     0x4000
F011F5  0c 27                   DC.W     0x0c27
F011F7  40 00                   DC.W     0x4000
F011F9  08 27                   DC.W     0x0827
F011FB  48 00                   DC.W     0x4800
F011FD  10 27                   DC.W     0x1027
F011FF  42 00                   DC.W     0x4200
F01201  16 42                   DC.W     0x1642
F01203  ab 00                   DC.W     0xab00
F01205  1a 42                   DC.W     0x1a42
F01207  6b 00                   DC.W     0x6b00
F01209  14 08                   DC.W     0x1408
F0120B  01 00                   DC.W     0x0100
F0120D  0e 67                   DC.W     0x0e67
F0120F  06 08                   DC.W     0x0608
F01211  eb 00                   DC.W     0xeb00
F01213  0e 00                   DC.W     0x0e00
F01215  14 e1                   DC.W     0x14e1
F01217  49 02                   DC.W     0x4902
F01219  41 07                   DC.W     0x4107
F0121B  00 00                   DC.W     0x0000
F0121D  41 20                   DC.W     0x4120  ; 'A '
F0121F  00 37                   DC.W     0x0037
F01221  41 00                   DC.W     0x4100
F01223  1c 61                   DC.W     0x1c61
F01225  00 fd                   DC.W     0x00fd
F01227  70 d3                   DC.W     0x70d3
F01229  ab 00                   DC.W     0xab00
F0122B  08 46                   DC.W     0x0846
F0122D  fc 27                   DC.W     0xfc27
F0122F  00 26                   DC.W     0x0026
F01231  a9 00                   DC.W     0xa900
F01233  0c 23                   DC.W     0x0c23
F01235  4b 00                   DC.W     0x4b00
F01237  0c 4c                   DC.W     0x0c4c
F01239  df 0e                   DC.W     0xdf0e
F0123B  08 4e                   DC.W     0x084e
F0123D  73 40                   DC.W     0x7340  ; 's@'
F0123F  e7 48                   DC.W     0xe748
F01241  e7 1c                   DC.W     0xe71c
F01243  1c 26                   DC.W     0x1c26
F01245  08 42                   DC.W     0x0842
F01247  82 34                   DC.W     0x8234
F01249  03 66                   DC.W     0x0366
F0124B  06 78                   DC.W     0x0678
F0124D  01 60                   DC.W     0x0160
F0124F  00 00                   DC.W     0x0000
F01251  96 48                   DC.W     0x9648
F01253  43 32                   DC.W     0x4332  ; 'C2'
F01255  03 78                   DC.W     0x0378
F01257  01 02                   DC.W     0x0102
F01259  83 00                   DC.W     0x8300
F0125B  00 00                   DC.W     0x0000
F0125D  0f 66                   DC.W     0x0f66
F0125F  14 36                   DC.W     0x1436
F01261  01 02                   DC.W     0x0102
F01263  83 00                   DC.W     0x8300
F01265  00 00                   DC.W     0x0000
F01267  70 78                   DC.W     0x7078  ; 'px'
F01269  00 08                   DC.W     0x0008
F0126B  01 00                   DC.W     0x0100
F0126D  0a 67                   DC.W     0x0a67
F0126F  04 61                   DC.W     0x0461
F01271  00 01                   DC.W     0x0001
F01273  3e 4b                   DC.W     0x3e4b  ; '>K'
F01275  f8 00                   DC.W     0xf800
F01277  00 49                   DC.W     0x0049
F01279  f8 00                   DC.W     0xf800
F0127B  00 42                   DC.W     0x0042
F0127D  a7 24                   DC.W     0xa724
F0127F  49 22                   DC.W     0x4922  ; 'I"'
F01281  78 0c                   DC.W     0x780c
F01283  00 08                   DC.W     0x0008
F01285  01 00                   DC.W     0x0100
F01287  08 66                   DC.W     0x0866
F01289  00 01                   DC.W     0x0001
F0128B  48 4a                   DC.W     0x484a  ; 'HJ'
F0128D  51 6b                   DC.W     0x516b  ; 'Qk'
F0128F  24 b6                   DC.W     0x24b6
F01291  31 40                   DC.W     0x3140  ; '1@'
F01293  00 66                   DC.W     0x0066
F01295  1e 26                   DC.W     0x1e26
F01297  69 00                   DC.W     0x6900
F01299  06 20                   DC.W     0x0620
F0129B  4f 4a                   DC.W     0x4f4a  ; 'OJ'
F0129D  90 67                   DC.W     0x9067
F0129F  06 b7                   DC.W     0x06b7
F012A1  d8 67                   DC.W     0xd867
F012A3  10 60                   DC.W     0x1060
F012A5  f6 48                   DC.W     0xf648
F012A7  53 41                   DC.W     0x5341  ; 'SA'
F012A9  eb 00                   DC.W     0xeb00
F012AB  0e 61                   DC.W     0x0e61
F012AD  00 f4                   DC.W     0x00f4
F012AF  3a 61                   DC.W     0x3a61  ; ':a'
F012B1  00 00                   DC.W     0x0000
F012B3  94 43                   DC.W     0x9443
F012B5  e9 00                   DC.W     0xe900
F012B7  0a 0c                   DC.W     0x0a0c
F012B9  51 ff                   DC.W     0x51ff
F012BB  ff 66                   DC.W     0xff66
F012BD  ce 42                   DC.W     0xce42
F012BF  84 20                   DC.W     0x8420
F012C1  0d 67                   DC.W     0x0d67
F012C3  7c 20                   DC.W     0x7c20  ; '| '
F012C5  0c 67                   DC.W     0x0c67
F012C7  34 b4                   DC.W     0x34b4
F012C9  ac 00                   DC.W     0xac00
F012CB  08 6f                   DC.W     0x086f
F012CD  0a 08                   DC.W     0x0a08
F012CF  01 00                   DC.W     0x0100
F012D1  09 67                   DC.W     0x0967
F012D3  28 24                   DC.W     0x2824  ; '($'
F012D5  2c 00                   DC.W     0x2c00
F012D7  08 61                   DC.W     0x0861
F012D9  00 00                   DC.W     0x0000
F012DB  9c 12                   DC.W     0x9c12
F012DD  11 82                   DC.W     0x1182
F012DF  29 00                   DC.W     0x2900
F012E1  01 61                   DC.W     0x0161
F012E3  00 00                   DC.W     0x0000
F012E5  da 08                   DC.W     0xda08
F012E7  ae 00                   DC.W     0xae00
F012E9  06 00                   DC.W     0x0600
F012EB  2d 20                   DC.W     0x2d20  ; '- '
F012ED  4b 20                   DC.W     0x4b20  ; 'K '
F012EF  04 67                   DC.W     0x0467
F012F1  04 54                   DC.W     0x0454
F012F3  af 00                   DC.W     0xaf00
F012F5  1a 4c                   DC.W     0x1a4c
F012F7  df 38                   DC.W     0xdf38
F012F9  38 4e                   DC.W     0x384e  ; '8N'
F012FB  73 08                   DC.W     0x7308
F012FD  01 00                   DC.W     0x0100
F012FF  0a 67                   DC.W     0x0a67
F01301  40 08                   DC.W     0x4008
F01303  ee 00                   DC.W     0xee00
F01305  06 00                   DC.W     0x0600
F01307  2d 1d                   DC.W     0x2d1d
F01309  7c 00                   DC.W     0x7c00
F0130B  f0 00                   DC.W     0xf000
F0130D  26 41                   DC.W     0x2641  ; '&A'
F0130F  ed 00                   DC.W     0xed00
F01311  14 2d                   DC.W     0x142d
F01313  48 00                   DC.W     0x4800
F01315  94 00                   DC.W     0x9400
F01317  7c 07                   DC.W     0x7c07
F01319  00 30                   DC.W     0x0030
F0131B  10 e3                   DC.W     0x10e3
F0131D  48 e2                   DC.W     0x48e2
F0131F  40 53                   DC.W     0x4053  ; '@S'
F01321  40 6c                   DC.W     0x406c  ; '@l'
F01323  fc 30                   DC.W     0xfc30
F01325  80 61                   DC.W     0x8061
F01327  00 f3                   DC.W     0x00f3
F01329  f0 08                   DC.W     0xf008
F0132B  90 00                   DC.W     0x9000
F0132D  0f 46                   DC.W     0x0f46
F0132F  fc 20                   DC.W     0xfc20
F01331  00 41                   DC.W     0x0041
F01333  d6 61                   DC.W     0xd661
F01335  00 f4                   DC.W     0x00f4
F01337  8a 61                   DC.W     0x8a61
F01339  00 00                   DC.W     0x0000
F0133B  84 60                   DC.W     0x8460
F0133D  00 f1                   DC.W     0x00f1
F0133F  ce 52                   DC.W     0xce52
F01341  84 52                   DC.W     0x8452
F01343  84 60                   DC.W     0x8460
F01345  9c 20                   DC.W     0x9c20
F01347  13 67                   DC.W     0x1367
F01349  2a 24                   DC.W     0x2a24  ; '*$'
F0134B  40 20                   DC.W     0x4020  ; '@ '
F0134D  0c 67                   DC.W     0x0c67
F0134F  1c 2a                   DC.W     0x1c2a
F01351  2a 00                   DC.W     0x2a00
F01353  08 ba                   DC.W     0x08ba
F01355  82 6d                   DC.W     0x826d
F01357  0e b4                   DC.W     0x0eb4
F01359  ac 00                   DC.W     0xac00
F0135B  08 6e                   DC.W     0x086e
F0135D  0e ba                   DC.W     0x0eba
F0135F  ac 00                   DC.W     0xac00
F01361  08 6d                   DC.W     0x086d
F01363  08 60                   DC.W     0x0860
F01365  0a ba                   DC.W     0x0aba
F01367  ac 00                   DC.W     0xac00
F01369  08 6f                   DC.W     0x086f
F0136B  04 28                   DC.W     0x0428
F0136D  4a 2a                   DC.W     0x4a2a  ; 'J*'
F0136F  4b 20                   DC.W     0x4b20  ; 'K '
F01371  12 66                   DC.W     0x1266
F01373  d6 4e                   DC.W     0xd64e
F01375  75 95                   DC.W     0x7595
F01377  ac 00                   DC.W     0xac00
F01379  08 d5                   DC.W     0x08d5
F0137B  ac 00                   DC.W     0xac00
F0137D  0c 2a                   DC.W     0x0c2a
F0137F  2c 00                   DC.W     0x2c00
F01381  08 e1                   DC.W     0x08e1
F01383  8d 47                   DC.W     0x8d47
F01385  f4 58                   DC.W     0xf458
F01387  00 66                   DC.W     0x0066
F01389  1a 2a                   DC.W     0x1a2a
F0138B  2c 00                   DC.W     0x2c00
F0138D  0c 24                   DC.W     0x0c24
F0138F  54 20                   DC.W     0x5420  ; 'T '
F01391  2c 00                   DC.W     0x2c00
F01393  04 67                   DC.W     0x0467
F01395  10 22                   DC.W     0x1022
F01397  40 db                   DC.W     0x40db
F01399  a9 00                   DC.W     0xa900
F0139B  0c 22                   DC.W     0x0c22
F0139D  8a 67                   DC.W     0x8a67
F0139F  04 25                   DC.W     0x0425
F013A1  49 00                   DC.W     0x4900
F013A3  04 4e                   DC.W     0x044e
F013A5  75 2a                   DC.W     0x752a  ; 'u*'
F013A7  8a 67                   DC.W     0x8a67
F013A9  fa 42                   DC.W     0xfa42
F013AB  aa 00                   DC.W     0xaa00
F013AD  04 4e                   DC.W     0x044e
F013AF  75 40                   DC.W     0x7540  ; 'u@'
F013B1  e7 61                   DC.W     0xe761
F013B3  00 f3                   DC.W     0x00f3
F013B5  88 1d                   DC.W     0x881d
F013B7  6e 00                   DC.W     0x6e00
F013B9  77 00                   DC.W     0x7700
F013BB  26 4e                   DC.W     0x264e  ; '&N'
F013BD  73 22                   DC.W     0x7322  ; 's"'
F013BF  5f 20                   DC.W     0x5f20  ; '_ '
F013C1  1f 67                   DC.W     0x1f67
F013C3  0c 20                   DC.W     0x0c20
F013C5  40 41                   DC.W     0x4041  ; '@A'
F013C7  e8 00                   DC.W     0xe800
F013C9  0e 61                   DC.W     0x0e61
F013CB  00 f3                   DC.W     0x00f3
F013CD  bc 60                   DC.W     0xbc60
F013CF  f0 4e                   DC.W     0xf04e
F013D1  d1 0c                   DC.W     0xd10c
F013D3  11 00                   DC.W     0x1100
F013D5  01 67                   DC.W     0x0167
F013D7  00 00                   DC.W     0x0000
F013D9  9c b5                   DC.W     0x9cb5
F013DB  e9 00                   DC.W     0xe900
F013DD  06 6c                   DC.W     0x066c
F013DF  00 00                   DC.W     0x0000
F013E1  94 b5                   DC.W     0x94b5
F013E3  e9 00                   DC.W     0xe900
F013E5  02 6d                   DC.W     0x026d
F013E7  00 00                   DC.W     0x0000
F013E9  98 08                   DC.W     0x9808
F013EB  01 00                   DC.W     0x0100
F013ED  0f 66                   DC.W     0x0f66
F013EF  00 ff                   DC.W     0x00ff
F013F1  50 4a                   DC.W     0x504a  ; 'PJ'
F013F3  51 6b                   DC.W     0x516b  ; 'Qk'
F013F5  00 00                   DC.W     0x0000
F013F7  8a 2a                   DC.W     0x8a2a
F013F9  69 00                   DC.W     0x6900
F013FB  06 48                   DC.W     0x0648
F013FD  55 41                   DC.W     0x5541  ; 'UA'
F013FF  ed 00                   DC.W     0xed00
F01401  0e 61                   DC.W     0x0e61
F01403  00 f2                   DC.W     0x00f2
F01405  e4 20                   DC.W     0xe420
F01407  15 67                   DC.W     0x1567
F01409  00 fe                   DC.W     0x00fe
F0140B  f2 e1                   DC.W     0xf2e1
F0140D  8a 26                   DC.W     0x8a26
F0140F  4a d7                   DC.W     0x4ad7
F01411  c2 e0                   DC.W     0xc2e0
F01413  8a 28                   DC.W     0x8a28
F01415  40 b0                   DC.W     0x40b0
F01417  8a 6e                   DC.W     0x8a6e
F01419  00 fe                   DC.W     0x00fe
F0141B  e2 20                   DC.W     0xe220
F0141D  2c 00                   DC.W     0x2c00
F0141F  08 e1                   DC.W     0x08e1
F01421  88 d0                   DC.W     0x88d0
F01423  8c b0                   DC.W     0x8cb0
F01425  8a 6e                   DC.W     0x8a6e
F01427  08 20                   DC.W     0x0820
F01429  14 66                   DC.W     0x1466
F0142B  e8 60                   DC.W     0xe860
F0142D  00 fe                   DC.W     0x00fe
F0142F  ce b0                   DC.W     0xceb0
F01431  8b 67                   DC.W     0x8b67
F01433  00 fe                   DC.W     0x00fe
F01435  8a 6e                   DC.W     0x8a6e
F01437  12 08                   DC.W     0x1208
F01439  01 00                   DC.W     0x0100
F0143B  09 67                   DC.W     0x0967
F0143D  00 fe                   DC.W     0x00fe
F0143F  be 90                   DC.W     0xbe90
F01441  8a e0                   DC.W     0x8ae0
F01443  88 24                   DC.W     0x8824
F01445  00 60                   DC.W     0x0060
F01447  00 fe                   DC.W     0x00fe
F01449  76 26                   DC.W     0x7626  ; 'v&'
F0144B  94 67                   DC.W     0x9467
F0144D  06 22                   DC.W     0x0622
F0144F  54 23                   DC.W     0x5423  ; 'T#'
F01451  4b 00                   DC.W     0x4b00
F01453  04 28                   DC.W     0x0428
F01455  8b 27                   DC.W     0x8b27
F01457  4c 00                   DC.W     0x4c00
F01459  04 27                   DC.W     0x0427
F0145B  6c 00                   DC.W     0x6c00
F0145D  0c 00                   DC.W     0x0c00
F0145F  0c 42                   DC.W     0x0c42
F01461  ac 00                   DC.W     0xac00
F01463  0c 90                   DC.W     0x0c90
F01465  8b e0                   DC.W     0x8be0
F01467  88 27                   DC.W     0x8827
F01469  40 00                   DC.W     0x4000
F0146B  08 91                   DC.W     0x0891
F0146D  ac 00                   DC.W     0xac00
F0146F  08 60                   DC.W     0x0860
F01471  00 fe                   DC.W     0x00fe
F01473  4c 43                   DC.W     0x4c43  ; 'LC'
F01475  e9 00                   DC.W     0xe900
F01477  0a 0c                   DC.W     0x0a0c
F01479  51 ff                   DC.W     0x51ff
F0147B  ff 66                   DC.W     0xff66
F0147D  00 ff                   DC.W     0x00ff
F0147F  54 08                   DC.W     0x5408
F01481  01 00                   DC.W     0x0100
F01483  0f 67                   DC.W     0x0f67
F01485  00 fe                   DC.W     0x00fe
F01487  ba 26                   DC.W     0xba26
F01489  4a 42                   DC.W     0x4a42  ; 'JB'
F0148B  84 60                   DC.W     0x8460
F0148D  00 fe                   DC.W     0x00fe
F0148F  4e 61                   DC.W     0x4e61  ; 'Na'
F01491  00 ec                   DC.W     0x00ec
F01493  f4 40                   DC.W     0xf440
F01495  e7 48                   DC.W     0xe748
F01497  e7 00                   DC.W     0xe700
F01499  0c 24                   DC.W     0x0c24
F0149B  01 6e                   DC.W     0x016e
F0149D  0a 4c                   DC.W     0x0a4c
F0149F  df 30                   DC.W     0xdf30
F014A1  00 54                   DC.W     0x0054
F014A3  af 00                   DC.W     0xaf00
F014A5  02 4e                   DC.W     0x024e
F014A7  73 24                   DC.W     0x7324  ; 's$'
F014A9  48 22                   DC.W     0x4822  ; 'H"'
F014AB  78 0c                   DC.W     0x780c
F014AD  00 0c                   DC.W     0x000c
F014AF  11 ff                   DC.W     0x11ff
F014B1  ff 67                   DC.W     0xff67
F014B3  1e 2a                   DC.W     0x1e2a
F014B5  69 00                   DC.W     0x6900
F014B7  06 b5                   DC.W     0x06b5
F014B9  cd 6c                   DC.W     0xcd6c
F014BB  16 b5                   DC.W     0x16b5
F014BD  e9 00                   DC.W     0xe900
F014BF  02 6d                   DC.W     0x026d
F014C1  dc 4a                   DC.W     0xdc4a
F014C3  51 6b                   DC.W     0x516b  ; 'Qk'
F014C5  e0 e1                   DC.W     0xe0e1
F014C7  89 d2                   DC.W     0x89d2
F014C9  8a b2                   DC.W     0x8ab2
F014CB  ad 00                   DC.W     0xad00
F014CD  08 62                   DC.W     0x0862
F014CF  ce 60                   DC.W     0xce60
F014D1  0c 43                   DC.W     0x0c43
F014D3  e9 00                   DC.W     0xe900
F014D5  0a 0c                   DC.W     0x0a0c
F014D7  51 ff                   DC.W     0x51ff
F014D9  ff 66                   DC.W     0xff66
F014DB  d2 60                   DC.W     0xd260
F014DD  c0 43                   DC.W     0xc043
F014DF  f8 00                   DC.W     0xf800
F014E1  00 41                   DC.W     0x0041
F014E3  ed 00                   DC.W     0xed00
F014E5  0e 61                   DC.W     0x0e61
F014E7  00 f2                   DC.W     0x00f2
F014E9  00 26                   DC.W     0x0026
F014EB  15 67                   DC.W     0x1567
F014ED  1e 20                   DC.W     0x1e20
F014EF  43 b1                   DC.W     0x43b1
F014F1  c1 6c                   DC.W     0xc16c
F014F3  06 22                   DC.W     0x0622
F014F5  48 26                   DC.W     0x4826  ; 'H&'
F014F7  10 66                   DC.W     0x1066
F014F9  f4 20                   DC.W     0xf420
F014FB  09 67                   DC.W     0x0967
F014FD  0e 20                   DC.W     0x0e20
F014FF  29 00                   DC.W     0x2900
F01501  08 e1                   DC.W     0x08e1
F01503  88 d0                   DC.W     0x88d0
F01505  89 b5                   DC.W     0x89b5
F01507  c0 6d                   DC.W     0xc06d
F01509  00 00                   DC.W     0x0000
F0150B  ac 25                   DC.W     0xac25
F0150D  42 00                   DC.W     0x4200
F0150F  08 20                   DC.W     0x0820
F01511  03 66                   DC.W     0x0366
F01513  04 20                   DC.W     0x0420
F01515  2d 00                   DC.W     0x2d00
F01517  08 90                   DC.W     0x0890
F01519  81 e0                   DC.W     0x81e0
F0151B  88 25                   DC.W     0x8825
F0151D  40 00                   DC.W     0x4000
F0151F  0c 24                   DC.W     0x0c24
F01521  83 25                   DC.W     0x8325
F01523  49 00                   DC.W     0x4900
F01525  04 66                   DC.W     0x0466
F01527  04 2a                   DC.W     0x042a
F01529  8a 60                   DC.W     0x8a60
F0152B  24 22                   DC.W     0x2422  ; '$"'
F0152D  8a 20                   DC.W     0x8a20
F0152F  0a 90                   DC.W     0x0a90
F01531  89 e0                   DC.W     0x89e0
F01533  88 90                   DC.W     0x8890
F01535  a9 00                   DC.W     0xa900
F01537  08 23                   DC.W     0x0823
F01539  40 00                   DC.W     0x4000
F0153B  0c 66                   DC.W     0x0c66
F0153D  12 20                   DC.W     0x1220
F0153F  2a 00                   DC.W     0x2a00
F01541  08 d1                   DC.W     0x08d1
F01543  a9 00                   DC.W     0xa900
F01545  08 23                   DC.W     0x0823
F01547  6a 00                   DC.W     0x6a00
F01549  0c 00                   DC.W     0x0c00
F0154B  0c 22                   DC.W     0x0c22
F0154D  92 24                   DC.W     0x9224
F0154F  49 4a                   DC.W     0x494a  ; 'IJ'
F01551  83 67                   DC.W     0x8367
F01553  24 22                   DC.W     0x2422  ; '$"'
F01555  43 23                   DC.W     0x4323  ; 'C#'
F01557  4a 00                   DC.W     0x4a00
F01559  04 4a                   DC.W     0x044a
F0155B  aa 00                   DC.W     0xaa00
F0155D  0c 66                   DC.W     0x0c66
F0155F  18 20                   DC.W     0x1820
F01561  29 00                   DC.W     0x2900
F01563  08 d1                   DC.W     0x08d1
F01565  aa 00                   DC.W     0xaa00
F01567  08 25                   DC.W     0x0825
F01569  69 00                   DC.W     0x6900
F0156B  0c 00                   DC.W     0x0c00
F0156D  0c 24                   DC.W     0x0c24
F0156F  91 67                   DC.W     0x9167
F01571  06 22                   DC.W     0x0622
F01573  52 23                   DC.W     0x5223  ; 'R#'
F01575  4a 00                   DC.W     0x4a00
F01577  04 12                   DC.W     0x0412
F01579  2d 00                   DC.W     0x2d00
F0157B  0c 02                   DC.W     0x0c02
F0157D  01 00                   DC.W     0x0100
F0157F  f0 22                   DC.W     0xf022
F01581  78 0c                   DC.W     0x780c
F01583  00 b2                   DC.W     0x00b2
F01585  11 66                   DC.W     0x1166
F01587  16 28                   DC.W     0x1628
F01589  69 00                   DC.W     0x6900
F0158B  06 08                   DC.W     0x0608
F0158D  2c 00                   DC.W     0x2c00
F0158F  06 00                   DC.W     0x0600
F01591  14 67                   DC.W     0x1467
F01593  0a 41                   DC.W     0x0a41
F01595  ec 00                   DC.W     0xec00
F01597  14 61                   DC.W     0x1461
F01599  00 f1                   DC.W     0x00f1
F0159B  ee 60                   DC.W     0xee60
F0159D  ee 43                   DC.W     0xee43
F0159F  e9 00                   DC.W     0xe900
F015A1  0a 0c                   DC.W     0x0a0c
F015A3  51 ff                   DC.W     0x51ff
F015A5  ff 66                   DC.W     0xff66
F015A7  dc 41                   DC.W     0xdc41
F015A9  ed 00                   DC.W     0xed00
F015AB  0e 61                   DC.W     0x0e61
F015AD  00 f1                   DC.W     0x00f1
F015AF  da 4c                   DC.W     0xda4c
F015B1  df 30                   DC.W     0xdf30
F015B3  00 4e                   DC.W     0x004e
F015B5  73 54                   DC.W     0x7354  ; 'sT'
F015B7  af 00                   DC.W     0xaf00
F015B9  02 60                   DC.W     0x0260
F015BB  ec 40                   DC.W     0xec40
F015BD  e7 2a                   DC.W     0xe72a
F015BF  49 22                   DC.W     0x4922  ; 'I"'
F015C1  48 20                   DC.W     0x4820  ; 'H '
F015C3  51 22                   DC.W     0x5122  ; 'Q"'
F015C5  29 00                   DC.W     0x2900
F015C7  04 61                   DC.W     0x0461
F015C9  00 01                   DC.W     0x0001
F015CB  34 60                   DC.W     0x3460  ; '4`'
F015CD  06 54                   DC.W     0x0654
F015CF  af 00                   DC.W     0xaf00
F015D1  02 4e                   DC.W     0x024e
F015D3  73 22                   DC.W     0x7322  ; 's"'
F015D5  4d 60                   DC.W     0x4d60  ; 'M`'
F015D7  02 40                   DC.W     0x0240
F015D9  e7 0c                   DC.W     0xe70c
F015DB  90 21                   DC.W     0x9021
F015DD  54 43                   DC.W     0x5443  ; 'TC'
F015DF  42 66                   DC.W     0x4266  ; 'Bf'
F015E1  ec 2a                   DC.W     0xec2a
F015E3  48 28                   DC.W     0x4828  ; 'H('
F015E5  6d 00                   DC.W     0x6d00
F015E7  40 0c                   DC.W     0x400c
F015E9  94 21                   DC.W     0x9421
F015EB  41 53                   DC.W     0x4153  ; 'AS'
F015ED  51 66                   DC.W     0x5166  ; 'Qf'
F015EF  08 08                   DC.W     0x0808
F015F1  ec 00                   DC.W     0xec00
F015F3  0f 00                   DC.W     0x0f00
F015F5  04 60                   DC.W     0x0460
F015F7  20 54                   DC.W     0x2054  ; ' T'
F015F9  af 00                   DC.W     0xaf00
F015FB  02 60                   DC.W     0x0260
F015FD  00 00                   DC.W     0x0000
F015FF  6a 40                   DC.W     0x6a40  ; 'j@'
F01601  e7 0c                   DC.W     0xe70c
F01603  90 21                   DC.W     0x9021
F01605  54 43                   DC.W     0x5443  ; 'TC'
F01607  42 66                   DC.W     0x4266  ; 'Bf'
F01609  50 2a                   DC.W     0x502a  ; 'P*'
F0160B  48 28                   DC.W     0x4828  ; 'H('
F0160D  6d 00                   DC.W     0x6d00
F0160F  40 20                   DC.W     0x4020  ; '@ '
F01611  0c 67                   DC.W     0x0c67
F01613  ba 4a                   DC.W     0xba4a
F01615  f8 0c                   DC.W     0xf80c
F01617  5b 08                   DC.W     0x5b08
F01619  2c 00                   DC.W     0x2c00
F0161B  08 00                   DC.W     0x0800
F0161D  04 67                   DC.W     0x0467
F0161F  3a 22                   DC.W     0x3a22  ; ':"'
F01621  02 e1                   DC.W     0x02e1
F01623  99 02                   DC.W     0x9902
F01625  81 00                   DC.W     0x8100
F01627  00 00                   DC.W     0x0000
F01629  ff 61                   DC.W     0xff61
F0162B  00 11                   DC.W     0x0011
F0162D  38 60                   DC.W     0x3860  ; '8`'
F0162F  02 60                   DC.W     0x0260
F01631  28 48                   DC.W     0x2848  ; '(H'
F01633  e7 3c                   DC.W     0xe73c
F01635  00 74                   DC.W     0x0074
F01637  10 61                   DC.W     0x1061
F01639  30 67                   DC.W     0x3067  ; '0g'
F0163B  0e df                   DC.W     0x0edf
F0163D  fc 00                   DC.W     0xfc00
F0163F  00 00                   DC.W     0x0000
F01641  10 48                   DC.W     0x1048
F01643  e7 03                   DC.W     0xe703
F01645  60 74                   DC.W     0x6074  ; '`t'
F01647  10 61                   DC.W     0x1061
F01649  20 df                   DC.W     0x20df
F0164B  fc 00                   DC.W     0xfc00
F0164D  00 00                   DC.W     0x0000
F0164F  10 4a                   DC.W     0x104a
F01651  80 67                   DC.W     0x8067
F01653  0a 61                   DC.W     0x0a61
F01655  00 10                   DC.W     0x0010
F01657  52 60                   DC.W     0x5260  ; 'R`'
F01659  04 54                   DC.W     0x0454
F0165B  af 00                   DC.W     0xaf00
F0165D  02 08                   DC.W     0x0208
F0165F  ac 00                   DC.W     0xac00
F01661  0f 00                   DC.W     0x0f00
F01663  04 66                   DC.W     0x0466
F01665  02 4e                   DC.W     0x024e
F01667  73 4e                   DC.W     0x734e  ; 'sN'
F01669  73 41                   DC.W     0x7341  ; 'sA'
F0166B  ef 00                   DC.W     0xef00
F0166D  04 36                   DC.W     0x0436
F0166F  d8 b7                   DC.W     0xd8b7
F01671  ec 00                   DC.W     0xec00
F01673  1a 65                   DC.W     0x1a65
F01675  04 26                   DC.W     0x0426
F01677  6c 00                   DC.W     0x6c00
F01679  16 55                   DC.W     0x1655
F0167B  42 67                   DC.W     0x4267  ; 'Bg'
F0167D  06 55                   DC.W     0x0655
F0167F  81 66                   DC.W     0x8166
F01681  ec 4e                   DC.W     0xec4e
F01683  75 55                   DC.W     0x7555  ; 'uU'
F01685  41 4e                   DC.W     0x414e  ; 'AN'
F01687  75 48                   DC.W     0x7548  ; 'uH'
F01689  e7 c0                   DC.W     0xe7c0
F0168B  1c 40                   DC.W     0x1c40
F0168D  e7 26                   DC.W     0xe726
F0168F  78 0c                   DC.W     0x780c
F01691  30 00                   DC.W     0x3000
F01693  7c 07                   DC.W     0x7c07
F01695  00 2a                   DC.W     0x002a
F01697  53 bb                   DC.W     0x53bb
F01699  eb 00                   DC.W     0xeb00
F0169B  04 66                   DC.W     0x0466
F0169D  04 4b                   DC.W     0x044b
F0169F  eb 00                   DC.W     0xeb00
F016A1  08 49                   DC.W     0x0849
F016A3  ed 00                   DC.W     0xed00
F016A5  1a 26                   DC.W     0x1a26
F016A7  8c 46                   DC.W     0x8c46
F016A9  df 2b                   DC.W     0xdf2b
F016AB  40 00                   DC.W     0x4000
F016AD  10 2b                   DC.W     0x102b
F016AF  48 00                   DC.W     0x4800
F016B1  08 2b                   DC.W     0x082b
F016B3  4e 00                   DC.W     0x4e00
F016B5  0c 28                   DC.W     0x0c28
F016B7  6f 00                   DC.W     0x6f00
F016B9  14 3a                   DC.W     0x143a
F016BB  94 54                   DC.W     0x9454
F016BD  af 00                   DC.W     0xaf00
F016BF  14 3b                   DC.W     0x143b
F016C1  6f 00                   DC.W     0x6f00
F016C3  18 00                   DC.W     0x1800
F016C5  02 2b                   DC.W     0x022b
F016C7  6f 00                   DC.W     0x6f00
F016C9  1a 00                   DC.W     0x1a00
F016CB  04 0c                   DC.W     0x040c
F016CD  55 ef                   DC.W     0x55ef
F016CF  ff 62                   DC.W     0xff62
F016D1  06 2b                   DC.W     0x062b
F016D3  6f 00                   DC.W     0x6f00
F016D5  20 00                   DC.W     0x2000
F016D7  08 61                   DC.W     0x0861
F016D9  00 f8                   DC.W     0x00f8
F016DB  bc 2b                   DC.W     0xbc2b
F016DD  41 00                   DC.W     0x4100
F016DF  14 32                   DC.W     0x1432
F016E1  3c 00                   DC.W     0x3c00
F016E3  f9 92                   DC.W     0xf992
F016E5  00 e0                   DC.W     0x00e0
F016E7  48 46                   DC.W     0x4846  ; 'HF'
F016E9  40 02                   DC.W     0x4002
F016EB  40 00                   DC.W     0x4000
F016ED  03 c0                   DC.W     0x03c0
F016EF  fc 00                   DC.W     0xfc00
F016F1  fa d2                   DC.W     0xfad2
F016F3  40 3b                   DC.W     0x403b  ; '@;'
F016F5  41 00                   DC.W     0x4100
F016F7  18 4c                   DC.W     0x184c
F016F9  df 38                   DC.W     0xdf38
F016FB  03 4e                   DC.W     0x034e
F016FD  75 40                   DC.W     0x7540  ; 'u@'
F016FF  e7 20                   DC.W     0xe720
F01701  08 67                   DC.W     0x0867
F01703  06 4a                   DC.W     0x064a
F01705  81 67                   DC.W     0x8167
F01707  1a 60                   DC.W     0x1a60
F01709  1c 20                   DC.W     0x1c20
F0170B  4e 4e                   DC.W     0x4e4e  ; 'NN'
F0170D  73 40                   DC.W     0x7340  ; 's@'
F0170F  e7 20                   DC.W     0xe720
F01711  10 67                   DC.W     0x1067
F01713  f6 22                   DC.W     0xf622
F01715  28 00                   DC.W     0x2800
F01717  04 67                   DC.W     0x0467
F01719  08 08                   DC.W     0x0808
F0171B  2e 00                   DC.W     0x2e00
F0171D  0f 00                   DC.W     0x0f00
F0171F  28 66                   DC.W     0x2866  ; '(f'
F01721  04 22                   DC.W     0x0422
F01723  2e 00                   DC.W     0x2e00
F01725  14 b0                   DC.W     0x14b0
F01727  ae 00                   DC.W     0xae00
F01729  10 66                   DC.W     0x1066
F0172B  06 b2                   DC.W     0x06b2
F0172D  ae 00                   DC.W     0xae00
F0172F  14 67                   DC.W     0x1467
F01731  d8 22                   DC.W     0xd822
F01733  78 0c                   DC.W     0x780c
F01735  10 b3                   DC.W     0x10b3
F01737  fc 00                   DC.W     0xfc00
F01739  00 00                   DC.W     0x0000
F0173B  00 67                   DC.W     0x0067
F0173D  12 b0                   DC.W     0x12b0
F0173F  a9 00                   DC.W     0xa900
F01741  10 66                   DC.W     0x1066
F01743  06 b2                   DC.W     0x06b2
F01745  a9 00                   DC.W     0xa900
F01747  14 67                   DC.W     0x1467
F01749  0a 22                   DC.W     0x0a22
F0174B  69 00                   DC.W     0x6900
F0174D  04 60                   DC.W     0x0460
F0174F  e6 54                   DC.W     0xe654
F01751  af 00                   DC.W     0xaf00
F01753  02 20                   DC.W     0x0220
F01755  49 4e                   DC.W     0x494e  ; 'IN'
F01757  73 40                   DC.W     0x7340  ; 's@'
F01759  e7 60                   DC.W     0xe760
F0175B  06 40                   DC.W     0x0640
F0175D  e7 08                   DC.W     0xe708
F0175F  86 00                   DC.W     0x8600
F01761  00 02                   DC.W     0x0002
F01763  86 00                   DC.W     0x8600
F01765  ff ff                   DC.W     0xffff
F01767  ff 42                   DC.W     0xff42
F01769  80 26                   DC.W     0x8026
F0176B  06 e0                   DC.W     0x06e0
F0176D  8e 28                   DC.W     0x8e28
F0176F  05 6f                   DC.W     0x056f
F01771  44 d8                   DC.W     0x44d8
F01773  83 53                   DC.W     0x8353
F01775  84 e0                   DC.W     0x84e0
F01777  8c 42                   DC.W     0x8c42
F01779  85 3a                   DC.W     0x853a
F0177B  28 00                   DC.W     0x2800
F0177D  06 4a                   DC.W     0x064a
F0177F  30 50                   DC.W     0x3050  ; '0P'
F01781  07 67                   DC.W     0x0767
F01783  28 bc                   DC.W     0x28bc
F01785  70 50                   DC.W     0x7050  ; 'pP'
F01787  00 65                   DC.W     0x0065
F01789  24 bc                   DC.W     0x24bc
F0178B  70 50                   DC.W     0x7050  ; 'pP'
F0178D  02 62                   DC.W     0x0262
F0178F  1e b8                   DC.W     0x1eb8
F01791  70 50                   DC.W     0x7050  ; 'pP'
F01793  02 62                   DC.W     0x0262
F01795  26 dc                   DC.W     0x26dc
F01797  70 50                   DC.W     0x7050  ; 'pP'
F01799  04 e1                   DC.W     0x04e1
F0179B  8e dc                   DC.W     0x8edc
F0179D  03 08                   DC.W     0x0308
F0179F  30 00                   DC.W     0x3000
F017A1  0b 50                   DC.W     0x0b50
F017A3  24 67                   DC.W     0x2467  ; '$g'
F017A5  04 58                   DC.W     0x0458
F017A7  af 00                   DC.W     0xaf00
F017A9  02 4e                   DC.W     0x024e
F017AB  73 20                   DC.W     0x7320  ; 's '
F017AD  05 51                   DC.W     0x0551
F017AF  85 0c                   DC.W     0x850c
F017B1  45 00                   DC.W     0x4500
F017B3  0c 6c                   DC.W     0x0c6c
F017B5  c8 2a                   DC.W     0xc82a
F017B7  00 54                   DC.W     0x0054
F017B9  af 00                   DC.W     0xaf00
F017BB  02 54                   DC.W     0x0254
F017BD  af 00                   DC.W     0xaf00
F017BF  02 2c                   DC.W     0x022c
F017C1  03 4e                   DC.W     0x034e
F017C3  73 40                   DC.W     0x7340  ; 's@'
F017C5  e7 42                   DC.W     0xe742
F017C7  80 2a                   DC.W     0x802a
F017C9  08 67                   DC.W     0x0867
F017CB  20 42                   DC.W     0x2042  ; ' B'
F017CD  85 3a                   DC.W     0x853a
F017CF  28 00                   DC.W     0x2800
F017D1  06 08                   DC.W     0x0608
F017D3  30 00                   DC.W     0x3000
F017D5  0f 50                   DC.W     0x0f50
F017D7  24 66                   DC.W     0x2466  ; '$f'
F017D9  04 20                   DC.W     0x0420
F017DB  05 60                   DC.W     0x0560
F017DD  06 be                   DC.W     0x06be
F017DF  b0 50                   DC.W     0xb050
F017E1  20 67                   DC.W     0x2067  ; ' g'
F017E3  0e 51                   DC.W     0x0e51
F017E5  85 0c                   DC.W     0x850c
F017E7  45 00                   DC.W     0x4500
F017E9  0c 6c                   DC.W     0x0c6c
F017EB  e6 2a                   DC.W     0xe62a
F017ED  00 54                   DC.W     0x0054
F017EF  af 00                   DC.W     0xaf00
F017F1  02 4e                   DC.W     0x024e
F017F3  73 40                   DC.W     0x7340  ; 's@'
F017F5  e7 42                   DC.W     0xe742
F017F7  83 42                   DC.W     0x8342
F017F9  80 22                   DC.W     0x8022
F017FB  78 0c                   DC.W     0x780c
F017FD  20 20                   DC.W     0x2020  ; '  '
F017FF  09 67                   DC.W     0x0967
F01801  62 45                   DC.W     0x6245  ; 'bE'
F01803  e9 00                   DC.W     0xe900
F01805  14 30                   DC.W     0x1430
F01807  29 00                   DC.W     0x2900
F01809  0e 67                   DC.W     0x0e67
F0180B  50 97                   DC.W     0x5097
F0180D  cb 4a                   DC.W     0xcb4a
F0180F  6a 00                   DC.W     0x6a00
F01811  0a 66                   DC.W     0x0a66
F01813  0c b7                   DC.W     0x0cb7
F01815  fc 00                   DC.W     0xfc00
F01817  00 00                   DC.W     0x0000
F01819  00 66                   DC.W     0x0066
F0181B  24 26                   DC.W     0x2426  ; '$&'
F0181D  4a 60                   DC.W     0x4a60  ; 'J`'
F0181F  20 b1                   DC.W     0x20b1
F01821  ea 00                   DC.W     0xea00
F01823  04 66                   DC.W     0x0466
F01825  1a b4                   DC.W     0x1ab4
F01827  92 67                   DC.W     0x9267
F01829  44 08                   DC.W     0x4408
F0182B  2a 00                   DC.W     0x2a00
F0182D  0c 00                   DC.W     0x0c00
F0182F  08 67                   DC.W     0x0867
F01831  0e 08                   DC.W     0x0e08
F01833  01 00                   DC.W     0x0100
F01835  0c 66                   DC.W     0x0c66
F01837  36 08                   DC.W     0x3608
F01839  01 00                   DC.W     0x0100
F0183B  0d 66                   DC.W     0x0d66
F0183D  02 26                   DC.W     0x0226
F0183F  0a d5                   DC.W     0x0ad5
F01841  fc 00                   DC.W     0xfc00
F01843  00 00                   DC.W     0x0000
F01845  12 53                   DC.W     0x1253
F01847  40 66                   DC.W     0x4066  ; '@f'
F01849  c4 4a                   DC.W     0xc44a
F0184B  83 66                   DC.W     0x8366
F0184D  24 30                   DC.W     0x2430  ; '$0'
F0184F  29 00                   DC.W     0x2900
F01851  0e 20                   DC.W     0x0e20
F01853  4b b7                   DC.W     0x4bb7
F01855  fc 00                   DC.W     0xfc00
F01857  00 00                   DC.W     0x0000
F01859  00 66                   DC.W     0x0066
F0185B  0c 20                   DC.W     0x0c20
F0185D  4a b0                   DC.W     0x4ab0
F0185F  69 00                   DC.W     0x6900
F01861  0c 6d                   DC.W     0x0c6d
F01863  02 91                   DC.W     0x0291
F01865  c8 52                   DC.W     0xc852
F01867  80 54                   DC.W     0x8054
F01869  af 00                   DC.W     0xaf00
F0186B  02 4e                   DC.W     0x024e
F0186D  73 20                   DC.W     0x7320  ; 's '
F0186F  4a 4e                   DC.W     0x4a4e  ; 'JN'
F01871  73 20                   DC.W     0x7320  ; 's '
F01873  43 4e                   DC.W     0x434e  ; 'CN'
F01875  73 40                   DC.W     0x7340  ; 's@'
F01877  e7 42                   DC.W     0xe742
F01879  82 42                   DC.W     0x8242
F0187B  83 42                   DC.W     0x8342
F0187D  81 22                   DC.W     0x8122
F0187F  78 0c                   DC.W     0x780c
F01881  24 28                   DC.W     0x2428  ; '$('
F01883  09 67                   DC.W     0x0967
F01885  66 34                   DC.W     0x6634  ; 'f4'
F01887  29 00                   DC.W     0x2900
F01889  0e b4                   DC.W     0x0eb4
F0188B  69 00                   DC.W     0x6900
F0188D  0c 67                   DC.W     0x0c67
F0188F  02 52                   DC.W     0x0252
F01891  42 28                   DC.W     0x4228  ; 'B('
F01893  02 70                   DC.W     0x0270
F01895  14 4a                   DC.W     0x144a
F01897  71 00                   DC.W     0x7100
F01899  0c 66                   DC.W     0x0c66
F0189B  14 4a                   DC.W     0x144a
F0189D  83 66                   DC.W     0x8366
F0189F  3a 26                   DC.W     0x3a26  ; ':&'
F018A1  00 0c                   DC.W     0x000c
F018A3  84 00                   DC.W     0x8400
F018A5  00 00                   DC.W     0x0000
F018A7  01 67                   DC.W     0x0167
F018A9  30 34                   DC.W     0x3034  ; '04'
F018AB  29 00                   DC.W     0x2900
F018AD  0e 60                   DC.W     0x0e60
F018AF  2a b1                   DC.W     0x2ab1
F018B1  fc 00                   DC.W     0xfc00
F018B3  00 00                   DC.W     0x0000
F018B5  00 67                   DC.W     0x0067
F018B7  06 b1                   DC.W     0x06b1
F018B9  f1 00                   DC.W     0xf100
F018BB  08 66                   DC.W     0x0866
F018BD  1c 24                   DC.W     0x1c24
F018BF  6c 00                   DC.W     0x6c00
F018C1  14 b5                   DC.W     0x14b5
F018C3  f1 00                   DC.W     0xf100
F018C5  04 66                   DC.W     0x0466
F018C7  12 24                   DC.W     0x1224
F018C9  6c 00                   DC.W     0x6c00
F018CB  10 b5                   DC.W     0x10b5
F018CD  f1 00                   DC.W     0xf100
F018CF  00 67                   DC.W     0x0067
F018D1  24 4a                   DC.W     0x244a  ; '$J'
F018D3  71 00                   DC.W     0x7100
F018D5  0c 6b                   DC.W     0x0c6b
F018D7  02 22                   DC.W     0x0222
F018D9  00 06                   DC.W     0x0006
F018DB  80 00                   DC.W     0x8000
F018DD  00 00                   DC.W     0x0000
F018DF  16 53                   DC.W     0x1653
F018E1  44 66                   DC.W     0x4466  ; 'Df'
F018E3  b2 54                   DC.W     0xb254
F018E5  af 00                   DC.W     0xaf00
F018E7  02 4a                   DC.W     0x024a
F018E9  83 66                   DC.W     0x8366
F018EB  06 42                   DC.W     0x0642
F018ED  80 42                   DC.W     0x8042
F018EF  82 4e                   DC.W     0x824e
F018F1  73 20                   DC.W     0x7320  ; 's '
F018F3  03 4e                   DC.W     0x034e
F018F5  73 20                   DC.W     0x7320  ; 's '
F018F7  71 00                   DC.W     0x7100
F018F9  08 4e                   DC.W     0x084e
F018FB  73 bb                   DC.W     0x73bb
F018FD  ce 67                   DC.W     0xce67
F018FF  20 08                   DC.W     0x2008
F01901  2d 00                   DC.W     0x2d00
F01903  0f 00                   DC.W     0x0f00
F01905  2c 66                   DC.W     0x2c66  ; ',f'
F01907  1c 06                   DC.W     0x1c06
F01909  6e 00                   DC.W     0x6e00
F0190B  0a 01                   DC.W     0x0a01
F0190D  02 4e                   DC.W     0x024e
F0190F  73 5a                   DC.W     0x735a  ; 'sZ'
F01911  6e 01                   DC.W     0x6e01
F01913  02 60                   DC.W     0x0260
F01915  00 01                   DC.W     0x0001
F01917  72 5c                   DC.W     0x725c  ; 'r\'
F01919  6e 01                   DC.W     0x6e01
F0191B  02 60                   DC.W     0x0260
F0191D  00 01                   DC.W     0x0001
F0191F  6a 42                   DC.W     0x6a42  ; 'jB'
F01921  b8 0c                   DC.W     0xb80c
F01923  62 2e                   DC.W     0x622e  ; 'b.'
F01925  2c 00                   DC.W     0x2c00
F01927  0c 20                   DC.W     0x0c20
F01929  6d 00                   DC.W     0x6d00
F0192B  36 61                   DC.W     0x3661  ; '6a'
F0192D  00 fe                   DC.W     0x00fe
F0192F  96 60                   DC.W     0x9660
F01931  e6 4a                   DC.W     0xe64a
F01933  85 67                   DC.W     0x8567
F01935  da 30                   DC.W     0xda30
F01937  2c 00                   DC.W     0x2c00
F01939  0a 32                   DC.W     0x0a32
F0193B  2c 00                   DC.W     0x2c00
F0193D  08 02                   DC.W     0x0802
F0193F  41 27                   DC.W     0x4127  ; 'A''
F01941  ff 08                   DC.W     0xff08
F01943  01 00                   DC.W     0x0100
F01945  08 67                   DC.W     0x0867
F01947  04 08                   DC.W     0x0408
F01949  81 00                   DC.W     0x8100
F0194B  07 08                   DC.W     0x0708
F0194D  00 00                   DC.W     0x0000
F0194F  0a 66                   DC.W     0x0a66
F01951  0a 08                   DC.W     0x0a08
F01953  00 00                   DC.W     0x0000
F01955  0b 67                   DC.W     0x0b67
F01957  10 08                   DC.W     0x1008
F01959  c1 00                   DC.W     0xc100
F0195B  0f 08                   DC.W     0x0f08
F0195D  c1 00                   DC.W     0xc100
F0195F  08 08                   DC.W     0x0808
F01961  c1 00                   DC.W     0xc100
F01963  07 08                   DC.W     0x0708
F01965  81 00                   DC.W     0x8100
F01967  0d 42                   DC.W     0x0d42
F01969  87 2c                   DC.W     0x872c
F0196B  2c 00                   DC.W     0x2c00
F0196D  10 08                   DC.W     0x1008
F0196F  01 00                   DC.W     0x0100
F01971  08 67                   DC.W     0x0867
F01973  04 08                   DC.W     0x0408
F01975  81 00                   DC.W     0x8100
F01977  0d 08                   DC.W     0x0d08
F01979  01 00                   DC.W     0x0100
F0197B  0d 67                   DC.W     0x0d67
F0197D  02 42                   DC.W     0x0242
F0197F  86 1e                   DC.W     0x861e
F01981  06 de                   DC.W     0x06de
F01983  ac 00                   DC.W     0xac00
F01985  14 06                   DC.W     0x1406
F01987  87 00                   DC.W     0x8700
F01989  00 00                   DC.W     0x0000
F0198B  ff e0                   DC.W     0xffe0
F0198D  8f 02                   DC.W     0x8f02
F0198F  86 00                   DC.W     0x8600
F01991  ff ff                   DC.W     0xffff
F01993  00 22                   DC.W     0x0022
F01995  46 08                   DC.W     0x4608
F01997  01 00                   DC.W     0x0100
F01999  08 66                   DC.W     0x0866
F0199B  1e 08                   DC.W     0x1e08
F0199D  81 00                   DC.W     0x8100
F0199F  07 66                   DC.W     0x0766
F019A1  18 41                   DC.W     0x1841
F019A3  f8 0c                   DC.W     0xf80c
F019A5  74 08                   DC.W     0x7408
F019A7  00 00                   DC.W     0x0000
F019A9  0e 66                   DC.W     0x0e66
F019AB  02 52                   DC.W     0x0252
F019AD  88 08                   DC.W     0x8808
F019AF  2d 00                   DC.W     0x2d00
F019B1  0f 00                   DC.W     0x0f00
F019B3  28 66                   DC.W     0x2866  ; '(f'
F019B5  02 54                   DC.W     0x0254
F019B7  88 12                   DC.W     0x8812
F019B9  10 48                   DC.W     0x1048
F019BB  47 3e                   DC.W     0x473e  ; 'G>'
F019BD  01 02                   DC.W     0x0102
F019BF  47 87                   DC.W     0x4787
F019C1  ff 3f                   DC.W     0xff3f
F019C3  01 48                   DC.W     0x0148
F019C5  47 20                   DC.W     0x4720  ; 'G '
F019C7  47 61                   DC.W     0x4761  ; 'Ga'
F019C9  00 f8                   DC.W     0x00f8
F019CB  74 60                   DC.W     0x7460  ; 't`'
F019CD  2c 53                   DC.W     0x2c53  ; ',S'
F019CF  80 67                   DC.W     0x8067
F019D1  08 5e                   DC.W     0x085e
F019D3  6e 01                   DC.W     0x6e01
F019D5  02 60                   DC.W     0x0260
F019D7  00 00                   DC.W     0x0000
F019D9  ac 50                   DC.W     0xac50
F019DB  6e 01                   DC.W     0x6e01
F019DD  02 60                   DC.W     0x0260
F019DF  f6 06                   DC.W     0xf606
F019E1  6e 00                   DC.W     0x6e00
F019E3  0b 01                   DC.W     0x0b01
F019E5  02 08                   DC.W     0x0208
F019E7  07 00                   DC.W     0x0700
F019E9  07 66                   DC.W     0x0766
F019EB  ea 22                   DC.W     0xea22
F019ED  07 41                   DC.W     0x0741
F019EF  d3 61                   DC.W     0xd361
F019F1  00 fa                   DC.W     0x00fa
F019F3  a2 60                   DC.W     0xa260
F019F5  e0 61                   DC.W     0xe061
F019F7  00 e7                   DC.W     0x00e7
F019F9  8e 26                   DC.W     0x8e26
F019FB  48 2e                   DC.W     0x482e  ; 'H.'
F019FD  02 2a                   DC.W     0x022a
F019FF  02 e1                   DC.W     0x02e1
F01A01  8d 08                   DC.W     0x8d08
F01A03  17 00                   DC.W     0x1700
F01A05  0d 67                   DC.W     0x0d67
F01A07  02 2c                   DC.W     0x022c
F01A09  0b 22                   DC.W     0x0b22
F01A0B  46 20                   DC.W     0x4620  ; 'F '
F01A0D  6d 00                   DC.W     0x6d00
F01A0F  36 61                   DC.W     0x3661  ; '6a'
F01A11  00 fd                   DC.W     0x00fd
F01A13  4a 60                   DC.W     0x4a60  ; 'J`'
F01A15  ca 60                   DC.W     0xca60
F01A17  c8 4a                   DC.W     0xc84a
F01A19  30 50                   DC.W     0x3050  ; '0P'
F01A1B  07 66                   DC.W     0x0766
F01A1D  c2 21                   DC.W     0xc221
F01A1F  ac 00                   DC.W     0xac00
F01A21  0c 50                   DC.W     0x0c50
F01A23  20 30 2c                DC.B     " 0,"  ; 3 bytes
F01A26  00 0a                   DC.W     0x000a
F01A28  02 40                   DC.W     0x0240
F01A2A  4f ff                   DC.W     0x4fff
F01A2C  08 00                   DC.W     0x0800
F01A2E  00 0a                   DC.W     0x000a
F01A30  67 04                   DC.W     0x6704
F01A32  08 c0                   DC.W     0x08c0
F01A34  00 0e                   DC.W     0x000e
F01A36  31 80 50 24             move.w   d0, $24(a0, d5.w)
F01A3A  31 bc 00 01 50 06       move.w   #$1, $6(a0, d5.w)
F01A40  08 00 00 0e             btst.b   #$e, d0
F01A44  67 06                   beq.b    loc_F01A4C
F01A46  31 bc 00 03 50 06       move.w   #$3, $6(a0, d5.w)

loc_F01A4C:
F01A4C  20 09                   move.l   a1, d0
F01A4E  e0 88                   lsr.l    #$8, d0
F01A50  31 80 50 00             move.w   d0, (a0, d5.w)
F01A54  d0 87                   add.l    d7, d0
F01A56  53 80                   subq.l   #$1, d0
F01A58  31 80 50 02             move.w   d0, $2(a0, d5.w)
F01A5C  20 0b                   move.l   a3, d0
F01A5E  90 89                   sub.l    a1, d0
F01A60  e0 88                   lsr.l    #$8, d0
F01A62  31 80 50 04             move.w   d0, $4(a0, d5.w)
F01A66  11 81 50 26             move.b   d1, $26(a0, d5.w)
F01A6A  08 f0 00 0f 50 24       bset.b   #$f, $24(a0, d5.w)
F01A70  52 28 00 05             addq.b   #$1, $5(a0)
F01A74  2d 4b 01 20             move.l   a3, $120(a6)
F01A78  08 17 00 09             btst.b   #$9, (a7)
F01A7C  67 06                   beq.b    loc_F01A84
F01A7E  e1 8f                   lsl.l    #$8, d7
F01A80  2d 47 01 24             move.l   d7, $124(a6)

loc_F01A84:
F01A84  4f ef 00 02             lea.l    $2(a7), a7

loc_F01A88:
F01A88  4e 73                   rte      
F01A8A  2e 2c                   DC.W     0x2e2c  ; '.,'
F01A8C  00 0c                   DC.W     0x000c
F01A8E  38 2c                   DC.W     0x382c  ; '8,'
F01A90  00 08                   DC.W     0x0008
F01A92  28 4d                   DC.W     0x284d  ; '(M'
F01A94  b9 ce                   DC.W     0xb9ce
F01A96  67 10                   DC.W     0x6710
F01A98  08 2c                   DC.W     0x082c
F01A9A  00 0f                   DC.W     0x000f
F01A9C  00 2c                   DC.W     0x002c
F01A9E  66 0c                   DC.W     0x660c
F01AA0  06 6e                   DC.W     0x066e
F01AA2  00 0a                   DC.W     0x000a
F01AA4  01 02                   DC.W     0x0102
F01AA6  4e 73                   DC.W     0x4e73  ; 'Ns'
F01AA8  42 b8 0c 62             clr.l    $c62.w
F01AAC  2a 6c 00 36             movea.l  $36(a4), a5
F01AB0  41 d5                   lea.l    (a5), a0
F01AB2  61 00 fd 10             bsr.w    loc_F017C4
F01AB6  60 08                   bra.b    loc_F01AC0
F01AB8  5e 6e                   DC.W     0x5e6e  ; '^n'
F01ABA  01 02                   DC.W     0x0102
F01ABC  60 00                   DC.W     0x6000
F01ABE  00 b0                   DC.W     0x00b0

loc_F01AC0:
F01AC0  4a ac 00 40             tst.l    $40(a4)
F01AC4  67 1c                   beq.b    loc_F01AE2
F01AC6  20 2c 01 3c             move.l   $13c(a4), d0
F01ACA  e0 88                   lsr.l    #$8, d0
F01ACC  b0 75 50 00             cmp.w    (a5, d5.w), d0
F01AD0  65 10                   bcs.b    loc_F01AE2
F01AD2  b0 75 50 02             cmp.w    $2(a5, d5.w), d0
F01AD6  62 0a                   bhi.b    loc_F01AE2
F01AD8  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F01ADE  60 00 00 8e             bra.w    loc_F01B6E

loc_F01AE2:
F01AE2  30 35 50 24             move.w   $24(a5, d5.w), d0
F01AE6  02 40 30 00             andi.w   #$3000, d0
F01AEA  67 40                   beq.b    loc_F01B2C
F01AEC  24 2c 00 14             move.l   $14(a4), d2
F01AF0  32 35 50 24             move.w   $24(a5, d5.w), d1
F01AF4  20 75 50 20             movea.l  $20(a5, d5.w), a0
F01AF8  61 00 fc fa             bsr.w    loc_F017F4
F01AFC  60 04                   bra.b    loc_F01B02
F01AFE  61 00                   DC.W     0x6100
F01B00  e6 86                   DC.W     0xe686

loc_F01B02:
F01B02  3c 28 00 10             move.w   $10(a0), d6
F01B06  53 46                   subq.w   #$1, d6
F01B08  dc 75 50 00             add.w    (a5, d5.w), d6
F01B0C  3b 86 50 02             move.w   d6, $2(a5, d5.w)
F01B10  53 68 00 0a             subq.w   #$1, $a(a0)
F01B14  42 86                   clr.l    d6
F01B16  3c 28 00 0a             move.w   $a(a0), d6
F01B1A  08 04 00 0b             btst.b   #$b, d4
F01B1E  67 08                   beq.b    loc_F01B28
F01B20  08 86 00 0f             bclr.b   #$f, d6
F01B24  31 46 00 0a             move.w   d6, $a(a0)

loc_F01B28:
F01B28  4a 46                   tst.w    d6
F01B2A  66 2e                   bne.b    loc_F01B5A

loc_F01B2C:
F01B2C  30 35 50 24             move.w   $24(a5, d5.w), d0
F01B30  02 40 0c 00             andi.w   #$c00, d0
F01B34  66 24                   bne.b    loc_F01B5A
F01B36  42 80                   clr.l    d0
F01B38  30 35 50 00             move.w   (a5, d5.w), d0
F01B3C  d0 75 50 04             add.w    $4(a5, d5.w), d0
F01B40  e1 88                   lsl.l    #$8, d0
F01B42  42 81                   clr.l    d1
F01B44  32 35 50 02             move.w   $2(a5, d5.w), d1
F01B48  92 75 50 00             sub.w    (a5, d5.w), d1
F01B4C  52 81                   addq.l   #$1, d1
F01B4E  20 40                   movea.l  d0, a0
F01B50  61 00 f9 42             bsr.w    loc_F01494
F01B54  60 04                   bra.b    loc_F01B5A
F01B56  61 00                   DC.W     0x6100
F01B58  e6 2e                   DC.W     0xe62e

loc_F01B5A:
F01B5A  42 b5 50 20             clr.l    $20(a5, d5.w)
F01B5E  42 75 50 24             clr.w    $24(a5, d5.w)
F01B62  42 35 50 27             clr.b    $27(a5, d5.w)
F01B66  42 75 50 06             clr.w    $6(a5, d5.w)
F01B6A  53 2d 00 05             subq.b   #$1, $5(a5)

loc_F01B6E:
F01B6E  4e 73                   rte      

loc_F01B70:
F01B70  40 e7                   move.w   sr, -(a7)
F01B72  4a ac 00 36             tst.l    $36(a4)
F01B76  67 1c                   beq.b    loc_F01B94
F01B78  2a 6c 00 36             movea.l  $36(a4), a5
F01B7C  42 85                   clr.l    d5
F01B7E  3a 2d 00 08             move.w   $8(a5), d5

loc_F01B82:
F01B82  08 35 00 0f 50 24       btst.b   #$f, $24(a5, d5.w)
F01B88  67 02                   beq.b    loc_F01B8C
F01B8A  61 62                   bsr.b    loc_F01BEE

loc_F01B8C:
F01B8C  51 85                   subq.l   #$8, d5
F01B8E  0c 45 00 0c             cmpi.w   #$c, d5
F01B92  6c ee                   bge.b    loc_F01B82

loc_F01B94:
F01B94  08 2c 00 02 00 29       btst.b   #$2, $29(a4)
F01B9A  67 50                   beq.b    loc_F01BEC
F01B9C  22 78 0c 20             movea.l  $c20.w, a1
F01BA0  4b e9 00 14             lea.l    $14(a1), a5
F01BA4  3e 29 00 0e             move.w   $e(a1), d7
F01BA8  67 42                   beq.b    loc_F01BEC
F01BAA  2c 2c 00 14             move.l   $14(a4), d6

loc_F01BAE:
F01BAE  4a 6d 00 0a             tst.w    $a(a5)
F01BB2  67 2e                   beq.b    loc_F01BE2
F01BB4  bc 95                   cmp.l    (a5), d6
F01BB6  66 2a                   bne.b    loc_F01BE2
F01BB8  08 ad 00 0f 00 0a       bclr.b   #$f, $a(a5)
F01BBE  4a 6d 00 0a             tst.w    $a(a5)
F01BC2  66 1e                   bne.b    loc_F01BE2
F01BC4  30 2d 00 08             move.w   $8(a5), d0
F01BC8  02 40 0c 00             andi.w   #$c00, d0
F01BCC  66 14                   bne.b    loc_F01BE2
F01BCE  42 81                   clr.l    d1
F01BD0  32 2d 00 10             move.w   $10(a5), d1
F01BD4  20 6d 00 0c             movea.l  $c(a5), a0
F01BD8  61 00 f8 ba             bsr.w    loc_F01494
F01BDC  60 04                   bra.b    loc_F01BE2
F01BDE  61 00                   DC.W     0x6100
F01BE0  e5 a6                   DC.W     0xe5a6

loc_F01BE2:
F01BE2  db fc 00 00 00 12       adda.l   #$12, a5
F01BE8  53 47                   subq.w   #$1, d7
F01BEA  66 c2                   bne.b    loc_F01BAE

loc_F01BEC:
F01BEC  4e 73                   rte      

loc_F01BEE:
F01BEE  42 84                   clr.l    d4
F01BF0  08 2c 00 02 00 29       btst.b   #$2, $29(a4)
F01BF6  67 04                   beq.b    loc_F01BFC
F01BF8  08 c4 00 0b             bset.b   #$b, d4

loc_F01BFC:
F01BFC  40 e7                   move.w   sr, -(a7)
F01BFE  60 00 fe e2             bra.w    loc_F01AE2
F01C02  26 4d                   DC.W     0x264d  ; '&M'
F01C04  42 b8                   DC.W     0x42b8
F01C06  0c 62                   DC.W     0x0c62
F01C08  2a 6e                   DC.W     0x2a6e  ; '*n'
F01C0A  00 36                   DC.W     0x0036
F01C0C  2e 2c                   DC.W     0x2e2c  ; '.,'
F01C0E  00 0c                   DC.W     0x000c
F01C10  41 d5                   DC.W     0x41d5
F01C12  61 00                   DC.W     0x6100
F01C14  fb b0                   DC.W     0xfbb0
F01C16  60 08                   DC.W     0x6008
F01C18  5e 6e                   DC.W     0x5e6e  ; '^n'
F01C1A  01 02                   DC.W     0x0102

loc_F01C1C:
F01C1C  60 00 01 52             bra.w    loc_F01D70
F01C20  4a ae 00 40             tst.l    $40(a6)
F01C24  67 20                   beq.b    loc_F01C46
F01C26  20 2e 01 3c             move.l   $13c(a6), d0
F01C2A  e0 48                   lsr.w    #$8, d0
F01C2C  b0 75 50 00             cmp.w    (a5, d5.w), d0
F01C30  65 14                   bcs.b    loc_F01C46
F01C32  b0 75 50 02             cmp.w    $2(a5, d5.w), d0
F01C36  62 0e                   bhi.b    loc_F01C46
F01C38  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F01C3E  60 dc                   bra.b    loc_F01C1C

loc_F01C40:
F01C40  56 6e 01 02             addq.w   #$3, $102(a6)
F01C44  60 d6                   bra.b    loc_F01C1C

loc_F01C46:
F01C46  b7 ce                   cmpa.l   a6, a3
F01C48  67 f6                   beq.b    loc_F01C40
F01C4A  22 45                   movea.l  d5, a1
F01C4C  24 46                   movea.l  d6, a2
F01C4E  2e 2a 00 0c             move.l   $c(a2), d7
F01C52  20 6b 00 36             movea.l  $36(a3), a0
F01C56  61 00 fb 6c             bsr.w    loc_F017C4
F01C5A  60 0c                   bra.b    loc_F01C68
F01C5C  4a 85                   DC.W     0x4a85
F01C5E  66 0e                   DC.W     0x660e
F01C60  5a 6e                   DC.W     0x5a6e  ; 'Zn'
F01C62  01 02                   DC.W     0x0102

loc_F01C64:
F01C64  60 00 01 0a             bra.w    loc_F01D70

loc_F01C68:
F01C68  5c 6e 01 02             addq.w   #$6, $102(a6)
F01C6C  60 f6                   bra.b    loc_F01C64
F01C6E  2a 09                   move.l   a1, d5
F01C70  2c 2a 00 10             move.l   $10(a2), d6
F01C74  08 2a 00 0e 00 08       btst.b   #$e, $8(a2)
F01C7A  66 14                   bne.b    loc_F01C90
F01C7C  42 86                   clr.l    d6
F01C7E  3c 35 50 00             move.w   (a5, d5.w), d6
F01C82  08 2a 00 0d 00 08       btst.b   #$d, $8(a2)
F01C88  67 04                   beq.b    loc_F01C8E
F01C8A  dc 75 50 04             add.w    $4(a5, d5.w), d6

loc_F01C8E:
F01C8E  e1 8e                   lsl.l    #$8, d6

loc_F01C90:
F01C90  42 80                   clr.l    d0
F01C92  30 35 50 02             move.w   $2(a5, d5.w), d0
F01C96  90 75 50 00             sub.w    (a5, d5.w), d0
F01C9A  24 00                   move.l   d0, d2
F01C9C  52 40                   addq.w   #$1, d0
F01C9E  2a 00                   move.l   d0, d5
F01CA0  e1 8d                   lsl.l    #$8, d5
F01CA2  61 00 fa b8             bsr.w    loc_F0175C
F01CA6  60 0a                   bra.b    loc_F01CB2
F01CA8  60 08                   DC.W     0x6008
F01CAA  4a 85                   DC.W     0x4a85
F01CAC  66 0c                   DC.W     0x660c
F01CAE  61 00                   DC.W     0x6100
F01CB0  e4 d6                   DC.W     0xe4d6

loc_F01CB2:
F01CB2  06 6e 00 0b 01 02       addi.w   #$b, $102(a6)
F01CB8  60 aa                   bra.b    loc_F01C64
F01CBA  4a 30 50 07             tst.b    $7(a0, d5.w)
F01CBE  66 f2                   bne.b    loc_F01CB2
F01CC0  22 06                   move.l   d6, d1
F01CC2  28 09                   move.l   a1, d4
F01CC4  e0 89                   lsr.l    #$8, d1
F01CC6  d4 41                   add.w    d1, d2
F01CC8  31 81 50 00             move.w   d1, (a0, d5.w)
F01CCC  31 82 50 02             move.w   d2, $2(a0, d5.w)
F01CD0  92 75 40 00             sub.w    (a5, d4.w), d1
F01CD4  44 41                   neg.w    d1
F01CD6  d2 75 40 04             add.w    $4(a5, d4.w), d1
F01CDA  31 81 50 04             move.w   d1, $4(a0, d5.w)
F01CDE  21 b5 40 20 50 20       move.l   $20(a5, d4.w), $20(a0, d5.w)
F01CE4  31 b5 40 26 50 26       move.w   $26(a5, d4.w), $26(a0, d5.w)
F01CEA  36 35 40 24             move.w   $24(a5, d4.w), d3
F01CEE  08 2a 00 0f 00 08       btst.b   #$f, $8(a2)
F01CF4  67 10                   beq.b    loc_F01D06
F01CF6  08 83 00 0e             bclr.b   #$e, d3
F01CFA  08 2a 00 0e 00 0a       btst.b   #$e, $a(a2)
F01D00  67 04                   beq.b    loc_F01D06
F01D02  08 c3 00 0e             bset.b   #$e, d3

loc_F01D06:
F01D06  08 c3 00 0f             bset.b   #$f, d3
F01D0A  31 83 50 24             move.w   d3, $24(a0, d5.w)
F01D0E  31 bc 00 01 50 06       move.w   #$1, $6(a0, d5.w)
F01D14  08 03 00 0e             btst.b   #$e, d3
F01D18  67 06                   beq.b    loc_F01D20
F01D1A  31 bc 00 03 50 06       move.w   #$3, $6(a0, d5.w)

loc_F01D20:
F01D20  42 b5 40 20             clr.l    $20(a5, d4.w)
F01D24  42 b5 40 24             clr.l    $24(a5, d4.w)
F01D28  42 b5 40 00             clr.l    (a5, d4.w)
F01D2C  42 b5 40 04             clr.l    $4(a5, d4.w)
F01D30  53 2d 00 05             subq.b   #$1, $5(a5)
F01D34  52 28 00 05             addq.b   #$1, $5(a0)
F01D38  32 30 50 00             move.w   (a0, d5.w), d1
F01D3C  d2 70 50 04             add.w    $4(a0, d5.w), d1
F01D40  e1 89                   lsl.l    #$8, d1
F01D42  2d 41 01 20             move.l   d1, $120(a6)
F01D46  08 03 00 0d             btst.b   #$d, d3
F01D4A  67 24                   beq.b    loc_F01D70
F01D4C  24 2e 00 14             move.l   $14(a6), d2
F01D50  b4 ab 00 14             cmp.l    $14(a3), d2
F01D54  67 1a                   beq.b    loc_F01D70
F01D56  20 70 50 20             movea.l  $20(a0, d5.w), a0
F01D5A  22 03                   move.l   d3, d1
F01D5C  28 4b                   movea.l  a3, a4
F01D5E  61 00 fa 94             bsr.w    loc_F017F4
F01D62  60 04                   bra.b    loc_F01D68
F01D64  61 00                   DC.W     0x6100
F01D66  e4 20                   DC.W     0xe420

loc_F01D68:
F01D68  26 4c                   movea.l  a4, a3
F01D6A  24 2b 00 14             move.l   $14(a3), d2
F01D6E  20 82                   move.l   d2, (a0)

loc_F01D70:
F01D70  4e 73                   rte      
F01D72  2a 4e                   DC.W     0x2a4e  ; '*N'
F01D74  42 b8                   DC.W     0x42b8
F01D76  0c 62                   DC.W     0x0c62
F01D78  60 0c                   DC.W     0x600c
F01D7A  bb ce                   DC.W     0xbbce
F01D7C  66 08                   DC.W     0x6608
F01D7E  06 6e                   DC.W     0x066e
F01D80  00 09                   DC.W     0x0009
F01D82  01 02                   DC.W     0x0102
F01D84  4e 73                   DC.W     0x4e73  ; 'Ns'
F01D86  24 2d 00 14             move.l   $14(a5), d2
F01D8A  32 2c 00 0a             move.w   $a(a4), d1
F01D8E  20 6c 00 0c             movea.l  $c(a4), a0
F01D92  61 00 fa 60             bsr.w    loc_F017F4
F01D96  60 1e                   bra.b    loc_F01DB6
F01D98  5e 6e                   DC.W     0x5e6e  ; '^n'
F01D9A  01 02                   DC.W     0x0102
F01D9C  60 00                   DC.W     0x6000
F01D9E  00 dc                   DC.W     0x00dc
F01DA0  5a 6e 01 02             addq.w   #$5, $102(a6)

loc_F01DA4:
F01DA4  60 00 00 d4             bra.w    loc_F01E7A

loc_F01DA8:
F01DA8  06 6e 00 0b 01 02       addi.w   #$b, $102(a6)
F01DAE  60 f4                   bra.b    loc_F01DA4

loc_F01DB0:
F01DB0  5c 6e 01 02             addq.w   #$6, $102(a6)
F01DB4  60 ee                   bra.b    loc_F01DA4

loc_F01DB6:
F01DB6  26 48                   movea.l  a0, a3
F01DB8  24 6d 00 36             movea.l  $36(a5), a2
F01DBC  2e 2b 00 04             move.l   $4(a3), d7
F01DC0  41 d2                   lea.l    (a2), a0
F01DC2  61 00 fa 00             bsr.w    loc_F017C4
F01DC6  60 e8                   bra.b    loc_F01DB0
F01DC8  4a 85                   DC.W     0x4a85
F01DCA  67 d4                   DC.W     0x67d4
F01DCC  42 85                   DC.W     0x4285
F01DCE  3a 2b                   DC.W     0x3a2b  ; ':+'
F01DD0  00 10                   DC.W     0x0010
F01DD2  e1 8d                   DC.W     0xe18d
F01DD4  08 2c                   DC.W     0x082c
F01DD6  00 0a                   DC.W     0x000a
F01DD8  00 08                   DC.W     0x0008
F01DDA  67 1c                   DC.W     0x671c
F01DDC  ba ac                   DC.W     0xbaac
F01DDE  00 14                   DC.W     0x0014
F01DE0  64 0a                   DC.W     0x640a
F01DE2  06 6e                   DC.W     0x066e
F01DE4  00 10                   DC.W     0x0010
F01DE6  01 02                   DC.W     0x0102
F01DE8  60 00                   DC.W     0x6000
F01DEA  00 90                   DC.W     0x0090
F01DEC  2a 2c 00 14             move.l   $14(a4), d5
F01DF0  06 85 00 00 00 ff       addi.l   #$ff, d5
F01DF6  42 05                   clr.b    d5
F01DF8  24 05                   move.l   d5, d2
F01DFA  2c 2c 00 10             move.l   $10(a4), d6
F01DFE  42 06                   clr.b    d6
F01E00  08 2c 00 0d 00 08       btst.b   #$d, $8(a4)
F01E06  67 04                   beq.b    loc_F01E0C
F01E08  2c 2b 00 0c             move.l   $c(a3), d6

loc_F01E0C:
F01E0C  41 d2                   lea.l    (a2), a0
F01E0E  61 00 f9 4c             bsr.w    loc_F0175C
F01E12  60 94                   bra.b    loc_F01DA8
F01E14  60 92                   DC.W     0x6092
F01E16  4a 85                   DC.W     0x4a85
F01E18  66 04                   DC.W     0x6604
F01E1A  61 00                   DC.W     0x6100
F01E1C  e3 6a                   DC.W     0xe36a
F01E1E  4a 30 50 07             tst.b    $7(a0, d5.w)
F01E22  66 84                   bne.b    loc_F01DA8
F01E24  25 ab 00 04 50 20       move.l   $4(a3), $20(a2, d5.w)
F01E2A  42 32 50 27             clr.b    $27(a2, d5.w)
F01E2E  20 06                   move.l   d6, d0
F01E30  e0 8e                   lsr.l    #$8, d6
F01E32  35 86 50 00             move.w   d6, (a2, d5.w)
F01E36  e0 8a                   lsr.l    #$8, d2
F01E38  dc 42                   add.w    d2, d6
F01E3A  53 46                   subq.w   #$1, d6
F01E3C  35 86 50 02             move.w   d6, $2(a2, d5.w)
F01E40  44 80                   neg.l    d0
F01E42  d0 ab 00 0c             add.l    $c(a3), d0
F01E46  e0 88                   lsr.l    #$8, d0
F01E48  35 80 50 04             move.w   d0, $4(a2, d5.w)
F01E4C  35 bc 00 01 50 06       move.w   #$1, $6(a2, d5.w)
F01E52  08 2b 00 0e 00 08       btst.b   #$e, $8(a3)
F01E58  67 06                   beq.b    loc_F01E60
F01E5A  35 bc 00 03 50 06       move.w   #$3, $6(a2, d5.w)

loc_F01E60:
F01E60  35 ab 00 08 50 24       move.w   $8(a3), $24(a2, d5.w)
F01E66  08 f2 00 0f 50 24       bset.b   #$f, $24(a2, d5.w)
F01E6C  52 2a 00 05             addq.b   #$1, $5(a2)
F01E70  52 6b 00 0a             addq.w   #$1, $a(a3)
F01E74  2d 6b 00 0c 01 20       move.l   $c(a3), $120(a6)

loc_F01E7A:
F01E7A  4e 73                   rte      
F01E7C  2c 2c                   DC.W     0x2c2c  ; ',,'
F01E7E  00 08                   DC.W     0x0008
F01E80  60 2a 22 2d             DC.B     "`*\"-"  ; 4 bytes
F01E84  00 36                   DC.W     0x0036
F01E86  67 1c                   DC.W     0x671c
F01E88  2a 2c                   DC.W     0x2a2c  ; '*,'
F01E8A  00 18                   DC.W     0x0018
F01E8C  2c 2c                   DC.W     0x2c2c  ; ',,'
F01E8E  00 08                   DC.W     0x0008
F01E90  20 41                   DC.W     0x2041  ; ' A'
F01E92  61 00                   DC.W     0x6100
F01E94  f8 c4                   DC.W     0xf8c4
F01E96  60 14                   DC.W     0x6014
F01E98  60 0a                   DC.W     0x600a
F01E9A  4a 85                   DC.W     0x4a85
F01E9C  67 06                   DC.W     0x6706
F01E9E  4a 30                   DC.W     0x4a30  ; 'J0'
F01EA0  50 07                   DC.W     0x5007
F01EA2  66 08                   DC.W     0x6608

loc_F01EA4:
F01EA4  06 6e 00 0c 01 02       addi.w   #$c, $102(a6)
F01EAA  4e 73                   rte      
F01EAC  2e 06                   move.l   d6, d7
F01EAE  41 ec 00 0c             lea.l    $c(a4), a0
F01EB2  61 00 f8 5a             bsr.w    loc_F0170E
F01EB6  60 06                   bra.b    loc_F01EBE
F01EB8  5e 6e                   DC.W     0x5e6e  ; '^n'
F01EBA  01 02                   DC.W     0x0102
F01EBC  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F01EBE:
F01EBE  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F01EC4  66 10                   bne.b    loc_F01ED6
F01EC6  08 28 00 0f 00 28       btst.b   #$f, $28(a0)
F01ECC  67 08                   beq.b    loc_F01ED6
F01ECE  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F01ED4  4e 73                   rte      

loc_F01ED6:
F01ED6  22 28 00 36             move.l   $36(a0), d1
F01EDA  67 1c                   beq.b    loc_F01EF8
F01EDC  2a 2c 00 18             move.l   $18(a4), d5
F01EE0  2c 2c 00 14             move.l   $14(a4), d6
F01EE4  20 41                   movea.l  d1, a0
F01EE6  61 00 f8 70             bsr.w    loc_F01758
F01EEA  60 14                   bra.b    loc_F01F00
F01EEC  60 0a                   DC.W     0x600a
F01EEE  4a 85                   DC.W     0x4a85
F01EF0  67 06                   DC.W     0x6706
F01EF2  4a 30                   DC.W     0x4a30  ; 'J0'
F01EF4  50 07                   DC.W     0x5007
F01EF6  66 08                   DC.W     0x6608

loc_F01EF8:
F01EF8  06 6e 00 0d 01 02       addi.w   #$d, $102(a6)
F01EFE  4e 73                   rte      

loc_F01F00:
F01F00  48 7a ff a2             pea.l    loc_F01EA4(pc)
F01F04  3f 3c 42 45             move.w   #$4245, -(a7)
F01F08  24 47                   movea.l  d7, a2
F01F0A  26 46                   movea.l  d6, a3
F01F0C  26 2c 00 18             move.l   $18(a4), d3
F01F10  de 86                   add.l    d6, d7
F01F12  08 07 00 00             btst.b   #$0, d7
F01F16  67 08                   beq.b    loc_F01F20
F01F18  06 6e 00 0b 01 02       addi.w   #$b, $102(a6)
F01F1E  60 26                   bra.b    loc_F01F46

loc_F01F20:
F01F20  08 06 00 00             btst.b   #$0, d6
F01F24  67 06                   beq.b    loc_F01F2C
F01F26  16 da                   move.b   (a2)+, (a3)+
F01F28  53 83                   subq.l   #$1, d3
F01F2A  67 1a                   beq.b    loc_F01F46

loc_F01F2C:
F01F2C  28 03                   move.l   d3, d4
F01F2E  e4 8b                   lsr.l    #$2, d3
F01F30  60 02                   bra.b    loc_F01F34

loc_F01F32:
F01F32  26 da                   move.l   (a2)+, (a3)+

loc_F01F34:
F01F34  51 cb ff fc             dbra     d3, loc_F01F32
F01F38  02 84 00 00 00 03       andi.l   #$3, d4
F01F3E  60 02                   bra.b    loc_F01F42

loc_F01F40:
F01F40  16 da                   move.b   (a2)+, (a3)+

loc_F01F42:
F01F42  51 cc ff fc             dbra     d4, loc_F01F40

loc_F01F46:
F01F46  5c 8f                   addq.l   #$6, a7
F01F48  4e 73                   rte      
F01F4A  2a 6e                   DC.W     0x2a6e  ; '*n'
F01F4C  00 36                   DC.W     0x0036
F01F4E  2e 2c                   DC.W     0x2e2c  ; '.,'
F01F50  00 0c                   DC.W     0x000c
F01F52  41 d5                   DC.W     0x41d5
F01F54  61 00                   DC.W     0x6100
F01F56  f8 6e                   DC.W     0xf86e
F01F58  60 08                   DC.W     0x6008
F01F5A  5e 6e                   DC.W     0x5e6e  ; '^n'
F01F5C  01 02                   DC.W     0x0102

loc_F01F5E:
F01F5E  60 00 00 d2             bra.w    loc_F02032
F01F62  3c 35 50 24             move.w   $24(a5, d5.w), d6
F01F66  30 06                   move.w   d6, d0
F01F68  02 40 30 00             andi.w   #$3000, d0
F01F6C  66 32                   bne.b    loc_F01FA0
F01F6E  32 2c 00 0a             move.w   $a(a4), d1
F01F72  02 41 30 00             andi.w   #$3000, d1
F01F76  67 20                   beq.b    loc_F01F98
F01F78  8c 41                   or.w     d1, d6
F01F7A  08 01 00 0c             btst.b   #$c, d1
F01F7E  67 26                   beq.b    loc_F01FA6
F01F80  08 01 00 0d             btst.b   #$d, d1
F01F84  66 12                   bne.b    loc_F01F98
F01F86  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F01F8C  66 18                   bne.b    loc_F01FA6
F01F8E  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F01F94  60 00 00 9c             bra.w    loc_F02032

loc_F01F98:
F01F98  06 6e 00 0f 01 02       addi.w   #$f, $102(a6)
F01F9E  60 be                   bra.b    loc_F01F5E

loc_F01FA0:
F01FA0  5c 6e 01 02             addq.w   #$6, $102(a6)
F01FA4  60 b8                   bra.b    loc_F01F5E

loc_F01FA6:
F01FA6  08 2c 00 0f 00 08       btst.b   #$f, $8(a4)
F01FAC  67 10                   beq.b    loc_F01FBE
F01FAE  08 86 00 0e             bclr.b   #$e, d6
F01FB2  08 2c 00 0e 00 0a       btst.b   #$e, $a(a4)
F01FB8  67 04                   beq.b    loc_F01FBE
F01FBA  08 c6 00 0e             bset.b   #$e, d6

loc_F01FBE:
F01FBE  22 06                   move.l   d6, d1
F01FC0  08 81 00 0f             bclr.b   #$f, d1
F01FC4  24 2e 00 14             move.l   $14(a6), d2
F01FC8  20 75 50 20             movea.l  $20(a5, d5.w), a0
F01FCC  61 00 f8 26             bsr.w    loc_F017F4
F01FD0  60 0e                   bra.b    loc_F01FE0
F01FD2  b1 fc                   DC.W     0xb1fc
F01FD4  00 00                   DC.W     0x0000
F01FD6  00 00                   DC.W     0x0000
F01FD8  66 0c                   DC.W     0x660c
F01FDA  5a 6e                   DC.W     0x5a6e  ; 'Zn'
F01FDC  01 02                   DC.W     0x0102
F01FDE  60 52                   DC.W     0x6052  ; '`R'

loc_F01FE0:
F01FE0  5c 6e 01 02             addq.w   #$6, $102(a6)
F01FE4  60 4c                   bra.b    loc_F02032
F01FE6  8d 75 50 24             or.w     d6, $24(a5, d5.w)
F01FEA  21 75 50 20 00 04       move.l   $20(a5, d5.w), $4(a0)
F01FF0  20 82                   move.l   d2, (a0)
F01FF2  31 41 00 08             move.w   d1, $8(a0)
F01FF6  31 7c 00 01 00 0a       move.w   #$1, $a(a0)
F01FFC  42 83                   clr.l    d3
F01FFE  36 35 50 00             move.w   (a5, d5.w), d3
F02002  d6 75 50 04             add.w    $4(a5, d5.w), d3
F02006  e1 8b                   lsl.l    #$8, d3
F02008  21 43 00 0c             move.l   d3, $c(a0)
F0200C  36 35 50 02             move.w   $2(a5, d5.w), d3
F02010  96 75 50 00             sub.w    (a5, d5.w), d3
F02014  52 43                   addq.w   #$1, d3
F02016  31 43 00 10             move.w   d3, $10(a0)
F0201A  33 40 00 0e             move.w   d0, $e(a1)
F0201E  31 7c 00 01 00 0a       move.w   #$1, $a(a0)
F02024  08 2c 00 0c 00 08       btst.b   #$c, $8(a4)
F0202A  67 06                   beq.b    loc_F02032
F0202C  08 e8 00 0f 00 0a       bset.b   #$f, $a(a0)

loc_F02032:
F02032  4e 73                   rte      
F02034  3e 2c                   DC.W     0x3e2c  ; '>,'
F02036  00 08                   DC.W     0x0008
F02038  08 07                   DC.W     0x0807
F0203A  00 0d                   DC.W     0x000d
F0203C  66 1c                   DC.W     0x661c
F0203E  7a 12                   DC.W     0x7a12
F02040  2c 2c                   DC.W     0x2c2c  ; ',,'
F02042  00 18                   DC.W     0x0018
F02044  20 6e                   DC.W     0x206e  ; ' n'
F02046  00 36                   DC.W     0x0036
F02048  61 00                   DC.W     0x6100
F0204A  f7 12                   DC.W     0xf712
F0204C  60 0a                   DC.W     0x600a
F0204E  4e 71                   DC.W     0x4e71  ; 'Nq'
F02050  06 6e                   DC.W     0x066e
F02052  00 0c                   DC.W     0x000c
F02054  01 02                   DC.W     0x0102
F02056  4e 73                   DC.W     0x4e73  ; 'Ns'
F02058  24 46                   movea.l  d6, a2
F0205A  08 2c 00 0e 00 08       btst.b   #$e, $8(a4)
F02060  67 22                   beq.b    loc_F02084
F02062  7a 04                   moveq    #$4, d5
F02064  2c 2c 00 10             move.l   $10(a4), d6
F02068  20 6d 00 36             movea.l  $36(a5), a0
F0206C  61 00 f6 ee             bsr.w    loc_F0175C
F02070  60 22                   bra.b    loc_F02094
F02072  60 0a                   DC.W     0x600a
F02074  4a 45                   DC.W     0x4a45  ; 'JE'
F02076  67 06                   DC.W     0x6706
F02078  4a 30                   DC.W     0x4a30  ; 'J0'
F0207A  d0 07                   DC.W     0xd007
F0207C  66 16                   DC.W     0x6616
F0207E  5e 6e 01 02             addq.w   #$7, $102(a6)
F02082  4e 73                   rte      

loc_F02084:
F02084  2e 2c 00 0c             move.l   $c(a4), d7
F02088  20 6d 00 36             movea.l  $36(a5), a0
F0208C  61 00 f7 36             bsr.w    loc_F017C4
F02090  60 02                   bra.b    loc_F02094
F02092  60 ea                   DC.W     0x60ea

loc_F02094:
F02094  42 80                   clr.l    d0
F02096  30 30 50 00             move.w   (a0, d5.w), d0
F0209A  08 2c 00 0d 00 08       btst.b   #$d, $8(a4)
F020A0  66 38                   bne.b    loc_F020DA
F020A2  d0 70 50 04             add.w    $4(a0, d5.w), d0
F020A6  e1 88                   lsl.l    #$8, d0
F020A8  25 40 00 0e             move.l   d0, $e(a2)
F020AC  42 80                   clr.l    d0
F020AE  24 b0 50 20             move.l   $20(a0, d5.w), (a2)
F020B2  35 70 50 24 00 04       move.w   $24(a0, d5.w), $4(a2)
F020B8  08 aa 00 0f 00 04       bclr.b   #$f, $4(a2)
F020BE  30 30 50 00             move.w   (a0, d5.w), d0
F020C2  e1 88                   lsl.l    #$8, d0
F020C4  25 40 00 06             move.l   d0, $6(a2)
F020C8  42 80                   clr.l    d0
F020CA  30 30 50 02             move.w   $2(a0, d5.w), d0
F020CE  e1 88                   lsl.l    #$8, d0
F020D0  06 00 00 ff             addi.b   #$ff, d0
F020D4  25 40 00 0a             move.l   d0, $a(a2)
F020D8  4e 73                   rte      

loc_F020DA:
F020DA  e1 88                   lsl.l    #$8, d0
F020DC  2d 40 01 20             move.l   d0, $120(a6)
F020E0  4e 73                   rte      
F020E2  22 78                   DC.W     0x2278  ; '"x'
F020E4  0c 66                   DC.W     0x0c66
F020E6  24 78                   DC.W     0x2478  ; '$x'
F020E8  0c 6a                   DC.W     0x0c6a
F020EA  42 87                   DC.W     0x4287
F020EC  42 82                   DC.W     0x4282
F020EE  14 2c                   DC.W     0x142c
F020F0  00 0b                   DC.W     0x000b
F020F2  4a 6c                   DC.W     0x4a6c  ; 'Jl'
F020F4  00 08                   DC.W     0x0008
F020F6  66 00                   DC.W     0x6600
F020F8  00 84                   DC.W     0x0084
F020FA  4a 31                   DC.W     0x4a31  ; 'J1'
F020FC  20 00                   DC.W     0x2000
F020FE  67 06                   DC.W     0x6706
F02100  5c 6e                   DC.W     0x5c6e  ; '\n'
F02102  01 02                   DC.W     0x0102
F02104  4e 73                   DC.W     0x4e73  ; 'Ns'
F02106  7e 08                   moveq    #$8, d7

loc_F02108:
F02108  47 f2 70 00             lea.l    (a2, d7.w), a3
F0210C  b7 ea 00 04             cmpa.l   $4(a2), a3
F02110  6d 06                   blt.b    loc_F02118
F02112  5a 6e 01 02             addq.w   #$5, $102(a6)
F02116  4e 73                   rte      

loc_F02118:
F02118  4a ab 00 08             tst.l    $8(a3)
F0211C  67 08                   beq.b    loc_F02126
F0211E  06 87 00 00 00 14       addi.l   #$14, d7
F02124  60 e2                   bra.b    loc_F02108

loc_F02126:
F02126  36 fc 4e b9             move.w   #$4eb9, (a3)+
F0212A  41 fa e7 ce             lea.l    loc_F008FA(pc), a0
F0212E  26 c8                   move.l   a0, (a3)+

loc_F02130:
F02130  7a 04                   moveq    #$4, d5
F02132  2c 2c 00 0c             move.l   $c(a4), d6
F02136  20 6d 00 36             movea.l  $36(a5), a0
F0213A  61 00 f6 20             bsr.w    loc_F0175C
F0213E  60 0a                   bra.b    loc_F0214A
F02140  4e 71                   DC.W     0x4e71  ; 'Nq'
F02142  06 6e                   DC.W     0x066e
F02144  00 0c                   DC.W     0x000c
F02146  01 02                   DC.W     0x0102
F02148  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F0214A:
F0214A  36 82                   move.w   d2, (a3)
F0214C  27 4d 00 02             move.l   a5, $2(a3)
F02150  27 6c 00 0c 00 06       move.l   $c(a4), $6(a3)
F02156  27 6c 00 10 00 0a       move.l   $10(a4), $a(a3)
F0215C  06 87 00 00 00 0c       addi.l   #$c, d7
F02162  8e fc 00 14             divu.w   #$14, d7
F02166  13 87 20 00             move.b   d7, (a1, d2.w)
F0216A  08 ed 00 00 00 29       bset.b   #$0, $29(a5)
F02170  47 eb ff fa             lea.l    -$6(a3), a3
F02174  e5 8a                   lsl.l    #$2, d2
F02176  20 42                   movea.l  d2, a0
F02178  20 8b                   move.l   a3, (a0)
F0217A  4e 73                   rte      
F0217C  1e 31 20 00             move.b   (a1, d2.w), d7
F02180  67 22                   beq.b    loc_F021A4
F02182  53 87                   subq.l   #$1, d7
F02184  ce fc 00 14             mulu.w   #$14, d7
F02188  50 87                   addq.l   #$8, d7
F0218A  47 f2 70 00             lea.l    (a2, d7.w), a3
F0218E  20 6b 00 08             movea.l  $8(a3), a0
F02192  20 28 00 14             move.l   $14(a0), d0
F02196  b0 ae 00 14             cmp.l    $14(a6), d0
F0219A  67 10                   beq.b    loc_F021AC
F0219C  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F021A2  66 08                   bne.b    loc_F021AC

loc_F021A4:
F021A4  3d 7c 00 07 01 02       move.w   #$7, $102(a6)
F021AA  4e 73                   rte      

loc_F021AC:
F021AC  47 eb 00 06             lea.l    $6(a3), a3
F021B0  08 2c 00 06 00 08       btst.b   #$6, $8(a4)
F021B6  66 00 ff 78             bne.w    loc_F02130
F021BA  08 2c 00 05 00 08       btst.b   #$5, $8(a4)
F021C0  66 08                   bne.b    loc_F021CA
F021C2  3d 7c 00 0f 01 02       move.w   #$f, $102(a6)
F021C8  4e 73                   rte      

loc_F021CA:
F021CA  61 32                   bsr.b    loc_F021FE
F021CC  4e 73                   rte      

loc_F021CE:
F021CE  40 e7                   move.w   sr, -(a7)
F021D0  22 78 0c 66             movea.l  $c66.w, a1
F021D4  24 78 0c 6a             movea.l  $c6a.w, a2
F021D8  7e 08                   moveq    #$8, d7

loc_F021DA:
F021DA  47 f2 70 00             lea.l    (a2, d7.w), a3
F021DE  b7 ea 00 04             cmpa.l   $4(a2), a3
F021E2  6c 18                   bge.b    loc_F021FC
F021E4  b9 eb 00 08             cmpa.l   $8(a3), a4
F021E8  66 0a                   bne.b    loc_F021F4
F021EA  47 eb 00 06             lea.l    $6(a3), a3
F021EE  42 82                   clr.l    d2
F021F0  34 13                   move.w   (a3), d2
F021F2  61 0a                   bsr.b    loc_F021FE

loc_F021F4:
F021F4  06 87 00 00 00 14       addi.l   #$14, d7
F021FA  60 de                   bra.b    loc_F021DA

loc_F021FC:
F021FC  4e 73                   rte      

loc_F021FE:
F021FE  41 fa e6 96             lea.l    loc_F00896(pc), a0
F02202  26 08                   move.l   a0, d3
F02204  e5 8a                   lsl.l    #$2, d2
F02206  20 42                   movea.l  d2, a0
F02208  20 83                   move.l   d3, (a0)
F0220A  e4 8a                   lsr.l    #$2, d2
F0220C  42 31 20 00             clr.b    (a1, d2.w)
F02210  42 ab 00 02             clr.l    $2(a3)
F02214  4e 75                   rts      
F02216  22 78                   DC.W     0x2278  ; '"x'
F02218  0c 66                   DC.W     0x0c66
F0221A  24 78                   DC.W     0x2478  ; '$x'
F0221C  0c 6e                   DC.W     0x0c6e
F0221E  42 87                   DC.W     0x4287
F02220  42 82                   DC.W     0x4282
F02222  14 2c                   DC.W     0x142c
F02224  00 0b                   DC.W     0x000b
F02226  4a 31                   DC.W     0x4a31  ; 'J1'
F02228  20 00                   DC.W     0x2000
F0222A  67 06                   DC.W     0x6706
F0222C  5c 6e                   DC.W     0x5c6e  ; '\n'
F0222E  01 02                   DC.W     0x0102
F02230  4e 73                   DC.W     0x4e73  ; 'Ns'
F02232  7e 08                   moveq    #$8, d7

loc_F02234:
F02234  47 f2 70 00             lea.l    (a2, d7.w), a3
F02238  b7 ea 00 04             cmpa.l   $4(a2), a3
F0223C  6d 06                   blt.b    loc_F02244
F0223E  5a 6e 01 02             addq.w   #$5, $102(a6)
F02242  4e 73                   rte      

loc_F02244:
F02244  4a ab 00 08             tst.l    $8(a3)
F02248  67 08                   beq.b    loc_F02252
F0224A  06 87 00 00 00 0e       addi.l   #$e, d7
F02250  60 e2                   bra.b    loc_F02234

loc_F02252:
F02252  36 82                   move.w   d2, (a3)
F02254  27 4e 00 02             move.l   a6, $2(a3)
F02258  27 6c 00 0c 00 06       move.l   $c(a4), $6(a3)
F0225E  27 6c 00 10 00 0a       move.l   $10(a4), $a(a3)
F02264  5c 87                   addq.l   #$6, d7
F02266  8e fc 00 0e             divu.w   #$e, d7
F0226A  13 87 20 00             move.b   d7, (a1, d2.w)
F0226E  08 ee 00 00 00 29       bset.b   #$0, $29(a6)
F02274  e5 8a                   lsl.l    #$2, d2
F02276  20 42                   movea.l  d2, a0
F02278  20 ac 00 0c             move.l   $c(a4), (a0)
F0227C  4e 73                   rte      
F0227E  42 82                   DC.W     0x4282
F02280  14 2c                   DC.W     0x142c
F02282  00 03                   DC.W     0x0003
F02284  22 78                   DC.W     0x2278  ; '"x'
F02286  0c 66                   DC.W     0x0c66
F02288  4a 31 20                DC.B     "J1 "  ; 3 bytes
F0228B  00 6e                   DC.W     0x006e
F0228D  08 3d                   DC.W     0x083d
F0228F  7c 00                   DC.W     0x7c00
F02291  0e 01                   DC.W     0x0e01
F02293  02 4e                   DC.W     0x024e
F02295  73 42                   DC.W     0x7342  ; 'sB'
F02297  83 16                   DC.W     0x8316
F02299  2c 00                   DC.W     0x2c00
F0229B  02 67                   DC.W     0x0267
F0229D  06 0c                   DC.W     0x060c
F0229F  43 00                   DC.W     0x4300
F022A1  06 6f                   DC.W     0x066f
F022A3  08 3d                   DC.W     0x083d
F022A5  7c 00                   DC.W     0x7c00
F022A7  09 01                   DC.W     0x0901
F022A9  02 4e                   DC.W     0x024e
F022AB  73 e1                   DC.W     0x73e1
F022AD  8b 08                   DC.W     0x8b08
F022AF  c3 00                   DC.W     0xc300
F022B1  0d 48                   DC.W     0x0d48
F022B3  7a 00                   DC.W     0x7a00
F022B5  1c 40                   DC.W     0x1c40
F022B7  e7 e5                   DC.W     0xe7e5
F022B9  8a 20                   DC.W     0x8a20
F022BB  42 2f                   DC.W     0x422f  ; 'B/'
F022BD  10 3f                   DC.W     0x103f
F022BF  03 08                   DC.W     0x0308
F022C1  38 00                   DC.W     0x3800
F022C3  07 0c                   DC.W     0x070c
F022C5  35 67                   DC.W     0x3567  ; '5g'
F022C7  06 61                   DC.W     0x0661
F022C9  00 f3                   DC.W     0x00f3
F022CB  be ee                   DC.W     0xbeee
F022CD  07 4e                   DC.W     0x074e
F022CF  73 08                   DC.W     0x7308
F022D1  38 00                   DC.W     0x3800
F022D3  07 0c                   DC.W     0x070c
F022D5  35 67                   DC.W     0x3567  ; '5g'
F022D7  06 61                   DC.W     0x0661
F022D9  00 f3                   DC.W     0x00f3
F022DB  ae dd                   DC.W     0xaedd
F022DD  07 4e                   DC.W     0x074e
F022DF  73 24                   DC.W     0x7324  ; 's$'
F022E1  78 0c                   DC.W     0x780c
F022E3  28 20                   DC.W     0x2820  ; '( '
F022E5  0a 67                   DC.W     0x0a67
F022E7  54 42                   DC.W     0x5442  ; 'TB'
F022E9  80 30                   DC.W     0x8030
F022EB  14 6c                   DC.W     0x146c
F022ED  54 44 40                DC.B     "TD@"  ; 3 bytes
F022F0  b0 6a                   DC.W     0xb06a
F022F2  00 04                   DC.W     0x0004
F022F4  6e 4c                   DC.W     0x6e4c  ; 'nL'
F022F6  53 80                   DC.W     0x5380
F022F8  c0 fc                   DC.W     0xc0fc
F022FA  00 0a                   DC.W     0x000a
F022FC  45 f2                   DC.W     0x45f2
F022FE  00 06                   DC.W     0x0006
F02300  34 2c                   DC.W     0x342c  ; '4,'
F02302  00 02                   DC.W     0x0002
F02304  08 02                   DC.W     0x0802
F02306  00 05                   DC.W     0x0005
F02308  66 5e                   DC.W     0x665e  ; 'f^'
F0230A  4a aa                   DC.W     0x4aaa
F0230C  00 06                   DC.W     0x0006
F0230E  66 38                   DC.W     0x6638  ; 'f8'
F02310  08 02                   DC.W     0x0802
F02312  00 04                   DC.W     0x0004
F02314  67 0c                   DC.W     0x670c
F02316  08 2e                   DC.W     0x082e
F02318  00 0f                   DC.W     0x000f
F0231A  00 28                   DC.W     0x0028
F0231C  66 04                   DC.W     0x6604
F0231E  08 82                   DC.W     0x0882
F02320  00 04                   DC.W     0x0004
F02322  7a 02                   moveq    #$2, d5
F02324  2c 2c 00 04             move.l   $4(a4), d6
F02328  20 6e 00 36             movea.l  $36(a6), a0
F0232C  61 00 f4 2e             bsr.w    loc_F0175C
F02330  60 24                   bra.b    loc_F02356
F02332  4e 71                   DC.W     0x4e71  ; 'Nq'
F02334  06 6e                   DC.W     0x066e
F02336  00 0c                   DC.W     0x000c
F02338  01 02                   DC.W     0x0102
F0233A  4e 73                   DC.W     0x4e73  ; 'Ns'
F0233C  58 6e 01 02             addq.w   #$4, $102(a6)
F02340  4e 73                   rte      
F02342  5a 6e 01 02             addq.w   #$5, $102(a6)
F02346  4e 73                   rte      

loc_F02348:
F02348  5c 6e 01 02             addq.w   #$6, $102(a6)
F0234C  4e 73                   rte      

loc_F0234E:
F0234E  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F02354  4e 73                   rte      

loc_F02356:
F02356  25 46 00 06             move.l   d6, $6(a2)
F0235A  02 42 00 f3             andi.w   #$f3, d2
F0235E  35 42 00 04             move.w   d2, $4(a2)
F02362  24 ae 00 14             move.l   $14(a6), (a2)
F02366  4e 73                   rte      
F02368  4a aa 00 06             tst.l    $6(a2)
F0236C  67 da                   beq.b    loc_F02348
F0236E  20 2e 00 14             move.l   $14(a6), d0
F02372  b0 92                   cmp.l    (a2), d0
F02374  67 08                   beq.b    loc_F0237E
F02376  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F0237C  67 d0                   beq.b    loc_F0234E

loc_F0237E:
F0237E  42 aa 00 06             clr.l    $6(a2)
F02382  4e 73                   rte      
F02384  4a ad                   DC.W     0x4aad
F02386  00 40                   DC.W     0x0040
F02388  67 06                   DC.W     0x6706
F0238A  5c 6e                   DC.W     0x5c6e  ; '\n'
F0238C  01 02                   DC.W     0x0102
F0238E  60 68                   DC.W     0x6068  ; '`h'
F02390  26 2c 00 0a             move.l   $a(a4), d3
F02394  06 83 00 00 00 ff       addi.l   #$ff, d3
F0239A  e0 8b                   lsr.l    #$8, d3
F0239C  48 43                   swap     d3
F0239E  16 38 0c 72             move.b   $c72.w, d3
F023A2  48 43                   swap     d3
F023A4  20 43                   movea.l  d3, a0
F023A6  61 00 ee 96             bsr.w    loc_F0123E
F023AA  60 06                   bra.b    loc_F023B2
F023AC  50 6e                   DC.W     0x506e  ; 'Pn'
F023AE  01 02                   DC.W     0x0102
F023B0  60 46                   DC.W     0x6046  ; '`F'

loc_F023B2:
F023B2  26 48                   movea.l  a0, a3
F023B4  26 bc 21 41 53 51       move.l   #$21415351, (a3)
F023BA  17 6c 00 08 00 04       move.b   $8(a4), $4(a3)
F023C0  08 ab 00 0f 00 04       bclr.b   #$f, $4(a3)
F023C6  17 6c 00 09 00 05       move.b   $9(a4), $5(a3)
F023CC  27 6c 00 0e 00 06       move.l   $e(a4), $6(a3)
F023D2  27 6c 00 12 00 0a       move.l   $12(a4), $a(a3)
F023D8  41 eb 00 28             lea.l    $28(a3), a0
F023DC  27 48 00 16             move.l   a0, $16(a3)
F023E0  27 48 00 1e             move.l   a0, $1e(a3)
F023E4  27 48 00 22             move.l   a0, $22(a3)
F023E8  e1 8a                   lsl.l    #$8, d2
F023EA  d4 8b                   add.l    a3, d2
F023EC  27 42 00 1a             move.l   d2, $1a(a3)
F023F0  42 6b 00 26             clr.w    $26(a3)
F023F4  2b 4b 00 40             move.l   a3, $40(a5)
F023F8  4e 73                   rte      
F023FA  28 4e                   DC.W     0x284e  ; '(N'
F023FC  60 02                   DC.W     0x6002

loc_F023FE:
F023FE  40 e7                   move.w   sr, -(a7)
F02400  08 ac 00 05 00 2d       bclr.b   #$5, $2d(a4)
F02406  4a ac 00 40             tst.l    $40(a4)
F0240A  67 20                   beq.b    loc_F0242C
F0240C  20 6c 00 40             movea.l  $40(a4), a0
F02410  42 ac 00 40             clr.l    $40(a4)
F02414  22 28 00 1a             move.l   $1a(a0), d1
F02418  92 88                   sub.l    a0, d1
F0241A  06 81 00 00 00 ff       addi.l   #$ff, d1
F02420  e0 81                   asr.l    #$8, d1
F02422  61 00 f0 70             bsr.w    loc_F01494
F02426  60 04                   bra.b    loc_F0242C
F02428  61 00                   DC.W     0x6100
F0242A  dd 5c                   DC.W     0xdd5c

loc_F0242C:
F0242C  4e 73                   rte      
F0242E  26 4c 28 6d             DC.B     "&L(m"  ; 4 bytes
F02432  00 40                   DC.W     0x0040
F02434  20 0c                   DC.W     0x200c
F02436  66 08                   DC.W     0x6608
F02438  58 6e                   DC.W     0x586e  ; 'Xn'
F0243A  01 02                   DC.W     0x0102

loc_F0243C:
F0243C  60 00 00 de             bra.w    loc_F0251C
F02440  08 2c 00 08 00 04       btst.b   #$8, $4(a4)
F02446  66 08                   bne.b    loc_F02450
F02448  06 6e 00 0e 01 02       addi.w   #$e, $102(a6)
F0244E  60 ec                   bra.b    loc_F0243C

loc_F02450:
F02450  7a 02                   moveq    #$2, d5
F02452  2c 2b 00 0a             move.l   $a(a3), d6
F02456  20 6e 00 36             movea.l  $36(a6), a0
F0245A  61 00 f3 00             bsr.w    loc_F0175C
F0245E  60 0a                   bra.b    loc_F0246A
F02460  4e 71                   DC.W     0x4e71  ; 'Nq'

loc_F02462:
F02462  06 6e 00 0c 01 02       addi.w   #$c, $102(a6)
F02468  60 d2                   bra.b    loc_F0243C

loc_F0246A:
F0246A  22 46                   movea.l  d6, a1
F0246C  42 81                   clr.l    d1
F0246E  12 19                   move.b   (a1)+, d1
F02470  2c 2b 00 0a             move.l   $a(a3), d6
F02474  dc 81                   add.l    d1, d6
F02476  e0 8e                   lsr.l    #$8, d6
F02478  bc 70 50 02             cmp.w    $2(a0, d5.w), d6
F0247C  62 e4                   bhi.b    loc_F02462
F0247E  0c 81 00 00 00 03       cmpi.l   #$3, d1
F02484  63 36                   bls.b    loc_F024BC
F02486  42 85                   clr.l    d5
F02488  2c 01                   move.l   d1, d6
F0248A  42 87                   clr.l    d7
F0248C  1e 19                   move.b   (a1)+, d7
F0248E  02 07 00 7f             andi.b   #$7f, d7
F02492  0c 07 00 07             cmpi.b   #$7, d7
F02496  66 02                   bne.b    loc_F0249A
F02498  59 87                   subq.l   #$4, d7

loc_F0249A:
F0249A  08 2b 00 0f 00 08       btst.b   #$f, $8(a3)
F024A0  67 02                   beq.b    loc_F024A4
F024A2  58 81                   addq.l   #$4, d1

loc_F024A4:
F024A4  0c 87 00 00 00 03       cmpi.l   #$3, d7
F024AA  66 18                   bne.b    loc_F024C4
F024AC  50 86                   addq.l   #$8, d6
F024AE  50 81                   addq.l   #$8, d1
F024B0  50 85                   addq.l   #$8, d5
F024B2  42 80                   clr.l    d0
F024B4  10 2c 00 05             move.b   $5(a4), d0
F024B8  bc 80                   cmp.l    d0, d6
F024BA  63 08                   bls.b    loc_F024C4

loc_F024BC:
F024BC  06 6e 00 10 01 02       addi.w   #$10, $102(a6)
F024C2  60 58                   bra.b    loc_F0251C

loc_F024C4:
F024C4  28 01                   move.l   d1, d4
F024C6  24 4b                   movea.l  a3, a2
F024C8  61 00 02 9a             bsr.w    loc_F02764
F024CC  60 06                   bra.b    loc_F024D4
F024CE  5a 6e                   DC.W     0x5a6e  ; 'Zn'
F024D0  01 02                   DC.W     0x0102
F024D2  60 48                   DC.W     0x6048  ; '`H'

loc_F024D4:
F024D4  28 6d 00 40             movea.l  $40(a5), a4
F024D8  20 4a                   movea.l  a2, a0
F024DA  16 c4                   move.b   d4, (a3)+
F024DC  08 28 00 0f 00 08       btst.b   #$f, $8(a0)
F024E2  67 04                   beq.b    loc_F024E8
F024E4  08 c7 00 07             bset.b   #$7, d7

loc_F024E8:
F024E8  16 c7                   move.b   d7, (a3)+
F024EA  74 01                   moveq    #$1, d2
F024EC  55 84                   subq.l   #$2, d4
F024EE  61 30                   bsr.b    loc_F02520
F024F0  08 28 00 0f 00 08       btst.b   #$f, $8(a0)
F024F6  67 0a                   beq.b    loc_F02502
F024F8  74 04                   moveq    #$4, d2
F024FA  45 e8 00 0e             lea.l    $e(a0), a2
F024FE  61 1e                   bsr.b    loc_F0251E
F02500  59 84                   subq.l   #$4, d4

loc_F02502:
F02502  4a 85                   tst.l    d5
F02504  67 0a                   beq.b    loc_F02510
F02506  24 05                   move.l   d5, d2
F02508  45 ee 00 10             lea.l    $10(a6), a2
F0250C  61 10                   bsr.b    loc_F0251E
F0250E  51 84                   subq.l   #$8, d4

loc_F02510:
F02510  24 49                   movea.l  a1, a2
F02512  24 04                   move.l   d4, d2
F02514  67 02                   beq.b    loc_F02518
F02516  61 06                   bsr.b    loc_F0251E

loc_F02518:
F02518  61 00 01 8e             bsr.w    loc_F026A8

loc_F0251C:
F0251C  4e 73                   rte      

loc_F0251E:
F0251E  36 da                   move.w   (a2)+, (a3)+

loc_F02520:
F02520  b7 ec 00 1a             cmpa.l   $1a(a4), a3
F02524  65 04                   bcs.b    loc_F0252A
F02526  26 6c 00 16             movea.l  $16(a4), a3

loc_F0252A:
F0252A  55 42                   subq.w   #$2, d2
F0252C  6e f0                   bgt.b    loc_F0251E
F0252E  4e 75                   rts      
F02530  28 6e                   DC.W     0x286e  ; '(n'
F02532  00 40                   DC.W     0x0040
F02534  20 0c                   DC.W     0x200c
F02536  66 06                   DC.W     0x6606
F02538  58 6e                   DC.W     0x586e  ; 'Xn'
F0253A  01 02                   DC.W     0x0102
F0253C  4e 73                   DC.W     0x4e73  ; 'Ns'
F0253E  4a 6c 00 26             tst.w    $26(a4)
F02542  66 04                   bne.b    loc_F02548
F02544  7e 02                   moveq    #$2, d7
F02546  60 14                   bra.b    loc_F0255C

loc_F02548:
F02548  2a 6c 00 1e             movea.l  $1e(a4), a5
F0254C  42 87                   clr.l    d7
F0254E  1e 15                   move.b   (a5), d7
F02550  14 2d 00 01             move.b   $1(a5), d2
F02554  08 02 00 07             btst.b   #$7, d2
F02558  67 02                   beq.b    loc_F0255C
F0255A  59 87                   subq.l   #$4, d7

loc_F0255C:
F0255C  2a 07                   move.l   d7, d5
F0255E  2c 08                   move.l   a0, d6
F02560  20 6e 00 36             movea.l  $36(a6), a0
F02564  61 00 f1 f6             bsr.w    loc_F0175C
F02568  60 0a                   bra.b    loc_F02574
F0256A  4e 71                   DC.W     0x4e71  ; 'Nq'
F0256C  06 6e                   DC.W     0x066e
F0256E  00 0c                   DC.W     0x000c
F02570  01 02                   DC.W     0x0102
F02572  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F02574:
F02574  26 46                   movea.l  d6, a3
F02576  0c 47 00 02             cmpi.w   #$2, d7
F0257A  66 04                   bne.b    loc_F02580
F0257C  42 53                   clr.w    (a3)
F0257E  4e 73                   rte      

loc_F02580:
F02580  54 8d                   addq.l   #$2, a5
F02582  08 82 00 07             bclr.b   #$7, d2
F02586  67 10                   beq.b    loc_F02598
F02588  58 8d                   addq.l   #$4, a5
F0258A  bb ec 00 1a             cmpa.l   $1a(a4), a5
F0258E  65 08                   bcs.b    loc_F02598
F02590  9b ec 00 1a             suba.l   $1a(a4), a5
F02594  db ec 00 16             adda.l   $16(a4), a5

loc_F02598:
F02598  16 c7                   move.b   d7, (a3)+
F0259A  16 c2                   move.b   d2, (a3)+
F0259C  6e 04                   bgt.b    loc_F025A2
F0259E  60 10                   bra.b    loc_F025B0

loc_F025A0:
F025A0  36 dd                   move.w   (a5)+, (a3)+

loc_F025A2:
F025A2  bb ec 00 1a             cmpa.l   $1a(a4), a5
F025A6  65 04                   bcs.b    loc_F025AC
F025A8  2a 6c 00 16             movea.l  $16(a4), a5

loc_F025AC:
F025AC  55 47                   subq.w   #$2, d7
F025AE  6e f0                   bgt.b    loc_F025A0

loc_F025B0:
F025B0  2e 0d                   move.l   a5, d7
F025B2  52 87                   addq.l   #$1, d7
F025B4  08 87 00 00             bclr.b   #$0, d7
F025B8  be ac 00 1a             cmp.l    $1a(a4), d7
F025BC  65 04                   bcs.b    loc_F025C2
F025BE  2e 2c 00 16             move.l   $16(a4), d7

loc_F025C2:
F025C2  00 7c 07 00             ori.w    #$700, sr
F025C6  29 47 00 1e             move.l   d7, $1e(a4)
F025CA  53 6c 00 26             subq.w   #$1, $26(a4)
F025CE  46 d7                   move.w   (a7), sr
F025D0  26 46                   movea.l  d6, a3
F025D2  0c 02 00 07             cmpi.b   #$7, d2
F025D6  66 1e                   bne.b    loc_F025F6
F025D8  24 6b 00 04             movea.l  $4(a3), a2
F025DC  27 6a 00 10 00 04       move.l   $10(a2), $4(a3)
F025E2  4a 2b 00 17             tst.b    $17(a3)
F025E6  67 08                   beq.b    loc_F025F0
F025E8  08 2b 00 0e 00 02       btst.b   #$e, $2(a3)
F025EE  67 08                   beq.b    loc_F025F8

loc_F025F0:
F025F0  37 7c 03 00 00 16       move.w   #$300, $16(a3)

loc_F025F6:
F025F6  4e 73                   rte      

loc_F025F8:
F025F8  42 80                   clr.l    d0
F025FA  30 30 50 02             move.w   $2(a0, d5.w), d0
F025FE  52 40                   addq.w   #$1, d0
F02600  d0 70 50 04             add.w    $4(a0, d5.w), d0
F02604  e1 88                   lsl.l    #$8, d0
F02606  04 80 00 00 00 18       subi.l   #$18, d0
F0260C  90 8b                   sub.l    a3, d0
F0260E  42 87                   clr.l    d7
F02610  1e 2b 00 17             move.b   $17(a3), d7
F02614  b0 87                   cmp.l    d7, d0
F02616  6c 0e                   bge.b    loc_F02626
F02618  2e 00                   move.l   d0, d7
F0261A  6f d4                   ble.b    loc_F025F0
F0261C  17 7c 00 01 00 16       move.b   #$1, $16(a3)
F02622  17 47 00 17             move.b   d7, $17(a3)

loc_F02626:
F02626  2a 07                   move.l   d7, d5
F02628  2c 2b 00 12             move.l   $12(a3), d6
F0262C  08 06 00 00             btst.b   #$0, d6
F02630  67 08                   beq.b    loc_F0263A
F02632  37 7c 02 00 00 16       move.w   #$200, $16(a3)
F02638  4e 73                   rte      

loc_F0263A:
F0263A  20 6a 00 36             movea.l  $36(a2), a0
F0263E  61 00 f1 1c             bsr.w    loc_F0175C
F02642  60 22                   bra.b    loc_F02666
F02644  60 02                   DC.W     0x6002
F02646  60 ea                   DC.W     0x60ea
F02648  e0 8e                   lsr.l    #$8, d6
F0264A  dc 70 50 04             add.w    $4(a0, d5.w), d6
F0264E  e1 8e                   lsl.l    #$8, d6
F02650  dc 03                   add.b    d3, d6
F02652  3e 30 50 02             move.w   $2(a0, d5.w), d7
F02656  52 87                   addq.l   #$1, d7
F02658  e1 8f                   lsl.l    #$8, d7
F0265A  9e 83                   sub.l    d3, d7
F0265C  17 7c 00 01 00 16       move.b   #$1, $16(a3)
F02662  17 47 00 17             move.b   d7, $17(a3)

loc_F02666:
F02666  42 87                   clr.l    d7
F02668  1e 2b 00 17             move.b   $17(a3), d7
F0266C  2a 46                   movea.l  d6, a5
F0266E  47 eb 00 18             lea.l    $18(a3), a3

loc_F02672:
F02672  36 dd                   move.w   (a5)+, (a3)+
F02674  55 87                   subq.l   #$2, d7
F02676  6e fa                   bgt.b    loc_F02672
F02678  4e 73                   rte      
F0267A  28 6e                   DC.W     0x286e  ; '(n'
F0267C  00 40                   DC.W     0x0040
F0267E  20 0c                   DC.W     0x200c
F02680  66 06                   DC.W     0x6606
F02682  58 6e                   DC.W     0x586e  ; 'Xn'
F02684  01 02                   DC.W     0x0102
F02686  60 1e                   DC.W     0x601e
F02688  20 2e 01 20             move.l   $120(a6), d0
F0268C  02 00 00 07             andi.b   #$7, d0
F02690  02 2c 00 f8 00 04       andi.b   #$f8, $4(a4)
F02696  81 2c 00 04             or.b     d0, $4(a4)
F0269A  4a 6c 00 26             tst.w    $26(a4)
F0269E  67 06                   beq.b    loc_F026A6
F026A0  4b d6                   lea.l    (a6), a5
F026A2  61 00 00 04             bsr.w    loc_F026A8

loc_F026A6:
F026A6  4e 73                   rte      

loc_F026A8:
F026A8  40 e7                   move.w   sr, -(a7)
F026AA  08 2d 00 07 00 2d       btst.b   #$7, $2d(a5)
F026B0  66 00 00 b0             bne.w    loc_F02762
F026B4  08 2c 00 0a 00 04       btst.b   #$a, $4(a4)
F026BA  67 00 00 98             beq.w    loc_F02754
F026BE  22 2c 00 06             move.l   $6(a4), d1
F026C2  20 6c 00 1e             movea.l  $1e(a4), a0
F026C6  10 28 00 01             move.b   $1(a0), d0
F026CA  08 00 00 07             btst.b   #$7, d0
F026CE  67 1c                   beq.b    loc_F026EC
F026D0  54 88                   addq.l   #$2, a0
F026D2  b1 ec 00 1a             cmpa.l   $1a(a4), a0
F026D6  65 04                   bcs.b    loc_F026DC
F026D8  20 6c 00 16             movea.l  $16(a4), a0

loc_F026DC:
F026DC  22 10                   move.l   (a0), d1
F026DE  54 88                   addq.l   #$2, a0
F026E0  b1 ec 00 1a             cmpa.l   $1a(a4), a0
F026E4  65 06                   bcs.b    loc_F026EC
F026E6  20 6c 00 16             movea.l  $16(a4), a0
F026EA  32 10                   move.w   (a0), d1

loc_F026EC:
F026EC  4a 81                   tst.l    d1
F026EE  6b 4c                   bmi.b    loc_F0273C
F026F0  22 41                   movea.l  d1, a1
F026F2  7a 02                   moveq    #$2, d5
F026F4  2c 09                   move.l   a1, d6
F026F6  20 6d 00 36             movea.l  $36(a5), a0
F026FA  61 00 f0 60             bsr.w    loc_F0175C
F026FE  60 04                   bra.b    loc_F02704
F02700  4e 71                   DC.W     0x4e71  ; 'Nq'
F02702  60 38                   DC.W     0x6038  ; '`8'

loc_F02704:
F02704  29 49 00 12             move.l   a1, $12(a4)
F02708  2c 2d 01 3c             move.l   $13c(a5), d6
F0270C  7a 42                   moveq    #$42, d5
F0270E  08 2c 00 0b 00 04       btst.b   #$b, $4(a4)
F02714  67 02                   beq.b    loc_F02718
F02716  7a 06                   moveq    #$6, d5

loc_F02718:
F02718  2e 05                   move.l   d5, d7
F0271A  9c 85                   sub.l    d5, d6
F0271C  20 6d 00 36             movea.l  $36(a5), a0
F02720  61 00 f0 3a             bsr.w    loc_F0175C
F02724  60 04                   bra.b    loc_F0272A
F02726  4e 71                   DC.W     0x4e71  ; 'Nq'
F02728  60 12                   DC.W     0x6012

loc_F0272A:
F0272A  dc 87                   add.l    d7, d6
F0272C  29 46 00 0e             move.l   d6, $e(a4)
F02730  08 ac 00 0a 00 04       bclr.b   #$a, $4(a4)
F02736  08 ed 00 05 00 2d       bset.b   #$5, $2d(a5)

loc_F0273C:
F0273C  20 2d 00 58             move.l   $58(a5), d0
F02740  67 12                   beq.b    loc_F02754
F02742  20 40                   movea.l  d0, a0
F02744  42 a8 00 04             clr.l    $4(a0)
F02748  42 ad 00 58             clr.l    $58(a5)
F0274C  08 ad 00 0e 00 2c       bclr.b   #$e, $2c(a5)
F02752  60 08                   bra.b    loc_F0275C

loc_F02754:
F02754  08 ad 00 0c 00 2c       bclr.b   #$c, $2c(a5)
F0275A  67 06                   beq.b    loc_F02762

loc_F0275C:
F0275C  41 d5                   lea.l    (a5), a0
F0275E  61 00 e0 9c             bsr.w    loc_F007FC

loc_F02762:
F02762  4e 73                   rte      

loc_F02764:
F02764  40 e7                   move.w   sr, -(a7)
F02766  42 80                   clr.l    d0
F02768  52 81                   addq.l   #$1, d1
F0276A  08 81 00 00             bclr.b   #$0, d1
F0276E  00 7c 07 00             ori.w    #$700, sr
F02772  26 6c 00 1e             movea.l  $1e(a4), a3
F02776  20 6c 00 22             movea.l  $22(a4), a0
F0277A  4a 6c 00 26             tst.w    $26(a4)
F0277E  66 0c                   bne.b    loc_F0278C
F02780  08 c0 00 01             bset.b   #$1, d0
F02784  26 48                   movea.l  a0, a3
F02786  29 48 00 1e             move.l   a0, $1e(a4)
F0278A  60 06                   bra.b    loc_F02792

loc_F0278C:
F0278C  b7 c8                   cmpa.l   a0, a3
F0278E  67 2c                   beq.b    loc_F027BC
F02790  62 08                   bhi.b    loc_F0279A

loc_F02792:
F02792  97 ec 00 16             suba.l   $16(a4), a3
F02796  d7 ec 00 1a             adda.l   $1a(a4), a3

loc_F0279A:
F0279A  d1 c1                   adda.l   d1, a0
F0279C  b1 cb                   cmpa.l   a3, a0
F0279E  62 1c                   bhi.b    loc_F027BC
F027A0  b1 ec 00 1a             cmpa.l   $1a(a4), a0
F027A4  65 08                   bcs.b    loc_F027AE
F027A6  91 ec 00 1a             suba.l   $1a(a4), a0
F027AA  d1 ec 00 16             adda.l   $16(a4), a0

loc_F027AE:
F027AE  26 6c 00 22             movea.l  $22(a4), a3
F027B2  29 48 00 22             move.l   a0, $22(a4)
F027B6  52 6c 00 26             addq.w   #$1, $26(a4)
F027BA  4e 73                   rte      

loc_F027BC:
F027BC  54 af 00 02             addq.l   #$2, $2(a7)
F027C0  4e 73                   rte      
F027C2  2a 48 28 6e             DC.B     "*H(n"  ; 4 bytes
F027C6  00 40                   DC.W     0x0040
F027C8  7a 42                   DC.W     0x7a42  ; 'zB'
F027CA  08 2c                   DC.W     0x082c
F027CC  00 0b                   DC.W     0x000b
F027CE  00 04                   DC.W     0x0004
F027D0  67 02                   DC.W     0x6702
F027D2  7a 06                   DC.W     0x7a06
F027D4  2e 05                   move.l   d5, d7
F027D6  2c 2e 01 3c             move.l   $13c(a6), d6
F027DA  20 6e 00 36             movea.l  $36(a6), a0
F027DE  61 00 ef 7c             bsr.w    loc_F0175C
F027E2  60 0c                   bra.b    loc_F027F0
F027E4  4e 71                   DC.W     0x4e71  ; 'Nq'
F027E6  3e 3c                   DC.W     0x3e3c  ; '><'
F027E8  80 99                   DC.W     0x8099
F027EA  41 d6                   DC.W     0x41d6
F027EC  61 00                   DC.W     0x6100
F027EE  e0 36                   DC.W     0xe036

loc_F027F0:
F027F0  df ae 01 3c             add.l    d7, $13c(a6)
F027F4  26 46                   movea.l  d6, a3
F027F6  08 2c 00 0b 00 04       btst.b   #$b, $4(a4)
F027FC  66 14                   bne.b    loc_F02812
F027FE  4c db 00 ff             movem.l  (a3)+, d0-d7
F02802  48 ee 00 ff 01 00       movem.l  d0-d7, $100(a6)
F02808  4c db 00 7f             movem.l  (a3)+, d0-d6
F0280C  48 ee 00 7f 01 20       movem.l  d0-d6, $120(a6)

loc_F02812:
F02812  32 1b                   move.w   (a3)+, d1
F02814  02 41 00 ff             andi.w   #$ff, d1
F02818  08 2f 00 0f 00 08       btst.b   #$f, $8(a7)
F0281E  67 04                   beq.b    loc_F02824
F02820  08 c1 00 0f             bset.b   #$f, d1

loc_F02824:
F02824  3d 41 00 fa             move.w   d1, $fa(a6)
F02828  2f 5b 00 0a             move.l   (a3)+, $a(a7)
F0282C  28 6e 00 40             movea.l  $40(a6), a4
F02830  20 0c                   move.l   a4, d0
F02832  67 1a                   beq.b    loc_F0284E
F02834  20 0d                   move.l   a5, d0
F02836  08 00 00 00             btst.b   #$0, d0
F0283A  67 06                   beq.b    loc_F02842
F0283C  08 ec 00 0a 00 04       bset.b   #$a, $4(a4)

loc_F02842:
F02842  4a 6c 00 26             tst.w    $26(a4)
F02846  67 06                   beq.b    loc_F0284E
F02848  4b d6                   lea.l    (a6), a5
F0284A  61 00 fe 5c             bsr.w    loc_F026A8

loc_F0284E:
F0284E  4e 73                   rte      
F02850  28 6e                   DC.W     0x286e  ; '(n'
F02852  00 40                   DC.W     0x0040
F02854  20 0c                   DC.W     0x200c
F02856  66 06                   DC.W     0x6606
F02858  58 6e                   DC.W     0x586e  ; 'Xn'
F0285A  01 02                   DC.W     0x0102
F0285C  60 34                   DC.W     0x6034  ; '`4'
F0285E  08 ee 00 0c 00 2c       bset.b   #$c, $2c(a6)
F02864  08 2e 00 05 00 2d       btst.b   #$5, $2d(a6)
F0286A  67 0e                   beq.b    loc_F0287A
F0286C  08 ae 00 0c 00 2c       bclr.b   #$c, $2c(a6)
F02872  41 d6                   lea.l    (a6), a0
F02874  61 00 df 86             bsr.w    loc_F007FC
F02878  60 18                   bra.b    loc_F02892

loc_F0287A:
F0287A  08 ec 00 08 00 04       bset.b   #$8, $4(a4)
F02880  08 ec 00 0a 00 04       bset.b   #$a, $4(a4)
F02886  4a 6c 00 26             tst.w    $26(a4)
F0288A  67 06                   beq.b    loc_F02892
F0288C  4b d6                   lea.l    (a6), a5
F0288E  61 00 fe 18             bsr.w    loc_F026A8

loc_F02892:
F02892  4e 73                   rte      
F02894  49 eb ff fe             lea.l    -$2(a3), a4
F02898  36 3c 80 01             move.w   #$8001, d3
F0289C  60 14                   bra.b    loc_F028B2
F0289E  26 4c                   DC.W     0x264c  ; '&L'
F028A0  4c ec                   DC.W     0x4cec
F028A2  00 70                   DC.W     0x0070
F028A4  00 12                   DC.W     0x0012
F028A6  48 46 3e 2c             DC.B     "HF>,"  ; 4 bytes
F028AA  00 08                   DC.W     0x0008
F028AC  36 2e                   DC.W     0x362e  ; '6.'
F028AE  00 28                   DC.W     0x0028
F028B0  42 03                   DC.W     0x4203

loc_F028B2:
F028B2  41 d3                   lea.l    (a3), a0
F028B4  61 00 ee 58             bsr.w    loc_F0170E
F028B8  60 02                   bra.b    loc_F028BC
F028BA  60 08                   DC.W     0x6008

loc_F028BC:
F028BC  30 3c 00 06             move.w   #$6, d0
F028C0  60 00 01 20             bra.w    loc_F029E2
F028C4  42 80                   clr.l    d0
F028C6  10 38 0c 73             move.b   $c73.w, d0
F028CA  48 40                   swap     d0
F028CC  30 3c 00 02             move.w   #$2, d0
F028D0  20 40                   movea.l  d0, a0
F028D2  61 00 e9 6a             bsr.w    loc_F0123E
F028D6  60 08                   bra.b    loc_F028E0
F028D8  30 3c                   DC.W     0x303c  ; '0<'
F028DA  00 08                   DC.W     0x0008
F028DC  60 00                   DC.W     0x6000
F028DE  01 04                   DC.W     0x0104

loc_F028E0:
F028E0  2a 48                   movea.l  a0, a5
F028E2  34 3c 00 7f             move.w   #$7f, d2

loc_F028E6:
F028E6  42 98                   clr.l    (a0)+
F028E8  51 ca ff fc             dbra     d2, loc_F028E6
F028EC  2b 53 00 10             move.l   (a3), $10(a5)
F028F0  20 2b 00 04             move.l   $4(a3), d0
F028F4  08 03 00 00             btst.b   #$0, d3
F028F8  66 14                   bne.b    loc_F0290E
F028FA  08 03 00 0f             btst.b   #$f, d3
F028FE  67 06                   beq.b    loc_F02906
F02900  4a 80                   tst.l    d0
F02902  66 0a                   bne.b    loc_F0290E
F02904  60 04                   bra.b    loc_F0290A

loc_F02906:
F02906  3c 2e 00 70             move.w   $70(a6), d6

loc_F0290A:
F0290A  20 2e 00 14             move.l   $14(a6), d0

loc_F0290E:
F0290E  3b 46 00 70             move.w   d6, $70(a5)
F02912  2b 40 00 14             move.l   d0, $14(a5)
F02916  61 00 00 dc             bsr.w    loc_F029F4
F0291A  42 04                   clr.b    d4
F0291C  08 03 00 0f             btst.b   #$f, d3
F02920  66 04                   bne.b    loc_F02926
F02922  02 44 1f ff             andi.w   #$1fff, d4

loc_F02926:
F02926  3b 44 00 28             move.w   d4, $28(a5)
F0292A  2b 45 00 6c             move.l   d5, $6c(a5)
F0292E  2b 45 00 fc             move.l   d5, $fc(a5)
F02932  48 44                   swap     d4
F02934  30 04                   move.w   d4, d0
F02936  e0 48                   lsr.w    #$8, d0
F02938  67 10                   beq.b    loc_F0294A
F0293A  08 03 00 00             btst.b   #$0, d3
F0293E  66 0e                   bne.b    loc_F0294E
F02940  4a 04                   tst.b    d4
F02942  67 06                   beq.b    loc_F0294A
F02944  b8 2e 00 25             cmp.b    $25(a6), d4
F02948  63 04                   bls.b    loc_F0294E

loc_F0294A:
F0294A  18 2e 00 25             move.b   $25(a6), d4

loc_F0294E:
F0294E  1b 44 00 25             move.b   d4, $25(a5)
F02952  b0 04                   cmp.b    d4, d0
F02954  63 02                   bls.b    loc_F02958
F02956  10 04                   move.b   d4, d0

loc_F02958:
F02958  1b 40 00 24             move.b   d0, $24(a5)
F0295C  1b 40 00 26             move.b   d0, $26(a5)
F02960  2a bc 21 54 43 42       move.l   #$21544342, (a5)
F02966  1b 7c 00 80 00 2c       move.b   #$80, $2c(a5)
F0296C  3b 7c 00 01 00 3a       move.w   #$1, $3a(a5)
F02972  1b 7c 00 fa 00 72       move.b   #$fa, $72(a5)
F02978  3b 7c 00 01 00 30       move.w   #$1, $30(a5)
F0297E  24 4d                   movea.l  a5, a2
F02980  d5 fc 00 00 01 60       adda.l   #$160, a2
F02986  2b 4a 00 36             move.l   a2, $36(a5)
F0298A  24 bc 21 54 53 54       move.l   #$21545354, (a2)
F02990  15 7c 00 04 00 04       move.b   #$4, $4(a2)
F02996  35 7c 00 24 00 06       move.w   #$24, $6(a2)
F0299C  35 7c 00 44 00 08       move.w   #$44, $8(a2)
F029A2  20 78 0c 10             movea.l  $c10.w, a0
F029A6  20 2d 00 10             move.l   $10(a5), d0
F029AA  22 2d 00 14             move.l   $14(a5), d1

loc_F029AE:
F029AE  b1 fc 00 00 00 00       cmpa.l   #$0, a0
F029B4  67 20                   beq.b    loc_F029D6
F029B6  b0 a8 00 10             cmp.l    $10(a0), d0
F029BA  66 06                   bne.b    loc_F029C2
F029BC  b2 a8 00 14             cmp.l    $14(a0), d1
F029C0  67 06                   beq.b    loc_F029C8

loc_F029C2:
F029C2  20 68 00 04             movea.l  $4(a0), a0
F029C6  60 e6                   bra.b    loc_F029AE

loc_F029C8:
F029C8  72 02                   moveq    #$2, d1
F029CA  41 d5                   lea.l    (a5), a0
F029CC  61 00 ea c6             bsr.w    loc_F01494
F029D0  30 3c 00 06             move.w   #$6, d0
F029D4  60 0c                   bra.b    loc_F029E2

loc_F029D6:
F029D6  2b 78 0c 10 00 04       move.l   $c10.w, $4(a5)
F029DC  21 cd 0c 10             move.l   a5, $c10.w
F029E0  4e 73                   rte      

loc_F029E2:
F029E2  08 03 00 00             btst.b   #$0, d3
F029E6  66 06                   bne.b    loc_F029EE
F029E8  3d 40 01 02             move.w   d0, $102(a6)
F029EC  4e 73                   rte      

loc_F029EE:
F029EE  54 af 00 02             addq.l   #$2, $2(a7)
F029F2  4e 73                   rte      

loc_F029F4:
F029F4  08 07 00 0f             btst.b   #$f, d7
F029F8  66 10                   bne.b    loc_F02A0A
F029FA  08 07 00 0e             btst.b   #$e, d7
F029FE  67 32                   beq.b    loc_F02A32
F02A00  20 2e 00 18             move.l   $18(a6), d0
F02A04  22 2e 00 1c             move.l   $1c(a6), d1
F02A08  60 20                   bra.b    loc_F02A2A

loc_F02A0A:
F02A0A  22 2c 00 0e             move.l   $e(a4), d1
F02A0E  20 2c 00 0a             move.l   $a(a4), d0
F02A12  67 0e                   beq.b    loc_F02A22
F02A14  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F02A1A  67 0a                   beq.b    loc_F02A26
F02A1C  4a 81                   tst.l    d1
F02A1E  67 06                   beq.b    loc_F02A26
F02A20  60 08                   bra.b    loc_F02A2A

loc_F02A22:
F02A22  20 2e 00 10             move.l   $10(a6), d0

loc_F02A26:
F02A26  22 2e 00 14             move.l   $14(a6), d1

loc_F02A2A:
F02A2A  2b 40 00 18             move.l   d0, $18(a5)
F02A2E  2b 41 00 1c             move.l   d1, $1c(a5)

loc_F02A32:
F02A32  4e 75                   rts      
F02A34  08 2c                   DC.W     0x082c
F02A36  00 0d                   DC.W     0x000d
F02A38  00 08                   DC.W     0x0008
F02A3A  67 04                   DC.W     0x6704
F02A3C  7a 52                   DC.W     0x7a52  ; 'zR'
F02A3E  60 0a                   DC.W     0x600a
F02A40  08 2c 00 0f 00 08       btst.b   #$f, $8(a4)
F02A46  67 18                   beq.b    loc_F02A60
F02A48  7a 12                   moveq    #$12, d5
F02A4A  2c 2e 01 20             move.l   $120(a6), d6
F02A4E  20 6e 00 36             movea.l  $36(a6), a0
F02A52  61 00 ed 08             bsr.w    loc_F0175C
F02A56  60 08                   bra.b    loc_F02A60
F02A58  4e 71                   DC.W     0x4e71  ; 'Nq'
F02A5A  54 6e                   DC.W     0x546e  ; 'Tn'
F02A5C  01 02                   DC.W     0x0102
F02A5E  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F02A60:
F02A60  4a 94                   tst.l    (a4)
F02A62  66 36                   bne.b    loc_F02A9A
F02A64  22 2e 00 14             move.l   $14(a6), d1
F02A68  2a 79 00 00 0c 10       movea.l  $c10.l, a5

loc_F02A6E:
F02A6E  bb fc 00 00 00 00       cmpa.l   #$0, a5
F02A74  67 2c                   beq.b    loc_F02AA2
F02A76  b2 ad 00 14             cmp.l    $14(a5), d1
F02A7A  66 18                   bne.b    loc_F02A94
F02A7C  08 2d 00 0f 00 28       btst.b   #$f, $28(a5)
F02A82  66 10                   bne.b    loc_F02A94
F02A84  08 2d 00 0f 00 2c       btst.b   #$f, $2c(a5)
F02A8A  67 08                   beq.b    loc_F02A94
F02A8C  08 2d 00 0f 00 2e       btst.b   #$f, $2e(a5)
F02A92  66 44                   bne.b    loc_F02AD8

loc_F02A94:
F02A94  2a 6d 00 04             movea.l  $4(a5), a5
F02A98  60 d4                   bra.b    loc_F02A6E

loc_F02A9A:
F02A9A  41 d4                   lea.l    (a4), a0
F02A9C  61 00 ec 70             bsr.w    loc_F0170E
F02AA0  60 0a                   bra.b    loc_F02AAC

loc_F02AA2:
F02AA2  42 ae 01 20             clr.l    $120(a6)
F02AA6  56 6e 01 02             addq.w   #$3, $102(a6)
F02AAA  4e 73                   rte      

loc_F02AAC:
F02AAC  2a 48                   movea.l  a0, a5
F02AAE  bd cd                   cmpa.l   a5, a6
F02AB0  67 10                   beq.b    loc_F02AC2
F02AB2  08 2d 00 0f 00 28       btst.b   #$f, $28(a5)
F02AB8  67 10                   beq.b    loc_F02ACA
F02ABA  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F02AC0  66 08                   bne.b    loc_F02ACA

loc_F02AC2:
F02AC2  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F02AC8  4e 73                   rte      

loc_F02ACA:
F02ACA  08 2d 00 0f 00 2c       btst.b   #$f, $2c(a5)
F02AD0  66 0c                   bne.b    loc_F02ADE
F02AD2  5c 6e 01 02             addq.w   #$6, $102(a6)
F02AD6  4e 73                   rte      

loc_F02AD8:
F02AD8  2d 6d 00 10 01 20       move.l   $10(a5), $120(a6)

loc_F02ADE:
F02ADE  08 2d 00 0f 00 2e       btst.b   #$f, $2e(a5)
F02AE4  66 5e                   bne.b    loc_F02B44
F02AE6  3e 2c 00 08             move.w   $8(a4), d7
F02AEA  61 00 ff 08             bsr.w    loc_F029F4
F02AEE  2b 6d 00 6c 00 fc       move.l   $6c(a5), $fc(a5)
F02AF4  1b 7c 00 fa 00 72       move.b   #$fa, $72(a5)
F02AFA  08 2d 00 0b 00 28       btst.b   #$b, $28(a5)
F02B00  67 42                   beq.b    loc_F02B44
F02B02  7a 02                   moveq    #$2, d5
F02B04  2c 2d 00 fc             move.l   $fc(a5), d6
F02B08  20 6d 00 36             movea.l  $36(a5), a0
F02B0C  61 00 ec 4e             bsr.w    loc_F0175C
F02B10  60 0a                   bra.b    loc_F02B1C
F02B12  4e 71                   DC.W     0x4e71  ; 'Nq'
F02B14  06 6e                   DC.W     0x066e
F02B16  00 0c                   DC.W     0x000c
F02B18  01 02                   DC.W     0x0102
F02B1A  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F02B1C:
F02B1C  2b 46 00 fc             move.l   d6, $fc(a5)
F02B20  3a 28 00 06             move.w   $6(a0), d5

loc_F02B24:
F02B24  08 30 00 0f 50 24       btst.b   #$f, $24(a0, d5.w)
F02B2A  67 10                   beq.b    loc_F02B3C
F02B2C  30 30 50 04             move.w   $4(a0, d5.w), d0
F02B30  d1 70 50 00             add.w    d0, (a0, d5.w)
F02B34  d1 70 50 02             add.w    d0, $2(a0, d5.w)
F02B38  42 70 50 04             clr.w    $4(a0, d5.w)

loc_F02B3C:
F02B3C  51 85                   subq.l   #$8, d5
F02B3E  0c 45 00 0c             cmpi.w   #$c, d5
F02B42  6c e0                   bge.b    loc_F02B24

loc_F02B44:
F02B44  42 6d 00 2e             clr.w    $2e(a5)
F02B48  08 2c 00 0d 00 08       btst.b   #$d, $8(a4)
F02B4E  67 18                   beq.b    loc_F02B68
F02B50  47 ec 00 12             lea.l    $12(a4), a3
F02B54  4c db 00 ff             movem.l  (a3)+, d0-d7
F02B58  48 ed 00 ff 01 00       movem.l  d0-d7, $100(a5)
F02B5E  4c db 00 7f             movem.l  (a3)+, d0-d6
F02B62  48 ed 00 7f 01 20       movem.l  d0-d6, $120(a5)

loc_F02B68:
F02B68  00 7c 07 00             ori.w    #$700, sr
F02B6C  08 ad 00 0f 00 2c       bclr.b   #$f, $2c(a5)
F02B72  30 2d 00 2c             move.w   $2c(a5), d0
F02B76  02 40 df 00             andi.w   #$df00, d0
F02B7A  66 08                   bne.b    loc_F02B84
F02B7C  46 d7                   move.w   (a7), sr
F02B7E  41 d5                   lea.l    (a5), a0
F02B80  61 00 dc 7a             bsr.w    loc_F007FC

loc_F02B84:
F02B84  4e 73                   rte      
F02B86  20 46                   DC.W     0x2046  ; ' F'
F02B88  4a 90                   DC.W     0x4a90
F02B8A  66 38 22 2e             DC.B     "f8\"."  ; 4 bytes
F02B8E  00 14                   DC.W     0x0014
F02B90  2a 78                   DC.W     0x2a78  ; '*x'
F02B92  0c 10                   DC.W     0x0c10

loc_F02B94:
F02B94  bb fc 00 00 00 00       cmpa.l   #$0, a5
F02B9A  67 2e                   beq.b    loc_F02BCA
F02B9C  b2 ad 00 14             cmp.l    $14(a5), d1
F02BA0  66 1c                   bne.b    loc_F02BBE
F02BA2  08 2d 00 0f 00 28       btst.b   #$f, $28(a5)
F02BA8  66 14                   bne.b    loc_F02BBE
F02BAA  bd cd                   cmpa.l   a5, a6
F02BAC  67 10                   beq.b    loc_F02BBE
F02BAE  08 2d 00 07 00 2d       btst.b   #$7, $2d(a5)
F02BB4  66 08                   bne.b    loc_F02BBE
F02BB6  08 ed 00 0f 00 2c       bset.b   #$f, $2c(a5)
F02BBC  67 4a                   beq.b    loc_F02C08

loc_F02BBE:
F02BBE  2a 6d 00 04             movea.l  $4(a5), a5
F02BC2  60 d0                   bra.b    loc_F02B94
F02BC4  61 00 eb 48             bsr.w    loc_F0170E
F02BC8  60 0a                   bra.b    loc_F02BD4

loc_F02BCA:
F02BCA  42 ae 01 20             clr.l    $120(a6)
F02BCE  56 6e 01 02             addq.w   #$3, $102(a6)
F02BD2  4e 73                   rte      

loc_F02BD4:
F02BD4  2a 48                   movea.l  a0, a5
F02BD6  08 2d 00 07 00 2d       btst.b   #$7, $2d(a5)
F02BDC  66 ec                   bne.b    loc_F02BCA
F02BDE  bd cd                   cmpa.l   a5, a6
F02BE0  67 10                   beq.b    loc_F02BF2
F02BE2  08 2d 00 0f 00 28       btst.b   #$f, $28(a5)
F02BE8  67 10                   beq.b    loc_F02BFA
F02BEA  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F02BF0  66 08                   bne.b    loc_F02BFA

loc_F02BF2:
F02BF2  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F02BF8  4e 73                   rte      

loc_F02BFA:
F02BFA  08 ed 00 0f 00 2c       bset.b   #$f, $2c(a5)
F02C00  67 06                   beq.b    loc_F02C08
F02C02  5c 6e 01 02             addq.w   #$6, $102(a6)
F02C06  4e 73                   rte      

loc_F02C08:
F02C08  3b 6d 00 2c 00 2e       move.w   $2c(a5), $2e(a5)
F02C0E  2d 6d 00 10 01 20       move.l   $10(a5), $120(a6)
F02C14  00 7c 07 00             ori.w    #$700, sr
F02C18  08 ad 00 04 00 2d       bclr.b   #$4, $2d(a5)
F02C1E  67 1c                   beq.b    loc_F02C3C
F02C20  43 f8 0c 08             lea.l    $c08.w, a1

loc_F02C24:
F02C24  20 49                   movea.l  a1, a0
F02C26  22 68 00 0c             movea.l  $c(a0), a1
F02C2A  b3 fc 00 00 00 00       cmpa.l   #$0, a1
F02C30  67 0a                   beq.b    loc_F02C3C
F02C32  b3 cd                   cmpa.l   a5, a1
F02C34  66 ee                   bne.b    loc_F02C24
F02C36  21 69 00 0c 00 0c       move.l   $c(a1), $c(a0)

loc_F02C3C:
F02C3C  4e 73                   rte      
F02C3E  08 ee                   DC.W     0x08ee
F02C40  00 0e                   DC.W     0x000e
F02C42  00 2c                   DC.W     0x002c
F02C44  08 ae                   DC.W     0x08ae
F02C46  00 03                   DC.W     0x0003
F02C48  00 2d                   DC.W     0x002d
F02C4A  66 02                   DC.W     0x6602
F02C4C  4e 73                   DC.W     0x4e73  ; 'Ns'
F02C4E  08 ae 00 0e 00 2c       bclr.b   #$e, $2c(a6)
F02C54  3d 6e 00 5e 01 02       move.w   $5e(a6), $102(a6)
F02C5A  42 6e 00 5e             clr.w    $5e(a6)
F02C5E  41 d6                   lea.l    (a6), a0
F02C60  61 00 db 9a             bsr.w    loc_F007FC
F02C64  4e 73                   rte      
F02C66  bb ce                   DC.W     0xbbce
F02C68  60 00                   DC.W     0x6000
F02C6A  00 0a                   DC.W     0x000a

loc_F02C6C:
F02C6C  40 e7                   move.w   sr, -(a7)
F02C6E  08 f8 00 07 0c 5b       bset.b   #$7, $c5b.w
F02C74  08 a8 00 0e 00 2c       bclr.b   #$e, $2c(a0)
F02C7A  67 28                   beq.b    loc_F02CA4
F02C7C  20 28 00 58             move.l   $58(a0), d0
F02C80  67 0a                   beq.b    loc_F02C8C
F02C82  22 40                   movea.l  d0, a1
F02C84  42 a9 00 04             clr.l    $4(a1)
F02C88  42 a8 00 58             clr.l    $58(a0)

loc_F02C8C:
F02C8C  31 68 00 5e 01 02       move.w   $5e(a0), $102(a0)
F02C92  67 0a                   beq.b    loc_F02C9E
F02C94  31 7c 08 13 01 00       move.w   #$813, $100(a0)
F02C9A  42 68 00 5e             clr.w    $5e(a0)

loc_F02C9E:
F02C9E  61 00 db 5c             bsr.w    loc_F007FC
F02CA2  4e 73                   rte      

loc_F02CA4:
F02CA4  08 e8 00 03 00 2d       bset.b   #$3, $2d(a0)
F02CAA  4e 73                   rte      
F02CAC  08 ee                   DC.W     0x08ee
F02CAE  00 09                   DC.W     0x0009
F02CB0  00 2c                   DC.W     0x002c
F02CB2  4e 73                   DC.W     0x4e73  ; 'Ns'
F02CB4  08 a8                   DC.W     0x08a8
F02CB6  00 09                   DC.W     0x0009
F02CB8  00 2c                   DC.W     0x002c
F02CBA  66 08                   DC.W     0x6608
F02CBC  06 6e                   DC.W     0x066e
F02CBE  00 0a                   DC.W     0x000a
F02CC0  01 02                   DC.W     0x0102
F02CC2  4e 73                   DC.W     0x4e73  ; 'Ns'
F02CC4  61 00 da fa             bsr.w    loc_F007C0
F02CC8  4e 73                   rte      
F02CCA  7e 01                   DC.W     0x7e01
F02CCC  60 02                   DC.W     0x6002
F02CCE  42 87                   DC.W     0x4287
F02CD0  24 08                   move.l   a0, d2
F02CD2  0c 82 05 26 5c 00       cmpi.l   #$5265c00, d2
F02CD8  63 06                   bls.b    loc_F02CE0
F02CDA  24 3c 05 26 5c 00       move.l   #$5265c00, d2

loc_F02CE0:
F02CE0  61 00 e2 b4             bsr.w    loc_F00F96
F02CE4  d4 81                   add.l    d1, d2
F02CE6  22 78 0c 2c             movea.l  $c2c.w, a1
F02CEA  45 e9 00 08             lea.l    $8(a1), a2

loc_F02CEE:
F02CEE  26 4a                   movea.l  a2, a3

loc_F02CF0:
F02CF0  20 13                   move.l   (a3), d0
F02CF2  67 1c                   beq.b    loc_F02D10
F02CF4  24 40                   movea.l  d0, a2
F02CF6  4a aa 00 04             tst.l    $4(a2)
F02CFA  67 0c                   beq.b    loc_F02D08
F02CFC  bd ea 00 04             cmpa.l   $4(a2), a6
F02D00  66 ec                   bne.b    loc_F02CEE
F02D02  4a aa 00 16             tst.l    $16(a2)
F02D06  66 e6                   bne.b    loc_F02CEE

loc_F02D08:
F02D08  26 92                   move.l   (a2), (a3)
F02D0A  61 00 e3 e4             bsr.w    loc_F010F0
F02D0E  60 e0                   bra.b    loc_F02CF0

loc_F02D10:
F02D10  20 2e 00 40             move.l   $40(a6), d0
F02D14  67 46                   beq.b    loc_F02D5C
F02D16  28 40                   movea.l  d0, a4
F02D18  00 7c 07 00             ori.w    #$700, sr
F02D1C  4a 47                   tst.w    d7
F02D1E  67 0c                   beq.b    loc_F02D2C
F02D20  08 ec 00 08 00 04       bset.b   #$8, $4(a4)
F02D26  08 ec 00 0a 00 04       bset.b   #$a, $4(a4)

loc_F02D2C:
F02D2C  08 2e 00 05 00 2d       btst.b   #$5, $2d(a6)
F02D32  67 10                   beq.b    loc_F02D44
F02D34  08 ac 00 0a 00 04       bclr.b   #$a, $4(a4)
F02D3A  46 d7                   move.w   (a7), sr

loc_F02D3C:
F02D3C  41 d6                   lea.l    (a6), a0
F02D3E  61 00 da bc             bsr.w    loc_F007FC
F02D42  60 66                   bra.b    loc_F02DAA

loc_F02D44:
F02D44  08 2c 00 0a 00 04       btst.b   #$a, $4(a4)
F02D4A  67 14                   beq.b    loc_F02D60
F02D4C  4a 6c 00 26             tst.w    $26(a4)
F02D50  67 0e                   beq.b    loc_F02D60
F02D52  46 d7                   move.w   (a7), sr
F02D54  4b d6                   lea.l    (a6), a5
F02D56  61 00 f9 50             bsr.w    loc_F026A8
F02D5A  60 e0                   bra.b    loc_F02D3C

loc_F02D5C:
F02D5C  00 7c 07 00             ori.w    #$700, sr

loc_F02D60:
F02D60  4a 47                   tst.w    d7
F02D62  67 1e                   beq.b    loc_F02D82
F02D64  08 ee 00 0e 00 2c       bset.b   #$e, $2c(a6)
F02D6A  08 ae 00 03 00 2d       bclr.b   #$3, $2d(a6)
F02D70  67 10                   beq.b    loc_F02D82
F02D72  08 ae 00 0e 00 2c       bclr.b   #$e, $2c(a6)
F02D78  46 d7                   move.w   (a7), sr
F02D7A  41 d6                   lea.l    (a6), a0
F02D7C  61 00 da 7e             bsr.w    loc_F007FC
F02D80  60 28                   bra.b    loc_F02DAA

loc_F02D82:
F02D82  20 29 00 04             move.l   $4(a1), d0
F02D86  67 24                   beq.b    loc_F02DAC
F02D88  24 40                   movea.l  d0, a2
F02D8A  23 52 00 04             move.l   (a2), $4(a1)
F02D8E  46 d7                   move.w   (a7), sr
F02D90  25 4e 00 04             move.l   a6, $4(a2)
F02D94  42 6a 00 14             clr.w    $14(a2)
F02D98  25 7c 21 44 4c 59 00 16  move.l   #$21444c59, $16(a2)
F02DA0  2d 4a 00 58             move.l   a2, $58(a6)
F02DA4  46 d7                   move.w   (a7), sr
F02DA6  61 00 e3 64             bsr.w    loc_F0110C

loc_F02DAA:
F02DAA  4e 73                   rte      

loc_F02DAC:
F02DAC  46 d7                   move.w   (a7), sr
F02DAE  3d 7c 00 05 01 02       move.w   #$5, $102(a6)
F02DB4  60 f4                   bra.b    loc_F02DAA
F02DB6  41 d6                   DC.W     0x41d6
F02DB8  61 00                   DC.W     0x6100
F02DBA  da 4a                   DC.W     0xda4a
F02DBC  4e 73                   DC.W     0x4e73  ; 'Ns'
F02DBE  08 2e                   DC.W     0x082e
F02DC0  00 0f                   DC.W     0x000f
F02DC2  00 28                   DC.W     0x0028
F02DC4  66 10                   DC.W     0x6610
F02DC6  08 28                   DC.W     0x0828
F02DC8  00 0f                   DC.W     0x000f
F02DCA  00 28                   DC.W     0x0028
F02DCC  67 08                   DC.W     0x6708
F02DCE  06 6e                   DC.W     0x066e
F02DD0  00 09                   DC.W     0x0009
F02DD2  01 02                   DC.W     0x0102
F02DD4  4e 73                   DC.W     0x4e73  ; 'Ns'
F02DD6  10 2c 00 08             move.b   $8(a4), d0
F02DDA  b0 28 00 25             cmp.b    $25(a0), d0
F02DDE  63 12                   bls.b    loc_F02DF2
F02DE0  42 ae 01 20             clr.l    $120(a6)
F02DE4  1d 68 00 25 01 23       move.b   $25(a0), $123(a6)
F02DEA  06 6e 00 0a 01 02       addi.w   #$a, $102(a6)
F02DF0  4e 73                   rte      

loc_F02DF2:
F02DF2  11 40 00 24             move.b   d0, $24(a0)
F02DF6  11 40 00 26             move.b   d0, $26(a0)
F02DFA  4e 73                   rte      
F02DFC  4a 94                   DC.W     0x4a94
F02DFE  66 40 22 2c             DC.B     "f@\","  ; 4 bytes
F02E02  00 04                   DC.W     0x0004
F02E04  67 08                   DC.W     0x6708
F02E06  08 2e                   DC.W     0x082e
F02E08  00 0f                   DC.W     0x000f
F02E0A  00 28                   DC.W     0x0028
F02E0C  66 04                   DC.W     0x6604
F02E0E  22 2e 00 14             move.l   $14(a6), d1
F02E12  2a 79 00 00 0c 10       movea.l  $c10.l, a5

loc_F02E18:
F02E18  bb fc 00 00 00 00       cmpa.l   #$0, a5
F02E1E  67 28                   beq.b    loc_F02E48
F02E20  b2 ad 00 14             cmp.l    $14(a5), d1
F02E24  66 14                   bne.b    loc_F02E3A
F02E26  08 2d 00 0f 00 28       btst.b   #$f, $28(a5)
F02E2C  66 0c                   bne.b    loc_F02E3A
F02E2E  bd cd                   cmpa.l   a5, a6
F02E30  67 08                   beq.b    loc_F02E3A
F02E32  08 ed 00 07 00 2d       bset.b   #$7, $2d(a5)
F02E38  67 44                   beq.b    loc_F02E7E

loc_F02E3A:
F02E3A  2a 6d 00 04             movea.l  $4(a5), a5
F02E3E  60 d8                   bra.b    loc_F02E18
F02E40  41 d4                   lea.l    (a4), a0
F02E42  61 00 e8 ca             bsr.w    loc_F0170E
F02E46  60 0a                   bra.b    loc_F02E52

loc_F02E48:
F02E48  42 ae 01 20             clr.l    $120(a6)
F02E4C  56 6e 01 02             addq.w   #$3, $102(a6)
F02E50  4e 73                   rte      

loc_F02E52:
F02E52  2a 48                   movea.l  a0, a5
F02E54  bd cd                   cmpa.l   a5, a6
F02E56  67 10                   beq.b    loc_F02E68
F02E58  08 2d 00 0f 00 28       btst.b   #$f, $28(a5)
F02E5E  67 10                   beq.b    loc_F02E70
F02E60  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F02E66  66 08                   bne.b    loc_F02E70

loc_F02E68:
F02E68  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F02E6E  4e 73                   rte      

loc_F02E70:
F02E70  08 ed 00 07 00 2d       bset.b   #$7, $2d(a5)
F02E76  67 06                   beq.b    loc_F02E7E
F02E78  5c 6e 01 02             addq.w   #$6, $102(a6)
F02E7C  4e 73                   rte      

loc_F02E7E:
F02E7E  30 2c 00 08             move.w   $8(a4), d0
F02E82  67 04                   beq.b    loc_F02E88
F02E84  08 c0 00 0f             bset.b   #$f, d0

loc_F02E88:
F02E88  08 ed 00 01 00 29       bset.b   #$1, $29(a5)
F02E8E  3b 40 00 2a             move.w   d0, $2a(a5)
F02E92  3b 6d 00 2c 00 2e       move.w   $2c(a5), $2e(a5)
F02E98  2d 6d 00 10 01 20       move.l   $10(a5), $120(a6)
F02E9E  2b 6e 00 10 00 b0       move.l   $10(a6), $b0(a5)
F02EA4  2b 6e 00 14 00 b4       move.l   $14(a6), $b4(a5)
F02EAA  08 ad 00 0a 00 2c       bclr.b   #$a, $2c(a5)
F02EB0  08 ad 00 06 00 2d       bclr.b   #$6, $2d(a5)
F02EB6  08 ad 00 0d 00 2c       bclr.b   #$d, $2c(a5)
F02EBC  67 30                   beq.b    loc_F02EEE
F02EBE  20 6d 00 94             movea.l  $94(a5), a0
F02EC2  00 7c 07 00             ori.w    #$700, sr

loc_F02EC6:
F02EC6  4a d0                   tas.b    (a0)
F02EC8  6b fc                   bmi.b    loc_F02EC6
F02ECA  43 e8 ff e2             lea.l    -$1e(a0), a1

loc_F02ECE:
F02ECE  4a a9 00 20             tst.l    $20(a1)
F02ED2  67 14                   beq.b    loc_F02EE8
F02ED4  bb e9 00 20             cmpa.l   $20(a1), a5
F02ED8  67 06                   beq.b    loc_F02EE0
F02EDA  22 69 00 20             movea.l  $20(a1), a1
F02EDE  60 ee                   bra.b    loc_F02ECE

loc_F02EE0:
F02EE0  23 6d 00 20 00 20       move.l   $20(a5), $20(a1)
F02EE6  52 50                   addq.w   #$1, (a0)

loc_F02EE8:
F02EE8  08 90 00 0f             bclr.b   #$f, (a0)
F02EEC  46 d7                   move.w   (a7), sr

loc_F02EEE:
F02EEE  02 6d 2d ff 00 2c       andi.w   #$2dff, $2c(a5)
F02EF4  1b 7c 00 f0 00 26       move.b   #$f0, $26(a5)
F02EFA  08 ad 00 0b 00 2c       bclr.b   #$b, $2c(a5)
F02F00  67 06                   beq.b    loc_F02F08
F02F02  08 ed 00 02 00 2d       bset.b   #$2, $2d(a5)

loc_F02F08:
F02F08  00 7c 07 00             ori.w    #$700, sr
F02F0C  08 ad 00 04 00 2d       bclr.b   #$4, $2d(a5)
F02F12  67 18                   beq.b    loc_F02F2C
F02F14  20 3c 00 00 0c 08       move.l   #$c08, d0

loc_F02F1A:
F02F1A  20 40                   movea.l  d0, a0
F02F1C  20 28 00 0c             move.l   $c(a0), d0
F02F20  67 0a                   beq.b    loc_F02F2C
F02F22  b0 8d                   cmp.l    a5, d0
F02F24  66 f4                   bne.b    loc_F02F1A
F02F26  21 6d 00 0c 00 0c       move.l   $c(a5), $c(a0)

loc_F02F2C:
F02F2C  41 d5                   lea.l    (a5), a0
F02F2E  61 00 d8 90             bsr.w    loc_F007C0
F02F32  4e 73                   rte      
F02F34  08 ee                   DC.W     0x08ee
F02F36  00 01                   DC.W     0x0001
F02F38  00 29                   DC.W     0x0029
F02F3A  3d 48                   DC.W     0x3d48  ; '=H'
F02F3C  00 2a                   DC.W     0x002a
F02F3E  66 06                   DC.W     0x6606
F02F40  08 ee                   DC.W     0x08ee
F02F42  00 0f                   DC.W     0x000f
F02F44  00 2a                   DC.W     0x002a

loc_F02F46:
F02F46  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F02F4C  67 0c                   beq.b    loc_F02F5A
F02F4E  08 2e 00 0d 00 28       btst.b   #$d, $28(a6)
F02F54  67 04                   beq.b    loc_F02F5A
F02F56  61 00 d2 2e             bsr.w    loc_F00186

loc_F02F5A:
F02F5A  08 2e 00 07 00 2d       btst.b   #$7, $2d(a6)
F02F60  67 0e                   beq.b    loc_F02F70
F02F62  60 24                   bra.b    loc_F02F88

loc_F02F64:
F02F64  08 2e 00 01 00 29       btst.b   #$1, $29(a6)
F02F6A  66 da                   bne.b    loc_F02F46
F02F6C  3d 48 00 2a             move.w   a0, $2a(a6)

loc_F02F70:
F02F70  3d 6e 00 2c 00 2e       move.w   $2c(a6), $2e(a6)
F02F76  08 ee 00 07 00 2d       bset.b   #$7, $2d(a6)
F02F7C  2d 6e 00 10 00 b0       move.l   $10(a6), $b0(a6)
F02F82  2d 6e 00 14 00 b4       move.l   $14(a6), $b4(a6)

loc_F02F88:
F02F88  28 4e                   movea.l  a6, a4
F02F8A  22 78 0c 2c             movea.l  $c2c.w, a1
F02F8E  45 e9 00 08             lea.l    $8(a1), a2

loc_F02F92:
F02F92  26 4a                   movea.l  a2, a3

loc_F02F94:
F02F94  20 13                   move.l   (a3), d0
F02F96  67 10                   beq.b    loc_F02FA8
F02F98  24 40                   movea.l  d0, a2
F02F9A  b9 ea 00 04             cmpa.l   $4(a2), a4
F02F9E  66 f2                   bne.b    loc_F02F92
F02FA0  26 92                   move.l   (a2), (a3)
F02FA2  61 00 e1 4c             bsr.w    loc_F010F0
F02FA6  60 ec                   bra.b    loc_F02F94

loc_F02FA8:
F02FA8  08 2c 00 00 00 29       btst.b   #$0, $29(a4)
F02FAE  67 04                   beq.b    loc_F02FB4
F02FB0  61 00 f2 1c             bsr.w    loc_F021CE

loc_F02FB4:
F02FB4  20 2c 00 54             move.l   $54(a4), d0
F02FB8  67 26                   beq.b    loc_F02FE0
F02FBA  20 40                   movea.l  d0, a0
F02FBC  42 a8 00 08             clr.l    $8(a0)
F02FC0  21 78 0e 34 00 04       move.l   $e34.w, $4(a0)
F02FC6  21 c8 0e 34             move.l   a0, $e34.w
F02FCA  20 28 00 16             move.l   $16(a0), d0

loc_F02FCE:
F02FCE  67 0a                   beq.b    loc_F02FDA
F02FD0  20 40                   movea.l  d0, a0
F02FD2  46 90                   not.l    (a0)
F02FD4  20 28 00 10             move.l   $10(a0), d0
F02FD8  60 f4                   bra.b    loc_F02FCE

loc_F02FDA:
F02FDA  28 bc 21 74 63 62       move.l   #$21746362, (a4)

loc_F02FE0:
F02FE0  26 2c 00 10             move.l   $10(a4), d3
F02FE4  28 2c 00 14             move.l   $14(a4), d4
F02FE8  08 ec 00 02 00 29       bset.b   #$2, $29(a4)
F02FEE  22 78 0c 10             movea.l  $c10.w, a1

loc_F02FF2:
F02FF2  08 29 00 07 00 2d       btst.b   #$7, $2d(a1)
F02FF8  66 32                   bne.b    loc_F0302C
F02FFA  b8 a9 00 14             cmp.l    $14(a1), d4
F02FFE  66 06                   bne.b    loc_F03006
F03000  08 ac 00 02 00 29       bclr.b   #$2, $29(a4)

loc_F03006:
F03006  08 2c 00 05 00 29       btst.b   #$5, $29(a4)
F0300C  67 1e                   beq.b    loc_F0302C
F0300E  08 29 00 0a 00 2c       btst.b   #$a, $2c(a1)
F03014  67 16                   beq.b    loc_F0302C
F03016  b6 a9 01 40             cmp.l    $140(a1), d3
F0301A  66 10                   bne.b    loc_F0302C
F0301C  b8 a9 01 44             cmp.l    $144(a1), d4
F03020  66 0a                   bne.b    loc_F0302C
F03022  3e 3c 00 40             move.w   #$40, d7
F03026  41 d1                   lea.l    (a1), a0
F03028  61 00 d7 fa             bsr.w    loc_F00824

loc_F0302C:
F0302C  22 69 00 04             movea.l  $4(a1), a1
F03030  20 09                   move.l   a1, d0
F03032  66 be                   bne.b    loc_F02FF2
F03034  08 2c 00 06 00 29       btst.b   #$6, $29(a4)
F0303A  67 06                   beq.b    loc_F03042
F0303C  61 00 05 26             bsr.w    loc_F03564
F03040  4e 71                   nop      

loc_F03042:
F03042  61 00 0a ec             bsr.w    loc_F03B30
F03046  08 2c 00 07 00 29       btst.b   #$7, $29(a4)
F0304C  67 04                   beq.b    loc_F03052
F0304E  61 00 04 44             bsr.w    loc_F03494

loc_F03052:
F03052  7e 01                   moveq    #$1, d7

loc_F03054:
F03054  43 f8 0c 9a             lea.l    $c9a.w, a1
F03058  45 f8 0c aa             lea.l    $caa.w, a2
F0305C  22 07                   move.l   d7, d1
F0305E  c2 fc 00 16             mulu.w   #$16, d1
F03062  0c 31 00 02 70 00       cmpi.b   #$2, (a1, d7.w)
F03068  66 1c                   bne.b    loc_F03086
F0306A  08 32 00 0e 10 14       btst.b   #$e, $14(a2, d1.w)
F03070  67 14                   beq.b    loc_F03086
F03072  2f 07                   move.l   d7, -(a7)
F03074  61 00 dd 2e             bsr.w    loc_F00DA4
F03078  2e 1f                   move.l   (a7)+, d7
F0307A  08 2c 00 0b 00 2c       btst.b   #$b, $2c(a4)
F03080  67 04                   beq.b    loc_F03086
F03082  61 00 d7 90             bsr.w    loc_F00814

loc_F03086:
F03086  52 87                   addq.l   #$1, d7
F03088  0c 87 00 00 00 0f       cmpi.l   #$f, d7
F0308E  6f c4                   ble.b    loc_F03054
F03090  46 d7                   move.w   (a7), sr
F03092  61 00 f3 6a             bsr.w    loc_F023FE
F03096  61 00 ea d8             bsr.w    loc_F01B70
F0309A  4a ac 00 18             tst.l    $18(a4)
F0309E  67 48                   beq.b    loc_F030E8
F030A0  34 3c 18 05             move.w   #$1805, d2
F030A4  48 42                   swap     d2
F030A6  34 2c 00 10             move.w   $10(a4), d2
F030AA  26 2c 00 12             move.l   $12(a4), d3
F030AE  38 2c 00 16             move.w   $16(a4), d4
F030B2  48 44                   swap     d4
F030B4  38 2c 00 b0             move.w   $b0(a4), d4
F030B8  2a 2c 00 b2             move.l   $b2(a4), d5
F030BC  3c 2c 00 b6             move.w   $b6(a4), d6
F030C0  48 46                   swap     d6
F030C2  3c 3c 01 00             move.w   #$100, d6
F030C6  2e 2c 00 2a             move.l   $2a(a4), d7
F030CA  3e 2c 00 5c             move.w   $5c(a4), d7
F030CE  08 2c 00 01 00 29       btst.b   #$1, $29(a4)
F030D4  67 04                   beq.b    loc_F030DA
F030D6  3c 3c 02 00             move.w   #$200, d6

loc_F030DA:
F030DA  24 4c                   movea.l  a4, a2
F030DC  41 ec 00 18             lea.l    $18(a4), a0
F030E0  61 00 e4 da             bsr.w    loc_F015BC
F030E4  4e 71                   nop      
F030E6  28 4a                   movea.l  a2, a4

loc_F030E8:
F030E8  43 f8 0c 0c             lea.l    $c0c.w, a1

loc_F030EC:
F030EC  20 29 00 04             move.l   $4(a1), d0
F030F0  67 0e                   beq.b    loc_F03100
F030F2  b9 c0                   cmpa.l   d0, a4
F030F4  67 04                   beq.b    loc_F030FA
F030F6  22 40                   movea.l  d0, a1
F030F8  60 f2                   bra.b    loc_F030EC

loc_F030FA:
F030FA  23 6c 00 04 00 04       move.l   $4(a4), $4(a1)

loc_F03100:
F03100  42 b8 0c 0c             clr.l    $c0c.w
F03104  72 02                   moveq    #$2, d1
F03106  41 d4                   lea.l    (a4), a0
F03108  61 00 e3 8a             bsr.w    loc_F01494
F0310C  4e 73                   rte      
F0310E  61 00                   DC.W     0x6100
F03110  d0 76                   DC.W     0xd076
F03112  08 28                   DC.W     0x0828
F03114  00 07                   DC.W     0x0007
F03116  00 2d                   DC.W     0x002d
F03118  67 06                   DC.W     0x6706
F0311A  06 6e                   DC.W     0x066e
F0311C  00 0a                   DC.W     0x000a
F0311E  01 02                   DC.W     0x0102
F03120  2d 68 00 70 01 20       move.l   $70(a0), $120(a6)
F03126  3d 68 00 28 01 22       move.w   $28(a0), $122(a6)
F0312C  4e 73                   rte      
F0312E  2d 6e                   DC.W     0x2d6e  ; '-n'
F03130  01 20                   DC.W     0x0120
F03132  00 48                   DC.W     0x0048
F03134  08 ee                   DC.W     0x08ee
F03136  00 04                   DC.W     0x0004
F03138  00 29                   DC.W     0x0029
F0313A  4e 73 2d 6e             DC.B     "Ns-n"  ; 4 bytes
F0313E  01 20                   DC.W     0x0120
F03140  00 4c                   DC.W     0x004c
F03142  08 ee                   DC.W     0x08ee
F03144  00 03                   DC.W     0x0003
F03146  00 29                   DC.W     0x0029
F03148  4e 73                   DC.W     0x4e73  ; 'Ns'
F0314A  7e 01                   DC.W     0x7e01
F0314C  48 47                   DC.W     0x4847  ; 'HG'
F0314E  60 02                   DC.W     0x6002
F03150  42 87                   DC.W     0x4287
F03152  2a 4c                   movea.l  a4, a5
F03154  42 ae 01 20             clr.l    $120(a6)
F03158  42 86                   clr.l    d6
F0315A  1c 2d 00 09             move.b   $9(a5), d6
F0315E  0c 06 00 01             cmpi.b   #$1, d6
F03162  67 2e                   beq.b    loc_F03192
F03164  6d 1c                   blt.b    loc_F03182
F03166  0c 06 00 03             cmpi.b   #$3, d6
F0316A  6e 16                   bgt.b    loc_F03182
F0316C  4a 87                   tst.l    d7
F0316E  67 24                   beq.b    loc_F03194
F03170  1e 2d 00 08             move.b   $8(a5), d7
F03174  08 07 00 07             btst.b   #$7, d7
F03178  67 1a                   beq.b    loc_F03194
F0317A  06 6e 00 10 01 02       addi.w   #$10, $102(a6)
F03180  60 06                   bra.b    loc_F03188

loc_F03182:
F03182  06 6e 00 0f 01 02       addi.w   #$f, $102(a6)

loc_F03188:
F03188  60 00 01 6c             bra.w    loc_F032F6

loc_F0318C:
F0318C  5c 6e 01 02             addq.w   #$6, $102(a6)
F03190  60 f6                   bra.b    loc_F03188

loc_F03192:
F03192  42 87                   clr.l    d7

loc_F03194:
F03194  28 4e                   movea.l  a6, a4
F03196  20 55                   movea.l  (a5), a0
F03198  61 00 e6 dc             bsr.w    loc_F01876
F0319C  60 0a                   bra.b    loc_F031A8
F0319E  4a 80                   DC.W     0x4a80
F031A0  66 4e                   DC.W     0x664e  ; 'fN'
F031A2  5a 6e                   DC.W     0x5a6e  ; 'Zn'
F031A4  01 02                   DC.W     0x0102
F031A6  60 e0                   DC.W     0x60e0

loc_F031A8:
F031A8  2d 40 01 20             move.l   d0, $120(a6)
F031AC  4a 87                   tst.l    d7
F031AE  67 d8                   beq.b    loc_F03188
F031B0  0c 06 00 03             cmpi.b   #$3, d6
F031B4  67 d6                   beq.b    loc_F0318C

loc_F031B6:
F031B6  26 00                   move.l   d0, d3
F031B8  bc 31 30 0f             cmp.b    $f(a1, d3.w), d6
F031BC  66 00 01 32             bne.w    loc_F032F0
F031C0  4a 71 30 0c             tst.w    $c(a1, d3.w)
F031C4  6c 06                   bge.b    loc_F031CC
F031C6  20 31 30 10             move.l   $10(a1, d3.w), d0
F031CA  60 ea                   bra.b    loc_F031B6

loc_F031CC:
F031CC  13 87 30 0e             move.b   d7, $e(a1, d3.w)
F031D0  4a 31 30 11             tst.b    $11(a1, d3.w)
F031D4  6b 06                   bmi.b    loc_F031DC
F031D6  13 87 30 11             move.b   d7, $11(a1, d3.w)
F031DA  60 ac                   bra.b    loc_F03188

loc_F031DC:
F031DC  4a 07                   tst.b    d7
F031DE  67 a8                   beq.b    loc_F03188

loc_F031E0:
F031E0  41 f1 30 10             lea.l    $10(a1, d3.w), a0
F031E4  61 00 d5 a2             bsr.w    loc_F00788
F031E8  53 47                   subq.w   #$1, d7
F031EA  66 f4                   bne.b    loc_F031E0

loc_F031EC:
F031EC  60 00 01 08             bra.w    loc_F032F6
F031F0  08 ee 00 07 00 29       bset.b   #$7, $29(a6)
F031F6  2d 40 01 20             move.l   d0, $120(a6)
F031FA  26 00                   move.l   d0, d3
F031FC  23 ae 00 10 30 00       move.l   $10(a6), (a1, d3.w)
F03202  23 ae 00 14 30 04       move.l   $14(a6), $4(a1, d3.w)
F03208  23 88 30 08             move.l   a0, $8(a1, d3.w)
F0320C  4a 41                   tst.w    d1
F0320E  66 40                   bne.b    loc_F03250
F03210  33 bc 00 01 30 0c       move.w   #$1, $c(a1, d3.w)
F03216  13 86 30 0f             move.b   d6, $f(a1, d3.w)
F0321A  13 87 30 0e             move.b   d7, $e(a1, d3.w)
F0321E  33 87 30 10             move.w   d7, $10(a1, d3.w)
F03222  42 b1 30 12             clr.l    $12(a1, d3.w)
F03226  33 42 00 0e             move.w   d2, $e(a1)
F0322A  0c 46 00 01             cmpi.w   #$1, d6
F0322E  66 08                   bne.b    loc_F03238
F03230  33 bc 00 01 30 10       move.w   #$1, $10(a1, d3.w)
F03236  60 b4                   bra.b    loc_F031EC

loc_F03238:
F03238  0c 46 00 02             cmpi.w   #$2, d6
F0323C  67 ae                   beq.b    loc_F031EC
F0323E  4a 87                   tst.l    d7
F03240  66 aa                   bne.b    loc_F031EC
F03242  42 b1 30 00             clr.l    (a1, d3.w)
F03246  33 bc 04 00 30 0c       move.w   #$400, $c(a1, d3.w)
F0324C  60 00 ff 46             bra.w    loc_F03194

loc_F03250:
F03250  c3 43                   exg.l    d1, d3
F03252  bc 31 30 0f             cmp.b    $f(a1, d3.w), d6
F03256  66 94                   bne.b    loc_F031EC
F03258  4a 87                   tst.l    d7
F0325A  67 08                   beq.b    loc_F03264
F0325C  0c 86 00 00 00 03       cmpi.l   #$3, d6
F03262  67 46                   beq.b    loc_F032AA

loc_F03264:
F03264  0c 86 00 00 00 02       cmpi.l   #$2, d6
F0326A  66 06                   bne.b    loc_F03272
F0326C  4a b1 30 00             tst.l    (a1, d3.w)
F03270  67 68                   beq.b    loc_F032DA

loc_F03272:
F03272  23 83 10 10             move.l   d3, $10(a1, d1.w)
F03276  33 bc ff ff 10 0c       move.w   #$ffff, $c(a1, d1.w)
F0327C  13 86 10 0f             move.b   d6, $f(a1, d1.w)
F03280  42 31 10 0e             clr.b    $e(a1, d1.w)
F03284  33 42 00 0e             move.w   d2, $e(a1)
F03288  52 71 30 0c             addq.w   #$1, $c(a1, d3.w)
F0328C  4a 87                   tst.l    d7
F0328E  66 00 ff 3c             bne.w    loc_F031CC
F03292  0c 46 00 03             cmpi.w   #$3, d6
F03296  66 00 00 5e             bne.w    loc_F032F6
F0329A  4a b1 30 00             tst.l    (a1, d3.w)
F0329E  66 56                   bne.b    loc_F032F6
F032A0  41 f1 30 10             lea.l    $10(a1, d3.w), a0
F032A4  61 00 d4 42             bsr.w    loc_F006E8
F032A8  4e 73                   rte      

loc_F032AA:
F032AA  4a b1 30 00             tst.l    (a1, d3.w)
F032AE  66 00 fe dc             bne.w    loc_F0318C
F032B2  2d 43 01 20             move.l   d3, $120(a6)
F032B6  23 ae 00 10 30 00       move.l   $10(a6), (a1, d3.w)
F032BC  52 71 30 0c             addq.w   #$1, $c(a1, d3.w)
F032C0  13 87 30 0e             move.b   d7, $e(a1, d3.w)
F032C4  60 08                   bra.b    loc_F032CE

loc_F032C6:
F032C6  41 f1 30 10             lea.l    $10(a1, d3.w), a0
F032CA  61 00 d4 bc             bsr.w    loc_F00788

loc_F032CE:
F032CE  4a 31 30 11             tst.b    $11(a1, d3.w)
F032D2  6b f2                   bmi.b    loc_F032C6
F032D4  13 87 30 11             move.b   d7, $11(a1, d3.w)
F032D8  60 1c                   bra.b    loc_F032F6

loc_F032DA:
F032DA  2d 43 01 20             move.l   d3, $120(a6)
F032DE  23 ae 00 10 30 00       move.l   $10(a6), (a1, d3.w)
F032E4  52 71 30 0c             addq.w   #$1, $c(a1, d3.w)
F032E8  4a 87                   tst.l    d7
F032EA  67 0a                   beq.b    loc_F032F6
F032EC  60 00 fe de             bra.w    loc_F031CC

loc_F032F0:
F032F0  06 6e 00 0b 01 02       addi.w   #$b, $102(a6)

loc_F032F6:
F032F6  4e 73                   rte      
F032F8  42 47                   DC.W     0x4247  ; 'BG'
F032FA  60 04                   DC.W     0x6004
F032FC  3e 3c                   DC.W     0x3e3c  ; '><'
F032FE  00 01                   DC.W     0x0001
F03300  26 2c 00 04             move.l   $4(a4), d3
F03304  22 78 0c 24             movea.l  $c24.w, a1
F03308  30 03                   move.w   d3, d0
F0330A  e0 48                   lsr.w    #$8, d0
F0330C  b0 69 00 0a             cmp.w    $a(a1), d0
F03310  6c 42                   bge.b    loc_F03354
F03312  28 14                   move.l   (a4), d4
F03314  b8 b1 30 08             cmp.l    $8(a1, d3.w), d4
F03318  66 3a                   bne.b    loc_F03354
F0331A  4a 71 30 0c             tst.w    $c(a1, d3.w)
F0331E  67 34                   beq.b    loc_F03354
F03320  0c 31 00 01 30 0f       cmpi.b   #$1, $f(a1, d3.w)
F03326  66 0a                   bne.b    loc_F03332
F03328  be 31 30 0e             cmp.b    $e(a1, d3.w), d7
F0332C  67 2c                   beq.b    loc_F0335A
F0332E  13 87 30 0e             move.b   d7, $e(a1, d3.w)

loc_F03332:
F03332  4a 71 30 0c             tst.w    $c(a1, d3.w)
F03336  6a 04                   bpl.b    loc_F0333C
F03338  26 31 30 10             move.l   $10(a1, d3.w), d3

loc_F0333C:
F0333C  4a 47                   tst.w    d7
F0333E  67 0a                   beq.b    loc_F0334A
F03340  41 f1 30 10             lea.l    $10(a1, d3.w), a0
F03344  61 00 d3 a2             bsr.w    loc_F006E8
F03348  4e 73                   rte      

loc_F0334A:
F0334A  41 f1 30 10             lea.l    $10(a1, d3.w), a0
F0334E  61 00 d4 38             bsr.w    loc_F00788
F03352  4e 73                   rte      

loc_F03354:
F03354  5e 6e 01 02             addq.w   #$7, $102(a6)
F03358  4e 73                   rte      

loc_F0335A:
F0335A  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F03360  4e 73                   rte      
F03362  2a 46 28 4e 20 55 ..    DC.B     "*F(N Ua"  ; 7 bytes
F03369  00 e5                   DC.W     0x00e5
F0336B  0c 60                   DC.W     0x0c60
F0336D  08 5e                   DC.W     0x085e
F0336F  6e 01                   DC.W     0x6e01
F03371  02 60                   DC.W     0x0260
F03373  00 01                   DC.W     0x0001
F03375  1a 26                   DC.W     0x1a26
F03377  00 22                   DC.W     0x0022
F03379  03 4a                   DC.W     0x034a
F0337B  71 10                   DC.W     0x7110
F0337D  0c 6c                   DC.W     0x0c6c
F0337F  04 26                   DC.W     0x0426
F03381  31 10                   DC.W     0x3110
F03383  10 0c                   DC.W     0x100c
F03385  31 00                   DC.W     0x3100
F03387  01 10                   DC.W     0x0110
F03389  0f 66                   DC.W     0x0f66
F0338B  0e 4a                   DC.W     0x0e4a
F0338D  31 10                   DC.W     0x3110
F0338F  0e 67                   DC.W     0x0e67
F03391  08 41                   DC.W     0x0841
F03393  f1 30                   DC.W     0xf130
F03395  10 61                   DC.W     0x1061
F03397  00 d3                   DC.W     0x00d3
F03399  f0 4a                   DC.W     0xf04a
F0339B  71 10                   DC.W     0x7110
F0339D  0c 6a                   DC.W     0x0c6a
F0339F  14 42                   DC.W     0x1442
F033A1  b1 10                   DC.W     0xb110
F033A3  00 42                   DC.W     0x0042
F033A5  71 10                   DC.W     0x7110
F033A7  0c 42                   DC.W     0x0c42
F033A9  31 30                   DC.W     0x3130  ; '10'
F033AB  0c 53                   DC.W     0x0c53
F033AD  71 30                   DC.W     0x7130  ; 'q0'
F033AF  0c 60                   DC.W     0x0c60
F033B1  00 00                   DC.W     0x0000
F033B3  dc 42                   DC.W     0xdc42
F033B5  31 30                   DC.W     0x3130  ; '10'
F033B7  0c 0c                   DC.W     0x0c0c
F033B9  31 00                   DC.W     0x3100
F033BB  03 30                   DC.W     0x0330
F033BD  0f 67                   DC.W     0x0f67
F033BF  00 00                   DC.W     0x0000
F033C1  7c 53                   DC.W     0x7c53  ; '|S'
F033C3  71 30                   DC.W     0x7130  ; 'q0'
F033C5  0c 66                   DC.W     0x0c66
F033C7  24 0c                   DC.W     0x240c
F033C9  31 00                   DC.W     0x3100
F033CB  02 30                   DC.W     0x0230
F033CD  0f 66                   DC.W     0x0f66
F033CF  00 00                   DC.W     0x0000
F033D1  ba 10                   DC.W     0xba10
F033D3  31 30                   DC.W     0x3130  ; '10'
F033D5  0e b0                   DC.W     0x0eb0
F033D7  31 30                   DC.W     0x3130  ; '10'
F033D9  11 67                   DC.W     0x1167
F033DB  00 00                   DC.W     0x0000
F033DD  ae 33                   DC.W     0xae33
F033DF  bc 04                   DC.W     0xbc04
F033E1  00 30                   DC.W     0x0030
F033E3  0c 42                   DC.W     0x0c42
F033E5  b1 30                   DC.W     0xb130
F033E7  00 60                   DC.W     0x0060
F033E9  00 00                   DC.W     0x0000
F033EB  a4 2e                   DC.W     0xa42e
F033ED  31 30                   DC.W     0x3130  ; '10'
F033EF  04 2c                   DC.W     0x042c
F033F1  31 30                   DC.W     0x3130  ; '10'
F033F3  08 42                   DC.W     0x0842
F033F5  84 34                   DC.W     0x8434
F033F7  29 00                   DC.W     0x2900
F033F9  0e 70                   DC.W     0x0e70
F033FB  14 4a                   DC.W     0x144a
F033FD  71 00                   DC.W     0x7100
F033FF  0c 6c                   DC.W     0x0c6c
F03401  2e be                   DC.W     0x2ebe
F03403  b1 00                   DC.W     0xb100
F03405  04 66                   DC.W     0x0466
F03407  28 bc                   DC.W     0x28bc
F03409  b1 00                   DC.W     0xb100
F0340B  08 66                   DC.W     0x0866
F0340D  22 4a                   DC.W     0x224a  ; '"J'
F0340F  44 67                   DC.W     0x4467  ; 'Dg'
F03411  06 23                   DC.W     0x0623
F03413  84 00                   DC.W     0x8400
F03415  10 60                   DC.W     0x1060
F03417  18 28                   DC.W     0x1828
F03419  00 33                   DC.W     0x0033
F0341B  b1 30                   DC.W     0xb130
F0341D  0c 00                   DC.W     0x0c00
F0341F  0c 33                   DC.W     0x0c33
F03421  b1 30                   DC.W     0xb130
F03423  10 00                   DC.W     0x1000
F03425  10 23                   DC.W     0x1023
F03427  b1 30                   DC.W     0xb130
F03429  12 00                   DC.W     0x1200
F0342B  12 42                   DC.W     0x1242
F0342D  71 30                   DC.W     0x7130  ; 'q0'
F0342F  0c 06                   DC.W     0x0c06
F03431  80 00                   DC.W     0x8000
F03433  00 00                   DC.W     0x0000
F03435  16 53                   DC.W     0x1653
F03437  42 66                   DC.W     0x4266  ; 'Bf'
F03439  c2 60                   DC.W     0xc260
F0343B  4e 4a                   DC.W     0x4e4a  ; 'NJ'
F0343D  31 30                   DC.W     0x3130  ; '10'
F0343F  11 6a                   DC.W     0x116a
F03441  12 2a                   DC.W     0x122a
F03443  71 30                   DC.W     0x7130  ; 'q0'
F03445  12 5e                   DC.W     0x125e
F03447  6d 01                   DC.W     0x6d01
F03449  02 41                   DC.W     0x0241
F0344B  f1 30                   DC.W     0xf130
F0344D  10 61                   DC.W     0x1061
F0344F  00 d3                   DC.W     0x00d3
F03451  38 60                   DC.W     0x3860  ; '8`'
F03453  e8 2e                   DC.W     0xe82e
F03455  31 30                   DC.W     0x3130  ; '10'
F03457  04 2c                   DC.W     0x042c
F03459  31 30                   DC.W     0x3130  ; '10'
F0345B  08 34                   DC.W     0x0834
F0345D  29 00                   DC.W     0x2900
F0345F  0e 70                   DC.W     0x0e70
F03461  14 4a                   DC.W     0x144a
F03463  71 00                   DC.W     0x7100
F03465  0c 6a                   DC.W     0x0c6a
F03467  14 be                   DC.W     0x14be
F03469  b1 00                   DC.W     0xb100
F0346B  04 66                   DC.W     0x0466
F0346D  0e bc                   DC.W     0x0ebc
F0346F  b1 00                   DC.W     0xb100
F03471  08 66                   DC.W     0x0866
F03473  08 42                   DC.W     0x0842
F03475  71 00                   DC.W     0x7100
F03477  0c 42                   DC.W     0x0c42
F03479  b1 00                   DC.W     0xb100
F0347B  00 06                   DC.W     0x0006
F0347D  80 00                   DC.W     0x8000
F0347F  00 00                   DC.W     0x0000
F03481  16 53                   DC.W     0x1653
F03483  42 66                   DC.W     0x4266  ; 'Bf'
F03485  dc 42                   DC.W     0xdc42
F03487  71 30                   DC.W     0x7130  ; 'q0'
F03489  0c 42                   DC.W     0x0c42
F0348B  b1 30                   DC.W     0xb130
F0348D  00 4e                   DC.W     0x004e
F0348F  73 28                   DC.W     0x7328  ; 's('
F03491  4e 60                   DC.W     0x4e60  ; 'N`'
F03493  02 40                   DC.W     0x0240
F03495  e7 08                   DC.W     0xe708
F03497  2c 00                   DC.W     0x2c00
F03499  07 00                   DC.W     0x0700
F0349B  29 67                   DC.W     0x2967  ; ')g'
F0349D  0a 41                   DC.W     0x0a41
F0349F  f8 00                   DC.W     0xf800
F034A1  00 61                   DC.W     0x0061
F034A3  00 e3                   DC.W     0x00e3
F034A5  d2 60                   DC.W     0xd260
F034A7  02 4e                   DC.W     0x024e
F034A9  73 61                   DC.W     0x7361  ; 'sa'
F034AB  02 60                   DC.W     0x0260
F034AD  f0 40                   DC.W     0xf040
F034AF  e7 60                   DC.W     0xe760
F034B1  00 fe                   DC.W     0x00fe
F034B3  c4 24                   DC.W     0xc424
F034B5  4d 20 6c                DC.B     "M l"  ; 3 bytes
F034B8  00 08                   DC.W     0x0008
F034BA  22 2c                   DC.W     0x222c  ; '",'
F034BC  00 0c                   DC.W     0x000c
F034BE  61 00                   DC.W     0x6100
F034C0  e2 3e                   DC.W     0xe23e
F034C2  60 06                   DC.W     0x6006
F034C4  5e 6e                   DC.W     0x5e6e  ; '^n'
F034C6  01 02                   DC.W     0x0102
F034C8  4e 73                   DC.W     0x4e73  ; 'Ns'
F034CA  2a 48                   movea.l  a0, a5
F034CC  08 2a 00 06 00 29       btst.b   #$6, $29(a2)
F034D2  67 06                   beq.b    loc_F034DA
F034D4  5c 6e 01 02             addq.w   #$6, $102(a6)
F034D8  4e 73                   rte      

loc_F034DA:
F034DA  bb ca                   cmpa.l   a2, a5
F034DC  67 2e                   beq.b    loc_F0350C
F034DE  bd ca                   cmpa.l   a2, a6
F034E0  67 08                   beq.b    loc_F034EA
F034E2  08 2a 00 0f 00 2c       btst.b   #$f, $2c(a2)
F034E8  67 22                   beq.b    loc_F0350C

loc_F034EA:
F034EA  08 2e 00 0f 00 28       btst.b   #$f, $28(a6)
F034F0  66 08                   bne.b    loc_F034FA
F034F2  08 2a 00 0f 00 28       btst.b   #$f, $28(a2)
F034F8  66 12                   bne.b    loc_F0350C

loc_F034FA:
F034FA  20 6d 00 14             movea.l  $14(a5), a0
F034FE  b1 ea 00 14             cmpa.l   $14(a2), a0
F03502  67 10                   beq.b    loc_F03514
F03504  08 2d 00 0f 00 28       btst.b   #$f, $28(a5)
F0350A  66 08                   bne.b    loc_F03514

loc_F0350C:
F0350C  06 6e 00 09 01 02       addi.w   #$9, $102(a6)
F03512  4e 73                   rte      

loc_F03514:
F03514  24 3c 0c 08 00 00       move.l   #$c080000, d2
F0351A  34 2a 00 10             move.w   $10(a2), d2
F0351E  26 2a 00 12             move.l   $12(a2), d3
F03522  28 2a 00 16             move.l   $16(a2), d4
F03526  38 3c 00 01             move.w   #$1, d4
F0352A  41 d5                   lea.l    (a5), a0
F0352C  61 00 e0 aa             bsr.w    loc_F015D8
F03530  60 06                   bra.b    loc_F03538
F03532  5a 6e                   DC.W     0x5a6e  ; 'Zn'
F03534  01 02                   DC.W     0x0102
F03536  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F03538:
F03538  08 ed 00 05 00 29       bset.b   #$5, $29(a5)
F0353E  08 ea 00 06 00 29       bset.b   #$6, $29(a2)
F03544  08 ea 00 0a 00 2c       bset.b   #$a, $2c(a2)
F0354A  25 6d 00 10 01 40       move.l   $10(a5), $140(a2)
F03550  25 6d 00 14 01 44       move.l   $14(a5), $144(a2)
F03556  bd ca                   cmpa.l   a2, a6
F03558  66 02                   bne.b    loc_F0355C
F0355A  4e 73                   rte      

loc_F0355C:
F0355C  3f 7c 00 02 00 06       move.w   #$2, $6(a7)
F03562  4e 73                   rte      

loc_F03564:
F03564  40 e7                   move.w   sr, -(a7)
F03566  24 4c                   movea.l  a4, a2
F03568  08 aa 00 0a 00 2c       bclr.b   #$a, $2c(a2)
F0356E  60 12                   bra.b    loc_F03582
F03570  24 48                   DC.W     0x2448  ; '$H'
F03572  08 2a                   DC.W     0x082a
F03574  00 06                   DC.W     0x0006
F03576  00 29                   DC.W     0x0029
F03578  66 08                   DC.W     0x6608
F0357A  06 6e                   DC.W     0x066e
F0357C  00 0a                   DC.W     0x000a
F0357E  01 02                   DC.W     0x0102
F03580  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F03582:
F03582  24 3c 0c 08 00 00       move.l   #$c080000, d2
F03588  34 2a 00 10             move.w   $10(a2), d2
F0358C  26 2a 00 12             move.l   $12(a2), d3
F03590  28 2a 00 16             move.l   $16(a2), d4
F03594  38 3c 00 02             move.w   #$2, d4
F03598  41 ea 01 40             lea.l    $140(a2), a0
F0359C  61 00 e0 1e             bsr.w    loc_F015BC
F035A0  4e 71                   nop      
F035A2  28 4a                   movea.l  a2, a4
F035A4  08 aa 00 06 00 29       bclr.b   #$6, $29(a2)
F035AA  08 aa 00 0f 00 fa       bclr.b   #$f, $fa(a2)
F035B0  42 aa 01 48             clr.l    $148(a2)
F035B4  08 aa 00 0a 00 2c       bclr.b   #$a, $2c(a2)
F035BA  66 02                   bne.b    loc_F035BE
F035BC  4e 73                   rte      

loc_F035BE:
F035BE  41 d2                   lea.l    (a2), a0
F035C0  61 00 d1 fe             bsr.w    loc_F007C0
F035C4  4e 73                   rte      
F035C6  10 28                   DC.W     0x1028
F035C8  01 48                   DC.W     0x0148
F035CA  21 6c                   DC.W     0x216c  ; '!l'
F035CC  00 08                   DC.W     0x0008
F035CE  01 48                   DC.W     0x0148
F035D0  02 00                   DC.W     0x0200
F035D2  00 38                   DC.W     0x0038
F035D4  02 28                   DC.W     0x0228
F035D6  00 07                   DC.W     0x0007
F035D8  01 48                   DC.W     0x0148
F035DA  81 28                   DC.W     0x8128
F035DC  01 48                   DC.W     0x0148
F035DE  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F035E0:
F035E0  08 2d 00 06 00 29       btst.b   #$6, $29(a5)
F035E6  67 2e                   beq.b    loc_F03616
F035E8  20 2d 01 40             move.l   $140(a5), d0
F035EC  b0 ae 00 10             cmp.l    $10(a6), d0
F035F0  66 24                   bne.b    loc_F03616
F035F2  20 2d 01 44             move.l   $144(a5), d0
F035F6  b0 ae 00 14             cmp.l    $14(a6), d0
F035FA  66 1a                   bne.b    loc_F03616
F035FC  2a 05                   move.l   d5, d5
F035FE  2c 2b 00 08             move.l   $8(a3), d6
F03602  20 6e 00 36             movea.l  $36(a6), a0
F03606  61 00 e1 54             bsr.w    loc_F0175C
F0360A  4e 75                   rts      
F0360C  4e 71                   DC.W     0x4e71  ; 'Nq'
F0360E  06 6e                   DC.W     0x066e
F03610  00 0c                   DC.W     0x000c
F03612  01 02                   DC.W     0x0102
F03614  60 06                   DC.W     0x6006

loc_F03616:
F03616  06 6e 00 0a 01 02       addi.w   #$a, $102(a6)
F0361C  58 8f                   addq.l   #$4, a7
F0361E  4e 73                   rte      
F03620  26 46 7a 60 61          DC.B     "&Fz`a"  ; 5 bytes
F03625  00 ff                   DC.W     0x00ff
F03627  ba 28                   DC.W     0xba28
F03629  46 43                   DC.W     0x4643  ; 'FC'
F0362B  ed 01                   DC.W     0xed01
F0362D  00 30                   DC.W     0x0030
F0362F  3c 00                   DC.W     0x3c00
F03631  10 28                   DC.W     0x1028
F03633  d9 53                   DC.W     0xd953
F03635  40 66                   DC.W     0x4066  ; '@f'
F03637  fa 28                   DC.W     0xfa28
F03639  ed 00                   DC.W     0xed00
F0363B  fc 38                   DC.W     0xfc38
F0363D  ed 00                   DC.W     0xed00
F0363F  fa 20                   DC.W     0xfa20
F03641  2d 01                   DC.W     0x2d01
F03643  48 02                   DC.W     0x4802
F03645  80 01                   DC.W     0x8001
F03647  ff ff                   DC.W     0xffff
F03649  ff 28                   DC.W     0xff28
F0364B  c0 28                   DC.W     0xc028
F0364D  ed 00                   DC.W     0xed00
F0364F  2c 30                   DC.W     0x2c30  ; ',0'
F03651  2d 01                   DC.W     0x2d01
F03653  48 02                   DC.W     0x4802
F03655  40 f8                   DC.W     0x40f8
F03657  00 38                   DC.W     0x0038
F03659  c0 28                   DC.W     0xc028
F0365B  ed 01                   DC.W     0xed01
F0365D  50 28                   DC.W     0x5028  ; 'P('
F0365F  ed 01                   DC.W     0xed01
F03661  54 28                   DC.W     0x5428  ; 'T('
F03663  ed 01                   DC.W     0xed01
F03665  4c 28                   DC.W     0x4c28  ; 'L('
F03667  ed 01                   DC.W     0xed01
F03669  58 4e                   DC.W     0x584e  ; 'XN'
F0366B  73 26                   DC.W     0x7326  ; 's&'
F0366D  46 08                   DC.W     0x4608
F0366F  2d 00                   DC.W     0x2d00
F03671  0a 00                   DC.W     0x0a00
F03673  2c 66                   DC.W     0x2c66  ; ',f'
F03675  08 06                   DC.W     0x0806
F03677  6d 00                   DC.W     0x6d00
F03679  0a 01                   DC.W     0x0a01
F0367B  02 4e                   DC.W     0x024e
F0367D  73 7a                   DC.W     0x737a  ; 'sz'
F0367F  4e 61                   DC.W     0x4e61  ; 'Na'
F03681  00 ff                   DC.W     0x00ff
F03683  5e 28                   DC.W     0x5e28  ; '^('
F03685  46 43                   DC.W     0x4643  ; 'FC'
F03687  ed 01                   DC.W     0xed01
F03689  00 30                   DC.W     0x0030
F0368B  3c 00                   DC.W     0x3c00
F0368D  10 22                   DC.W     0x1022
F0368F  dc 53                   DC.W     0xdc53
F03691  40 66                   DC.W     0x4066  ; '@f'
F03693  fa 2b                   DC.W     0xfa2b
F03695  6d 01                   DC.W     0x6d01
F03697  00 00                   DC.W     0x0000
F03699  74 2b                   DC.W     0x742b  ; 't+'
F0369B  6d 01                   DC.W     0x6d01
F0369D  20 00                   DC.W     0x2000
F0369F  94 2b                   DC.W     0x942b
F036A1  5c 00                   DC.W     0x5c00
F036A3  fc 30                   DC.W     0xfc30
F036A5  1c 1c                   DC.W     0x1c1c
F036A7  2d 01                   DC.W     0x2d01
F036A9  48 2b                   DC.W     0x482b  ; 'H+'
F036AB  5c 01                   DC.W     0x5c01
F036AD  48 02                   DC.W     0x4802
F036AF  2d 00                   DC.W     0x2d00
F036B1  03 01                   DC.W     0x0301
F036B3  48 02                   DC.W     0x4802
F036B5  06 00                   DC.W     0x0600
F036B7  f8 8d                   DC.W     0xf88d
F036B9  2d 01                   DC.W     0x2d01
F036BB  48 1b                   DC.W     0x481b
F036BD  40 00                   DC.W     0x4000
F036BF  fb 4e                   DC.W     0xfb4e
F036C1  73 26                   DC.W     0x7326  ; 's&'
F036C3  4c 08                   DC.W     0x4c08
F036C5  2d 00                   DC.W     0x2d00
F036C7  0a 00                   DC.W     0x0a00
F036C9  2c 66                   DC.W     0x2c66  ; ',f'
F036CB  08 06                   DC.W     0x0806
F036CD  6d 00                   DC.W     0x6d00
F036CF  0a 01                   DC.W     0x0a01
F036D1  02 4e                   DC.W     0x024e
F036D3  73 7a                   DC.W     0x737a  ; 'sz'
F036D5  12 61                   DC.W     0x1261
F036D7  00 ff                   DC.W     0x00ff
F036D9  08 28                   DC.W     0x0828
F036DB  46 08                   DC.W     0x4608
F036DD  ad 00                   DC.W     0xad00
F036DF  0f 00                   DC.W     0x0f00
F036E1  fa 2b                   DC.W     0xfa2b
F036E3  6c 00                   DC.W     0x6c00
F036E5  02 01                   DC.W     0x0201
F036E7  50 2b                   DC.W     0x502b  ; 'P+'
F036E9  6c 00                   DC.W     0x6c00
F036EB  06 01                   DC.W     0x0601
F036ED  54 2b                   DC.W     0x542b  ; 'T+'
F036EF  6c 00                   DC.W     0x6c00
F036F1  0a 01                   DC.W     0x0a01
F036F3  4c 2b                   DC.W     0x4c2b  ; 'L+'
F036F5  6c 00                   DC.W     0x6c00
F036F7  0e 01                   DC.W     0x0e01
F036F9  58 42                   DC.W     0x5842  ; 'XB'
F036FB  6d 01                   DC.W     0x6d01
F036FD  58 02                   DC.W     0x5802
F036FF  2d 00                   DC.W     0x2d00
F03701  03 01                   DC.W     0x0301
F03703  48 1e                   DC.W     0x481e
F03705  14 02                   DC.W     0x1402
F03707  07 00                   DC.W     0x0700
F03709  38 8f                   DC.W     0x388f
F0370B  2d 01                   DC.W     0x2d01
F0370D  48 4a                   DC.W     0x484a  ; 'HJ'
F0370F  07 67                   DC.W     0x0767
F03711  3a 08                   DC.W     0x3a08
F03713  ed 00                   DC.W     0xed00
F03715  0f 00                   DC.W     0x0f00
F03717  fa 2e                   DC.W     0xfa2e
F03719  2d 01                   DC.W     0x2d01
F0371B  48 08                   DC.W     0x4808
F0371D  07 00                   DC.W     0x0700
F0371F  1d 67                   DC.W     0x1d67
F03721  2a 7a                   DC.W     0x2a7a  ; '*z'
F03723  04 2c                   DC.W     0x042c
F03725  2d 01                   DC.W     0x2d01
F03727  50 20                   DC.W     0x5020  ; 'P '
F03729  6d 00                   DC.W     0x6d00
F0372B  36 61                   DC.W     0x3661  ; '6a'
F0372D  00 e0                   DC.W     0x00e0
F0372F  2e 60                   DC.W     0x2e60  ; '.`'
F03731  0a 4e                   DC.W     0x0a4e
F03733  71 06                   DC.W     0x7106
F03735  6e 00                   DC.W     0x6e00
F03737  0f 01                   DC.W     0x0f01
F03739  02 4e                   DC.W     0x024e
F0373B  73 08                   DC.W     0x7308
F0373D  86 00                   DC.W     0x8600
F0373F  00 28                   DC.W     0x0028
F03741  46 08                   DC.W     0x4608
F03743  07 00                   DC.W     0x0700
F03745  1c 66                   DC.W     0x1c66
F03747  04 2b                   DC.W     0x042b
F03749  54 01                   DC.W     0x5401
F0374B  54 08                   DC.W     0x5408
F0374D  ad 00                   DC.W     0xad00
F0374F  0a 00                   DC.W     0x0a00
F03751  2c 30                   DC.W     0x2c30  ; ',0'
F03753  2d 00                   DC.W     0x2d00
F03755  2c 02                   DC.W     0x2c02
F03757  40 ff                   DC.W     0x40ff
F03759  00 66                   DC.W     0x0066
F0375B  06 41                   DC.W     0x0641
F0375D  d5 61                   DC.W     0xd561
F0375F  00 d0                   DC.W     0x00d0
F03761  9c 4e                   DC.W     0x9c4e
F03763  73 2c                   DC.W     0x732c  ; 's,'
F03765  08 2a                   DC.W     0x082a
F03767  48 22 79                DC.B     "H\"y"  ; 3 bytes
F0376A  00 00                   DC.W     0x0000
F0376C  0c 30                   DC.W     0x0c30
F0376E  20 09                   DC.W     0x2009
F03770  67 16                   DC.W     0x6716
F03772  20 69                   DC.W     0x2069  ; ' i'
F03774  00 04                   DC.W     0x0004
F03776  91 c9                   DC.W     0x91c9
F03778  2a 08                   DC.W     0x2a08
F0377A  24 08                   DC.W     0x2408
F0377C  20 6e                   DC.W     0x206e  ; ' n'
F0377E  00 36                   DC.W     0x0036
F03780  61 00                   DC.W     0x6100
F03782  df da                   DC.W     0xdfda
F03784  60 0a                   DC.W     0x600a
F03786  4e 71                   DC.W     0x4e71  ; 'Nq'
F03788  06 6e 00 0c 01 02       addi.w   #$c, $102(a6)
F0378E  4e 73                   rte      
F03790  24 46                   movea.l  d6, a2
F03792  26 02                   move.l   d2, d3
F03794  e4 8a                   lsr.l    #$2, d2

loc_F03796:
F03796  24 d9                   move.l   (a1)+, (a2)+
F03798  53 82                   subq.l   #$1, d2
F0379A  66 fa                   bne.b    loc_F03796
F0379C  24 46                   movea.l  d6, a2
F0379E  28 4d                   movea.l  a5, a4
F037A0  22 79 00 00 0c 30       movea.l  $c30.l, a1
F037A6  26 51                   movea.l  (a1), a3
F037A8  97 c9                   suba.l   a1, a3
F037AA  d9 cb                   adda.l   a3, a4
F037AC  24 cc                   move.l   a4, (a2)+
F037AE  db c3                   adda.l   d3, a5
F037B0  24 cd                   move.l   a5, (a2)+
F037B2  4e 73                   rte      
F037B4  08 2e                   DC.W     0x082e
F037B6  00 0f                   DC.W     0x000f
F037B8  00 28                   DC.W     0x0028
F037BA  66 08                   DC.W     0x6608
F037BC  06 6e                   DC.W     0x066e
F037BE  00 09                   DC.W     0x0009
F037C0  01 02                   DC.W     0x0102
F037C2  4e 73                   DC.W     0x4e73  ; 'Ns'
F037C4  4c dc 00 03             movem.l  (a4)+, d0-d1
F037C8  2e 3c 05 26 5c 00       move.l   #$5265c00, d7

loc_F037CE:
F037CE  b2 87                   cmp.l    d7, d1
F037D0  65 06                   bcs.b    loc_F037D8
F037D2  92 87                   sub.l    d7, d1
F037D4  52 80                   addq.l   #$1, d0
F037D6  60 f6                   bra.b    loc_F037CE

loc_F037D8:
F037D8  26 01                   move.l   d1, d3
F037DA  28 00                   move.l   d0, d4
F037DC  00 7c 07 00             ori.w    #$700, sr
F037E0  96 b8 0c 42             sub.l    $c42.w, d3
F037E4  98 b8 0c 3e             sub.l    $c3e.w, d4
F037E8  21 c0 0c 3e             move.l   d0, $c3e.w
F037EC  21 c1 0c 42             move.l   d1, $c42.w
F037F0  d7 b8 0c 46             add.l    d3, $c46.w
F037F4  d9 b8 0c 4a             add.l    d4, $c4a.w
F037F8  46 d7                   move.w   (a7), sr
F037FA  42 a7                   clr.l    -(a7)
F037FC  22 78 0c 2c             movea.l  $c2c.w, a1
F03800  45 e9 00 08             lea.l    $8(a1), a2

loc_F03804:
F03804  26 4a                   movea.l  a2, a3

loc_F03806:
F03806  24 53                   movea.l  (a3), a2
F03808  20 0a                   move.l   a2, d0
F0380A  67 40                   beq.b    loc_F0384C
F0380C  08 2a 00 0f 00 14       btst.b   #$f, $14(a2)
F03812  67 32                   beq.b    loc_F03846
F03814  26 92                   move.l   (a2), (a3)
F03816  24 97                   move.l   (a7), (a2)
F03818  2e 8a                   move.l   a2, (a7)
F0381A  08 2a 00 00 00 15       btst.b   #$0, $15(a2)
F03820  66 e4                   bne.b    loc_F03806
F03822  20 2a 00 0c             move.l   $c(a2), d0
F03826  67 de                   beq.b    loc_F03806
F03828  b2 aa 00 08             cmp.l    $8(a2), d1
F0382C  6e 0c                   bgt.b    loc_F0383A

loc_F0382E:
F0382E  91 aa 00 08             sub.l    d0, $8(a2)
F03832  b2 aa 00 08             cmp.l    $8(a2), d1
F03836  67 ce                   beq.b    loc_F03806
F03838  6d f4                   blt.b    loc_F0382E

loc_F0383A:
F0383A  d1 aa 00 08             add.l    d0, $8(a2)
F0383E  b2 aa 00 08             cmp.l    $8(a2), d1
F03842  6e f6                   bgt.b    loc_F0383A
F03844  60 c0                   bra.b    loc_F03806

loc_F03846:
F03846  d7 aa 00 08             add.l    d3, $8(a2)
F0384A  60 b8                   bra.b    loc_F03804

loc_F0384C:
F0384C  2e 1f                   move.l   (a7)+, d7
F0384E  67 10                   beq.b    loc_F03860

loc_F03850:
F03850  24 47                   movea.l  d7, a2
F03852  24 2a 00 08             move.l   $8(a2), d2
F03856  2e 12                   move.l   (a2), d7
F03858  61 00 d8 b2             bsr.w    loc_F0110C
F0385C  4a 87                   tst.l    d7
F0385E  66 f0                   bne.b    loc_F03850

loc_F03860:
F03860  4e 73                   rte      
F03862  61 00                   DC.W     0x6100
F03864  d7 32                   DC.W     0xd732
F03866  20 38                   DC.W     0x2038  ; ' 8'
F03868  0c 3e                   DC.W     0x0c3e
F0386A  0c 81                   DC.W     0x0c81
F0386C  05 26                   DC.W     0x0526
F0386E  5c 00                   DC.W     0x5c00
F03870  65 08                   DC.W     0x6508
F03872  04 81                   DC.W     0x0481
F03874  05 26                   DC.W     0x0526
F03876  5c 00                   DC.W     0x5c00
F03878  52 80                   DC.W     0x5280
F0387A  48 d4 00 03             movem.l  d0-d1, (a4)
F0387E  4e 73                   rte      
F03880  24 2c                   DC.W     0x242c  ; '$,'
F03882  00 0a                   DC.W     0x000a
F03884  36 2c                   DC.W     0x362c  ; '6,'
F03886  00 08                   DC.W     0x0008
F03888  7c 01                   DC.W     0x7c01
F0388A  42 84                   DC.W     0x4284
F0388C  08 03                   DC.W     0x0803
F0388E  00 0e                   DC.W     0x000e
F03890  67 0e                   DC.W     0x670e
F03892  28 2c                   DC.W     0x282c  ; '(,'
F03894  00 0e                   DC.W     0x000e
F03896  6e 08                   DC.W     0x6e08
F03898  3d 7c                   DC.W     0x3d7c  ; '=|'
F0389A  00 10                   DC.W     0x0010
F0389C  01 02                   DC.W     0x0102
F0389E  4e 73                   DC.W     0x4e73  ; 'Ns'
F038A0  42 85                   clr.l    d5
F038A2  08 03 00 0a             btst.b   #$a, d3
F038A6  67 0a                   beq.b    loc_F038B2
F038A8  2a 2c 00 16             move.l   $16(a4), d5
F038AC  66 04                   bne.b    loc_F038B2
F038AE  08 c6 00 1f             bset.b   #$1f, d6

loc_F038B2:
F038B2  61 00 d6 e2             bsr.w    loc_F00F96
F038B6  02 43 c0 00             andi.w   #$c000, d3
F038BA  67 2a                   beq.b    loc_F038E6
F038BC  42 86                   clr.l    d6
F038BE  36 2c 00 08             move.w   $8(a4), d3
F038C2  08 03 00 0b             btst.b   #$b, d3
F038C6  67 04                   beq.b    loc_F038CC
F038C8  08 83 00 0e             bclr.b   #$e, d3

loc_F038CC:
F038CC  08 03 00 0f             btst.b   #$f, d3
F038D0  67 18                   beq.b    loc_F038EA

loc_F038D2:
F038D2  b4 81                   cmp.l    d1, d2
F038D4  6c 18                   bge.b    loc_F038EE
F038D6  4a 84                   tst.l    d4
F038D8  67 04                   beq.b    loc_F038DE
F038DA  d4 84                   add.l    d4, d2
F038DC  60 f4                   bra.b    loc_F038D2

loc_F038DE:
F038DE  06 82 05 26 5c 00       addi.l   #$5265c00, d2
F038E4  60 08                   bra.b    loc_F038EE

loc_F038E6:
F038E6  36 2c 00 08             move.w   $8(a4), d3

loc_F038EA:
F038EA  24 01                   move.l   d1, d2
F038EC  d4 84                   add.l    d4, d2

loc_F038EE:
F038EE  2a 2c 00 16             move.l   $16(a4), d5
F038F2  08 03 00 0a             btst.b   #$a, d3
F038F6  66 02                   bne.b    loc_F038FA
F038F8  42 85                   clr.l    d5

loc_F038FA:
F038FA  22 78 0c 2c             movea.l  $c2c.w, a1
F038FE  45 e9 00 08             lea.l    $8(a1), a2

loc_F03902:
F03902  26 4a                   movea.l  a2, a3

loc_F03904:
F03904  24 53                   movea.l  (a3), a2
F03906  20 0a                   move.l   a2, d0
F03908  67 00 00 8c             beq.w    loc_F03996
F0390C  4a aa 00 04             tst.l    $4(a2)
F03910  66 08                   bne.b    loc_F0391A
F03912  26 92                   move.l   (a2), (a3)
F03914  61 00 d7 da             bsr.w    loc_F010F0
F03918  60 ea                   bra.b    loc_F03904

loc_F0391A:
F0391A  bb ea 00 04             cmpa.l   $4(a2), a5
F0391E  66 e2                   bne.b    loc_F03902
F03920  08 2a 00 01 00 15       btst.b   #$1, $15(a2)
F03926  66 da                   bne.b    loc_F03902
F03928  4a 86                   tst.l    d6
F0392A  6b 06                   bmi.b    loc_F03932
F0392C  ba aa 00 16             cmp.l    $16(a2), d5
F03930  66 d0                   bne.b    loc_F03902

loc_F03932:
F03932  26 92                   move.l   (a2), (a3)
F03934  4a 86                   tst.l    d6
F03936  66 24                   bne.b    loc_F0395C

loc_F03938:
F03938  25 4d 00 04             move.l   a5, $4(a2)
F0393C  25 44 00 0c             move.l   d4, $c(a2)
F03940  25 6c 00 12 00 10       move.l   $12(a4), $10(a2)
F03946  42 6a 00 1a             clr.w    $1a(a2)
F0394A  25 45 00 16             move.l   d5, $16(a2)
F0394E  08 c3 00 00             bset.b   #$0, d3
F03952  35 43 00 14             move.w   d3, $14(a2)
F03956  61 00 d7 b4             bsr.w    loc_F0110C
F0395A  4e 73                   rte      

loc_F0395C:
F0395C  52 46                   addq.w   #$1, d6
F0395E  08 03 00 01             btst.b   #$1, d3
F03962  66 08                   bne.b    loc_F0396C
F03964  08 2a 00 09 00 14       btst.b   #$9, $14(a2)
F0396A  67 1e                   beq.b    loc_F0398A

loc_F0396C:
F0396C  08 ea 00 07 00 1a       bset.b   #$7, $1a(a2)
F03972  08 aa 00 0e 00 14       bclr.b   #$e, $14(a2)
F03978  08 ea 00 01 00 15       bset.b   #$1, $15(a2)
F0397E  61 00 d7 8c             bsr.w    loc_F0110C
F03982  4a 86                   tst.l    d6
F03984  6b 00 ff 7e             bmi.w    loc_F03904
F03988  4e 73                   rte      

loc_F0398A:
F0398A  61 00 d7 64             bsr.w    loc_F010F0
F0398E  4a 86                   tst.l    d6
F03990  6b 00 ff 72             bmi.w    loc_F03904
F03994  4e 73                   rte      

loc_F03996:
F03996  4a 86                   tst.l    d6
F03998  66 1c                   bne.b    loc_F039B6
F0399A  00 7c 07 00             ori.w    #$700, sr
F0399E  20 29 00 04             move.l   $4(a1), d0
F039A2  67 0a                   beq.b    loc_F039AE
F039A4  24 40                   movea.l  d0, a2
F039A6  23 52 00 04             move.l   (a2), $4(a1)
F039AA  46 d7                   move.w   (a7), sr
F039AC  60 8a                   bra.b    loc_F03938

loc_F039AE:
F039AE  3d 7c 00 05 01 02       move.w   #$5, $102(a6)
F039B4  4e 73                   rte      

loc_F039B6:
F039B6  53 46                   subq.w   #$1, d6
F039B8  6e 06                   bgt.b    loc_F039C0
F039BA  3d 7c 00 07 01 02       move.w   #$7, $102(a6)

loc_F039C0:
F039C0  4e 73                   rte      
F039C2  3d 7c                   DC.W     0x3d7c  ; '=|'
F039C4  00 01                   DC.W     0x0001
F039C6  01 02                   DC.W     0x0102
F039C8  20 2e                   DC.W     0x202e  ; ' .'
F039CA  01 20                   DC.W     0x0120
F039CC  0c 80                   DC.W     0x0c80
F039CE  4b aa                   DC.W     0x4baa
F039D0  7b fb                   DC.W     0x7bfb
F039D2  66 3e 4a 6e             DC.B     "f>Jn"  ; 4 bytes
F039D6  00 70                   DC.W     0x0070
F039D8  67 0c                   DC.W     0x670c
F039DA  20 78                   DC.W     0x2078  ; ' x'
F039DC  0c 3a                   DC.W     0x0c3a
F039DE  08 28                   DC.W     0x0828
F039E0  00 01                   DC.W     0x0001
F039E2  00 01                   DC.W     0x0001
F039E4  66 2c                   DC.W     0x662c  ; 'f,'
F039E6  20 78 0c 08             movea.l  $c08.w, a0
F039EA  2c 20                   move.l   -(a0), d6
F039EC  7a 06                   moveq    #$6, d5
F039EE  20 6e 00 36             movea.l  $36(a6), a0
F039F2  61 00 dd 68             bsr.w    loc_F0175C
F039F6  60 04                   bra.b    loc_F039FC
F039F8  60 18                   DC.W     0x6018
F039FA  60 16                   DC.W     0x6016

loc_F039FC:
F039FC  2a 46                   movea.l  d6, a5
F039FE  42 ae 01 00             clr.l    $100(a6)
F03A02  4c ee 1f ff 01 00       movem.l  $100(a6), d0-d7/a0-a4
F03A08  4e 95                   jsr      (a5)
F03A0A  42 b8 0c 62             clr.l    $c62.w
F03A0E  2c 78 0c 0c             movea.l  $c0c.w, a6
F03A12  4e 73                   rte      
F03A14  3e 2c                   DC.W     0x3e2c  ; '>,'
F03A16  00 04                   DC.W     0x0004
F03A18  08 2e                   DC.W     0x082e
F03A1A  00 0f                   DC.W     0x000f
F03A1C  00 28                   DC.W     0x0028
F03A1E  66 04                   DC.W     0x6604
F03A20  08 87                   DC.W     0x0887
F03A22  00 0e                   DC.W     0x000e
F03A24  4a 94                   tst.l    (a4)
F03A26  67 18                   beq.b    loc_F03A40
F03A28  7a 04                   moveq    #$4, d5
F03A2A  2c 14                   move.l   (a4), d6
F03A2C  20 6e 00 36             movea.l  $36(a6), a0
F03A30  61 00 dd 2a             bsr.w    loc_F0175C
F03A34  60 0a                   bra.b    loc_F03A40
F03A36  4e 71                   DC.W     0x4e71  ; 'Nq'
F03A38  06 6e                   DC.W     0x066e
F03A3A  00 0c                   DC.W     0x000c
F03A3C  01 02                   DC.W     0x0102
F03A3E  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F03A40:
F03A40  4a ae 00 40             tst.l    $40(a6)
F03A44  66 06                   bne.b    loc_F03A4C
F03A46  58 6e 01 02             addq.w   #$4, $102(a6)
F03A4A  4e 73                   rte      

loc_F03A4C:
F03A4C  14 2c 00 04             move.b   $4(a4), d2
F03A50  02 82 00 00 00 0f       andi.l   #$f, d2
F03A56  45 f8 0c 9a             lea.l    $c9a.w, a2
F03A5A  4a 32 20 00             tst.b    (a2, d2.w)
F03A5E  67 06                   beq.b    loc_F03A66
F03A60  5c 6e 01 02             addq.w   #$6, $102(a6)
F03A64  60 3a                   bra.b    loc_F03AA0

loc_F03A66:
F03A66  15 bc 00 02 20 00       move.b   #$2, (a2, d2.w)
F03A6C  45 f8 0c aa             lea.l    $caa.w, a2
F03A70  c4 fc 00 16             mulu.w   #$16, d2
F03A74  25 8e 20 00             move.l   a6, (a2, d2.w)
F03A78  25 ae 00 14 20 04       move.l   $14(a6), $4(a2, d2.w)
F03A7E  35 bc 00 01 20 08       move.w   #$1, $8(a2, d2.w)
F03A84  42 b2 20 0a             clr.l    $a(a2, d2.w)
F03A88  25 94 20 0e             move.l   (a4), $e(a2, d2.w)
F03A8C  42 72 20 12             clr.w    $12(a2, d2.w)
F03A90  35 87 20 14             move.w   d7, $14(a2, d2.w)
F03A94  02 32 00 60 20 14       andi.b   #$60, $14(a2, d2.w)
F03A9A  08 f2 00 0f 20 14       bset.b   #$f, $14(a2, d2.w)

loc_F03AA0:
F03AA0  4e 73                   rte      
F03AA2  24 08                   DC.W     0x2408
F03AA4  02 82                   DC.W     0x0282
F03AA6  00 00                   DC.W     0x0000
F03AA8  00 0f                   DC.W     0x000f
F03AAA  45 f8                   DC.W     0x45f8
F03AAC  0c 9a                   DC.W     0x0c9a
F03AAE  0c 32                   DC.W     0x0c32
F03AB0  00 02                   DC.W     0x0002
F03AB2  20 00                   DC.W     0x2000
F03AB4  66 10                   DC.W     0x6610
F03AB6  22 02                   DC.W     0x2202
F03AB8  c2 fc                   DC.W     0xc2fc
F03ABA  00 16                   DC.W     0x0016
F03ABC  43 f8                   DC.W     0x43f8
F03ABE  0c aa                   DC.W     0x0caa
F03AC0  bd f1                   DC.W     0xbdf1
F03AC2  10 00                   DC.W     0x1000
F03AC4  67 06                   DC.W     0x6706
F03AC6  5e 6e 01 02             addq.w   #$7, $102(a6)
F03ACA  60 62                   bra.b    loc_F03B2E

loc_F03ACC:
F03ACC  26 78 0c 10             movea.l  $c10.w, a3

loc_F03AD0:
F03AD0  08 2b 00 0b 00 2c       btst.b   #$b, $2c(a3)
F03AD6  67 2c                   beq.b    loc_F03B04
F03AD8  b4 2b 00 73             cmp.b    $73(a3), d2
F03ADC  66 26                   bne.b    loc_F03B04
F03ADE  08 ab 00 02 00 2d       bclr.b   #$2, $2d(a3)
F03AE4  08 ab 00 0b 00 2c       bclr.b   #$b, $2c(a3)
F03AEA  27 7c 00 00 00 01 01 00  move.l   #$1, $100(a3)
F03AF2  e7 4a                   lsl.w    #$3, d2
F03AF4  17 42 01 00             move.b   d2, $100(a3)
F03AF8  42 2b 00 fb             clr.b    $fb(a3)
F03AFC  e6 4a                   lsr.w    #$3, d2
F03AFE  41 d3                   lea.l    (a3), a0
F03B00  61 00 cc be             bsr.w    loc_F007C0

loc_F03B04:
F03B04  26 6b 00 04             movea.l  $4(a3), a3
F03B08  20 0b                   move.l   a3, d0
F03B0A  66 c4                   bne.b    loc_F03AD0
F03B0C  42 32 20 00             clr.b    (a2, d2.w)
F03B10  42 b1 10 00             clr.l    (a1, d1.w)
F03B14  42 b1 10 0e             clr.l    $e(a1, d1.w)
F03B18  42 71 10 14             clr.w    $14(a1, d1.w)

loc_F03B1C:
F03B1C  08 31 00 0e 10 08       btst.b   #$e, $8(a1, d1.w)
F03B22  67 0a                   beq.b    loc_F03B2E
F03B24  41 f1 10 08             lea.l    $8(a1, d1.w), a0
F03B28  61 00 cc 5e             bsr.w    loc_F00788
F03B2C  60 ee                   bra.b    loc_F03B1C

loc_F03B2E:
F03B2E  4e 73                   rte      

loc_F03B30:
F03B30  40 e7                   move.w   sr, -(a7)
F03B32  45 f8 0c 9a             lea.l    $c9a.w, a2
F03B36  43 f8 0c aa             lea.l    $caa.w, a1
F03B3A  74 02                   moveq    #$2, d2

loc_F03B3C:
F03B3C  0c 32 00 02 20 00       cmpi.b   #$2, (a2, d2.w)
F03B42  66 0c                   bne.b    loc_F03B50
F03B44  22 02                   move.l   d2, d1
F03B46  c2 fc 00 16             mulu.w   #$16, d1
F03B4A  b9 f1 10 00             cmpa.l   (a1, d1.w), a4
F03B4E  67 0c                   beq.b    loc_F03B5C

loc_F03B50:
F03B50  52 82                   addq.l   #$1, d2
F03B52  0c 82 00 00 00 10       cmpi.l   #$10, d2
F03B58  6d e2                   blt.b    loc_F03B3C
F03B5A  4e 73                   rte      

loc_F03B5C:
F03B5C  61 02                   bsr.b    loc_F03B60
F03B5E  60 dc                   bra.b    loc_F03B3C

loc_F03B60:
F03B60  40 e7                   move.w   sr, -(a7)
F03B62  60 00 ff 68             bra.w    loc_F03ACC
F03B66  22 08                   DC.W     0x2208
F03B68  02 81                   DC.W     0x0281
F03B6A  00 00                   DC.W     0x0000
F03B6C  00 0f                   DC.W     0x000f
F03B6E  20 08                   DC.W     0x2008
F03B70  43 f8                   DC.W     0x43f8
F03B72  0c 9a                   DC.W     0x0c9a
F03B74  0c 31                   DC.W     0x0c31
F03B76  00 02                   DC.W     0x0002
F03B78  10 00                   DC.W     0x1000
F03B7A  66 12                   DC.W     0x6612
F03B7C  c2 fc                   DC.W     0xc2fc
F03B7E  00 16                   DC.W     0x0016
F03B80  43 f8                   DC.W     0x43f8
F03B82  0c aa                   DC.W     0x0caa
F03B84  24 31                   DC.W     0x2431  ; '$1'
F03B86  10 04                   DC.W     0x1004
F03B88  b4 ae                   DC.W     0xb4ae
F03B8A  00 14                   DC.W     0x0014
F03B8C  67 06                   DC.W     0x6706
F03B8E  5e 6e 01 02             addq.w   #$7, $102(a6)
F03B92  4e 73                   rte      
F03B94  08 00 00 07             btst.b   #$7, d0
F03B98  66 20                   bne.b    loc_F03BBA

loc_F03B9A:
F03B9A  4a f1 10 08             tas.b    $8(a1, d1.w)
F03B9E  6b fa                   bmi.b    loc_F03B9A
F03BA0  08 b1 00 0f 10 14       bclr.b   #$f, $14(a1, d1.w)
F03BA6  08 31 00 0e 10 08       btst.b   #$e, $8(a1, d1.w)
F03BAC  66 04                   bne.b    loc_F03BB2
F03BAE  42 71 10 08             clr.w    $8(a1, d1.w)

loc_F03BB2:
F03BB2  08 b1 00 0f 10 08       bclr.b   #$f, $8(a1, d1.w)
F03BB8  4e 73                   rte      

loc_F03BBA:
F03BBA  08 f1 00 0f 10 14       bset.b   #$f, $14(a1, d1.w)
F03BC0  08 b1 00 0c 10 14       bclr.b   #$c, $14(a1, d1.w)
F03BC6  67 08                   beq.b    loc_F03BD0
F03BC8  41 f1 10 08             lea.l    $8(a1, d1.w), a0
F03BCC  61 00 cb ba             bsr.w    loc_F00788

loc_F03BD0:
F03BD0  4e 73                   rte      
F03BD2  08 2d                   DC.W     0x082d
F03BD4  00 0b                   DC.W     0x000b
F03BD6  00 2c                   DC.W     0x002c
F03BD8  66 10                   DC.W     0x6610
F03BDA  08 2d                   DC.W     0x082d
F03BDC  00 02                   DC.W     0x0002
F03BDE  00 2d                   DC.W     0x002d
F03BE0  66 08                   DC.W     0x6608

loc_F03BE2:
F03BE2  06 6e 00 0a 01 02       addi.w   #$a, $102(a6)
F03BE8  4e 73                   rte      
F03BEA  12 2c 00 0a             move.b   $a(a4), d1
F03BEE  02 41 00 0f             andi.w   #$f, d1
F03BF2  b2 2d 00 73             cmp.b    $73(a5), d1
F03BF6  67 08                   beq.b    loc_F03C00
F03BF8  08 2d 00 07 00 2d       btst.b   #$7, $2d(a5)
F03BFE  67 e2                   beq.b    loc_F03BE2

loc_F03C00:
F03C00  c2 fc 00 16             mulu.w   #$16, d1
F03C04  47 f8 0c aa             lea.l    $caa.w, a3
F03C08  24 33 10 04             move.l   $4(a3, d1.w), d2
F03C0C  b4 ae 00 14             cmp.l    $14(a6), d2
F03C10  67 06                   beq.b    loc_F03C18
F03C12  5e 6e 01 02             addq.w   #$7, $102(a6)
F03C16  4e 73                   rte      

loc_F03C18:
F03C18  3e 2c 00 08             move.w   $8(a4), d7
F03C1C  08 2d 00 07 00 2d       btst.b   #$7, $2d(a5)
F03C22  67 1e                   beq.b    loc_F03C42
F03C24  02 47 0f ff             andi.w   #$fff, d7
F03C28  08 07 00 08             btst.b   #$8, d7
F03C2C  67 14                   beq.b    loc_F03C42
F03C2E  08 ad 00 02 00 2d       bclr.b   #$2, $2d(a5)
F03C34  67 1a                   beq.b    loc_F03C50
F03C36  08 2d 00 0b 00 2c       btst.b   #$b, $2c(a5)
F03C3C  67 12                   beq.b    loc_F03C50
F03C3E  53 73 10 12             subq.w   #$1, $12(a3, d1.w)

loc_F03C42:
F03C42  08 ad 00 02 00 2d       bclr.b   #$2, $2d(a5)
F03C48  66 06                   bne.b    loc_F03C50
F03C4A  08 ad 00 0b 00 2c       bclr.b   #$b, $2c(a5)

loc_F03C50:
F03C50  53 73 10 12             subq.w   #$1, $12(a3, d1.w)
F03C54  08 33 00 0f 10 14       btst.b   #$f, $14(a3, d1.w)
F03C5A  67 10                   beq.b    loc_F03C6C
F03C5C  08 b3 00 0c 10 14       bclr.b   #$c, $14(a3, d1.w)
F03C62  67 08                   beq.b    loc_F03C6C
F03C64  41 f3 10 08             lea.l    $8(a3, d1.w), a0
F03C68  61 00 cb 1e             bsr.w    loc_F00788

loc_F03C6C:
F03C6C  08 07 00 0e             btst.b   #$e, d7
F03C70  67 06                   beq.b    loc_F03C78
F03C72  1b 6c 00 0b 00 fb       move.b   $b(a4), $fb(a5)

loc_F03C78:
F03C78  08 07 00 0d             btst.b   #$d, d7
F03C7C  67 06                   beq.b    loc_F03C84
F03C7E  2b 6c 00 0c 01 00       move.l   $c(a4), $100(a5)

loc_F03C84:
F03C84  08 07 00 0c             btst.b   #$c, d7
F03C88  67 06                   beq.b    loc_F03C90
F03C8A  2b 6c 00 10 01 20       move.l   $10(a4), $120(a5)

loc_F03C90:
F03C90  08 07 00 0b             btst.b   #$b, d7
F03C94  67 10                   beq.b    loc_F03CA6

loc_F03C96:
F03C96  08 2d 00 0b 00 2c       btst.b   #$b, $2c(a5)
F03C9C  66 06                   bne.b    loc_F03CA4
F03C9E  41 d5                   lea.l    (a5), a0
F03CA0  61 00 cb 5a             bsr.w    loc_F007FC

loc_F03CA4:
F03CA4  4e 73                   rte      

loc_F03CA6:
F03CA6  08 07 00 0a             btst.b   #$a, d7
F03CAA  67 08                   beq.b    loc_F03CB4
F03CAC  08 ed 00 0e 00 2c       bset.b   #$e, $2c(a5)
F03CB2  4e 73                   rte      

loc_F03CB4:
F03CB4  08 07 00 09             btst.b   #$9, d7
F03CB8  67 dc                   beq.b    loc_F03C96
F03CBA  08 ed 00 09 00 2c       bset.b   #$9, $2c(a5)
F03CC0  4e 73                   rte      
F03CC2  08 2e                   DC.W     0x082e
F03CC4  00 0f                   DC.W     0x000f
F03CC6  00 28                   DC.W     0x0028
F03CC8  66 08                   DC.W     0x6608
F03CCA  06 6e                   DC.W     0x066e
F03CCC  00 09                   DC.W     0x0009
F03CCE  01 02                   DC.W     0x0102
F03CD0  4e 73                   DC.W     0x4e73  ; 'Ns'
F03CD2  2a 3c 00 00 02 00       move.l   #$200, d5
F03CD8  2c 2c 00 0a             move.l   $a(a4), d6
F03CDC  20 6e 00 36             movea.l  $36(a6), a0
F03CE0  61 00 da 7a             bsr.w    loc_F0175C
F03CE4  60 0a                   bra.b    loc_F03CF0
F03CE6  4e 71                   DC.W     0x4e71  ; 'Nq'
F03CE8  06 6e                   DC.W     0x066e
F03CEA  00 0c                   DC.W     0x000c
F03CEC  01 02                   DC.W     0x0102
F03CEE  4e 73                   DC.W     0x4e73  ; 'Ns'

loc_F03CF0:
F03CF0  08 2c 00 0f 00 08       btst.b   #$f, $8(a4)
F03CF6  66 08                   bne.b    loc_F03D00
F03CF8  06 6e 00 0f 01 02       addi.w   #$f, $102(a6)
F03CFE  4e 73                   rte      

loc_F03D00:
F03D00  26 46                   movea.l  d6, a3
F03D02  70 7f                   moveq    #$7f, d0

loc_F03D04:
F03D04  26 dd                   move.l   (a5)+, (a3)+
F03D06  51 c8 ff fc             dbra     d0, loc_F03D04
F03D0A  4e 73                   rte      
F03D0C  2c 08                   DC.W     0x2c08
F03D0E  08 06                   DC.W     0x0806
F03D10  00 00                   DC.W     0x0000
F03D12  66 10                   DC.W     0x6610
F03D14  7a 08                   DC.W     0x7a08
F03D16  2e 08                   DC.W     0x2e08
F03D18  20 6e                   DC.W     0x206e  ; ' n'
F03D1A  00 36                   DC.W     0x0036
F03D1C  61 00                   DC.W     0x6100
F03D1E  da 3e                   DC.W     0xda3e
F03D20  60 08                   DC.W     0x6008
F03D22  4e 71                   DC.W     0x4e71  ; 'Nq'
F03D24  70 02                   moveq    #$2, d0
F03D26  61 00 06 4e             bsr.w    loc_F04376
F03D2A  24 46                   movea.l  d6, a2
F03D2C  22 2a 00 04             move.l   $4(a2), d1
F03D30  66 06                   bne.b    loc_F03D38
F03D32  70 0b                   moveq    #$b, d0
F03D34  61 00 06 40             bsr.w    loc_F04376

loc_F03D38:
F03D38  41 f8 0c 8e             lea.l    $c8e.w, a0
F03D3C  41 f8 0c 8e             lea.l    $c8e.w, a0
F03D40  61 00 c9 a6             bsr.w    loc_F006E8
F03D44  47 f8 0c 18             lea.l    $c18.w, a3

loc_F03D48:
F03D48  22 53                   movea.l  (a3), a1
F03D4A  4a 93                   tst.l    (a3)
F03D4C  67 0e                   beq.b    loc_F03D5C
F03D4E  b2 a9 00 14             cmp.l    $14(a1), d1
F03D52  67 00 02 c8             beq.w    loc_F0401C
F03D56  47 e9 00 04             lea.l    $4(a1), a3
F03D5A  60 ec                   bra.b    loc_F03D48

loc_F03D5C:
F03D5C  0c 12 00 01             cmpi.b   #$1, (a2)
F03D60  66 00 02 ae             bne.w    loc_F04010
F03D64  2c 07                   move.l   d7, d6
F03D66  20 6e 00 36             movea.l  $36(a6), a0
F03D6A  42 85                   clr.l    d5
F03D6C  1a 2a 00 1b             move.b   $1b(a2), d5
F03D70  e7 8d                   lsl.l    #$3, d5
F03D72  06 45 00 1c             addi.w   #$1c, d5
F03D76  61 00 d9 e4             bsr.w    loc_F0175C
F03D7A  60 06                   bra.b    loc_F03D82
F03D7C  4e 71                   DC.W     0x4e71  ; 'Nq'
F03D7E  60 00                   DC.W     0x6000
F03D80  02 98                   DC.W     0x0298

loc_F03D82:
F03D82  42 80                   clr.l    d0
F03D84  10 2a 00 18             move.b   $18(a2), d0
F03D88  0c 00 00 19             cmpi.b   #$19, d0
F03D8C  65 0c                   bcs.b    loc_F03D9A
F03D8E  0c 00 00 1f             cmpi.b   #$1f, d0
F03D92  63 0c                   bls.b    loc_F03DA0
F03D94  0c 00 00 40             cmpi.b   #$40, d0
F03D98  64 06                   bcc.b    loc_F03DA0

loc_F03D9A:
F03D9A  70 cb                   moveq    #$cb, d0
F03D9C  61 00 00 84             bsr.w    loc_F03E22

loc_F03DA0:
F03DA0  72 0c                   moveq    #$c, d1
F03DA2  c2 6a 00 02             and.w    $2(a2), d1
F03DA6  0c 41 00 0c             cmpi.w   #$c, d1
F03DAA  66 04                   bne.b    loc_F03DB0
F03DAC  70 0b                   moveq    #$b, d0
F03DAE  61 72                   bsr.b    loc_F03E22

loc_F03DB0:
F03DB0  22 78 0c 66             movea.l  $c66.w, a1
F03DB4  4a 31 00 00             tst.b    (a1, d0.w)
F03DB8  67 0e                   beq.b    loc_F03DC8
F03DBA  6a 00 03 a6             bpl.w    loc_F04162
F03DBE  08 2a 00 02 00 03       btst.b   #$2, $3(a2)
F03DC4  66 00 03 9c             bne.w    loc_F04162

loc_F03DC8:
F03DC8  0c 2a 00 ff 00 08       cmpi.b   #$ff, $8(a2)
F03DCE  67 0a                   beq.b    loc_F03DDA
F03DD0  4a aa 00 0a             tst.l    $a(a2)
F03DD4  66 04                   bne.b    loc_F03DDA
F03DD6  70 c7                   moveq    #$c7, d0
F03DD8  61 48                   bsr.b    loc_F03E22

loc_F03DDA:
F03DDA  0c 2a 00 07 00 19       cmpi.b   #$7, $19(a2)
F03DE0  62 08                   bhi.b    loc_F03DEA
F03DE2  0c 2a 00 01 00 19       cmpi.b   #$1, $19(a2)
F03DE8  64 04                   bcc.b    loc_F03DEE

loc_F03DEA:
F03DEA  70 cc                   moveq    #$cc, d0
F03DEC  61 34                   bsr.b    loc_F03E22

loc_F03DEE:
F03DEE  47 ea 00 1c             lea.l    $1c(a2), a3
F03DF2  42 85                   clr.l    d5
F03DF4  1a 2a 00 1b             move.b   $1b(a2), d5
F03DF8  67 30                   beq.b    loc_F03E2A
F03DFA  0c 05 00 04             cmpi.b   #$4, d5
F03DFE  6f 04                   ble.b    loc_F03E04
F03E00  70 ce                   moveq    #$ce, d0
F03E02  61 1e                   bsr.b    loc_F03E22

loc_F03E04:
F03E04  53 85                   subq.l   #$1, d5
F03E06  e7 8d                   lsl.l    #$3, d5
F03E08  32 2a 00 16             move.w   $16(a2), d1

loc_F03E0C:
F03E0C  b2 73 50 00             cmp.w    (a3, d5.w), d1
F03E10  64 04                   bcc.b    loc_F03E16
F03E12  70 cf                   moveq    #$cf, d0
F03E14  61 0c                   bsr.b    loc_F03E22

loc_F03E16:
F03E16  b2 73 50 04             cmp.w    $4(a3, d5.w), d1
F03E1A  64 0a                   bcc.b    loc_F03E26
F03E1C  70 cf                   moveq    #$cf, d0
F03E1E  61 00 05 48             bsr.w    loc_F04368

loc_F03E22:
F03E22  60 00 05 44             bra.w    loc_F04368

loc_F03E26:
F03E26  51 85                   subq.l   #$8, d5
F03E28  6c e2                   bge.b    loc_F03E0C

loc_F03E2A:
F03E2A  20 2a 00 12             move.l   $12(a2), d0
F03E2E  20 40                   movea.l  d0, a0
F03E30  08 00 00 00             btst.b   #$0, d0
F03E34  66 02                   bne.b    loc_F03E38
F03E36  52 88                   addq.l   #$1, a0

loc_F03E38:
F03E38  2f 3c 00 f0 3e 48       move.l   #loc_F03E48, -(a7)
F03E3E  3f 3c 42 45             move.w   #$4245, -(a7)
F03E42  12 10                   move.b   (a0), d1
F03E44  5c 8f                   addq.l   #$6, a7
F03E46  60 04                   bra.b    loc_F03E4C

loc_F03E48:
F03E48  70 c9                   moveq    #$c9, d0
F03E4A  61 d6                   bsr.b    loc_F03E22

loc_F03E4C:
F03E4C  47 f8 0c 18             lea.l    $c18.w, a3
F03E50  70 18                   moveq    #$18, d0
F03E52  c0 6a 00 02             and.w    $2(a2), d0
F03E56  0c 00 00 18             cmpi.b   #$18, d0
F03E5A  66 04                   bne.b    loc_F03E60
F03E5C  70 0b                   moveq    #$b, d0
F03E5E  61 c2                   bsr.b    loc_F03E22

loc_F03E60:
F03E60  0c 00 00 08             cmpi.b   #$8, d0
F03E64  66 3e                   bne.b    loc_F03EA4
F03E66  20 2a 00 0e             move.l   $e(a2), d0

loc_F03E6A:
F03E6A  28 53                   movea.l  (a3), a4
F03E6C  4a 93                   tst.l    (a3)
F03E6E  66 04                   bne.b    loc_F03E74
F03E70  70 0b                   moveq    #$b, d0
F03E72  61 ae                   bsr.b    loc_F03E22

loc_F03E74:
F03E74  47 ec 00 04             lea.l    $4(a4), a3
F03E78  b0 ac 00 14             cmp.l    $14(a4), d0
F03E7C  66 ec                   bne.b    loc_F03E6A
F03E7E  10 2a 00 18             move.b   $18(a2), d0
F03E82  08 2c 00 02 00 49       btst.b   #$2, $49(a4)
F03E88  67 06                   beq.b    loc_F03E90
F03E8A  b0 2c 00 28             cmp.b    $28(a4), d0
F03E8E  67 04                   beq.b    loc_F03E94

loc_F03E90:
F03E90  70 0b                   moveq    #$b, d0
F03E92  61 8e                   bsr.b    loc_F03E22

loc_F03E94:
F03E94  0c ac 00 00 00 00 00 10  cmpi.l   #$0, $10(a4)
F03E9C  67 06                   beq.b    loc_F03EA4
F03E9E  28 6c 00 10             movea.l  $10(a4), a4
F03EA2  60 f0                   bra.b    loc_F03E94

loc_F03EA4:
F03EA4  22 53                   movea.l  (a3), a1
F03EA6  4a 93                   tst.l    (a3)
F03EA8  67 06                   beq.b    loc_F03EB0
F03EAA  47 e9 00 04             lea.l    $4(a1), a3
F03EAE  60 f4                   bra.b    loc_F03EA4

loc_F03EB0:
F03EB0  20 6a 00 0a             movea.l  $a(a2), a0
F03EB4  70 00                   moveq    #$0, d0
F03EB6  10 28 00 10             move.b   $10(a0), d0
F03EBA  52 40                   addq.w   #$1, d0
F03EBC  20 40                   movea.l  d0, a0
F03EBE  48 e7 80 38             movem.l  d0/a2-a4, -(a7)
F03EC2  61 00 d3 7a             bsr.w    loc_F0123E
F03EC6  60 0a                   bra.b    loc_F03ED2
F03EC8  4c df                   DC.W     0x4cdf
F03ECA  1c 01                   DC.W     0x1c01
F03ECC  70 08                   DC.W     0x7008
F03ECE  61 00                   DC.W     0x6100
F03ED0  ff 52                   DC.W     0xff52

loc_F03ED2:
F03ED2  4c df 1c 01             movem.l  (a7)+, d0/a2-a4
F03ED6  22 48                   movea.l  a0, a1
F03ED8  ed 88                   lsl.l    #$6, d0

loc_F03EDA:
F03EDA  42 98                   clr.l    (a0)+
F03EDC  53 80                   subq.l   #$1, d0
F03EDE  6e fa                   bgt.b    loc_F03EDA
F03EE0  08 2a 00 03 00 03       btst.b   #$3, $3(a2)
F03EE6  67 04                   beq.b    loc_F03EEC
F03EE8  29 49 00 10             move.l   a1, $10(a4)

loc_F03EEC:
F03EEC  26 89                   move.l   a1, (a3)
F03EEE  22 bc 21 43 43 42       move.l   #$21434342, (a1)
F03EF4  08 2a 00 00 00 03       btst.b   #$0, $3(a2)
F03EFA  67 06                   beq.b    loc_F03F02
F03EFC  00 69 00 01 00 48       ori.w    #$1, $48(a1)

loc_F03F02:
F03F02  4c ea 00 3f 00 04       movem.l  $4(a2), d0-d5
F03F08  48 e9 00 3f 00 14       movem.l  d0-d5, $14(a1)
F03F0E  10 29 00 29             move.b   $29(a1), d0
F03F12  04 00 00 e0             subi.b   #$e0, d0
F03F16  e1 88                   lsl.l    #$8, d0
F03F18  33 40 00 42             move.w   d0, $42(a1)
F03F1C  04 40 01 00             subi.w   #$100, d0
F03F20  33 40 00 40             move.w   d0, $40(a1)
F03F24  47 ea 00 1c             lea.l    $1c(a2), a3
F03F28  49 e9 00 70             lea.l    $70(a1), a4
F03F2C  10 29 00 2b             move.b   $2b(a1), d0

loc_F03F30:
F03F30  67 08                   beq.b    loc_F03F3A
F03F32  28 db                   move.l   (a3)+, (a4)+
F03F34  28 db                   move.l   (a3)+, (a4)+
F03F36  53 00                   subq.b   #$1, d0
F03F38  60 f6                   bra.b    loc_F03F30

loc_F03F3A:
F03F3A  42 80                   clr.l    d0
F03F3C  10 2a 00 18             move.b   $18(a2), d0
F03F40  e5 88                   lsl.l    #$2, d0
F03F42  23 40 00 44             move.l   d0, $44(a1)
F03F46  26 6a 00 0a             movea.l  $a(a2), a3
F03F4A  d7 d3                   adda.l   (a3), a3
F03F4C  23 4b 00 1e             move.l   a3, $1e(a1)
F03F50  0c 29 00 ff 00 18       cmpi.b   #$ff, $18(a1)
F03F56  66 08                   bne.b    loc_F03F60
F03F58  23 7c 00 f0 43 ee 00 1e  move.l   #loc_F043EE, $1e(a1)

loc_F03F60:
F03F60  08 2a 00 04 00 03       btst.b   #$4, $3(a2)
F03F66  67 06                   beq.b    loc_F03F6E
F03F68  08 e9 00 02 00 49       bset.b   #$2, $49(a1)

loc_F03F6E:
F03F6E  08 2a 00 02 00 03       btst.b   #$2, $3(a2)
F03F74  67 08                   beq.b    loc_F03F7E
F03F76  08 e9 00 00 00 48       bset.b   #$0, $48(a1)
F03F7C  60 52                   bra.b    loc_F03FD0

loc_F03F7E:
F03F7E  08 2a 00 03 00 03       btst.b   #$3, $3(a2)
F03F84  66 62                   bne.b    loc_F03FE8
F03F86  42 80                   clr.l    d0
F03F88  10 2a 00 18             move.b   $18(a2), d0
F03F8C  26 78 0c 66             movea.l  $c66.w, a3
F03F90  4a 33 08 00             tst.b    (a3, d0.l)
F03F94  67 3a                   beq.b    loc_F03FD0
F03F96  28 69 00 44             movea.l  $44(a1), a4
F03F9A  20 0c                   move.l   a4, d0
F03F9C  26 54                   movea.l  (a4), a3
F03F9E  47 eb ff b6             lea.l    -$4a(a3), a3
F03FA2  12 2a 00 1a             move.b   $1a(a2), d1
F03FA6  60 0a                   bra.b    loc_F03FB2

loc_F03FA8:
F03FA8  26 6c 00 08             movea.l  $8(a4), a3
F03FAC  4a ac 00 08             tst.l    $8(a4)
F03FB0  67 0c                   beq.b    loc_F03FBE

loc_F03FB2:
F03FB2  14 2b 00 2a             move.b   $2a(a3), d2
F03FB6  b2 02                   cmp.b    d2, d1
F03FB8  6e 04                   bgt.b    loc_F03FBE
F03FBA  28 4b                   movea.l  a3, a4
F03FBC  60 ea                   bra.b    loc_F03FA8

loc_F03FBE:
F03FBE  b9 c0                   cmpa.l   d0, a4
F03FC0  67 0a                   beq.b    loc_F03FCC
F03FC2  23 4b 00 08             move.l   a3, $8(a1)
F03FC6  29 49 00 08             move.l   a1, $8(a4)
F03FCA  60 1c                   bra.b    loc_F03FE8

loc_F03FCC:
F03FCC  23 4b 00 08             move.l   a3, $8(a1)

loc_F03FD0:
F03FD0  26 69 00 44             movea.l  $44(a1), a3
F03FD4  33 7c 4e b9 00 4a       move.w   #$4eb9, $4a(a1)
F03FDA  23 7c 00 f0 44 a2 00 4c  move.l   #$f044a2, $4c(a1)
F03FE2  49 e9 00 4a             lea.l    $4a(a1), a4
F03FE6  26 8c                   move.l   a4, (a3)

loc_F03FE8:
F03FE8  42 80                   clr.l    d0
F03FEA  10 2a 00 18             move.b   $18(a2), d0
F03FEE  20 78 0c 66             movea.l  $c66.w, a0
F03FF2  11 bc 00 ff 00 00       move.b   #$ff, (a0, d0.w)
F03FF8  20 69 00 1a             movea.l  $1a(a1), a0
F03FFC  d1 e8 00 08             adda.l   $8(a0), a0
F04000  2a 49                   movea.l  a1, a5
F04002  2f 0e                   move.l   a6, -(a7)
F04004  4e 90                   jsr      (a0)
F04006  2c 5f                   movea.l  (a7)+, a6
F04008  60 00 03 74             bra.w    loc_F0437E

loc_F0400C:
F0400C  60 00 03 5a             bra.w    loc_F04368

loc_F04010:
F04010  70 0b                   moveq    #$b, d0
F04012  61 f8                   bsr.b    loc_F0400C

loc_F04014:
F04014  70 09                   moveq    #$9, d0
F04016  61 f4                   bsr.b    loc_F0400C
F04018  70 02                   moveq    #$2, d0
F0401A  61 f0                   bsr.b    loc_F0400C

loc_F0401C:
F0401C  0c 12 00 01             cmpi.b   #$1, (a2)
F04020  67 00 01 40             beq.w    loc_F04162
F04024  6f 06                   ble.b    loc_F0402C
F04026  0c 12 00 07             cmpi.b   #$7, (a2)
F0402A  6f 04                   ble.b    loc_F04030

loc_F0402C:
F0402C  70 c1                   moveq    #$c1, d0
F0402E  61 dc                   bsr.b    loc_F0400C

loc_F04030:
F04030  20 6e 00 36             movea.l  $36(a6), a0
F04034  42 80                   clr.l    d0
F04036  10 12                   move.b   (a2), d0
F04038  53 00                   subq.b   #$1, d0
F0403A  26 40                   movea.l  d0, a3
F0403C  42 85                   clr.l    d5
F0403E  0c 12 00 07             cmpi.b   #$7, (a2)
F04042  66 20                   bne.b    loc_F04064
F04044  0c 29 00 10 00 18       cmpi.b   #$10, $18(a1)
F0404A  65 32                   bcs.b    loc_F0407E
F0404C  0c 29 00 7f 00 18       cmpi.b   #$7f, $18(a1)
F04052  63 10                   bls.b    loc_F04064
F04054  0c 29 00 80 00 18       cmpi.b   #$80, $18(a1)
F0405A  65 22                   bcs.b    loc_F0407E
F0405C  0c 29 00 8f 00 18       cmpi.b   #$8f, $18(a1)
F04062  62 1a                   bhi.b    loc_F0407E

loc_F04064:
F04064  1a 3b b0 10             move.b   loc_F04076(pc, a3.w), d5
F04068  67 14                   beq.b    loc_F0407E
F0406A  2c 07                   move.l   d7, d6
F0406C  61 00 d6 ee             bsr.w    loc_F0175C
F04070  60 0c                   bra.b    loc_F0407E
F04072  4e 71                   DC.W     0x4e71  ; 'Nq'
F04074  60 a2                   DC.W     0x60a2

loc_F04076:
F04076  00 08                   DC.W     0x0008
F04078  12 08                   DC.W     0x1208
F0407A  08 08                   DC.W     0x0808
F0407C  18 00                   DC.W     0x1800

loc_F0407E:
F0407E  d7 cb                   adda.l   a3, a3
F04080  47 fb b0 06             lea.l    loc_F04088(pc, a3.w), a3
F04084  d6 d3                   adda.w   (a3), a3
F04086  4e d3                   jmp      (a3)

loc_F04088:
F04088  ff fe                   dc.w     $fffe
F0408A  00 0c                   DC.W     0x000c
F0408C  00 cc                   DC.W     0x00cc
F0408E  01 a2                   DC.W     0x01a2
F04090  01 da                   DC.W     0x01da
F04092  01 f0                   DC.W     0x01f0
F04094  02 12                   DC.W     0x0212
F04096  20 2a                   DC.W     0x202a  ; ' *'
F04098  00 04                   DC.W     0x0004
F0409A  61 00                   DC.W     0x6100
F0409C  02 b2                   DC.W     0x02b2
F0409E  66 00                   DC.W     0x6600
F040A0  00 b4                   DC.W     0x00b4
F040A2  20 a9                   DC.W     0x20a9
F040A4  00 0c                   DC.W     0x000c
F040A6  08 a9                   DC.W     0x08a9
F040A8  00 00                   DC.W     0x0000
F040AA  00 48                   DC.W     0x0048
F040AC  66 58 22 29             DC.B     "fX\")"  ; 4 bytes
F040B0  00 44                   DC.W     0x0044
F040B2  28 41 26 54 47          DC.B     "(A&TG"  ; 5 bytes
F040B7  eb ff                   DC.W     0xebff
F040B9  b6 20                   DC.W     0xb620
F040BB  09 60                   DC.W     0x0960
F040BD  0e 26                   DC.W     0x0e26
F040BF  6c 00                   DC.W     0x6c00
F040C1  08 4a                   DC.W     0x084a
F040C3  ac 00                   DC.W     0xac00
F040C5  08 66                   DC.W     0x0866
F040C7  04 61                   DC.W     0x0461
F040C9  00 c0                   DC.W     0x00c0
F040CB  bc b0                   DC.W     0xbcb0
F040CD  8b 67                   DC.W     0x8b67
F040CF  04 28                   DC.W     0x0428
F040D1  4b 60                   DC.W     0x4b60  ; 'K`'
F040D3  ea b9                   DC.W     0xeab9
F040D5  c1 66                   DC.W     0xc166
F040D7  26 4a                   DC.W     0x264a  ; '&J'
F040D9  ab 00                   DC.W     0xab00
F040DB  08 67                   DC.W     0x0867
F040DD  28 28                   DC.W     0x2828  ; '(('
F040DF  6b 00                   DC.W     0x6b00
F040E1  08 29                   DC.W     0x0829
F040E3  7c 00                   DC.W     0x7c00
F040E5  00 4e                   DC.W     0x004e
F040E7  b9 00                   DC.W     0xb900
F040E9  4a 29                   DC.W     0x4a29  ; 'J)'
F040EB  7c 00                   DC.W     0x7c00
F040ED  f0 44                   DC.W     0xf044
F040EF  a2 00                   DC.W     0xa200
F040F1  4c 49                   DC.W     0x4c49  ; 'LI'
F040F3  ec 00                   DC.W     0xec00
F040F5  4a 26                   DC.W     0x4a26  ; 'J&'
F040F7  6b 00                   DC.W     0x6b00
F040F9  44 26                   DC.W     0x4426  ; 'D&'
F040FB  8c 60                   DC.W     0x8c60
F040FD  20 29                   DC.W     0x2029  ; ' )'
F040FF  6b 00                   DC.W     0x6b00
F04101  08 00                   DC.W     0x0800
F04103  08 60                   DC.W     0x0860
F04105  18 42                   DC.W     0x1842
F04107  81 12                   DC.W     0x8112
F04109  29 00                   DC.W     0x2900
F0410B  28 26                   DC.W     0x2826  ; '(&'
F0410D  69 00                   DC.W     0x6900
F0410F  44 26                   DC.W     0x4426  ; 'D&'
F04111  bc 00                   DC.W     0xbc00
F04113  f0 08                   DC.W     0xf008
F04115  96 26                   DC.W     0x9626
F04117  78 0c                   DC.W     0x780c
F04119  66 42                   DC.W     0x6642  ; 'fB'
F0411B  33 10                   DC.W     0x3310
F0411D  00 49                   DC.W     0x0049
F0411F  f8 0c                   DC.W     0xf80c
F04121  18 20                   DC.W     0x1820
F04123  09 26                   DC.W     0x0926
F04125  54 4a                   DC.W     0x544a  ; 'TJ'
F04127  94 66                   DC.W     0x9466
F04129  04 61                   DC.W     0x0461
F0412B  00 c0                   DC.W     0x00c0
F0412D  5a b0                   DC.W     0x5ab0
F0412F  8b 67                   DC.W     0x8b67
F04131  06 49                   DC.W     0x0649
F04133  eb 00                   DC.W     0xeb00
F04135  04 60                   DC.W     0x0460
F04137  ec 28                   DC.W     0xec28
F04139  ab 00                   DC.W     0xab00
F0413B  04 41                   DC.W     0x0441
F0413D  f8 0c                   DC.W     0xf80c
F0413F  8e 61                   DC.W     0x8e61
F04141  00 c6                   DC.W     0x00c6
F04143  46 20                   DC.W     0x4620  ; 'F '
F04145  49 72                   DC.W     0x4972  ; 'Ir'
F04147  01 61                   DC.W     0x0161
F04149  00 d3                   DC.W     0x00d3
F0414B  4a 60                   DC.W     0x4a60  ; 'J`'
F0414D  00 02                   DC.W     0x0002
F0414F  38 61                   DC.W     0x3861  ; '8a'
F04151  00 c0                   DC.W     0x00c0
F04153  34 70                   DC.W     0x3470  ; '4p'
F04155  81 61                   DC.W     0x8161
F04157  7a 26                   DC.W     0x7a26  ; 'z&'
F04159  49 61                   DC.W     0x4961  ; 'Ia'
F0415B  00 01                   DC.W     0x0001
F0415D  ee 22                   DC.W     0xee22
F0415F  4b 66                   DC.W     0x4b66  ; 'Kf'
F04161  04 70                   DC.W     0x0470
F04163  06 61                   DC.W     0x0661
F04165  6c 08                   DC.W     0x6c08
F04167  29 00                   DC.W     0x2900
F04169  07 00                   DC.W     0x0700
F0416B  48 67                   DC.W     0x4867  ; 'Hg'
F0416D  04 70                   DC.W     0x0470
F0416F  82 61                   DC.W     0x8261
F04171  60 08                   DC.W     0x6008
F04173  29 00                   DC.W     0x2900
F04175  01 00                   DC.W     0x0100
F04177  49 67                   DC.W     0x4967  ; 'Ig'
F04179  04 70                   DC.W     0x0470
F0417B  83 61                   DC.W     0x8361
F0417D  54 08                   DC.W     0x5408
F0417F  29 00                   DC.W     0x2900
F04181  00 00                   DC.W     0x0000
F04183  49 67                   DC.W     0x4967  ; 'Ig'
F04185  0a 08                   DC.W     0x0a08
F04187  2e 00                   DC.W     0x2e00
F04189  07 00                   DC.W     0x0700
F0418B  28 67                   DC.W     0x2867  ; '(g'
F0418D  00 fe                   DC.W     0x00fe
F0418F  86 08                   DC.W     0x8608
F04191  29 00                   DC.W     0x2900
F04193  02 00                   DC.W     0x0200
F04195  49 67                   DC.W     0x4967  ; 'Ig'
F04197  04 70                   DC.W     0x0470
F04199  0b 61                   DC.W     0x0b61
F0419B  36 0c                   DC.W     0x360c
F0419D  29 00                   DC.W     0x2900
F0419F  0f 00                   DC.W     0x0f00
F041A1  18 63                   DC.W     0x1863
F041A3  18 0c                   DC.W     0x180c
F041A5  29 00                   DC.W     0x2900
F041A7  7f 00                   DC.W     0x7f00
F041A9  18 63                   DC.W     0x1863
F041AB  18 0c                   DC.W     0x180c
F041AD  29 00                   DC.W     0x2900
F041AF  80 00                   DC.W     0x8000
F041B1  18 65                   DC.W     0x1865
F041B3  08 0c                   DC.W     0x080c
F041B5  29 00                   DC.W     0x2900
F041B7  8f 00                   DC.W     0x8f00
F041B9  18 63                   DC.W     0x1863
F041BB  08 08                   DC.W     0x0808
F041BD  2a 00                   DC.W     0x2a00
F041BF  00 00                   DC.W     0x0000
F041C1  03 67                   DC.W     0x0367
F041C3  3c 0c                   DC.W     0x3c0c
F041C5  2a 00                   DC.W     0x2a00
F041C7  04 00                   DC.W     0x0400
F041C9  09 64                   DC.W     0x0964
F041CB  0a 70                   DC.W     0x0a70
F041CD  c6 61                   DC.W     0xc661
F041CF  00 01                   DC.W     0x0001
F041D1  98 60                   DC.W     0x9860
F041D3  00 01                   DC.W     0x0001
F041D5  94 13                   DC.W     0x9413
F041D7  6a 00                   DC.W     0x6a00
F041D9  09 00                   DC.W     0x0900
F041DB  3a 23                   DC.W     0x3a23  ; ':#'
F041DD  6a 00                   DC.W     0x6a00
F041DF  0a 00                   DC.W     0x0a00
F041E1  3c 67                   DC.W     0x3c67  ; '<g'
F041E3  1c 2f                   DC.W     0x1c2f
F041E5  08 20                   DC.W     0x0820
F041E7  6e 00                   DC.W     0x6e00
F041E9  36 2c                   DC.W     0x362c  ; '6,'
F041EB  29 00                   DC.W     0x2900
F041ED  3c 7a                   DC.W     0x3c7a  ; '<z'
F041EF  04 61                   DC.W     0x0461
F041F1  00 d5                   DC.W     0x00d5
F041F3  6a 60                   DC.W     0x6a60  ; 'j`'
F041F5  08 4e                   DC.W     0x084e
F041F7  71 20 5f 70             DC.B     "q _p"  ; 4 bytes
F041FB  c7 61                   DC.W     0xc761
F041FD  d4 20                   DC.W     0xd420
F041FF  5f 23                   DC.W     0x5f23  ; '_#'
F04201  4e 00                   DC.W     0x4e00
F04203  34 13                   DC.W     0x3413
F04205  6a 00                   DC.W     0x6a00
F04207  03 00                   DC.W     0x0300
F04209  39 02                   DC.W     0x3902
F0420B  29 00                   DC.W     0x2900
F0420D  03 00                   DC.W     0x0300
F0420F  39 13                   DC.W     0x3913
F04211  6a 00                   DC.W     0x6a00
F04213  08 00                   DC.W     0x0800
F04215  38 20                   DC.W     0x3820  ; '8 '
F04217  89 20                   DC.W     0x8920
F04219  2e 00                   DC.W     0x2e00
F0421B  10 22                   DC.W     0x1022
F0421D  2e 00                   DC.W     0x2e00
F0421F  14 23                   DC.W     0x1423
F04221  40 00                   DC.W     0x4000
F04223  2c 23                   DC.W     0x2c23  ; ',#'
F04225  41 00                   DC.W     0x4100
F04227  30 00                   DC.W     0x3000
F04229  69 80                   DC.W     0x6980
F0422B  00 00                   DC.W     0x0000
F0422D  48 60                   DC.W     0x4860  ; 'H`'
F0422F  72 41                   DC.W     0x7241  ; 'rA'
F04231  ee 00                   DC.W     0xee00
F04233  44 08                   DC.W     0x4408
F04235  2a 00                   DC.W     0x2a00
F04237  00 00                   DC.W     0x0000
F04239  03 67                   DC.W     0x0367
F0423B  16 4a                   DC.W     0x164a
F0423D  90 67                   DC.W     0x9067
F0423F  62 26                   DC.W     0x6226  ; 'b&'
F04241  50 20                   DC.W     0x5020  ; 'P '
F04243  ab 00                   DC.W     0xab00
F04245  0c 42                   DC.W     0x0c42
F04247  ab 00                   DC.W     0xab00
F04249  0c 02                   DC.W     0x0c02
F0424B  6b 7f                   DC.W     0x6b7f
F0424D  ff 00                   DC.W     0xff00
F0424F  48 60                   DC.W     0x4860  ; 'H`'
F04251  ea 61                   DC.W     0xea61
F04253  00 00                   DC.W     0x0000
F04255  f6 66                   DC.W     0xf666
F04257  00 fe                   DC.W     0x00fe
F04259  fc 20                   DC.W     0xfc20
F0425B  a9 00                   DC.W     0xa900
F0425D  0c 42                   DC.W     0x0c42
F0425F  a9 00                   DC.W     0xa900
F04261  0c 02                   DC.W     0x0c02
F04263  69 7f                   DC.W     0x697f
F04265  ff 00                   DC.W     0xff00
F04267  48 60                   DC.W     0x4860  ; 'H`'
F04269  38 08                   DC.W     0x3808
F0426B  2e 00                   DC.W     0x2e00
F0426D  07 00                   DC.W     0x0700
F0426F  28 67                   DC.W     0x2867  ; '(g'
F04271  00 fd                   DC.W     0x00fd
F04273  a2 08                   DC.W     0xa208
F04275  a9 00                   DC.W     0xa900
F04277  01 00                   DC.W     0x0100
F04279  49 66 26 70             DC.B     "If&p"  ; 4 bytes
F0427D  06 61                   DC.W     0x0661
F0427F  00 00                   DC.W     0x0000
F04281  e8 61                   DC.W     0xe861
F04283  00 00                   DC.W     0x0000
F04285  c6 66                   DC.W     0xc666
F04287  00 fe                   DC.W     0x00fe
F04289  cc 20                   DC.W     0xcc20
F0428B  a9 00                   DC.W     0xa900
F0428D  0c 42                   DC.W     0x0c42
F0428F  a9 00                   DC.W     0xa900
F04291  0c 02                   DC.W     0x0c02
F04293  69 7f                   DC.W     0x697f
F04295  ff 00                   DC.W     0xff00
F04297  48 08                   DC.W     0x4808
F04299  e9 00                   DC.W     0xe900
F0429B  01 00                   DC.W     0x0100
F0429D  49 66                   DC.W     0x4966  ; 'If'
F0429F  00 fe                   DC.W     0x00fe
F042A1  da 60                   DC.W     0xda60
F042A3  00 00                   DC.W     0x0000
F042A5  da 0c                   DC.W     0xda0c
F042A7  29 00                   DC.W     0x2900
F042A9  ff 00                   DC.W     0xff00
F042AB  18 66                   DC.W     0x1866
F042AD  04 7e                   DC.W     0x047e
F042AF  85 61                   DC.W     0x8561
F042B1  76 0c                   DC.W     0x760c
F042B3  29 00                   DC.W     0x2900
F042B5  80 00                   DC.W     0x8000
F042B7  18 65                   DC.W     0x1865
F042B9  08 0c                   DC.W     0x080c
F042BB  29 00                   DC.W     0x2900
F042BD  8f 00                   DC.W     0x8f00
F042BF  18 63                   DC.W     0x1863
F042C1  08 61                   DC.W     0x0861
F042C3  00 00                   DC.W     0x0000
F042C5  86 66                   DC.W     0x8666
F042C7  00 fe                   DC.W     0x00fe
F042C9  8c 2a                   DC.W     0x8c2a
F042CB  49 0c                   DC.W     0x490c
F042CD  2d 00                   DC.W     0x2d00
F042CF  10 00                   DC.W     0x1000
F042D1  18 65                   DC.W     0x1865
F042D3  5a 0c                   DC.W     0x5a0c
F042D5  2d 00                   DC.W     0x2d00
F042D7  7f 00                   DC.W     0x7f00
F042D9  18 63                   DC.W     0x1863
F042DB  10 0c                   DC.W     0x100c
F042DD  2d 00                   DC.W     0x2d00
F042DF  80 00                   DC.W     0x8000
F042E1  18 65                   DC.W     0x1865
F042E3  4a 0c                   DC.W     0x4a0c
F042E5  2d 00                   DC.W     0x2d00
F042E7  8f 00                   DC.W     0x8f00
F042E9  18 62                   DC.W     0x1862
F042EB  42 20                   DC.W     0x4220  ; 'B '
F042ED  2a 00                   DC.W     0x2a00
F042EF  08 66                   DC.W     0x0866
F042F1  04 20                   DC.W     0x0420
F042F3  2e 00                   DC.W     0x2e00
F042F5  10 22                   DC.W     0x1022
F042F7  2a 00                   DC.W     0x2a00
F042F9  0c 66                   DC.W     0x0c66
F042FB  04 22                   DC.W     0x0422
F042FD  2e 00                   DC.W     0x2e00
F042FF  14 08                   DC.W     0x1408
F04301  2e 00                   DC.W     0x2e00
F04303  07 00                   DC.W     0x0700
F04305  28 66                   DC.W     0x2866  ; '(f'
F04307  0a b2                   DC.W     0x0ab2
F04309  ae 00                   DC.W     0xae00
F0430B  14 67                   DC.W     0x1467
F0430D  04 7e                   DC.W     0x047e
F0430F  c6 61                   DC.W     0xc661
F04311  16 48                   DC.W     0x1648
F04313  ed 00                   DC.W     0xed00
F04315  03 00                   DC.W     0x0300
F04317  54 41                   DC.W     0x5441  ; 'TA'
F04319  ed 00                   DC.W     0xed00
F0431B  54 70                   DC.W     0x5470  ; 'Tp'
F0431D  06 4e                   DC.W     0x064e
F0431F  40 60                   DC.W     0x4060  ; '@`'
F04321  08 4e                   DC.W     0x084e
F04323  71 7e                   DC.W     0x717e  ; 'q~'
F04325  03 61                   DC.W     0x0361
F04327  40 60                   DC.W     0x4060  ; '@`'
F04329  3e 2b                   DC.W     0x3e2b  ; '>+'
F0432B  48 00                   DC.W     0x4800
F0432D  50 41                   DC.W     0x5041  ; 'PA'
F0432F  f8 0c                   DC.W     0xf80c
F04331  8e 61                   DC.W     0x8e61
F04333  00 c4                   DC.W     0x00c4
F04335  54 20                   DC.W     0x5420  ; 'T '
F04337  6d 00                   DC.W     0x6d00
F04339  1a d1                   DC.W     0x1ad1
F0433B  e8 00                   DC.W     0xe800
F0433D  04 2f                   DC.W     0x042f
F0433F  0e 4e                   DC.W     0x0e4e
F04341  90 2c                   DC.W     0x902c
F04343  5f 4a                   DC.W     0x5f4a  ; '_J'
F04345  40 67                   DC.W     0x4067  ; '@g'
F04347  3e 61                   DC.W     0x3e61  ; '>a'
F04349  2c 20                   DC.W     0x2c20  ; ', '
F0434B  29 00                   DC.W     0x2900
F0434D  14 41                   DC.W     0x1441
F0434F  ee 00                   DC.W     0xee00
F04351  44 4a                   DC.W     0x444a  ; 'DJ'
F04353  90 67                   DC.W     0x9067
F04355  0e 22                   DC.W     0x0e22
F04357  50 b0                   DC.W     0x50b0
F04359  a9 00                   DC.W     0xa900
F0435B  14 67                   DC.W     0x1467
F0435D  08 41                   DC.W     0x0841
F0435F  e9 00                   DC.W     0xe900
F04361  0c 60                   DC.W     0x0c60
F04363  ee 46                   DC.W     0xee46
F04365  80 4e                   DC.W     0x804e
F04367  75 42                   DC.W     0x7542  ; 'uB'
F04369  81 12                   DC.W     0x8112
F0436B  00 41                   DC.W     0x0041
F0436D  f8 0c                   DC.W     0xf80c
F0436F  8e 61                   DC.W     0x8e61
F04371  00 c4                   DC.W     0x00c4
F04373  16 20                   DC.W     0x1620
F04375  01 58                   DC.W     0x0158
F04377  8f 3d                   DC.W     0x8f3d
F04379  40 01                   DC.W     0x4001
F0437B  02 60                   DC.W     0x0260
F0437D  0e 41                   DC.W     0x0e41
F0437F  f8 0c                   DC.W     0xf80c
F04381  8e 61                   DC.W     0x8e61
F04383  00 c4                   DC.W     0x00c4
F04385  04 42                   DC.W     0x0442
F04387  80 42                   DC.W     0x8042
F04389  ae 01                   DC.W     0xae01
F0438B  00 4e                   DC.W     0x004e
F0438D  73 2c                   DC.W     0x732c  ; 's,'
F0438F  6d 00                   DC.W     0x6d00
F04391  34 42                   DC.W     0x3442  ; '4B'
F04393  80 12                   DC.W     0x8012
F04395  2d 00                   DC.W     0x2d00
F04397  39 08                   DC.W     0x3908
F04399  01 00                   DC.W     0x0100
F0439B  00 66                   DC.W     0x0066
F0439D  08 20                   DC.W     0x0820
F0439F  4e 70                   DC.W     0x4e70  ; 'Np'
F043A1  16 4e                   DC.W     0x164e
F043A3  40 60                   DC.W     0x4060  ; '@`'
F043A5  46 1b                   DC.W     0x461b
F043A7  7c 00                   DC.W     0x7c00
F043A9  01 00                   DC.W     0x0100
F043AB  71 1b                   DC.W     0x711b
F043AD  7c 00                   DC.W     0x7c00
F043AF  06 00                   DC.W     0x0600
F043B1  70 74                   DC.W     0x7074  ; 'pt'
F043B3  02 41                   DC.W     0x0241
F043B5  ed 00                   DC.W     0xed00
F043B7  70 21                   DC.W     0x7021  ; 'p!'
F043B9  ad 00                   DC.W     0xad00
F043BB  3c 20                   DC.W     0x3c20  ; '< '
F043BD  00 67                   DC.W     0x0067
F043BF  0a 06                   DC.W     0x0a06
F043C1  ad 04                   DC.W     0xad04
F043C3  80 00                   DC.W     0x8000
F043C5  00 00                   DC.W     0x0000
F043C7  70 58                   DC.W     0x7058  ; 'pX'
F043C9  82 11                   DC.W     0x8211
F043CB  80 20                   DC.W     0x8020
F043CD  00 11                   DC.W     0x0011
F043CF  ad 00                   DC.W     0xad00
F043D1  38 20                   DC.W     0x3820  ; '8 '
F043D3  01 54                   DC.W     0x0154
F043D5  82 b4                   DC.W     0x82b4
F043D7  2d 00                   DC.W     0x2d00
F043D9  3a 63                   DC.W     0x3a63  ; ':c'
F043DB  06 1b                   DC.W     0x061b
F043DD  6d 00                   DC.W     0x6d00
F043DF  3a 00                   DC.W     0x3a00
F043E1  70 4c                   DC.W     0x704c  ; 'pL'
F043E3  ed 00                   DC.W     0xed00
F043E5  3c 00                   DC.W     0x3c00
F043E7  70 61                   DC.W     0x7061  ; 'pa'
F043E9  00 00                   DC.W     0x0000
F043EB  9e 4e                   DC.W     0x9e4e
F043ED  75 48                   DC.W     0x7548  ; 'uH'
F043EF  e7 60                   DC.W     0xe760
F043F1  00 43                   DC.W     0x0043
F043F3  ed 00                   DC.W     0xed00
F043F5  70 42                   DC.W     0x7042  ; 'pB'
F043F7  80 20                   DC.W     0x8020
F043F9  6d 00                   DC.W     0x6d00
F043FB  22 12                   DC.W     0x2212
F043FD  2d 00                   DC.W     0x2d00
F043FF  2b 67                   DC.W     0x2b67  ; '+g'
F04401  7c 30                   DC.W     0x7c30  ; '|0'
F04403  11 14                   DC.W     0x1114
F04405  30 00                   DC.W     0x3000
F04407  00 4a                   DC.W     0x004a
F04409  29 00                   DC.W     0x2900
F0440B  03 66                   DC.W     0x0366
F0440D  02 46                   DC.W     0x0246
F0440F  02 c4                   DC.W     0x02c4
F04411  29 00                   DC.W     0x2900
F04413  02 66                   DC.W     0x0266
F04415  08 43                   DC.W     0x0843
F04417  e9 00                   DC.W     0xe900
F04419  08 53                   DC.W     0x0853
F0441B  01 60                   DC.W     0x0160
F0441D  e2 30                   DC.W     0xe230
F0441F  29 00                   DC.W     0x2900
F04421  04 08                   DC.W     0x0408
F04423  29 00                   DC.W     0x2900
F04425  01 00                   DC.W     0x0100
F04427  07 67                   DC.W     0x0767
F04429  06 4a                   DC.W     0x064a
F0442B  30 00                   DC.W     0x3000
F0442D  00 60                   DC.W     0x0060
F0442F  28 11                   DC.W     0x2811
F04431  a9 00                   DC.W     0xa900
F04433  06 00                   DC.W     0x0600
F04435  00 30                   DC.W     0x0030
F04437  2d 00                   DC.W     0x2d00
F04439  26 d0                   DC.W     0x26d0
F0443B  88 08                   DC.W     0x8808
F0443D  00 00                   DC.W     0x0000
F0443F  00 66                   DC.W     0x0066
F04441  02 53                   DC.W     0x0253
F04443  80 90                   DC.W     0x8090
F04445  88 24                   DC.W     0x8824
F04447  00 4a                   DC.W     0x004a
F04449  30 00                   DC.W     0x3000
F0444B  00 55                   DC.W     0x0055
F0444D  40 6c                   DC.W     0x406c  ; '@l'
F0444F  f8 42                   DC.W     0xf842
F04451  30 20                   DC.W     0x3020  ; '0 '
F04453  00 55                   DC.W     0x0055
F04455  42 6c                   DC.W     0x426c  ; 'Bl'
F04457  f8 40                   DC.W     0xf840
F04459  c0 04                   DC.W     0xc004
F0445B  40 01                   DC.W     0x4001
F0445D  00 46                   DC.W     0x0046
F0445F  c0 08                   DC.W     0xc008
F04461  2d 00                   DC.W     0x2d00
F04463  07 00                   DC.W     0x0700
F04465  48 67                   DC.W     0x4867  ; 'Hg'
F04467  0c 48                   DC.W     0x0c48
F04469  e7 1f                   DC.W     0xe71f
F0446B  3a 61                   DC.W     0x3a61  ; ':a'
F0446D  00 ff                   DC.W     0x00ff
F0446F  20 4c                   DC.W     0x204c  ; ' L'
F04471  df 5c                   DC.W     0xdf5c
F04473  f8 4c                   DC.W     0xf84c
F04475  df 00                   DC.W     0xdf00
F04477  06 00                   DC.W     0x0600
F04479  7c 00                   DC.W     0x7c00
F0447B  01 4e                   DC.W     0x014e
F0447D  75 4c                   DC.W     0x754c  ; 'uL'
F0447F  df 00                   DC.W     0xdf00
F04481  06 02                   DC.W     0x0602
F04483  7c ff                   DC.W     0x7cff
F04485  fe 4e                   DC.W     0xfe4e
F04487  75 48                   DC.W     0x7548  ; 'uH'
