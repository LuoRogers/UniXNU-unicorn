#!/usr/bin/env python3
"""Adapt UniXNU's patch-xnu-entry-probe.py to a kernel it was not written for.

The pinned tool assumes (a) one exact four-instruction SCTLR/ISB/CPACR sequence
right after `_start_first_cpu`, and (b) zero padding at fixed offsets from the
entry for its probe caves. The darwin24 4K kernel of this port has neither: the
CPACR pair is absent from that sequence, and the entry body is real code.

This rewrites the tool in place (inside the assembled tree copy, never upstream):

  * the MMU-enable matcher shrinks to `msr SCTLR_EL1, x0` + `ISB`
  * AFTER_MMU_VA moves to MMU_ENABLE_VA + 4 and its expected word follows
  * the probe caves are placed into the first executable zero run found in the
    image, with PANIC_CAVE_END covering the whole run

Usage: adapt-entry-probe.py <path-to-patch-xnu-entry-probe.py>
"""

import pathlib
import sys

OLD_MATCH = (
    "if (instruction(va) == 0xD5181000 and\n"
    "                    instruction(va + 4) == 0xD5033FDF and\n"
    "                    instruction(va + 0x20) == 0xD2A00600 and\n"
    "                    instruction(va + 0x24) == 0xD5181040):"
)
NEW_MATCH = (
    "if (instruction(va) == 0xD5181000 and\n"
    "                    instruction(va + 4) == 0xD5033FDF):"
)

DISCOVERY = '''    # This kernel's entry body is code, not the zero padding the original tool
    # assumed. Put the probe caves into the first executable zero run instead.
    need = 0x2400
    zeros = bytes(need)
    found = None
    for _vmaddr, _vmsize, _fileoff, _filesize in SEGMENTS:
        _span = min(_vmsize, _filesize)
        _end = _fileoff + _span - need
        if _end <= _fileoff:
            continue
        _idx = data.find(zeros, _fileoff, _end)
        while _idx != -1:
            if ((_idx - _fileoff) % 16) == 0:
                found = _vmaddr + (_idx - _fileoff)
                break
            _idx = data.find(zeros, _idx + 16, _end)
        if found:
            break
    if not found:
        raise SystemExit('no executable zero run for the entry probes')
    CAVES = {stage: found + (stage - 1) * CAVE_SIZE for stage in (1, 2, 3, 4)}
    PANIC_CAVE_END = found + need
'''


def main() -> int:
    p = pathlib.Path(sys.argv[1])
    s = p.read_text()
    changed = 0
    if OLD_MATCH in s:
        s = s.replace(OLD_MATCH, NEW_MATCH, 1)
        changed += 1
    if "AFTER_MMU_VA = MMU_ENABLE_VA + 0x20" in s:
        s = s.replace("AFTER_MMU_VA = MMU_ENABLE_VA + 0x20", "AFTER_MMU_VA = MMU_ENABLE_VA + 4", 1)
        changed += 1
    if "AFTER_MMU_VA: 0xD2A00600" in s:
        s = s.replace("AFTER_MMU_VA: 0xD2A00600", "AFTER_MMU_VA: 0xD5033FDF", 1)
        changed += 1
    tool_block_old = """    clang = shutil.which('clang') or '/opt/homebrew/opt/llvm/bin/clang'
    lld = shutil.which('ld.lld') or '/opt/homebrew/opt/llvm/bin/ld.lld'
    objcopy = shutil.which('llvm-objcopy') or '/opt/homebrew/opt/llvm/bin/llvm-objcopy'"""
    tool_block_new = """    def _tool(name, extra=()):
        for candidate in (shutil.which(name), *extra):
            if candidate and Path(candidate).exists():
                return candidate
        return name

    clang = _tool('clang', ('/usr/bin/clang',))
    lld = _tool('ld.lld', ('/usr/local/opt/lld/bin/ld.lld', '/usr/local/opt/llvm/bin/ld.lld',
                           '/opt/homebrew/opt/llvm/bin/ld.lld'))
    objcopy = _tool('llvm-objcopy', ('/usr/local/opt/llvm/bin/llvm-objcopy',
                                     '/opt/homebrew/opt/llvm/bin/llvm-objcopy'))"""
    if tool_block_old in s:
        s = s.replace(tool_block_old, tool_block_new)
        changed += 1
    if "    return names" in s and "executable zero run" not in s:
        s = s.replace("    return names", DISCOVERY + "    return names", 1)
        changed += 1
    p.write_text(s)
    print(f"entry-probe patcher adapted ({changed} edit(s))")
    if changed < 5:
        print("warning: fewer edits than expected; the pinned tool may have changed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
