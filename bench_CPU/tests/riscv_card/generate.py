#!/usr/bin/env python3
"""Build small self-checking RV32I ROMs against 99_doc/RISCV_CARD.pdf.

Uses GNU binutils rather than a second handwritten instruction encoder. Each
case fits the existing 256-word ROM and runs with a freshly reset CPU model.
"""
import csv
import re
import shutil
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "generated"
MASK = 0xFFFFFFFF
CASES = []
BASE_INSTRUCTIONS = "add sub xor or and sll srl sra slt sltu addi xori ori andi slli srli srai slti sltiu lb lh lw lbu lhu sb sh sw beq bne blt bge bltu bgeu jal jalr lui auipc".split()


def signed(value):
    value &= MASK
    return value if value < 0x80000000 else value - 0x100000000


def li(reg, value):
    return "li {}, {}".format(reg, signed(value))


def address(reg, label):
    # Independent absolute-address reference for PC-relative instructions.
    return ["lui {}, %hi({})".format(reg, label),
            "addi {0}, {0}, %lo({1})".format(reg, label)]


class Case:
    def __init__(self, name, group):
        self.name, self.group = name, group
        self.lines, self.checks = [], 0
        CASES.append(self)

    def emit(self, *lines):
        self.lines.extend(lines)
        return self

    def check(self, reg, value):
        self.checks += 1
        self.emit("li s10, {}".format(self.checks), li("t6", value),
                  "bne {}, t6, fail".format(reg))

    def equal(self, lhs, rhs):
        self.checks += 1
        self.emit("li s10, {}".format(self.checks),
                  "bne {}, {}, fail".format(lhs, rhs))


def integer_cases():
    pairs = [(0, 0), (1, MASK), (0x7FFFFFFF, 1), (0x80000000, MASK),
             (0x80000000, 0x7FFFFFFF), (MASK, MASK),
             (0xAAAAAAAA, 0x55555555), (0x89ABCDEF, 4)]
    operations = {
        "add": lambda a, b: a + b, "sub": lambda a, b: a - b,
        "xor": lambda a, b: a ^ b, "or": lambda a, b: a | b,
        "and": lambda a, b: a & b,
        "slt": lambda a, b: int(signed(a) < signed(b)),
        "sltu": lambda a, b: int((a & MASK) < (b & MASK)),
    }
    for op, reference in operations.items():
        c = Case(op, "RV32I")
        for a, b in pairs:
            c.emit(li("t0", a), li("t1", b), "{} t2, t0, t1".format(op))
            c.check("t2", reference(a, b))

    shifts = {"sll": lambda a, n: a << n,
              "srl": lambda a, n: (a & MASK) >> n,
              "sra": lambda a, n: signed(a) >> n}
    for op, reference in shifts.items():
        for suffix, amounts in [("shamt_0_15", range(16)),
                                ("shamt_16_31", range(16, 32)),
                                ("masked_shamt", [32, 33, 63, 0xFFFFFFFF])]:
            c = Case(op + "_" + suffix, "RV32I")
            for n in amounts:
                c.emit(li("t0", 0x80000001), li("t1", n),
                       "{} t2, t0, t1".format(op))
                c.check("t2", reference(0x80000001, n & 31))
        for suffix, amounts in [("shamt_0_15", range(16)),
                                ("shamt_16_31", range(16, 32))]:
            c = Case(op + "i_" + suffix, "RV32I")
            for n in amounts:
                c.emit(li("t0", 0x80000001), "{}i t2, t0, {}".format(op, n))
                c.check("t2", reference(0x80000001, n))

    immediate_ops = {"addi": lambda a, i: a + i,
                     "xori": lambda a, i: a ^ (i & MASK),
                     "ori": lambda a, i: a | (i & MASK),
                     "andi": lambda a, i: a & (i & MASK),
                     "slti": lambda a, i: int(signed(a) < i),
                     "sltiu": lambda a, i: int((a & MASK) < (i & MASK))}
    vectors = [(0, -2048), (0, -1), (MASK, 1), (0x7FFFFFFF, 1),
               (0x80000000, -1), (0x12345678, 2047), (0xFFFFFFFF, 0)]
    for op, reference in immediate_ops.items():
        c = Case(op, "RV32I")
        for a, imm in vectors:
            c.emit(li("t0", a), "{} t2, t0, {}".format(op, imm))
            c.check("t2", reference(a, imm))

    c = Case("lui", "RV32I")
    for upper in [0, 1, 0x7FFFF, 0x80000, 0xFFFFF]:
        c.emit("lui t2, {}".format(upper))
        c.check("t2", upper << 12)

    c = Case("auipc", "RV32I")
    for i, upper in enumerate([0, 1, 0x7FFFF, 0x80000, 0xFFFFF]):
        label = "pc_{}".format(i)
        c.emit(label + ":", "auipc t2, {}".format(upper), *address("t0", label),
               "lui t1, {}".format(upper), "add t0, t0, t1")
        c.equal("t2", "t0")


