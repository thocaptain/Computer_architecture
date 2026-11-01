"""Assemble app05 with GNU RV32I tools, then compare every byte with the .mem ROM.

Run in WSL/Linux with binutils-riscv64-linux-gnu installed. The existing .s and
.mem files are read without regeneration, so the artifacts being checked cannot
be silently replaced by the verification step.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
APPS = ROOT / "02_test" / "Milestone1" / "apps"
OUTPUT = APPS / "encoding_check"


def main():
    prefix = os.environ.get("RISCV_TOOL_PREFIX", "riscv64-linux-gnu-")
    tools = {name: shutil.which(prefix + name) for name in ("as", "ld", "objcopy", "objdump")}
    missing = [prefix + name for name, path in tools.items() if path is None]
    if missing:
        raise SystemExit("Missing GNU RISC-V tools: " + ", ".join(missing))
    assembly = APPS / "app05_instruction.s"
    rom_path = APPS / "app05_instruction.mem"
    if not assembly.is_file() or not rom_path.is_file():
        raise SystemExit("Generate app05_instruction.s and .mem before verification")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    obj, elf = OUTPUT / "app05_instruction.o", OUTPUT / "app05_instruction.elf"
    gnu_bin = OUTPUT / "app05_instruction.gnu.bin"
    mem_bin = OUTPUT / "app05_instruction.from_mem.bin"
    logs = []

    def run(arguments):
        command = [str(argument) for argument in arguments]
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        logs.append("$ " + " ".join(command) + "\n" + result.stdout + result.stderr)
        (OUTPUT / "commands.log").write_text("\n".join(logs), encoding="utf-8")
        if result.returncode:
            raise SystemExit(f"GNU tool failed ({result.returncode}); see {OUTPUT / 'commands.log'}")
        return result.stdout

    version = run([tools["as"], "--version"]).splitlines()[0]
    # riscv64 GNU binutils can emit ELF32 when RV32I and ILP32 are explicit.
    run([tools["as"], "-march=rv32i", "-mabi=ilp32", "-mno-relax", "-o", obj, assembly])
    run([tools["ld"], "-m", "elf32lriscv", "--no-relax", "-Ttext=0", "-e", "_start", "-o", elf, obj])
    run([tools["objcopy"], "-O", "binary", "--only-section=.text", elf, gnu_bin])
    words = [int(line.strip(), 16) for line in rom_path.read_text().splitlines() if line.strip()]
    if any(word < 0 or word > 0xFFFFFFFF for word in words):
        raise SystemExit("ROM contains a value outside 32 bits")
    expected = b"".join(word.to_bytes(4, "little") for word in words)
    mem_bin.write_bytes(expected)
    actual = gnu_bin.read_bytes()
    mismatch_count = sum(a != b for a, b in zip(expected, actual)) + abs(len(expected)-len(actual))
    summary = {
        "status": "PASS" if mismatch_count == 0 else "FAIL",
        "assembler": version,
        "isa": "rv32i", "abi": "ilp32", "text_address": 0,
        "compressed_instructions": False, "linker_relaxation": False,
        "instruction_words": len(words), "mem_bytes": len(expected), "gnu_bytes": len(actual),
        "mismatching_bytes": mismatch_count,
        "mem_sha256": hashlib.sha256(expected).hexdigest(),
        "gnu_sha256": hashlib.sha256(actual).hexdigest(),
        "assembly_sha256": hashlib.sha256(assembly.read_bytes()).hexdigest(),
        "rom_text_sha256": hashlib.sha256(rom_path.read_bytes()).hexdigest(),
    }
    if mismatch_count:
        index = next((idx for idx, (a, b) in enumerate(zip(expected, actual)) if a != b), min(len(expected), len(actual)))
        address = index & ~3
        summary["first_mismatch"] = {
            "byte_address": index, "instruction_address": address,
            "mem_word": expected[address:address+4].hex(), "gnu_word": actual[address:address+4].hex(),
        }
    (OUTPUT / "verification.json").write_text(json.dumps(summary, indent=2) + "\n")
    sample = run([tools["objdump"], "-d", "-M", "no-aliases,numeric", "--start-address=0", "--stop-address=128", elf])
    (OUTPUT / "disassembly_sample.txt").write_text(sample)
    report = "\n".join([
        "# App05 independent instruction-encoding verification", "",
        f"Result: **{summary['status']}**", "",
        f"Tool: {version}. ISA=rv32i, ABI=ilp32, ELF32, .text linked at address zero.",
        "Compressed instructions and linker relaxation disabled to preserve 32-bit instruction addresses.", "",
        "The existing assembly listing was assembled and linked by GNU tools.",
        "GNU objcopy extracted the .text section as a raw binary. Separately, the",
        "existing ROM .mem words were converted to four little-endian bytes each.",
        "The two binaries were compared byte for byte, including resolved branch",
        "and jump immediates and absolute label-address relocations.", "",
        f"- Instruction words: {len(words):,}", f"- ROM code bytes: {len(expected):,}",
        f"- GNU code bytes: {len(actual):,}", f"- Mismatching bytes: {mismatch_count}",
        f"- ROM binary SHA-256: `{summary['mem_sha256']}`",
        f"- GNU binary SHA-256: `{summary['gnu_sha256']}`", "",
        "Artifacts: app05_instruction.gnu.bin, app05_instruction.from_mem.bin,",
        "app05_instruction.elf, verification.json, commands.log, disassembly_sample.txt.", "",
        "This checks encoding consistency with an independent assembler for every",
        "instruction in this ROM. It does not prove that every possible RV32I",
        "instruction/operand combination or the CPU implementation is correct.", "",
    ])
    (OUTPUT / "RESULTS.md").write_text(report, encoding="utf-8")
    print(f"GNU RV32I encoding {summary['status']}: {len(words):,} instructions, {len(actual):,} bytes, {mismatch_count} mismatching bytes")
    print(f"ROM SHA256: {summary['mem_sha256']}")
    print(f"GNU SHA256: {summary['gnu_sha256']}")
    print(f"Report: {OUTPUT / 'RESULTS.md'}")
    if mismatch_count:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
