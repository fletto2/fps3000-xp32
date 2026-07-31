#!/usr/bin/env python3
"""Positive/negative controls for verify_findings.py's structural self-audits.

Three guards protect the regression harness from defects that INFLATE the pass
count instead of failing:

  1. check() calls below sys.exit()      -- 193 were found orphaned
  2. use-before-definition in the emulator block -- aborted three runs
  3. vacuous checks (literal True, constant-vs-constant) -- 7 found in total

Every one of those guards has been wrong at least once: #1 initially matched its
own source text, #2 lost its sys.exit in an edit (printing FATAL and carrying on)
and then over-reported six false positives, #3 existed only as a one-off script
while two more vacuous checks were introduced.  A guard nobody tests is worth
nothing, so this script asserts each guard is BOTH quiet on the real file AND
fires on a synthetic instance of the defect it exists to catch.
"""
import ast
import os
import sys
import tempfile

HARNESS = os.path.join(os.path.dirname(__file__), 'verify_findings.py')
CUT = 'def word(a):'          # the guards all run above this point


def _run(text, path):
    """Execute only the guard prologue of `text`, reporting whether it exits."""
    open(path, 'w').write(text)
    ns = {'__file__': path, '__name__': 'guardtest'}
    try:
        exec(compile(ast.parse(text[:text.index(CUT)]), path, 'exec'), ns)
    except SystemExit as e:
        return 'fired', e.code
    return 'quiet', 0


def main():
    src = open(HARNESS).read()
    d = tempfile.mkdtemp()
    cases = [
        ('clean file', src, 'quiet'),
        ('orphaned check below sys.exit',
         src.rstrip() + "\ncheck('orphaned', True)\n", 'fired'),
        ('use-before-definition in the emulator block',
         src.replace("    print('\\nemulator runtime')",
                     "    print(_LATER_NAME)\n    print('\\nemulator runtime')", 1)
            .replace("_rom = open(ROM, 'rb').read()",
                     "_LATER_NAME = 1\n_rom = open(ROM, 'rb').read()", 1), 'fired'),
        ('vacuous check (literal True)',
         src.replace("def word(a):", "check('vacuous', True)\n\n\ndef word(a):", 1),
         'fired'),
    ]
    bad = 0
    for i, (name, text, want) in enumerate(cases):
        got, code = _run(text, os.path.join(d, 'g%d.py' % i))
        ok = got == want
        bad += not ok
        print('  %-44s want %-5s got %-5s %s'
              % (name, want, got, 'OK' if ok else '*** WRONG ***'))
    print('\n  %d/%d guard controls behaved correctly' % (len(cases) - bad, len(cases)))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