def memory_cases():
    for op in ["lb", "lbu", "lh", "lhu", "lw"]:
        c = Case(op, "RV32I")
        c.emit("lui s0, 2", li("t0", 0x80FF7F01), "sw t0, 0(s0)")
        width = 1 if op in ["lb", "lbu"] else 2 if op in ["lh", "lhu"] else 4
        for offset in range(0, 4, width):
            value = (0x80FF7F01 >> (offset * 8)) & ((1 << (width * 8)) - 1)
            if op in ["lb", "lh"] and value & (1 << (width * 8 - 1)):
                value -= 1 << (width * 8)
            c.emit("{} t2, {}(s0)".format(op, offset))
            c.check("t2", value)
        c.emit("addi s1, s0, 4", "{} t2, -4(s1)".format(op))
        value = 1 if width == 1 else 0x7F01 if width == 2 else 0x80FF7F01
        c.check("t2", value)

    for op, width in [("sb", 1), ("sh", 2), ("sw", 4)]:
        c = Case(op, "RV32I")
        c.emit("lui s0, 2")
        for offset in range(0, 4, width):
            c.emit(li("t0", 0x11223344), "sw t0, 0(s0)", li("t1", 0xDEADBEEF),
                   "{} t1, {}(s0)".format(op, offset), "lw t2, 0(s0)")
            mask = ((1 << (width * 8)) - 1) << (offset * 8)
            expected = (0x11223344 & ~mask) | ((0xDEADBEEF << (offset * 8)) & mask)
            c.check("t2", expected)
        c.emit("addi s1, s0, 4", li("t1", 0x87654321),
               "{} t1, -4(s1)".format(op), "{} t2, 0(s0)".format({1: "lbu", 2: "lhu", 4: "lw"}[width]))
        c.check("t2", 0x87654321 & ((1 << (width * 8)) - 1))


def branch_cases():
    predicates = {"beq": lambda a, b: a == b, "bne": lambda a, b: a != b,
                  "blt": lambda a, b: signed(a) < signed(b),
                  "bge": lambda a, b: signed(a) >= signed(b),
                  "bltu": lambda a, b: (a & MASK) < (b & MASK),
                  "bgeu": lambda a, b: (a & MASK) >= (b & MASK)}
    pairs = [(0, 0), (1, 1), (MASK, 1), (1, MASK),
             (0x80000000, 0x7FFFFFFF), (0x7FFFFFFF, 0x80000000)]
    for op, predicate in predicates.items():
        c = Case(op, "RV32I")
        for i, (a, b) in enumerate(pairs):
            c.emit("li s10, {}".format(i + 1), li("t0", a), li("t1", b))
            if predicate(a, b):
                c.emit("{} t0, t1, taken_{}".format(op, i), "j fail", "taken_{}:".format(i))
            else:
                c.emit("{} t0, t1, fail".format(op))
        # Backward branch, first taken and then not taken at the same PC.
        yes = next((a, b) for a, b in pairs if predicate(a, b))
        no = next((a, b) for a, b in pairs if not predicate(a, b))
        c.emit(li("t0", yes[0]), li("t1", yes[1]), "li t2, 0", "j back_check", "back_target:",
               li("t0", no[0]), li("t1", no[1]), "li t2, 1", "back_check:",
               "{} t0, t1, back_target".format(op))
        c.check("t2", 1)


