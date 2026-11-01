# App05 independent instruction-encoding verification

Result: **PASS**

Tool: GNU assembler (GNU Binutils for Ubuntu) 2.42. ISA=rv32i, ABI=ilp32, ELF32, .text linked at address zero.
Compressed instructions and linker relaxation disabled to preserve 32-bit instruction addresses.

The existing assembly listing was assembled and linked by GNU tools.
GNU objcopy extracted the .text section as a raw binary. Separately, the
existing ROM .mem words were converted to four little-endian bytes each.
The two binaries were compared byte for byte, including resolved branch
and jump immediates and absolute label-address relocations.

- Instruction words: 530,151
- ROM code bytes: 2,120,604
- GNU code bytes: 2,120,604
- Mismatching bytes: 0
- ROM binary SHA-256: `16f98a1d92f003189cc5b969755c40a74534e323ef126683da976754c5ab8b6a`
- GNU binary SHA-256: `16f98a1d92f003189cc5b969755c40a74534e323ef126683da976754c5ab8b6a`

Artifacts: app05_instruction.gnu.bin, app05_instruction.from_mem.bin,
app05_instruction.elf, verification.json, commands.log, disassembly_sample.txt.

This checks encoding consistency with an independent assembler for every
instruction in this ROM. It does not prove that every possible RV32I
instruction/operand combination or the CPU implementation is correct.
