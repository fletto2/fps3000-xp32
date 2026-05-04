#!/usr/bin/env python3
"""
Produce a cleanly-formatted, annotated FPS-3000 ROM disassembly.

Inputs:
  - fps3k_custom_annotated.asm  (output from disasm.py + annotate)
  - /tmp/fps3k_annotations_cooperative.txt
  - /tmp/fps3k_glm51_followup.txt (optional, if GLM-5.1 has run)

Outputs:
  - fps3k_clean.asm  — cleanly formatted, with:
      • All known meaningful labels (TCBRDHC_Entry, PanelSendAndWait, …)
      • Every loc_F0xxxx kept verbatim BUT with a "; in <enclosing-function>"
        annotation if known
      • XLTR register accesses ($200-$21A relative to a0=0xFF0000) annotated
        with their canonical names (XLTR_MODE0, XLTR_DATA_LO, …)
      • MC consensus annotations as ";; …" comments on the line above
      • Hex addresses preserved as the leading column in lowercase 6-digit
        format (e.g.  f056ba)
"""
import re, collections, os

ASM_IN  = '/home/fletto/ext/src/claude/fps3000/fps3k_custom_annotated.asm'
ASM_OUT = '/home/fletto/ext/src/claude/fps3000/fps3k_clean.asm'

# ---- enclosing-function map (start_addr → name) ----
# Subroutines whose extent we know; "in <name>" annotation for any
# loc_F0xxxx that falls within [start, end).
FUNCTIONS = [
    (0xF04488, 0xF046F0, 'task__init_misc'),       # pre-RDHC fragment
    (0xF046F0, 0xF051A2, 'TCBRDHC'),                # RDHC main loop
    (0xF051A2, 0xF05256, 'SRecordDataHandler'),
    (0xF05256, 0xF05688, 'SRecordFinalize_andHelpers'),
    (0xF05688, 0xF056BA, 'PanelIOConfigure_25A'),
    (0xF056BA, 0xF05BA4, 'PanelSendAndWait_andDispatch'),
    (0xF05BA4, 0xF05C4C, 'PanelStatusDispatchTable'),       # data
    (0xF05C4C, 0xF05D00, 'PanelErrorMaskTable'),            # data
    (0xF05D00, 0xF05F00, 'TCBIO1I'),
    (0xF05F00, 0xF06914, 'TCBXP4I'),
    (0xF06914, 0xF07D00, 'TCBXP3I_TCBXP2I'),
    (0xF07D00, 0xF08700, 'TCBXP1I'),
    (0xF08700, 0xF08902, 'MainInit'),
    (0xF08902, 0xF0891C, 'BusAddressErrorHandler'),
    (0xF0891C, 0xF08A5C, 'PollBoardStatus'),
    (0xF08A5C, 0xF08D5E, 'HardwareInit'),
    (0xF08D5E, 0xF08DF8, 'RAMAddressingTest'),
    (0xF08DF8, 0xF08EAC, 'ROMChecksumTest'),
    (0xF08EAC, 0xF08F72, 'MemBusProbe'),
    (0xF08F72, 0xF09176, 'IOChannelDiagnostic'),
    (0xF09176, 0xF0919C, 'PTMInit'),
    (0xF0919C, 0xF098EE, 'PanelBusDiagnostic'),
    (0xF098EE, 0xF09C00, 'ROMChecksum_etc'),
    (0xF09C00, 0xF09E88, 'Phase2Init_VCTscan'),
    (0xF09E88, 0xF0A04E, 'Init_RMS68K_StoreTags'),
    (0xF0A04E, 0xF0A57E, 'RTOSKernelInit'),
]

def enclosing(addr):
    for s, e, n in FUNCTIONS:
        if s <= addr < e:
            return n
    return None