def jump_cases():
    c = Case("jal", "RV32I")
    c.emit("jal t1, jal_target", "jal_return:", "j fail", "jal_target:",
           "addi t2, t1, 0", *address("t0", "jal_return"))
    c.equal("t2", "t0")
    c.emit("jal zero, no_link_target", "j fail", "no_link_target:")
    c.check("zero", 0)

    c = Case("jalr", "RV32I")
    c.emit(*address("t0", "jalr_target"), "addi t0, t0, -12", "jalr t1, 12(t0)",
           "jalr_return:", "j fail", "jalr_target:", "addi t2, t1, 0",
           *address("t0", "jalr_return"))
    c.equal("t2", "t0")
    # Negative immediate with rd == rs1 must use the old base register value.
    c.emit(*address("t0", "jalr_alias_target"), "addi t0, t0, 12", "jalr t0, -12(t0)",
           "jalr_alias_return:", "j fail", "jalr_alias_target:", "addi t2, t0, 0",
           *address("t0", "jalr_alias_return"))
    c.equal("t2", "t0")
    c.emit(*address("t0", "jalr_no_link_target"), "li t1, 77", "jalr zero, 0(t0)",
           "j fail", "jalr_no_link_target:")
    c.check("zero", 0)
    c.check("t1", 77)
    # The jump target is produced by the immediately preceding load.
    c.emit("lui s0, 2", *address("t0", "jalr_loaded_target"), "sw t0, 0(s0)",
           "lw t1, 0(s0)", "jalr t2, 0(t1)", "jalr_loaded_return:", "j fail",
           "jalr_loaded_target:", "addi t3, t2, 0", *address("t0", "jalr_loaded_return"))
    c.equal("t3", "t0")

    # JALR must clear bit zero of the target, including on pipelined cores.
    c = Case("jalr_odd_target", "RV32I edge")
    # Clear bit zero after adding rs1 + imm, not before the addition.
    for i, (bias, imm) in enumerate([(1, 0), (0, 1), (2, -1), (-1, 1)]):
        target = "odd_target_{}".format(i)
        returned = "odd_return_{}".format(i)
        pc_label = "odd_pc_{}".format(i)
        c.emit(*address("t0", target))
        if bias:
            c.emit("addi t0, t0, {}".format(bias))
        c.emit("jalr t1, {}(t0)".format(imm), returned + ":", "j fail", target + ":",
               "addi t3, t1, 0", pc_label + ":", "auipc t2, 0", *address("t0", pc_label))
        c.equal("t2", "t0")
        c.emit(*address("t0", returned))
        c.equal("t3", "t0")


def hazard_cases():
    c = Case("x0_and_dependencies", "RV32I edge")
    c.emit("addi zero, zero, 123", "addi t0, zero, 1", "add zero, t0, t0")
    c.check("zero", 0)
    c.check("t0", 1)
    c.emit("addi t1, t0, 3", "add t2, t1, t0", "sub t2, t2, t1")
    c.check("t2", 1)

    c = Case("load_use_and_store_forwarding", "RV32I edge")
    c.emit("lui s0, 2", "li t0, 37", "sw t0, 0(s0)", "lw t1, 0(s0)",
           "add t2, t1, t1", "sw t2, 4(s0)", "lw t3, 4(s0)", "sw t3, 8(s0)", "lw t4, 8(s0)")
    c.check("t4", 74)

    c = Case("wrong_path_has_no_side_effects", "RV32I edge")
    c.emit("lui s0, 2", "sw zero, 0(s0)", "li t0, 1", "beq t0, t0, keep",
           "sw t0, 0(s0)", "li s8, 0", "keep:", "lw t2, 0(s0)")
    c.check("t2", 0)

    c = Case("cache_eviction_preserves_stores", "RV32I edge")
    c.emit("lui s0, 2", li("t0", 0x89ABCDEF), "sw t0, 0(s0)", "li t1, 123",
           "sw t1, 512(s0)", "lw t2, 0(s0)")
    c.check("t2", 0x89ABCDEF)
    c.emit("lw t2, 512(s0)")
    c.check("t2", 123)


