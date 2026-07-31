# AP I/F (612-4448) connection list — J22 / J23

Supplied by the project owner, 2026-07-31. **This is the 4448 board — the one in this chassis** —
as distinct from the `512-3448-010` schematic set, which is an FPS-100-class relative.

Convention: `A` = left connector (J22), `B` = right connector (J23); pin 1 = leftmost component
side, 100 = rightmost solder side; **odd = component side, even = solder side**.

## J22 (A)

| pin | signal | pin | signal | pin | signal | pin | signal |
|---|---|---|---|---|---|---|---|
| A1 | +5V | A26 | DA13* | A51 | DPMBS12* | A76 | HD01 |
| A2 | +5V | A27 | PNL14* | A52 | IO24* | A77 | DACKR |
| A3 | GND | A28 | DA14* | A53 | DPMBS13* | A78 | HD02 |
| A4 | GND | A29 | PNL15* | A54 | IO25* | A79 | HADRCLK1* |
| A5 | READY* | A30 | DA15* | A55 | DPMBS14* | A80 | HD03 |
| A6 | !IOCLK | A31 | SP+DP12* | A56 | IO26* | A81 | DPMBS16* |
| A7 | IO32* | A32 | SP+DP13* | A57 | DPMBS15* | A82 | IO28* |
| A8 | IO33* | A33 | SP+DP14* | A58 | IO27* | A83 | DPMBS17* |
| A9 | IO34* | A34 | SP+DP15* | A59 | DCHO01* | A84 | IO29* |
| A10 | IORDY* | A35 | MDCA1 | A60 | MDCR1* | A85 | DPMBS18* |
| A11 | PNL08* | A36 | B0CLK | A61 | HST00 | A86 | IO30* |
| A12 | DA08* | A37 | MDWRT* | A62 | DMA00* | A87 | DPMBS19* |
| A13 | PNL09* | A38 | IN100 | A63 | HST01 | A88 | IO31* |
| A14 | DA09* | A39 | INTR* | A64 | DMA01* | A89 | DPMBS20* |
| A15 | PNL10* | A40 | INTFN | A65 | BXA2HD | A90 | IO36* |
| A16 | DA10* | A41 | B2MDI | A66 | DMA02* | A91 | DPMBS21* |
| A17 | PNL11* | A42 | B2IO | A67 | HST02 | A92 | INTPOUT |
| A18 | DA11* | A43 | OUT* | A68 | DMA03* | A93 | RUN* |
| A19 | SP+DP08* | A44 | INTPIN | A69 | HST03 | A94 | CTLOUT |
| A20 | SP+DP09* | A45 | B2CLK | **A70** | **OVFL\*** | A95 | CTLOUTR |
| A21 | SP+DP10* | A46 | IOACK* | A71 | DAVAL | A96 | HADRCLK2* |
| A22 | SP+DP11* | A47 | IO35* | **A72** | **UNFL\*** | A97 | GND |
| A23 | PNL12* | A48 | NUF2CLK | A73 | DAVALR | A98 | GND |
| A24 | DA12* | A49 | HINTIND | A74 | HD00 | A99 | +5V |
| A25 | PNL13* | A50 | CTLCLK | A75 | DACK | A100 | +5V |

## J23 (B)

| pin | signal | pin | signal | pin | signal | pin | signal |
|---|---|---|---|---|---|---|---|
| B1 | +5V | B26 | HD05 | B51 | CCT5INT* | B76 | INT06* |
| B2 | +5V | **B27** | **SAPXR** | B52 | !HRSET | B77 | DPMBS27* |
| B3 | GND | B28 | HD06 | B53 | HST10 | B78 | INT07* |
| B4 | GND | B29 | SHSTX | **B54** | **REGSEL00** | B79 | DMA12* |
| **B5** | **CTLACK** | B30 | HD07 | B55 | HST11 | **B80** | **I+H13** |
| B6 | CTLACKR | B31 | SHSTXR | **B56** | **REGSEL01** | B81 | DMA13* |
| B7 | APDMAACT | B32 | B1CLK | **B57** | **REGSEL02** | **B82** | **I+H14** |
| B8 | APDMAACTR | B33 | B3CLK | B58 | HD12 | B83 | DMA14* |
| B9 | HST04 | B34 | HALTINT* | **B59** | **REGSEL03** | B84 | IO39* |
| B10 | DMA04* | B35 | CHALTINT* | B60 | HD13 | B85 | DMA15* |
| B11 | HST05 | B36 | HD08 | **B61** | **REGSEL04** | B86 | PNLBSY* |
| B12 | DMA05* | B37 | WCFQ0* | B62 | HD14 | B87 | HST12 |
| B13 | HADRCLK* | B38 | HD09 | B63 | SYRST* | B88 | LT2HD* |
| B14 | DMA06* | B39 | DMA08* | B64 | HD15 | B89 | HST13 |
| B15 | HST06 | B40 | HD10 | **B65** | **REGSEL05** | B90 | FN2HD* |
| B16 | DMA07* | B41 | DMA09* | B66 | SPLFMT* | B91 | HADR2HD* |
| B17 | HST07 | B42 | HD11 | B67 | DPMBS22* | B92 | SR2HD* |
| B18 | DMAIND | B43 | DMA10* | B68 | IO37* | B93 | HST14 |
| B19 | HDMAACT | **B44** | **I+H09** | B69 | DPMBS23* | B94 | BL2HD |
| B20 | RUNIND | B45 | DMA11* | B70 | IO38* | B95 | HST15 |
| B21 | HDMAACTR | **B46** | **I+H10** | B71 | DPMBS24* | B96 | BH2HD |
| **B22** | **DMASTB** | B47 | HST08 | B72 | LDFN* | B97 | GND |
| **B23** | **DMASTBR** | B48 | BXB2HD | B73 | DPMBS25* | B98 | GND |
| B24 | HD04 | B49 | HST09 | B74 | LDSR* | B99 | +5V |
| **B25** | **SAPX** | B50 | CTL5INT* | B75 | DPMBS26* | B100 | +5V |