# ---- XLTR register-offset → name map (when accessed via (a0) where a0=0xFF0000) ----
XLTR_OFFS = {
    0x000E: 'XLTR_CMD_ARG',
    0x0048: 'XLTR_CH1_DATA_A',  0x004E: 'XLTR_CH1_DATA_B',
    0x0068: 'XLTR_CH2_DATA_A',  0x006E: 'XLTR_CH2_DATA_B',
    0x0088: 'XLTR_CH3_DATA_A',  0x008E: 'XLTR_CH3_DATA_B',
    0x00A8: 'XLTR_CH4_DATA_A',  0x00AE: 'XLTR_CH4_DATA_B',
    0x0200: 'XLTR_MODE0',
    0x0202: 'XLTR_MODE1',
    0x0204: 'XLTR_CHANNEL_SELECT',
    0x020C: 'XLTR_COUNTER',
    0x0210: 'XLTR_MODE2',
    0x0214: 'XLTR_DATA_LO',
    0x0216: 'XLTR_DATA_HI',
    0x0218: 'XLTR_STATUS_IRQ',
    0x021A: 'XLTR_IRQ_MASK',
    0x0244: 'XLTR_CH1_CONFIG',
    0x0246: 'XLTR_CH2_CONFIG',
    0x0250: 'XLTR_CH3_CONFIG',
    0x0252: 'XLTR_CH4_CONFIG',
}

# ---- panel-command code → name map (codes 0x258..0x27D) ----
PANEL_CMDS = {
    0x258: 'PCMD_CH1_RESET',      # speculative names by position
    0x259: 'PCMD_CH1_INIT',
    0x25A: 'PCMD_CH1_ACK',        # used in SRecordFinalize
    0x25B: 'PCMD_CH1_FLUSH',
    0x25C: 'PCMD_RESET_STATUS',   # most-common common code (5 uses)
    0x25D: 'PCMD_CH1_CONFIG',
    0x25E: 'PCMD_CH2_CONFIG',
    0x25F: 'PCMD_CH3_CONFIG',
    0x260: 'PCMD_CH4_CONFIG',
    0x269: 'PCMD_ERROR_ABORT',    # error-path abort (bit 13 set)
    0x26A: 'PCMD_TIMEOUT_ABORT',
    0x26B: 'PCMD_CH_ABORT',
    0x26C: 'PCMD_RELEASE',        # 9 uses — most common abort/release
    0x26E: 'PCMD_CH1_TCB_FAIL',
    0x271: 'PCMD_CH4_TCB_FAIL',
    0x276: 'PCMD_INIT_STEP1',     # 0x276..0x27D = init sequence per Path B
    0x277: 'PCMD_INIT_STEP2',
    0x278: 'PCMD_INIT_STEP3',
    0x279: 'PCMD_INIT_STEP4',
    0x27A: 'PCMD_INIT_STEP5',
    0x27B: 'PCMD_INIT_STEP6',
    0x27D: 'PCMD_INIT_STEP8',
}

# Common SBC-RAM globals (low memory)
RAM_GLOBALS = {
    0x000400: 'g__sched_save_d0',
    0x000800: 'g__ctx_save',
    0x000C00: 'g__tcb_chain_ptr',
    0x000C08: 'g__saved_sp',
    0x000C36: 'g__apif_base',
    0x000C3A: 'g__apif_ptr',
    0x000C66: 'g__current_tcb',
    0x000E58: 'g__srec_addr',          # 32-bit, current S-record assembly addr
    0x000E60: 'g__srec_count',         # block size counter
    0x000E64: 'g__panel_expected',     # expected panel-cmd response
    0x000E6E: 'g__last_panel_arg',
    0x000E74: 'g__last_panel_cmd',
    0x000E86: 'g__channel_mode',       # mode register
    0x000E87: 'g__global_status',      # bits 6,7 used
    0x00105E: 'g__max_block_size',
    0x001064: 'g__irq_mask_shadow',
    0x001080: 'g__channel_data_table', # pointer table indexed by channel
}


def fmt_xltr_offset(off, kind=''):
    """Return e.g. '$202(a0) [XLTR_MODE1]' for known offsets."""
    name = XLTR_OFFS.get(off)
    if name:
        return f'[{name}]'
    return ''