def pseudo_cases():
    c = Case("pseudo_la", "Pseudo RV32I")
    c.emit("la t2, pseudo_address", *address("t0", "pseudo_address"))
    c.equal("t2", "t0")
    c.emit("pseudo_address:", "nop")

    simple = {"nop": ("li t2, 123\nnop", 123),
              "li": ("li t2, 0x89abcdef", 0x89ABCDEF),
              "mv": ("li t0, -123\nmv t2, t0", -123),
              "not": ("li t0, 0x12345678\nnot t2, t0", 0xEDCBA987),
              "neg": ("li t0, -123\nneg t2, t0", 123)}
    for op, (body, expected) in simple.items():
        c = Case("pseudo_" + op, "Pseudo RV32I")
        c.emit(body)
        c.check("t2", expected)
    for op, predicate in {"seqz": lambda n: n == 0, "snez": lambda n: n != 0,
                          "sltz": lambda n: n < 0, "sgtz": lambda n: n > 0}.items():
        c = Case("pseudo_" + op, "Pseudo RV32I")
        for n in [-1, 0, 1]:
            c.emit(li("t0", n), "{} t2, t0".format(op))
            c.check("t2", int(predicate(n)))

    unary = {"beqz": lambda n: n == 0, "bnez": lambda n: n != 0,
             "blez": lambda n: n <= 0, "bgez": lambda n: n >= 0,
             "bltz": lambda n: n < 0, "bgtz": lambda n: n > 0}
    for op, predicate in unary.items():
        c = Case("pseudo_" + op, "Pseudo RV32I")
        for i, n in enumerate([-1, 0, 1]):
            c.emit("li s10, {}".format(i + 1), li("t0", n))
            if predicate(n):
                c.emit("{} t0, yes_{}".format(op, i), "j fail", "yes_{}:".format(i))
            else:
                c.emit("{} t0, fail".format(op))
    for op, predicate in {"bgt": lambda a, b: signed(a) > signed(b),
                          "ble": lambda a, b: signed(a) <= signed(b),
                          "bgtu": lambda a, b: (a & MASK) > (b & MASK),
                          "bleu": lambda a, b: (a & MASK) <= (b & MASK)}.items():
        c = Case("pseudo_" + op, "Pseudo RV32I")
        for i, (a, b) in enumerate([(MASK, 1), (1, MASK), (1, 1)]):
            c.emit("li s10, {}".format(i + 1), li("t0", a), li("t1", b))
            if predicate(a, b):
                c.emit("{} t0, t1, yes_{}".format(op, i), "j fail", "yes_{}:".format(i))
            else:
                c.emit("{} t0, t1, fail".format(op))

    for op, width in [("lb", 1), ("lh", 2), ("lw", 4)]:
        c = Case("pseudo_" + op + "_symbol", "Pseudo RV32I")
        c.emit("lui s0, 2", li("t0", 0x89ABCDEF), "sw t0, 0(s0)", "{} t2, card_data".format(op))
        value = 0x89ABCDEF & ((1 << (8 * width)) - 1)
        if value & (1 << (8 * width - 1)):
            value -= 1 << (8 * width)
        c.check("t2", value)
    for op, load, expected in [("sb", "lbu", 0xEF), ("sh", "lhu", 0xCDEF), ("sw", "lw", 0x89ABCDEF)]:
        c = Case("pseudo_" + op + "_symbol", "Pseudo RV32I")
        c.emit("lui s0, 2", "sw zero, 0(s0)", li("t0", 0x89ABCDEF),
               "{} t0, card_data, t1".format(op), "{} t2, 0(s0)".format(load))
        c.check("t2", expected)

    for op in ["j", "jal", "jr", "jalr", "ret", "call", "tail"]:
        c = Case("pseudo_" + op, "Pseudo RV32I")
        if op == "j":
            c.emit("j target", "j fail", "target:")
        elif op in ["jal", "call"]:
            c.emit(op + " target", "return_here:", "j after_target", "target:",
                   "addi t2, ra, 0", "ret", "after_target:", *address("t0", "return_here"))
            c.equal("t2", "t0")
        elif op == "jalr":
            c.emit(*address("t0", "target"), "jalr t0", "return_here:", "j fail",
                   "target:", "addi t2, ra, 0", *address("t0", "return_here"))
            c.equal("t2", "t0")
        elif op == "ret":
            c.emit(*address("ra", "target"), "ret", "j fail", "target:")
        else:
            if op == "jr":
                c.emit(*address("t0", "target"), "jr t0")
            else:
                c.emit("tail target")
            c.emit("j fail", "target:")
        c.check("zero", 0)


