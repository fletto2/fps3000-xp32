; FPS-3000 RMS68K kernel disassembly
; ROM     : FPS3K_U11_U12_JOIN.bin
; Range   : 0xF00000-0xF04487  (17544 bytes)
; Method  : recursive descent seeded from the TRAP #0 jump
;           table at 0xF001D6 + exception vectors
; Coverage: 16662/17544 bytes as code  (95.0%)
; Instructions: 5069   Labels: 987

  f00000: 00 00                    DC.W     $0000
  f00002: 00 00                    DC.W     $0000
  f00004: 00 f0                    DC.W     $00f0
  f00006: 9c 00                    DC.W     $9c00
  f00008: 00 00                    DC.W     $0000
  f0000a: 00 00                    DC.W     $0000
  f0000c: 00 00                    DC.W     $0000
  f0000e: 00 00                    DC.W     $0000
  f00010: 00 00                    DC.W     $0000
  f00012: 00 00                    DC.W     $0000
  f00014: 00 00                    DC.W     $0000
  f00016: 00 00                    DC.W     $0000
  f00018: 00 00                    DC.W     $0000
  f0001a: 00 00                    DC.W     $0000
  f0001c: 00 00                    DC.W     $0000
  f0001e: 00 00                    DC.W     $0000
  f00020: 00 00                    DC.W     $0000
  f00022: 00 00                    DC.W     $0000
  f00024: 00 00                    DC.W     $0000
  f00026: 00 00                    DC.W     $0000
  f00028: 00 00                    DC.W     $0000
  f0002a: 00 00                    DC.W     $0000
  f0002c: 00 00                    DC.W     $0000
  f0002e: 00 00                    DC.W     $0000
  f00030: 00 00                    DC.W     $0000
  f00032: 00 00                    DC.W     $0000
  f00034: 00 00                    DC.W     $0000
  f00036: 00 00                    DC.W     $0000
  f00038: 00 00                    DC.W     $0000
  f0003a: 00 00                    DC.W     $0000
  f0003c: 00 00                    DC.W     $0000
  f0003e: 00 00                    DC.W     $0000
  f00040: 00 00                    DC.W     $0000
  f00042: 00 00                    DC.W     $0000
  f00044: 00 00                    DC.W     $0000
  f00046: 00 00                    DC.W     $0000
  f00048: 00 00                    DC.W     $0000
  f0004a: 00 00                    DC.W     $0000
  f0004c: 00 00                    DC.W     $0000
  f0004e: 00 00                    DC.W     $0000
  f00050: 00 00                    DC.W     $0000
  f00052: 00 00                    DC.W     $0000
  f00054: 00 00                    DC.W     $0000
  f00056: 00 00                    DC.W     $0000
  f00058: 00 00                    DC.W     $0000
  f0005a: 00 00                    DC.W     $0000
  f0005c: 00 00                    DC.W     $0000
  f0005e: 00 00                    DC.W     $0000
  f00060: 00 00                    DC.W     $0000
  f00062: 00 00                    DC.W     $0000
  f00064: 00 00                    DC.W     $0000
  f00066: 00 00                    DC.W     $0000
  f00068: 00 00                    DC.W     $0000
  f0006a: 00 00                    DC.W     $0000
  f0006c: 00 00                    DC.W     $0000
  f0006e: 00 00                    DC.W     $0000
  f00070: 00 00                    DC.W     $0000
  f00072: 00 00                    DC.W     $0000
  f00074: 00 00                    DC.W     $0000
  f00076: 00 00                    DC.W     $0000
  f00078: 00 00                    DC.W     $0000
  f0007a: 00 00                    DC.W     $0000
  f0007c: 00 00                    DC.W     $0000
  f0007e: 00 00                    DC.W     $0000
  f00080: 00 00                    DC.W     $0000
  f00082: 00 00                    DC.W     $0000
  f00084: 00 00                    DC.W     $0000
  f00086: 00 00                    DC.W     $0000
  f00088: 00 00                    DC.W     $0000
  f0008a: 00 00                    DC.W     $0000
  f0008c: 00 00                    DC.W     $0000
  f0008e: 00 00                    DC.W     $0000
  f00090: 00 00                    DC.W     $0000
  f00092: 00 00                    DC.W     $0000
  f00094: 00 00                    DC.W     $0000
  f00096: 00 00                    DC.W     $0000
  f00098: 00 00                    DC.W     $0000
  f0009a: 00 00                    DC.W     $0000
  f0009c: 00 00                    DC.W     $0000
  f0009e: 00 00                    DC.W     $0000
  f000a0: 00 00                    DC.W     $0000
  f000a2: 00 00                    DC.W     $0000
  f000a4: 00 00                    DC.W     $0000
  f000a6: 00 00                    DC.W     $0000
  f000a8: 00 00                    DC.W     $0000
  f000aa: 00 00                    DC.W     $0000
  f000ac: 00 00                    DC.W     $0000
  f000ae: 00 00                    DC.W     $0000
  f000b0: 00 00                    DC.W     $0000
  f000b2: 00 00                    DC.W     $0000
  f000b4: 00 00                    DC.W     $0000
  f000b6: 00 00                    DC.W     $0000
  f000b8: 00 00                    DC.W     $0000
  f000ba: 00 00                    DC.W     $0000
  f000bc: 00 00                    DC.W     $0000
  f000be: 00 00                    DC.W     $0000
  f000c0: 00 00                    DC.W     $0000
  f000c2: 00 00                    DC.W     $0000
  f000c4: 00 00                    DC.W     $0000
  f000c6: 00 00                    DC.W     $0000
  f000c8: 00 00                    DC.W     $0000
  f000ca: 00 00                    DC.W     $0000
  f000cc: 00 00                    DC.W     $0000
  f000ce: 00 00                    DC.W     $0000
  f000d0: 00 00                    DC.W     $0000
  f000d2: 00 00                    DC.W     $0000
  f000d4: 00 00                    DC.W     $0000
  f000d6: 00 00                    DC.W     $0000
  f000d8: 00 00                    DC.W     $0000
  f000da: 00 00                    DC.W     $0000
  f000dc: 00 00                    DC.W     $0000
  f000de: 00 00                    DC.W     $0000
  f000e0: 00 00                    DC.W     $0000
  f000e2: 00 00                    DC.W     $0000
  f000e4: 00 00                    DC.W     $0000
  f000e6: 00 00                    DC.W     $0000
  f000e8: 00 00                    DC.W     $0000
  f000ea: 00 00                    DC.W     $0000
  f000ec: 00 00                    DC.W     $0000
  f000ee: 00 00                    DC.W     $0000
  f000f0: 00 00                    DC.W     $0000
  f000f2: 00 00                    DC.W     $0000
  f000f4: 00 00                    DC.W     $0000
  f000f6: 00 00                    DC.W     $0000
  f000f8: 00 00                    DC.W     $0000
  f000fa: 00 00                    DC.W     $0000
  f000fc: 00 00                    DC.W     $0000
  f000fe: 00 00                    DC.W     $0000
  f00100: 4e f9 00 f0 05 0c        jmp      $f0050c.l
  f00106: 42 6f 00 06              clr.w    $6(a7)
  f0010a: 3d 7c 00 01 01 02        move.w   #$1, $102(a6)
  f00110: 4e 73                    rte      
  f00112: 4e 75                    rts      
  f00114: 4e b9                    DC.W     $4eb9
  f00116: 00 f0                    DC.W     $00f0
  f00118: 01 86                    DC.W     $0186
  f0011a: 21 56                    DC.W     $2156
  f0011c: 43 54                    DC.W     $4354
  f0011e: 00 f0                    DC.W     $00f0
  f00120: 08 96                    DC.W     $0896
  f00122: 02 f0                    DC.W     $02f0
  f00124: 0a d8                    DC.W     $0ad8
  f00126: 04 f0                    DC.W     $04f0
  f00128: 0a dc                    DC.W     $0adc
  f0012a: 05 f0                    DC.W     $05f0
  f0012c: 0a de                    DC.W     $0ade
  f0012e: 09 f0                    DC.W     $09f0
  f00130: 0a ee                    DC.W     $0aee
  f00132: 0a f0                    DC.W     $0af0
  f00134: 0a e6                    DC.W     $0ae6
  f00136: 0c 00                    DC.W     $0c00
  f00138: 00 00                    DC.W     $0000
  f0013a: 18 f0                    DC.W     $18f0
  f0013c: 09 ea                    DC.W     $09ea
  f0013e: 19 00                    DC.W     $1900
  f00140: 00 00                    DC.W     $0000
  f00142: 1c f0                    DC.W     $1cf0
  f00144: 0e c8                    DC.W     $0ec8
  f00146: 1d 00                    DC.W     $1d00
  f00148: 00 00                    DC.W     $0000
  f0014a: 1f 00                    DC.W     $1f00
  f0014c: 00 01                    DC.W     $0001
  f0014e: 20 f0                    DC.W     $20f0
  f00150: 01 ac                    DC.W     $01ac
  f00152: 21 f0                    DC.W     $21f0
  f00154: 02 62                    DC.W     $0262
  f00156: 22 f0                    DC.W     $22f0
  f00158: 0a 78                    DC.W     $0a78
  f0015a: 30 00                    DC.W     $3000
  f0015c: 00 00                    DC.W     $0000
  f0015e: 8d f0                    DC.W     $8df0
  f00160: 0a 58                    DC.W     $0a58
  f00162: 8e f0                    DC.W     $8ef0
  f00164: 01 86                    DC.W     $0186
  f00166: 8f 00                    DC.W     $8f00
  f00168: 00 00                    DC.W     $0000
  f0016a: 90 00                    DC.W     $9000
  f0016c: 00 00                    DC.W     $0000
  f0016e: 91 00                    DC.W     $9100
  f00170: 00 00                    DC.W     $0000
  f00172: 92 00                    DC.W     $9200
  f00174: 00 00                    DC.W     $0000
  f00176: 93 f0                    DC.W     $93f0
  f00178: 09 dc                    DC.W     $09dc
  f0017a: 94 00                    DC.W     $9400
  f0017c: 00 00                    DC.W     $0000
  f0017e: 00 00                    DC.W     $0000
  f00180: 00 00                    DC.W     $0000

TRAP0_dir_00:
  f00182: 4f ef 00 02              lea.l    $2(a7), a7

loc_F00186:
  f00186: 48 f8 ff ff 08 08        movem.l  d0-d7/a0-a7, $808.w
  f0018c: 40 f8 08 06              move.w   sr, $806.w
  f00190: 21 d7 08 00              move.l   (a7), $800.w
  f00194: 4e 69                    move     usp, a1
  f00196: 21 c9 08 48              move.l   a1, $848.w
  f0019a: 21 f8 00 08 08 4c        move.l   $8.w, $84c.w
  f001a0: 30 3c 02 b2              move.w   #$2b2, d0
  f001a4: 4e b9 00 f0 45 00        jsr      $f04500.l

loc_F001AA:
  f001aa: 60 fe                    bra.b    $f001aa

VEC_20_F001AC:
  f001ac: 3f 17                    move.w   (a7), -(a7)
  f001ae: 02 17 00 7f              andi.b   #$7f, (a7)
  f001b2: 54 8f                    addq.l   #$2, a7
  f001b4: 66 02                    bne.b    $f001b8
  f001b6: 4e 73                    rte      

loc_F001B8:
  f001b8: e5 88                    lsl.l    #$2, d0
  f001ba: 6b 00 ff c6              bmi.w    $f00182
  f001be: 06 80 00 f0 01 d6        addi.l   #$f001d6, d0
  f001c4: 0c 80 00 f0 02 62        cmpi.l   #$f00262, d0
  f001ca: 6c 00 ff b6              bge.w    $f00182
  f001ce: c1 88                    exg.l    d0, a0
  f001d0: 2f 10                    move.l   (a0), -(a7)
  f001d2: c1 88                    exg.l    d0, a0
  f001d4: 4e 75                    rts      
  f001d6: 00 f0                    DC.W     $00f0
  f001d8: 01 82                    DC.W     $0182
  f001da: 00 f0                    DC.W     $00f0
  f001dc: 06 ea                    DC.W     $06ea
  f001de: 00 f0                    DC.W     $00f0
  f001e0: 07 8a                    DC.W     $078a
  f001e2: 00 f0                    DC.W     $00f0
  f001e4: 07 c2                    DC.W     $07c2
  f001e6: 00 f0                    DC.W     $00f0
  f001e8: 12 40                    DC.W     $1240
  f001ea: 00 f0                    DC.W     $00f0
  f001ec: 14 96                    DC.W     $1496
  f001ee: 00 f0                    DC.W     $00f0
  f001f0: 17 10                    DC.W     $1710
  f001f2: 00 f0                    DC.W     $00f0
  f001f4: 17 c6                    DC.W     $17c6
  f001f6: 00 f0                    DC.W     $00f0
  f001f8: 17 5e                    DC.W     $175e
  f001fa: 00 f0                    DC.W     $00f0
  f001fc: 17 f6                    DC.W     $17f6
  f001fe: 00 f0                    DC.W     $00f0
  f00200: 26 aa                    DC.W     $26aa
  f00202: 00 f0                    DC.W     $00f0
  f00204: 15 be                    DC.W     $15be
  f00206: 00 f0                    DC.W     $00f0
  f00208: 18 78                    DC.W     $1878
  f0020a: 00 f0                    DC.W     $00f0
  f0020c: 17 00                    DC.W     $1700
  f0020e: 00 f0                    DC.W     $00f0
  f00210: 08 16                    DC.W     $0816
  f00212: 00 f0                    DC.W     $00f0
  f00214: 3b 32                    DC.W     $3b32
  f00216: 00 f0                    DC.W     $00f0
  f00218: 34 96                    DC.W     $3496
  f0021a: 00 f0                    DC.W     $00f0
  f0021c: 24 00                    DC.W     $2400
  f0021e: 00 f0                    DC.W     $00f0
  f00220: 1b 72                    DC.W     $1b72
  f00222: 00 f0                    DC.W     $00f0
  f00224: 0d a6                    DC.W     $0da6
  f00226: 00 f0                    DC.W     $00f0
  f00228: 35 66                    DC.W     $3566
  f0022a: 00 f0                    DC.W     $00f0
  f0022c: 08 26                    DC.W     $0826
  f0022e: 00 f0                    DC.W     $00f0
  f00230: 2c 6e                    DC.W     $2c6e
  f00232: 00 f0                    DC.W     $00f0
  f00234: 15 da                    DC.W     $15da
  f00236: 00 f0                    DC.W     $00f0
  f00238: 16 02                    DC.W     $1602
  f0023a: 00 f0                    DC.W     $00f0
  f0023c: 27 66                    DC.W     $2766
  f0023e: 00 f0                    DC.W     $00f0
  f00240: 17 62                    DC.W     $1762
  f00242: 00 f0                    DC.W     $00f0
  f00244: 14 90                    DC.W     $1490
  f00246: 00 f0                    DC.W     $00f0
  f00248: 0f 98                    DC.W     $0f98
  f0024a: 00 f0                    DC.W     $00f0
  f0024c: 21 d0                    DC.W     $21d0
  f0024e: 00 f0                    DC.W     $00f0
  f00250: 11 08                    DC.W     $1108
  f00252: 00 f0                    DC.W     $00f0
  f00254: 28 94                    DC.W     $2894
  f00256: 00 f0                    DC.W     $00f0
  f00258: 01 82                    DC.W     $0182
  f0025a: 00 f0                    DC.W     $00f0
  f0025c: 10 f2                    DC.W     $10f2
  f0025e: 00 f0                    DC.W     $00f0
  f00260: 11 98                    DC.W     $1198

VEC_21_F00262:
  f00262: 3f 17                    move.w   (a7), -(a7)
  f00264: 02 2f 00 0c 00 01        andi.b   #$c, $1(a7)
  f0026a: 02 17 00 7f              andi.b   #$7f, (a7)
  f0026e: 67 08                    beq.b    $f00278
  f00270: 0c 2f 00 0c 00 01        cmpi.b   #$c, $1(a7)
  f00276: 67 08                    beq.b    $f00280

loc_F00278:
  f00278: 54 8f                    addq.l   #$2, a7
  f0027a: 60 00 00 4a              bra.w    $f002c6
  f0027e: 4a fb                    DC.W     $4afb

loc_F00280:
  f00280: 58 8f                    addq.l   #$4, a7
  f00282: 5d 97                    subq.l   #$6, (a7)
  f00284: 48 e7 ff fe              movem.l  d0-d7/a0-a6, -(a7)
  f00288: 2a 79 00 00 0c 6e        movea.l  $c6e.l, a5
  f0028e: 2c 6d 00 04              movea.l  $4(a5), a6
  f00292: 4b ed 00 08              lea.l    $8(a5), a5
  f00296: 28 6f 00 3c              movea.l  $3c(a7), a4

loc_F0029A:
  f0029a: b9 ed 00 0a              cmpa.l   $a(a5), a4
  f0029e: db fc 00 00 00 0e        adda.l   #$e, a5
  f002a4: 67 04                    beq.b    $f002aa
  f002a6: bd cd                    cmpa.l   a5, a6
  f002a8: 64 f0                    bcc.b    $f0029a

loc_F002AA:
  f002aa: 66 16                    bne.b    $f002c2
  f002ac: 2c 6d ff f4              movea.l  -$c(a5), a6
  f002b0: 41 d6                    lea.l    (a6), a0
  f002b2: 61 00 29 b8              bsr.w    $f02c6c
  f002b6: 4c df 7f ff              movem.l  (a7)+, d0-d7/a0-a6
  f002ba: 4f ef 00 04              lea.l    $4(a7), a7
  f002be: 4e 73                    rte      
  f002c0: 60 04                    bra.b    $f002c6

loc_F002C2:
  f002c2: 61 00 fe c2              bsr.w    $f00186

loc_F002C6:
  f002c6: 3f 17                    move.w   (a7), -(a7)
  f002c8: 02 17 00 7f              andi.b   #$7f, (a7)
  f002cc: 54 8f                    addq.l   #$2, a7
  f002ce: 66 00 06 6a              bne.w    $f0093a
  f002d2: 61 00 03 dc              bsr.w    $f006b0
  f002d6: 3d 6e 01 00 00 5c        move.w   $100(a6), $5c(a6)
  f002dc: 08 38 00 0f 0c 34        btst.b   #$f, $c34.w
  f002e2: 67 06                    beq.b    $f002ea
  f002e4: 61 00 13 a2              bsr.w    $f01688
  f002e8: ff 15                    dc.w     $ff15

loc_F002EA:
  f002ea: 08 2e 00 06 00 29        btst.b   #$6, $29(a6)
  f002f0: 67 10                    beq.b    $f00302
  f002f2: 22 2e 01 48              move.l   $148(a6), d1
  f002f6: 08 01 00 01              btst.b   #$1, d1
  f002fa: 67 06                    beq.b    $f00302
  f002fc: 7e 01                    moveq    #$1, d7
  f002fe: 61 00 0a 58              bsr.w    $f00d58

loc_F00302:
  f00302: 3d 40 01 00              move.w   d0, $100(a6)
  f00306: 1d 7c 00 08 01 00        move.b   #$8, $100(a6)
  f0030c: 42 6e 01 02              clr.w    $102(a6)

loc_F00310:
  f00310: 02 80 00 00 ff ff        andi.l   #$ffff, d0
  f00316: 4a 40                    tst.w    d0
  f00318: 6b 5e                    bmi.b    $f00378
  f0031a: e5 88                    lsl.l    #$2, d0
  f0031c: 0c 80 00 00 01 30        cmpi.l   #$130, d0
  f00322: 6e 00 00 a2              bgt.w    $f003c6
  f00326: 45 f9 00 f0 03 d8        lea.l    $f003d8.l, a2
  f0032c: d5 c0                    adda.l   d0, a2
  f0032e: 34 2a 00 02              move.w   $2(a2), d2
  f00332: 3f 02                    move.w   d2, -(a7)
  f00334: 08 02 00 07              btst.b   #$7, d2
  f00338: 67 30                    beq.b    $f0036a
  f0033a: 42 85                    clr.l    d5
  f0033c: 1a 17                    move.b   (a7), d5
  f0033e: 2c 08                    move.l   a0, d6
  f00340: 20 6e 00 36              movea.l  $36(a6), a0
  f00344: 61 00 14 16              bsr.w    $f0175c
  f00348: 60 08                    bra.b    $f00352
  f0034a: 4e 71                    nop      
  f0034c: 54 6e 01 02              addq.w   #$2, $102(a6)
  f00350: 60 60                    bra.b    $f003b2

loc_F00352:
  f00352: 28 46                    movea.l  d6, a4
  f00354: 08 02 00 06              btst.b   #$6, d2
  f00358: 67 10                    beq.b    $f0036a
  f0035a: 41 d4                    lea.l    (a4), a0
  f0035c: 61 00 13 b0              bsr.w    $f0170e
  f00360: 60 06                    bra.b    $f00368
  f00362: 56 6e 01 02              addq.w   #$3, $102(a6)
  f00366: 60 4a                    bra.b    $f003b2

loc_F00368:
  f00368: 2a 48                    movea.l  a0, a5

loc_F0036A:
  f0036a: d4 d2                    adda.w   (a2), a2

loc_F0036C:
  f0036c: 48 79 00 f0 03 b2        pea.l    $f003b2.l
  f00372: 3f 3c 20 00              move.w   #$2000, -(a7)
  f00376: 4e d2                    jmp      (a2)

loc_F00378:
  f00378: 24 78 0c 28              movea.l  $c28.w, a2
  f0037c: 24 0a                    move.l   a2, d2
  f0037e: 67 46                    beq.b    $f003c6
  f00380: 44 40                    neg.w    d0
  f00382: b0 6a 00 04              cmp.w    $4(a2), d0
  f00386: 6e 3e                    bgt.b    $f003c6
  f00388: 53 80                    subq.l   #$1, d0
  f0038a: c0 fc 00 0a              mulu.w   #$a, d0
  f0038e: 45 f2 00 06              lea.l    $6(a2, d0.w), a2
  f00392: 4a aa 00 06              tst.l    $6(a2)
  f00396: 67 2e                    beq.b    $f003c6
  f00398: 08 2a 00 04 00 05        btst.b   #$4, $5(a2)
  f0039e: 66 08                    bne.b    $f003a8
  f003a0: 22 12                    move.l   (a2), d1
  f003a2: b2 ae 00 14              cmp.l    $14(a6), d1
  f003a6: 66 1e                    bne.b    $f003c6

loc_F003A8:
  f003a8: 3f 2a 00 04              move.w   $4(a2), -(a7)
  f003ac: 24 6a 00 06              movea.l  $6(a2), a2
  f003b0: 60 ba                    bra.b    $f0036c

loc_F003B2:
  f003b2: 30 1f                    move.w   (a7)+, d0
  f003b4: 02 80 00 00 00 0f        andi.l   #$f, d0
  f003ba: e3 88                    lsl.l    #$1, d0
  f003bc: 41 f9 00 f0 06 50        lea.l    $f00650.l, a0
  f003c2: 4e f0 00 00              jmp      (a0, d0.w)

loc_F003C6:
  f003c6: 3d 7c 00 01 01 02        move.w   #$1, $102(a6)
  f003cc: 60 00 02 a2              bra.w    $f00670

TRAP1_dir_00:
  f003d0: 3d 7c 00 01 01 02        move.w   #$1, $102(a6)
  f003d6: 4e 73                    rte      
  f003d8: ff f8                    DC.W     $fff8
  f003da: 00 00                    DC.W     $0000
  f003dc: 15 20                    DC.W     $1520
  f003de: 1c c0                    DC.W     $1cc0
  f003e0: 16 aa                    DC.W     $16aa
  f003e2: 18 c0                    DC.W     $18c0
  f003e4: 18 1e                    DC.W     $181e
  f003e6: 18 c0                    DC.W     $18c0
  f003e8: 19 8a                    DC.W     $198a
  f003ea: 18 80                    DC.W     $1880
  f003ec: 19 8e                    DC.W     $198e
  f003ee: 18 c0                    DC.W     $18c0
  f003f0: 1a 92                    DC.W     $1a92
  f003f2: 1c c0                    DC.W     $1cc0
  f003f4: 1b 56                    DC.W     $1b56
  f003f6: 18 80                    DC.W     $1880
  f003f8: 33 6c                    DC.W     $336c
  f003fa: 00 00                    DC.W     $0000
  f003fc: 1c 38                    DC.W     $1c38
  f003fe: 1c c0                    DC.W     $1cc0
  f00400: ff d0                    DC.W     $ffd0
  f00402: 00 00                    DC.W     $0000
  f00404: 24 9a                    DC.W     $249a
  f00406: 1c 80                    DC.W     $1c80
  f00408: ff c8                    DC.W     $ffc8
  f0040a: 00 00                    DC.W     $0000
  f0040c: 26 28                    DC.W     $2628
  f0040e: 0a 82                    DC.W     $0a82
  f00410: 2b 24                    DC.W     $2b24
  f00412: 00 03                    DC.W     $0003
  f00414: 2b 50                    DC.W     $2b50
  f00416: 00 03                    DC.W     $0003
  f00418: 29 e4                    DC.W     $29e4
  f0041a: 0a 82                    DC.W     $0a82
  f0041c: 28 90                    DC.W     $2890
  f0041e: 00 01                    DC.W     $0001
  f00420: 28 94                    DC.W     $2894
  f00422: 08 c2                    DC.W     $08c2
  f00424: 28 1a                    DC.W     $281a
  f00426: 00 01                    DC.W     $0001
  f00428: 28 3e                    DC.W     $283e
  f0042a: 08 c2                    DC.W     $08c2
  f0042c: 28 a2                    DC.W     $28a2
  f0042e: 00 01                    DC.W     $0001
  f00430: 29 86                    DC.W     $2986
  f00432: 00 01                    DC.W     $0001
  f00434: 2c de                    DC.W     $2cde
  f00436: 08 c0                    DC.W     $08c0
  f00438: 29 86                    DC.W     $2986
  f0043a: 09 c2                    DC.W     $09c2
  f0043c: 27 4a                    DC.W     $274a
  f0043e: 08 80                    DC.W     $0880
  f00440: 2c ee                    DC.W     $2cee
  f00442: 24 80                    DC.W     $2480
  f00444: 2c f8                    DC.W     $2cf8
  f00446: 38 80                    DC.W     $3880
  f00448: 38 7a                    DC.W     $387a
  f0044a: 0e c0                    DC.W     $0ec0
  f0044c: 34 34                    DC.W     $3434
  f0044e: 16 c0                    DC.W     $16c0
  f00450: 28 7a                    DC.W     $287a
  f00452: 00 01                    DC.W     $0001
  f00454: 1f 30                    DC.W     $1f30
  f00456: 18 c2                    DC.W     $18c2
  f00458: 1f a2                    DC.W     $1fa2
  f0045a: 00 00                    DC.W     $0000
  f0045c: 22 1e                    DC.W     $221e
  f0045e: 00 00                    DC.W     $0000
  f00460: 20 d0                    DC.W     $20d0
  f00462: 00 00                    DC.W     $0000
  f00464: 1f ca                    DC.W     $1fca
  f00466: 12 c2                    DC.W     $12c2
  f00468: 23 e8                    DC.W     $23e8
  f0046a: 00 01                    DC.W     $0001
  f0046c: 23 56                    DC.W     $2356
  f0046e: 00 04                    DC.W     $0004
  f00470: ff 60                    DC.W     $ff60
  f00472: 00 00                    DC.W     $0000
  f00474: ff 5c                    DC.W     $ff5c
  f00476: 00 00                    DC.W     $0000
  f00478: ff 58                    DC.W     $ff58
  f0047a: 00 00                    DC.W     $0000
  f0047c: 2c d4                    DC.W     $2cd4
  f0047e: 0a 80                    DC.W     $0a80
  f00480: 2e 7c                    DC.W     $2e7c
  f00482: 08 80                    DC.W     $0880
  f00484: 2e 74                    DC.W     $2e74
  f00486: 08 80                    DC.W     $0880
  f00488: 2e da                    DC.W     $2eda
  f0048a: 0a 80                    DC.W     $0a80
  f0048c: 2c be                    DC.W     $2cbe
  f0048e: 0a 80                    DC.W     $0a80
  f00490: 30 00                    DC.W     $3000
  f00492: 00 00                    DC.W     $0000
  f00494: ff 3c                    DC.W     $ff3c
  f00496: 00 00                    DC.W     $0000
  f00498: ff 38                    DC.W     $ff38
  f0049a: 00 00                    DC.W     $0000
  f0049c: ff 34                    DC.W     $ff34
  f0049e: 00 00                    DC.W     $0000
  f004a0: ff 30                    DC.W     $ff30
  f004a2: 00 00                    DC.W     $0000
  f004a4: 35 70                    DC.W     $3570
  f004a6: 06 80                    DC.W     $0680
  f004a8: 35 fa                    DC.W     $35fa
  f004aa: 00 00                    DC.W     $0000
  f004ac: 36 ba                    DC.W     $36ba
  f004ae: 00 00                    DC.W     $0000
  f004b0: 37 22                    DC.W     $3722
  f004b2: 14 c0                    DC.W     $14c0
  f004b4: ff 1c                    DC.W     $ff1c
  f004b6: 00 00                    DC.W     $0000
  f004b8: ff 18                    DC.W     $ff18
  f004ba: 00 00                    DC.W     $0000
  f004bc: ff 14                    DC.W     $ff14
  f004be: 00 00                    DC.W     $0000
  f004c0: 1e 20                    DC.W     $1e20
  f004c2: 08 80                    DC.W     $0880
  f004c4: 34 fe                    DC.W     $34fe
  f004c6: 00 00                    DC.W     $0000
  f004c8: 38 44                    DC.W     $3844
  f004ca: 00 00                    DC.W     $0000
  f004cc: 1c 16                    DC.W     $1c16
  f004ce: 10 c0                    DC.W     $10c0
  f004d0: 1d ae                    DC.W     $1dae
  f004d2: 04 80                    DC.W     $0480
  f004d4: fe fc                    DC.W     $fefc
  f004d6: 00 00                    DC.W     $0000
  f004d8: 2f dc                    DC.W     $2fdc
  f004da: 10 c1                    DC.W     $10c1
  f004dc: 30 94                    DC.W     $3094
  f004de: 10 c0                    DC.W     $10c0
  f004e0: 30 e6                    DC.W     $30e6
  f004e2: 0c c0                    DC.W     $0cc0
  f004e4: 31 3c                    DC.W     $313c
  f004e6: 0c c0                    DC.W     $0cc0
  f004e8: 31 84                    DC.W     $3184
  f004ea: 0c c0                    DC.W     $0cc0
  f004ec: 31 d6                    DC.W     $31d6
  f004ee: 0c c0                    DC.W     $0cc0
  f004f0: fe e0                    DC.W     $fee0
  f004f2: 00 00                    DC.W     $0000
  f004f4: fe dc                    DC.W     $fedc
  f004f6: 00 00                    DC.W     $0000
  f004f8: 19 84                    DC.W     $1984
  f004fa: 1c 80                    DC.W     $1c80
  f004fc: 32 b8                    DC.W     $32b8
  f004fe: 08 80                    DC.W     $0880
  f00500: 33 62                    DC.W     $3362
  f00502: 08 80                    DC.W     $0880
  f00504: fe cc                    DC.W     $fecc
  f00506: 00 00                    DC.W     $0000
  f00508: 1d 0e                    DC.W     $1d0e
  f0050a: 10 c0                    DC.W     $10c0

loc_F0050C:
  f0050c: 2e 78 0c 08              movea.l  $c08.w, a7

loc_F00510:
  f00510: 46 fc 20 00              move.w   #$2000, sr
  f00514: 61 00 0a ac              bsr.w    $f00fc2
  f00518: 4d f8 0c 08              lea.l    $c08.w, a6

loc_F0051C:
  f0051c: 22 4e                    movea.l  a6, a1
  f0051e: 4a a9 00 0c              tst.l    $c(a1)
  f00522: 67 ec                    beq.b    $f00510
  f00524: 00 7c 07 00              ori.w    #$700, sr
  f00528: 2c 69 00 0c              movea.l  $c(a1), a6
  f0052c: 30 2e 00 2c              move.w   $2c(a6), d0
  f00530: 02 40 ff 00              andi.w   #$ff00, d0
  f00534: 66 e6                    bne.b    $f0051c
  f00536: 23 6e 00 0c 00 0c        move.l   $c(a6), $c(a1)
  f0053c: 08 ae 00 04 00 2d        bclr.b   #$4, $2d(a6)
  f00542: 21 ce 0c 0c              move.l   a6, $c0c.w
  f00546: 2a 4e                    movea.l  a6, a5
  f00548: db fc 00 00 01 00        adda.l   #$100, a5
  f0054e: 10 2e 00 72              move.b   $72(a6), d0

loc_F00552:
  f00552: 3f 25                    move.w   -(a5), -(a7)
  f00554: 32 0d                    move.w   a5, d1
  f00556: b0 01                    cmp.b    d1, d0
  f00558: 66 f8                    bne.b    $f00552
  f0055a: 42 38 0c 5b              clr.b    $c5b.w
  f0055e: 02 7c f8 ff              andi.w   #$f8ff, sr
  f00562: 31 f8 0c 54 0c 52        move.w   $c54.w, $c52.w

loc_F00568:
  f00568: 08 ae 00 06 00 2d        bclr.b   #$6, $2d(a6)
  f0056e: 66 50                    bne.b    $f005c0
  f00570: 08 2e 00 07 00 2d        btst.b   #$7, $2d(a6)
  f00576: 66 54                    bne.b    $f005cc
  f00578: 08 ae 00 05 00 2d        bclr.b   #$5, $2d(a6)
  f0057e: 66 58                    bne.b    $f005d8

loc_F00580:
  f00580: 4a b8 0c 1c              tst.l    $c1c.w
  f00584: 67 08                    beq.b    $f0058e
  f00586: 2a 6e 00 36              movea.l  $36(a6), a5
  f0058a: 61 00 01 46              bsr.w    $f006d2

loc_F0058E:
  f0058e: 20 6e 01 3c              movea.l  $13c(a6), a0
  f00592: 4e 60                    move     a0, usp
  f00594: 4c ee 3f ff 01 00        movem.l  $100(a6), d0-d7/a0-a5
  f0059a: 08 38 00 0a 0c 34        btst.b   #$a, $c34.w
  f005a0: 67 06                    beq.b    $f005a8
  f005a2: 61 00 10 e4              bsr.w    $f01688
  f005a6: fd 10                    dc.w     $fd10

loc_F005A8:
  f005a8: 08 ae 00 0f 01 48        bclr.b   #$f, $148(a6)
  f005ae: 66 06                    bne.b    $f005b6
  f005b0: 2c 6e 01 38              movea.l  $138(a6), a6
  f005b4: 4e 73                    rte      

loc_F005B6:
  f005b6: 2c 6e 01 38              movea.l  $138(a6), a6
  f005ba: 00 7c 80 00              ori.w    #$8000, sr
  f005be: 4e 73                    rte      

loc_F005C0:
  f005c0: 4c ee 7f ff 00 74        movem.l  $74(a6), d0-d7/a0-a6
  f005c6: 1d 40 00 26              move.b   d0, $26(a6)
  f005ca: 4e 73                    rte      

loc_F005CC:
  f005cc: 48 7a ff 3e              pea.l    $f0050c(pc)
  f005d0: 3f 3c 20 00              move.w   #$2000, -(a7)
  f005d4: 60 00 29 8e              bra.w    $f02f64

loc_F005D8:
  f005d8: 2a 6e 00 40              movea.l  $40(a6), a5
  f005dc: 7a 42                    moveq    #$42, d5
  f005de: 08 2d 00 0b 00 04        btst.b   #$b, $4(a5)
  f005e4: 67 02                    beq.b    $f005e8
  f005e6: 7a 06                    moveq    #$6, d5

loc_F005E8:
  f005e8: 2c 2e 01 3c              move.l   $13c(a6), d6
  f005ec: 9c 85                    sub.l    d5, d6
  f005ee: 2e 05                    move.l   d5, d7
  f005f0: 20 6e 00 36              movea.l  $36(a6), a0
  f005f4: 61 00 11 66              bsr.w    $f0175c
  f005f8: 60 0c                    bra.b    $f00606
  f005fa: 4e 71                    nop      
  f005fc: 08 ec 00 0a 00 04        bset.b   #$a, $4(a4)
  f00602: 60 00 ff 7c              bra.w    $f00580

loc_F00606:
  f00606: dc 87                    add.l    d7, d6
  f00608: 28 46                    movea.l  d6, a4
  f0060a: 39 6e 00 fa ff fa        move.w   $fa(a6), -$6(a4)
  f00610: 29 6e 00 fc ff fc        move.l   $fc(a6), -$4(a4)
  f00616: 5d ae 01 3c              subq.l   #$6, $13c(a6)
  f0061a: 08 2d 00 0b 00 04        btst.b   #$b, $4(a5)
  f00620: 66 20                    bne.b    $f00642
  f00622: 4c ee 0f ff 01 00        movem.l  $100(a6), d0-d7/a0-a3
  f00628: 48 ec 0f ff ff be        movem.l  d0-d7/a0-a3, -$42(a4)
  f0062e: 4c ee 00 07 01 30        movem.l  $130(a6), d0-d2
  f00634: 48 ec 00 07 ff ee        movem.l  d0-d2, -$12(a4)
  f0063a: 04 ae 00 00 00 3c 01 3c  subi.l   #$3c, $13c(a6)

loc_F00642:
  f00642: 2f 6d 00 12 00 02        move.l   $12(a5), $2(a7)
  f00648: 60 00 ff 36              bra.w    $f00580

loc_F0064C:
  f0064c: 60 00 fe be              bra.w    $f0050c

loc_F00650:
  f00650: 60 08                    bra.b    $f0065a
  f00652: 60 16                    bra.b    $f0066a
  f00654: 60 1a                    bra.b    $f00670
  f00656: 60 f4                    bra.b    $f0064c
  f00658: 60 22                    bra.b    $f0067c

loc_F0065A:
  f0065a: 4a 38 0c 5b              tst.b    $c5b.w
  f0065e: 66 10                    bne.b    $f00670
  f00660: 61 30                    bsr.b    $f00692
  f00662: 3e ae 00 fa              move.w   $fa(a6), (a7)
  f00666: 60 00 ff 00              bra.w    $f00568

loc_F0066A:
  f0066a: 4a 6e 01 02              tst.w    $102(a6)
  f0066e: 67 06                    beq.b    $f00676

loc_F00670:
  f00670: 41 d6                    lea.l    (a6), a0
  f00672: 61 00 01 88              bsr.w    $f007fc

loc_F00676:
  f00676: 48 7a fe 94              pea.l    $f0050c(pc)
  f0067a: 60 16                    bra.b    $f00692

loc_F0067C:
  f0067c: 3e ae 00 fa              move.w   $fa(a6), (a7)
  f00680: 48 7a fe e6              pea.l    $f00568(pc)
  f00684: 60 1c                    bra.b    $f006a2

loc_F00686:
  f00686: 41 d6                    lea.l    (a6), a0
  f00688: 61 00 01 72              bsr.w    $f007fc

loc_F0068C:
  f0068c: 48 7a fe 7e              pea.l    $f0050c(pc)
  f00690: 60 10                    bra.b    $f006a2

loc_F00692:
  f00692: 4a 6e 01 02              tst.w    $102(a6)
  f00696: 66 04                    bne.b    $f0069c
  f00698: 42 ae 01 00              clr.l    $100(a6)

loc_F0069C:
  f0069c: 40 c1                    move.w   sr, d1
  f0069e: 1d 41 00 fb              move.b   d1, $fb(a6)

loc_F006A2:
  f006a2: 2d 6f 00 06 00 fc        move.l   $6(a7), $fc(a6)
  f006a8: 1d 7c 00 fa 00 72        move.b   #$fa, $72(a6)
  f006ae: 4e 75                    rts      

loc_F006B0:
  f006b0: 48 56                    pea.l    (a6)
  f006b2: 2c 78 0c 0c              movea.l  $c0c.w, a6
  f006b6: 48 ee 3f ff 01 00        movem.l  d0-d7/a0-a5, $100(a6)
  f006bc: 2d 5f 01 38              move.l   (a7)+, $138(a6)
  f006c0: 4e 69                    move     usp, a1
  f006c2: 2d 49 01 3c              move.l   a1, $13c(a6)
  f006c6: 22 78 0c 08              movea.l  $c08.w, a1
  f006ca: 3d 69 ff fa 00 fa        move.w   -$6(a1), $fa(a6)
  f006d0: 4e 75                    rts      

loc_F006D2:
  f006d2: 40 e7                    move.w   sr, -(a7)

loc_F006D4:
  f006d4: 00 7c 07 00              ori.w    #$700, sr
  f006d8: 08 38 00 08 0c 34        btst.b   #$8, $c34.w
  f006de: 67 06                    beq.b    $f006e6
  f006e0: 61 00 0f a6              bsr.w    $f01688
  f006e4: dd 08                    addx.b   -(a0), -(a6)

loc_F006E6:
  f006e6: 4e 73                    rte      

TRAP0_T0P_bsr:
  f006e8: 40 e7                    move.w   sr, -(a7)

TRAP0_T0P:
  f006ea: 00 7c 07 00              ori.w    #$700, sr

loc_F006EE:
  f006ee: 4a d0                    tas.b    (a0)
  f006f0: 6b fc                    bmi.b    $f006ee
  f006f2: 30 10                    move.w   (a0), d0
  f006f4: e3 48                    lsl.w    #$1, d0
  f006f6: e2 40                    asr.w    #$1, d0
  f006f8: 53 40                    subq.w   #$1, d0
  f006fa: 30 80                    move.w   d0, (a0)
  f006fc: 6b 02                    bmi.b    $f00700
  f006fe: 4e 73                    rte      

loc_F00700:
  f00700: 61 3a                    bsr.b    $f0073c
  f00702: 61 14                    bsr.b    $f00718
  f00704: 08 90 00 0f              bclr.b   #$f, (a0)
  f00708: 46 df                    move.w   (a7)+, sr
  f0070a: 2e 78 0c 08              movea.l  $c08.w, a7
  f0070e: 41 d6                    lea.l    (a6), a0
  f00710: 61 00 00 ae              bsr.w    $f007c0
  f00714: 60 00 fd f6              bra.w    $f0050c

loc_F00718:
  f00718: 08 ee 00 0d 00 2c        bset.b   #$d, $2c(a6)
  f0071e: 42 ae 00 20              clr.l    $20(a6)
  f00722: 20 28 00 02              move.l   $2(a0), d0
  f00726: 66 06                    bne.b    $f0072e
  f00728: 21 4e 00 02              move.l   a6, $2(a0)
  f0072c: 4e 75                    rts      

loc_F0072E:
  f0072e: 2a 40                    movea.l  d0, a5
  f00730: 20 2d 00 20              move.l   $20(a5), d0
  f00734: 66 f8                    bne.b    $f0072e
  f00736: 2b 4e 00 20              move.l   a6, $20(a5)
  f0073a: 4e 75                    rts      

loc_F0073C:
  f0073c: 10 2e 00 26              move.b   $26(a6), d0
  f00740: 1d 7c 00 f0 00 26        move.b   #$f0, $26(a6)
  f00746: 08 ee 00 06 00 2d        bset.b   #$6, $2d(a6)
  f0074c: 48 ee 7f ff 00 74        movem.l  d0-d7/a0-a6, $74(a6)
  f00752: 48 e7 01 0c              movem.l  d7/a4-a5, -(a7)
  f00756: 20 38 0c 08              move.l   $c08.w, d0
  f0075a: 4b ef 00 10              lea.l    $10(a7), a5
  f0075e: 90 8d                    sub.l    a5, d0
  f00760: 0c 80 00 00 00 50        cmpi.l   #$50, d0
  f00766: 6f 04                    ble.b    $f0076c
  f00768: 61 00 fa 1c              bsr.w    $f00186

loc_F0076C:
  f0076c: 2e 0d                    move.l   a5, d7
  f0076e: 02 87 00 00 00 ff        andi.l   #$ff, d7
  f00774: 49 f6 70 00              lea.l    (a6, d7.w), a4
  f00778: 1d 47 00 72              move.b   d7, $72(a6)

loc_F0077C:
  f0077c: 38 dd                    move.w   (a5)+, (a4)+
  f0077e: 55 40                    subq.w   #$2, d0
  f00780: 6e fa                    bgt.b    $f0077c
  f00782: 4c df 30 80              movem.l  (a7)+, d7/a4-a5
  f00786: 4e 75                    rts      

TRAP0_T0V_bsr:
  f00788: 40 e7                    move.w   sr, -(a7)

TRAP0_T0V:
  f0078a: 00 7c 07 00              ori.w    #$700, sr

loc_F0078E:
  f0078e: 4a d0                    tas.b    (a0)
  f00790: 6b fc                    bmi.b    $f0078e
  f00792: 30 10                    move.w   (a0), d0
  f00794: e3 48                    lsl.w    #$1, d0
  f00796: e2 40                    asr.w    #$1, d0
  f00798: 52 40                    addq.w   #$1, d0
  f0079a: 6f 04                    ble.b    $f007a0
  f0079c: 30 80                    move.w   d0, (a0)
  f0079e: 4e 73                    rte      

loc_F007A0:
  f007a0: 2f 09                    move.l   a1, -(a7)
  f007a2: 22 68 00 02              movea.l  $2(a0), a1
  f007a6: 21 69 00 20 00 02        move.l   $20(a1), $2(a0)
  f007ac: 08 80 00 0f              bclr.b   #$f, d0
  f007b0: 30 80                    move.w   d0, (a0)
  f007b2: 42 a9 00 20              clr.l    $20(a1)
  f007b6: 08 a9 00 0d 00 2c        bclr.b   #$d, $2c(a1)
  f007bc: 22 5f                    movea.l  (a7)+, a1
  f007be: 4e 73                    rte      

TRAP0_T0RYDLAY_bsr:
  f007c0: 40 e7                    move.w   sr, -(a7)

TRAP0_T0RYDLAY:
  f007c2: 08 e8 00 04 00 2d        bset.b   #$4, $2d(a0)
  f007c8: 66 30                    bne.b    $f007fa
  f007ca: 48 e7 00 60              movem.l  a1-a2, -(a7)
  f007ce: 43 f8 0c 08              lea.l    $c08.w, a1
  f007d2: 00 7c 07 00              ori.w    #$700, sr
  f007d6: 10 28 00 26              move.b   $26(a0), d0

loc_F007DA:
  f007da: 24 49                    movea.l  a1, a2
  f007dc: 22 6a 00 0c              movea.l  $c(a2), a1
  f007e0: b3 fc 00 00 00 00        cmpa.l   #$0, a1
  f007e6: 67 06                    beq.b    $f007ee
  f007e8: b0 29 00 26              cmp.b    $26(a1), d0
  f007ec: 63 ec                    bls.b    $f007da

loc_F007EE:
  f007ee: 21 49 00 0c              move.l   a1, $c(a0)
  f007f2: 25 48 00 0c              move.l   a0, $c(a2)
  f007f6: 4c df 06 00              movem.l  (a7)+, a1-a2

loc_F007FA:
  f007fa: 4e 73                    rte      

loc_F007FC:
  f007fc: 11 68 00 24 00 26        move.b   $24(a0), $26(a0)
  f00802: 60 bc                    bra.b    $f007c0

loc_F00804:
  f00804: 10 28 00 24              move.b   $24(a0), d0
  f00808: 02 00 00 f0              andi.b   #$f0, d0
  f0080c: 11 40 00 26              move.b   d0, $26(a0)
  f00810: 60 ae                    bra.b    $f007c0

loc_F00812:
  f00812: 60 ac                    bra.b    $f007c0

TRAP0_T0PAUSE_bsr:
  f00814: 40 e7                    move.w   sr, -(a7)

TRAP0_T0PAUSE:
  f00816: 1d 7c 00 f0 00 25        move.b   #$f0, $25(a6)
  f0081c: 61 00 ff 1e              bsr.w    $f0073c
  f00820: 60 00 fc ea              bra.w    $f0050c

TRAP0_T0EXABRT_bsr:
  f00824: 40 e7                    move.w   sr, -(a7)

TRAP0_T0EXABRT:
  f00826: 08 c7 00 0f              bset.b   #$f, d7
  f0082a: 31 47 00 2a              move.w   d7, $2a(a0)
  f0082e: 42 68 00 5c              clr.w    $5c(a0)
  f00832: 08 e8 00 01 00 29        bset.b   #$1, $29(a0)
  f00838: 21 7c 45 58 45 43 00 b0  move.l   #$45584543, $b0(a0)
  f00840: 21 7c 20 20 20 20 00 b4  move.l   #$20202020, $b4(a0)
  f00848: 3c 28 00 2c              move.w   $2c(a0), d6
  f0084c: 08 c6 00 07              bset.b   #$7, d6
  f00850: 31 46 00 2e              move.w   d6, $2e(a0)
  f00854: bd c8                    cmpa.l   a0, a6
  f00856: 67 24                    beq.b    $f0087c
  f00858: 02 46 2d ff              andi.w   #$2dff, d6
  f0085c: 08 86 00 0a              bclr.b   #$a, d6
  f00860: 67 04                    beq.b    $f00866
  f00862: 08 86 00 06              bclr.b   #$6, d6

loc_F00866:
  f00866: 31 46 00 2c              move.w   d6, $2c(a0)
  f0086a: 11 7c 00 f0 00 26        move.b   #$f0, $26(a0)
  f00870: 08 06 00 0d              btst.b   #$d, d6
  f00874: 66 04                    bne.b    $f0087a
  f00876: 61 00 ff 48              bsr.w    $f007c0

loc_F0087A:
  f0087a: 4e 73                    rte      

loc_F0087C:
  f0087c: 31 46 00 2c              move.w   d6, $2c(a0)
  f00880: 5c 8f                    addq.l   #$6, a7
  f00882: 20 3c 00 00 00 0f        move.l   #$f, d0
  f00888: 31 57 00 fa              move.w   (a7), $fa(a0)
  f0088c: 21 6f 00 02 00 fc        move.l   $2(a7), $fc(a0)
  f00892: 60 00 fa 7c              bra.w    $f00310

VEC_0C_F00896:
  f00896: 08 38 00 0e 0c 34        btst.b   #$e, $c34.w
  f0089c: 67 06                    beq.b    $f008a4
  f0089e: 61 00 0d e8              bsr.w    $f01688
  f008a2: ee 14                    roxr.b   #$7, d4

loc_F008A4:
  f008a4: 4e 73                    rte      

loc_F008A6:
  f008a6: 2a 5f                    movea.l  (a7)+, a5
  f008a8: 61 00 fe 28              bsr.w    $f006d2
  f008ac: 20 5f                    movea.l  (a7)+, a0
  f008ae: 4e 60                    move     a0, usp
  f008b0: 4c df 7f ff              movem.l  (a7)+, d0-d7/a0-a6
  f008b4: 5c 8f                    addq.l   #$6, a7
  f008b6: 48 e7 80 80              movem.l  d0/a0, -(a7)

loc_F008BA:
  f008ba: 20 38 0e 48              move.l   $e48.w, d0
  f008be: 67 14                    beq.b    $f008d4
  f008c0: 20 40                    movea.l  d0, a0
  f008c2: 00 50 00 20              ori.w    #$20, (a0)
  f008c6: 20 78 0c 4e              movea.l  $c4e.w, a0
  f008ca: 30 28 00 18              move.w   $18(a0), d0
  f008ce: 08 00 00 01              btst.b   #$1, d0
  f008d2: 67 e6                    beq.b    $f008ba

loc_F008D4:
  f008d4: 4c df 01 01              movem.l  (a7)+, d0/a0
  f008d8: 3f 17                    move.w   (a7), -(a7)
  f008da: 02 17 00 7f              andi.b   #$7f, (a7)
  f008de: 54 8f                    addq.l   #$2, a7
  f008e0: 66 c2                    bne.b    $f008a4
  f008e2: 4a 38 0c 5b              tst.b    $c5b.w
  f008e6: 67 bc                    beq.b    $f008a4
  f008e8: 02 7c f8 ff              andi.w   #$f8ff, sr
  f008ec: 61 00 fd c2              bsr.w    $f006b0
  f008f0: 41 d6                    lea.l    (a6), a0
  f008f2: 61 00 ff 1e              bsr.w    $f00812
  f008f6: 60 00 fd 94              bra.w    $f0068c
  f008fa: 40 e7                    move.w   sr, -(a7)
  f008fc: 08 38 00 09 0c 34        btst.b   #$9, $c34.w
  f00902: 67 06                    beq.b    $f0090a
  f00904: 61 00 0d 82              bsr.w    $f01688
  f00908: ee 09                    lsr.b    #$7, d1

loc_F0090A:
  f0090a: 48 e7 ff fe              movem.l  d0-d7/a0-a6, -(a7)
  f0090e: 4e 69                    move     usp, a1
  f00910: 2f 09                    move.l   a1, -(a7)
  f00912: 2f 38 0c 62              move.l   $c62.w, -(a7)
  f00916: 20 6f 00 46              movea.l  $46(a7), a0
  f0091a: 2c 68 00 02              movea.l  $2(a0), a6
  f0091e: 48 56                    pea.l    (a6)
  f00920: 2f 28 00 06              move.l   $6(a0), -(a7)
  f00924: 40 c0                    move.w   sr, d0
  f00926: 02 40 0f ff              andi.w   #$fff, d0
  f0092a: 3f 00                    move.w   d0, -(a7)
  f0092c: 22 68 00 0a              movea.l  $a(a0), a1
  f00930: 30 50                    movea.w  (a0), a0
  f00932: 2a 6e 00 36              movea.l  $36(a6), a5
  f00936: 60 00 fd 9c              bra.w    $f006d4

loc_F0093A:
  f0093a: 08 17 00 0d              btst.b   #$d, (a7)
  f0093e: 66 00 ff 64              bne.w    $f008a4
  f00942: 5c 8f                    addq.l   #$6, a7
  f00944: 2c 5f                    movea.l  (a7)+, a6
  f00946: 28 16                    move.l   (a6), d4
  f00948: 0c 84 21 54 43 42        cmpi.l   #$21544342, d4
  f0094e: 67 04                    beq.b    $f00954
  f00950: 61 00 f8 34              bsr.w    $f00186

loc_F00954:
  f00954: 4a 40                    tst.w    d0
  f00956: 67 00 ff 4e              beq.w    $f008a6
  f0095a: 0c 40 00 01              cmpi.w   #$1, d0
  f0095e: 66 0a                    bne.b    $f0096a
  f00960: 41 d6                    lea.l    (a6), a0
  f00962: 61 00 23 08              bsr.w    $f02c6c
  f00966: 60 00 ff 3e              bra.w    $f008a6

loc_F0096A:
  f0096a: 0c 40 00 02              cmpi.w   #$2, d0
  f0096e: 66 00 ff 36              bne.w    $f008a6
  f00972: 4a 81                    tst.l    d1
  f00974: 66 16                    bne.b    $f0098c
  f00976: 26 02                    move.l   d2, d3
  f00978: 48 43                    swap     d3
  f0097a: 34 3c 06 02              move.w   #$602, d2
  f0097e: 48 42                    swap     d2

loc_F00980:
  f00980: 41 d6                    lea.l    (a6), a0
  f00982: 61 00 0c 7c              bsr.w    $f01600
  f00986: 4e 71                    nop      
  f00988: 60 00 ff 1c              bra.w    $f008a6

loc_F0098C:
  f0098c: 48 42                    swap     d2
  f0098e: 48 41                    swap     d1
  f00990: 28 02                    move.l   d2, d4
  f00992: 26 01                    move.l   d1, d3
  f00994: 36 02                    move.w   d2, d3
  f00996: 34 3c 0a 82              move.w   #$a82, d2
  f0099a: 48 42                    swap     d2
  f0099c: 34 01                    move.w   d1, d2
  f0099e: 60 e0                    bra.b    $f00980

loc_F009A0:
  f009a0: e2 88                    lsr.l    #$1, d0
  f009a2: 26 00                    move.l   d0, d3
  f009a4: 54 8f                    addq.l   #$2, a7
  f009a6: 28 1f                    move.l   (a7)+, d4
  f009a8: 2c 5f                    movea.l  (a7)+, a6
  f009aa: 22 16                    move.l   (a6), d1
  f009ac: 0c 81 21 54 43 42        cmpi.l   #$21544342, d1
  f009b2: 67 04                    beq.b    $f009b8
  f009b4: 61 00 f7 d0              bsr.w    $f00186

loc_F009B8:
  f009b8: 00 43 f0 00              ori.w    #$f000, d3
  f009bc: 3d 43 00 5e              move.w   d3, $5e(a6)
  f009c0: 41 d6                    lea.l    (a6), a0
  f009c2: 61 00 22 a8              bsr.w    $f02c6c
  f009c6: 4a ae 00 40              tst.l    $40(a6)
  f009ca: 67 00 fe da              beq.w    $f008a6
  f009ce: 24 3c 0a 02 ff ff        move.l   #$a02ffff, d2
  f009d4: 48 43                    swap     d3
  f009d6: 48 44                    swap     d4
  f009d8: 36 04                    move.w   d4, d3
  f009da: 60 a4                    bra.b    $f00980
  f009dc: 2f 08                    move.l   a0, -(a7)
  f009de: 20 78 0e 48              movea.l  $e48.w, a0
  f009e2: 02 50 ff df              andi.w   #$ffdf, (a0)
  f009e6: 20 5f                    movea.l  (a7)+, a0
  f009e8: 4e 73                    rte      
  f009ea: 52 78 0c 5c              addq.w   #$1, $c5c.w
  f009ee: 0c 78 00 64 0c 5c        cmpi.w   #$64, $c5c.w
  f009f4: 6b 24                    bmi.b    $f00a1a
  f009f6: 2f 09                    move.l   a1, -(a7)
  f009f8: 22 78 0c 3a              movea.l  $c3a.w, a1
  f009fc: 33 7c 00 15 00 04        move.w   #$15, $4(a1)
  f00a02: 33 7c 00 35 00 04        move.w   #$35, $4(a1)
  f00a08: 33 7c 00 2e 00 04        move.w   #$2e, $4(a1)
  f00a0e: 33 7c 00 3e 00 04        move.w   #$3e, $4(a1)
  f00a14: 22 5f                    movea.l  (a7)+, a1
  f00a16: 42 78 0c 5c              clr.w    $c5c.w

loc_F00A1A:
  f00a1a: 4e 73                    rte      
  f00a1c: 4a b8                    DC.W     $4ab8
  f00a1e: 0c 78                    DC.W     $0c78
  f00a20: 66 10                    DC.W     $6610
  f00a22: 00 7c                    DC.W     $007c
  f00a24: 70 00                    DC.W     $7000
  f00a26: 48 e7                    DC.W     $48e7
  f00a28: ff fe                    DC.W     $fffe
  f00a2a: 21 cf                    DC.W     $21cf
  f00a2c: 0c 78                    DC.W     $0c78
  f00a2e: 46 ef                    DC.W     $46ef
  f00a30: 00 3c                    DC.W     $003c
  f00a32: 2e 78                    DC.W     $2e78
  f00a34: 0c 78                    DC.W     $0c78
  f00a36: 00 7c                    DC.W     $007c
  f00a38: 07 00                    DC.W     $0700
  f00a3a: 10 39                    DC.W     $1039
  f00a3c: 00 f7                    DC.W     $00f7
  f00a3e: 00 30 00 00 00 20        ori.b    #$0, $20(a0, d0.w)
  f00a44: 13 c0 00 f7 00 30        move.b   d0, $f70030.l
  f00a4a: 2e 78 0c 78              movea.l  $c78.w, a7
  f00a4e: 4c df ff ff              movem.l  (a7)+, d0-d7/a0-a7
  f00a52: 42 b8 0c 78              clr.l    $c78.w
  f00a56: 4e 73                    rte      
  f00a58: 48 f8 ff ff 08 08        movem.l  d0-d7/a0-a7, $808.w
  f00a5e: 31 d7 08 06              move.w   (a7), $806.w
  f00a62: 21 ef 00 02 08 00        move.l   $2(a7), $800.w
  f00a68: 00 7c 07 00              ori.w    #$700, sr
  f00a6c: 4c f8 ff ff 08 08        movem.l  $808.w, d0-d7/a0-a7
  f00a72: 4e 73                    rte      
  f00a74: 61 20                    bsr.b    $f00a96

loc_F00A76:
  f00a76: 61 1e                    bsr.b    $f00a96

VEC_22_F00A78:
  f00a78: 61 1c                    bsr.b    $f00a96

VEC_23_F00A7A:
  f00a7a: 61 1a                    bsr.b    $f00a96

VEC_24_F00A7C:
  f00a7c: 61 18                    bsr.b    $f00a96

VEC_25_F00A7E:
  f00a7e: 61 16                    bsr.b    $f00a96

VEC_26_F00A80:
  f00a80: 61 14                    bsr.b    $f00a96

VEC_27_F00A82:
  f00a82: 61 12                    bsr.b    $f00a96

VEC_28_F00A84:
  f00a84: 61 10                    bsr.b    $f00a96

VEC_29_F00A86:
  f00a86: 61 0e                    bsr.b    $f00a96

VEC_2A_F00A88:
  f00a88: 61 0c                    bsr.b    $f00a96

VEC_2B_F00A8A:
  f00a8a: 61 0a                    bsr.b    $f00a96

VEC_2C_F00A8C:
  f00a8c: 61 08                    bsr.b    $f00a96

VEC_2D_F00A8E:
  f00a8e: 61 06                    bsr.b    $f00a96

VEC_2E_F00A90:
  f00a90: 61 04                    bsr.b    $f00a96

VEC_2F_F00A92:
  f00a92: 61 02                    bsr.b    $f00a96
  f00a94: 4e 71                    nop      

loc_F00A96:
  f00a96: 3f 2f 00 04              move.w   $4(a7), -(a7)
  f00a9a: 02 17 00 7f              andi.b   #$7f, (a7)
  f00a9e: 54 8f                    addq.l   #$2, a7
  f00aa0: 67 0e                    beq.b    $f00ab0
  f00aa2: 08 2f 00 0d 00 04        btst.b   #$d, $4(a7)
  f00aa8: 67 00 01 bc              beq.w    $f00c66
  f00aac: 61 00 f6 d8              bsr.w    $f00186

loc_F00AB0:
  f00ab0: 61 00 fb fe              bsr.w    $f006b0
  f00ab4: 08 38 00 0c 0c 34        btst.b   #$c, $c34.w

loc_F00ABA:
  f00aba: 67 0a                    beq.b    $f00ac6
  f00abc: 40 e7                    move.w   sr, -(a7)
  f00abe: 61 00 0b c8              bsr.w    $f01688
  f00ac2: aa 12                    dc.w     $aa12
  f00ac4: 54 8f                    addq.l   #$2, a7

loc_F00AC6:
  f00ac6: 4b fa 00 06              lea.l    $f00ace(pc), a5
  f00aca: 60 00 00 a8              bra.w    $f00b74
  f00ace: 00 f0                    DC.W     $00f0
  f00ad0: 0a 76                    DC.W     $0a76
  f00ad2: 00 03                    DC.W     $0003
  f00ad4: 00 4c                    DC.W     $004c
  f00ad6: 00 02                    DC.W     $0002
  f00ad8: 61 50                    bsr.b    $f00b2a
  f00ada: 61 58                    bsr.b    $f00b34
  f00adc: 61 32                    bsr.b    $f00b10
  f00ade: 61 30                    bsr.b    $f00b10
  f00ae0: 61 2e                    bsr.b    $f00b10
  f00ae2: 61 2c                    bsr.b    $f00b10
  f00ae4: 61 2a                    bsr.b    $f00b10

VEC_0A_F00AE6:
  f00ae6: 61 28                    bsr.b    $f00b10

VEC_0B_F00AE8:
  f00ae8: 61 26                    bsr.b    $f00b10
  f00aea: 4e 71                    nop      
  f00aec: 4e 71                    nop      

VEC_09_F00AEE:
  f00aee: 61 02                    bsr.b    $f00af2
  f00af0: 4e 71                    nop      

loc_F00AF2:
  f00af2: 3f 2f 00 04              move.w   $4(a7), -(a7)
  f00af6: 02 17 00 7f              andi.b   #$7f, (a7)
  f00afa: 54 8f                    addq.l   #$2, a7
  f00afc: 67 50                    beq.b    $f00b4e
  f00afe: 08 2f 00 0d 00 04        btst.b   #$d, $4(a7)
  f00b04: 66 00 02 0e              bne.w    $f00d14
  f00b08: 58 8f                    addq.l   #$4, a7
  f00b0a: 08 97 00 0f              bclr.b   #$f, (a7)
  f00b0e: 4e 73                    rte      

loc_F00B10:
  f00b10: 3f 2f 00 04              move.w   $4(a7), -(a7)
  f00b14: 02 17 00 7f              andi.b   #$7f, (a7)
  f00b18: 54 8f                    addq.l   #$2, a7
  f00b1a: 67 32                    beq.b    $f00b4e
  f00b1c: 08 2f 00 0d 00 04        btst.b   #$d, $4(a7)
  f00b22: 67 00 01 54              beq.w    $f00c78
  f00b26: 61 00 f6 5e              bsr.w    $f00186

loc_F00B2A:
  f00b2a: 08 2f 00 0d 00 0c        btst.b   #$d, $c(a7)
  f00b30: 66 00 01 ce              bne.w    $f00d00

loc_F00B34:
  f00b34: 3f 2f 00 0c              move.w   $c(a7), -(a7)
  f00b38: 02 17 00 7f              andi.b   #$7f, (a7)
  f00b3c: 54 8f                    addq.l   #$2, a7
  f00b3e: 67 0e                    beq.b    $f00b4e
  f00b40: 08 2f 00 0d 00 0c        btst.b   #$d, $c(a7)
  f00b46: 67 00 01 2a              beq.w    $f00c72
  f00b4a: 61 00 f6 3a              bsr.w    $f00186

loc_F00B4E:
  f00b4e: 61 00 fb 60              bsr.w    $f006b0
  f00b52: 08 38 00 0b 0c 34        btst.b   #$b, $c34.w
  f00b58: 67 0a                    beq.b    $f00b64
  f00b5a: 40 e7                    move.w   sr, -(a7)
  f00b5c: 61 00 0b 2a              bsr.w    $f01688
  f00b60: aa 11                    dc.w     $aa11
  f00b62: 54 8f                    addq.l   #$2, a7

loc_F00B64:
  f00b64: 4b fa 00 04              lea.l    $f00b6a(pc), a5
  f00b68: 60 0a                    bra.b    $f00b74
  f00b6a: 00 f0                    DC.W     $00f0
  f00b6c: 0a ba                    DC.W     $0aba
  f00b6e: 00 04                    DC.W     $0004
  f00b70: 00 48                    DC.W     $0048
  f00b72: 00 10                    DC.W     $0010

loc_F00B74:
  f00b74: 2e 1f                    move.l   (a7)+, d7
  f00b76: 9e 95                    sub.l    (a5), d7
  f00b78: e2 8f                    lsr.l    #$1, d7
  f00b7a: 0c 07 00 18              cmpi.b   #$18, d7
  f00b7e: 6e 00 01 04              bgt.w    $f00c84
  f00b82: 32 2d 00 04              move.w   $4(a5), d1
  f00b86: 34 2e 00 28              move.w   $28(a6), d2
  f00b8a: 03 02                    btst.l   d1, d2
  f00b8c: 67 5e                    beq.b    $f00bec
  f00b8e: 32 2d 00 06              move.w   $6(a5), d1
  f00b92: 2c 36 10 00              move.l   (a6, d1.w), d6
  f00b96: 22 07                    move.l   d7, d1
  f00b98: 92 6d 00 08              sub.w    $8(a5), d1
  f00b9c: e5 89                    lsl.l    #$2, d1
  f00b9e: dc 81                    add.l    d1, d6
  f00ba0: 7a 04                    moveq    #$4, d5
  f00ba2: 20 6e 00 36              movea.l  $36(a6), a0
  f00ba6: 61 00 0b b4              bsr.w    $f0175c
  f00baa: 60 04                    bra.b    $f00bb0
  f00bac: 4e 71                    nop      
  f00bae: 60 3c                    bra.b    $f00bec

loc_F00BB0:
  f00bb0: 22 46                    movea.l  d6, a1
  f00bb2: 4a 91                    tst.l    (a1)
  f00bb4: 67 36                    beq.b    $f00bec
  f00bb6: 2a 38 0c 08              move.l   $c08.w, d5
  f00bba: 9a 8f                    sub.l    a7, d5
  f00bbc: 2c 2e 01 3c              move.l   $13c(a6), d6
  f00bc0: 9c 85                    sub.l    d5, d6
  f00bc2: 26 06                    move.l   d6, d3
  f00bc4: 20 6e 00 36              movea.l  $36(a6), a0
  f00bc8: 61 00 0b 92              bsr.w    $f0175c
  f00bcc: 60 04                    bra.b    $f00bd2
  f00bce: 4e 71                    nop      
  f00bd0: 60 1a                    bra.b    $f00bec

loc_F00BD2:
  f00bd2: 28 46                    movea.l  d6, a4

loc_F00BD4:
  f00bd4: 38 df                    move.w   (a7)+, (a4)+
  f00bd6: bf f8 0c 08              cmpa.l   $c08.w, a7
  f00bda: 66 f8                    bne.b    $f00bd4
  f00bdc: 2f 11                    move.l   (a1), -(a7)
  f00bde: 3f 2c ff fa              move.w   -$6(a4), -(a7)
  f00be2: 3c 3c 00 01              move.w   #$1, d6
  f00be6: 2d 43 01 3c              move.l   d3, $13c(a6)
  f00bea: 60 16                    bra.b    $f00c02

loc_F00BEC:
  f00bec: 42 86                    clr.l    d6
  f00bee: 0c 07 00 10              cmpi.b   #$10, d7
  f00bf2: 6d 0e                    blt.b    $f00c02
  f00bf4: 0c 07 00 11              cmpi.b   #$11, d7
  f00bf8: 6e 08                    bgt.b    $f00c02
  f00bfa: 2d 5f 00 b8              move.l   (a7)+, $b8(a6)
  f00bfe: 2d 5f 00 bc              move.l   (a7)+, $bc(a6)

loc_F00C02:
  f00c02: 08 2e 00 06 00 29        btst.b   #$6, $29(a6)
  f00c08: 67 14                    beq.b    $f00c1e
  f00c0a: 22 2e 01 48              move.l   $148(a6), d1
  f00c0e: 0f 01                    btst.l   d7, d1
  f00c10: 67 0c                    beq.b    $f00c1e
  f00c12: 61 00 01 44              bsr.w    $f00d58
  f00c16: 0c 07 00 0f              cmpi.b   #$f, d7
  f00c1a: 6e 00 fa 6a              bgt.w    $f00686

loc_F00C1E:
  f00c1e: 4a 06                    tst.b    d6
  f00c20: 66 00 fa 64              bne.w    $f00686
  f00c24: 0c 07 00 0f              cmpi.b   #$f, d7
  f00c28: 6e 30                    bgt.b    $f00c5a
  f00c2a: 43 f8 0c 9a              lea.l    $c9a.w, a1
  f00c2e: 0c 31 00 02 70 00        cmpi.b   #$2, (a1, d7.w)
  f00c34: 66 0c                    bne.b    $f00c42
  f00c36: 48 7a fa 54              pea.l    $f0068c(pc)
  f00c3a: 3f 3c 20 00              move.w   #$2000, -(a7)
  f00c3e: 60 00 01 82              bra.w    $f00dc2

loc_F00C42:
  f00c42: 3d 40 01 00              move.w   d0, $100(a6)
  f00c46: 3d 7c 00 01 01 02        move.w   #$1, $102(a6)
  f00c4c: e7 8f                    lsl.l    #$3, d7
  f00c4e: 1d 47 01 00              move.b   d7, $100(a6)
  f00c52: 42 2e 00 fb              clr.b    $fb(a6)
  f00c56: 60 00 fa 2e              bra.w    $f00686

loc_F00C5A:
  f00c5a: 4a 46                    tst.w    d6
  f00c5c: 66 00 fa 28              bne.w    $f00686
  f00c60: 41 d6                    lea.l    (a6), a0
  f00c62: 61 00 fb c0              bsr.w    $f00824

loc_F00C66:
  f00c66: 20 1f                    move.l   (a7)+, d0
  f00c68: 04 80 00 f0 0a 76        subi.l   #$f00a76, d0
  f00c6e: 60 00 fd 30              bra.w    $f009a0

loc_F00C72:
  f00c72: 20 1f                    move.l   (a7)+, d0
  f00c74: 50 8f                    addq.l   #$8, a7
  f00c76: 60 02                    bra.b    $f00c7a

loc_F00C78:
  f00c78: 20 1f                    move.l   (a7)+, d0

loc_F00C7A:
  f00c7a: 04 80 00 f0 0a ba        subi.l   #$f00aba, d0
  f00c80: 60 00 fd 1e              bra.w    $f009a0

loc_F00C84:
  f00c84: 7e 1c                    moveq    #$1c, d7
  f00c86: 24 2e 01 48              move.l   $148(a6), d2
  f00c8a: 08 02 00 1d              btst.b   #$1d, d2
  f00c8e: 66 16                    bne.b    $f00ca6
  f00c90: 08 02 00 1c              btst.b   #$1c, d2
  f00c94: 66 64                    bne.b    $f00cfa
  f00c96: 08 02 00 1b              btst.b   #$1b, d2
  f00c9a: 66 4c                    bne.b    $f00ce8
  f00c9c: 4c ee 7f ff 01 00        movem.l  $100(a6), d0-d7/a0-a6
  f00ca2: 60 00 00 ae              bra.w    $f00d52

loc_F00CA6:
  f00ca6: 7a 04                    moveq    #$4, d5
  f00ca8: 2c 2e 01 50              move.l   $150(a6), d6
  f00cac: 20 6e 00 36              movea.l  $36(a6), a0
  f00cb0: 61 00 0a aa              bsr.w    $f0175c
  f00cb4: 60 04                    bra.b    $f00cba
  f00cb6: 4e 71                    nop      
  f00cb8: 60 26                    bra.b    $f00ce0

loc_F00CBA:
  f00cba: 7e 1d                    moveq    #$1d, d7
  f00cbc: 20 46                    movea.l  d6, a0
  f00cbe: 26 10                    move.l   (a0), d3
  f00cc0: 28 2e 01 54              move.l   $154(a6), d4
  f00cc4: b7 84                    eor.l    d3, d4
  f00cc6: 08 02 00 1c              btst.b   #$1c, d2
  f00cca: 66 0c                    bne.b    $f00cd8
  f00ccc: c8 ae 01 4c              and.l    $14c(a6), d4
  f00cd0: 67 0e                    beq.b    $f00ce0
  f00cd2: 2d 43 01 54              move.l   d3, $154(a6)
  f00cd6: 60 22                    bra.b    $f00cfa

loc_F00CD8:
  f00cd8: 52 87                    addq.l   #$1, d7
  f00cda: c8 ae 01 4c              and.l    $14c(a6), d4
  f00cde: 67 1a                    beq.b    $f00cfa

loc_F00CE0:
  f00ce0: 08 02 00 1b              btst.b   #$1b, d2
  f00ce4: 67 00 f9 a0              beq.w    $f00686

loc_F00CE8:
  f00ce8: 52 6e 01 58              addq.w   #$1, $158(a6)
  f00cec: 20 2e 01 58              move.l   $158(a6), d0
  f00cf0: b0 6e 01 58              cmp.w    $158(a6), d0
  f00cf4: 62 00 f9 90              bhi.w    $f00686
  f00cf8: 7e 1b                    moveq    #$1b, d7

loc_F00CFA:
  f00cfa: 48 7a f9 8a              pea.l    $f00686(pc)
  f00cfe: 60 58                    bra.b    $f00d58

loc_F00D00:
  f00d00: 0c 6f 42 45 00 12        cmpi.w   #$4245, $12(a7)
  f00d06: 67 04                    beq.b    $f00d0c
  f00d08: 61 00 f4 7c              bsr.w    $f00186

loc_F00D0C:
  f00d0c: df fc 00 00 00 14        adda.l   #$14, a7
  f00d12: 4e 75                    rts      

loc_F00D14:
  f00d14: 2e 81                    move.l   d1, (a7)
  f00d16: 2f 0e                    move.l   a6, -(a7)
  f00d18: 2c 78 0c 0c              movea.l  $c0c.w, a6
  f00d1c: bd fc 00 00 00 00        cmpa.l   #$0, a6
  f00d22: 67 2a                    beq.b    $f00d4e
  f00d24: 08 2f 00 0d 00 0e        btst.b   #$d, $e(a7)
  f00d2a: 66 22                    bne.b    $f00d4e
  f00d2c: 08 2e 00 06 00 29        btst.b   #$6, $29(a6)
  f00d32: 67 1a                    beq.b    $f00d4e
  f00d34: 12 2e 01 48              move.b   $148(a6), d1
  f00d38: 02 01 00 38              andi.b   #$38, d1
  f00d3c: 67 10                    beq.b    $f00d4e
  f00d3e: 08 ee 00 0f 01 48        bset.b   #$f, $148(a6)
  f00d44: 2c 5f                    movea.l  (a7)+, a6
  f00d46: 22 1f                    move.l   (a7)+, d1
  f00d48: 08 97 00 0f              bclr.b   #$f, (a7)
  f00d4c: 4e 73                    rte      

loc_F00D4E:
  f00d4e: 2c 5f                    movea.l  (a7)+, a6
  f00d50: 22 1f                    move.l   (a7)+, d1

loc_F00D52:
  f00d52: 2f 38 0c 36              move.l   $c36.w, -(a7)
  f00d56: 4e 75                    rts      

loc_F00D58:
  f00d58: 40 e7                    move.w   sr, -(a7)
  f00d5a: 61 00 f9 e0              bsr.w    $f0073c
  f00d5e: 24 3c 0c 08 00 00        move.l   #$c080000, d2
  f00d64: 34 2e 00 10              move.w   $10(a6), d2
  f00d68: 26 2e 00 12              move.l   $12(a6), d3
  f00d6c: 28 2e 00 16              move.l   $16(a6), d4
  f00d70: 38 07                    move.w   d7, d4
  f00d72: e1 4c                    lsl.w    #$8, d4
  f00d74: 18 3c 00 03              move.b   #$3, d4
  f00d78: 41 ee 01 40              lea.l    $140(a6), a0
  f00d7c: 61 00 08 3e              bsr.w    $f015bc
  f00d80: 60 18                    bra.b    $f00d9a
  f00d82: 08 ae 00 06 00 29        bclr.b   #$6, $29(a6)
  f00d88: 4c ee 7f ff 00 74        movem.l  $74(a6), d0-d7/a0-a6
  f00d8e: 08 ae 00 06 00 2d        bclr.b   #$6, $2d(a6)
  f00d94: 1d 40 00 26              move.b   d0, $26(a6)
  f00d98: 4e 73                    rte      

loc_F00D9A:
  f00d9a: 08 ee 00 0a 00 2c        bset.b   #$a, $2c(a6)
  f00da0: 60 00 f7 6a              bra.w    $f0050c

TRAP0_dir_13_bsr:
  f00da4: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_13:
  f00da6: 45 f8 0c aa              lea.l    $caa.w, a2
  f00daa: 08 c7 00 06              bset.b   #$6, d7
  f00dae: 08 ec 00 06 00 73        bset.b   #$6, $73(a4)
  f00db4: 08 2c 00 02 00 29        btst.b   #$2, $29(a4)
  f00dba: 67 16                    beq.b    $f00dd2
  f00dbc: 08 c7 00 05              bset.b   #$5, d7
  f00dc0: 60 10                    bra.b    $f00dd2

loc_F00DC2:
  f00dc2: 22 07                    move.l   d7, d1
  f00dc4: c2 fc 00 16              mulu.w   #$16, d1
  f00dc8: 45 f8 0c aa              lea.l    $caa.w, a2
  f00dcc: 28 4e                    movea.l  a6, a4
  f00dce: 19 47 00 73              move.b   d7, $73(a4)

loc_F00DD2:
  f00dd2: 2a 72 10 00              movea.l  (a2, d1.w), a5
  f00dd6: bb ce                    cmpa.l   a6, a5
  f00dd8: 67 00 00 b0              beq.w    $f00e8a
  f00ddc: 24 3c 1c 87 00 00        move.l   #$1c870000, d2
  f00de2: 34 32 10 0e              move.w   $e(a2, d1.w), d2
  f00de6: 26 32 10 10              move.l   $10(a2, d1.w), d3
  f00dea: 36 07                    move.w   d7, d3
  f00dec: 08 2c 00 0f 00 28        btst.b   #$f, $28(a4)
  f00df2: 67 04                    beq.b    $f00df8
  f00df4: 08 c3 00 07              bset.b   #$7, d3

loc_F00DF8:
  f00df8: e1 4b                    lsl.w    #$8, d3
  f00dfa: 16 2c 00 24              move.b   $24(a4), d3
  f00dfe: 28 0c                    move.l   a4, d4
  f00e00: 2a 2c 00 14              move.l   $14(a4), d5
  f00e04: 2c 2c 00 70              move.l   $70(a4), d6
  f00e08: 3c 2c 01 00              move.w   $100(a4), d6
  f00e0c: 2e 2c 01 02              move.l   $102(a4), d7
  f00e10: 3e 2c 01 20              move.w   $120(a4), d7
  f00e14: 20 2c 01 22              move.l   $122(a4), d0
  f00e18: 30 3c 03 00              move.w   #$300, d0
  f00e1c: 08 32 00 0d 10 14        btst.b   #$d, $14(a2, d1.w)
  f00e22: 67 06                    beq.b    $f00e2a
  f00e24: 42 40                    clr.w    d0
  f00e26: 10 32 10 15              move.b   $15(a2, d1.w), d0

loc_F00E2A:
  f00e2a: 08 03 00 0e              btst.b   #$e, d3
  f00e2e: 67 14                    beq.b    $f00e44
  f00e30: 3c 2c 00 2a              move.w   $2a(a4), d6
  f00e34: 2e 2c 00 28              move.l   $28(a4), d7
  f00e38: 3e 2c 00 b0              move.w   $b0(a4), d7
  f00e3c: 48 40                    swap     d0
  f00e3e: 30 2c 00 b2              move.w   $b2(a4), d0
  f00e42: 48 40                    swap     d0

loc_F00E44:
  f00e44: 22 40                    movea.l  d0, a1
  f00e46: 4a b2 10 0e              tst.l    $e(a2, d1.w)
  f00e4a: 66 14                    bne.b    $f00e60
  f00e4c: 20 2d 00 40              move.l   $40(a5), d0
  f00e50: 67 34                    beq.b    $f00e86
  f00e52: 26 40                    movea.l  d0, a3
  f00e54: 34 2b 00 06              move.w   $6(a3), d2
  f00e58: 48 43                    swap     d3
  f00e5a: 36 2b 00 08              move.w   $8(a3), d3
  f00e5e: 48 43                    swap     d3

loc_F00E60:
  f00e60: 41 f2 10 08              lea.l    $8(a2, d1.w), a0
  f00e64: 61 00 f8 82              bsr.w    $f006e8
  f00e68: 4a b2 10 00              tst.l    (a2, d1.w)
  f00e6c: 67 18                    beq.b    $f00e86
  f00e6e: 48 e7 40 28              movem.l  d1/a2/a4, -(a7)
  f00e72: 41 d5                    lea.l    (a5), a0
  f00e74: 61 00 07 62              bsr.w    $f015d8
  f00e78: 60 32                    bra.b    $f00eac
  f00e7a: 4c df 14 02              movem.l  (a7)+, d1/a2/a4
  f00e7e: 20 72 10 08              movea.l  $8(a2, d1.w), a0
  f00e82: 61 00 f9 04              bsr.w    $f00788

loc_F00E86:
  f00e86: 1e 2c 00 73              move.b   $73(a4), d7

loc_F00E8A:
  f00e8a: 08 07 00 06              btst.b   #$6, d7
  f00e8e: 66 1a                    bne.b    $f00eaa
  f00e90: 2d 7c 00 00 00 01 01 00  move.l   #$1, $100(a6)
  f00e98: e7 4f                    lsl.w    #$3, d7
  f00e9a: 1d 47 01 00              move.b   d7, $100(a6)
  f00e9e: 42 2e 00 fb              clr.b    $fb(a6)
  f00ea2: 41 fa f7 e2              lea.l    $f00686(pc), a0
  f00ea6: 2f 48 00 02              move.l   a0, $2(a7)

loc_F00EAA:
  f00eaa: 4e 73                    rte      

loc_F00EAC:
  f00eac: 4c df 14 02              movem.l  (a7)+, d1/a2/a4
  f00eb0: 02 2c 00 0f 00 73        andi.b   #$f, $73(a4)
  f00eb6: 08 f2 00 0c 10 14        bset.b   #$c, $14(a2, d1.w)
  f00ebc: 52 72 10 12              addq.w   #$1, $12(a2, d1.w)
  f00ec0: 08 ec 00 0b 00 2c        bset.b   #$b, $2c(a4)
  f00ec6: 4e 73                    rte      

VEC_1C_F00EC8:
  f00ec8: 48 e7 c0 c0              movem.l  d0-d1/a0-a1, -(a7)
  f00ecc: 20 78 0c 3a              movea.l  $c3a.w, a0
  f00ed0: 11 7c 00 00 00 02        move.b   #$0, $2(a0)
  f00ed6: 20 78 0c 4e              movea.l  $c4e.w, a0
  f00eda: 08 f8 00 07 0c 5a        bset.b   #$7, $c5a.w
  f00ee0: 32 3c 01 00              move.w   #$100, d1
  f00ee4: 10 28 00 03              move.b   $3(a0), d0
  f00ee8: 10 28 00 0d              move.b   $d(a0), d0
  f00eec: 42 81                    clr.l    d1
  f00eee: 32 38 0c 56              move.w   $c56.w, d1
  f00ef2: d3 b8 0c 42              add.l    d1, $c42.w
  f00ef6: 20 38 0c 42              move.l   $c42.w, d0
  f00efa: 04 80 05 26 5c 00        subi.l   #$5265c00, d0
  f00f00: 6b 3a                    bmi.b    $f00f3c
  f00f02: 52 b8 0c 3e              addq.l   #$1, $c3e.w
  f00f06: 21 c0 0c 42              move.l   d0, $c42.w
  f00f0a: 20 3c 05 26 5c 00        move.l   #$5265c00, d0
  f00f10: 22 78 0c 2c              movea.l  $c2c.w, a1
  f00f14: 40 e7                    move.w   sr, -(a7)
  f00f16: 00 7c 07 00              ori.w    #$700, sr
  f00f1a: 20 69 00 0c              movea.l  $c(a1), a0

loc_F00F1E:
  f00f1e: 22 08                    move.l   a0, d1
  f00f20: 67 08                    beq.b    $f00f2a
  f00f22: 91 a8 00 08              sub.l    d0, $8(a0)
  f00f26: 20 50                    movea.l  (a0), a0
  f00f28: 60 f4                    bra.b    $f00f1e

loc_F00F2A:
  f00f2a: 46 df                    move.w   (a7)+, sr
  f00f2c: 20 69 00 08              movea.l  $8(a1), a0

loc_F00F30:
  f00f30: 22 08                    move.l   a0, d1
  f00f32: 67 08                    beq.b    $f00f3c
  f00f34: 91 a8 00 08              sub.l    d0, $8(a0)
  f00f38: 20 50                    movea.l  (a0), a0
  f00f3a: 60 f4                    bra.b    $f00f30

loc_F00F3C:
  f00f3c: 22 78 0c 2c              movea.l  $c2c.w, a1
  f00f40: 4a a9 00 0c              tst.l    $c(a1)
  f00f44: 67 14                    beq.b    $f00f5a
  f00f46: 30 2f 00 10              move.w   $10(a7), d0
  f00f4a: 02 40 27 ff              andi.w   #$27ff, d0
  f00f4e: 00 40 20 00              ori.w    #$2000, d0
  f00f52: 22 38 0c 42              move.l   $c42.w, d1
  f00f56: 61 00 01 d0              bsr.w    $f01128

loc_F00F5A:
  f00f5a: 4c df 03 03              movem.l  (a7)+, d0-d1/a0-a1
  f00f5e: 08 38 00 0d 0c 34        btst.b   #$d, $c34.w
  f00f64: 67 06                    beq.b    $f00f6c
  f00f66: 61 00 07 20              bsr.w    $f01688
  f00f6a: ff 13                    dc.w     $ff13

loc_F00F6C:
  f00f6c: 53 78 0c 52              subq.w   #$1, $c52.w
  f00f70: 6e 10                    bgt.b    $f00f82
  f00f72: 08 f8 00 07 0c 5b        bset.b   #$7, $c5b.w
  f00f78: 3f 17                    move.w   (a7), -(a7)
  f00f7a: 02 17 00 7f              andi.b   #$7f, (a7)
  f00f7e: 54 8f                    addq.l   #$2, a7
  f00f80: 67 02                    beq.b    $f00f84

loc_F00F82:
  f00f82: 4e 73                    rte      

loc_F00F84:
  f00f84: 02 7c f8 ff              andi.w   #$f8ff, sr
  f00f88: 61 00 f7 26              bsr.w    $f006b0
  f00f8c: 41 d6                    lea.l    (a6), a0
  f00f8e: 61 00 f8 6c              bsr.w    $f007fc
  f00f92: 60 00 f6 f8              bra.w    $f0068c

TRAP0_T0RDTIM_bsr:
  f00f96: 40 e7                    move.w   sr, -(a7)

TRAP0_T0RDTIM:
  f00f98: 2f 08                    move.l   a0, -(a7)
  f00f9a: 20 78 0c 4e              movea.l  $c4e.w, a0

loc_F00F9E:
  f00f9e: 42 81                    clr.l    d1
  f00fa0: 42 38 0c 5a              clr.b    $c5a.w
  f00fa4: 03 08 00 0d              movep.w  $d(a0), d1
  f00fa8: 30 01                    move.w   d1, d0
  f00faa: e0 49                    lsr.w    #$8, d1
  f00fac: 44 41                    neg.w    d1
  f00fae: d2 78 0c 58              add.w    $c58.w, d1
  f00fb2: e4 49                    lsr.w    #$2, d1
  f00fb4: d2 b8 0c 42              add.l    $c42.w, d1
  f00fb8: 4a 38 0c 5a              tst.b    $c5a.w
  f00fbc: 66 e0                    bne.b    $f00f9e
  f00fbe: 20 5f                    movea.l  (a7)+, a0
  f00fc0: 4e 73                    rte      

loc_F00FC2:
  f00fc2: 72 01                    moveq    #$1, d1
  f00fc4: d2 78 0c 56              add.w    $c56.w, d1
  f00fc8: d2 b8 0c 42              add.l    $c42.w, d1
  f00fcc: 22 78 0c 2c              movea.l  $c2c.w, a1
  f00fd0: 47 e9 00 08              lea.l    $8(a1), a3

loc_F00FD4:
  f00fd4: 24 53                    movea.l  (a3), a2
  f00fd6: 20 0a                    move.l   a2, d0
  f00fd8: 67 0c                    beq.b    $f00fe6
  f00fda: 4a aa 00 04              tst.l    $4(a2)
  f00fde: 66 08                    bne.b    $f00fe8
  f00fe0: 26 92                    move.l   (a2), (a3)
  f00fe2: 60 00 00 8c              bra.w    $f01070

loc_F00FE6:
  f00fe6: 4e 75                    rts      

loc_F00FE8:
  f00fe8: b2 aa 00 08              cmp.l    $8(a2), d1
  f00fec: 6d f8                    blt.b    $f00fe6
  f00fee: 61 00 ff a6              bsr.w    $f00f96
  f00ff2: b2 aa 00 08              cmp.l    $8(a2), d1
  f00ff6: 6d ee                    blt.b    $f00fe6
  f00ff8: 26 92                    move.l   (a2), (a3)
  f00ffa: 2a 6a 00 04              movea.l  $4(a2), a5
  f00ffe: 08 2d 00 07 00 2d        btst.b   #$7, $2d(a5)
  f01004: 66 6a                    bne.b    $f01070
  f01006: 08 aa 00 00 00 15        bclr.b   #$0, $15(a2)
  f0100c: 24 2a 00 0c              move.l   $c(a2), d2
  f01010: d4 aa 00 08              add.l    $8(a2), d2
  f01014: 3e 2a 00 14              move.w   $14(a2), d7
  f01018: 67 3e                    beq.b    $f01058
  f0101a: 08 2a 00 0e 00 14        btst.b   #$e, $14(a2)
  f01020: 67 0c                    beq.b    $f0102e
  f01022: 52 6a 00 1a              addq.w   #$1, $1a(a2)
  f01026: 08 c7 00 00              bset.b   #$0, d7
  f0102a: 61 00 00 e0              bsr.w    $f0110c

loc_F0102E:
  f0102e: 08 2a 00 0d 00 14        btst.b   #$d, $14(a2)
  f01034: 66 42                    bne.b    $f01078
  f01036: 08 2a 00 0c 00 14        btst.b   #$c, $14(a2)
  f0103c: 67 10                    beq.b    $f0104e
  f0103e: 08 ad 00 0e 00 2c        bclr.b   #$e, $2c(a5)
  f01044: 66 1c                    bne.b    $f01062
  f01046: 08 ed 00 03 00 2d        bset.b   #$3, $2d(a5)
  f0104c: 60 1a                    bra.b    $f01068

loc_F0104E:
  f0104e: 08 ad 00 09 00 2c        bclr.b   #$9, $2c(a5)
  f01054: 67 12                    beq.b    $f01068
  f01056: 60 0a                    bra.b    $f01062

loc_F01058:
  f01058: 42 ad 00 58              clr.l    $58(a5)
  f0105c: 08 ad 00 0e 00 2c        bclr.b   #$e, $2c(a5)

loc_F01062:
  f01062: 41 d5                    lea.l    (a5), a0
  f01064: 61 00 f7 96              bsr.w    $f007fc

loc_F01068:
  f01068: 08 07 00 00              btst.b   #$0, d7
  f0106c: 66 00 ff 66              bne.w    $f00fd4

loc_F01070:
  f01070: 61 00 00 7e              bsr.w    $f010f0
  f01074: 60 00 ff 5e              bra.w    $f00fd4

loc_F01078:
  f01078: 48 e7 41 50              movem.l  d1/d7/a1/a3, -(a7)
  f0107c: 24 38 0c 3e              move.l   $c3e.w, d2
  f01080: 26 01                    move.l   d1, d3
  f01082: 36 38 0c 40              move.w   $c40.w, d3
  f01086: 48 43                    swap     d3
  f01088: 28 01                    move.l   d1, d4
  f0108a: 48 44                    swap     d4
  f0108c: 34 3c 0a 04              move.w   #$a04, d2
  f01090: 08 07 00 0a              btst.b   #$a, d7
  f01094: 67 0c                    beq.b    $f010a2
  f01096: 34 3c 10 04              move.w   #$1004, d2
  f0109a: 38 2a 00 16              move.w   $16(a2), d4
  f0109e: 2a 2a 00 18              move.l   $18(a2), d5

loc_F010A2:
  f010a2: 48 42                    swap     d2
  f010a4: 08 2a 00 0c 00 14        btst.b   #$c, $14(a2)
  f010aa: 67 32                    beq.b    $f010de
  f010ac: 48 e7 1c 00              movem.l  d3-d5, -(a7)
  f010b0: 7a 02                    moveq    #$2, d5
  f010b2: 2c 2a 00 10              move.l   $10(a2), d6
  f010b6: 20 6d 00 36              movea.l  $36(a5), a0
  f010ba: 61 00 06 a0              bsr.w    $f0175c
  f010be: 60 08                    bra.b    $f010c8
  f010c0: 4e 71                    nop      
  f010c2: 4c df 00 38              movem.l  (a7)+, d3-d5
  f010c6: 60 16                    bra.b    $f010de

loc_F010C8:
  f010c8: 4c df 00 70              movem.l  (a7)+, d4-d6
  f010cc: 26 2a 00 10              move.l   $10(a2), d3
  f010d0: 48 43                    swap     d3
  f010d2: 36 02                    move.w   d2, d3
  f010d4: 06 82 04 80 00 00        addi.l   #$4800000, d2
  f010da: 34 2a 00 10              move.w   $10(a2), d2

loc_F010DE:
  f010de: 41 d5                    lea.l    (a5), a0
  f010e0: 61 00 04 f6              bsr.w    $f015d8
  f010e4: 4e 71                    nop      
  f010e6: 4c df 0a 82              movem.l  (a7)+, d1/d7/a1/a3
  f010ea: 52 81                    addq.l   #$1, d1
  f010ec: 60 00 ff 7a              bra.w    $f01068

TRAP0_dir_21_bsr:
  f010f0: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_21:
  f010f2: 00 7c 07 00              ori.w    #$700, sr
  f010f6: 24 a9 00 04              move.l   $4(a1), (a2)
  f010fa: 25 7c ff ff ff ff 00 04  move.l   #$ffffffff, $4(a2)
  f01102: 23 4a 00 04              move.l   a2, $4(a1)
  f01106: 4e 73                    rte      

TRAP0_dir_1E:
  f01108: 4f ef 00 02              lea.l    $2(a7), a7

loc_F0110C:
  f0110c: 49 e9 00 08              lea.l    $8(a1), a4

loc_F01110:
  f01110: 20 4c                    movea.l  a4, a0
  f01112: 20 14                    move.l   (a4), d0
  f01114: 67 08                    beq.b    $f0111e
  f01116: 28 40                    movea.l  d0, a4
  f01118: b4 ac 00 08              cmp.l    $8(a4), d2
  f0111c: 6c f2                    bge.b    $f01110

loc_F0111E:
  f0111e: 25 42 00 08              move.l   d2, $8(a2)
  f01122: 24 80                    move.l   d0, (a2)
  f01124: 20 8a                    move.l   a2, (a0)
  f01126: 4e 75                    rts      

loc_F01128:
  f01128: 22 78 0c 2c              movea.l  $c2c.w, a1
  f0112c: 41 e9 00 0c              lea.l    $c(a1), a0
  f01130: 3f 00                    move.w   d0, -(a7)
  f01132: 46 fc 27 00              move.w   #$2700, sr

loc_F01136:
  f01136: 22 48                    movea.l  a0, a1
  f01138: 4a 91                    tst.l    (a1)
  f0113a: 66 02                    bne.b    $f0113e
  f0113c: 4e 73                    rte      

loc_F0113E:
  f0113e: 20 51                    movea.l  (a1), a0
  f01140: b2 a8 00 08              cmp.l    $8(a0), d1
  f01144: 6d f0                    blt.b    $f01136
  f01146: b0 68 00 1c              cmp.w    $1c(a0), d0
  f0114a: 6c ea                    bge.b    $f01136
  f0114c: 2f 28 00 10              move.l   $10(a0), -(a7)
  f01150: 3f 28 00 1c              move.w   $1c(a0), -(a7)
  f01154: 42 68 00 1a              clr.w    $1a(a0)
  f01158: 20 28 00 08              move.l   $8(a0), d0

loc_F0115C:
  f0115c: 52 68 00 1a              addq.w   #$1, $1a(a0)
  f01160: d0 a8 00 0c              add.l    $c(a0), d0
  f01164: b2 80                    cmp.l    d0, d1
  f01166: 6c f4                    bge.b    $f0115c
  f01168: 21 40 00 08              move.l   d0, $8(a0)
  f0116c: 42 80                    clr.l    d0
  f0116e: 30 28 00 1a              move.w   $1a(a0), d0
  f01172: 22 28 00 16              move.l   $16(a0), d1
  f01176: 08 28 00 0e 00 14        btst.b   #$e, $14(a0)
  f0117c: 66 16                    bne.b    $f01194
  f0117e: 22 90                    move.l   (a0), (a1)
  f01180: 22 78 0c 2c              movea.l  $c2c.w, a1
  f01184: 20 a9 00 04              move.l   $4(a1), (a0)
  f01188: 23 48 00 04              move.l   a0, $4(a1)
  f0118c: 21 7c ff ff ff ff 00 04  move.l   #$ffffffff, $4(a0)

loc_F01194:
  f01194: 4e 73                    rte      

TRAP0_T0RQPA_bsr:
  f01196: 40 e7                    move.w   sr, -(a7)

TRAP0_T0RQPA:
  f01198: 48 e7 10 70              movem.l  d3/a1-a3, -(a7)
  f0119c: 20 09                    move.l   a1, d0
  f0119e: 22 78 0c 2c              movea.l  $c2c.w, a1
  f011a2: 47 e9 00 0c              lea.l    $c(a1), a3
  f011a6: 46 fc 27 00              move.w   #$2700, sr

loc_F011AA:
  f011aa: 24 4b                    movea.l  a3, a2
  f011ac: 26 13                    move.l   (a3), d3
  f011ae: 67 24                    beq.b    $f011d4
  f011b0: 26 43                    movea.l  d3, a3
  f011b2: b4 ab 00 16              cmp.l    $16(a3), d2
  f011b6: 66 f2                    bne.b    $f011aa
  f011b8: 24 93                    move.l   (a3), (a2)
  f011ba: 4a 41                    tst.w    d1
  f011bc: 6a 2c                    bpl.b    $f011ea
  f011be: 26 a9 00 04              move.l   $4(a1), (a3)
  f011c2: 23 4b 00 04              move.l   a3, $4(a1)
  f011c6: 27 7c ff ff ff ff 00 04  move.l   #$ffffffff, $4(a3)

loc_F011CE:
  f011ce: 4c df 0e 08              movem.l  (a7)+, d3/a1-a3
  f011d2: 4e 73                    rte      

loc_F011D4:
  f011d4: 4a 41                    tst.w    d1
  f011d6: 6b f6                    bmi.b    $f011ce
  f011d8: 26 29 00 04              move.l   $4(a1), d3
  f011dc: 66 06                    bne.b    $f011e4
  f011de: 54 af 00 12              addq.l   #$2, $12(a7)
  f011e2: 60 ea                    bra.b    $f011ce

loc_F011E4:
  f011e4: 26 43                    movea.l  d3, a3
  f011e6: 23 53 00 04              move.l   (a3), $4(a1)

loc_F011EA:
  f011ea: 46 ef 00 10              move.w   $10(a7), sr
  f011ee: 42 ab 00 04              clr.l    $4(a3)
  f011f2: 27 40 00 0c              move.l   d0, $c(a3)
  f011f6: 27 40 00 08              move.l   d0, $8(a3)
  f011fa: 27 48 00 10              move.l   a0, $10(a3)
  f011fe: 27 42 00 16              move.l   d2, $16(a3)
  f01202: 42 ab 00 1a              clr.l    $1a(a3)
  f01206: 42 6b 00 14              clr.w    $14(a3)
  f0120a: 08 01 00 0e              btst.b   #$e, d1
  f0120e: 67 06                    beq.b    $f01216
  f01210: 08 eb 00 0e 00 14        bset.b   #$e, $14(a3)

loc_F01216:
  f01216: e1 49                    lsl.w    #$8, d1
  f01218: 02 41 07 00              andi.w   #$700, d1
  f0121c: 00 41 20 00              ori.w    #$2000, d1
  f01220: 37 41 00 1c              move.w   d1, $1c(a3)
  f01224: 61 00 fd 70              bsr.w    $f00f96
  f01228: d3 ab 00 08              add.l    d1, $8(a3)
  f0122c: 46 fc 27 00              move.w   #$2700, sr
  f01230: 26 a9 00 0c              move.l   $c(a1), (a3)
  f01234: 23 4b 00 0c              move.l   a3, $c(a1)
  f01238: 4c df 0e 08              movem.l  (a7)+, d3/a1-a3
  f0123c: 4e 73                    rte      

TRAP0_T0PAGAL_bsr:
  f0123e: 40 e7                    move.w   sr, -(a7)

TRAP0_T0PAGAL:
  f01240: 48 e7 1c 1c              movem.l  d3-d5/a3-a5, -(a7)
  f01244: 26 08                    move.l   a0, d3
  f01246: 42 82                    clr.l    d2
  f01248: 34 03                    move.w   d3, d2
  f0124a: 66 06                    bne.b    $f01252
  f0124c: 78 01                    moveq    #$1, d4
  f0124e: 60 00 00 96              bra.w    $f012e6

loc_F01252:
  f01252: 48 43                    swap     d3
  f01254: 32 03                    move.w   d3, d1
  f01256: 78 01                    moveq    #$1, d4
  f01258: 02 83 00 00 00 0f        andi.l   #$f, d3
  f0125e: 66 14                    bne.b    $f01274
  f01260: 36 01                    move.w   d1, d3
  f01262: 02 83 00 00 00 70        andi.l   #$70, d3
  f01268: 78 00                    moveq    #$0, d4
  f0126a: 08 01 00 0a              btst.b   #$a, d1
  f0126e: 67 04                    beq.b    $f01274
  f01270: 61 00 01 3e              bsr.w    $f013b0

loc_F01274:
  f01274: 4b f8 00 00              lea.l    $0.w, a5
  f01278: 49 f8 00 00              lea.l    $0.w, a4
  f0127c: 42 a7                    clr.l    -(a7)
  f0127e: 24 49                    movea.l  a1, a2
  f01280: 22 78 0c 00              movea.l  $c00.w, a1
  f01284: 08 01 00 08              btst.b   #$8, d1
  f01288: 66 00 01 48              bne.w    $f013d2

loc_F0128C:
  f0128c: 4a 51                    tst.w    (a1)
  f0128e: 6b 24                    bmi.b    $f012b4
  f01290: b6 31 40 00              cmp.b    (a1, d4.w), d3
  f01294: 66 1e                    bne.b    $f012b4
  f01296: 26 69 00 06              movea.l  $6(a1), a3
  f0129a: 20 4f                    movea.l  a7, a0

loc_F0129C:
  f0129c: 4a 90                    tst.l    (a0)
  f0129e: 67 06                    beq.b    $f012a6
  f012a0: b7 d8                    cmpa.l   (a0)+, a3
  f012a2: 67 10                    beq.b    $f012b4
  f012a4: 60 f6                    bra.b    $f0129c

loc_F012A6:
  f012a6: 48 53                    pea.l    (a3)
  f012a8: 41 eb 00 0e              lea.l    $e(a3), a0
  f012ac: 61 00 f4 3a              bsr.w    $f006e8
  f012b0: 61 00 00 94              bsr.w    $f01346

loc_F012B4:
  f012b4: 43 e9 00 0a              lea.l    $a(a1), a1
  f012b8: 0c 51 ff ff              cmpi.w   #$ffff, (a1)
  f012bc: 66 ce                    bne.b    $f0128c

loc_F012BE:
  f012be: 42 84                    clr.l    d4
  f012c0: 20 0d                    move.l   a5, d0
  f012c2: 67 7c                    beq.b    $f01340
  f012c4: 20 0c                    move.l   a4, d0
  f012c6: 67 34                    beq.b    $f012fc
  f012c8: b4 ac 00 08              cmp.l    $8(a4), d2
  f012cc: 6f 0a                    ble.b    $f012d8
  f012ce: 08 01 00 09              btst.b   #$9, d1
  f012d2: 67 28                    beq.b    $f012fc
  f012d4: 24 2c 00 08              move.l   $8(a4), d2

loc_F012D8:
  f012d8: 61 00 00 9c              bsr.w    $f01376

loc_F012DC:
  f012dc: 12 11                    move.b   (a1), d1
  f012de: 82 29 00 01              or.b     $1(a1), d1

loc_F012E2:
  f012e2: 61 00 00 da              bsr.w    $f013be

loc_F012E6:
  f012e6: 08 ae 00 06 00 2d        bclr.b   #$6, $2d(a6)
  f012ec: 20 4b                    movea.l  a3, a0
  f012ee: 20 04                    move.l   d4, d0
  f012f0: 67 04                    beq.b    $f012f6
  f012f2: 54 af 00 1a              addq.l   #$2, $1a(a7)

loc_F012F6:
  f012f6: 4c df 38 38              movem.l  (a7)+, d3-d5/a3-a5
  f012fa: 4e 73                    rte      

loc_F012FC:
  f012fc: 08 01 00 0a              btst.b   #$a, d1
  f01300: 67 40                    beq.b    $f01342
  f01302: 08 ee 00 06 00 2d        bset.b   #$6, $2d(a6)
  f01308: 1d 7c 00 f0 00 26        move.b   #$f0, $26(a6)
  f0130e: 41 ed 00 14              lea.l    $14(a5), a0
  f01312: 2d 48 00 94              move.l   a0, $94(a6)
  f01316: 00 7c 07 00              ori.w    #$700, sr
  f0131a: 30 10                    move.w   (a0), d0
  f0131c: e3 48                    lsl.w    #$1, d0
  f0131e: e2 40                    asr.w    #$1, d0

loc_F01320:
  f01320: 53 40                    subq.w   #$1, d0
  f01322: 6c fc                    bge.b    $f01320
  f01324: 30 80                    move.w   d0, (a0)
  f01326: 61 00 f3 f0              bsr.w    $f00718
  f0132a: 08 90 00 0f              bclr.b   #$f, (a0)
  f0132e: 46 fc 20 00              move.w   #$2000, sr
  f01332: 41 d6                    lea.l    (a6), a0
  f01334: 61 00 f4 8a              bsr.w    $f007c0
  f01338: 61 00 00 84              bsr.w    $f013be
  f0133c: 60 00 f1 ce              bra.w    $f0050c

loc_F01340:
  f01340: 52 84                    addq.l   #$1, d4

loc_F01342:
  f01342: 52 84                    addq.l   #$1, d4
  f01344: 60 9c                    bra.b    $f012e2

loc_F01346:
  f01346: 20 13                    move.l   (a3), d0
  f01348: 67 2a                    beq.b    $f01374

loc_F0134A:
  f0134a: 24 40                    movea.l  d0, a2
  f0134c: 20 0c                    move.l   a4, d0
  f0134e: 67 1c                    beq.b    $f0136c
  f01350: 2a 2a 00 08              move.l   $8(a2), d5
  f01354: ba 82                    cmp.l    d2, d5
  f01356: 6d 0e                    blt.b    $f01366
  f01358: b4 ac 00 08              cmp.l    $8(a4), d2
  f0135c: 6e 0e                    bgt.b    $f0136c
  f0135e: ba ac 00 08              cmp.l    $8(a4), d5
  f01362: 6d 08                    blt.b    $f0136c
  f01364: 60 0a                    bra.b    $f01370

loc_F01366:
  f01366: ba ac 00 08              cmp.l    $8(a4), d5
  f0136a: 6f 04                    ble.b    $f01370

loc_F0136C:
  f0136c: 28 4a                    movea.l  a2, a4
  f0136e: 2a 4b                    movea.l  a3, a5

loc_F01370:
  f01370: 20 12                    move.l   (a2), d0
  f01372: 66 d6                    bne.b    $f0134a

loc_F01374:
  f01374: 4e 75                    rts      

loc_F01376:
  f01376: 95 ac 00 08              sub.l    d2, $8(a4)
  f0137a: d5 ac 00 0c              add.l    d2, $c(a4)
  f0137e: 2a 2c 00 08              move.l   $8(a4), d5
  f01382: e1 8d                    lsl.l    #$8, d5
  f01384: 47 f4 58 00              lea.l    (a4, d5.l), a3
  f01388: 66 1a                    bne.b    $f013a4
  f0138a: 2a 2c 00 0c              move.l   $c(a4), d5
  f0138e: 24 54                    movea.l  (a4), a2
  f01390: 20 2c 00 04              move.l   $4(a4), d0
  f01394: 67 10                    beq.b    $f013a6
  f01396: 22 40                    movea.l  d0, a1
  f01398: db a9 00 0c              add.l    d5, $c(a1)
  f0139c: 22 8a                    move.l   a2, (a1)
  f0139e: 67 04                    beq.b    $f013a4
  f013a0: 25 49 00 04              move.l   a1, $4(a2)

loc_F013A4:
  f013a4: 4e 75                    rts      

loc_F013A6:
  f013a6: 2a 8a                    move.l   a2, (a5)
  f013a8: 67 fa                    beq.b    $f013a4
  f013aa: 42 aa 00 04              clr.l    $4(a2)
  f013ae: 4e 75                    rts      

loc_F013B0:
  f013b0: 40 e7                    move.w   sr, -(a7)
  f013b2: 61 00 f3 88              bsr.w    $f0073c
  f013b6: 1d 6e 00 77 00 26        move.b   $77(a6), $26(a6)
  f013bc: 4e 73                    rte      

loc_F013BE:
  f013be: 22 5f                    movea.l  (a7)+, a1

loc_F013C0:
  f013c0: 20 1f                    move.l   (a7)+, d0
  f013c2: 67 0c                    beq.b    $f013d0
  f013c4: 20 40                    movea.l  d0, a0
  f013c6: 41 e8 00 0e              lea.l    $e(a0), a0
  f013ca: 61 00 f3 bc              bsr.w    $f00788
  f013ce: 60 f0                    bra.b    $f013c0

loc_F013D0:
  f013d0: 4e d1                    jmp      (a1)

loc_F013D2:
  f013d2: 0c 11 00 01              cmpi.b   #$1, (a1)
  f013d6: 67 00 00 9c              beq.w    $f01474
  f013da: b5 e9 00 06              cmpa.l   $6(a1), a2
  f013de: 6c 00 00 94              bge.w    $f01474
  f013e2: b5 e9 00 02              cmpa.l   $2(a1), a2
  f013e6: 6d 00 00 98              blt.w    $f01480
  f013ea: 08 01 00 0f              btst.b   #$f, d1
  f013ee: 66 00 ff 50              bne.w    $f01340
  f013f2: 4a 51                    tst.w    (a1)
  f013f4: 6b 00 00 8a              bmi.w    $f01480
  f013f8: 2a 69 00 06              movea.l  $6(a1), a5
  f013fc: 48 55                    pea.l    (a5)
  f013fe: 41 ed 00 0e              lea.l    $e(a5), a0
  f01402: 61 00 f2 e4              bsr.w    $f006e8
  f01406: 20 15                    move.l   (a5), d0
  f01408: 67 00 fe f2              beq.w    $f012fc
  f0140c: e1 8a                    lsl.l    #$8, d2
  f0140e: 26 4a                    movea.l  a2, a3
  f01410: d7 c2                    adda.l   d2, a3
  f01412: e0 8a                    lsr.l    #$8, d2

loc_F01414:
  f01414: 28 40                    movea.l  d0, a4
  f01416: b0 8a                    cmp.l    a2, d0
  f01418: 6e 00 fe e2              bgt.w    $f012fc
  f0141c: 20 2c 00 08              move.l   $8(a4), d0
  f01420: e1 88                    lsl.l    #$8, d0
  f01422: d0 8c                    add.l    a4, d0
  f01424: b0 8a                    cmp.l    a2, d0
  f01426: 6e 08                    bgt.b    $f01430
  f01428: 20 14                    move.l   (a4), d0
  f0142a: 66 e8                    bne.b    $f01414
  f0142c: 60 00 fe ce              bra.w    $f012fc

loc_F01430:
  f01430: b0 8b                    cmp.l    a3, d0
  f01432: 67 00 fe 8a              beq.w    $f012be
  f01436: 6e 12                    bgt.b    $f0144a
  f01438: 08 01 00 09              btst.b   #$9, d1
  f0143c: 67 00 fe be              beq.w    $f012fc
  f01440: 90 8a                    sub.l    a2, d0
  f01442: e0 88                    lsr.l    #$8, d0
  f01444: 24 00                    move.l   d0, d2
  f01446: 60 00 fe 76              bra.w    $f012be

loc_F0144A:
  f0144a: 26 94                    move.l   (a4), (a3)
  f0144c: 67 06                    beq.b    $f01454
  f0144e: 22 54                    movea.l  (a4), a1
  f01450: 23 4b 00 04              move.l   a3, $4(a1)

loc_F01454:
  f01454: 28 8b                    move.l   a3, (a4)
  f01456: 27 4c 00 04              move.l   a4, $4(a3)
  f0145a: 27 6c 00 0c 00 0c        move.l   $c(a4), $c(a3)
  f01460: 42 ac 00 0c              clr.l    $c(a4)
  f01464: 90 8b                    sub.l    a3, d0
  f01466: e0 88                    lsr.l    #$8, d0
  f01468: 27 40 00 08              move.l   d0, $8(a3)
  f0146c: 91 ac 00 08              sub.l    d0, $8(a4)
  f01470: 60 00 fe 4c              bra.w    $f012be

loc_F01474:
  f01474: 43 e9 00 0a              lea.l    $a(a1), a1
  f01478: 0c 51 ff ff              cmpi.w   #$ffff, (a1)
  f0147c: 66 00 ff 54              bne.w    $f013d2

loc_F01480:
  f01480: 08 01 00 0f              btst.b   #$f, d1
  f01484: 67 00 fe ba              beq.w    $f01340
  f01488: 26 4a                    movea.l  a2, a3
  f0148a: 42 84                    clr.l    d4
  f0148c: 60 00 fe 4e              bra.w    $f012dc

TRAP0_dir_1B:
  f01490: 61 00 ec f4              bsr.w    $f00186

TRAP0_T0PGFR_bsr:
  f01494: 40 e7                    move.w   sr, -(a7)

TRAP0_T0PGFR:
  f01496: 48 e7 00 0c              movem.l  a4-a5, -(a7)
  f0149a: 24 01                    move.l   d1, d2
  f0149c: 6e 0a                    bgt.b    $f014a8

loc_F0149E:
  f0149e: 4c df 30 00              movem.l  (a7)+, a4-a5
  f014a2: 54 af 00 02              addq.l   #$2, $2(a7)

loc_F014A6:
  f014a6: 4e 73                    rte      

loc_F014A8:
  f014a8: 24 48                    movea.l  a0, a2
  f014aa: 22 78 0c 00              movea.l  $c00.w, a1

loc_F014AE:
  f014ae: 0c 11 ff ff              cmpi.b   #$ff, (a1)
  f014b2: 67 1e                    beq.b    $f014d2
  f014b4: 2a 69 00 06              movea.l  $6(a1), a5
  f014b8: b5 cd                    cmpa.l   a5, a2
  f014ba: 6c 16                    bge.b    $f014d2
  f014bc: b5 e9 00 02              cmpa.l   $2(a1), a2
  f014c0: 6d dc                    blt.b    $f0149e
  f014c2: 4a 51                    tst.w    (a1)
  f014c4: 6b e0                    bmi.b    $f014a6
  f014c6: e1 89                    lsl.l    #$8, d1
  f014c8: d2 8a                    add.l    a2, d1
  f014ca: b2 ad 00 08              cmp.l    $8(a5), d1
  f014ce: 62 ce                    bhi.b    $f0149e
  f014d0: 60 0c                    bra.b    $f014de

loc_F014D2:
  f014d2: 43 e9 00 0a              lea.l    $a(a1), a1
  f014d6: 0c 51 ff ff              cmpi.w   #$ffff, (a1)
  f014da: 66 d2                    bne.b    $f014ae
  f014dc: 60 c0                    bra.b    $f0149e

loc_F014DE:
  f014de: 43 f8 00 00              lea.l    $0.w, a1
  f014e2: 41 ed 00 0e              lea.l    $e(a5), a0
  f014e6: 61 00 f2 00              bsr.w    $f006e8
  f014ea: 26 15                    move.l   (a5), d3
  f014ec: 67 1e                    beq.b    $f0150c

loc_F014EE:
  f014ee: 20 43                    movea.l  d3, a0
  f014f0: b1 c1                    cmpa.l   d1, a0
  f014f2: 6c 06                    bge.b    $f014fa
  f014f4: 22 48                    movea.l  a0, a1
  f014f6: 26 10                    move.l   (a0), d3
  f014f8: 66 f4                    bne.b    $f014ee

loc_F014FA:
  f014fa: 20 09                    move.l   a1, d0
  f014fc: 67 0e                    beq.b    $f0150c
  f014fe: 20 29 00 08              move.l   $8(a1), d0
  f01502: e1 88                    lsl.l    #$8, d0
  f01504: d0 89                    add.l    a1, d0
  f01506: b5 c0                    cmpa.l   d0, a2
  f01508: 6d 00 00 ac              blt.w    $f015b6

loc_F0150C:
  f0150c: 25 42 00 08              move.l   d2, $8(a2)
  f01510: 20 03                    move.l   d3, d0
  f01512: 66 04                    bne.b    $f01518
  f01514: 20 2d 00 08              move.l   $8(a5), d0

loc_F01518:
  f01518: 90 81                    sub.l    d1, d0
  f0151a: e0 88                    lsr.l    #$8, d0
  f0151c: 25 40 00 0c              move.l   d0, $c(a2)
  f01520: 24 83                    move.l   d3, (a2)
  f01522: 25 49 00 04              move.l   a1, $4(a2)
  f01526: 66 04                    bne.b    $f0152c
  f01528: 2a 8a                    move.l   a2, (a5)
  f0152a: 60 24                    bra.b    $f01550

loc_F0152C:
  f0152c: 22 8a                    move.l   a2, (a1)
  f0152e: 20 0a                    move.l   a2, d0
  f01530: 90 89                    sub.l    a1, d0
  f01532: e0 88                    lsr.l    #$8, d0
  f01534: 90 a9 00 08              sub.l    $8(a1), d0
  f01538: 23 40 00 0c              move.l   d0, $c(a1)
  f0153c: 66 12                    bne.b    $f01550
  f0153e: 20 2a 00 08              move.l   $8(a2), d0
  f01542: d1 a9 00 08              add.l    d0, $8(a1)
  f01546: 23 6a 00 0c 00 0c        move.l   $c(a2), $c(a1)
  f0154c: 22 92                    move.l   (a2), (a1)
  f0154e: 24 49                    movea.l  a1, a2

loc_F01550:
  f01550: 4a 83                    tst.l    d3
  f01552: 67 24                    beq.b    $f01578
  f01554: 22 43                    movea.l  d3, a1
  f01556: 23 4a 00 04              move.l   a2, $4(a1)
  f0155a: 4a aa 00 0c              tst.l    $c(a2)
  f0155e: 66 18                    bne.b    $f01578
  f01560: 20 29 00 08              move.l   $8(a1), d0
  f01564: d1 aa 00 08              add.l    d0, $8(a2)
  f01568: 25 69 00 0c 00 0c        move.l   $c(a1), $c(a2)
  f0156e: 24 91                    move.l   (a1), (a2)
  f01570: 67 06                    beq.b    $f01578
  f01572: 22 52                    movea.l  (a2), a1
  f01574: 23 4a 00 04              move.l   a2, $4(a1)

loc_F01578:
  f01578: 12 2d 00 0c              move.b   $c(a5), d1
  f0157c: 02 01 00 f0              andi.b   #$f0, d1
  f01580: 22 78 0c 00              movea.l  $c00.w, a1

loc_F01584:
  f01584: b2 11                    cmp.b    (a1), d1
  f01586: 66 16                    bne.b    $f0159e
  f01588: 28 69 00 06              movea.l  $6(a1), a4

loc_F0158C:
  f0158c: 08 2c 00 06 00 14        btst.b   #$6, $14(a4)
  f01592: 67 0a                    beq.b    $f0159e
  f01594: 41 ec 00 14              lea.l    $14(a4), a0
  f01598: 61 00 f1 ee              bsr.w    $f00788
  f0159c: 60 ee                    bra.b    $f0158c

loc_F0159E:
  f0159e: 43 e9 00 0a              lea.l    $a(a1), a1
  f015a2: 0c 51 ff ff              cmpi.w   #$ffff, (a1)
  f015a6: 66 dc                    bne.b    $f01584

loc_F015A8:
  f015a8: 41 ed 00 0e              lea.l    $e(a5), a0
  f015ac: 61 00 f1 da              bsr.w    $f00788
  f015b0: 4c df 30 00              movem.l  (a7)+, a4-a5
  f015b4: 4e 73                    rte      

loc_F015B6:
  f015b6: 54 af 00 02              addq.l   #$2, $2(a7)
  f015ba: 60 ec                    bra.b    $f015a8

TRAP0_T0QEVNTN_bsr:
  f015bc: 40 e7                    move.w   sr, -(a7)

TRAP0_T0QEVNTN:
  f015be: 2a 49                    movea.l  a1, a5
  f015c0: 22 48                    movea.l  a0, a1
  f015c2: 20 51                    movea.l  (a1), a0
  f015c4: 22 29 00 04              move.l   $4(a1), d1
  f015c8: 61 00 01 34              bsr.w    $f016fe
  f015cc: 60 06                    bra.b    $f015d4

loc_F015CE:
  f015ce: 54 af 00 02              addq.l   #$2, $2(a7)
  f015d2: 4e 73                    rte      

loc_F015D4:
  f015d4: 22 4d                    movea.l  a5, a1
  f015d6: 60 02                    bra.b    $f015da

TRAP0_T0QEVNTT_bsr:
  f015d8: 40 e7                    move.w   sr, -(a7)

TRAP0_T0QEVNTT:
  f015da: 0c 90 21 54 43 42        cmpi.l   #$21544342, (a0)
  f015e0: 66 ec                    bne.b    $f015ce
  f015e2: 2a 48                    movea.l  a0, a5
  f015e4: 28 6d 00 40              movea.l  $40(a5), a4
  f015e8: 0c 94 21 41 53 51        cmpi.l   #$21415351, (a4)
  f015ee: 66 08                    bne.b    $f015f8
  f015f0: 08 ec 00 0f 00 04        bset.b   #$f, $4(a4)
  f015f6: 60 20                    bra.b    $f01618

loc_F015F8:
  f015f8: 54 af 00 02              addq.l   #$2, $2(a7)
  f015fc: 60 00 00 6a              bra.w    $f01668

TRAP0_T0QEVNTI_bsr:
  f01600: 40 e7                    move.w   sr, -(a7)

TRAP0_T0QEVNTI:
  f01602: 0c 90 21 54 43 42        cmpi.l   #$21544342, (a0)
  f01608: 66 50                    bne.b    $f0165a
  f0160a: 2a 48                    movea.l  a0, a5
  f0160c: 28 6d 00 40              movea.l  $40(a5), a4
  f01610: 20 0c                    move.l   a4, d0
  f01612: 67 ba                    beq.b    $f015ce
  f01614: 4a f8 0c 5b              tas.b    $c5b.w

loc_F01618:
  f01618: 08 2c 00 08 00 04        btst.b   #$8, $4(a4)
  f0161e: 67 3a                    beq.b    $f0165a
  f01620: 22 02                    move.l   d2, d1
  f01622: e1 99                    rol.l    #$8, d1
  f01624: 02 81 00 00 00 ff        andi.l   #$ff, d1
  f0162a: 61 00 11 38              bsr.w    $f02764
  f0162e: 60 02                    bra.b    $f01632
  f01630: 60 28                    bra.b    $f0165a

loc_F01632:
  f01632: 48 e7 3c 00              movem.l  d2-d5, -(a7)
  f01636: 74 10                    moveq    #$10, d2
  f01638: 61 30                    bsr.b    $f0166a
  f0163a: 67 0e                    beq.b    $f0164a
  f0163c: df fc 00 00 00 10        adda.l   #$10, a7
  f01642: 48 e7 03 60              movem.l  d6-d7/a1-a2, -(a7)
  f01646: 74 10                    moveq    #$10, d2
  f01648: 61 20                    bsr.b    $f0166a

loc_F0164A:
  f0164a: df fc 00 00 00 10        adda.l   #$10, a7
  f01650: 4a 80                    tst.l    d0
  f01652: 67 0a                    beq.b    $f0165e
  f01654: 61 00 10 52              bsr.w    $f026a8
  f01658: 60 04                    bra.b    $f0165e

loc_F0165A:
  f0165a: 54 af 00 02              addq.l   #$2, $2(a7)

loc_F0165E:
  f0165e: 08 ac 00 0f 00 04        bclr.b   #$f, $4(a4)
  f01664: 66 02                    bne.b    $f01668
  f01666: 4e 73                    rte      

loc_F01668:
  f01668: 4e 73                    rte      

loc_F0166A:
  f0166a: 41 ef 00 04              lea.l    $4(a7), a0

loc_F0166E:
  f0166e: 36 d8                    move.w   (a0)+, (a3)+
  f01670: b7 ec 00 1a              cmpa.l   $1a(a4), a3
  f01674: 65 04                    bcs.b    $f0167a
  f01676: 26 6c 00 16              movea.l  $16(a4), a3

loc_F0167A:
  f0167a: 55 42                    subq.w   #$2, d2
  f0167c: 67 06                    beq.b    $f01684
  f0167e: 55 81                    subq.l   #$2, d1
  f01680: 66 ec                    bne.b    $f0166e
  f01682: 4e 75                    rts      

loc_F01684:
  f01684: 55 41                    subq.w   #$2, d1
  f01686: 4e 75                    rts      

loc_F01688:
  f01688: 48 e7 c0 1c              movem.l  d0-d1/a3-a5, -(a7)
  f0168c: 40 e7                    move.w   sr, -(a7)
  f0168e: 26 78 0c 30              movea.l  $c30.w, a3
  f01692: 00 7c 07 00              ori.w    #$700, sr
  f01696: 2a 53                    movea.l  (a3), a5
  f01698: bb eb 00 04              cmpa.l   $4(a3), a5
  f0169c: 66 04                    bne.b    $f016a2
  f0169e: 4b eb 00 08              lea.l    $8(a3), a5

loc_F016A2:
  f016a2: 49 ed 00 1a              lea.l    $1a(a5), a4
  f016a6: 26 8c                    move.l   a4, (a3)
  f016a8: 46 df                    move.w   (a7)+, sr
  f016aa: 2b 40 00 10              move.l   d0, $10(a5)
  f016ae: 2b 48 00 08              move.l   a0, $8(a5)
  f016b2: 2b 4e 00 0c              move.l   a6, $c(a5)
  f016b6: 28 6f 00 14              movea.l  $14(a7), a4
  f016ba: 3a 94                    move.w   (a4), (a5)
  f016bc: 54 af 00 14              addq.l   #$2, $14(a7)
  f016c0: 3b 6f 00 18 00 02        move.w   $18(a7), $2(a5)
  f016c6: 2b 6f 00 1a 00 04        move.l   $1a(a7), $4(a5)
  f016cc: 0c 55 ef ff              cmpi.w   #$efff, (a5)
  f016d0: 62 06                    bhi.b    $f016d8
  f016d2: 2b 6f 00 20 00 08        move.l   $20(a7), $8(a5)

loc_F016D8:
  f016d8: 61 00 f8 bc              bsr.w    $f00f96
  f016dc: 2b 41 00 14              move.l   d1, $14(a5)
  f016e0: 32 3c 00 f9              move.w   #$f9, d1
  f016e4: 92 00                    sub.b    d0, d1
  f016e6: e0 48                    lsr.w    #$8, d0
  f016e8: 46 40                    not.w    d0
  f016ea: 02 40 00 03              andi.w   #$3, d0
  f016ee: c0 fc 00 fa              mulu.w   #$fa, d0
  f016f2: d2 40                    add.w    d0, d1
  f016f4: 3b 41 00 18              move.w   d1, $18(a5)
  f016f8: 4c df 38 03              movem.l  (a7)+, d0-d1/a3-a5
  f016fc: 4e 75                    rts      

TRAP0_T0GTXTCB_bsr:
  f016fe: 40 e7                    move.w   sr, -(a7)

TRAP0_T0GTXTCB:
  f01700: 20 08                    move.l   a0, d0
  f01702: 67 06                    beq.b    $f0170a
  f01704: 4a 81                    tst.l    d1
  f01706: 67 1a                    beq.b    $f01722
  f01708: 60 1c                    bra.b    $f01726

loc_F0170A:
  f0170a: 20 4e                    movea.l  a6, a0
  f0170c: 4e 73                    rte      

TRAP0_T0GETTCB_bsr:
  f0170e: 40 e7                    move.w   sr, -(a7)

TRAP0_T0GETTCB:
  f01710: 20 10                    move.l   (a0), d0
  f01712: 67 f6                    beq.b    $f0170a
  f01714: 22 28 00 04              move.l   $4(a0), d1
  f01718: 67 08                    beq.b    $f01722
  f0171a: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f01720: 66 04                    bne.b    $f01726

loc_F01722:
  f01722: 22 2e 00 14              move.l   $14(a6), d1

loc_F01726:
  f01726: b0 ae 00 10              cmp.l    $10(a6), d0
  f0172a: 66 06                    bne.b    $f01732
  f0172c: b2 ae 00 14              cmp.l    $14(a6), d1
  f01730: 67 d8                    beq.b    $f0170a

loc_F01732:
  f01732: 22 78 0c 10              movea.l  $c10.w, a1

loc_F01736:
  f01736: b3 fc 00 00 00 00        cmpa.l   #$0, a1
  f0173c: 67 12                    beq.b    $f01750
  f0173e: b0 a9 00 10              cmp.l    $10(a1), d0
  f01742: 66 06                    bne.b    $f0174a
  f01744: b2 a9 00 14              cmp.l    $14(a1), d1
  f01748: 67 0a                    beq.b    $f01754

loc_F0174A:
  f0174a: 22 69 00 04              movea.l  $4(a1), a1
  f0174e: 60 e6                    bra.b    $f01736

loc_F01750:
  f01750: 54 af 00 02              addq.l   #$2, $2(a7)

loc_F01754:
  f01754: 20 49                    movea.l  a1, a0
  f01756: 4e 73                    rte      

loc_F01758:
  f01758: 40 e7                    move.w   sr, -(a7)
  f0175a: 60 06                    bra.b    $f01762

TRAP0_T0LOGPHY_bsr:
  f0175c: 40 e7                    move.w   sr, -(a7)

TRAP0_T0LOGPHY:
  f0175e: 08 86 00 00              bclr.b   #$0, d6

TRAP0_T0LOGPHO:
  f01762: 02 86 00 ff ff ff        andi.l   #$ffffff, d6
  f01768: 42 80                    clr.l    d0
  f0176a: 26 06                    move.l   d6, d3
  f0176c: e0 8e                    lsr.l    #$8, d6
  f0176e: 28 05                    move.l   d5, d4
  f01770: 6f 44                    ble.b    $f017b6
  f01772: d8 83                    add.l    d3, d4
  f01774: 53 84                    subq.l   #$1, d4
  f01776: e0 8c                    lsr.l    #$8, d4
  f01778: 42 85                    clr.l    d5
  f0177a: 3a 28 00 06              move.w   $6(a0), d5

loc_F0177E:
  f0177e: 4a 30 50 07              tst.b    $7(a0, d5.w)
  f01782: 67 28                    beq.b    $f017ac
  f01784: bc 70 50 00              cmp.w    (a0, d5.w), d6
  f01788: 65 24                    bcs.b    $f017ae
  f0178a: bc 70 50 02              cmp.w    $2(a0, d5.w), d6
  f0178e: 62 1e                    bhi.b    $f017ae
  f01790: b8 70 50 02              cmp.w    $2(a0, d5.w), d4
  f01794: 62 26                    bhi.b    $f017bc
  f01796: dc 70 50 04              add.w    $4(a0, d5.w), d6
  f0179a: e1 8e                    lsl.l    #$8, d6
  f0179c: dc 03                    add.b    d3, d6
  f0179e: 08 30 00 0b 50 24        btst.b   #$b, $24(a0, d5.w)
  f017a4: 67 04                    beq.b    $f017aa
  f017a6: 58 af 00 02              addq.l   #$4, $2(a7)

loc_F017AA:
  f017aa: 4e 73                    rte      

loc_F017AC:
  f017ac: 20 05                    move.l   d5, d0

loc_F017AE:
  f017ae: 51 85                    subq.l   #$8, d5
  f017b0: 0c 45 00 0c              cmpi.w   #$c, d5
  f017b4: 6c c8                    bge.b    $f0177e

loc_F017B6:
  f017b6: 2a 00                    move.l   d0, d5
  f017b8: 54 af 00 02              addq.l   #$2, $2(a7)

loc_F017BC:
  f017bc: 54 af 00 02              addq.l   #$2, $2(a7)
  f017c0: 2c 03                    move.l   d3, d6
  f017c2: 4e 73                    rte      

TRAP0_T0FNDSEG_bsr:
  f017c4: 40 e7                    move.w   sr, -(a7)

TRAP0_T0FNDSEG:
  f017c6: 42 80                    clr.l    d0
  f017c8: 2a 08                    move.l   a0, d5
  f017ca: 67 20                    beq.b    $f017ec
  f017cc: 42 85                    clr.l    d5
  f017ce: 3a 28 00 06              move.w   $6(a0), d5

loc_F017D2:
  f017d2: 08 30 00 0f 50 24        btst.b   #$f, $24(a0, d5.w)
  f017d8: 66 04                    bne.b    $f017de
  f017da: 20 05                    move.l   d5, d0
  f017dc: 60 06                    bra.b    $f017e4

loc_F017DE:
  f017de: be b0 50 20              cmp.l    $20(a0, d5.w), d7
  f017e2: 67 0e                    beq.b    $f017f2

loc_F017E4:
  f017e4: 51 85                    subq.l   #$8, d5
  f017e6: 0c 45 00 0c              cmpi.w   #$c, d5
  f017ea: 6c e6                    bge.b    $f017d2

loc_F017EC:
  f017ec: 2a 00                    move.l   d0, d5
  f017ee: 54 af 00 02              addq.l   #$2, $2(a7)

loc_F017F2:
  f017f2: 4e 73                    rte      

TRAP0_T0FNDGSG_bsr:
  f017f4: 40 e7                    move.w   sr, -(a7)

TRAP0_T0FNDGSG:
  f017f6: 42 83                    clr.l    d3
  f017f8: 42 80                    clr.l    d0
  f017fa: 22 78 0c 20              movea.l  $c20.w, a1
  f017fe: 20 09                    move.l   a1, d0
  f01800: 67 62                    beq.b    $f01864
  f01802: 45 e9 00 14              lea.l    $14(a1), a2
  f01806: 30 29 00 0e              move.w   $e(a1), d0
  f0180a: 67 50                    beq.b    $f0185c
  f0180c: 97 cb                    suba.l   a3, a3

loc_F0180E:
  f0180e: 4a 6a 00 0a              tst.w    $a(a2)
  f01812: 66 0c                    bne.b    $f01820
  f01814: b7 fc 00 00 00 00        cmpa.l   #$0, a3
  f0181a: 66 24                    bne.b    $f01840
  f0181c: 26 4a                    movea.l  a2, a3
  f0181e: 60 20                    bra.b    $f01840

loc_F01820:
  f01820: b1 ea 00 04              cmpa.l   $4(a2), a0
  f01824: 66 1a                    bne.b    $f01840
  f01826: b4 92                    cmp.l    (a2), d2
  f01828: 67 44                    beq.b    $f0186e
  f0182a: 08 2a 00 0c 00 08        btst.b   #$c, $8(a2)
  f01830: 67 0e                    beq.b    $f01840
  f01832: 08 01 00 0c              btst.b   #$c, d1
  f01836: 66 36                    bne.b    $f0186e
  f01838: 08 01 00 0d              btst.b   #$d, d1
  f0183c: 66 02                    bne.b    $f01840
  f0183e: 26 0a                    move.l   a2, d3

loc_F01840:
  f01840: d5 fc 00 00 00 12        adda.l   #$12, a2
  f01846: 53 40                    subq.w   #$1, d0
  f01848: 66 c4                    bne.b    $f0180e
  f0184a: 4a 83                    tst.l    d3
  f0184c: 66 24                    bne.b    $f01872
  f0184e: 30 29 00 0e              move.w   $e(a1), d0
  f01852: 20 4b                    movea.l  a3, a0
  f01854: b7 fc 00 00 00 00        cmpa.l   #$0, a3
  f0185a: 66 0c                    bne.b    $f01868

loc_F0185C:
  f0185c: 20 4a                    movea.l  a2, a0
  f0185e: b0 69 00 0c              cmp.w    $c(a1), d0
  f01862: 6d 02                    blt.b    $f01866

loc_F01864:
  f01864: 91 c8                    suba.l   a0, a0

loc_F01866:
  f01866: 52 80                    addq.l   #$1, d0

loc_F01868:
  f01868: 54 af 00 02              addq.l   #$2, $2(a7)
  f0186c: 4e 73                    rte      

loc_F0186E:
  f0186e: 20 4a                    movea.l  a2, a0
  f01870: 4e 73                    rte      

loc_F01872:
  f01872: 20 43                    movea.l  d3, a0
  f01874: 4e 73                    rte      

TRAP0_T0FNDSEM_bsr:
  f01876: 40 e7                    move.w   sr, -(a7)

TRAP0_T0FNDSEM:
  f01878: 42 82                    clr.l    d2
  f0187a: 42 83                    clr.l    d3
  f0187c: 42 81                    clr.l    d1
  f0187e: 22 78 0c 24              movea.l  $c24.w, a1
  f01882: 28 09                    move.l   a1, d4
  f01884: 67 66                    beq.b    $f018ec
  f01886: 34 29 00 0e              move.w   $e(a1), d2
  f0188a: b4 69 00 0c              cmp.w    $c(a1), d2
  f0188e: 67 02                    beq.b    $f01892
  f01890: 52 42                    addq.w   #$1, d2

loc_F01892:
  f01892: 28 02                    move.l   d2, d4
  f01894: 70 14                    moveq    #$14, d0

loc_F01896:
  f01896: 4a 71 00 0c              tst.w    $c(a1, d0.w)
  f0189a: 66 14                    bne.b    $f018b0
  f0189c: 4a 83                    tst.l    d3
  f0189e: 66 3a                    bne.b    $f018da
  f018a0: 26 00                    move.l   d0, d3
  f018a2: 0c 84 00 00 00 01        cmpi.l   #$1, d4
  f018a8: 67 30                    beq.b    $f018da
  f018aa: 34 29 00 0e              move.w   $e(a1), d2
  f018ae: 60 2a                    bra.b    $f018da

loc_F018B0:
  f018b0: b1 fc 00 00 00 00        cmpa.l   #$0, a0
  f018b6: 67 06                    beq.b    $f018be
  f018b8: b1 f1 00 08              cmpa.l   $8(a1, d0.w), a0
  f018bc: 66 1c                    bne.b    $f018da

loc_F018BE:
  f018be: 24 6c 00 14              movea.l  $14(a4), a2
  f018c2: b5 f1 00 04              cmpa.l   $4(a1, d0.w), a2
  f018c6: 66 12                    bne.b    $f018da
  f018c8: 24 6c 00 10              movea.l  $10(a4), a2
  f018cc: b5 f1 00 00              cmpa.l   (a1, d0.w), a2
  f018d0: 67 24                    beq.b    $f018f6
  f018d2: 4a 71 00 0c              tst.w    $c(a1, d0.w)
  f018d6: 6b 02                    bmi.b    $f018da
  f018d8: 22 00                    move.l   d0, d1

loc_F018DA:
  f018da: 06 80 00 00 00 16        addi.l   #$16, d0
  f018e0: 53 44                    subq.w   #$1, d4
  f018e2: 66 b2                    bne.b    $f01896
  f018e4: 54 af 00 02              addq.l   #$2, $2(a7)
  f018e8: 4a 83                    tst.l    d3
  f018ea: 66 06                    bne.b    $f018f2

loc_F018EC:
  f018ec: 42 80                    clr.l    d0
  f018ee: 42 82                    clr.l    d2
  f018f0: 4e 73                    rte      

loc_F018F2:
  f018f2: 20 03                    move.l   d3, d0
  f018f4: 4e 73                    rte      

loc_F018F6:
  f018f6: 20 71 00 08              movea.l  $8(a1, d0.w), a0
  f018fa: 4e 73                    rte      

TRAP1_GTSEG:
  f018fc: bb ce                    cmpa.l   a6, a5
  f018fe: 67 20                    beq.b    $f01920
  f01900: 08 2d 00 0f 00 2c        btst.b   #$f, $2c(a5)
  f01906: 66 1c                    bne.b    $f01924
  f01908: 06 6e 00 0a 01 02        addi.w   #$a, $102(a6)
  f0190e: 4e 73                    rte      

loc_F01910:
  f01910: 5a 6e 01 02              addq.w   #$5, $102(a6)
  f01914: 60 00 01 72              bra.w    $f01a88

loc_F01918:
  f01918: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f0191c: 60 00 01 6a              bra.w    $f01a88

loc_F01920:
  f01920: 42 b8 0c 62              clr.l    $c62.w

loc_F01924:
  f01924: 2e 2c 00 0c              move.l   $c(a4), d7
  f01928: 20 6d 00 36              movea.l  $36(a5), a0
  f0192c: 61 00 fe 96              bsr.w    $f017c4
  f01930: 60 e6                    bra.b    $f01918
  f01932: 4a 85                    tst.l    d5
  f01934: 67 da                    beq.b    $f01910
  f01936: 30 2c 00 0a              move.w   $a(a4), d0
  f0193a: 32 2c 00 08              move.w   $8(a4), d1
  f0193e: 02 41 27 ff              andi.w   #$27ff, d1
  f01942: 08 01 00 08              btst.b   #$8, d1
  f01946: 67 04                    beq.b    $f0194c
  f01948: 08 81 00 07              bclr.b   #$7, d1

loc_F0194C:
  f0194c: 08 00 00 0a              btst.b   #$a, d0
  f01950: 66 0a                    bne.b    $f0195c
  f01952: 08 00 00 0b              btst.b   #$b, d0
  f01956: 67 10                    beq.b    $f01968
  f01958: 08 c1 00 0f              bset.b   #$f, d1

loc_F0195C:
  f0195c: 08 c1 00 08              bset.b   #$8, d1
  f01960: 08 c1 00 07              bset.b   #$7, d1
  f01964: 08 81 00 0d              bclr.b   #$d, d1

loc_F01968:
  f01968: 42 87                    clr.l    d7
  f0196a: 2c 2c 00 10              move.l   $10(a4), d6
  f0196e: 08 01 00 08              btst.b   #$8, d1
  f01972: 67 04                    beq.b    $f01978
  f01974: 08 81 00 0d              bclr.b   #$d, d1

loc_F01978:
  f01978: 08 01 00 0d              btst.b   #$d, d1
  f0197c: 67 02                    beq.b    $f01980
  f0197e: 42 86                    clr.l    d6

loc_F01980:
  f01980: 1e 06                    move.b   d6, d7
  f01982: de ac 00 14              add.l    $14(a4), d7
  f01986: 06 87 00 00 00 ff        addi.l   #$ff, d7
  f0198c: e0 8f                    lsr.l    #$8, d7
  f0198e: 02 86 00 ff ff 00        andi.l   #$ffff00, d6
  f01994: 22 46                    movea.l  d6, a1
  f01996: 08 01 00 08              btst.b   #$8, d1
  f0199a: 66 1e                    bne.b    $f019ba
  f0199c: 08 81 00 07              bclr.b   #$7, d1
  f019a0: 66 18                    bne.b    $f019ba
  f019a2: 41 f8 0c 74              lea.l    $c74.w, a0
  f019a6: 08 00 00 0e              btst.b   #$e, d0
  f019aa: 66 02                    bne.b    $f019ae
  f019ac: 52 88                    addq.l   #$1, a0

loc_F019AE:
  f019ae: 08 2d 00 0f 00 28        btst.b   #$f, $28(a5)
  f019b4: 66 02                    bne.b    $f019b8
  f019b6: 54 88                    addq.l   #$2, a0

loc_F019B8:
  f019b8: 12 10                    move.b   (a0), d1

loc_F019BA:
  f019ba: 48 47                    swap     d7
  f019bc: 3e 01                    move.w   d1, d7
  f019be: 02 47 87 ff              andi.w   #$87ff, d7
  f019c2: 3f 01                    move.w   d1, -(a7)
  f019c4: 48 47                    swap     d7
  f019c6: 20 47                    movea.l  d7, a0
  f019c8: 61 00 f8 74              bsr.w    $f0123e
  f019cc: 60 2c                    bra.b    $f019fa
  f019ce: 53 80                    subq.l   #$1, d0
  f019d0: 67 08                    beq.b    $f019da
  f019d2: 5e 6e 01 02              addq.w   #$7, $102(a6)

loc_F019D6:
  f019d6: 60 00 00 ac              bra.w    $f01a84

loc_F019DA:
  f019da: 50 6e 01 02              addq.w   #$8, $102(a6)
  f019de: 60 f6                    bra.b    $f019d6

loc_F019E0:
  f019e0: 06 6e 00 0b 01 02        addi.w   #$b, $102(a6)
  f019e6: 08 07 00 07              btst.b   #$7, d7
  f019ea: 66 ea                    bne.b    $f019d6
  f019ec: 22 07                    move.l   d7, d1
  f019ee: 41 d3                    lea.l    (a3), a0
  f019f0: 61 00 fa a2              bsr.w    $f01494
  f019f4: 60 e0                    bra.b    $f019d6
  f019f6: 61 00 e7 8e              bsr.w    $f00186

loc_F019FA:
  f019fa: 26 48                    movea.l  a0, a3
  f019fc: 2e 02                    move.l   d2, d7
  f019fe: 2a 02                    move.l   d2, d5
  f01a00: e1 8d                    lsl.l    #$8, d5
  f01a02: 08 17 00 0d              btst.b   #$d, (a7)
  f01a06: 67 02                    beq.b    $f01a0a
  f01a08: 2c 0b                    move.l   a3, d6

loc_F01A0A:
  f01a0a: 22 46                    movea.l  d6, a1
  f01a0c: 20 6d 00 36              movea.l  $36(a5), a0
  f01a10: 61 00 fd 4a              bsr.w    $f0175c
  f01a14: 60 ca                    bra.b    $f019e0
  f01a16: 60 c8                    bra.b    $f019e0
  f01a18: 4a 30 50 07              tst.b    $7(a0, d5.w)
  f01a1c: 66 c2                    bne.b    $f019e0
  f01a1e: 21 ac 00 0c 50 20        move.l   $c(a4), $20(a0, d5.w)
  f01a24: 30 2c 00 0a              move.w   $a(a4), d0
  f01a28: 02 40 4f ff              andi.w   #$4fff, d0
  f01a2c: 08 00 00 0a              btst.b   #$a, d0
  f01a30: 67 04                    beq.b    $f01a36
  f01a32: 08 c0 00 0e              bset.b   #$e, d0

loc_F01A36:
  f01a36: 31 80 50 24              move.w   d0, $24(a0, d5.w)
  f01a3a: 31 bc 00 01 50 06        move.w   #$1, $6(a0, d5.w)
  f01a40: 08 00 00 0e              btst.b   #$e, d0
  f01a44: 67 06                    beq.b    $f01a4c
  f01a46: 31 bc 00 03 50 06        move.w   #$3, $6(a0, d5.w)

loc_F01A4C:
  f01a4c: 20 09                    move.l   a1, d0
  f01a4e: e0 88                    lsr.l    #$8, d0
  f01a50: 31 80 50 00              move.w   d0, (a0, d5.w)
  f01a54: d0 87                    add.l    d7, d0
  f01a56: 53 80                    subq.l   #$1, d0
  f01a58: 31 80 50 02              move.w   d0, $2(a0, d5.w)
  f01a5c: 20 0b                    move.l   a3, d0
  f01a5e: 90 89                    sub.l    a1, d0
  f01a60: e0 88                    lsr.l    #$8, d0
  f01a62: 31 80 50 04              move.w   d0, $4(a0, d5.w)
  f01a66: 11 81 50 26              move.b   d1, $26(a0, d5.w)
  f01a6a: 08 f0 00 0f 50 24        bset.b   #$f, $24(a0, d5.w)
  f01a70: 52 28 00 05              addq.b   #$1, $5(a0)
  f01a74: 2d 4b 01 20              move.l   a3, $120(a6)
  f01a78: 08 17 00 09              btst.b   #$9, (a7)
  f01a7c: 67 06                    beq.b    $f01a84
  f01a7e: e1 8f                    lsl.l    #$8, d7
  f01a80: 2d 47 01 24              move.l   d7, $124(a6)

loc_F01A84:
  f01a84: 4f ef 00 02              lea.l    $2(a7), a7

loc_F01A88:
  f01a88: 4e 73                    rte      

TRAP1_DESEG:
  f01a8a: 2e 2c 00 0c              move.l   $c(a4), d7
  f01a8e: 38 2c 00 08              move.w   $8(a4), d4
  f01a92: 28 4d                    movea.l  a5, a4
  f01a94: b9 ce                    cmpa.l   a6, a4
  f01a96: 67 10                    beq.b    $f01aa8
  f01a98: 08 2c 00 0f 00 2c        btst.b   #$f, $2c(a4)
  f01a9e: 66 0c                    bne.b    $f01aac
  f01aa0: 06 6e 00 0a 01 02        addi.w   #$a, $102(a6)
  f01aa6: 4e 73                    rte      

loc_F01AA8:
  f01aa8: 42 b8 0c 62              clr.l    $c62.w

loc_F01AAC:
  f01aac: 2a 6c 00 36              movea.l  $36(a4), a5
  f01ab0: 41 d5                    lea.l    (a5), a0
  f01ab2: 61 00 fd 10              bsr.w    $f017c4
  f01ab6: 60 08                    bra.b    $f01ac0
  f01ab8: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f01abc: 60 00 00 b0              bra.w    $f01b6e

loc_F01AC0:
  f01ac0: 4a ac 00 40              tst.l    $40(a4)
  f01ac4: 67 1c                    beq.b    $f01ae2
  f01ac6: 20 2c 01 3c              move.l   $13c(a4), d0
  f01aca: e0 88                    lsr.l    #$8, d0
  f01acc: b0 75 50 00              cmp.w    (a5, d5.w), d0
  f01ad0: 65 10                    bcs.b    $f01ae2
  f01ad2: b0 75 50 02              cmp.w    $2(a5, d5.w), d0
  f01ad6: 62 0a                    bhi.b    $f01ae2
  f01ad8: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f01ade: 60 00 00 8e              bra.w    $f01b6e

loc_F01AE2:
  f01ae2: 30 35 50 24              move.w   $24(a5, d5.w), d0
  f01ae6: 02 40 30 00              andi.w   #$3000, d0
  f01aea: 67 40                    beq.b    $f01b2c
  f01aec: 24 2c 00 14              move.l   $14(a4), d2
  f01af0: 32 35 50 24              move.w   $24(a5, d5.w), d1
  f01af4: 20 75 50 20              movea.l  $20(a5, d5.w), a0
  f01af8: 61 00 fc fa              bsr.w    $f017f4
  f01afc: 60 04                    bra.b    $f01b02
  f01afe: 61 00 e6 86              bsr.w    $f00186

loc_F01B02:
  f01b02: 3c 28 00 10              move.w   $10(a0), d6
  f01b06: 53 46                    subq.w   #$1, d6
  f01b08: dc 75 50 00              add.w    (a5, d5.w), d6
  f01b0c: 3b 86 50 02              move.w   d6, $2(a5, d5.w)
  f01b10: 53 68 00 0a              subq.w   #$1, $a(a0)
  f01b14: 42 86                    clr.l    d6
  f01b16: 3c 28 00 0a              move.w   $a(a0), d6
  f01b1a: 08 04 00 0b              btst.b   #$b, d4
  f01b1e: 67 08                    beq.b    $f01b28
  f01b20: 08 86 00 0f              bclr.b   #$f, d6
  f01b24: 31 46 00 0a              move.w   d6, $a(a0)

loc_F01B28:
  f01b28: 4a 46                    tst.w    d6
  f01b2a: 66 2e                    bne.b    $f01b5a

loc_F01B2C:
  f01b2c: 30 35 50 24              move.w   $24(a5, d5.w), d0
  f01b30: 02 40 0c 00              andi.w   #$c00, d0
  f01b34: 66 24                    bne.b    $f01b5a
  f01b36: 42 80                    clr.l    d0
  f01b38: 30 35 50 00              move.w   (a5, d5.w), d0
  f01b3c: d0 75 50 04              add.w    $4(a5, d5.w), d0
  f01b40: e1 88                    lsl.l    #$8, d0
  f01b42: 42 81                    clr.l    d1
  f01b44: 32 35 50 02              move.w   $2(a5, d5.w), d1
  f01b48: 92 75 50 00              sub.w    (a5, d5.w), d1
  f01b4c: 52 81                    addq.l   #$1, d1
  f01b4e: 20 40                    movea.l  d0, a0
  f01b50: 61 00 f9 42              bsr.w    $f01494
  f01b54: 60 04                    bra.b    $f01b5a
  f01b56: 61 00 e6 2e              bsr.w    $f00186

loc_F01B5A:
  f01b5a: 42 b5 50 20              clr.l    $20(a5, d5.w)
  f01b5e: 42 75 50 24              clr.w    $24(a5, d5.w)
  f01b62: 42 35 50 27              clr.b    $27(a5, d5.w)
  f01b66: 42 75 50 06              clr.w    $6(a5, d5.w)
  f01b6a: 53 2d 00 05              subq.b   #$1, $5(a5)

loc_F01B6E:
  f01b6e: 4e 73                    rte      

TRAP0_dir_12_bsr:
  f01b70: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_12:
  f01b72: 4a ac 00 36              tst.l    $36(a4)
  f01b76: 67 1c                    beq.b    $f01b94
  f01b78: 2a 6c 00 36              movea.l  $36(a4), a5
  f01b7c: 42 85                    clr.l    d5
  f01b7e: 3a 2d 00 08              move.w   $8(a5), d5

loc_F01B82:
  f01b82: 08 35 00 0f 50 24        btst.b   #$f, $24(a5, d5.w)
  f01b88: 67 02                    beq.b    $f01b8c
  f01b8a: 61 62                    bsr.b    $f01bee

loc_F01B8C:
  f01b8c: 51 85                    subq.l   #$8, d5
  f01b8e: 0c 45 00 0c              cmpi.w   #$c, d5
  f01b92: 6c ee                    bge.b    $f01b82

loc_F01B94:
  f01b94: 08 2c 00 02 00 29        btst.b   #$2, $29(a4)
  f01b9a: 67 50                    beq.b    $f01bec
  f01b9c: 22 78 0c 20              movea.l  $c20.w, a1
  f01ba0: 4b e9 00 14              lea.l    $14(a1), a5
  f01ba4: 3e 29 00 0e              move.w   $e(a1), d7
  f01ba8: 67 42                    beq.b    $f01bec
  f01baa: 2c 2c 00 14              move.l   $14(a4), d6

loc_F01BAE:
  f01bae: 4a 6d 00 0a              tst.w    $a(a5)
  f01bb2: 67 2e                    beq.b    $f01be2
  f01bb4: bc 95                    cmp.l    (a5), d6
  f01bb6: 66 2a                    bne.b    $f01be2
  f01bb8: 08 ad 00 0f 00 0a        bclr.b   #$f, $a(a5)
  f01bbe: 4a 6d 00 0a              tst.w    $a(a5)
  f01bc2: 66 1e                    bne.b    $f01be2
  f01bc4: 30 2d 00 08              move.w   $8(a5), d0
  f01bc8: 02 40 0c 00              andi.w   #$c00, d0
  f01bcc: 66 14                    bne.b    $f01be2
  f01bce: 42 81                    clr.l    d1
  f01bd0: 32 2d 00 10              move.w   $10(a5), d1
  f01bd4: 20 6d 00 0c              movea.l  $c(a5), a0
  f01bd8: 61 00 f8 ba              bsr.w    $f01494
  f01bdc: 60 04                    bra.b    $f01be2
  f01bde: 61 00 e5 a6              bsr.w    $f00186

loc_F01BE2:
  f01be2: db fc 00 00 00 12        adda.l   #$12, a5
  f01be8: 53 47                    subq.w   #$1, d7
  f01bea: 66 c2                    bne.b    $f01bae

loc_F01BEC:
  f01bec: 4e 73                    rte      

loc_F01BEE:
  f01bee: 42 84                    clr.l    d4
  f01bf0: 08 2c 00 02 00 29        btst.b   #$2, $29(a4)
  f01bf6: 67 04                    beq.b    $f01bfc
  f01bf8: 08 c4 00 0b              bset.b   #$b, d4

loc_F01BFC:
  f01bfc: 40 e7                    move.w   sr, -(a7)
  f01bfe: 60 00 fe e2              bra.w    $f01ae2

TRAP1_TRSEG:
  f01c02: 26 4d                    movea.l  a5, a3
  f01c04: 42 b8 0c 62              clr.l    $c62.w
  f01c08: 2a 6e 00 36              movea.l  $36(a6), a5
  f01c0c: 2e 2c 00 0c              move.l   $c(a4), d7
  f01c10: 41 d5                    lea.l    (a5), a0
  f01c12: 61 00 fb b0              bsr.w    $f017c4
  f01c16: 60 08                    bra.b    $f01c20
  f01c18: 5e 6e 01 02              addq.w   #$7, $102(a6)

loc_F01C1C:
  f01c1c: 60 00 01 52              bra.w    $f01d70

loc_F01C20:
  f01c20: 4a ae 00 40              tst.l    $40(a6)
  f01c24: 67 20                    beq.b    $f01c46
  f01c26: 20 2e 01 3c              move.l   $13c(a6), d0
  f01c2a: e0 48                    lsr.w    #$8, d0
  f01c2c: b0 75 50 00              cmp.w    (a5, d5.w), d0
  f01c30: 65 14                    bcs.b    $f01c46
  f01c32: b0 75 50 02              cmp.w    $2(a5, d5.w), d0
  f01c36: 62 0e                    bhi.b    $f01c46
  f01c38: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f01c3e: 60 dc                    bra.b    $f01c1c

loc_F01C40:
  f01c40: 56 6e 01 02              addq.w   #$3, $102(a6)
  f01c44: 60 d6                    bra.b    $f01c1c

loc_F01C46:
  f01c46: b7 ce                    cmpa.l   a6, a3
  f01c48: 67 f6                    beq.b    $f01c40
  f01c4a: 22 45                    movea.l  d5, a1
  f01c4c: 24 46                    movea.l  d6, a2
  f01c4e: 2e 2a 00 0c              move.l   $c(a2), d7
  f01c52: 20 6b 00 36              movea.l  $36(a3), a0
  f01c56: 61 00 fb 6c              bsr.w    $f017c4
  f01c5a: 60 0c                    bra.b    $f01c68
  f01c5c: 4a 85                    tst.l    d5
  f01c5e: 66 0e                    bne.b    $f01c6e
  f01c60: 5a 6e 01 02              addq.w   #$5, $102(a6)

loc_F01C64:
  f01c64: 60 00 01 0a              bra.w    $f01d70

loc_F01C68:
  f01c68: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f01c6c: 60 f6                    bra.b    $f01c64

loc_F01C6E:
  f01c6e: 2a 09                    move.l   a1, d5
  f01c70: 2c 2a 00 10              move.l   $10(a2), d6
  f01c74: 08 2a 00 0e 00 08        btst.b   #$e, $8(a2)
  f01c7a: 66 14                    bne.b    $f01c90
  f01c7c: 42 86                    clr.l    d6
  f01c7e: 3c 35 50 00              move.w   (a5, d5.w), d6
  f01c82: 08 2a 00 0d 00 08        btst.b   #$d, $8(a2)
  f01c88: 67 04                    beq.b    $f01c8e
  f01c8a: dc 75 50 04              add.w    $4(a5, d5.w), d6

loc_F01C8E:
  f01c8e: e1 8e                    lsl.l    #$8, d6

loc_F01C90:
  f01c90: 42 80                    clr.l    d0
  f01c92: 30 35 50 02              move.w   $2(a5, d5.w), d0
  f01c96: 90 75 50 00              sub.w    (a5, d5.w), d0
  f01c9a: 24 00                    move.l   d0, d2
  f01c9c: 52 40                    addq.w   #$1, d0
  f01c9e: 2a 00                    move.l   d0, d5
  f01ca0: e1 8d                    lsl.l    #$8, d5
  f01ca2: 61 00 fa b8              bsr.w    $f0175c
  f01ca6: 60 0a                    bra.b    $f01cb2
  f01ca8: 60 08                    bra.b    $f01cb2
  f01caa: 4a 85                    tst.l    d5
  f01cac: 66 0c                    bne.b    $f01cba
  f01cae: 61 00 e4 d6              bsr.w    $f00186

loc_F01CB2:
  f01cb2: 06 6e 00 0b 01 02        addi.w   #$b, $102(a6)
  f01cb8: 60 aa                    bra.b    $f01c64

loc_F01CBA:
  f01cba: 4a 30 50 07              tst.b    $7(a0, d5.w)
  f01cbe: 66 f2                    bne.b    $f01cb2
  f01cc0: 22 06                    move.l   d6, d1
  f01cc2: 28 09                    move.l   a1, d4
  f01cc4: e0 89                    lsr.l    #$8, d1
  f01cc6: d4 41                    add.w    d1, d2
  f01cc8: 31 81 50 00              move.w   d1, (a0, d5.w)
  f01ccc: 31 82 50 02              move.w   d2, $2(a0, d5.w)
  f01cd0: 92 75 40 00              sub.w    (a5, d4.w), d1
  f01cd4: 44 41                    neg.w    d1
  f01cd6: d2 75 40 04              add.w    $4(a5, d4.w), d1
  f01cda: 31 81 50 04              move.w   d1, $4(a0, d5.w)
  f01cde: 21 b5 40 20 50 20        move.l   $20(a5, d4.w), $20(a0, d5.w)
  f01ce4: 31 b5 40 26 50 26        move.w   $26(a5, d4.w), $26(a0, d5.w)
  f01cea: 36 35 40 24              move.w   $24(a5, d4.w), d3
  f01cee: 08 2a 00 0f 00 08        btst.b   #$f, $8(a2)
  f01cf4: 67 10                    beq.b    $f01d06
  f01cf6: 08 83 00 0e              bclr.b   #$e, d3
  f01cfa: 08 2a 00 0e 00 0a        btst.b   #$e, $a(a2)
  f01d00: 67 04                    beq.b    $f01d06
  f01d02: 08 c3 00 0e              bset.b   #$e, d3

loc_F01D06:
  f01d06: 08 c3 00 0f              bset.b   #$f, d3
  f01d0a: 31 83 50 24              move.w   d3, $24(a0, d5.w)
  f01d0e: 31 bc 00 01 50 06        move.w   #$1, $6(a0, d5.w)
  f01d14: 08 03 00 0e              btst.b   #$e, d3
  f01d18: 67 06                    beq.b    $f01d20
  f01d1a: 31 bc 00 03 50 06        move.w   #$3, $6(a0, d5.w)

loc_F01D20:
  f01d20: 42 b5 40 20              clr.l    $20(a5, d4.w)
  f01d24: 42 b5 40 24              clr.l    $24(a5, d4.w)
  f01d28: 42 b5 40 00              clr.l    (a5, d4.w)
  f01d2c: 42 b5 40 04              clr.l    $4(a5, d4.w)
  f01d30: 53 2d 00 05              subq.b   #$1, $5(a5)
  f01d34: 52 28 00 05              addq.b   #$1, $5(a0)
  f01d38: 32 30 50 00              move.w   (a0, d5.w), d1
  f01d3c: d2 70 50 04              add.w    $4(a0, d5.w), d1
  f01d40: e1 89                    lsl.l    #$8, d1
  f01d42: 2d 41 01 20              move.l   d1, $120(a6)
  f01d46: 08 03 00 0d              btst.b   #$d, d3
  f01d4a: 67 24                    beq.b    $f01d70
  f01d4c: 24 2e 00 14              move.l   $14(a6), d2
  f01d50: b4 ab 00 14              cmp.l    $14(a3), d2
  f01d54: 67 1a                    beq.b    $f01d70
  f01d56: 20 70 50 20              movea.l  $20(a0, d5.w), a0
  f01d5a: 22 03                    move.l   d3, d1
  f01d5c: 28 4b                    movea.l  a3, a4
  f01d5e: 61 00 fa 94              bsr.w    $f017f4
  f01d62: 60 04                    bra.b    $f01d68
  f01d64: 61 00 e4 20              bsr.w    $f00186

loc_F01D68:
  f01d68: 26 4c                    movea.l  a4, a3
  f01d6a: 24 2b 00 14              move.l   $14(a3), d2
  f01d6e: 20 82                    move.l   d2, (a0)

loc_F01D70:
  f01d70: 4e 73                    rte      

TRAP1_ATTSEG:
  f01d72: 2a 4e                    movea.l  a6, a5
  f01d74: 42 b8 0c 62              clr.l    $c62.w
  f01d78: 60 0c                    bra.b    $f01d86

TRAP1_SHRSEG:
  f01d7a: bb ce                    cmpa.l   a6, a5
  f01d7c: 66 08                    bne.b    $f01d86
  f01d7e: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f01d84: 4e 73                    rte      

loc_F01D86:
  f01d86: 24 2d 00 14              move.l   $14(a5), d2
  f01d8a: 32 2c 00 0a              move.w   $a(a4), d1
  f01d8e: 20 6c 00 0c              movea.l  $c(a4), a0
  f01d92: 61 00 fa 60              bsr.w    $f017f4
  f01d96: 60 1e                    bra.b    $f01db6
  f01d98: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f01d9c: 60 00 00 dc              bra.w    $f01e7a

loc_F01DA0:
  f01da0: 5a 6e 01 02              addq.w   #$5, $102(a6)

loc_F01DA4:
  f01da4: 60 00 00 d4              bra.w    $f01e7a

loc_F01DA8:
  f01da8: 06 6e 00 0b 01 02        addi.w   #$b, $102(a6)
  f01dae: 60 f4                    bra.b    $f01da4

loc_F01DB0:
  f01db0: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f01db4: 60 ee                    bra.b    $f01da4

loc_F01DB6:
  f01db6: 26 48                    movea.l  a0, a3
  f01db8: 24 6d 00 36              movea.l  $36(a5), a2
  f01dbc: 2e 2b 00 04              move.l   $4(a3), d7
  f01dc0: 41 d2                    lea.l    (a2), a0
  f01dc2: 61 00 fa 00              bsr.w    $f017c4
  f01dc6: 60 e8                    bra.b    $f01db0
  f01dc8: 4a 85                    tst.l    d5
  f01dca: 67 d4                    beq.b    $f01da0
  f01dcc: 42 85                    clr.l    d5
  f01dce: 3a 2b 00 10              move.w   $10(a3), d5
  f01dd2: e1 8d                    lsl.l    #$8, d5
  f01dd4: 08 2c 00 0a 00 08        btst.b   #$a, $8(a4)
  f01dda: 67 1c                    beq.b    $f01df8
  f01ddc: ba ac 00 14              cmp.l    $14(a4), d5
  f01de0: 64 0a                    bcc.b    $f01dec
  f01de2: 06 6e 00 10 01 02        addi.w   #$10, $102(a6)
  f01de8: 60 00 00 90              bra.w    $f01e7a

loc_F01DEC:
  f01dec: 2a 2c 00 14              move.l   $14(a4), d5
  f01df0: 06 85 00 00 00 ff        addi.l   #$ff, d5
  f01df6: 42 05                    clr.b    d5

loc_F01DF8:
  f01df8: 24 05                    move.l   d5, d2
  f01dfa: 2c 2c 00 10              move.l   $10(a4), d6
  f01dfe: 42 06                    clr.b    d6
  f01e00: 08 2c 00 0d 00 08        btst.b   #$d, $8(a4)
  f01e06: 67 04                    beq.b    $f01e0c
  f01e08: 2c 2b 00 0c              move.l   $c(a3), d6

loc_F01E0C:
  f01e0c: 41 d2                    lea.l    (a2), a0
  f01e0e: 61 00 f9 4c              bsr.w    $f0175c
  f01e12: 60 94                    bra.b    $f01da8
  f01e14: 60 92                    bra.b    $f01da8
  f01e16: 4a 85                    tst.l    d5
  f01e18: 66 04                    bne.b    $f01e1e
  f01e1a: 61 00 e3 6a              bsr.w    $f00186

loc_F01E1E:
  f01e1e: 4a 30 50 07              tst.b    $7(a0, d5.w)
  f01e22: 66 84                    bne.b    $f01da8
  f01e24: 25 ab 00 04 50 20        move.l   $4(a3), $20(a2, d5.w)
  f01e2a: 42 32 50 27              clr.b    $27(a2, d5.w)
  f01e2e: 20 06                    move.l   d6, d0
  f01e30: e0 8e                    lsr.l    #$8, d6
  f01e32: 35 86 50 00              move.w   d6, (a2, d5.w)
  f01e36: e0 8a                    lsr.l    #$8, d2
  f01e38: dc 42                    add.w    d2, d6
  f01e3a: 53 46                    subq.w   #$1, d6
  f01e3c: 35 86 50 02              move.w   d6, $2(a2, d5.w)
  f01e40: 44 80                    neg.l    d0
  f01e42: d0 ab 00 0c              add.l    $c(a3), d0
  f01e46: e0 88                    lsr.l    #$8, d0
  f01e48: 35 80 50 04              move.w   d0, $4(a2, d5.w)
  f01e4c: 35 bc 00 01 50 06        move.w   #$1, $6(a2, d5.w)
  f01e52: 08 2b 00 0e 00 08        btst.b   #$e, $8(a3)
  f01e58: 67 06                    beq.b    $f01e60
  f01e5a: 35 bc 00 03 50 06        move.w   #$3, $6(a2, d5.w)

loc_F01E60:
  f01e60: 35 ab 00 08 50 24        move.w   $8(a3), $24(a2, d5.w)
  f01e66: 08 f2 00 0f 50 24        bset.b   #$f, $24(a2, d5.w)
  f01e6c: 52 2a 00 05              addq.b   #$1, $5(a2)
  f01e70: 52 6b 00 0a              addq.w   #$1, $a(a3)
  f01e74: 2d 6b 00 0c 01 20        move.l   $c(a3), $120(a6)

loc_F01E7A:
  f01e7a: 4e 73                    rte      

TRAP1_MOVEPL:
  f01e7c: 2c 2c 00 08              move.l   $8(a4), d6
  f01e80: 60 2a                    bra.b    $f01eac

TRAP1_MOVELL:
  f01e82: 22 2d 00 36              move.l   $36(a5), d1
  f01e86: 67 1c                    beq.b    $f01ea4
  f01e88: 2a 2c 00 18              move.l   $18(a4), d5
  f01e8c: 2c 2c 00 08              move.l   $8(a4), d6
  f01e90: 20 41                    movea.l  d1, a0
  f01e92: 61 00 f8 c4              bsr.w    $f01758
  f01e96: 60 14                    bra.b    $f01eac
  f01e98: 60 0a                    bra.b    $f01ea4
  f01e9a: 4a 85                    tst.l    d5
  f01e9c: 67 06                    beq.b    $f01ea4
  f01e9e: 4a 30 50 07              tst.b    $7(a0, d5.w)
  f01ea2: 66 08                    bne.b    $f01eac

loc_F01EA4:
  f01ea4: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f01eaa: 4e 73                    rte      

loc_F01EAC:
  f01eac: 2e 06                    move.l   d6, d7
  f01eae: 41 ec 00 0c              lea.l    $c(a4), a0
  f01eb2: 61 00 f8 5a              bsr.w    $f0170e
  f01eb6: 60 06                    bra.b    $f01ebe
  f01eb8: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f01ebc: 4e 73                    rte      

loc_F01EBE:
  f01ebe: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f01ec4: 66 10                    bne.b    $f01ed6
  f01ec6: 08 28 00 0f 00 28        btst.b   #$f, $28(a0)
  f01ecc: 67 08                    beq.b    $f01ed6
  f01ece: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f01ed4: 4e 73                    rte      

loc_F01ED6:
  f01ed6: 22 28 00 36              move.l   $36(a0), d1
  f01eda: 67 1c                    beq.b    $f01ef8
  f01edc: 2a 2c 00 18              move.l   $18(a4), d5
  f01ee0: 2c 2c 00 14              move.l   $14(a4), d6
  f01ee4: 20 41                    movea.l  d1, a0
  f01ee6: 61 00 f8 70              bsr.w    $f01758
  f01eea: 60 14                    bra.b    $f01f00
  f01eec: 60 0a                    bra.b    $f01ef8
  f01eee: 4a 85                    tst.l    d5
  f01ef0: 67 06                    beq.b    $f01ef8
  f01ef2: 4a 30 50 07              tst.b    $7(a0, d5.w)
  f01ef6: 66 08                    bne.b    $f01f00

loc_F01EF8:
  f01ef8: 06 6e 00 0d 01 02        addi.w   #$d, $102(a6)
  f01efe: 4e 73                    rte      

loc_F01F00:
  f01f00: 48 7a ff a2              pea.l    $f01ea4(pc)
  f01f04: 3f 3c 42 45              move.w   #$4245, -(a7)
  f01f08: 24 47                    movea.l  d7, a2
  f01f0a: 26 46                    movea.l  d6, a3
  f01f0c: 26 2c 00 18              move.l   $18(a4), d3
  f01f10: de 86                    add.l    d6, d7
  f01f12: 08 07 00 00              btst.b   #$0, d7
  f01f16: 67 08                    beq.b    $f01f20
  f01f18: 06 6e 00 0b 01 02        addi.w   #$b, $102(a6)
  f01f1e: 60 26                    bra.b    $f01f46

loc_F01F20:
  f01f20: 08 06 00 00              btst.b   #$0, d6
  f01f24: 67 06                    beq.b    $f01f2c
  f01f26: 16 da                    move.b   (a2)+, (a3)+
  f01f28: 53 83                    subq.l   #$1, d3
  f01f2a: 67 1a                    beq.b    $f01f46

loc_F01F2C:
  f01f2c: 28 03                    move.l   d3, d4
  f01f2e: e4 8b                    lsr.l    #$2, d3
  f01f30: 60 02                    bra.b    $f01f34

loc_F01F32:
  f01f32: 26 da                    move.l   (a2)+, (a3)+

loc_F01F34:
  f01f34: 51 cb ff fc              dbra     d3, $f01f32
  f01f38: 02 84 00 00 00 03        andi.l   #$3, d4
  f01f3e: 60 02                    bra.b    $f01f42

loc_F01F40:
  f01f40: 16 da                    move.b   (a2)+, (a3)+

loc_F01F42:
  f01f42: 51 cc ff fc              dbra     d4, $f01f40

loc_F01F46:
  f01f46: 5c 8f                    addq.l   #$6, a7
  f01f48: 4e 73                    rte      

TRAP1_DCLSHR:
  f01f4a: 2a 6e 00 36              movea.l  $36(a6), a5
  f01f4e: 2e 2c 00 0c              move.l   $c(a4), d7
  f01f52: 41 d5                    lea.l    (a5), a0
  f01f54: 61 00 f8 6e              bsr.w    $f017c4
  f01f58: 60 08                    bra.b    $f01f62
  f01f5a: 5e 6e 01 02              addq.w   #$7, $102(a6)

loc_F01F5E:
  f01f5e: 60 00 00 d2              bra.w    $f02032

loc_F01F62:
  f01f62: 3c 35 50 24              move.w   $24(a5, d5.w), d6
  f01f66: 30 06                    move.w   d6, d0
  f01f68: 02 40 30 00              andi.w   #$3000, d0
  f01f6c: 66 32                    bne.b    $f01fa0
  f01f6e: 32 2c 00 0a              move.w   $a(a4), d1
  f01f72: 02 41 30 00              andi.w   #$3000, d1
  f01f76: 67 20                    beq.b    $f01f98
  f01f78: 8c 41                    or.w     d1, d6
  f01f7a: 08 01 00 0c              btst.b   #$c, d1
  f01f7e: 67 26                    beq.b    $f01fa6
  f01f80: 08 01 00 0d              btst.b   #$d, d1
  f01f84: 66 12                    bne.b    $f01f98
  f01f86: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f01f8c: 66 18                    bne.b    $f01fa6
  f01f8e: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f01f94: 60 00 00 9c              bra.w    $f02032

loc_F01F98:
  f01f98: 06 6e 00 0f 01 02        addi.w   #$f, $102(a6)
  f01f9e: 60 be                    bra.b    $f01f5e

loc_F01FA0:
  f01fa0: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f01fa4: 60 b8                    bra.b    $f01f5e

loc_F01FA6:
  f01fa6: 08 2c 00 0f 00 08        btst.b   #$f, $8(a4)
  f01fac: 67 10                    beq.b    $f01fbe
  f01fae: 08 86 00 0e              bclr.b   #$e, d6
  f01fb2: 08 2c 00 0e 00 0a        btst.b   #$e, $a(a4)
  f01fb8: 67 04                    beq.b    $f01fbe
  f01fba: 08 c6 00 0e              bset.b   #$e, d6

loc_F01FBE:
  f01fbe: 22 06                    move.l   d6, d1
  f01fc0: 08 81 00 0f              bclr.b   #$f, d1
  f01fc4: 24 2e 00 14              move.l   $14(a6), d2
  f01fc8: 20 75 50 20              movea.l  $20(a5, d5.w), a0
  f01fcc: 61 00 f8 26              bsr.w    $f017f4
  f01fd0: 60 0e                    bra.b    $f01fe0
  f01fd2: b1 fc 00 00 00 00        cmpa.l   #$0, a0
  f01fd8: 66 0c                    bne.b    $f01fe6
  f01fda: 5a 6e 01 02              addq.w   #$5, $102(a6)
  f01fde: 60 52                    bra.b    $f02032

loc_F01FE0:
  f01fe0: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f01fe4: 60 4c                    bra.b    $f02032

loc_F01FE6:
  f01fe6: 8d 75 50 24              or.w     d6, $24(a5, d5.w)
  f01fea: 21 75 50 20 00 04        move.l   $20(a5, d5.w), $4(a0)
  f01ff0: 20 82                    move.l   d2, (a0)
  f01ff2: 31 41 00 08              move.w   d1, $8(a0)
  f01ff6: 31 7c 00 01 00 0a        move.w   #$1, $a(a0)
  f01ffc: 42 83                    clr.l    d3
  f01ffe: 36 35 50 00              move.w   (a5, d5.w), d3
  f02002: d6 75 50 04              add.w    $4(a5, d5.w), d3
  f02006: e1 8b                    lsl.l    #$8, d3
  f02008: 21 43 00 0c              move.l   d3, $c(a0)
  f0200c: 36 35 50 02              move.w   $2(a5, d5.w), d3
  f02010: 96 75 50 00              sub.w    (a5, d5.w), d3
  f02014: 52 43                    addq.w   #$1, d3
  f02016: 31 43 00 10              move.w   d3, $10(a0)
  f0201a: 33 40 00 0e              move.w   d0, $e(a1)
  f0201e: 31 7c 00 01 00 0a        move.w   #$1, $a(a0)
  f02024: 08 2c 00 0c 00 08        btst.b   #$c, $8(a4)
  f0202a: 67 06                    beq.b    $f02032
  f0202c: 08 e8 00 0f 00 0a        bset.b   #$f, $a(a0)

loc_F02032:
  f02032: 4e 73                    rte      

TRAP1_RCVSA:
  f02034: 3e 2c 00 08              move.w   $8(a4), d7
  f02038: 08 07 00 0d              btst.b   #$d, d7
  f0203c: 66 1c                    bne.b    $f0205a
  f0203e: 7a 12                    moveq    #$12, d5
  f02040: 2c 2c 00 18              move.l   $18(a4), d6
  f02044: 20 6e 00 36              movea.l  $36(a6), a0
  f02048: 61 00 f7 12              bsr.w    $f0175c
  f0204c: 60 0a                    bra.b    $f02058
  f0204e: 4e 71                    nop      
  f02050: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f02056: 4e 73                    rte      

loc_F02058:
  f02058: 24 46                    movea.l  d6, a2

loc_F0205A:
  f0205a: 08 2c 00 0e 00 08        btst.b   #$e, $8(a4)
  f02060: 67 22                    beq.b    $f02084
  f02062: 7a 04                    moveq    #$4, d5
  f02064: 2c 2c 00 10              move.l   $10(a4), d6
  f02068: 20 6d 00 36              movea.l  $36(a5), a0
  f0206c: 61 00 f6 ee              bsr.w    $f0175c
  f02070: 60 22                    bra.b    $f02094
  f02072: 60 0a                    bra.b    $f0207e
  f02074: 4a 45                    tst.w    d5
  f02076: 67 06                    beq.b    $f0207e
  f02078: 4a 30 d0 07              tst.b    $7(a0, a5.w)
  f0207c: 66 16                    bne.b    $f02094

loc_F0207E:
  f0207e: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f02082: 4e 73                    rte      

loc_F02084:
  f02084: 2e 2c 00 0c              move.l   $c(a4), d7
  f02088: 20 6d 00 36              movea.l  $36(a5), a0
  f0208c: 61 00 f7 36              bsr.w    $f017c4
  f02090: 60 02                    bra.b    $f02094
  f02092: 60 ea                    bra.b    $f0207e

loc_F02094:
  f02094: 42 80                    clr.l    d0
  f02096: 30 30 50 00              move.w   (a0, d5.w), d0
  f0209a: 08 2c 00 0d 00 08        btst.b   #$d, $8(a4)
  f020a0: 66 38                    bne.b    $f020da
  f020a2: d0 70 50 04              add.w    $4(a0, d5.w), d0
  f020a6: e1 88                    lsl.l    #$8, d0
  f020a8: 25 40 00 0e              move.l   d0, $e(a2)
  f020ac: 42 80                    clr.l    d0
  f020ae: 24 b0 50 20              move.l   $20(a0, d5.w), (a2)
  f020b2: 35 70 50 24 00 04        move.w   $24(a0, d5.w), $4(a2)
  f020b8: 08 aa 00 0f 00 04        bclr.b   #$f, $4(a2)
  f020be: 30 30 50 00              move.w   (a0, d5.w), d0
  f020c2: e1 88                    lsl.l    #$8, d0
  f020c4: 25 40 00 06              move.l   d0, $6(a2)
  f020c8: 42 80                    clr.l    d0
  f020ca: 30 30 50 02              move.w   $2(a0, d5.w), d0
  f020ce: e1 88                    lsl.l    #$8, d0
  f020d0: 06 00 00 ff              addi.b   #$ff, d0
  f020d4: 25 40 00 0a              move.l   d0, $a(a2)
  f020d8: 4e 73                    rte      

loc_F020DA:
  f020da: e1 88                    lsl.l    #$8, d0
  f020dc: 2d 40 01 20              move.l   d0, $120(a6)
  f020e0: 4e 73                    rte      

TRAP1_CISR:
  f020e2: 22 78 0c 66              movea.l  $c66.w, a1
  f020e6: 24 78 0c 6a              movea.l  $c6a.w, a2
  f020ea: 42 87                    clr.l    d7
  f020ec: 42 82                    clr.l    d2
  f020ee: 14 2c 00 0b              move.b   $b(a4), d2
  f020f2: 4a 6c 00 08              tst.w    $8(a4)
  f020f6: 66 00 00 84              bne.w    $f0217c
  f020fa: 4a 31 20 00              tst.b    (a1, d2.w)
  f020fe: 67 06                    beq.b    $f02106
  f02100: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f02104: 4e 73                    rte      

loc_F02106:
  f02106: 7e 08                    moveq    #$8, d7

loc_F02108:
  f02108: 47 f2 70 00              lea.l    (a2, d7.w), a3
  f0210c: b7 ea 00 04              cmpa.l   $4(a2), a3
  f02110: 6d 06                    blt.b    $f02118
  f02112: 5a 6e 01 02              addq.w   #$5, $102(a6)
  f02116: 4e 73                    rte      

loc_F02118:
  f02118: 4a ab 00 08              tst.l    $8(a3)
  f0211c: 67 08                    beq.b    $f02126
  f0211e: 06 87 00 00 00 14        addi.l   #$14, d7
  f02124: 60 e2                    bra.b    $f02108

loc_F02126:
  f02126: 36 fc 4e b9              move.w   #$4eb9, (a3)+
  f0212a: 41 fa e7 ce              lea.l    $f008fa(pc), a0
  f0212e: 26 c8                    move.l   a0, (a3)+

loc_F02130:
  f02130: 7a 04                    moveq    #$4, d5
  f02132: 2c 2c 00 0c              move.l   $c(a4), d6
  f02136: 20 6d 00 36              movea.l  $36(a5), a0
  f0213a: 61 00 f6 20              bsr.w    $f0175c
  f0213e: 60 0a                    bra.b    $f0214a
  f02140: 4e 71                    nop      
  f02142: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f02148: 4e 73                    rte      

loc_F0214A:
  f0214a: 36 82                    move.w   d2, (a3)
  f0214c: 27 4d 00 02              move.l   a5, $2(a3)
  f02150: 27 6c 00 0c 00 06        move.l   $c(a4), $6(a3)
  f02156: 27 6c 00 10 00 0a        move.l   $10(a4), $a(a3)
  f0215c: 06 87 00 00 00 0c        addi.l   #$c, d7
  f02162: 8e fc 00 14              divu.w   #$14, d7
  f02166: 13 87 20 00              move.b   d7, (a1, d2.w)
  f0216a: 08 ed 00 00 00 29        bset.b   #$0, $29(a5)
  f02170: 47 eb ff fa              lea.l    -$6(a3), a3
  f02174: e5 8a                    lsl.l    #$2, d2
  f02176: 20 42                    movea.l  d2, a0
  f02178: 20 8b                    move.l   a3, (a0)
  f0217a: 4e 73                    rte      

loc_F0217C:
  f0217c: 1e 31 20 00              move.b   (a1, d2.w), d7
  f02180: 67 22                    beq.b    $f021a4
  f02182: 53 87                    subq.l   #$1, d7
  f02184: ce fc 00 14              mulu.w   #$14, d7
  f02188: 50 87                    addq.l   #$8, d7
  f0218a: 47 f2 70 00              lea.l    (a2, d7.w), a3
  f0218e: 20 6b 00 08              movea.l  $8(a3), a0
  f02192: 20 28 00 14              move.l   $14(a0), d0
  f02196: b0 ae 00 14              cmp.l    $14(a6), d0
  f0219a: 67 10                    beq.b    $f021ac
  f0219c: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f021a2: 66 08                    bne.b    $f021ac

loc_F021A4:
  f021a4: 3d 7c 00 07 01 02        move.w   #$7, $102(a6)
  f021aa: 4e 73                    rte      

loc_F021AC:
  f021ac: 47 eb 00 06              lea.l    $6(a3), a3
  f021b0: 08 2c 00 06 00 08        btst.b   #$6, $8(a4)
  f021b6: 66 00 ff 78              bne.w    $f02130
  f021ba: 08 2c 00 05 00 08        btst.b   #$5, $8(a4)
  f021c0: 66 08                    bne.b    $f021ca
  f021c2: 3d 7c 00 0f 01 02        move.w   #$f, $102(a6)
  f021c8: 4e 73                    rte      

loc_F021CA:
  f021ca: 61 32                    bsr.b    $f021fe
  f021cc: 4e 73                    rte      

TRAP0_dir_1D_bsr:
  f021ce: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_1D:
  f021d0: 22 78 0c 66              movea.l  $c66.w, a1
  f021d4: 24 78 0c 6a              movea.l  $c6a.w, a2
  f021d8: 7e 08                    moveq    #$8, d7

loc_F021DA:
  f021da: 47 f2 70 00              lea.l    (a2, d7.w), a3
  f021de: b7 ea 00 04              cmpa.l   $4(a2), a3
  f021e2: 6c 18                    bge.b    $f021fc
  f021e4: b9 eb 00 08              cmpa.l   $8(a3), a4
  f021e8: 66 0a                    bne.b    $f021f4
  f021ea: 47 eb 00 06              lea.l    $6(a3), a3
  f021ee: 42 82                    clr.l    d2
  f021f0: 34 13                    move.w   (a3), d2
  f021f2: 61 0a                    bsr.b    $f021fe

loc_F021F4:
  f021f4: 06 87 00 00 00 14        addi.l   #$14, d7
  f021fa: 60 de                    bra.b    $f021da

loc_F021FC:
  f021fc: 4e 73                    rte      

loc_F021FE:
  f021fe: 41 fa e6 96              lea.l    $f00896(pc), a0
  f02202: 26 08                    move.l   a0, d3
  f02204: e5 8a                    lsl.l    #$2, d2
  f02206: 20 42                    movea.l  d2, a0
  f02208: 20 83                    move.l   d3, (a0)
  f0220a: e4 8a                    lsr.l    #$2, d2
  f0220c: 42 31 20 00              clr.b    (a1, d2.w)
  f02210: 42 ab 00 02              clr.l    $2(a3)
  f02214: 4e 75                    rts      

TRAP1_CNCTIRQ:
  f02216: 22 78 0c 66              movea.l  $c66.w, a1
  f0221a: 24 78 0c 6e              movea.l  $c6e.w, a2
  f0221e: 42 87                    clr.l    d7
  f02220: 42 82                    clr.l    d2
  f02222: 14 2c 00 0b              move.b   $b(a4), d2
  f02226: 4a 31 20 00              tst.b    (a1, d2.w)
  f0222a: 67 06                    beq.b    $f02232
  f0222c: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f02230: 4e 73                    rte      

loc_F02232:
  f02232: 7e 08                    moveq    #$8, d7

loc_F02234:
  f02234: 47 f2 70 00              lea.l    (a2, d7.w), a3
  f02238: b7 ea 00 04              cmpa.l   $4(a2), a3
  f0223c: 6d 06                    blt.b    $f02244
  f0223e: 5a 6e 01 02              addq.w   #$5, $102(a6)
  f02242: 4e 73                    rte      

loc_F02244:
  f02244: 4a ab 00 08              tst.l    $8(a3)
  f02248: 67 08                    beq.b    $f02252
  f0224a: 06 87 00 00 00 0e        addi.l   #$e, d7
  f02250: 60 e2                    bra.b    $f02234

loc_F02252:
  f02252: 36 82                    move.w   d2, (a3)
  f02254: 27 4e 00 02              move.l   a6, $2(a3)
  f02258: 27 6c 00 0c 00 06        move.l   $c(a4), $6(a3)
  f0225e: 27 6c 00 10 00 0a        move.l   $10(a4), $a(a3)
  f02264: 5c 87                    addq.l   #$6, d7
  f02266: 8e fc 00 0e              divu.w   #$e, d7
  f0226a: 13 87 20 00              move.b   d7, (a1, d2.w)
  f0226e: 08 ee 00 00 00 29        bset.b   #$0, $29(a6)
  f02274: e5 8a                    lsl.l    #$2, d2
  f02276: 20 42                    movea.l  d2, a0
  f02278: 20 ac 00 0c              move.l   $c(a4), (a0)
  f0227c: 4e 73                    rte      

TRAP1_SINT:
  f0227e: 42 82                    clr.l    d2
  f02280: 14 2c 00 03              move.b   $3(a4), d2
  f02284: 22 78 0c 66              movea.l  $c66.w, a1
  f02288: 4a 31 20 00              tst.b    (a1, d2.w)
  f0228c: 6e 08                    bgt.b    $f02296
  f0228e: 3d 7c 00 0e 01 02        move.w   #$e, $102(a6)
  f02294: 4e 73                    rte      

loc_F02296:
  f02296: 42 83                    clr.l    d3
  f02298: 16 2c 00 02              move.b   $2(a4), d3
  f0229c: 67 06                    beq.b    $f022a4
  f0229e: 0c 43 00 06              cmpi.w   #$6, d3
  f022a2: 6f 08                    ble.b    $f022ac

loc_F022A4:
  f022a4: 3d 7c 00 09 01 02        move.w   #$9, $102(a6)
  f022aa: 4e 73                    rte      

loc_F022AC:
  f022ac: e1 8b                    lsl.l    #$8, d3
  f022ae: 08 c3 00 0d              bset.b   #$d, d3
  f022b2: 48 7a 00 1c              pea.l    $f022d0(pc)
  f022b6: 40 e7                    move.w   sr, -(a7)
  f022b8: e5 8a                    lsl.l    #$2, d2
  f022ba: 20 42                    movea.l  d2, a0
  f022bc: 2f 10                    move.l   (a0), -(a7)
  f022be: 3f 03                    move.w   d3, -(a7)
  f022c0: 08 38 00 07 0c 35        btst.b   #$7, $c35.w
  f022c6: 67 06                    beq.b    $f022ce
  f022c8: 61 00 f3 be              bsr.w    $f01688
  f022cc: ee 07                    asr.b    #$7, d7

loc_F022CE:
  f022ce: 4e 73                    rte      
  f022d0: 08 38 00 07 0c 35        btst.b   #$7, $c35.w
  f022d6: 67 06                    beq.b    $f022de
  f022d8: 61 00 f3 ae              bsr.w    $f01688
  f022dc: dd 07                    addx.b   d7, d6

loc_F022DE:
  f022de: 4e 73                    rte      

TRAP1_CDIR:
  f022e0: 24 78 0c 28              movea.l  $c28.w, a2
  f022e4: 20 0a                    move.l   a2, d0
  f022e6: 67 54                    beq.b    $f0233c
  f022e8: 42 80                    clr.l    d0
  f022ea: 30 14                    move.w   (a4), d0
  f022ec: 6c 54                    bge.b    $f02342
  f022ee: 44 40                    neg.w    d0
  f022f0: b0 6a 00 04              cmp.w    $4(a2), d0
  f022f4: 6e 4c                    bgt.b    $f02342
  f022f6: 53 80                    subq.l   #$1, d0
  f022f8: c0 fc 00 0a              mulu.w   #$a, d0
  f022fc: 45 f2 00 06              lea.l    $6(a2, d0.w), a2
  f02300: 34 2c 00 02              move.w   $2(a4), d2
  f02304: 08 02 00 05              btst.b   #$5, d2
  f02308: 66 5e                    bne.b    $f02368
  f0230a: 4a aa 00 06              tst.l    $6(a2)
  f0230e: 66 38                    bne.b    $f02348
  f02310: 08 02 00 04              btst.b   #$4, d2
  f02314: 67 0c                    beq.b    $f02322
  f02316: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f0231c: 66 04                    bne.b    $f02322
  f0231e: 08 82 00 04              bclr.b   #$4, d2

loc_F02322:
  f02322: 7a 02                    moveq    #$2, d5
  f02324: 2c 2c 00 04              move.l   $4(a4), d6
  f02328: 20 6e 00 36              movea.l  $36(a6), a0
  f0232c: 61 00 f4 2e              bsr.w    $f0175c
  f02330: 60 24                    bra.b    $f02356
  f02332: 4e 71                    nop      
  f02334: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f0233a: 4e 73                    rte      

loc_F0233C:
  f0233c: 58 6e 01 02              addq.w   #$4, $102(a6)
  f02340: 4e 73                    rte      

loc_F02342:
  f02342: 5a 6e 01 02              addq.w   #$5, $102(a6)
  f02346: 4e 73                    rte      

loc_F02348:
  f02348: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f0234c: 4e 73                    rte      

loc_F0234E:
  f0234e: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f02354: 4e 73                    rte      

loc_F02356:
  f02356: 25 46 00 06              move.l   d6, $6(a2)
  f0235a: 02 42 00 f3              andi.w   #$f3, d2
  f0235e: 35 42 00 04              move.w   d2, $4(a2)
  f02362: 24 ae 00 14              move.l   $14(a6), (a2)
  f02366: 4e 73                    rte      

loc_F02368:
  f02368: 4a aa 00 06              tst.l    $6(a2)
  f0236c: 67 da                    beq.b    $f02348
  f0236e: 20 2e 00 14              move.l   $14(a6), d0
  f02372: b0 92                    cmp.l    (a2), d0
  f02374: 67 08                    beq.b    $f0237e
  f02376: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f0237c: 67 d0                    beq.b    $f0234e

loc_F0237E:
  f0237e: 42 aa 00 06              clr.l    $6(a2)
  f02382: 4e 73                    rte      

TRAP1_GTASQ:
  f02384: 4a ad 00 40              tst.l    $40(a5)
  f02388: 67 06                    beq.b    $f02390
  f0238a: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f0238e: 60 68                    bra.b    $f023f8

loc_F02390:
  f02390: 26 2c 00 0a              move.l   $a(a4), d3
  f02394: 06 83 00 00 00 ff        addi.l   #$ff, d3
  f0239a: e0 8b                    lsr.l    #$8, d3
  f0239c: 48 43                    swap     d3
  f0239e: 16 38 0c 72              move.b   $c72.w, d3
  f023a2: 48 43                    swap     d3
  f023a4: 20 43                    movea.l  d3, a0
  f023a6: 61 00 ee 96              bsr.w    $f0123e
  f023aa: 60 06                    bra.b    $f023b2
  f023ac: 50 6e 01 02              addq.w   #$8, $102(a6)
  f023b0: 60 46                    bra.b    $f023f8

loc_F023B2:
  f023b2: 26 48                    movea.l  a0, a3
  f023b4: 26 bc 21 41 53 51        move.l   #$21415351, (a3)
  f023ba: 17 6c 00 08 00 04        move.b   $8(a4), $4(a3)
  f023c0: 08 ab 00 0f 00 04        bclr.b   #$f, $4(a3)
  f023c6: 17 6c 00 09 00 05        move.b   $9(a4), $5(a3)
  f023cc: 27 6c 00 0e 00 06        move.l   $e(a4), $6(a3)
  f023d2: 27 6c 00 12 00 0a        move.l   $12(a4), $a(a3)
  f023d8: 41 eb 00 28              lea.l    $28(a3), a0
  f023dc: 27 48 00 16              move.l   a0, $16(a3)
  f023e0: 27 48 00 1e              move.l   a0, $1e(a3)
  f023e4: 27 48 00 22              move.l   a0, $22(a3)
  f023e8: e1 8a                    lsl.l    #$8, d2
  f023ea: d4 8b                    add.l    a3, d2
  f023ec: 27 42 00 1a              move.l   d2, $1a(a3)
  f023f0: 42 6b 00 26              clr.w    $26(a3)
  f023f4: 2b 4b 00 40              move.l   a3, $40(a5)

loc_F023F8:
  f023f8: 4e 73                    rte      

TRAP1_DEASQ:
  f023fa: 28 4e                    movea.l  a6, a4
  f023fc: 60 02                    bra.b    $f02400

TRAP0_dir_11_bsr:
  f023fe: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_11:
  f02400: 08 ac 00 05 00 2d        bclr.b   #$5, $2d(a4)
  f02406: 4a ac 00 40              tst.l    $40(a4)
  f0240a: 67 20                    beq.b    $f0242c
  f0240c: 20 6c 00 40              movea.l  $40(a4), a0
  f02410: 42 ac 00 40              clr.l    $40(a4)
  f02414: 22 28 00 1a              move.l   $1a(a0), d1
  f02418: 92 88                    sub.l    a0, d1
  f0241a: 06 81 00 00 00 ff        addi.l   #$ff, d1
  f02420: e0 81                    asr.l    #$8, d1
  f02422: 61 00 f0 70              bsr.w    $f01494
  f02426: 60 04                    bra.b    $f0242c
  f02428: 61 00 dd 5c              bsr.w    $f00186

loc_F0242C:
  f0242c: 4e 73                    rte      

TRAP1_QEVNT:
  f0242e: 26 4c                    movea.l  a4, a3
  f02430: 28 6d 00 40              movea.l  $40(a5), a4
  f02434: 20 0c                    move.l   a4, d0
  f02436: 66 08                    bne.b    $f02440
  f02438: 58 6e 01 02              addq.w   #$4, $102(a6)

loc_F0243C:
  f0243c: 60 00 00 de              bra.w    $f0251c

loc_F02440:
  f02440: 08 2c 00 08 00 04        btst.b   #$8, $4(a4)
  f02446: 66 08                    bne.b    $f02450
  f02448: 06 6e 00 0e 01 02        addi.w   #$e, $102(a6)
  f0244e: 60 ec                    bra.b    $f0243c

loc_F02450:
  f02450: 7a 02                    moveq    #$2, d5
  f02452: 2c 2b 00 0a              move.l   $a(a3), d6
  f02456: 20 6e 00 36              movea.l  $36(a6), a0
  f0245a: 61 00 f3 00              bsr.w    $f0175c
  f0245e: 60 0a                    bra.b    $f0246a
  f02460: 4e 71                    nop      

loc_F02462:
  f02462: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f02468: 60 d2                    bra.b    $f0243c

loc_F0246A:
  f0246a: 22 46                    movea.l  d6, a1
  f0246c: 42 81                    clr.l    d1
  f0246e: 12 19                    move.b   (a1)+, d1
  f02470: 2c 2b 00 0a              move.l   $a(a3), d6
  f02474: dc 81                    add.l    d1, d6
  f02476: e0 8e                    lsr.l    #$8, d6
  f02478: bc 70 50 02              cmp.w    $2(a0, d5.w), d6
  f0247c: 62 e4                    bhi.b    $f02462
  f0247e: 0c 81 00 00 00 03        cmpi.l   #$3, d1
  f02484: 63 36                    bls.b    $f024bc
  f02486: 42 85                    clr.l    d5
  f02488: 2c 01                    move.l   d1, d6
  f0248a: 42 87                    clr.l    d7
  f0248c: 1e 19                    move.b   (a1)+, d7
  f0248e: 02 07 00 7f              andi.b   #$7f, d7
  f02492: 0c 07 00 07              cmpi.b   #$7, d7
  f02496: 66 02                    bne.b    $f0249a
  f02498: 59 87                    subq.l   #$4, d7

loc_F0249A:
  f0249a: 08 2b 00 0f 00 08        btst.b   #$f, $8(a3)
  f024a0: 67 02                    beq.b    $f024a4
  f024a2: 58 81                    addq.l   #$4, d1

loc_F024A4:
  f024a4: 0c 87 00 00 00 03        cmpi.l   #$3, d7
  f024aa: 66 18                    bne.b    $f024c4
  f024ac: 50 86                    addq.l   #$8, d6
  f024ae: 50 81                    addq.l   #$8, d1
  f024b0: 50 85                    addq.l   #$8, d5
  f024b2: 42 80                    clr.l    d0
  f024b4: 10 2c 00 05              move.b   $5(a4), d0
  f024b8: bc 80                    cmp.l    d0, d6
  f024ba: 63 08                    bls.b    $f024c4

loc_F024BC:
  f024bc: 06 6e 00 10 01 02        addi.w   #$10, $102(a6)
  f024c2: 60 58                    bra.b    $f0251c

loc_F024C4:
  f024c4: 28 01                    move.l   d1, d4
  f024c6: 24 4b                    movea.l  a3, a2
  f024c8: 61 00 02 9a              bsr.w    $f02764
  f024cc: 60 06                    bra.b    $f024d4
  f024ce: 5a 6e 01 02              addq.w   #$5, $102(a6)
  f024d2: 60 48                    bra.b    $f0251c

loc_F024D4:
  f024d4: 28 6d 00 40              movea.l  $40(a5), a4
  f024d8: 20 4a                    movea.l  a2, a0
  f024da: 16 c4                    move.b   d4, (a3)+
  f024dc: 08 28 00 0f 00 08        btst.b   #$f, $8(a0)
  f024e2: 67 04                    beq.b    $f024e8
  f024e4: 08 c7 00 07              bset.b   #$7, d7

loc_F024E8:
  f024e8: 16 c7                    move.b   d7, (a3)+
  f024ea: 74 01                    moveq    #$1, d2
  f024ec: 55 84                    subq.l   #$2, d4
  f024ee: 61 30                    bsr.b    $f02520
  f024f0: 08 28 00 0f 00 08        btst.b   #$f, $8(a0)
  f024f6: 67 0a                    beq.b    $f02502
  f024f8: 74 04                    moveq    #$4, d2
  f024fa: 45 e8 00 0e              lea.l    $e(a0), a2
  f024fe: 61 1e                    bsr.b    $f0251e
  f02500: 59 84                    subq.l   #$4, d4

loc_F02502:
  f02502: 4a 85                    tst.l    d5
  f02504: 67 0a                    beq.b    $f02510
  f02506: 24 05                    move.l   d5, d2
  f02508: 45 ee 00 10              lea.l    $10(a6), a2
  f0250c: 61 10                    bsr.b    $f0251e
  f0250e: 51 84                    subq.l   #$8, d4

loc_F02510:
  f02510: 24 49                    movea.l  a1, a2
  f02512: 24 04                    move.l   d4, d2
  f02514: 67 02                    beq.b    $f02518
  f02516: 61 06                    bsr.b    $f0251e

loc_F02518:
  f02518: 61 00 01 8e              bsr.w    $f026a8

loc_F0251C:
  f0251c: 4e 73                    rte      

loc_F0251E:
  f0251e: 36 da                    move.w   (a2)+, (a3)+

loc_F02520:
  f02520: b7 ec 00 1a              cmpa.l   $1a(a4), a3
  f02524: 65 04                    bcs.b    $f0252a
  f02526: 26 6c 00 16              movea.l  $16(a4), a3

loc_F0252A:
  f0252a: 55 42                    subq.w   #$2, d2
  f0252c: 6e f0                    bgt.b    $f0251e
  f0252e: 4e 75                    rts      

TRAP1_RDEVNT:
  f02530: 28 6e 00 40              movea.l  $40(a6), a4
  f02534: 20 0c                    move.l   a4, d0
  f02536: 66 06                    bne.b    $f0253e
  f02538: 58 6e 01 02              addq.w   #$4, $102(a6)
  f0253c: 4e 73                    rte      

loc_F0253E:
  f0253e: 4a 6c 00 26              tst.w    $26(a4)
  f02542: 66 04                    bne.b    $f02548
  f02544: 7e 02                    moveq    #$2, d7
  f02546: 60 14                    bra.b    $f0255c

loc_F02548:
  f02548: 2a 6c 00 1e              movea.l  $1e(a4), a5
  f0254c: 42 87                    clr.l    d7
  f0254e: 1e 15                    move.b   (a5), d7
  f02550: 14 2d 00 01              move.b   $1(a5), d2
  f02554: 08 02 00 07              btst.b   #$7, d2
  f02558: 67 02                    beq.b    $f0255c
  f0255a: 59 87                    subq.l   #$4, d7

loc_F0255C:
  f0255c: 2a 07                    move.l   d7, d5
  f0255e: 2c 08                    move.l   a0, d6
  f02560: 20 6e 00 36              movea.l  $36(a6), a0
  f02564: 61 00 f1 f6              bsr.w    $f0175c
  f02568: 60 0a                    bra.b    $f02574
  f0256a: 4e 71                    nop      
  f0256c: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f02572: 4e 73                    rte      

loc_F02574:
  f02574: 26 46                    movea.l  d6, a3
  f02576: 0c 47 00 02              cmpi.w   #$2, d7
  f0257a: 66 04                    bne.b    $f02580
  f0257c: 42 53                    clr.w    (a3)
  f0257e: 4e 73                    rte      

loc_F02580:
  f02580: 54 8d                    addq.l   #$2, a5
  f02582: 08 82 00 07              bclr.b   #$7, d2
  f02586: 67 10                    beq.b    $f02598
  f02588: 58 8d                    addq.l   #$4, a5
  f0258a: bb ec 00 1a              cmpa.l   $1a(a4), a5
  f0258e: 65 08                    bcs.b    $f02598
  f02590: 9b ec 00 1a              suba.l   $1a(a4), a5
  f02594: db ec 00 16              adda.l   $16(a4), a5

loc_F02598:
  f02598: 16 c7                    move.b   d7, (a3)+
  f0259a: 16 c2                    move.b   d2, (a3)+
  f0259c: 6e 04                    bgt.b    $f025a2
  f0259e: 60 10                    bra.b    $f025b0

loc_F025A0:
  f025a0: 36 dd                    move.w   (a5)+, (a3)+

loc_F025A2:
  f025a2: bb ec 00 1a              cmpa.l   $1a(a4), a5
  f025a6: 65 04                    bcs.b    $f025ac
  f025a8: 2a 6c 00 16              movea.l  $16(a4), a5

loc_F025AC:
  f025ac: 55 47                    subq.w   #$2, d7
  f025ae: 6e f0                    bgt.b    $f025a0

loc_F025B0:
  f025b0: 2e 0d                    move.l   a5, d7
  f025b2: 52 87                    addq.l   #$1, d7
  f025b4: 08 87 00 00              bclr.b   #$0, d7
  f025b8: be ac 00 1a              cmp.l    $1a(a4), d7
  f025bc: 65 04                    bcs.b    $f025c2
  f025be: 2e 2c 00 16              move.l   $16(a4), d7

loc_F025C2:
  f025c2: 00 7c 07 00              ori.w    #$700, sr
  f025c6: 29 47 00 1e              move.l   d7, $1e(a4)
  f025ca: 53 6c 00 26              subq.w   #$1, $26(a4)
  f025ce: 46 d7                    move.w   (a7), sr
  f025d0: 26 46                    movea.l  d6, a3
  f025d2: 0c 02 00 07              cmpi.b   #$7, d2
  f025d6: 66 1e                    bne.b    $f025f6
  f025d8: 24 6b 00 04              movea.l  $4(a3), a2
  f025dc: 27 6a 00 10 00 04        move.l   $10(a2), $4(a3)
  f025e2: 4a 2b 00 17              tst.b    $17(a3)
  f025e6: 67 08                    beq.b    $f025f0
  f025e8: 08 2b 00 0e 00 02        btst.b   #$e, $2(a3)
  f025ee: 67 08                    beq.b    $f025f8

loc_F025F0:
  f025f0: 37 7c 03 00 00 16        move.w   #$300, $16(a3)

loc_F025F6:
  f025f6: 4e 73                    rte      

loc_F025F8:
  f025f8: 42 80                    clr.l    d0
  f025fa: 30 30 50 02              move.w   $2(a0, d5.w), d0
  f025fe: 52 40                    addq.w   #$1, d0
  f02600: d0 70 50 04              add.w    $4(a0, d5.w), d0
  f02604: e1 88                    lsl.l    #$8, d0
  f02606: 04 80 00 00 00 18        subi.l   #$18, d0
  f0260c: 90 8b                    sub.l    a3, d0
  f0260e: 42 87                    clr.l    d7
  f02610: 1e 2b 00 17              move.b   $17(a3), d7
  f02614: b0 87                    cmp.l    d7, d0
  f02616: 6c 0e                    bge.b    $f02626
  f02618: 2e 00                    move.l   d0, d7
  f0261a: 6f d4                    ble.b    $f025f0
  f0261c: 17 7c 00 01 00 16        move.b   #$1, $16(a3)
  f02622: 17 47 00 17              move.b   d7, $17(a3)

loc_F02626:
  f02626: 2a 07                    move.l   d7, d5
  f02628: 2c 2b 00 12              move.l   $12(a3), d6
  f0262c: 08 06 00 00              btst.b   #$0, d6
  f02630: 67 08                    beq.b    $f0263a

loc_F02632:
  f02632: 37 7c 02 00 00 16        move.w   #$200, $16(a3)
  f02638: 4e 73                    rte      

loc_F0263A:
  f0263a: 20 6a 00 36              movea.l  $36(a2), a0
  f0263e: 61 00 f1 1c              bsr.w    $f0175c
  f02642: 60 22                    bra.b    $f02666
  f02644: 60 02                    bra.b    $f02648
  f02646: 60 ea                    bra.b    $f02632

loc_F02648:
  f02648: e0 8e                    lsr.l    #$8, d6
  f0264a: dc 70 50 04              add.w    $4(a0, d5.w), d6
  f0264e: e1 8e                    lsl.l    #$8, d6
  f02650: dc 03                    add.b    d3, d6
  f02652: 3e 30 50 02              move.w   $2(a0, d5.w), d7
  f02656: 52 87                    addq.l   #$1, d7
  f02658: e1 8f                    lsl.l    #$8, d7
  f0265a: 9e 83                    sub.l    d3, d7
  f0265c: 17 7c 00 01 00 16        move.b   #$1, $16(a3)
  f02662: 17 47 00 17              move.b   d7, $17(a3)

loc_F02666:
  f02666: 42 87                    clr.l    d7
  f02668: 1e 2b 00 17              move.b   $17(a3), d7
  f0266c: 2a 46                    movea.l  d6, a5
  f0266e: 47 eb 00 18              lea.l    $18(a3), a3

loc_F02672:
  f02672: 36 dd                    move.w   (a5)+, (a3)+
  f02674: 55 87                    subq.l   #$2, d7
  f02676: 6e fa                    bgt.b    $f02672
  f02678: 4e 73                    rte      

TRAP1_SETASQ:
  f0267a: 28 6e 00 40              movea.l  $40(a6), a4
  f0267e: 20 0c                    move.l   a4, d0
  f02680: 66 06                    bne.b    $f02688
  f02682: 58 6e 01 02              addq.w   #$4, $102(a6)
  f02686: 60 1e                    bra.b    $f026a6

loc_F02688:
  f02688: 20 2e 01 20              move.l   $120(a6), d0
  f0268c: 02 00 00 07              andi.b   #$7, d0
  f02690: 02 2c 00 f8 00 04        andi.b   #$f8, $4(a4)
  f02696: 81 2c 00 04              or.b     d0, $4(a4)
  f0269a: 4a 6c 00 26              tst.w    $26(a4)
  f0269e: 67 06                    beq.b    $f026a6
  f026a0: 4b d6                    lea.l    (a6), a5
  f026a2: 61 00 00 04              bsr.w    $f026a8

loc_F026A6:
  f026a6: 4e 73                    rte      

TRAP0_dir_0A_bsr:
  f026a8: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_0A:
  f026aa: 08 2d 00 07 00 2d        btst.b   #$7, $2d(a5)
  f026b0: 66 00 00 b0              bne.w    $f02762
  f026b4: 08 2c 00 0a 00 04        btst.b   #$a, $4(a4)
  f026ba: 67 00 00 98              beq.w    $f02754
  f026be: 22 2c 00 06              move.l   $6(a4), d1
  f026c2: 20 6c 00 1e              movea.l  $1e(a4), a0
  f026c6: 10 28 00 01              move.b   $1(a0), d0
  f026ca: 08 00 00 07              btst.b   #$7, d0
  f026ce: 67 1c                    beq.b    $f026ec
  f026d0: 54 88                    addq.l   #$2, a0
  f026d2: b1 ec 00 1a              cmpa.l   $1a(a4), a0
  f026d6: 65 04                    bcs.b    $f026dc
  f026d8: 20 6c 00 16              movea.l  $16(a4), a0

loc_F026DC:
  f026dc: 22 10                    move.l   (a0), d1
  f026de: 54 88                    addq.l   #$2, a0
  f026e0: b1 ec 00 1a              cmpa.l   $1a(a4), a0
  f026e4: 65 06                    bcs.b    $f026ec
  f026e6: 20 6c 00 16              movea.l  $16(a4), a0
  f026ea: 32 10                    move.w   (a0), d1

loc_F026EC:
  f026ec: 4a 81                    tst.l    d1
  f026ee: 6b 4c                    bmi.b    $f0273c
  f026f0: 22 41                    movea.l  d1, a1
  f026f2: 7a 02                    moveq    #$2, d5
  f026f4: 2c 09                    move.l   a1, d6
  f026f6: 20 6d 00 36              movea.l  $36(a5), a0
  f026fa: 61 00 f0 60              bsr.w    $f0175c
  f026fe: 60 04                    bra.b    $f02704
  f02700: 4e 71                    nop      
  f02702: 60 38                    bra.b    $f0273c

loc_F02704:
  f02704: 29 49 00 12              move.l   a1, $12(a4)
  f02708: 2c 2d 01 3c              move.l   $13c(a5), d6
  f0270c: 7a 42                    moveq    #$42, d5
  f0270e: 08 2c 00 0b 00 04        btst.b   #$b, $4(a4)
  f02714: 67 02                    beq.b    $f02718
  f02716: 7a 06                    moveq    #$6, d5

loc_F02718:
  f02718: 2e 05                    move.l   d5, d7
  f0271a: 9c 85                    sub.l    d5, d6
  f0271c: 20 6d 00 36              movea.l  $36(a5), a0
  f02720: 61 00 f0 3a              bsr.w    $f0175c
  f02724: 60 04                    bra.b    $f0272a
  f02726: 4e 71                    nop      
  f02728: 60 12                    bra.b    $f0273c

loc_F0272A:
  f0272a: dc 87                    add.l    d7, d6
  f0272c: 29 46 00 0e              move.l   d6, $e(a4)
  f02730: 08 ac 00 0a 00 04        bclr.b   #$a, $4(a4)
  f02736: 08 ed 00 05 00 2d        bset.b   #$5, $2d(a5)

loc_F0273C:
  f0273c: 20 2d 00 58              move.l   $58(a5), d0
  f02740: 67 12                    beq.b    $f02754
  f02742: 20 40                    movea.l  d0, a0
  f02744: 42 a8 00 04              clr.l    $4(a0)
  f02748: 42 ad 00 58              clr.l    $58(a5)
  f0274c: 08 ad 00 0e 00 2c        bclr.b   #$e, $2c(a5)
  f02752: 60 08                    bra.b    $f0275c

loc_F02754:
  f02754: 08 ad 00 0c 00 2c        bclr.b   #$c, $2c(a5)
  f0275a: 67 06                    beq.b    $f02762

loc_F0275C:
  f0275c: 41 d5                    lea.l    (a5), a0
  f0275e: 61 00 e0 9c              bsr.w    $f007fc

loc_F02762:
  f02762: 4e 73                    rte      

TRAP0_dir_19_bsr:
  f02764: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_19:
  f02766: 42 80                    clr.l    d0
  f02768: 52 81                    addq.l   #$1, d1
  f0276a: 08 81 00 00              bclr.b   #$0, d1
  f0276e: 00 7c 07 00              ori.w    #$700, sr
  f02772: 26 6c 00 1e              movea.l  $1e(a4), a3
  f02776: 20 6c 00 22              movea.l  $22(a4), a0
  f0277a: 4a 6c 00 26              tst.w    $26(a4)
  f0277e: 66 0c                    bne.b    $f0278c
  f02780: 08 c0 00 01              bset.b   #$1, d0
  f02784: 26 48                    movea.l  a0, a3
  f02786: 29 48 00 1e              move.l   a0, $1e(a4)
  f0278a: 60 06                    bra.b    $f02792

loc_F0278C:
  f0278c: b7 c8                    cmpa.l   a0, a3
  f0278e: 67 2c                    beq.b    $f027bc
  f02790: 62 08                    bhi.b    $f0279a

loc_F02792:
  f02792: 97 ec 00 16              suba.l   $16(a4), a3
  f02796: d7 ec 00 1a              adda.l   $1a(a4), a3

loc_F0279A:
  f0279a: d1 c1                    adda.l   d1, a0
  f0279c: b1 cb                    cmpa.l   a3, a0
  f0279e: 62 1c                    bhi.b    $f027bc
  f027a0: b1 ec 00 1a              cmpa.l   $1a(a4), a0
  f027a4: 65 08                    bcs.b    $f027ae
  f027a6: 91 ec 00 1a              suba.l   $1a(a4), a0
  f027aa: d1 ec 00 16              adda.l   $16(a4), a0

loc_F027AE:
  f027ae: 26 6c 00 22              movea.l  $22(a4), a3
  f027b2: 29 48 00 22              move.l   a0, $22(a4)
  f027b6: 52 6c 00 26              addq.w   #$1, $26(a4)
  f027ba: 4e 73                    rte      

loc_F027BC:
  f027bc: 54 af 00 02              addq.l   #$2, $2(a7)
  f027c0: 4e 73                    rte      

TRAP1_RTEVNT:
  f027c2: 2a 48                    movea.l  a0, a5
  f027c4: 28 6e 00 40              movea.l  $40(a6), a4
  f027c8: 7a 42                    moveq    #$42, d5
  f027ca: 08 2c 00 0b 00 04        btst.b   #$b, $4(a4)
  f027d0: 67 02                    beq.b    $f027d4
  f027d2: 7a 06                    moveq    #$6, d5

loc_F027D4:
  f027d4: 2e 05                    move.l   d5, d7
  f027d6: 2c 2e 01 3c              move.l   $13c(a6), d6
  f027da: 20 6e 00 36              movea.l  $36(a6), a0
  f027de: 61 00 ef 7c              bsr.w    $f0175c
  f027e2: 60 0c                    bra.b    $f027f0
  f027e4: 4e 71                    nop      
  f027e6: 3e 3c 80 99              move.w   #$8099, d7
  f027ea: 41 d6                    lea.l    (a6), a0
  f027ec: 61 00 e0 36              bsr.w    $f00824

loc_F027F0:
  f027f0: df ae 01 3c              add.l    d7, $13c(a6)
  f027f4: 26 46                    movea.l  d6, a3
  f027f6: 08 2c 00 0b 00 04        btst.b   #$b, $4(a4)
  f027fc: 66 14                    bne.b    $f02812
  f027fe: 4c db 00 ff              movem.l  (a3)+, d0-d7
  f02802: 48 ee 00 ff 01 00        movem.l  d0-d7, $100(a6)
  f02808: 4c db 00 7f              movem.l  (a3)+, d0-d6
  f0280c: 48 ee 00 7f 01 20        movem.l  d0-d6, $120(a6)

loc_F02812:
  f02812: 32 1b                    move.w   (a3)+, d1
  f02814: 02 41 00 ff              andi.w   #$ff, d1
  f02818: 08 2f 00 0f 00 08        btst.b   #$f, $8(a7)
  f0281e: 67 04                    beq.b    $f02824
  f02820: 08 c1 00 0f              bset.b   #$f, d1

loc_F02824:
  f02824: 3d 41 00 fa              move.w   d1, $fa(a6)
  f02828: 2f 5b 00 0a              move.l   (a3)+, $a(a7)
  f0282c: 28 6e 00 40              movea.l  $40(a6), a4
  f02830: 20 0c                    move.l   a4, d0
  f02832: 67 1a                    beq.b    $f0284e
  f02834: 20 0d                    move.l   a5, d0
  f02836: 08 00 00 00              btst.b   #$0, d0
  f0283a: 67 06                    beq.b    $f02842
  f0283c: 08 ec 00 0a 00 04        bset.b   #$a, $4(a4)

loc_F02842:
  f02842: 4a 6c 00 26              tst.w    $26(a4)
  f02846: 67 06                    beq.b    $f0284e
  f02848: 4b d6                    lea.l    (a6), a5
  f0284a: 61 00 fe 5c              bsr.w    $f026a8

loc_F0284E:
  f0284e: 4e 73                    rte      

TRAP1_WTEVNT:
  f02850: 28 6e 00 40              movea.l  $40(a6), a4
  f02854: 20 0c                    move.l   a4, d0
  f02856: 66 06                    bne.b    $f0285e
  f02858: 58 6e 01 02              addq.w   #$4, $102(a6)
  f0285c: 60 34                    bra.b    $f02892

loc_F0285E:
  f0285e: 08 ee 00 0c 00 2c        bset.b   #$c, $2c(a6)
  f02864: 08 2e 00 05 00 2d        btst.b   #$5, $2d(a6)
  f0286a: 67 0e                    beq.b    $f0287a
  f0286c: 08 ae 00 0c 00 2c        bclr.b   #$c, $2c(a6)
  f02872: 41 d6                    lea.l    (a6), a0
  f02874: 61 00 df 86              bsr.w    $f007fc
  f02878: 60 18                    bra.b    $f02892

loc_F0287A:
  f0287a: 08 ec 00 08 00 04        bset.b   #$8, $4(a4)
  f02880: 08 ec 00 0a 00 04        bset.b   #$a, $4(a4)
  f02886: 4a 6c 00 26              tst.w    $26(a4)
  f0288a: 67 06                    beq.b    $f02892
  f0288c: 4b d6                    lea.l    (a6), a5
  f0288e: 61 00 fe 18              bsr.w    $f026a8

loc_F02892:
  f02892: 4e 73                    rte      

TRAP0_T0CRTCB:
  f02894: 49 eb ff fe              lea.l    -$2(a3), a4
  f02898: 36 3c 80 01              move.w   #$8001, d3
  f0289c: 60 14                    bra.b    $f028b2

TRAP1_CRTCB:
  f0289e: 26 4c                    movea.l  a4, a3
  f028a0: 4c ec 00 70 00 12        movem.l  $12(a4), d4-d6
  f028a6: 48 46                    swap     d6
  f028a8: 3e 2c 00 08              move.w   $8(a4), d7
  f028ac: 36 2e 00 28              move.w   $28(a6), d3
  f028b0: 42 03                    clr.b    d3

loc_F028B2:
  f028b2: 41 d3                    lea.l    (a3), a0
  f028b4: 61 00 ee 58              bsr.w    $f0170e
  f028b8: 60 02                    bra.b    $f028bc
  f028ba: 60 08                    bra.b    $f028c4

loc_F028BC:
  f028bc: 30 3c 00 06              move.w   #$6, d0
  f028c0: 60 00 01 20              bra.w    $f029e2

loc_F028C4:
  f028c4: 42 80                    clr.l    d0
  f028c6: 10 38 0c 73              move.b   $c73.w, d0
  f028ca: 48 40                    swap     d0
  f028cc: 30 3c 00 02              move.w   #$2, d0
  f028d0: 20 40                    movea.l  d0, a0
  f028d2: 61 00 e9 6a              bsr.w    $f0123e
  f028d6: 60 08                    bra.b    $f028e0
  f028d8: 30 3c 00 08              move.w   #$8, d0
  f028dc: 60 00 01 04              bra.w    $f029e2

loc_F028E0:
  f028e0: 2a 48                    movea.l  a0, a5
  f028e2: 34 3c 00 7f              move.w   #$7f, d2

loc_F028E6:
  f028e6: 42 98                    clr.l    (a0)+
  f028e8: 51 ca ff fc              dbra     d2, $f028e6
  f028ec: 2b 53 00 10              move.l   (a3), $10(a5)
  f028f0: 20 2b 00 04              move.l   $4(a3), d0
  f028f4: 08 03 00 00              btst.b   #$0, d3
  f028f8: 66 14                    bne.b    $f0290e
  f028fa: 08 03 00 0f              btst.b   #$f, d3
  f028fe: 67 06                    beq.b    $f02906
  f02900: 4a 80                    tst.l    d0
  f02902: 66 0a                    bne.b    $f0290e
  f02904: 60 04                    bra.b    $f0290a

loc_F02906:
  f02906: 3c 2e 00 70              move.w   $70(a6), d6

loc_F0290A:
  f0290a: 20 2e 00 14              move.l   $14(a6), d0

loc_F0290E:
  f0290e: 3b 46 00 70              move.w   d6, $70(a5)
  f02912: 2b 40 00 14              move.l   d0, $14(a5)
  f02916: 61 00 00 dc              bsr.w    $f029f4
  f0291a: 42 04                    clr.b    d4
  f0291c: 08 03 00 0f              btst.b   #$f, d3
  f02920: 66 04                    bne.b    $f02926
  f02922: 02 44 1f ff              andi.w   #$1fff, d4

loc_F02926:
  f02926: 3b 44 00 28              move.w   d4, $28(a5)
  f0292a: 2b 45 00 6c              move.l   d5, $6c(a5)
  f0292e: 2b 45 00 fc              move.l   d5, $fc(a5)
  f02932: 48 44                    swap     d4
  f02934: 30 04                    move.w   d4, d0
  f02936: e0 48                    lsr.w    #$8, d0
  f02938: 67 10                    beq.b    $f0294a
  f0293a: 08 03 00 00              btst.b   #$0, d3
  f0293e: 66 0e                    bne.b    $f0294e
  f02940: 4a 04                    tst.b    d4
  f02942: 67 06                    beq.b    $f0294a
  f02944: b8 2e 00 25              cmp.b    $25(a6), d4
  f02948: 63 04                    bls.b    $f0294e

loc_F0294A:
  f0294a: 18 2e 00 25              move.b   $25(a6), d4

loc_F0294E:
  f0294e: 1b 44 00 25              move.b   d4, $25(a5)
  f02952: b0 04                    cmp.b    d4, d0
  f02954: 63 02                    bls.b    $f02958
  f02956: 10 04                    move.b   d4, d0

loc_F02958:
  f02958: 1b 40 00 24              move.b   d0, $24(a5)
  f0295c: 1b 40 00 26              move.b   d0, $26(a5)
  f02960: 2a bc 21 54 43 42        move.l   #$21544342, (a5)
  f02966: 1b 7c 00 80 00 2c        move.b   #$80, $2c(a5)
  f0296c: 3b 7c 00 01 00 3a        move.w   #$1, $3a(a5)
  f02972: 1b 7c 00 fa 00 72        move.b   #$fa, $72(a5)
  f02978: 3b 7c 00 01 00 30        move.w   #$1, $30(a5)
  f0297e: 24 4d                    movea.l  a5, a2
  f02980: d5 fc 00 00 01 60        adda.l   #$160, a2
  f02986: 2b 4a 00 36              move.l   a2, $36(a5)
  f0298a: 24 bc 21 54 53 54        move.l   #$21545354, (a2)
  f02990: 15 7c 00 04 00 04        move.b   #$4, $4(a2)
  f02996: 35 7c 00 24 00 06        move.w   #$24, $6(a2)
  f0299c: 35 7c 00 44 00 08        move.w   #$44, $8(a2)
  f029a2: 20 78 0c 10              movea.l  $c10.w, a0
  f029a6: 20 2d 00 10              move.l   $10(a5), d0
  f029aa: 22 2d 00 14              move.l   $14(a5), d1

loc_F029AE:
  f029ae: b1 fc 00 00 00 00        cmpa.l   #$0, a0
  f029b4: 67 20                    beq.b    $f029d6
  f029b6: b0 a8 00 10              cmp.l    $10(a0), d0
  f029ba: 66 06                    bne.b    $f029c2
  f029bc: b2 a8 00 14              cmp.l    $14(a0), d1
  f029c0: 67 06                    beq.b    $f029c8

loc_F029C2:
  f029c2: 20 68 00 04              movea.l  $4(a0), a0
  f029c6: 60 e6                    bra.b    $f029ae

loc_F029C8:
  f029c8: 72 02                    moveq    #$2, d1
  f029ca: 41 d5                    lea.l    (a5), a0
  f029cc: 61 00 ea c6              bsr.w    $f01494
  f029d0: 30 3c 00 06              move.w   #$6, d0
  f029d4: 60 0c                    bra.b    $f029e2

loc_F029D6:
  f029d6: 2b 78 0c 10 00 04        move.l   $c10.w, $4(a5)
  f029dc: 21 cd 0c 10              move.l   a5, $c10.w
  f029e0: 4e 73                    rte      

loc_F029E2:
  f029e2: 08 03 00 00              btst.b   #$0, d3
  f029e6: 66 06                    bne.b    $f029ee
  f029e8: 3d 40 01 02              move.w   d0, $102(a6)
  f029ec: 4e 73                    rte      

loc_F029EE:
  f029ee: 54 af 00 02              addq.l   #$2, $2(a7)
  f029f2: 4e 73                    rte      

loc_F029F4:
  f029f4: 08 07 00 0f              btst.b   #$f, d7
  f029f8: 66 10                    bne.b    $f02a0a
  f029fa: 08 07 00 0e              btst.b   #$e, d7
  f029fe: 67 32                    beq.b    $f02a32
  f02a00: 20 2e 00 18              move.l   $18(a6), d0
  f02a04: 22 2e 00 1c              move.l   $1c(a6), d1
  f02a08: 60 20                    bra.b    $f02a2a

loc_F02A0A:
  f02a0a: 22 2c 00 0e              move.l   $e(a4), d1
  f02a0e: 20 2c 00 0a              move.l   $a(a4), d0
  f02a12: 67 0e                    beq.b    $f02a22
  f02a14: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f02a1a: 67 0a                    beq.b    $f02a26
  f02a1c: 4a 81                    tst.l    d1
  f02a1e: 67 06                    beq.b    $f02a26
  f02a20: 60 08                    bra.b    $f02a2a

loc_F02A22:
  f02a22: 20 2e 00 10              move.l   $10(a6), d0

loc_F02A26:
  f02a26: 22 2e 00 14              move.l   $14(a6), d1

loc_F02A2A:
  f02a2a: 2b 40 00 18              move.l   d0, $18(a5)
  f02a2e: 2b 41 00 1c              move.l   d1, $1c(a5)

loc_F02A32:
  f02a32: 4e 75                    rts      

TRAP1_START:
  f02a34: 08 2c 00 0d 00 08        btst.b   #$d, $8(a4)
  f02a3a: 67 04                    beq.b    $f02a40
  f02a3c: 7a 52                    moveq    #$52, d5
  f02a3e: 60 0a                    bra.b    $f02a4a

loc_F02A40:
  f02a40: 08 2c 00 0f 00 08        btst.b   #$f, $8(a4)
  f02a46: 67 18                    beq.b    $f02a60
  f02a48: 7a 12                    moveq    #$12, d5

loc_F02A4A:
  f02a4a: 2c 2e 01 20              move.l   $120(a6), d6
  f02a4e: 20 6e 00 36              movea.l  $36(a6), a0
  f02a52: 61 00 ed 08              bsr.w    $f0175c
  f02a56: 60 08                    bra.b    $f02a60
  f02a58: 4e 71                    nop      
  f02a5a: 54 6e 01 02              addq.w   #$2, $102(a6)
  f02a5e: 4e 73                    rte      

loc_F02A60:
  f02a60: 4a 94                    tst.l    (a4)
  f02a62: 66 36                    bne.b    $f02a9a
  f02a64: 22 2e 00 14              move.l   $14(a6), d1
  f02a68: 2a 79 00 00 0c 10        movea.l  $c10.l, a5

loc_F02A6E:
  f02a6e: bb fc 00 00 00 00        cmpa.l   #$0, a5
  f02a74: 67 2c                    beq.b    $f02aa2
  f02a76: b2 ad 00 14              cmp.l    $14(a5), d1
  f02a7a: 66 18                    bne.b    $f02a94
  f02a7c: 08 2d 00 0f 00 28        btst.b   #$f, $28(a5)
  f02a82: 66 10                    bne.b    $f02a94
  f02a84: 08 2d 00 0f 00 2c        btst.b   #$f, $2c(a5)
  f02a8a: 67 08                    beq.b    $f02a94
  f02a8c: 08 2d 00 0f 00 2e        btst.b   #$f, $2e(a5)
  f02a92: 66 44                    bne.b    $f02ad8

loc_F02A94:
  f02a94: 2a 6d 00 04              movea.l  $4(a5), a5
  f02a98: 60 d4                    bra.b    $f02a6e

loc_F02A9A:
  f02a9a: 41 d4                    lea.l    (a4), a0
  f02a9c: 61 00 ec 70              bsr.w    $f0170e
  f02aa0: 60 0a                    bra.b    $f02aac

loc_F02AA2:
  f02aa2: 42 ae 01 20              clr.l    $120(a6)
  f02aa6: 56 6e 01 02              addq.w   #$3, $102(a6)
  f02aaa: 4e 73                    rte      

loc_F02AAC:
  f02aac: 2a 48                    movea.l  a0, a5
  f02aae: bd cd                    cmpa.l   a5, a6
  f02ab0: 67 10                    beq.b    $f02ac2
  f02ab2: 08 2d 00 0f 00 28        btst.b   #$f, $28(a5)
  f02ab8: 67 10                    beq.b    $f02aca
  f02aba: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f02ac0: 66 08                    bne.b    $f02aca

loc_F02AC2:
  f02ac2: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f02ac8: 4e 73                    rte      

loc_F02ACA:
  f02aca: 08 2d 00 0f 00 2c        btst.b   #$f, $2c(a5)
  f02ad0: 66 0c                    bne.b    $f02ade
  f02ad2: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f02ad6: 4e 73                    rte      

loc_F02AD8:
  f02ad8: 2d 6d 00 10 01 20        move.l   $10(a5), $120(a6)

loc_F02ADE:
  f02ade: 08 2d 00 0f 00 2e        btst.b   #$f, $2e(a5)
  f02ae4: 66 5e                    bne.b    $f02b44
  f02ae6: 3e 2c 00 08              move.w   $8(a4), d7
  f02aea: 61 00 ff 08              bsr.w    $f029f4
  f02aee: 2b 6d 00 6c 00 fc        move.l   $6c(a5), $fc(a5)
  f02af4: 1b 7c 00 fa 00 72        move.b   #$fa, $72(a5)
  f02afa: 08 2d 00 0b 00 28        btst.b   #$b, $28(a5)
  f02b00: 67 42                    beq.b    $f02b44
  f02b02: 7a 02                    moveq    #$2, d5
  f02b04: 2c 2d 00 fc              move.l   $fc(a5), d6
  f02b08: 20 6d 00 36              movea.l  $36(a5), a0
  f02b0c: 61 00 ec 4e              bsr.w    $f0175c
  f02b10: 60 0a                    bra.b    $f02b1c
  f02b12: 4e 71                    nop      
  f02b14: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f02b1a: 4e 73                    rte      

loc_F02B1C:
  f02b1c: 2b 46 00 fc              move.l   d6, $fc(a5)
  f02b20: 3a 28 00 06              move.w   $6(a0), d5

loc_F02B24:
  f02b24: 08 30 00 0f 50 24        btst.b   #$f, $24(a0, d5.w)
  f02b2a: 67 10                    beq.b    $f02b3c
  f02b2c: 30 30 50 04              move.w   $4(a0, d5.w), d0
  f02b30: d1 70 50 00              add.w    d0, (a0, d5.w)
  f02b34: d1 70 50 02              add.w    d0, $2(a0, d5.w)
  f02b38: 42 70 50 04              clr.w    $4(a0, d5.w)

loc_F02B3C:
  f02b3c: 51 85                    subq.l   #$8, d5
  f02b3e: 0c 45 00 0c              cmpi.w   #$c, d5
  f02b42: 6c e0                    bge.b    $f02b24

loc_F02B44:
  f02b44: 42 6d 00 2e              clr.w    $2e(a5)
  f02b48: 08 2c 00 0d 00 08        btst.b   #$d, $8(a4)
  f02b4e: 67 18                    beq.b    $f02b68
  f02b50: 47 ec 00 12              lea.l    $12(a4), a3
  f02b54: 4c db 00 ff              movem.l  (a3)+, d0-d7
  f02b58: 48 ed 00 ff 01 00        movem.l  d0-d7, $100(a5)
  f02b5e: 4c db 00 7f              movem.l  (a3)+, d0-d6
  f02b62: 48 ed 00 7f 01 20        movem.l  d0-d6, $120(a5)

loc_F02B68:
  f02b68: 00 7c 07 00              ori.w    #$700, sr
  f02b6c: 08 ad 00 0f 00 2c        bclr.b   #$f, $2c(a5)
  f02b72: 30 2d 00 2c              move.w   $2c(a5), d0
  f02b76: 02 40 df 00              andi.w   #$df00, d0
  f02b7a: 66 08                    bne.b    $f02b84
  f02b7c: 46 d7                    move.w   (a7), sr
  f02b7e: 41 d5                    lea.l    (a5), a0
  f02b80: 61 00 dc 7a              bsr.w    $f007fc

loc_F02B84:
  f02b84: 4e 73                    rte      

TRAP1_STOP:
  f02b86: 20 46                    movea.l  d6, a0
  f02b88: 4a 90                    tst.l    (a0)
  f02b8a: 66 38                    bne.b    $f02bc4
  f02b8c: 22 2e 00 14              move.l   $14(a6), d1
  f02b90: 2a 78 0c 10              movea.l  $c10.w, a5

loc_F02B94:
  f02b94: bb fc 00 00 00 00        cmpa.l   #$0, a5
  f02b9a: 67 2e                    beq.b    $f02bca
  f02b9c: b2 ad 00 14              cmp.l    $14(a5), d1
  f02ba0: 66 1c                    bne.b    $f02bbe
  f02ba2: 08 2d 00 0f 00 28        btst.b   #$f, $28(a5)
  f02ba8: 66 14                    bne.b    $f02bbe
  f02baa: bd cd                    cmpa.l   a5, a6
  f02bac: 67 10                    beq.b    $f02bbe
  f02bae: 08 2d 00 07 00 2d        btst.b   #$7, $2d(a5)
  f02bb4: 66 08                    bne.b    $f02bbe
  f02bb6: 08 ed 00 0f 00 2c        bset.b   #$f, $2c(a5)
  f02bbc: 67 4a                    beq.b    $f02c08

loc_F02BBE:
  f02bbe: 2a 6d 00 04              movea.l  $4(a5), a5
  f02bc2: 60 d0                    bra.b    $f02b94

loc_F02BC4:
  f02bc4: 61 00 eb 48              bsr.w    $f0170e
  f02bc8: 60 0a                    bra.b    $f02bd4

loc_F02BCA:
  f02bca: 42 ae 01 20              clr.l    $120(a6)
  f02bce: 56 6e 01 02              addq.w   #$3, $102(a6)
  f02bd2: 4e 73                    rte      

loc_F02BD4:
  f02bd4: 2a 48                    movea.l  a0, a5
  f02bd6: 08 2d 00 07 00 2d        btst.b   #$7, $2d(a5)
  f02bdc: 66 ec                    bne.b    $f02bca
  f02bde: bd cd                    cmpa.l   a5, a6
  f02be0: 67 10                    beq.b    $f02bf2
  f02be2: 08 2d 00 0f 00 28        btst.b   #$f, $28(a5)
  f02be8: 67 10                    beq.b    $f02bfa
  f02bea: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f02bf0: 66 08                    bne.b    $f02bfa

loc_F02BF2:
  f02bf2: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f02bf8: 4e 73                    rte      

loc_F02BFA:
  f02bfa: 08 ed 00 0f 00 2c        bset.b   #$f, $2c(a5)
  f02c00: 67 06                    beq.b    $f02c08
  f02c02: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f02c06: 4e 73                    rte      

loc_F02C08:
  f02c08: 3b 6d 00 2c 00 2e        move.w   $2c(a5), $2e(a5)
  f02c0e: 2d 6d 00 10 01 20        move.l   $10(a5), $120(a6)
  f02c14: 00 7c 07 00              ori.w    #$700, sr
  f02c18: 08 ad 00 04 00 2d        bclr.b   #$4, $2d(a5)
  f02c1e: 67 1c                    beq.b    $f02c3c
  f02c20: 43 f8 0c 08              lea.l    $c08.w, a1

loc_F02C24:
  f02c24: 20 49                    movea.l  a1, a0
  f02c26: 22 68 00 0c              movea.l  $c(a0), a1
  f02c2a: b3 fc 00 00 00 00        cmpa.l   #$0, a1
  f02c30: 67 0a                    beq.b    $f02c3c
  f02c32: b3 cd                    cmpa.l   a5, a1
  f02c34: 66 ee                    bne.b    $f02c24
  f02c36: 21 69 00 0c 00 0c        move.l   $c(a1), $c(a0)

loc_F02C3C:
  f02c3c: 4e 73                    rte      

TRAP1_WAIT:
  f02c3e: 08 ee 00 0e 00 2c        bset.b   #$e, $2c(a6)
  f02c44: 08 ae 00 03 00 2d        bclr.b   #$3, $2d(a6)
  f02c4a: 66 02                    bne.b    $f02c4e
  f02c4c: 4e 73                    rte      

loc_F02C4E:
  f02c4e: 08 ae 00 0e 00 2c        bclr.b   #$e, $2c(a6)
  f02c54: 3d 6e 00 5e 01 02        move.w   $5e(a6), $102(a6)
  f02c5a: 42 6e 00 5e              clr.w    $5e(a6)
  f02c5e: 41 d6                    lea.l    (a6), a0
  f02c60: 61 00 db 9a              bsr.w    $f007fc
  f02c64: 4e 73                    rte      

TRAP1_WAKEUP:
  f02c66: bb ce                    cmpa.l   a6, a5
  f02c68: 60 00 00 0a              bra.w    $f02c74

TRAP0_T0WAKEUP_bsr:
  f02c6c: 40 e7                    move.w   sr, -(a7)

TRAP0_T0WAKEUP:
  f02c6e: 08 f8 00 07 0c 5b        bset.b   #$7, $c5b.w

loc_F02C74:
  f02c74: 08 a8 00 0e 00 2c        bclr.b   #$e, $2c(a0)
  f02c7a: 67 28                    beq.b    $f02ca4
  f02c7c: 20 28 00 58              move.l   $58(a0), d0
  f02c80: 67 0a                    beq.b    $f02c8c
  f02c82: 22 40                    movea.l  d0, a1
  f02c84: 42 a9 00 04              clr.l    $4(a1)
  f02c88: 42 a8 00 58              clr.l    $58(a0)

loc_F02C8C:
  f02c8c: 31 68 00 5e 01 02        move.w   $5e(a0), $102(a0)
  f02c92: 67 0a                    beq.b    $f02c9e
  f02c94: 31 7c 08 13 01 00        move.w   #$813, $100(a0)
  f02c9a: 42 68 00 5e              clr.w    $5e(a0)

loc_F02C9E:
  f02c9e: 61 00 db 5c              bsr.w    $f007fc
  f02ca2: 4e 73                    rte      

loc_F02CA4:
  f02ca4: 08 e8 00 03 00 2d        bset.b   #$3, $2d(a0)
  f02caa: 4e 73                    rte      

TRAP1_SUSPND:
  f02cac: 08 ee 00 09 00 2c        bset.b   #$9, $2c(a6)
  f02cb2: 4e 73                    rte      

TRAP1_RESUME:
  f02cb4: 08 a8 00 09 00 2c        bclr.b   #$9, $2c(a0)
  f02cba: 66 08                    bne.b    $f02cc4
  f02cbc: 06 6e 00 0a 01 02        addi.w   #$a, $102(a6)
  f02cc2: 4e 73                    rte      

loc_F02CC4:
  f02cc4: 61 00 da fa              bsr.w    $f007c0
  f02cc8: 4e 73                    rte      

TRAP1_DELAYW:
  f02cca: 7e 01                    moveq    #$1, d7
  f02ccc: 60 02                    bra.b    $f02cd0

TRAP1_DELAY:
  f02cce: 42 87                    clr.l    d7

loc_F02CD0:
  f02cd0: 24 08                    move.l   a0, d2
  f02cd2: 0c 82 05 26 5c 00        cmpi.l   #$5265c00, d2
  f02cd8: 63 06                    bls.b    $f02ce0
  f02cda: 24 3c 05 26 5c 00        move.l   #$5265c00, d2

loc_F02CE0:
  f02ce0: 61 00 e2 b4              bsr.w    $f00f96
  f02ce4: d4 81                    add.l    d1, d2
  f02ce6: 22 78 0c 2c              movea.l  $c2c.w, a1
  f02cea: 45 e9 00 08              lea.l    $8(a1), a2

loc_F02CEE:
  f02cee: 26 4a                    movea.l  a2, a3

loc_F02CF0:
  f02cf0: 20 13                    move.l   (a3), d0
  f02cf2: 67 1c                    beq.b    $f02d10
  f02cf4: 24 40                    movea.l  d0, a2
  f02cf6: 4a aa 00 04              tst.l    $4(a2)
  f02cfa: 67 0c                    beq.b    $f02d08
  f02cfc: bd ea 00 04              cmpa.l   $4(a2), a6
  f02d00: 66 ec                    bne.b    $f02cee
  f02d02: 4a aa 00 16              tst.l    $16(a2)
  f02d06: 66 e6                    bne.b    $f02cee

loc_F02D08:
  f02d08: 26 92                    move.l   (a2), (a3)
  f02d0a: 61 00 e3 e4              bsr.w    $f010f0
  f02d0e: 60 e0                    bra.b    $f02cf0

loc_F02D10:
  f02d10: 20 2e 00 40              move.l   $40(a6), d0
  f02d14: 67 46                    beq.b    $f02d5c
  f02d16: 28 40                    movea.l  d0, a4
  f02d18: 00 7c 07 00              ori.w    #$700, sr
  f02d1c: 4a 47                    tst.w    d7
  f02d1e: 67 0c                    beq.b    $f02d2c
  f02d20: 08 ec 00 08 00 04        bset.b   #$8, $4(a4)
  f02d26: 08 ec 00 0a 00 04        bset.b   #$a, $4(a4)

loc_F02D2C:
  f02d2c: 08 2e 00 05 00 2d        btst.b   #$5, $2d(a6)
  f02d32: 67 10                    beq.b    $f02d44
  f02d34: 08 ac 00 0a 00 04        bclr.b   #$a, $4(a4)
  f02d3a: 46 d7                    move.w   (a7), sr

loc_F02D3C:
  f02d3c: 41 d6                    lea.l    (a6), a0
  f02d3e: 61 00 da bc              bsr.w    $f007fc
  f02d42: 60 66                    bra.b    $f02daa

loc_F02D44:
  f02d44: 08 2c 00 0a 00 04        btst.b   #$a, $4(a4)
  f02d4a: 67 14                    beq.b    $f02d60
  f02d4c: 4a 6c 00 26              tst.w    $26(a4)
  f02d50: 67 0e                    beq.b    $f02d60
  f02d52: 46 d7                    move.w   (a7), sr
  f02d54: 4b d6                    lea.l    (a6), a5
  f02d56: 61 00 f9 50              bsr.w    $f026a8
  f02d5a: 60 e0                    bra.b    $f02d3c

loc_F02D5C:
  f02d5c: 00 7c 07 00              ori.w    #$700, sr

loc_F02D60:
  f02d60: 4a 47                    tst.w    d7
  f02d62: 67 1e                    beq.b    $f02d82
  f02d64: 08 ee 00 0e 00 2c        bset.b   #$e, $2c(a6)
  f02d6a: 08 ae 00 03 00 2d        bclr.b   #$3, $2d(a6)
  f02d70: 67 10                    beq.b    $f02d82
  f02d72: 08 ae 00 0e 00 2c        bclr.b   #$e, $2c(a6)
  f02d78: 46 d7                    move.w   (a7), sr
  f02d7a: 41 d6                    lea.l    (a6), a0
  f02d7c: 61 00 da 7e              bsr.w    $f007fc
  f02d80: 60 28                    bra.b    $f02daa

loc_F02D82:
  f02d82: 20 29 00 04              move.l   $4(a1), d0
  f02d86: 67 24                    beq.b    $f02dac
  f02d88: 24 40                    movea.l  d0, a2
  f02d8a: 23 52 00 04              move.l   (a2), $4(a1)
  f02d8e: 46 d7                    move.w   (a7), sr
  f02d90: 25 4e 00 04              move.l   a6, $4(a2)
  f02d94: 42 6a 00 14              clr.w    $14(a2)
  f02d98: 25 7c 21 44 4c 59 00 16  move.l   #$21444c59, $16(a2)
  f02da0: 2d 4a 00 58              move.l   a2, $58(a6)
  f02da4: 46 d7                    move.w   (a7), sr
  f02da6: 61 00 e3 64              bsr.w    $f0110c

loc_F02DAA:
  f02daa: 4e 73                    rte      

loc_F02DAC:
  f02dac: 46 d7                    move.w   (a7), sr
  f02dae: 3d 7c 00 05 01 02        move.w   #$5, $102(a6)
  f02db4: 60 f4                    bra.b    $f02daa

TRAP1_RELINQ:
  f02db6: 41 d6                    lea.l    (a6), a0
  f02db8: 61 00 da 4a              bsr.w    $f00804
  f02dbc: 4e 73                    rte      

TRAP1_SETPRI:
  f02dbe: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f02dc4: 66 10                    bne.b    $f02dd6
  f02dc6: 08 28 00 0f 00 28        btst.b   #$f, $28(a0)
  f02dcc: 67 08                    beq.b    $f02dd6
  f02dce: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f02dd4: 4e 73                    rte      

loc_F02DD6:
  f02dd6: 10 2c 00 08              move.b   $8(a4), d0
  f02dda: b0 28 00 25              cmp.b    $25(a0), d0
  f02dde: 63 12                    bls.b    $f02df2
  f02de0: 42 ae 01 20              clr.l    $120(a6)
  f02de4: 1d 68 00 25 01 23        move.b   $25(a0), $123(a6)
  f02dea: 06 6e 00 0a 01 02        addi.w   #$a, $102(a6)
  f02df0: 4e 73                    rte      

loc_F02DF2:
  f02df2: 11 40 00 24              move.b   d0, $24(a0)
  f02df6: 11 40 00 26              move.b   d0, $26(a0)
  f02dfa: 4e 73                    rte      

TRAP1_TERMT:
  f02dfc: 4a 94                    tst.l    (a4)
  f02dfe: 66 40                    bne.b    $f02e40
  f02e00: 22 2c 00 04              move.l   $4(a4), d1
  f02e04: 67 08                    beq.b    $f02e0e
  f02e06: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f02e0c: 66 04                    bne.b    $f02e12

loc_F02E0E:
  f02e0e: 22 2e 00 14              move.l   $14(a6), d1

loc_F02E12:
  f02e12: 2a 79 00 00 0c 10        movea.l  $c10.l, a5

loc_F02E18:
  f02e18: bb fc 00 00 00 00        cmpa.l   #$0, a5
  f02e1e: 67 28                    beq.b    $f02e48
  f02e20: b2 ad 00 14              cmp.l    $14(a5), d1
  f02e24: 66 14                    bne.b    $f02e3a
  f02e26: 08 2d 00 0f 00 28        btst.b   #$f, $28(a5)
  f02e2c: 66 0c                    bne.b    $f02e3a
  f02e2e: bd cd                    cmpa.l   a5, a6
  f02e30: 67 08                    beq.b    $f02e3a
  f02e32: 08 ed 00 07 00 2d        bset.b   #$7, $2d(a5)
  f02e38: 67 44                    beq.b    $f02e7e

loc_F02E3A:
  f02e3a: 2a 6d 00 04              movea.l  $4(a5), a5
  f02e3e: 60 d8                    bra.b    $f02e18

loc_F02E40:
  f02e40: 41 d4                    lea.l    (a4), a0
  f02e42: 61 00 e8 ca              bsr.w    $f0170e
  f02e46: 60 0a                    bra.b    $f02e52

loc_F02E48:
  f02e48: 42 ae 01 20              clr.l    $120(a6)
  f02e4c: 56 6e 01 02              addq.w   #$3, $102(a6)
  f02e50: 4e 73                    rte      

loc_F02E52:
  f02e52: 2a 48                    movea.l  a0, a5
  f02e54: bd cd                    cmpa.l   a5, a6
  f02e56: 67 10                    beq.b    $f02e68
  f02e58: 08 2d 00 0f 00 28        btst.b   #$f, $28(a5)
  f02e5e: 67 10                    beq.b    $f02e70
  f02e60: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f02e66: 66 08                    bne.b    $f02e70

loc_F02E68:
  f02e68: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f02e6e: 4e 73                    rte      

loc_F02E70:
  f02e70: 08 ed 00 07 00 2d        bset.b   #$7, $2d(a5)
  f02e76: 67 06                    beq.b    $f02e7e
  f02e78: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f02e7c: 4e 73                    rte      

loc_F02E7E:
  f02e7e: 30 2c 00 08              move.w   $8(a4), d0
  f02e82: 67 04                    beq.b    $f02e88
  f02e84: 08 c0 00 0f              bset.b   #$f, d0

loc_F02E88:
  f02e88: 08 ed 00 01 00 29        bset.b   #$1, $29(a5)
  f02e8e: 3b 40 00 2a              move.w   d0, $2a(a5)
  f02e92: 3b 6d 00 2c 00 2e        move.w   $2c(a5), $2e(a5)
  f02e98: 2d 6d 00 10 01 20        move.l   $10(a5), $120(a6)
  f02e9e: 2b 6e 00 10 00 b0        move.l   $10(a6), $b0(a5)
  f02ea4: 2b 6e 00 14 00 b4        move.l   $14(a6), $b4(a5)
  f02eaa: 08 ad 00 0a 00 2c        bclr.b   #$a, $2c(a5)
  f02eb0: 08 ad 00 06 00 2d        bclr.b   #$6, $2d(a5)
  f02eb6: 08 ad 00 0d 00 2c        bclr.b   #$d, $2c(a5)
  f02ebc: 67 30                    beq.b    $f02eee
  f02ebe: 20 6d 00 94              movea.l  $94(a5), a0
  f02ec2: 00 7c 07 00              ori.w    #$700, sr

loc_F02EC6:
  f02ec6: 4a d0                    tas.b    (a0)
  f02ec8: 6b fc                    bmi.b    $f02ec6
  f02eca: 43 e8 ff e2              lea.l    -$1e(a0), a1

loc_F02ECE:
  f02ece: 4a a9 00 20              tst.l    $20(a1)
  f02ed2: 67 14                    beq.b    $f02ee8
  f02ed4: bb e9 00 20              cmpa.l   $20(a1), a5
  f02ed8: 67 06                    beq.b    $f02ee0
  f02eda: 22 69 00 20              movea.l  $20(a1), a1
  f02ede: 60 ee                    bra.b    $f02ece

loc_F02EE0:
  f02ee0: 23 6d 00 20 00 20        move.l   $20(a5), $20(a1)
  f02ee6: 52 50                    addq.w   #$1, (a0)

loc_F02EE8:
  f02ee8: 08 90 00 0f              bclr.b   #$f, (a0)
  f02eec: 46 d7                    move.w   (a7), sr

loc_F02EEE:
  f02eee: 02 6d 2d ff 00 2c        andi.w   #$2dff, $2c(a5)
  f02ef4: 1b 7c 00 f0 00 26        move.b   #$f0, $26(a5)
  f02efa: 08 ad 00 0b 00 2c        bclr.b   #$b, $2c(a5)
  f02f00: 67 06                    beq.b    $f02f08
  f02f02: 08 ed 00 02 00 2d        bset.b   #$2, $2d(a5)

loc_F02F08:
  f02f08: 00 7c 07 00              ori.w    #$700, sr
  f02f0c: 08 ad 00 04 00 2d        bclr.b   #$4, $2d(a5)
  f02f12: 67 18                    beq.b    $f02f2c
  f02f14: 20 3c 00 00 0c 08        move.l   #$c08, d0

loc_F02F1A:
  f02f1a: 20 40                    movea.l  d0, a0
  f02f1c: 20 28 00 0c              move.l   $c(a0), d0
  f02f20: 67 0a                    beq.b    $f02f2c
  f02f22: b0 8d                    cmp.l    a5, d0
  f02f24: 66 f4                    bne.b    $f02f1a
  f02f26: 21 6d 00 0c 00 0c        move.l   $c(a5), $c(a0)

loc_F02F2C:
  f02f2c: 41 d5                    lea.l    (a5), a0
  f02f2e: 61 00 d8 90              bsr.w    $f007c0
  f02f32: 4e 73                    rte      

TRAP1_ABORT:
  f02f34: 08 ee 00 01 00 29        bset.b   #$1, $29(a6)
  f02f3a: 3d 48 00 2a              move.w   a0, $2a(a6)
  f02f3e: 66 06                    bne.b    $f02f46
  f02f40: 08 ee 00 0f 00 2a        bset.b   #$f, $2a(a6)

loc_F02F46:
  f02f46: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f02f4c: 67 0c                    beq.b    $f02f5a
  f02f4e: 08 2e 00 0d 00 28        btst.b   #$d, $28(a6)
  f02f54: 67 04                    beq.b    $f02f5a
  f02f56: 61 00 d2 2e              bsr.w    $f00186

loc_F02F5A:
  f02f5a: 08 2e 00 07 00 2d        btst.b   #$7, $2d(a6)
  f02f60: 67 0e                    beq.b    $f02f70
  f02f62: 60 24                    bra.b    $f02f88

TRAP1_TERM:
  f02f64: 08 2e 00 01 00 29        btst.b   #$1, $29(a6)
  f02f6a: 66 da                    bne.b    $f02f46
  f02f6c: 3d 48 00 2a              move.w   a0, $2a(a6)

loc_F02F70:
  f02f70: 3d 6e 00 2c 00 2e        move.w   $2c(a6), $2e(a6)
  f02f76: 08 ee 00 07 00 2d        bset.b   #$7, $2d(a6)
  f02f7c: 2d 6e 00 10 00 b0        move.l   $10(a6), $b0(a6)
  f02f82: 2d 6e 00 14 00 b4        move.l   $14(a6), $b4(a6)

loc_F02F88:
  f02f88: 28 4e                    movea.l  a6, a4
  f02f8a: 22 78 0c 2c              movea.l  $c2c.w, a1
  f02f8e: 45 e9 00 08              lea.l    $8(a1), a2

loc_F02F92:
  f02f92: 26 4a                    movea.l  a2, a3

loc_F02F94:
  f02f94: 20 13                    move.l   (a3), d0
  f02f96: 67 10                    beq.b    $f02fa8
  f02f98: 24 40                    movea.l  d0, a2
  f02f9a: b9 ea 00 04              cmpa.l   $4(a2), a4
  f02f9e: 66 f2                    bne.b    $f02f92
  f02fa0: 26 92                    move.l   (a2), (a3)
  f02fa2: 61 00 e1 4c              bsr.w    $f010f0
  f02fa6: 60 ec                    bra.b    $f02f94

loc_F02FA8:
  f02fa8: 08 2c 00 00 00 29        btst.b   #$0, $29(a4)
  f02fae: 67 04                    beq.b    $f02fb4
  f02fb0: 61 00 f2 1c              bsr.w    $f021ce

loc_F02FB4:
  f02fb4: 20 2c 00 54              move.l   $54(a4), d0
  f02fb8: 67 26                    beq.b    $f02fe0
  f02fba: 20 40                    movea.l  d0, a0
  f02fbc: 42 a8 00 08              clr.l    $8(a0)
  f02fc0: 21 78 0e 34 00 04        move.l   $e34.w, $4(a0)
  f02fc6: 21 c8 0e 34              move.l   a0, $e34.w
  f02fca: 20 28 00 16              move.l   $16(a0), d0

loc_F02FCE:
  f02fce: 67 0a                    beq.b    $f02fda
  f02fd0: 20 40                    movea.l  d0, a0
  f02fd2: 46 90                    not.l    (a0)
  f02fd4: 20 28 00 10              move.l   $10(a0), d0
  f02fd8: 60 f4                    bra.b    $f02fce

loc_F02FDA:
  f02fda: 28 bc 21 74 63 62        move.l   #$21746362, (a4)

loc_F02FE0:
  f02fe0: 26 2c 00 10              move.l   $10(a4), d3
  f02fe4: 28 2c 00 14              move.l   $14(a4), d4
  f02fe8: 08 ec 00 02 00 29        bset.b   #$2, $29(a4)
  f02fee: 22 78 0c 10              movea.l  $c10.w, a1

loc_F02FF2:
  f02ff2: 08 29 00 07 00 2d        btst.b   #$7, $2d(a1)
  f02ff8: 66 32                    bne.b    $f0302c
  f02ffa: b8 a9 00 14              cmp.l    $14(a1), d4
  f02ffe: 66 06                    bne.b    $f03006
  f03000: 08 ac 00 02 00 29        bclr.b   #$2, $29(a4)

loc_F03006:
  f03006: 08 2c 00 05 00 29        btst.b   #$5, $29(a4)
  f0300c: 67 1e                    beq.b    $f0302c
  f0300e: 08 29 00 0a 00 2c        btst.b   #$a, $2c(a1)
  f03014: 67 16                    beq.b    $f0302c
  f03016: b6 a9 01 40              cmp.l    $140(a1), d3
  f0301a: 66 10                    bne.b    $f0302c
  f0301c: b8 a9 01 44              cmp.l    $144(a1), d4
  f03020: 66 0a                    bne.b    $f0302c
  f03022: 3e 3c 00 40              move.w   #$40, d7
  f03026: 41 d1                    lea.l    (a1), a0
  f03028: 61 00 d7 fa              bsr.w    $f00824

loc_F0302C:
  f0302c: 22 69 00 04              movea.l  $4(a1), a1
  f03030: 20 09                    move.l   a1, d0
  f03032: 66 be                    bne.b    $f02ff2
  f03034: 08 2c 00 06 00 29        btst.b   #$6, $29(a4)
  f0303a: 67 06                    beq.b    $f03042
  f0303c: 61 00 05 26              bsr.w    $f03564
  f03040: 4e 71                    nop      

loc_F03042:
  f03042: 61 00 0a ec              bsr.w    $f03b30
  f03046: 08 2c 00 07 00 29        btst.b   #$7, $29(a4)
  f0304c: 67 04                    beq.b    $f03052
  f0304e: 61 00 04 44              bsr.w    $f03494

loc_F03052:
  f03052: 7e 01                    moveq    #$1, d7

loc_F03054:
  f03054: 43 f8 0c 9a              lea.l    $c9a.w, a1
  f03058: 45 f8 0c aa              lea.l    $caa.w, a2
  f0305c: 22 07                    move.l   d7, d1
  f0305e: c2 fc 00 16              mulu.w   #$16, d1
  f03062: 0c 31 00 02 70 00        cmpi.b   #$2, (a1, d7.w)
  f03068: 66 1c                    bne.b    $f03086
  f0306a: 08 32 00 0e 10 14        btst.b   #$e, $14(a2, d1.w)
  f03070: 67 14                    beq.b    $f03086
  f03072: 2f 07                    move.l   d7, -(a7)
  f03074: 61 00 dd 2e              bsr.w    $f00da4
  f03078: 2e 1f                    move.l   (a7)+, d7
  f0307a: 08 2c 00 0b 00 2c        btst.b   #$b, $2c(a4)
  f03080: 67 04                    beq.b    $f03086
  f03082: 61 00 d7 90              bsr.w    $f00814

loc_F03086:
  f03086: 52 87                    addq.l   #$1, d7
  f03088: 0c 87 00 00 00 0f        cmpi.l   #$f, d7
  f0308e: 6f c4                    ble.b    $f03054
  f03090: 46 d7                    move.w   (a7), sr
  f03092: 61 00 f3 6a              bsr.w    $f023fe
  f03096: 61 00 ea d8              bsr.w    $f01b70
  f0309a: 4a ac 00 18              tst.l    $18(a4)
  f0309e: 67 48                    beq.b    $f030e8
  f030a0: 34 3c 18 05              move.w   #$1805, d2
  f030a4: 48 42                    swap     d2
  f030a6: 34 2c 00 10              move.w   $10(a4), d2
  f030aa: 26 2c 00 12              move.l   $12(a4), d3
  f030ae: 38 2c 00 16              move.w   $16(a4), d4
  f030b2: 48 44                    swap     d4
  f030b4: 38 2c 00 b0              move.w   $b0(a4), d4
  f030b8: 2a 2c 00 b2              move.l   $b2(a4), d5
  f030bc: 3c 2c 00 b6              move.w   $b6(a4), d6
  f030c0: 48 46                    swap     d6
  f030c2: 3c 3c 01 00              move.w   #$100, d6
  f030c6: 2e 2c 00 2a              move.l   $2a(a4), d7
  f030ca: 3e 2c 00 5c              move.w   $5c(a4), d7
  f030ce: 08 2c 00 01 00 29        btst.b   #$1, $29(a4)
  f030d4: 67 04                    beq.b    $f030da
  f030d6: 3c 3c 02 00              move.w   #$200, d6

loc_F030DA:
  f030da: 24 4c                    movea.l  a4, a2
  f030dc: 41 ec 00 18              lea.l    $18(a4), a0
  f030e0: 61 00 e4 da              bsr.w    $f015bc
  f030e4: 4e 71                    nop      
  f030e6: 28 4a                    movea.l  a2, a4

loc_F030E8:
  f030e8: 43 f8 0c 0c              lea.l    $c0c.w, a1

loc_F030EC:
  f030ec: 20 29 00 04              move.l   $4(a1), d0
  f030f0: 67 0e                    beq.b    $f03100
  f030f2: b9 c0                    cmpa.l   d0, a4
  f030f4: 67 04                    beq.b    $f030fa
  f030f6: 22 40                    movea.l  d0, a1
  f030f8: 60 f2                    bra.b    $f030ec

loc_F030FA:
  f030fa: 23 6c 00 04 00 04        move.l   $4(a4), $4(a1)

loc_F03100:
  f03100: 42 b8 0c 0c              clr.l    $c0c.w
  f03104: 72 02                    moveq    #$2, d1
  f03106: 41 d4                    lea.l    (a4), a0
  f03108: 61 00 e3 8a              bsr.w    $f01494
  f0310c: 4e 73                    rte      
  f0310e: 61 00 d0 76              bsr.w    $f00186

TRAP1_TSKATTR:
  f03112: 08 28 00 07 00 2d        btst.b   #$7, $2d(a0)
  f03118: 67 06                    beq.b    $f03120
  f0311a: 06 6e 00 0a 01 02        addi.w   #$a, $102(a6)

loc_F03120:
  f03120: 2d 68 00 70 01 20        move.l   $70(a0), $120(a6)
  f03126: 3d 68 00 28 01 22        move.w   $28(a0), $122(a6)
  f0312c: 4e 73                    rte      

TRAP1_EXPVCT:
  f0312e: 2d 6e 01 20 00 48        move.l   $120(a6), $48(a6)
  f03134: 08 ee 00 04 00 29        bset.b   #$4, $29(a6)
  f0313a: 4e 73                    rte      

TRAP1_TRPVCT:
  f0313c: 2d 6e 01 20 00 4c        move.l   $120(a6), $4c(a6)
  f03142: 08 ee 00 03 00 29        bset.b   #$3, $29(a6)
  f03148: 4e 73                    rte      

TRAP1_CRSEM:
  f0314a: 7e 01                    moveq    #$1, d7
  f0314c: 48 47                    swap     d7
  f0314e: 60 02                    bra.b    $f03152

TRAP1_ATSEM:
  f03150: 42 87                    clr.l    d7

loc_F03152:
  f03152: 2a 4c                    movea.l  a4, a5
  f03154: 42 ae 01 20              clr.l    $120(a6)
  f03158: 42 86                    clr.l    d6
  f0315a: 1c 2d 00 09              move.b   $9(a5), d6
  f0315e: 0c 06 00 01              cmpi.b   #$1, d6
  f03162: 67 2e                    beq.b    $f03192
  f03164: 6d 1c                    blt.b    $f03182
  f03166: 0c 06 00 03              cmpi.b   #$3, d6
  f0316a: 6e 16                    bgt.b    $f03182
  f0316c: 4a 87                    tst.l    d7
  f0316e: 67 24                    beq.b    $f03194
  f03170: 1e 2d 00 08              move.b   $8(a5), d7
  f03174: 08 07 00 07              btst.b   #$7, d7
  f03178: 67 1a                    beq.b    $f03194
  f0317a: 06 6e 00 10 01 02        addi.w   #$10, $102(a6)
  f03180: 60 06                    bra.b    $f03188

loc_F03182:
  f03182: 06 6e 00 0f 01 02        addi.w   #$f, $102(a6)

loc_F03188:
  f03188: 60 00 01 6c              bra.w    $f032f6

loc_F0318C:
  f0318c: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f03190: 60 f6                    bra.b    $f03188

loc_F03192:
  f03192: 42 87                    clr.l    d7

loc_F03194:
  f03194: 28 4e                    movea.l  a6, a4
  f03196: 20 55                    movea.l  (a5), a0
  f03198: 61 00 e6 dc              bsr.w    $f01876
  f0319c: 60 0a                    bra.b    $f031a8
  f0319e: 4a 80                    tst.l    d0
  f031a0: 66 4e                    bne.b    $f031f0
  f031a2: 5a 6e 01 02              addq.w   #$5, $102(a6)
  f031a6: 60 e0                    bra.b    $f03188

loc_F031A8:
  f031a8: 2d 40 01 20              move.l   d0, $120(a6)
  f031ac: 4a 87                    tst.l    d7
  f031ae: 67 d8                    beq.b    $f03188
  f031b0: 0c 06 00 03              cmpi.b   #$3, d6
  f031b4: 67 d6                    beq.b    $f0318c

loc_F031B6:
  f031b6: 26 00                    move.l   d0, d3
  f031b8: bc 31 30 0f              cmp.b    $f(a1, d3.w), d6
  f031bc: 66 00 01 32              bne.w    $f032f0
  f031c0: 4a 71 30 0c              tst.w    $c(a1, d3.w)
  f031c4: 6c 06                    bge.b    $f031cc
  f031c6: 20 31 30 10              move.l   $10(a1, d3.w), d0
  f031ca: 60 ea                    bra.b    $f031b6

loc_F031CC:
  f031cc: 13 87 30 0e              move.b   d7, $e(a1, d3.w)
  f031d0: 4a 31 30 11              tst.b    $11(a1, d3.w)
  f031d4: 6b 06                    bmi.b    $f031dc
  f031d6: 13 87 30 11              move.b   d7, $11(a1, d3.w)
  f031da: 60 ac                    bra.b    $f03188

loc_F031DC:
  f031dc: 4a 07                    tst.b    d7
  f031de: 67 a8                    beq.b    $f03188

loc_F031E0:
  f031e0: 41 f1 30 10              lea.l    $10(a1, d3.w), a0
  f031e4: 61 00 d5 a2              bsr.w    $f00788
  f031e8: 53 47                    subq.w   #$1, d7
  f031ea: 66 f4                    bne.b    $f031e0

loc_F031EC:
  f031ec: 60 00 01 08              bra.w    $f032f6

loc_F031F0:
  f031f0: 08 ee 00 07 00 29        bset.b   #$7, $29(a6)
  f031f6: 2d 40 01 20              move.l   d0, $120(a6)
  f031fa: 26 00                    move.l   d0, d3
  f031fc: 23 ae 00 10 30 00        move.l   $10(a6), (a1, d3.w)
  f03202: 23 ae 00 14 30 04        move.l   $14(a6), $4(a1, d3.w)
  f03208: 23 88 30 08              move.l   a0, $8(a1, d3.w)
  f0320c: 4a 41                    tst.w    d1
  f0320e: 66 40                    bne.b    $f03250
  f03210: 33 bc 00 01 30 0c        move.w   #$1, $c(a1, d3.w)
  f03216: 13 86 30 0f              move.b   d6, $f(a1, d3.w)
  f0321a: 13 87 30 0e              move.b   d7, $e(a1, d3.w)
  f0321e: 33 87 30 10              move.w   d7, $10(a1, d3.w)
  f03222: 42 b1 30 12              clr.l    $12(a1, d3.w)
  f03226: 33 42 00 0e              move.w   d2, $e(a1)
  f0322a: 0c 46 00 01              cmpi.w   #$1, d6
  f0322e: 66 08                    bne.b    $f03238
  f03230: 33 bc 00 01 30 10        move.w   #$1, $10(a1, d3.w)
  f03236: 60 b4                    bra.b    $f031ec

loc_F03238:
  f03238: 0c 46 00 02              cmpi.w   #$2, d6
  f0323c: 67 ae                    beq.b    $f031ec
  f0323e: 4a 87                    tst.l    d7
  f03240: 66 aa                    bne.b    $f031ec
  f03242: 42 b1 30 00              clr.l    (a1, d3.w)
  f03246: 33 bc 04 00 30 0c        move.w   #$400, $c(a1, d3.w)
  f0324c: 60 00 ff 46              bra.w    $f03194

loc_F03250:
  f03250: c3 43                    exg.l    d1, d3
  f03252: bc 31 30 0f              cmp.b    $f(a1, d3.w), d6
  f03256: 66 94                    bne.b    $f031ec
  f03258: 4a 87                    tst.l    d7
  f0325a: 67 08                    beq.b    $f03264
  f0325c: 0c 86 00 00 00 03        cmpi.l   #$3, d6
  f03262: 67 46                    beq.b    $f032aa

loc_F03264:
  f03264: 0c 86 00 00 00 02        cmpi.l   #$2, d6
  f0326a: 66 06                    bne.b    $f03272
  f0326c: 4a b1 30 00              tst.l    (a1, d3.w)
  f03270: 67 68                    beq.b    $f032da

loc_F03272:
  f03272: 23 83 10 10              move.l   d3, $10(a1, d1.w)
  f03276: 33 bc ff ff 10 0c        move.w   #$ffff, $c(a1, d1.w)
  f0327c: 13 86 10 0f              move.b   d6, $f(a1, d1.w)
  f03280: 42 31 10 0e              clr.b    $e(a1, d1.w)
  f03284: 33 42 00 0e              move.w   d2, $e(a1)
  f03288: 52 71 30 0c              addq.w   #$1, $c(a1, d3.w)
  f0328c: 4a 87                    tst.l    d7
  f0328e: 66 00 ff 3c              bne.w    $f031cc
  f03292: 0c 46 00 03              cmpi.w   #$3, d6
  f03296: 66 00 00 5e              bne.w    $f032f6
  f0329a: 4a b1 30 00              tst.l    (a1, d3.w)
  f0329e: 66 56                    bne.b    $f032f6
  f032a0: 41 f1 30 10              lea.l    $10(a1, d3.w), a0
  f032a4: 61 00 d4 42              bsr.w    $f006e8
  f032a8: 4e 73                    rte      

loc_F032AA:
  f032aa: 4a b1 30 00              tst.l    (a1, d3.w)
  f032ae: 66 00 fe dc              bne.w    $f0318c
  f032b2: 2d 43 01 20              move.l   d3, $120(a6)
  f032b6: 23 ae 00 10 30 00        move.l   $10(a6), (a1, d3.w)
  f032bc: 52 71 30 0c              addq.w   #$1, $c(a1, d3.w)
  f032c0: 13 87 30 0e              move.b   d7, $e(a1, d3.w)
  f032c4: 60 08                    bra.b    $f032ce

loc_F032C6:
  f032c6: 41 f1 30 10              lea.l    $10(a1, d3.w), a0
  f032ca: 61 00 d4 bc              bsr.w    $f00788

loc_F032CE:
  f032ce: 4a 31 30 11              tst.b    $11(a1, d3.w)
  f032d2: 6b f2                    bmi.b    $f032c6
  f032d4: 13 87 30 11              move.b   d7, $11(a1, d3.w)
  f032d8: 60 1c                    bra.b    $f032f6

loc_F032DA:
  f032da: 2d 43 01 20              move.l   d3, $120(a6)
  f032de: 23 ae 00 10 30 00        move.l   $10(a6), (a1, d3.w)
  f032e4: 52 71 30 0c              addq.w   #$1, $c(a1, d3.w)
  f032e8: 4a 87                    tst.l    d7
  f032ea: 67 0a                    beq.b    $f032f6
  f032ec: 60 00 fe de              bra.w    $f031cc

loc_F032F0:
  f032f0: 06 6e 00 0b 01 02        addi.w   #$b, $102(a6)

loc_F032F6:
  f032f6: 4e 73                    rte      

TRAP1_SGSEM:
  f032f8: 42 47                    clr.w    d7
  f032fa: 60 04                    bra.b    $f03300

TRAP1_WTSEM:
  f032fc: 3e 3c 00 01              move.w   #$1, d7

loc_F03300:
  f03300: 26 2c 00 04              move.l   $4(a4), d3
  f03304: 22 78 0c 24              movea.l  $c24.w, a1
  f03308: 30 03                    move.w   d3, d0
  f0330a: e0 48                    lsr.w    #$8, d0
  f0330c: b0 69 00 0a              cmp.w    $a(a1), d0
  f03310: 6c 42                    bge.b    $f03354
  f03312: 28 14                    move.l   (a4), d4
  f03314: b8 b1 30 08              cmp.l    $8(a1, d3.w), d4
  f03318: 66 3a                    bne.b    $f03354
  f0331a: 4a 71 30 0c              tst.w    $c(a1, d3.w)
  f0331e: 67 34                    beq.b    $f03354
  f03320: 0c 31 00 01 30 0f        cmpi.b   #$1, $f(a1, d3.w)
  f03326: 66 0a                    bne.b    $f03332
  f03328: be 31 30 0e              cmp.b    $e(a1, d3.w), d7
  f0332c: 67 2c                    beq.b    $f0335a
  f0332e: 13 87 30 0e              move.b   d7, $e(a1, d3.w)

loc_F03332:
  f03332: 4a 71 30 0c              tst.w    $c(a1, d3.w)
  f03336: 6a 04                    bpl.b    $f0333c
  f03338: 26 31 30 10              move.l   $10(a1, d3.w), d3

loc_F0333C:
  f0333c: 4a 47                    tst.w    d7
  f0333e: 67 0a                    beq.b    $f0334a
  f03340: 41 f1 30 10              lea.l    $10(a1, d3.w), a0
  f03344: 61 00 d3 a2              bsr.w    $f006e8
  f03348: 4e 73                    rte      

loc_F0334A:
  f0334a: 41 f1 30 10              lea.l    $10(a1, d3.w), a0
  f0334e: 61 00 d4 38              bsr.w    $f00788
  f03352: 4e 73                    rte      

loc_F03354:
  f03354: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f03358: 4e 73                    rte      

loc_F0335A:
  f0335a: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f03360: 4e 73                    rte      

TRAP1_DESEM:
  f03362: 2a 46                    movea.l  d6, a5
  f03364: 28 4e                    movea.l  a6, a4
  f03366: 20 55                    movea.l  (a5), a0
  f03368: 61 00 e5 0c              bsr.w    $f01876
  f0336c: 60 08                    bra.b    $f03376
  f0336e: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f03372: 60 00 01 1a              bra.w    $f0348e

loc_F03376:
  f03376: 26 00                    move.l   d0, d3
  f03378: 22 03                    move.l   d3, d1
  f0337a: 4a 71 10 0c              tst.w    $c(a1, d1.w)
  f0337e: 6c 04                    bge.b    $f03384
  f03380: 26 31 10 10              move.l   $10(a1, d1.w), d3

loc_F03384:
  f03384: 0c 31 00 01 10 0f        cmpi.b   #$1, $f(a1, d1.w)
  f0338a: 66 0e                    bne.b    $f0339a
  f0338c: 4a 31 10 0e              tst.b    $e(a1, d1.w)
  f03390: 67 08                    beq.b    $f0339a
  f03392: 41 f1 30 10              lea.l    $10(a1, d3.w), a0
  f03396: 61 00 d3 f0              bsr.w    $f00788

loc_F0339A:
  f0339a: 4a 71 10 0c              tst.w    $c(a1, d1.w)
  f0339e: 6a 14                    bpl.b    $f033b4
  f033a0: 42 b1 10 00              clr.l    (a1, d1.w)
  f033a4: 42 71 10 0c              clr.w    $c(a1, d1.w)
  f033a8: 42 31 30 0c              clr.b    $c(a1, d3.w)
  f033ac: 53 71 30 0c              subq.w   #$1, $c(a1, d3.w)
  f033b0: 60 00 00 dc              bra.w    $f0348e

loc_F033B4:
  f033b4: 42 31 30 0c              clr.b    $c(a1, d3.w)
  f033b8: 0c 31 00 03 30 0f        cmpi.b   #$3, $f(a1, d3.w)
  f033be: 67 00 00 7c              beq.w    $f0343c
  f033c2: 53 71 30 0c              subq.w   #$1, $c(a1, d3.w)
  f033c6: 66 24                    bne.b    $f033ec
  f033c8: 0c 31 00 02 30 0f        cmpi.b   #$2, $f(a1, d3.w)
  f033ce: 66 00 00 ba              bne.w    $f0348a
  f033d2: 10 31 30 0e              move.b   $e(a1, d3.w), d0
  f033d6: b0 31 30 11              cmp.b    $11(a1, d3.w), d0
  f033da: 67 00 00 ae              beq.w    $f0348a
  f033de: 33 bc 04 00 30 0c        move.w   #$400, $c(a1, d3.w)
  f033e4: 42 b1 30 00              clr.l    (a1, d3.w)
  f033e8: 60 00 00 a4              bra.w    $f0348e

loc_F033EC:
  f033ec: 2e 31 30 04              move.l   $4(a1, d3.w), d7
  f033f0: 2c 31 30 08              move.l   $8(a1, d3.w), d6
  f033f4: 42 84                    clr.l    d4
  f033f6: 34 29 00 0e              move.w   $e(a1), d2
  f033fa: 70 14                    moveq    #$14, d0

loc_F033FC:
  f033fc: 4a 71 00 0c              tst.w    $c(a1, d0.w)
  f03400: 6c 2e                    bge.b    $f03430
  f03402: be b1 00 04              cmp.l    $4(a1, d0.w), d7
  f03406: 66 28                    bne.b    $f03430
  f03408: bc b1 00 08              cmp.l    $8(a1, d0.w), d6
  f0340c: 66 22                    bne.b    $f03430
  f0340e: 4a 44                    tst.w    d4
  f03410: 67 06                    beq.b    $f03418
  f03412: 23 84 00 10              move.l   d4, $10(a1, d0.w)
  f03416: 60 18                    bra.b    $f03430

loc_F03418:
  f03418: 28 00                    move.l   d0, d4
  f0341a: 33 b1 30 0c 00 0c        move.w   $c(a1, d3.w), $c(a1, d0.w)
  f03420: 33 b1 30 10 00 10        move.w   $10(a1, d3.w), $10(a1, d0.w)
  f03426: 23 b1 30 12 00 12        move.l   $12(a1, d3.w), $12(a1, d0.w)
  f0342c: 42 71 30 0c              clr.w    $c(a1, d3.w)

loc_F03430:
  f03430: 06 80 00 00 00 16        addi.l   #$16, d0
  f03436: 53 42                    subq.w   #$1, d2
  f03438: 66 c2                    bne.b    $f033fc
  f0343a: 60 4e                    bra.b    $f0348a

loc_F0343C:
  f0343c: 4a 31 30 11              tst.b    $11(a1, d3.w)
  f03440: 6a 12                    bpl.b    $f03454
  f03442: 2a 71 30 12              movea.l  $12(a1, d3.w), a5
  f03446: 5e 6d 01 02              addq.w   #$7, $102(a5)
  f0344a: 41 f1 30 10              lea.l    $10(a1, d3.w), a0
  f0344e: 61 00 d3 38              bsr.w    $f00788
  f03452: 60 e8                    bra.b    $f0343c

loc_F03454:
  f03454: 2e 31 30 04              move.l   $4(a1, d3.w), d7
  f03458: 2c 31 30 08              move.l   $8(a1, d3.w), d6
  f0345c: 34 29 00 0e              move.w   $e(a1), d2
  f03460: 70 14                    moveq    #$14, d0

loc_F03462:
  f03462: 4a 71 00 0c              tst.w    $c(a1, d0.w)
  f03466: 6a 14                    bpl.b    $f0347c
  f03468: be b1 00 04              cmp.l    $4(a1, d0.w), d7
  f0346c: 66 0e                    bne.b    $f0347c
  f0346e: bc b1 00 08              cmp.l    $8(a1, d0.w), d6
  f03472: 66 08                    bne.b    $f0347c
  f03474: 42 71 00 0c              clr.w    $c(a1, d0.w)
  f03478: 42 b1 00 00              clr.l    (a1, d0.w)

loc_F0347C:
  f0347c: 06 80 00 00 00 16        addi.l   #$16, d0
  f03482: 53 42                    subq.w   #$1, d2
  f03484: 66 dc                    bne.b    $f03462
  f03486: 42 71 30 0c              clr.w    $c(a1, d3.w)

loc_F0348A:
  f0348a: 42 b1 30 00              clr.l    (a1, d3.w)

loc_F0348E:
  f0348e: 4e 73                    rte      

TRAP1_DESEMA:
  f03490: 28 4e                    movea.l  a6, a4
  f03492: 60 02                    bra.b    $f03496

TRAP0_dir_10_bsr:
  f03494: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_10:
  f03496: 08 2c 00 07 00 29        btst.b   #$7, $29(a4)
  f0349c: 67 0a                    beq.b    $f034a8

loc_F0349E:
  f0349e: 41 f8 00 00              lea.l    $0.w, a0
  f034a2: 61 00 e3 d2              bsr.w    $f01876
  f034a6: 60 02                    bra.b    $f034aa

loc_F034A8:
  f034a8: 4e 73                    rte      

loc_F034AA:
  f034aa: 61 02                    bsr.b    $f034ae
  f034ac: 60 f0                    bra.b    $f0349e

loc_F034AE:
  f034ae: 40 e7                    move.w   sr, -(a7)
  f034b0: 60 00 fe c4              bra.w    $f03376

TRAP1_EXMON:
  f034b4: 24 4d                    movea.l  a5, a2
  f034b6: 20 6c 00 08              movea.l  $8(a4), a0
  f034ba: 22 2c 00 0c              move.l   $c(a4), d1
  f034be: 61 00 e2 3e              bsr.w    $f016fe
  f034c2: 60 06                    bra.b    $f034ca
  f034c4: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f034c8: 4e 73                    rte      

loc_F034CA:
  f034ca: 2a 48                    movea.l  a0, a5
  f034cc: 08 2a 00 06 00 29        btst.b   #$6, $29(a2)
  f034d2: 67 06                    beq.b    $f034da
  f034d4: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f034d8: 4e 73                    rte      

loc_F034DA:
  f034da: bb ca                    cmpa.l   a2, a5
  f034dc: 67 2e                    beq.b    $f0350c
  f034de: bd ca                    cmpa.l   a2, a6
  f034e0: 67 08                    beq.b    $f034ea
  f034e2: 08 2a 00 0f 00 2c        btst.b   #$f, $2c(a2)
  f034e8: 67 22                    beq.b    $f0350c

loc_F034EA:
  f034ea: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f034f0: 66 08                    bne.b    $f034fa
  f034f2: 08 2a 00 0f 00 28        btst.b   #$f, $28(a2)
  f034f8: 66 12                    bne.b    $f0350c

loc_F034FA:
  f034fa: 20 6d 00 14              movea.l  $14(a5), a0
  f034fe: b1 ea 00 14              cmpa.l   $14(a2), a0
  f03502: 67 10                    beq.b    $f03514
  f03504: 08 2d 00 0f 00 28        btst.b   #$f, $28(a5)
  f0350a: 66 08                    bne.b    $f03514

loc_F0350C:
  f0350c: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f03512: 4e 73                    rte      

loc_F03514:
  f03514: 24 3c 0c 08 00 00        move.l   #$c080000, d2
  f0351a: 34 2a 00 10              move.w   $10(a2), d2
  f0351e: 26 2a 00 12              move.l   $12(a2), d3
  f03522: 28 2a 00 16              move.l   $16(a2), d4
  f03526: 38 3c 00 01              move.w   #$1, d4
  f0352a: 41 d5                    lea.l    (a5), a0
  f0352c: 61 00 e0 aa              bsr.w    $f015d8
  f03530: 60 06                    bra.b    $f03538
  f03532: 5a 6e 01 02              addq.w   #$5, $102(a6)
  f03536: 4e 73                    rte      

loc_F03538:
  f03538: 08 ed 00 05 00 29        bset.b   #$5, $29(a5)
  f0353e: 08 ea 00 06 00 29        bset.b   #$6, $29(a2)
  f03544: 08 ea 00 0a 00 2c        bset.b   #$a, $2c(a2)
  f0354a: 25 6d 00 10 01 40        move.l   $10(a5), $140(a2)
  f03550: 25 6d 00 14 01 44        move.l   $14(a5), $144(a2)
  f03556: bd ca                    cmpa.l   a2, a6
  f03558: 66 02                    bne.b    $f0355c
  f0355a: 4e 73                    rte      

loc_F0355C:
  f0355c: 3f 7c 00 02 00 06        move.w   #$2, $6(a7)
  f03562: 4e 73                    rte      

TRAP0_dir_14_bsr:
  f03564: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_14:
  f03566: 24 4c                    movea.l  a4, a2
  f03568: 08 aa 00 0a 00 2c        bclr.b   #$a, $2c(a2)
  f0356e: 60 12                    bra.b    $f03582

TRAP1_DEMON:
  f03570: 24 48                    movea.l  a0, a2
  f03572: 08 2a 00 06 00 29        btst.b   #$6, $29(a2)
  f03578: 66 08                    bne.b    $f03582
  f0357a: 06 6e 00 0a 01 02        addi.w   #$a, $102(a6)
  f03580: 4e 73                    rte      

loc_F03582:
  f03582: 24 3c 0c 08 00 00        move.l   #$c080000, d2
  f03588: 34 2a 00 10              move.w   $10(a2), d2
  f0358c: 26 2a 00 12              move.l   $12(a2), d3
  f03590: 28 2a 00 16              move.l   $16(a2), d4
  f03594: 38 3c 00 02              move.w   #$2, d4
  f03598: 41 ea 01 40              lea.l    $140(a2), a0
  f0359c: 61 00 e0 1e              bsr.w    $f015bc
  f035a0: 4e 71                    nop      
  f035a2: 28 4a                    movea.l  a2, a4
  f035a4: 08 aa 00 06 00 29        bclr.b   #$6, $29(a2)
  f035aa: 08 aa 00 0f 00 fa        bclr.b   #$f, $fa(a2)
  f035b0: 42 aa 01 48              clr.l    $148(a2)
  f035b4: 08 aa 00 0a 00 2c        bclr.b   #$a, $2c(a2)
  f035ba: 66 02                    bne.b    $f035be
  f035bc: 4e 73                    rte      

loc_F035BE:
  f035be: 41 d2                    lea.l    (a2), a0
  f035c0: 61 00 d1 fe              bsr.w    $f007c0
  f035c4: 4e 73                    rte      

TRAP1_EXMMSK:
  f035c6: 10 28 01 48              move.b   $148(a0), d0
  f035ca: 21 6c 00 08 01 48        move.l   $8(a4), $148(a0)
  f035d0: 02 00 00 38              andi.b   #$38, d0
  f035d4: 02 28 00 07 01 48        andi.b   #$7, $148(a0)
  f035da: 81 28 01 48              or.b     d0, $148(a0)
  f035de: 4e 73                    rte      

loc_F035E0:
  f035e0: 08 2d 00 06 00 29        btst.b   #$6, $29(a5)
  f035e6: 67 2e                    beq.b    $f03616
  f035e8: 20 2d 01 40              move.l   $140(a5), d0
  f035ec: b0 ae 00 10              cmp.l    $10(a6), d0
  f035f0: 66 24                    bne.b    $f03616
  f035f2: 20 2d 01 44              move.l   $144(a5), d0
  f035f6: b0 ae 00 14              cmp.l    $14(a6), d0
  f035fa: 66 1a                    bne.b    $f03616
  f035fc: 2a 05                    move.l   d5, d5
  f035fe: 2c 2b 00 08              move.l   $8(a3), d6
  f03602: 20 6e 00 36              movea.l  $36(a6), a0
  f03606: 61 00 e1 54              bsr.w    $f0175c
  f0360a: 4e 75                    rts      
  f0360c: 4e 71                    nop      
  f0360e: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f03614: 60 06                    bra.b    $f0361c

loc_F03616:
  f03616: 06 6e 00 0a 01 02        addi.w   #$a, $102(a6)

loc_F0361C:
  f0361c: 58 8f                    addq.l   #$4, a7
  f0361e: 4e 73                    rte      

TRAP1_RSTATE:
  f03620: 26 46                    movea.l  d6, a3
  f03622: 7a 60                    moveq    #$60, d5
  f03624: 61 00 ff ba              bsr.w    $f035e0
  f03628: 28 46                    movea.l  d6, a4
  f0362a: 43 ed 01 00              lea.l    $100(a5), a1
  f0362e: 30 3c 00 10              move.w   #$10, d0

loc_F03632:
  f03632: 28 d9                    move.l   (a1)+, (a4)+
  f03634: 53 40                    subq.w   #$1, d0
  f03636: 66 fa                    bne.b    $f03632
  f03638: 28 ed 00 fc              move.l   $fc(a5), (a4)+
  f0363c: 38 ed 00 fa              move.w   $fa(a5), (a4)+
  f03640: 20 2d 01 48              move.l   $148(a5), d0
  f03644: 02 80 01 ff ff ff        andi.l   #$1ffffff, d0
  f0364a: 28 c0                    move.l   d0, (a4)+
  f0364c: 28 ed 00 2c              move.l   $2c(a5), (a4)+
  f03650: 30 2d 01 48              move.w   $148(a5), d0
  f03654: 02 40 f8 00              andi.w   #$f800, d0
  f03658: 38 c0                    move.w   d0, (a4)+
  f0365a: 28 ed 01 50              move.l   $150(a5), (a4)+
  f0365e: 28 ed 01 54              move.l   $154(a5), (a4)+
  f03662: 28 ed 01 4c              move.l   $14c(a5), (a4)+
  f03666: 28 ed 01 58              move.l   $158(a5), (a4)+
  f0366a: 4e 73                    rte      

TRAP1_PSTATE:
  f0366c: 26 46                    movea.l  d6, a3
  f0366e: 08 2d 00 0a 00 2c        btst.b   #$a, $2c(a5)
  f03674: 66 08                    bne.b    $f0367e
  f03676: 06 6d 00 0a 01 02        addi.w   #$a, $102(a5)
  f0367c: 4e 73                    rte      

loc_F0367E:
  f0367e: 7a 4e                    moveq    #$4e, d5
  f03680: 61 00 ff 5e              bsr.w    $f035e0
  f03684: 28 46                    movea.l  d6, a4
  f03686: 43 ed 01 00              lea.l    $100(a5), a1
  f0368a: 30 3c 00 10              move.w   #$10, d0

loc_F0368E:
  f0368e: 22 dc                    move.l   (a4)+, (a1)+
  f03690: 53 40                    subq.w   #$1, d0
  f03692: 66 fa                    bne.b    $f0368e
  f03694: 2b 6d 01 00 00 74        move.l   $100(a5), $74(a5)
  f0369a: 2b 6d 01 20 00 94        move.l   $120(a5), $94(a5)
  f036a0: 2b 5c 00 fc              move.l   (a4)+, $fc(a5)
  f036a4: 30 1c                    move.w   (a4)+, d0
  f036a6: 1c 2d 01 48              move.b   $148(a5), d6
  f036aa: 2b 5c 01 48              move.l   (a4)+, $148(a5)
  f036ae: 02 2d 00 03 01 48        andi.b   #$3, $148(a5)
  f036b4: 02 06 00 f8              andi.b   #$f8, d6
  f036b8: 8d 2d 01 48              or.b     d6, $148(a5)
  f036bc: 1b 40 00 fb              move.b   d0, $fb(a5)
  f036c0: 4e 73                    rte      

TRAP1_REXMON:
  f036c2: 26 4c                    movea.l  a4, a3
  f036c4: 08 2d 00 0a 00 2c        btst.b   #$a, $2c(a5)
  f036ca: 66 08                    bne.b    $f036d4
  f036cc: 06 6d 00 0a 01 02        addi.w   #$a, $102(a5)
  f036d2: 4e 73                    rte      

loc_F036D4:
  f036d4: 7a 12                    moveq    #$12, d5
  f036d6: 61 00 ff 08              bsr.w    $f035e0
  f036da: 28 46                    movea.l  d6, a4
  f036dc: 08 ad 00 0f 00 fa        bclr.b   #$f, $fa(a5)
  f036e2: 2b 6c 00 02 01 50        move.l   $2(a4), $150(a5)
  f036e8: 2b 6c 00 06 01 54        move.l   $6(a4), $154(a5)
  f036ee: 2b 6c 00 0a 01 4c        move.l   $a(a4), $14c(a5)
  f036f4: 2b 6c 00 0e 01 58        move.l   $e(a4), $158(a5)
  f036fa: 42 6d 01 58              clr.w    $158(a5)
  f036fe: 02 2d 00 03 01 48        andi.b   #$3, $148(a5)
  f03704: 1e 14                    move.b   (a4), d7
  f03706: 02 07 00 38              andi.b   #$38, d7
  f0370a: 8f 2d 01 48              or.b     d7, $148(a5)
  f0370e: 4a 07                    tst.b    d7
  f03710: 67 3a                    beq.b    $f0374c
  f03712: 08 ed 00 0f 00 fa        bset.b   #$f, $fa(a5)
  f03718: 2e 2d 01 48              move.l   $148(a5), d7
  f0371c: 08 07 00 1d              btst.b   #$1d, d7
  f03720: 67 2a                    beq.b    $f0374c
  f03722: 7a 04                    moveq    #$4, d5
  f03724: 2c 2d 01 50              move.l   $150(a5), d6
  f03728: 20 6d 00 36              movea.l  $36(a5), a0
  f0372c: 61 00 e0 2e              bsr.w    $f0175c
  f03730: 60 0a                    bra.b    $f0373c
  f03732: 4e 71                    nop      
  f03734: 06 6e 00 0f 01 02        addi.w   #$f, $102(a6)
  f0373a: 4e 73                    rte      

loc_F0373C:
  f0373c: 08 86 00 00              bclr.b   #$0, d6
  f03740: 28 46                    movea.l  d6, a4
  f03742: 08 07 00 1c              btst.b   #$1c, d7
  f03746: 66 04                    bne.b    $f0374c
  f03748: 2b 54 01 54              move.l   (a4), $154(a5)

loc_F0374C:
  f0374c: 08 ad 00 0a 00 2c        bclr.b   #$a, $2c(a5)
  f03752: 30 2d 00 2c              move.w   $2c(a5), d0
  f03756: 02 40 ff 00              andi.w   #$ff00, d0
  f0375a: 66 06                    bne.b    $f03762
  f0375c: 41 d5                    lea.l    (a5), a0
  f0375e: 61 00 d0 9c              bsr.w    $f007fc

loc_F03762:
  f03762: 4e 73                    rte      

TRAP1_SNPTRC:
  f03764: 2c 08                    move.l   a0, d6
  f03766: 2a 48                    movea.l  a0, a5
  f03768: 22 79 00 00 0c 30        movea.l  $c30.l, a1
  f0376e: 20 09                    move.l   a1, d0
  f03770: 67 16                    beq.b    $f03788
  f03772: 20 69 00 04              movea.l  $4(a1), a0
  f03776: 91 c9                    suba.l   a1, a0
  f03778: 2a 08                    move.l   a0, d5
  f0377a: 24 08                    move.l   a0, d2
  f0377c: 20 6e 00 36              movea.l  $36(a6), a0
  f03780: 61 00 df da              bsr.w    $f0175c
  f03784: 60 0a                    bra.b    $f03790
  f03786: 4e 71                    nop      

loc_F03788:
  f03788: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f0378e: 4e 73                    rte      

loc_F03790:
  f03790: 24 46                    movea.l  d6, a2
  f03792: 26 02                    move.l   d2, d3
  f03794: e4 8a                    lsr.l    #$2, d2

loc_F03796:
  f03796: 24 d9                    move.l   (a1)+, (a2)+
  f03798: 53 82                    subq.l   #$1, d2
  f0379a: 66 fa                    bne.b    $f03796
  f0379c: 24 46                    movea.l  d6, a2
  f0379e: 28 4d                    movea.l  a5, a4
  f037a0: 22 79 00 00 0c 30        movea.l  $c30.l, a1
  f037a6: 26 51                    movea.l  (a1), a3
  f037a8: 97 c9                    suba.l   a1, a3
  f037aa: d9 cb                    adda.l   a3, a4
  f037ac: 24 cc                    move.l   a4, (a2)+
  f037ae: db c3                    adda.l   d3, a5
  f037b0: 24 cd                    move.l   a5, (a2)+
  f037b2: 4e 73                    rte      

TRAP1_STDTIM:
  f037b4: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f037ba: 66 08                    bne.b    $f037c4
  f037bc: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f037c2: 4e 73                    rte      

loc_F037C4:
  f037c4: 4c dc 00 03              movem.l  (a4)+, d0-d1
  f037c8: 2e 3c 05 26 5c 00        move.l   #$5265c00, d7

loc_F037CE:
  f037ce: b2 87                    cmp.l    d7, d1
  f037d0: 65 06                    bcs.b    $f037d8
  f037d2: 92 87                    sub.l    d7, d1
  f037d4: 52 80                    addq.l   #$1, d0
  f037d6: 60 f6                    bra.b    $f037ce

loc_F037D8:
  f037d8: 26 01                    move.l   d1, d3
  f037da: 28 00                    move.l   d0, d4
  f037dc: 00 7c 07 00              ori.w    #$700, sr
  f037e0: 96 b8 0c 42              sub.l    $c42.w, d3
  f037e4: 98 b8 0c 3e              sub.l    $c3e.w, d4
  f037e8: 21 c0 0c 3e              move.l   d0, $c3e.w
  f037ec: 21 c1 0c 42              move.l   d1, $c42.w
  f037f0: d7 b8 0c 46              add.l    d3, $c46.w
  f037f4: d9 b8 0c 4a              add.l    d4, $c4a.w
  f037f8: 46 d7                    move.w   (a7), sr
  f037fa: 42 a7                    clr.l    -(a7)
  f037fc: 22 78 0c 2c              movea.l  $c2c.w, a1
  f03800: 45 e9 00 08              lea.l    $8(a1), a2

loc_F03804:
  f03804: 26 4a                    movea.l  a2, a3

loc_F03806:
  f03806: 24 53                    movea.l  (a3), a2
  f03808: 20 0a                    move.l   a2, d0
  f0380a: 67 40                    beq.b    $f0384c
  f0380c: 08 2a 00 0f 00 14        btst.b   #$f, $14(a2)
  f03812: 67 32                    beq.b    $f03846
  f03814: 26 92                    move.l   (a2), (a3)
  f03816: 24 97                    move.l   (a7), (a2)
  f03818: 2e 8a                    move.l   a2, (a7)
  f0381a: 08 2a 00 00 00 15        btst.b   #$0, $15(a2)
  f03820: 66 e4                    bne.b    $f03806
  f03822: 20 2a 00 0c              move.l   $c(a2), d0
  f03826: 67 de                    beq.b    $f03806
  f03828: b2 aa 00 08              cmp.l    $8(a2), d1
  f0382c: 6e 0c                    bgt.b    $f0383a

loc_F0382E:
  f0382e: 91 aa 00 08              sub.l    d0, $8(a2)
  f03832: b2 aa 00 08              cmp.l    $8(a2), d1
  f03836: 67 ce                    beq.b    $f03806
  f03838: 6d f4                    blt.b    $f0382e

loc_F0383A:
  f0383a: d1 aa 00 08              add.l    d0, $8(a2)
  f0383e: b2 aa 00 08              cmp.l    $8(a2), d1
  f03842: 6e f6                    bgt.b    $f0383a
  f03844: 60 c0                    bra.b    $f03806

loc_F03846:
  f03846: d7 aa 00 08              add.l    d3, $8(a2)
  f0384a: 60 b8                    bra.b    $f03804

loc_F0384C:
  f0384c: 2e 1f                    move.l   (a7)+, d7
  f0384e: 67 10                    beq.b    $f03860

loc_F03850:
  f03850: 24 47                    movea.l  d7, a2
  f03852: 24 2a 00 08              move.l   $8(a2), d2
  f03856: 2e 12                    move.l   (a2), d7
  f03858: 61 00 d8 b2              bsr.w    $f0110c
  f0385c: 4a 87                    tst.l    d7
  f0385e: 66 f0                    bne.b    $f03850

loc_F03860:
  f03860: 4e 73                    rte      

TRAP1_GTDTIM:
  f03862: 61 00 d7 32              bsr.w    $f00f96
  f03866: 20 38 0c 3e              move.l   $c3e.w, d0
  f0386a: 0c 81 05 26 5c 00        cmpi.l   #$5265c00, d1
  f03870: 65 08                    bcs.b    $f0387a
  f03872: 04 81 05 26 5c 00        subi.l   #$5265c00, d1
  f03878: 52 80                    addq.l   #$1, d0

loc_F0387A:
  f0387a: 48 d4 00 03              movem.l  d0-d1, (a4)
  f0387e: 4e 73                    rte      

TRAP1_RQSTPA:
  f03880: 24 2c 00 0a              move.l   $a(a4), d2
  f03884: 36 2c 00 08              move.w   $8(a4), d3
  f03888: 7c 01                    moveq    #$1, d6
  f0388a: 42 84                    clr.l    d4
  f0388c: 08 03 00 0e              btst.b   #$e, d3
  f03890: 67 0e                    beq.b    $f038a0
  f03892: 28 2c 00 0e              move.l   $e(a4), d4
  f03896: 6e 08                    bgt.b    $f038a0
  f03898: 3d 7c 00 10 01 02        move.w   #$10, $102(a6)
  f0389e: 4e 73                    rte      

loc_F038A0:
  f038a0: 42 85                    clr.l    d5
  f038a2: 08 03 00 0a              btst.b   #$a, d3
  f038a6: 67 0a                    beq.b    $f038b2
  f038a8: 2a 2c 00 16              move.l   $16(a4), d5
  f038ac: 66 04                    bne.b    $f038b2
  f038ae: 08 c6 00 1f              bset.b   #$1f, d6

loc_F038B2:
  f038b2: 61 00 d6 e2              bsr.w    $f00f96
  f038b6: 02 43 c0 00              andi.w   #$c000, d3
  f038ba: 67 2a                    beq.b    $f038e6
  f038bc: 42 86                    clr.l    d6
  f038be: 36 2c 00 08              move.w   $8(a4), d3
  f038c2: 08 03 00 0b              btst.b   #$b, d3
  f038c6: 67 04                    beq.b    $f038cc
  f038c8: 08 83 00 0e              bclr.b   #$e, d3

loc_F038CC:
  f038cc: 08 03 00 0f              btst.b   #$f, d3
  f038d0: 67 18                    beq.b    $f038ea

loc_F038D2:
  f038d2: b4 81                    cmp.l    d1, d2
  f038d4: 6c 18                    bge.b    $f038ee
  f038d6: 4a 84                    tst.l    d4
  f038d8: 67 04                    beq.b    $f038de
  f038da: d4 84                    add.l    d4, d2
  f038dc: 60 f4                    bra.b    $f038d2

loc_F038DE:
  f038de: 06 82 05 26 5c 00        addi.l   #$5265c00, d2
  f038e4: 60 08                    bra.b    $f038ee

loc_F038E6:
  f038e6: 36 2c 00 08              move.w   $8(a4), d3

loc_F038EA:
  f038ea: 24 01                    move.l   d1, d2
  f038ec: d4 84                    add.l    d4, d2

loc_F038EE:
  f038ee: 2a 2c 00 16              move.l   $16(a4), d5
  f038f2: 08 03 00 0a              btst.b   #$a, d3
  f038f6: 66 02                    bne.b    $f038fa
  f038f8: 42 85                    clr.l    d5

loc_F038FA:
  f038fa: 22 78 0c 2c              movea.l  $c2c.w, a1
  f038fe: 45 e9 00 08              lea.l    $8(a1), a2

loc_F03902:
  f03902: 26 4a                    movea.l  a2, a3

loc_F03904:
  f03904: 24 53                    movea.l  (a3), a2
  f03906: 20 0a                    move.l   a2, d0
  f03908: 67 00 00 8c              beq.w    $f03996
  f0390c: 4a aa 00 04              tst.l    $4(a2)
  f03910: 66 08                    bne.b    $f0391a
  f03912: 26 92                    move.l   (a2), (a3)
  f03914: 61 00 d7 da              bsr.w    $f010f0
  f03918: 60 ea                    bra.b    $f03904

loc_F0391A:
  f0391a: bb ea 00 04              cmpa.l   $4(a2), a5
  f0391e: 66 e2                    bne.b    $f03902
  f03920: 08 2a 00 01 00 15        btst.b   #$1, $15(a2)
  f03926: 66 da                    bne.b    $f03902
  f03928: 4a 86                    tst.l    d6
  f0392a: 6b 06                    bmi.b    $f03932
  f0392c: ba aa 00 16              cmp.l    $16(a2), d5
  f03930: 66 d0                    bne.b    $f03902

loc_F03932:
  f03932: 26 92                    move.l   (a2), (a3)
  f03934: 4a 86                    tst.l    d6
  f03936: 66 24                    bne.b    $f0395c

loc_F03938:
  f03938: 25 4d 00 04              move.l   a5, $4(a2)
  f0393c: 25 44 00 0c              move.l   d4, $c(a2)
  f03940: 25 6c 00 12 00 10        move.l   $12(a4), $10(a2)
  f03946: 42 6a 00 1a              clr.w    $1a(a2)
  f0394a: 25 45 00 16              move.l   d5, $16(a2)
  f0394e: 08 c3 00 00              bset.b   #$0, d3
  f03952: 35 43 00 14              move.w   d3, $14(a2)
  f03956: 61 00 d7 b4              bsr.w    $f0110c
  f0395a: 4e 73                    rte      

loc_F0395C:
  f0395c: 52 46                    addq.w   #$1, d6
  f0395e: 08 03 00 01              btst.b   #$1, d3
  f03962: 66 08                    bne.b    $f0396c
  f03964: 08 2a 00 09 00 14        btst.b   #$9, $14(a2)
  f0396a: 67 1e                    beq.b    $f0398a

loc_F0396C:
  f0396c: 08 ea 00 07 00 1a        bset.b   #$7, $1a(a2)
  f03972: 08 aa 00 0e 00 14        bclr.b   #$e, $14(a2)
  f03978: 08 ea 00 01 00 15        bset.b   #$1, $15(a2)
  f0397e: 61 00 d7 8c              bsr.w    $f0110c
  f03982: 4a 86                    tst.l    d6
  f03984: 6b 00 ff 7e              bmi.w    $f03904
  f03988: 4e 73                    rte      

loc_F0398A:
  f0398a: 61 00 d7 64              bsr.w    $f010f0
  f0398e: 4a 86                    tst.l    d6
  f03990: 6b 00 ff 72              bmi.w    $f03904
  f03994: 4e 73                    rte      

loc_F03996:
  f03996: 4a 86                    tst.l    d6
  f03998: 66 1c                    bne.b    $f039b6
  f0399a: 00 7c 07 00              ori.w    #$700, sr
  f0399e: 20 29 00 04              move.l   $4(a1), d0
  f039a2: 67 0a                    beq.b    $f039ae
  f039a4: 24 40                    movea.l  d0, a2
  f039a6: 23 52 00 04              move.l   (a2), $4(a1)
  f039aa: 46 d7                    move.w   (a7), sr
  f039ac: 60 8a                    bra.b    $f03938

loc_F039AE:
  f039ae: 3d 7c 00 05 01 02        move.w   #$5, $102(a6)
  f039b4: 4e 73                    rte      

loc_F039B6:
  f039b6: 53 46                    subq.w   #$1, d6
  f039b8: 6e 06                    bgt.b    $f039c0
  f039ba: 3d 7c 00 07 01 02        move.w   #$7, $102(a6)

loc_F039C0:
  f039c0: 4e 73                    rte      

TRAP1_dir_3B:
  f039c2: 3d 7c 00 01 01 02        move.w   #$1, $102(a6)
  f039c8: 20 2e 01 20              move.l   $120(a6), d0
  f039cc: 0c 80 4b aa 7b fb        cmpi.l   #$4baa7bfb, d0
  f039d2: 66 3e                    bne.b    $f03a12
  f039d4: 4a 6e 00 70              tst.w    $70(a6)
  f039d8: 67 0c                    beq.b    $f039e6
  f039da: 20 78 0c 3a              movea.l  $c3a.w, a0
  f039de: 08 28 00 01 00 01        btst.b   #$1, $1(a0)
  f039e4: 66 2c                    bne.b    $f03a12

loc_F039E6:
  f039e6: 20 78 0c 08              movea.l  $c08.w, a0
  f039ea: 2c 20                    move.l   -(a0), d6
  f039ec: 7a 06                    moveq    #$6, d5
  f039ee: 20 6e 00 36              movea.l  $36(a6), a0
  f039f2: 61 00 dd 68              bsr.w    $f0175c
  f039f6: 60 04                    bra.b    $f039fc
  f039f8: 60 18                    bra.b    $f03a12
  f039fa: 60 16                    bra.b    $f03a12

loc_F039FC:
  f039fc: 2a 46                    movea.l  d6, a5
  f039fe: 42 ae 01 00              clr.l    $100(a6)
  f03a02: 4c ee 1f ff 01 00        movem.l  $100(a6), d0-d7/a0-a4
  f03a08: 4e 95                    jsr      (a5)
  f03a0a: 42 b8 0c 62              clr.l    $c62.w
  f03a0e: 2c 78 0c 0c              movea.l  $c0c.w, a6

loc_F03A12:
  f03a12: 4e 73                    rte      

TRAP1_SERVER:
  f03a14: 3e 2c 00 04              move.w   $4(a4), d7
  f03a18: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f03a1e: 66 04                    bne.b    $f03a24
  f03a20: 08 87 00 0e              bclr.b   #$e, d7

loc_F03A24:
  f03a24: 4a 94                    tst.l    (a4)
  f03a26: 67 18                    beq.b    $f03a40
  f03a28: 7a 04                    moveq    #$4, d5
  f03a2a: 2c 14                    move.l   (a4), d6
  f03a2c: 20 6e 00 36              movea.l  $36(a6), a0
  f03a30: 61 00 dd 2a              bsr.w    $f0175c
  f03a34: 60 0a                    bra.b    $f03a40
  f03a36: 4e 71                    nop      
  f03a38: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f03a3e: 4e 73                    rte      

loc_F03A40:
  f03a40: 4a ae 00 40              tst.l    $40(a6)
  f03a44: 66 06                    bne.b    $f03a4c
  f03a46: 58 6e 01 02              addq.w   #$4, $102(a6)
  f03a4a: 4e 73                    rte      

loc_F03A4C:
  f03a4c: 14 2c 00 04              move.b   $4(a4), d2
  f03a50: 02 82 00 00 00 0f        andi.l   #$f, d2
  f03a56: 45 f8 0c 9a              lea.l    $c9a.w, a2
  f03a5a: 4a 32 20 00              tst.b    (a2, d2.w)
  f03a5e: 67 06                    beq.b    $f03a66
  f03a60: 5c 6e 01 02              addq.w   #$6, $102(a6)
  f03a64: 60 3a                    bra.b    $f03aa0

loc_F03A66:
  f03a66: 15 bc 00 02 20 00        move.b   #$2, (a2, d2.w)
  f03a6c: 45 f8 0c aa              lea.l    $caa.w, a2
  f03a70: c4 fc 00 16              mulu.w   #$16, d2
  f03a74: 25 8e 20 00              move.l   a6, (a2, d2.w)
  f03a78: 25 ae 00 14 20 04        move.l   $14(a6), $4(a2, d2.w)
  f03a7e: 35 bc 00 01 20 08        move.w   #$1, $8(a2, d2.w)
  f03a84: 42 b2 20 0a              clr.l    $a(a2, d2.w)
  f03a88: 25 94 20 0e              move.l   (a4), $e(a2, d2.w)
  f03a8c: 42 72 20 12              clr.w    $12(a2, d2.w)
  f03a90: 35 87 20 14              move.w   d7, $14(a2, d2.w)
  f03a94: 02 32 00 60 20 14        andi.b   #$60, $14(a2, d2.w)
  f03a9a: 08 f2 00 0f 20 14        bset.b   #$f, $14(a2, d2.w)

loc_F03AA0:
  f03aa0: 4e 73                    rte      

TRAP1_DSERVE:
  f03aa2: 24 08                    move.l   a0, d2
  f03aa4: 02 82 00 00 00 0f        andi.l   #$f, d2
  f03aaa: 45 f8 0c 9a              lea.l    $c9a.w, a2
  f03aae: 0c 32 00 02 20 00        cmpi.b   #$2, (a2, d2.w)
  f03ab4: 66 10                    bne.b    $f03ac6
  f03ab6: 22 02                    move.l   d2, d1
  f03ab8: c2 fc 00 16              mulu.w   #$16, d1
  f03abc: 43 f8 0c aa              lea.l    $caa.w, a1
  f03ac0: bd f1 10 00              cmpa.l   (a1, d1.w), a6
  f03ac4: 67 06                    beq.b    $f03acc

loc_F03AC6:
  f03ac6: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f03aca: 60 62                    bra.b    $f03b2e

loc_F03ACC:
  f03acc: 26 78 0c 10              movea.l  $c10.w, a3

loc_F03AD0:
  f03ad0: 08 2b 00 0b 00 2c        btst.b   #$b, $2c(a3)
  f03ad6: 67 2c                    beq.b    $f03b04
  f03ad8: b4 2b 00 73              cmp.b    $73(a3), d2
  f03adc: 66 26                    bne.b    $f03b04
  f03ade: 08 ab 00 02 00 2d        bclr.b   #$2, $2d(a3)
  f03ae4: 08 ab 00 0b 00 2c        bclr.b   #$b, $2c(a3)
  f03aea: 27 7c 00 00 00 01 01 00  move.l   #$1, $100(a3)
  f03af2: e7 4a                    lsl.w    #$3, d2
  f03af4: 17 42 01 00              move.b   d2, $100(a3)
  f03af8: 42 2b 00 fb              clr.b    $fb(a3)
  f03afc: e6 4a                    lsr.w    #$3, d2
  f03afe: 41 d3                    lea.l    (a3), a0
  f03b00: 61 00 cc be              bsr.w    $f007c0

loc_F03B04:
  f03b04: 26 6b 00 04              movea.l  $4(a3), a3
  f03b08: 20 0b                    move.l   a3, d0
  f03b0a: 66 c4                    bne.b    $f03ad0
  f03b0c: 42 32 20 00              clr.b    (a2, d2.w)
  f03b10: 42 b1 10 00              clr.l    (a1, d1.w)
  f03b14: 42 b1 10 0e              clr.l    $e(a1, d1.w)
  f03b18: 42 71 10 14              clr.w    $14(a1, d1.w)

loc_F03B1C:
  f03b1c: 08 31 00 0e 10 08        btst.b   #$e, $8(a1, d1.w)
  f03b22: 67 0a                    beq.b    $f03b2e
  f03b24: 41 f1 10 08              lea.l    $8(a1, d1.w), a0
  f03b28: 61 00 cc 5e              bsr.w    $f00788
  f03b2c: 60 ee                    bra.b    $f03b1c

loc_F03B2E:
  f03b2e: 4e 73                    rte      

TRAP0_dir_0F_bsr:
  f03b30: 40 e7                    move.w   sr, -(a7)

TRAP0_dir_0F:
  f03b32: 45 f8 0c 9a              lea.l    $c9a.w, a2
  f03b36: 43 f8 0c aa              lea.l    $caa.w, a1
  f03b3a: 74 02                    moveq    #$2, d2

loc_F03B3C:
  f03b3c: 0c 32 00 02 20 00        cmpi.b   #$2, (a2, d2.w)
  f03b42: 66 0c                    bne.b    $f03b50
  f03b44: 22 02                    move.l   d2, d1
  f03b46: c2 fc 00 16              mulu.w   #$16, d1
  f03b4a: b9 f1 10 00              cmpa.l   (a1, d1.w), a4
  f03b4e: 67 0c                    beq.b    $f03b5c

loc_F03B50:
  f03b50: 52 82                    addq.l   #$1, d2
  f03b52: 0c 82 00 00 00 10        cmpi.l   #$10, d2
  f03b58: 6d e2                    blt.b    $f03b3c
  f03b5a: 4e 73                    rte      

loc_F03B5C:
  f03b5c: 61 02                    bsr.b    $f03b60
  f03b5e: 60 dc                    bra.b    $f03b3c

loc_F03B60:
  f03b60: 40 e7                    move.w   sr, -(a7)
  f03b62: 60 00 ff 68              bra.w    $f03acc

TRAP1_DERQST:
  f03b66: 22 08                    move.l   a0, d1
  f03b68: 02 81 00 00 00 0f        andi.l   #$f, d1
  f03b6e: 20 08                    move.l   a0, d0
  f03b70: 43 f8 0c 9a              lea.l    $c9a.w, a1
  f03b74: 0c 31 00 02 10 00        cmpi.b   #$2, (a1, d1.w)
  f03b7a: 66 12                    bne.b    $f03b8e
  f03b7c: c2 fc 00 16              mulu.w   #$16, d1
  f03b80: 43 f8 0c aa              lea.l    $caa.w, a1
  f03b84: 24 31 10 04              move.l   $4(a1, d1.w), d2
  f03b88: b4 ae 00 14              cmp.l    $14(a6), d2
  f03b8c: 67 06                    beq.b    $f03b94

loc_F03B8E:
  f03b8e: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f03b92: 4e 73                    rte      

loc_F03B94:
  f03b94: 08 00 00 07              btst.b   #$7, d0
  f03b98: 66 20                    bne.b    $f03bba

loc_F03B9A:
  f03b9a: 4a f1 10 08              tas.b    $8(a1, d1.w)
  f03b9e: 6b fa                    bmi.b    $f03b9a
  f03ba0: 08 b1 00 0f 10 14        bclr.b   #$f, $14(a1, d1.w)
  f03ba6: 08 31 00 0e 10 08        btst.b   #$e, $8(a1, d1.w)
  f03bac: 66 04                    bne.b    $f03bb2
  f03bae: 42 71 10 08              clr.w    $8(a1, d1.w)

loc_F03BB2:
  f03bb2: 08 b1 00 0f 10 08        bclr.b   #$f, $8(a1, d1.w)
  f03bb8: 4e 73                    rte      

loc_F03BBA:
  f03bba: 08 f1 00 0f 10 14        bset.b   #$f, $14(a1, d1.w)
  f03bc0: 08 b1 00 0c 10 14        bclr.b   #$c, $14(a1, d1.w)
  f03bc6: 67 08                    beq.b    $f03bd0
  f03bc8: 41 f1 10 08              lea.l    $8(a1, d1.w), a0
  f03bcc: 61 00 cb ba              bsr.w    $f00788

loc_F03BD0:
  f03bd0: 4e 73                    rte      

TRAP1_AKRQST:
  f03bd2: 08 2d 00 0b 00 2c        btst.b   #$b, $2c(a5)
  f03bd8: 66 10                    bne.b    $f03bea
  f03bda: 08 2d 00 02 00 2d        btst.b   #$2, $2d(a5)
  f03be0: 66 08                    bne.b    $f03bea

loc_F03BE2:
  f03be2: 06 6e 00 0a 01 02        addi.w   #$a, $102(a6)
  f03be8: 4e 73                    rte      

loc_F03BEA:
  f03bea: 12 2c 00 0a              move.b   $a(a4), d1
  f03bee: 02 41 00 0f              andi.w   #$f, d1
  f03bf2: b2 2d 00 73              cmp.b    $73(a5), d1
  f03bf6: 67 08                    beq.b    $f03c00
  f03bf8: 08 2d 00 07 00 2d        btst.b   #$7, $2d(a5)
  f03bfe: 67 e2                    beq.b    $f03be2

loc_F03C00:
  f03c00: c2 fc 00 16              mulu.w   #$16, d1
  f03c04: 47 f8 0c aa              lea.l    $caa.w, a3
  f03c08: 24 33 10 04              move.l   $4(a3, d1.w), d2
  f03c0c: b4 ae 00 14              cmp.l    $14(a6), d2
  f03c10: 67 06                    beq.b    $f03c18
  f03c12: 5e 6e 01 02              addq.w   #$7, $102(a6)
  f03c16: 4e 73                    rte      

loc_F03C18:
  f03c18: 3e 2c 00 08              move.w   $8(a4), d7
  f03c1c: 08 2d 00 07 00 2d        btst.b   #$7, $2d(a5)
  f03c22: 67 1e                    beq.b    $f03c42
  f03c24: 02 47 0f ff              andi.w   #$fff, d7
  f03c28: 08 07 00 08              btst.b   #$8, d7
  f03c2c: 67 14                    beq.b    $f03c42
  f03c2e: 08 ad 00 02 00 2d        bclr.b   #$2, $2d(a5)
  f03c34: 67 1a                    beq.b    $f03c50
  f03c36: 08 2d 00 0b 00 2c        btst.b   #$b, $2c(a5)
  f03c3c: 67 12                    beq.b    $f03c50
  f03c3e: 53 73 10 12              subq.w   #$1, $12(a3, d1.w)

loc_F03C42:
  f03c42: 08 ad 00 02 00 2d        bclr.b   #$2, $2d(a5)
  f03c48: 66 06                    bne.b    $f03c50
  f03c4a: 08 ad 00 0b 00 2c        bclr.b   #$b, $2c(a5)

loc_F03C50:
  f03c50: 53 73 10 12              subq.w   #$1, $12(a3, d1.w)
  f03c54: 08 33 00 0f 10 14        btst.b   #$f, $14(a3, d1.w)
  f03c5a: 67 10                    beq.b    $f03c6c
  f03c5c: 08 b3 00 0c 10 14        bclr.b   #$c, $14(a3, d1.w)
  f03c62: 67 08                    beq.b    $f03c6c
  f03c64: 41 f3 10 08              lea.l    $8(a3, d1.w), a0
  f03c68: 61 00 cb 1e              bsr.w    $f00788

loc_F03C6C:
  f03c6c: 08 07 00 0e              btst.b   #$e, d7
  f03c70: 67 06                    beq.b    $f03c78
  f03c72: 1b 6c 00 0b 00 fb        move.b   $b(a4), $fb(a5)

loc_F03C78:
  f03c78: 08 07 00 0d              btst.b   #$d, d7
  f03c7c: 67 06                    beq.b    $f03c84
  f03c7e: 2b 6c 00 0c 01 00        move.l   $c(a4), $100(a5)

loc_F03C84:
  f03c84: 08 07 00 0c              btst.b   #$c, d7
  f03c88: 67 06                    beq.b    $f03c90
  f03c8a: 2b 6c 00 10 01 20        move.l   $10(a4), $120(a5)

loc_F03C90:
  f03c90: 08 07 00 0b              btst.b   #$b, d7
  f03c94: 67 10                    beq.b    $f03ca6

loc_F03C96:
  f03c96: 08 2d 00 0b 00 2c        btst.b   #$b, $2c(a5)
  f03c9c: 66 06                    bne.b    $f03ca4
  f03c9e: 41 d5                    lea.l    (a5), a0
  f03ca0: 61 00 cb 5a              bsr.w    $f007fc

loc_F03CA4:
  f03ca4: 4e 73                    rte      

loc_F03CA6:
  f03ca6: 08 07 00 0a              btst.b   #$a, d7
  f03caa: 67 08                    beq.b    $f03cb4
  f03cac: 08 ed 00 0e 00 2c        bset.b   #$e, $2c(a5)
  f03cb2: 4e 73                    rte      

loc_F03CB4:
  f03cb4: 08 07 00 09              btst.b   #$9, d7
  f03cb8: 67 dc                    beq.b    $f03c96
  f03cba: 08 ed 00 09 00 2c        bset.b   #$9, $2c(a5)
  f03cc0: 4e 73                    rte      

TRAP1_TSKINFO:
  f03cc2: 08 2e 00 0f 00 28        btst.b   #$f, $28(a6)
  f03cc8: 66 08                    bne.b    $f03cd2
  f03cca: 06 6e 00 09 01 02        addi.w   #$9, $102(a6)
  f03cd0: 4e 73                    rte      

loc_F03CD2:
  f03cd2: 2a 3c 00 00 02 00        move.l   #$200, d5
  f03cd8: 2c 2c 00 0a              move.l   $a(a4), d6
  f03cdc: 20 6e 00 36              movea.l  $36(a6), a0
  f03ce0: 61 00 da 7a              bsr.w    $f0175c
  f03ce4: 60 0a                    bra.b    $f03cf0
  f03ce6: 4e 71                    nop      
  f03ce8: 06 6e 00 0c 01 02        addi.w   #$c, $102(a6)
  f03cee: 4e 73                    rte      

loc_F03CF0:
  f03cf0: 08 2c 00 0f 00 08        btst.b   #$f, $8(a4)
  f03cf6: 66 08                    bne.b    $f03d00
  f03cf8: 06 6e 00 0f 01 02        addi.w   #$f, $102(a6)
  f03cfe: 4e 73                    rte      

loc_F03D00:
  f03d00: 26 46                    movea.l  d6, a3
  f03d02: 70 7f                    moveq    #$7f, d0

loc_F03D04:
  f03d04: 26 dd                    move.l   (a5)+, (a3)+
  f03d06: 51 c8 ff fc              dbra     d0, $f03d04
  f03d0a: 4e 73                    rte      

TRAP1_CMR:
  f03d0c: 2c 08                    move.l   a0, d6
  f03d0e: 08 06 00 00              btst.b   #$0, d6
  f03d12: 66 10                    bne.b    $f03d24
  f03d14: 7a 08                    moveq    #$8, d5
  f03d16: 2e 08                    move.l   a0, d7
  f03d18: 20 6e 00 36              movea.l  $36(a6), a0
  f03d1c: 61 00 da 3e              bsr.w    $f0175c
  f03d20: 60 08                    bra.b    $f03d2a
  f03d22: 4e 71                    nop      

loc_F03D24:
  f03d24: 70 02                    moveq    #$2, d0
  f03d26: 61 00 06 4e              bsr.w    $f04376

loc_F03D2A:
  f03d2a: 24 46                    movea.l  d6, a2
  f03d2c: 22 2a 00 04              move.l   $4(a2), d1
  f03d30: 66 06                    bne.b    $f03d38
  f03d32: 70 0b                    moveq    #$b, d0
  f03d34: 61 00 06 40              bsr.w    $f04376

loc_F03D38:
  f03d38: 41 f8 0c 8e              lea.l    $c8e.w, a0
  f03d3c: 41 f8 0c 8e              lea.l    $c8e.w, a0
  f03d40: 61 00 c9 a6              bsr.w    $f006e8
  f03d44: 47 f8 0c 18              lea.l    $c18.w, a3

loc_F03D48:
  f03d48: 22 53                    movea.l  (a3), a1
  f03d4a: 4a 93                    tst.l    (a3)
  f03d4c: 67 0e                    beq.b    $f03d5c
  f03d4e: b2 a9 00 14              cmp.l    $14(a1), d1
  f03d52: 67 00 02 c8              beq.w    $f0401c
  f03d56: 47 e9 00 04              lea.l    $4(a1), a3
  f03d5a: 60 ec                    bra.b    $f03d48

loc_F03D5C:
  f03d5c: 0c 12 00 01              cmpi.b   #$1, (a2)
  f03d60: 66 00 02 ae              bne.w    $f04010
  f03d64: 2c 07                    move.l   d7, d6
  f03d66: 20 6e 00 36              movea.l  $36(a6), a0
  f03d6a: 42 85                    clr.l    d5
  f03d6c: 1a 2a 00 1b              move.b   $1b(a2), d5
  f03d70: e7 8d                    lsl.l    #$3, d5
  f03d72: 06 45 00 1c              addi.w   #$1c, d5
  f03d76: 61 00 d9 e4              bsr.w    $f0175c
  f03d7a: 60 06                    bra.b    $f03d82
  f03d7c: 4e 71                    nop      
  f03d7e: 60 00 02 98              bra.w    $f04018

loc_F03D82:
  f03d82: 42 80                    clr.l    d0
  f03d84: 10 2a 00 18              move.b   $18(a2), d0
  f03d88: 0c 00 00 19              cmpi.b   #$19, d0
  f03d8c: 65 0c                    bcs.b    $f03d9a
  f03d8e: 0c 00 00 1f              cmpi.b   #$1f, d0
  f03d92: 63 0c                    bls.b    $f03da0
  f03d94: 0c 00 00 40              cmpi.b   #$40, d0
  f03d98: 64 06                    bcc.b    $f03da0

loc_F03D9A:
  f03d9a: 70 cb                    moveq    #$cb, d0
  f03d9c: 61 00 00 84              bsr.w    $f03e22

loc_F03DA0:
  f03da0: 72 0c                    moveq    #$c, d1
  f03da2: c2 6a 00 02              and.w    $2(a2), d1
  f03da6: 0c 41 00 0c              cmpi.w   #$c, d1
  f03daa: 66 04                    bne.b    $f03db0
  f03dac: 70 0b                    moveq    #$b, d0
  f03dae: 61 72                    bsr.b    $f03e22

loc_F03DB0:
  f03db0: 22 78 0c 66              movea.l  $c66.w, a1
  f03db4: 4a 31 00 00              tst.b    (a1, d0.w)
  f03db8: 67 0e                    beq.b    $f03dc8
  f03dba: 6a 00 03 a6              bpl.w    $f04162
  f03dbe: 08 2a 00 02 00 03        btst.b   #$2, $3(a2)
  f03dc4: 66 00 03 9c              bne.w    $f04162

loc_F03DC8:
  f03dc8: 0c 2a 00 ff 00 08        cmpi.b   #$ff, $8(a2)
  f03dce: 67 0a                    beq.b    $f03dda
  f03dd0: 4a aa 00 0a              tst.l    $a(a2)
  f03dd4: 66 04                    bne.b    $f03dda
  f03dd6: 70 c7                    moveq    #$c7, d0
  f03dd8: 61 48                    bsr.b    $f03e22

loc_F03DDA:
  f03dda: 0c 2a 00 07 00 19        cmpi.b   #$7, $19(a2)
  f03de0: 62 08                    bhi.b    $f03dea
  f03de2: 0c 2a 00 01 00 19        cmpi.b   #$1, $19(a2)
  f03de8: 64 04                    bcc.b    $f03dee

loc_F03DEA:
  f03dea: 70 cc                    moveq    #$cc, d0
  f03dec: 61 34                    bsr.b    $f03e22

loc_F03DEE:
  f03dee: 47 ea 00 1c              lea.l    $1c(a2), a3
  f03df2: 42 85                    clr.l    d5
  f03df4: 1a 2a 00 1b              move.b   $1b(a2), d5
  f03df8: 67 30                    beq.b    $f03e2a
  f03dfa: 0c 05 00 04              cmpi.b   #$4, d5
  f03dfe: 6f 04                    ble.b    $f03e04
  f03e00: 70 ce                    moveq    #$ce, d0
  f03e02: 61 1e                    bsr.b    $f03e22

loc_F03E04:
  f03e04: 53 85                    subq.l   #$1, d5
  f03e06: e7 8d                    lsl.l    #$3, d5
  f03e08: 32 2a 00 16              move.w   $16(a2), d1

loc_F03E0C:
  f03e0c: b2 73 50 00              cmp.w    (a3, d5.w), d1
  f03e10: 64 04                    bcc.b    $f03e16
  f03e12: 70 cf                    moveq    #$cf, d0
  f03e14: 61 0c                    bsr.b    $f03e22

loc_F03E16:
  f03e16: b2 73 50 04              cmp.w    $4(a3, d5.w), d1
  f03e1a: 64 0a                    bcc.b    $f03e26
  f03e1c: 70 cf                    moveq    #$cf, d0
  f03e1e: 61 00 05 48              bsr.w    $f04368

loc_F03E22:
  f03e22: 60 00 05 44              bra.w    $f04368

loc_F03E26:
  f03e26: 51 85                    subq.l   #$8, d5
  f03e28: 6c e2                    bge.b    $f03e0c

loc_F03E2A:
  f03e2a: 20 2a 00 12              move.l   $12(a2), d0
  f03e2e: 20 40                    movea.l  d0, a0
  f03e30: 08 00 00 00              btst.b   #$0, d0
  f03e34: 66 02                    bne.b    $f03e38
  f03e36: 52 88                    addq.l   #$1, a0

loc_F03E38:
  f03e38: 2f 3c 00 f0 3e 48        move.l   #$f03e48, -(a7)
  f03e3e: 3f 3c 42 45              move.w   #$4245, -(a7)
  f03e42: 12 10                    move.b   (a0), d1
  f03e44: 5c 8f                    addq.l   #$6, a7
  f03e46: 60 04                    bra.b    $f03e4c

loc_F03E48:
  f03e48: 70 c9                    moveq    #$c9, d0
  f03e4a: 61 d6                    bsr.b    $f03e22

loc_F03E4C:
  f03e4c: 47 f8 0c 18              lea.l    $c18.w, a3
  f03e50: 70 18                    moveq    #$18, d0
  f03e52: c0 6a 00 02              and.w    $2(a2), d0
  f03e56: 0c 00 00 18              cmpi.b   #$18, d0
  f03e5a: 66 04                    bne.b    $f03e60
  f03e5c: 70 0b                    moveq    #$b, d0
  f03e5e: 61 c2                    bsr.b    $f03e22

loc_F03E60:
  f03e60: 0c 00 00 08              cmpi.b   #$8, d0
  f03e64: 66 3e                    bne.b    $f03ea4
  f03e66: 20 2a 00 0e              move.l   $e(a2), d0

loc_F03E6A:
  f03e6a: 28 53                    movea.l  (a3), a4
  f03e6c: 4a 93                    tst.l    (a3)
  f03e6e: 66 04                    bne.b    $f03e74
  f03e70: 70 0b                    moveq    #$b, d0
  f03e72: 61 ae                    bsr.b    $f03e22

loc_F03E74:
  f03e74: 47 ec 00 04              lea.l    $4(a4), a3
  f03e78: b0 ac 00 14              cmp.l    $14(a4), d0
  f03e7c: 66 ec                    bne.b    $f03e6a
  f03e7e: 10 2a 00 18              move.b   $18(a2), d0
  f03e82: 08 2c 00 02 00 49        btst.b   #$2, $49(a4)
  f03e88: 67 06                    beq.b    $f03e90
  f03e8a: b0 2c 00 28              cmp.b    $28(a4), d0
  f03e8e: 67 04                    beq.b    $f03e94

loc_F03E90:
  f03e90: 70 0b                    moveq    #$b, d0
  f03e92: 61 8e                    bsr.b    $f03e22

loc_F03E94:
  f03e94: 0c ac 00 00 00 00 00 10  cmpi.l   #$0, $10(a4)
  f03e9c: 67 06                    beq.b    $f03ea4
  f03e9e: 28 6c 00 10              movea.l  $10(a4), a4
  f03ea2: 60 f0                    bra.b    $f03e94

loc_F03EA4:
  f03ea4: 22 53                    movea.l  (a3), a1
  f03ea6: 4a 93                    tst.l    (a3)
  f03ea8: 67 06                    beq.b    $f03eb0
  f03eaa: 47 e9 00 04              lea.l    $4(a1), a3
  f03eae: 60 f4                    bra.b    $f03ea4

loc_F03EB0:
  f03eb0: 20 6a 00 0a              movea.l  $a(a2), a0
  f03eb4: 70 00                    moveq    #$0, d0
  f03eb6: 10 28 00 10              move.b   $10(a0), d0
  f03eba: 52 40                    addq.w   #$1, d0
  f03ebc: 20 40                    movea.l  d0, a0
  f03ebe: 48 e7 80 38              movem.l  d0/a2-a4, -(a7)
  f03ec2: 61 00 d3 7a              bsr.w    $f0123e
  f03ec6: 60 0a                    bra.b    $f03ed2
  f03ec8: 4c df 1c 01              movem.l  (a7)+, d0/a2-a4
  f03ecc: 70 08                    moveq    #$8, d0
  f03ece: 61 00 ff 52              bsr.w    $f03e22

loc_F03ED2:
  f03ed2: 4c df 1c 01              movem.l  (a7)+, d0/a2-a4
  f03ed6: 22 48                    movea.l  a0, a1
  f03ed8: ed 88                    lsl.l    #$6, d0

loc_F03EDA:
  f03eda: 42 98                    clr.l    (a0)+
  f03edc: 53 80                    subq.l   #$1, d0
  f03ede: 6e fa                    bgt.b    $f03eda
  f03ee0: 08 2a 00 03 00 03        btst.b   #$3, $3(a2)
  f03ee6: 67 04                    beq.b    $f03eec
  f03ee8: 29 49 00 10              move.l   a1, $10(a4)

loc_F03EEC:
  f03eec: 26 89                    move.l   a1, (a3)
  f03eee: 22 bc 21 43 43 42        move.l   #$21434342, (a1)
  f03ef4: 08 2a 00 00 00 03        btst.b   #$0, $3(a2)
  f03efa: 67 06                    beq.b    $f03f02
  f03efc: 00 69 00 01 00 48        ori.w    #$1, $48(a1)

loc_F03F02:
  f03f02: 4c ea 00 3f 00 04        movem.l  $4(a2), d0-d5
  f03f08: 48 e9 00 3f 00 14        movem.l  d0-d5, $14(a1)
  f03f0e: 10 29 00 29              move.b   $29(a1), d0
  f03f12: 04 00 00 e0              subi.b   #$e0, d0
  f03f16: e1 88                    lsl.l    #$8, d0
  f03f18: 33 40 00 42              move.w   d0, $42(a1)
  f03f1c: 04 40 01 00              subi.w   #$100, d0
  f03f20: 33 40 00 40              move.w   d0, $40(a1)
  f03f24: 47 ea 00 1c              lea.l    $1c(a2), a3
  f03f28: 49 e9 00 70              lea.l    $70(a1), a4
  f03f2c: 10 29 00 2b              move.b   $2b(a1), d0

loc_F03F30:
  f03f30: 67 08                    beq.b    $f03f3a
  f03f32: 28 db                    move.l   (a3)+, (a4)+
  f03f34: 28 db                    move.l   (a3)+, (a4)+
  f03f36: 53 00                    subq.b   #$1, d0
  f03f38: 60 f6                    bra.b    $f03f30

loc_F03F3A:
  f03f3a: 42 80                    clr.l    d0
  f03f3c: 10 2a 00 18              move.b   $18(a2), d0
  f03f40: e5 88                    lsl.l    #$2, d0
  f03f42: 23 40 00 44              move.l   d0, $44(a1)
  f03f46: 26 6a 00 0a              movea.l  $a(a2), a3
  f03f4a: d7 d3                    adda.l   (a3), a3
  f03f4c: 23 4b 00 1e              move.l   a3, $1e(a1)
  f03f50: 0c 29 00 ff 00 18        cmpi.b   #$ff, $18(a1)
  f03f56: 66 08                    bne.b    $f03f60
  f03f58: 23 7c 00 f0 43 ee 00 1e  move.l   #$f043ee, $1e(a1)

loc_F03F60:
  f03f60: 08 2a 00 04 00 03        btst.b   #$4, $3(a2)
  f03f66: 67 06                    beq.b    $f03f6e
  f03f68: 08 e9 00 02 00 49        bset.b   #$2, $49(a1)

loc_F03F6E:
  f03f6e: 08 2a 00 02 00 03        btst.b   #$2, $3(a2)
  f03f74: 67 08                    beq.b    $f03f7e
  f03f76: 08 e9 00 00 00 48        bset.b   #$0, $48(a1)
  f03f7c: 60 52                    bra.b    $f03fd0

loc_F03F7E:
  f03f7e: 08 2a 00 03 00 03        btst.b   #$3, $3(a2)
  f03f84: 66 62                    bne.b    $f03fe8
  f03f86: 42 80                    clr.l    d0
  f03f88: 10 2a 00 18              move.b   $18(a2), d0
  f03f8c: 26 78 0c 66              movea.l  $c66.w, a3
  f03f90: 4a 33 08 00              tst.b    (a3, d0.l)
  f03f94: 67 3a                    beq.b    $f03fd0
  f03f96: 28 69 00 44              movea.l  $44(a1), a4
  f03f9a: 20 0c                    move.l   a4, d0
  f03f9c: 26 54                    movea.l  (a4), a3
  f03f9e: 47 eb ff b6              lea.l    -$4a(a3), a3
  f03fa2: 12 2a 00 1a              move.b   $1a(a2), d1
  f03fa6: 60 0a                    bra.b    $f03fb2

loc_F03FA8:
  f03fa8: 26 6c 00 08              movea.l  $8(a4), a3
  f03fac: 4a ac 00 08              tst.l    $8(a4)
  f03fb0: 67 0c                    beq.b    $f03fbe

loc_F03FB2:
  f03fb2: 14 2b 00 2a              move.b   $2a(a3), d2
  f03fb6: b2 02                    cmp.b    d2, d1
  f03fb8: 6e 04                    bgt.b    $f03fbe
  f03fba: 28 4b                    movea.l  a3, a4
  f03fbc: 60 ea                    bra.b    $f03fa8

loc_F03FBE:
  f03fbe: b9 c0                    cmpa.l   d0, a4
  f03fc0: 67 0a                    beq.b    $f03fcc
  f03fc2: 23 4b 00 08              move.l   a3, $8(a1)
  f03fc6: 29 49 00 08              move.l   a1, $8(a4)
  f03fca: 60 1c                    bra.b    $f03fe8

loc_F03FCC:
  f03fcc: 23 4b 00 08              move.l   a3, $8(a1)

loc_F03FD0:
  f03fd0: 26 69 00 44              movea.l  $44(a1), a3
  f03fd4: 33 7c 4e b9 00 4a        move.w   #$4eb9, $4a(a1)
  f03fda: 23 7c 00 f0 44 a2 00 4c  move.l   #$f044a2, $4c(a1)
  f03fe2: 49 e9 00 4a              lea.l    $4a(a1), a4
  f03fe6: 26 8c                    move.l   a4, (a3)

loc_F03FE8:
  f03fe8: 42 80                    clr.l    d0
  f03fea: 10 2a 00 18              move.b   $18(a2), d0
  f03fee: 20 78 0c 66              movea.l  $c66.w, a0
  f03ff2: 11 bc 00 ff 00 00        move.b   #$ff, (a0, d0.w)
  f03ff8: 20 69 00 1a              movea.l  $1a(a1), a0
  f03ffc: d1 e8 00 08              adda.l   $8(a0), a0
  f04000: 2a 49                    movea.l  a1, a5
  f04002: 2f 0e                    move.l   a6, -(a7)
  f04004: 4e 90                    jsr      (a0)
  f04006: 2c 5f                    movea.l  (a7)+, a6
  f04008: 60 00 03 74              bra.w    $f0437e

loc_F0400C:
  f0400c: 60 00 03 5a              bra.w    $f04368

loc_F04010:
  f04010: 70 0b                    moveq    #$b, d0
  f04012: 61 f8                    bsr.b    $f0400c

loc_F04014:
  f04014: 70 09                    moveq    #$9, d0
  f04016: 61 f4                    bsr.b    $f0400c

loc_F04018:
  f04018: 70 02                    moveq    #$2, d0
  f0401a: 61 f0                    bsr.b    $f0400c

loc_F0401C:
  f0401c: 0c 12 00 01              cmpi.b   #$1, (a2)
  f04020: 67 00 01 40              beq.w    $f04162
  f04024: 6f 06                    ble.b    $f0402c
  f04026: 0c 12 00 07              cmpi.b   #$7, (a2)
  f0402a: 6f 04                    ble.b    $f04030

loc_F0402C:
  f0402c: 70 c1                    moveq    #$c1, d0
  f0402e: 61 dc                    bsr.b    $f0400c

loc_F04030:
  f04030: 20 6e 00 36              movea.l  $36(a6), a0
  f04034: 42 80                    clr.l    d0
  f04036: 10 12                    move.b   (a2), d0
  f04038: 53 00                    subq.b   #$1, d0
  f0403a: 26 40                    movea.l  d0, a3
  f0403c: 42 85                    clr.l    d5
  f0403e: 0c 12 00 07              cmpi.b   #$7, (a2)
  f04042: 66 20                    bne.b    $f04064
  f04044: 0c 29 00 10 00 18        cmpi.b   #$10, $18(a1)
  f0404a: 65 32                    bcs.b    $f0407e
  f0404c: 0c 29 00 7f 00 18        cmpi.b   #$7f, $18(a1)
  f04052: 63 10                    bls.b    $f04064
  f04054: 0c 29 00 80 00 18        cmpi.b   #$80, $18(a1)
  f0405a: 65 22                    bcs.b    $f0407e
  f0405c: 0c 29 00 8f 00 18        cmpi.b   #$8f, $18(a1)
  f04062: 62 1a                    bhi.b    $f0407e

loc_F04064:
  f04064: 1a 3b b0 10              move.b   $f04076(pc, a3.w), d5
  f04068: 67 14                    beq.b    $f0407e
  f0406a: 2c 07                    move.l   d7, d6
  f0406c: 61 00 d6 ee              bsr.w    $f0175c
  f04070: 60 0c                    bra.b    $f0407e
  f04072: 4e 71                    nop      
  f04074: 60 a2                    bra.b    $f04018
  f04076: 00 08                    DC.W     $0008
  f04078: 12 08                    DC.W     $1208
  f0407a: 08 08                    DC.W     $0808
  f0407c: 18 00                    move.b   d0, d4

loc_F0407E:
  f0407e: d7 cb                    adda.l   a3, a3
  f04080: 47 fb b0 06              lea.l    $f04088(pc, a3.w), a3
  f04084: d6 d3                    adda.w   (a3), a3
  f04086: 4e d3                    jmp      (a3)
  f04088: ff fe                    DC.W     $fffe
  f0408a: 00 0c                    DC.W     $000c
  f0408c: 00 cc                    DC.W     $00cc
  f0408e: 01 a2                    bclr.b   d0, -(a2)
  f04090: 01 da                    bset.b   d0, (a2)+
  f04092: 01 f0 02 12              bset.b   d0, $12(a0, d0.w)
  f04096: 20 2a 00 04              move.l   $4(a2), d0
  f0409a: 61 00 02 b2              bsr.w    $f0434e
  f0409e: 66 00 00 b4              bne.w    $f04154
  f040a2: 20 a9 00 0c              move.l   $c(a1), (a0)
  f040a6: 08 a9 00 00 00 48        bclr.b   #$0, $48(a1)
  f040ac: 66 58                    bne.b    $f04106
  f040ae: 22 29 00 44              move.l   $44(a1), d1
  f040b2: 28 41                    movea.l  d1, a4
  f040b4: 26 54                    movea.l  (a4), a3
  f040b6: 47 eb ff b6              lea.l    -$4a(a3), a3
  f040ba: 20 09                    move.l   a1, d0
  f040bc: 60 0e                    bra.b    $f040cc

loc_F040BE:
  f040be: 26 6c 00 08              movea.l  $8(a4), a3
  f040c2: 4a ac 00 08              tst.l    $8(a4)
  f040c6: 66 04                    bne.b    $f040cc
  f040c8: 61 00 c0 bc              bsr.w    $f00186

loc_F040CC:
  f040cc: b0 8b                    cmp.l    a3, d0
  f040ce: 67 04                    beq.b    $f040d4
  f040d0: 28 4b                    movea.l  a3, a4
  f040d2: 60 ea                    bra.b    $f040be

loc_F040D4:
  f040d4: b9 c1                    cmpa.l   d1, a4
  f040d6: 66 26                    bne.b    $f040fe
  f040d8: 4a ab 00 08              tst.l    $8(a3)
  f040dc: 67 28                    beq.b    $f04106
  f040de: 28 6b 00 08              movea.l  $8(a3), a4
  f040e2: 29 7c 00 00 4e b9 00 4a  move.l   #$4eb9, $4a(a4)
  f040ea: 29 7c 00 f0 44 a2 00 4c  move.l   #$f044a2, $4c(a4)
  f040f2: 49 ec 00 4a              lea.l    $4a(a4), a4
  f040f6: 26 6b 00 44              movea.l  $44(a3), a3
  f040fa: 26 8c                    move.l   a4, (a3)
  f040fc: 60 20                    bra.b    $f0411e

loc_F040FE:
  f040fe: 29 6b 00 08 00 08        move.l   $8(a3), $8(a4)
  f04104: 60 18                    bra.b    $f0411e

loc_F04106:
  f04106: 42 81                    clr.l    d1
  f04108: 12 29 00 28              move.b   $28(a1), d1
  f0410c: 26 69 00 44              movea.l  $44(a1), a3
  f04110: 26 bc 00 f0 08 96        move.l   #$f00896, (a3)
  f04116: 26 78 0c 66              movea.l  $c66.w, a3
  f0411a: 42 33 10 00              clr.b    (a3, d1.w)

loc_F0411E:
  f0411e: 49 f8 0c 18              lea.l    $c18.w, a4
  f04122: 20 09                    move.l   a1, d0

loc_F04124:
  f04124: 26 54                    movea.l  (a4), a3
  f04126: 4a 94                    tst.l    (a4)
  f04128: 66 04                    bne.b    $f0412e
  f0412a: 61 00 c0 5a              bsr.w    $f00186

loc_F0412E:
  f0412e: b0 8b                    cmp.l    a3, d0
  f04130: 67 06                    beq.b    $f04138
  f04132: 49 eb 00 04              lea.l    $4(a3), a4
  f04136: 60 ec                    bra.b    $f04124

loc_F04138:
  f04138: 28 ab 00 04              move.l   $4(a3), (a4)
  f0413c: 41 f8 0c 8e              lea.l    $c8e.w, a0
  f04140: 61 00 c6 46              bsr.w    $f00788
  f04144: 20 49                    movea.l  a1, a0
  f04146: 72 01                    moveq    #$1, d1
  f04148: 61 00 d3 4a              bsr.w    $f01494
  f0414c: 60 00 02 38              bra.w    $f04386
  f04150: 61 00 c0 34              bsr.w    $f00186

loc_F04154:
  f04154: 70 81                    moveq    #$81, d0
  f04156: 61 7a                    bsr.b    $f041d2
  f04158: 26 49                    movea.l  a1, a3
  f0415a: 61 00 01 ee              bsr.w    $f0434a
  f0415e: 22 4b                    movea.l  a3, a1
  f04160: 66 04                    bne.b    $f04166

loc_F04162:
  f04162: 70 06                    moveq    #$6, d0
  f04164: 61 6c                    bsr.b    $f041d2

loc_F04166:
  f04166: 08 29 00 07 00 48        btst.b   #$7, $48(a1)
  f0416c: 67 04                    beq.b    $f04172
  f0416e: 70 82                    moveq    #$82, d0
  f04170: 61 60                    bsr.b    $f041d2

loc_F04172:
  f04172: 08 29 00 01 00 49        btst.b   #$1, $49(a1)
  f04178: 67 04                    beq.b    $f0417e

loc_F0417A:
  f0417a: 70 83                    moveq    #$83, d0
  f0417c: 61 54                    bsr.b    $f041d2

loc_F0417E:
  f0417e: 08 29 00 00 00 49        btst.b   #$0, $49(a1)
  f04184: 67 0a                    beq.b    $f04190
  f04186: 08 2e 00 07 00 28        btst.b   #$7, $28(a6)
  f0418c: 67 00 fe 86              beq.w    $f04014

loc_F04190:
  f04190: 08 29 00 02 00 49        btst.b   #$2, $49(a1)
  f04196: 67 04                    beq.b    $f0419c
  f04198: 70 0b                    moveq    #$b, d0
  f0419a: 61 36                    bsr.b    $f041d2

loc_F0419C:
  f0419c: 0c 29 00 0f 00 18        cmpi.b   #$f, $18(a1)
  f041a2: 63 18                    bls.b    $f041bc
  f041a4: 0c 29 00 7f 00 18        cmpi.b   #$7f, $18(a1)
  f041aa: 63 18                    bls.b    $f041c4
  f041ac: 0c 29 00 80 00 18        cmpi.b   #$80, $18(a1)
  f041b2: 65 08                    bcs.b    $f041bc
  f041b4: 0c 29 00 8f 00 18        cmpi.b   #$8f, $18(a1)
  f041ba: 63 08                    bls.b    $f041c4

loc_F041BC:
  f041bc: 08 2a 00 00 00 03        btst.b   #$0, $3(a2)
  f041c2: 67 3c                    beq.b    $f04200

loc_F041C4:
  f041c4: 0c 2a 00 04 00 09        cmpi.b   #$4, $9(a2)
  f041ca: 64 0a                    bcc.b    $f041d6
  f041cc: 70 c6                    moveq    #$c6, d0
  f041ce: 61 00 01 98              bsr.w    $f04368

loc_F041D2:
  f041d2: 60 00 01 94              bra.w    $f04368

loc_F041D6:
  f041d6: 13 6a 00 09 00 3a        move.b   $9(a2), $3a(a1)
  f041dc: 23 6a 00 0a 00 3c        move.l   $a(a2), $3c(a1)
  f041e2: 67 1c                    beq.b    $f04200
  f041e4: 2f 08                    move.l   a0, -(a7)
  f041e6: 20 6e 00 36              movea.l  $36(a6), a0
  f041ea: 2c 29 00 3c              move.l   $3c(a1), d6
  f041ee: 7a 04                    moveq    #$4, d5
  f041f0: 61 00 d5 6a              bsr.w    $f0175c
  f041f4: 60 08                    bra.b    $f041fe
  f041f6: 4e 71                    nop      
  f041f8: 20 5f                    movea.l  (a7)+, a0
  f041fa: 70 c7                    moveq    #$c7, d0
  f041fc: 61 d4                    bsr.b    $f041d2

loc_F041FE:
  f041fe: 20 5f                    movea.l  (a7)+, a0

loc_F04200:
  f04200: 23 4e 00 34              move.l   a6, $34(a1)
  f04204: 13 6a 00 03 00 39        move.b   $3(a2), $39(a1)
  f0420a: 02 29 00 03 00 39        andi.b   #$3, $39(a1)
  f04210: 13 6a 00 08 00 38        move.b   $8(a2), $38(a1)
  f04216: 20 89                    move.l   a1, (a0)
  f04218: 20 2e 00 10              move.l   $10(a6), d0
  f0421c: 22 2e 00 14              move.l   $14(a6), d1
  f04220: 23 40 00 2c              move.l   d0, $2c(a1)
  f04224: 23 41 00 30              move.l   d1, $30(a1)
  f04228: 00 69 80 00 00 48        ori.w    #$8000, $48(a1)
  f0422e: 60 72                    bra.b    $f042a2
  f04230: 41 ee 00 44              lea.l    $44(a6), a0
  f04234: 08 2a 00 00 00 03        btst.b   #$0, $3(a2)
  f0423a: 67 16                    beq.b    $f04252

loc_F0423C:
  f0423c: 4a 90                    tst.l    (a0)
  f0423e: 67 62                    beq.b    $f042a2
  f04240: 26 50                    movea.l  (a0), a3
  f04242: 20 ab 00 0c              move.l   $c(a3), (a0)
  f04246: 42 ab 00 0c              clr.l    $c(a3)
  f0424a: 02 6b 7f ff 00 48        andi.w   #$7fff, $48(a3)
  f04250: 60 ea                    bra.b    $f0423c

loc_F04252:
  f04252: 61 00 00 f6              bsr.w    $f0434a
  f04256: 66 00 fe fc              bne.w    $f04154
  f0425a: 20 a9 00 0c              move.l   $c(a1), (a0)
  f0425e: 42 a9 00 0c              clr.l    $c(a1)
  f04262: 02 69 7f ff 00 48        andi.w   #$7fff, $48(a1)
  f04268: 60 38                    bra.b    $f042a2
  f0426a: 08 2e 00 07 00 28        btst.b   #$7, $28(a6)
  f04270: 67 00 fd a2              beq.w    $f04014
  f04274: 08 a9 00 01 00 49        bclr.b   #$1, $49(a1)
  f0427a: 66 26                    bne.b    $f042a2
  f0427c: 70 06                    moveq    #$6, d0
  f0427e: 61 00 00 e8              bsr.w    $f04368
  f04282: 61 00 00 c6              bsr.w    $f0434a
  f04286: 66 00 fe cc              bne.w    $f04154
  f0428a: 20 a9 00 0c              move.l   $c(a1), (a0)
  f0428e: 42 a9 00 0c              clr.l    $c(a1)
  f04292: 02 69 7f ff 00 48        andi.w   #$7fff, $48(a1)
  f04298: 08 e9 00 01 00 49        bset.b   #$1, $49(a1)
  f0429e: 66 00 fe da              bne.w    $f0417a

loc_F042A2:
  f042a2: 60 00 00 da              bra.w    $f0437e
  f042a6: 0c 29 00 ff 00 18        cmpi.b   #$ff, $18(a1)
  f042ac: 66 04                    bne.b    $f042b2
  f042ae: 7e 85                    moveq    #$85, d7
  f042b0: 61 76                    bsr.b    $f04328

loc_F042B2:
  f042b2: 0c 29 00 80 00 18        cmpi.b   #$80, $18(a1)
  f042b8: 65 08                    bcs.b    $f042c2
  f042ba: 0c 29 00 8f 00 18        cmpi.b   #$8f, $18(a1)
  f042c0: 63 08                    bls.b    $f042ca

loc_F042C2:
  f042c2: 61 00 00 86              bsr.w    $f0434a
  f042c6: 66 00 fe 8c              bne.w    $f04154

loc_F042CA:
  f042ca: 2a 49                    movea.l  a1, a5
  f042cc: 0c 2d 00 10 00 18        cmpi.b   #$10, $18(a5)
  f042d2: 65 5a                    bcs.b    $f0432e
  f042d4: 0c 2d 00 7f 00 18        cmpi.b   #$7f, $18(a5)
  f042da: 63 10                    bls.b    $f042ec
  f042dc: 0c 2d 00 80 00 18        cmpi.b   #$80, $18(a5)
  f042e2: 65 4a                    bcs.b    $f0432e
  f042e4: 0c 2d 00 8f 00 18        cmpi.b   #$8f, $18(a5)
  f042ea: 62 42                    bhi.b    $f0432e

loc_F042EC:
  f042ec: 20 2a 00 08              move.l   $8(a2), d0
  f042f0: 66 04                    bne.b    $f042f6
  f042f2: 20 2e 00 10              move.l   $10(a6), d0

loc_F042F6:
  f042f6: 22 2a 00 0c              move.l   $c(a2), d1
  f042fa: 66 04                    bne.b    $f04300
  f042fc: 22 2e 00 14              move.l   $14(a6), d1

loc_F04300:
  f04300: 08 2e 00 07 00 28        btst.b   #$7, $28(a6)
  f04306: 66 0a                    bne.b    $f04312
  f04308: b2 ae 00 14              cmp.l    $14(a6), d1
  f0430c: 67 04                    beq.b    $f04312
  f0430e: 7e c6                    moveq    #$c6, d7
  f04310: 61 16                    bsr.b    $f04328

loc_F04312:
  f04312: 48 ed 00 03 00 54        movem.l  d0-d1, $54(a5)
  f04318: 41 ed 00 54              lea.l    $54(a5), a0
  f0431c: 70 06                    moveq    #$6, d0
  f0431e: 4e 40                    trap     #$0
  f04320: 60 08                    bra.b    $f0432a
  f04322: 4e 71                    nop      
  f04324: 7e 03                    moveq    #$3, d7
  f04326: 61 40                    bsr.b    $f04368

loc_F04328:
  f04328: 60 3e                    bra.b    $f04368

loc_F0432A:
  f0432a: 2b 48 00 50              move.l   a0, $50(a5)

loc_F0432E:
  f0432e: 41 f8 0c 8e              lea.l    $c8e.w, a0
  f04332: 61 00 c4 54              bsr.w    $f00788
  f04336: 20 6d 00 1a              movea.l  $1a(a5), a0
  f0433a: d1 e8 00 04              adda.l   $4(a0), a0
  f0433e: 2f 0e                    move.l   a6, -(a7)
  f04340: 4e 90                    jsr      (a0)
  f04342: 2c 5f                    movea.l  (a7)+, a6
  f04344: 4a 40                    tst.w    d0
  f04346: 67 3e                    beq.b    $f04386
  f04348: 61 2c                    bsr.b    $f04376

loc_F0434A:
  f0434a: 20 29 00 14              move.l   $14(a1), d0

loc_F0434E:
  f0434e: 41 ee 00 44              lea.l    $44(a6), a0

loc_F04352:
  f04352: 4a 90                    tst.l    (a0)
  f04354: 67 0e                    beq.b    $f04364
  f04356: 22 50                    movea.l  (a0), a1
  f04358: b0 a9 00 14              cmp.l    $14(a1), d0
  f0435c: 67 08                    beq.b    $f04366
  f0435e: 41 e9 00 0c              lea.l    $c(a1), a0
  f04362: 60 ee                    bra.b    $f04352

loc_F04364:
  f04364: 46 80                    not.l    d0

loc_F04366:
  f04366: 4e 75                    rts      

loc_F04368:
  f04368: 42 81                    clr.l    d1
  f0436a: 12 00                    move.b   d0, d1
  f0436c: 41 f8 0c 8e              lea.l    $c8e.w, a0
  f04370: 61 00 c4 16              bsr.w    $f00788
  f04374: 20 01                    move.l   d1, d0

loc_F04376:
  f04376: 58 8f                    addq.l   #$4, a7
  f04378: 3d 40 01 02              move.w   d0, $102(a6)
  f0437c: 60 0e                    bra.b    $f0438c

loc_F0437E:
  f0437e: 41 f8 0c 8e              lea.l    $c8e.w, a0
  f04382: 61 00 c4 04              bsr.w    $f00788

loc_F04386:
  f04386: 42 80                    clr.l    d0
  f04388: 42 ae 01 00              clr.l    $100(a6)

loc_F0438C:
  f0438c: 4e 73                    rte      

loc_F0438E:
  f0438e: 2c 6d 00 34              movea.l  $34(a5), a6
  f04392: 42 80                    clr.l    d0
  f04394: 12 2d 00 39              move.b   $39(a5), d1
  f04398: 08 01 00 00              btst.b   #$0, d1
  f0439c: 66 08                    bne.b    $f043a6
  f0439e: 20 4e                    movea.l  a6, a0
  f043a0: 70 16                    moveq    #$16, d0
  f043a2: 4e 40                    trap     #$0
  f043a4: 60 46                    bra.b    $f043ec

loc_F043A6:
  f043a6: 1b 7c 00 01 00 71        move.b   #$1, $71(a5)
  f043ac: 1b 7c 00 06 00 70        move.b   #$6, $70(a5)
  f043b2: 74 02                    moveq    #$2, d2
  f043b4: 41 ed 00 70              lea.l    $70(a5), a0
  f043b8: 21 ad 00 3c 20 00        move.l   $3c(a5), (a0, d2.w)
  f043be: 67 0a                    beq.b    $f043ca
  f043c0: 06 ad 04 80 00 00 00 70  addi.l   #$4800000, $70(a5)
  f043c8: 58 82                    addq.l   #$4, d2

loc_F043CA:
  f043ca: 11 80 20 00              move.b   d0, (a0, d2.w)
  f043ce: 11 ad 00 38 20 01        move.b   $38(a5), $1(a0, d2.w)
  f043d4: 54 82                    addq.l   #$2, d2
  f043d6: b4 2d 00 3a              cmp.b    $3a(a5), d2
  f043da: 63 06                    bls.b    $f043e2
  f043dc: 1b 6d 00 3a 00 70        move.b   $3a(a5), $70(a5)

loc_F043E2:
  f043e2: 4c ed 00 3c 00 70        movem.l  $70(a5), d2-d5
  f043e8: 61 00 00 9e              bsr.w    $f04488

loc_F043EC:
  f043ec: 4e 75                    rts      

loc_F043EE:
  f043ee: 48 e7 60 00              movem.l  d1-d2, -(a7)
  f043f2: 43 ed 00 70              lea.l    $70(a5), a1
  f043f6: 42 80                    clr.l    d0
  f043f8: 20 6d 00 22              movea.l  $22(a5), a0
  f043fc: 12 2d 00 2b              move.b   $2b(a5), d1

loc_F04400:
  f04400: 67 7c                    beq.b    $f0447e
  f04402: 30 11                    move.w   (a1), d0
  f04404: 14 30 00 00              move.b   (a0, d0.w), d2
  f04408: 4a 29 00 03              tst.b    $3(a1)
  f0440c: 66 02                    bne.b    $f04410
  f0440e: 46 02                    not.b    d2

loc_F04410:
  f04410: c4 29 00 02              and.b    $2(a1), d2
  f04414: 66 08                    bne.b    $f0441e
  f04416: 43 e9 00 08              lea.l    $8(a1), a1
  f0441a: 53 01                    subq.b   #$1, d1
  f0441c: 60 e2                    bra.b    $f04400

loc_F0441E:
  f0441e: 30 29 00 04              move.w   $4(a1), d0
  f04422: 08 29 00 01 00 07        btst.b   #$1, $7(a1)
  f04428: 67 06                    beq.b    $f04430
  f0442a: 4a 30 00 00              tst.b    (a0, d0.w)
  f0442e: 60 28                    bra.b    $f04458

loc_F04430:
  f04430: 11 a9 00 06 00 00        move.b   $6(a1), (a0, d0.w)
  f04436: 30 2d 00 26              move.w   $26(a5), d0
  f0443a: d0 88                    add.l    a0, d0
  f0443c: 08 00 00 00              btst.b   #$0, d0
  f04440: 66 02                    bne.b    $f04444
  f04442: 53 80                    subq.l   #$1, d0

loc_F04444:
  f04444: 90 88                    sub.l    a0, d0
  f04446: 24 00                    move.l   d0, d2

loc_F04448:
  f04448: 4a 30 00 00              tst.b    (a0, d0.w)
  f0444c: 55 40                    subq.w   #$2, d0
  f0444e: 6c f8                    bge.b    $f04448

loc_F04450:
  f04450: 42 30 20 00              clr.b    (a0, d2.w)
  f04454: 55 42                    subq.w   #$2, d2
  f04456: 6c f8                    bge.b    $f04450

loc_F04458:
  f04458: 40 c0                    move.w   sr, d0
  f0445a: 04 40 01 00              subi.w   #$100, d0
  f0445e: 46 c0                    move.w   d0, sr
  f04460: 08 2d 00 07 00 48        btst.b   #$7, $48(a5)
  f04466: 67 0c                    beq.b    $f04474
  f04468: 48 e7 1f 3a              movem.l  d3-d7/a2-a4/a6, -(a7)
  f0446c: 61 00 ff 20              bsr.w    $f0438e
  f04470: 4c df 5c f8              movem.l  (a7)+, d3-d7/a2-a4/a6

loc_F04474:
  f04474: 4c df 00 06              movem.l  (a7)+, d1-d2
  f04478: 00 7c 00 01              ori.w    #$1, sr
  f0447c: 4e 75                    rts      

loc_F0447E:
  f0447e: 4c df 00 06              movem.l  (a7)+, d1-d2
  f04482: 02 7c ff fe              andi.w   #$fffe, sr
  f04486: 4e 75                    rts      