def main():
    print(f'Reading {ASM_IN}...')
    with open(ASM_IN) as f:
        lines = f.readlines()

    # Pre-pass: build a per-line "current function" map keyed by line index
    # using the address column.
    current_func = None
    out = []

    out.append('; ============================================================\n')
    out.append('; FPS-3000 SBC ROM — clean, annotated disassembly\n')
    out.append('; ROM file: FPS3K_U11_U12_JOIN.bin (64 KB at 0xF00000)\n')
    out.append('; Generated by build_clean_disasm.py — see disasm.py for raw\n')
    out.append(';\n')
    out.append('; Format:\n')
    out.append(';   labels are inserted as `Label_Name:` with the hex addr in a\n')
    out.append(';   trailing comment. Every line keeps its hex address as the\n')
    out.append(';   leading column. Monte-Carlo annotations appear as `;>>>>` lines\n')
    out.append(';   above their target instruction.\n')
    out.append(';\n')
    out.append('; Functions / regions in this disassembly:\n')
    for s, e, n in FUNCTIONS:
        out.append(f';   {s:06X}–{e-1:06X}  {n}\n')
    out.append('; ============================================================\n\n')

    for line in lines:
        # Detect a label of the form "Name:" or "loc_F0xxxx:" on its own line
        m_label = re.match(r'^([A-Za-z_][\w]*):\s*$', line)
        if m_label:
            label = m_label.group(1)
            # Try to derive the address from the next line
            # We'll rewrite labels to keep them aligned, and add a `; loc 0xF0xxxx`
            # comment when it's a loc_ label.
            m_addr_loc = re.match(r'loc_F0([0-9A-Fa-f]{4})', label)
            if m_addr_loc:
                addr = int(m_addr_loc.group(1), 16) | 0xF00000
                fn = enclosing(addr)
                if fn:
                    out.append(f'{label}:                            ; in {fn} (0x{addr:06X})\n')
                else:
                    out.append(f'{label}:                            ; (0x{addr:06X})\n')
                current_func = fn or current_func
            else:
                out.append(line)
                # Update current_func from named labels too
                for s, e, fn in FUNCTIONS:
                    if line.startswith(fn + ':'):
                        current_func = fn
                        break
            continue

        # Detect address line: "  f0xxxx: bytes  mnemonic..."
        m_addr = re.match(r'^  (f0[0-9a-f]{4}): ([0-9a-f][0-9a-f ]*?)\s{2,}([a-z][a-z\.]*)\s*(.*)$', line)
        if m_addr:
            addr = int(m_addr.group(1), 16)
            bytes_col = m_addr.group(2).rstrip()
            mnem = m_addr.group(3)
            args = m_addr.group(4).rstrip()

            # Annotate XLTR register accesses
            xltr_note = ''
            m_off = re.search(r'\$([0-9a-f]+)\(a[0-7]\)', args)
            if m_off:
                off = int(m_off.group(1), 16)
                if off in XLTR_OFFS and (off >= 0x200 or 'a0' in args):
                    xltr_note = f' ; → {XLTR_OFFS[off]}'

            # Annotate panel-command code immediates
            pcmd_note = ''
            m_imm = re.search(r'#\$([0-9a-f]+),\s*d0', args)
            if m_imm and 'jsr' not in mnem:
                imm = int(m_imm.group(1), 16)
                if imm in PANEL_CMDS:
                    pcmd_note = f' ; {PANEL_CMDS[imm]}'

            # RAM global ref?
            ram_note = ''
            m_ram = re.search(r'\$([0-9a-f]+)(?:\.l|\.w)?', args)
            if m_ram:
                addr_imm = int(m_ram.group(1), 16)
                if addr_imm in RAM_GLOBALS:
                    ram_note = f' ; {RAM_GLOBALS[addr_imm]}'

            note = xltr_note + pcmd_note + ram_note
            new_line = f'  {addr:06x}:  {bytes_col:<22s}  {mnem:<10s}{(" " + args).rstrip()}{note}\n'
            out.append(new_line)
            continue

        # Pass through everything else (comments, blank lines, ;>>>> annotations)
        out.append(line)

    with open(ASM_OUT, 'w') as f:
        f.writelines(out)
    print(f'Wrote {ASM_OUT}  ({sum(1 for l in out)} lines)')


if __name__ == '__main__':
    main()