UNSUPPORTED = {
    "RV32I system": ("No trap/environment implementation", ["ecall", "ebreak"]),
    "RV32M": ("No multiply/divide extension", ["mul", "mulh", "mulsu (mulhsu)", "mulu (mulhu)", "div", "divu", "rem", "remu"]),
    "RV32A": ("No atomic/reservation implementation", ["lr.w", "sc.w", "amoswap.w", "amoadd.w", "amoand.w", "amoor.w", "amoxor.w", "amomax.w", "amomin.w"]),
    "RV32F/D": ("No floating-point registers or execution unit", ["flw", "fsw", "fmadd.s", "fmsub.s", "fnmadd.s", "fnmsub.s", "fadd.s", "fsub.s", "fmul.s", "fdiv.s", "fsqrt.s", "fsgnj.s", "fsgnjn.s", "fsgnjx.s", "fmin.s", "fmax.s", "fcvt.s.w", "fcvt.s.wu", "fcvt.w.s", "fcvt.wu.s", "fmv.x.w", "fmv.w.x", "feq.s", "flt.s", "fle.s", "fclass.s"]),
    "RV32C": ("No 16-bit instruction fetch/decompression", ["c.lwsp", "c.swsp", "c.lw", "c.sw", "c.j", "c.jal", "c.jr", "c.jalr", "c.beqz", "c.bnez", "c.li", "c.lui", "c.addi", "c.addi16sp", "c.addi4spn", "c.slli", "c.srli", "c.srai", "c.andi", "c.mv", "c.add", "c.and", "c.or", "c.xor", "c.sub", "c.nop", "c.ebreak"]),
    "Pseudo unsupported": ("Requires RV64, floating point, or fence support", ["ld symbol", "sd symbol", "flw symbol", "fld symbol", "fsw symbol", "fsd symbol", "negw", "sext.w", "fmv.s", "fabs.s", "fneg.s", "fmv.d", "fabs.d", "fneg.d", "fence"]),
}


def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def main():
    tools = {name: shutil.which("riscv64-unknown-elf-" + name) for name in ["as", "ld", "objcopy", "objdump"]}
    if not all(tools.values()):
        raise SystemExit("Install GNU RISC-V binutils (riscv64-unknown-elf-as/ld/objcopy/objdump).")
    OUT.mkdir(parents=True, exist_ok=True)
    integer_cases()
    memory_cases()
    branch_cases()
    jump_cases()
    hazard_cases()
    pseudo_cases()
    rows = []
    assembled_instructions = set()
    for case_id, case in enumerate(CASES, 1):
        base = OUT / case.name
        source = [".option norvc", ".option norelax", ".option nopic", ".section .text",
                  ".globl _start", ".extern card_data", "_start:", "lui s8, 7",
                  "li s11, {}".format(case_id), "li s10, 0"] + case.lines + [
                      "j pass", "fail:", "sw s10, 0(s8)", "li t5, 0x0bad", "sw t5, 16(s8)", "j halt",
                      "pass:", "sw s11, 0(s8)", "li t5, 0x600d", "sw t5, 16(s8)", "halt:", "j halt"]
        base.with_suffix(".s").write_text("# {}: {}\n{}\n".format(case.name, case.group, "\n".join(source)))
        try:
            run(tools["as"], "-march=rv32i", "-mabi=ilp32", "-o", str(base.with_suffix(".o")), str(base.with_suffix(".s")))
            run(tools["ld"], "-m", "elf32lriscv", "--no-relax", "--defsym=card_data=0x2000", "-Ttext=0", "-e", "_start", "-o", str(base.with_suffix(".elf")), str(base.with_suffix(".o")))
            run(tools["objcopy"], "-O", "binary", "-j", ".text", str(base.with_suffix(".elf")), str(base.with_suffix(".bin")))
        except subprocess.CalledProcessError as exc:
            raise SystemExit("{}: {}".format(case.name, exc.stderr.decode()))
        data = base.with_suffix(".bin").read_bytes()
        if len(data) > 1024 or len(data) % 4:
            raise SystemExit("{}: invalid ROM size {} (limit 1024 bytes)".format(case.name, len(data)))
        words = list(struct.unpack("<{}I".format(len(data) // 4), data))
        words += [0x00000013] * (256 - len(words))
        base.with_suffix(".mem").write_text("\n".join("{:08x}".format(word) for word in words) + "\n")
        listing = subprocess.check_output([tools["objdump"], "-d", "-M", "no-aliases", str(base.with_suffix(".elf"))])
        base.with_suffix(".dis").write_bytes(listing)
        assembled_instructions.update(re.findall(
            r"^\s*[0-9a-f]+:\s+[0-9a-f]+\s+([a-z][a-z0-9.]*)", listing.decode(), re.MULTILINE))
        rows.append([case.name, case.group, "TEST", "tests/riscv_card/generated/" + case.name + ".mem", str(case_id), "20000", ""])
    for group, (reason, names) in UNSUPPORTED.items():
        for name in names:
            rows.append([name, group, "UNSUPPORTED", "-", "0", "0", reason])
    with (OUT / "manifest.tsv").open("w", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(["name", "group", "action", "rom", "id", "max_cycles", "note"])
        writer.writerows(rows)
    if set(BASE_INSTRUCTIONS) - assembled_instructions:
        raise SystemExit("Missing assembled instructions: " + str(set(BASE_INSTRUCTIONS) - assembled_instructions))
    with (OUT / "instruction_coverage.csv").open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(["instruction", "group", "action", "test_cases", "note"])
        for op in BASE_INSTRUCTIONS:
            names = [case.name for case in CASES if case.group == "RV32I" and
                     (case.name == op or case.name.startswith(op + "_"))]
            if not names:
                raise SystemExit("Missing dedicated instruction test: " + op)
            writer.writerow([op, "RV32I", "TEST", ";".join(names), ""])
        for case in CASES:
            if case.group == "Pseudo RV32I":
                writer.writerow([case.name[len("pseudo_"):].replace("_symbol", " symbol"),
                                 case.group, "TEST", case.name, "Assembled as RV32I with relaxation disabled"])
        for group, (reason, names) in UNSUPPORTED.items():
            for name in names:
                writer.writerow([name, group, "UNSUPPORTED", "", reason])
    print("Generated {} self-checking ROMs; {} unsupported card entries documented.".format(len(CASES), len(rows) - len(CASES)))


if __name__ == "__main__":
    main()
