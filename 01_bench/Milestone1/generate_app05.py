"""App 05: bounded exhaustive RV32I instruction sweeps, no external assembler.

Emit real RV32I instructions, a readable assembly listing, a ROM image, and an
explicit coverage manifest. Golden arithmetic is computed here, outside RTL.
"""
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "02_test" / "Milestone1" / "apps"
MASK = 0xFFFFFFFF
VALUES = [0, 1, 2, 31, 32, 33, 0x7FFFFFFF, 0x80000000,
          MASK, MASK-1, 0x80000001, 0x55555555, 0xAAAAAAAA, 0xFFFF, 0x10000, 0x12345678]
R = {"add": (0, 0), "sub": (0, 32), "sll": (1, 0), "slt": (2, 0),
     "sltu": (3, 0), "xor": (4, 0), "srl": (5, 0), "sra": (5, 32),
     "or": (6, 0), "and": (7, 0)}
I = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
B = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}
LOAD = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORE = {"sb": 0, "sh": 1, "sw": 2}


def signed(value):
    value &= MASK
    return value - (1 << 32) if value & (1 << 31) else value


def save(path, content):
    if not path.exists() or path.read_text(encoding="ascii") != content:
        path.write_text(content, encoding="ascii")


def golden(name, a, b):
    return {"add": lambda: a+b, "sub": lambda: a-b, "sll": lambda: a << (b & 31),
            "slt": lambda: int(signed(a) < signed(b)), "sltu": lambda: int(a < b),
            "xor": lambda: a ^ b, "srl": lambda: a >> (b & 31),
            "sra": lambda: signed(a) >> (b & 31), "or": lambda: a | b,
            "and": lambda: a & b}[name]() & MASK


class Program:
    def __init__(self):
        self.words, self.listing, self.labels, self.fixups = [], [], {}, []
        self.coverage = Counter()
        self.cases = []
        self.serial = 0

    @property
    def pc(self):
        return len(self.words) * 4

    def label(self, name):
        assert name not in self.labels
        self.labels[name] = self.pc
        self.listing.append(f"{name}:")

    def unique(self, prefix):
        self.serial += 1
        return f"{prefix}_{self.serial}"

    def emit(self, word, asm):
        self.words.append(word & MASK)
        self.listing.append(f"    {asm}")

    def imm(self, name, rd, rs, imm):
        assert -2048 <= imm <= 2047
        self.emit(((imm & 4095) << 20) | (rs << 15) | (I[name] << 12) | (rd << 7) | 0x13,
                  f"{name} x{rd}, x{rs}, {imm}")

    def li(self, rd, value):
        value &= MASK
        if -2048 <= signed(value) <= 2047:
            self.imm("addi", rd, 0, signed(value))
        else:
            upper = ((value + 0x800) >> 12) & 0xFFFFF
            low = signed((value - (upper << 12)) & MASK)
            self.emit((upper << 12) | (rd << 7) | 0x37, f"lui x{rd}, 0x{upper:x}")
            self.imm("addi", rd, rd, low)

    def address(self, rd, label, adjustment=0):
        pos = len(self.words)
        self.emit(0, f"lui x{rd}, %hi({label}{adjustment:+d})")
        self.emit(0, f"addi x{rd}, x{rd}, %lo({label}{adjustment:+d})")
        self.fixups.append(("address", pos, rd, label, adjustment))

    def reg(self, name, rd=3, rs1=1, rs2=2):
        f3, f7 = R[name]
        self.emit((f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33,
                  f"{name} x{rd}, x{rs1}, x{rs2}")

    def shift(self, name, rd, rs, shamt):
        f3, high = (1, 0) if name == "slli" else (5, 0x400 if name == "srai" else 0)
        self.emit(((high | shamt) << 20) | (rs << 15) | (f3 << 12) | (rd << 7) | 0x13,
                  f"{name} x{rd}, x{rs}, {shamt}")

    def branch(self, name, rs1, rs2, target):
        pos = len(self.words)
        self.emit(0, f"{name} x{rs1}, x{rs2}, {target}")
        self.fixups.append(("branch", pos, B[name], rs1, rs2, target))

    def jal(self, rd, target):
        pos = len(self.words)
        self.emit(0, f"jal x{rd}, {target}")
        self.fixups.append(("jal", pos, rd, target))

    def jalr(self, rd, rs, imm=0):
        self.emit(((imm & 4095) << 20) | (rs << 15) | (rd << 7) | 0x67,
                  f"jalr x{rd}, {imm}(x{rs})")

    def memory(self, name, rd_or_rs, base, offset):
        assert -2048 <= offset <= 2047
        if name in LOAD:
            word = ((offset & 4095) << 20) | (base << 15) | (LOAD[name] << 12) | (rd_or_rs << 7) | 3
        else:
            immediate = offset & 4095
            word = ((immediate >> 5) << 25) | (rd_or_rs << 20) | (base << 15) | (STORE[name] << 12) | ((immediate & 31) << 7) | 0x23
        self.emit(word, f"{name} x{rd_or_rs}, {offset}(x{base})")

    def check(self, reg, expected, instruction, description):
        case_id = len(self.cases) + 1
        self.cases.append({"id": case_id, "instruction": instruction, "detail": description, "check_pc": self.pc})
        self.coverage[instruction] += 1
        self.li(28, case_id)
        self.li(4, expected)
        ok = self.unique("check_ok")
        self.branch("beq", reg, 4, ok)
        self.jalr(0, 30)
        self.label(ok)

    def finish(self):
        self.li(31, 0x7000)
        self.li(3, len(self.cases))
        self.memory("sw", 3, 31, 0)
        self.li(3, 0x600D)
        self.memory("sw", 3, 31, 16)
        self.label("DONE")
        self.jal(0, "DONE")
        self.label("FAIL")
        self.li(31, 0x7000)
        self.memory("sw", 28, 31, 0)
        self.li(3, 0xBAD)
        self.memory("sw", 3, 31, 16)
        self.jal(0, "FAIL")
        for fixup in self.fixups:
            kind, pos, *args = fixup
            if kind == "address":
                rd, label, adjustment = args
                value = self.labels[label] + adjustment
                upper = ((value + 0x800) >> 12) & 0xFFFFF
                low = (value - (upper << 12)) & 4095
                self.words[pos] = (upper << 12) | (rd << 7) | 0x37
                self.words[pos+1] = (low << 20) | (rd << 15) | (rd << 7) | 0x13
            elif kind == "branch":
                f3, rs1, rs2, label = args
                delta = self.labels[label] - pos*4
                assert -4096 <= delta <= 4094 and delta % 2 == 0
                imm = delta & 8191
                self.words[pos] = ((imm >> 12) << 31) | (((imm >> 5) & 63) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((imm >> 1) & 15) << 8) | (((imm >> 11) & 1) << 7) | 0x63
            else:
                rd, label = args
                delta = self.labels[label] - pos*4
                assert -(1 << 20) <= delta < (1 << 20) and delta % 2 == 0
                imm = delta & 0x1FFFFF
                self.words[pos] = ((imm >> 20) << 31) | (((imm >> 1) & 1023) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 255) << 12) | (rd << 7) | 0x6F


def generate():
    p = Program()
    p.label("_start")
    p.address(30, "FAIL")
    for name in R:
        for a in VALUES:
            for b in VALUES:
                p.li(1, a); p.li(2, b); p.reg(name)
                p.check(3, golden(name, a, b), name, f"a={a:08x} b={b:08x}")
    for name in I:
        for immediate in range(-2048, 2048):
            a = VALUES[immediate & 15]
            p.li(1, a); p.imm(name, 3, 1, immediate)
            operation = "sltu" if name == "sltiu" else name[:-1]
            p.check(3, golden(operation, a, immediate & MASK), name, f"imm={immediate} a={a:08x}")
    for name in ("slli", "srli", "srai"):
        for a in VALUES:
            for amount in range(32):
                p.li(1, a); p.shift(name, 3, 1, amount)
                p.check(3, golden(name[:-1], a, amount), name, f"a={a:08x} shamt={amount}")
    for name in ("sll", "srl", "sra"):
        for a in VALUES:
            for amount in range(32):
                for high in (0, 32, 0xFFFFFFE0):
                    p.li(1, a); p.li(2, high | amount); p.reg(name)
                    p.check(3, golden(name, a, amount), name, f"shamt={amount} high={high:08x}")
    for name in B:
        for a in VALUES:
            for b in VALUES:
                condition = {"beq": a == b, "bne": a != b, "blt": signed(a) < signed(b),
                             "bge": signed(a) >= signed(b), "bltu": a < b, "bgeu": a >= b}[name]
                yes, end = p.unique("taken"), p.unique("branch_end")
                p.li(1, a); p.li(2, b); p.li(3, 0)
                p.branch(name, 1, 2, yes); p.jal(0, end)
                p.label(yes); p.li(3, 1); p.label(end)
                p.check(3, int(condition), name, f"taken={int(condition)} a={a:08x} b={b:08x}")
        # A negative branch displacement, taken once, checks backward redirection.
        body, entry, end = p.unique("back_body"), p.unique("back_entry"), p.unique("back_end")
        p.jal(0, entry); p.label(body); p.li(3, 1); p.jal(0, end); p.label(entry)
        a, b = {"beq": (1, 1), "bne": (1, 2), "blt": (0, 1), "bge": (1, 0),
                "bltu": (0, 1), "bgeu": (1, 0)}[name]
        p.li(1, a); p.li(2, b); p.li(3, 0); p.branch(name, 1, 2, body); p.label(end)
        p.check(3, 1, name, "negative displacement / taken")
    for value in [0, 1, 0x7FFFF, 0x80000, 0xFFFFF] + [1 << n for n in range(20)]:
        for name, opcode in (("lui", 0x37), ("auipc", 0x17)):
            pc = p.pc
            p.emit((value << 12) | (3 << 7) | opcode, f"{name} x3, 0x{value:x}")
            p.check(3, ((value << 12) + (pc if name == "auipc" else 0)) & MASK, name, f"upper={value:05x}")

    # Exhaust every *aligned* signed 12-bit memory offset for every supported width.
    p.li(29, 0x2800)
    for store, size, signed_load, unsigned_load in (("sb", 1, "lb", "lbu"), ("sh", 2, "lh", "lhu"), ("sw", 4, "lw", "lw")):
        for offset in range(-2048, 2048, size):
            bits = size * 8
            value = ((offset * 65537) ^ 0xA5F0807F) & MASK
            field = value & ((1 << bits)-1)
            expected_signed = field - (1 << bits) if field & (1 << (bits-1)) else field
            aligned = offset & ~3
            p.li(1, 0x55555555); p.memory("sw", 1, 29, aligned)
            p.li(1, value); p.memory(store, 1, 29, offset)
            p.memory(signed_load, 3, 29, offset)
            p.check(3, expected_signed & MASK, signed_load, f"offset={offset} signed / after {store}")
            if size != 4:
                p.memory(unsigned_load, 3, 29, offset)
                p.check(3, field, unsigned_load, f"offset={offset} zero extension")
            merged = (0x55555555 & ~(((1 << bits)-1) << (8*(offset & 3)))) | (field << (8*(offset & 3)))
            p.memory("lw", 3, 29, aligned)
            p.check(3, merged & MASK, store, f"offset={offset} byte lanes / neighbor preservation")

    # All architectural register indices appear as destination and both source roles.
    for role in ("rd", "rs1", "rs2"):
        for reg in range(32):
            if role == "rd":
                p.li(1, 0x12345678); p.li(2, 0x01020304); p.reg("add", reg)
                p.imm("addi", 5, reg, 0)
                expected = 0 if reg == 0 else 0x1336597C
            elif role == "rs1":
                p.li(reg, 17); p.li(2 if reg != 2 else 6, 23)
                p.reg("add", 5, reg, 2 if reg != 2 else 6)
                expected = 23 if reg == 0 else 40
            else:
                p.li(reg, 17); p.li(1 if reg != 1 else 6, 23)
                p.reg("add", 5, 1 if reg != 1 else 6, reg)
                expected = 23 if reg == 0 else 40
            p.address(30, "FAIL")
            p.check(5, expected, "add", f"register role {role}=x{reg}")
    for name in R:
        for rd in (1, 2):
            p.li(1, 0x80000001); p.li(2, 31); p.reg(name, rd)
            p.check(rd, golden(name, 0x80000001, 31), name, f"rd aliases rs{rd}")

    for rd in range(32):
        target = p.unique("jal_target")
        p.li(3, 0); link = p.pc + 4
        p.jal(rd, target); p.li(3, 1); p.label(target)
        p.imm("addi", 5, rd, 0); p.address(30, "FAIL")
        p.check(5, link if rd else 0, "jal", f"link rd=x{rd}")
        # rd=x3 intentionally overwrites marker; link check above is authoritative.
        if rd != 3:
            p.check(3, 0, "jal", "wrong-path flush")
    for immediate in range(-2048, 2048):
        target = p.unique("jalr_target")
        p.address(6, target, -immediate); p.li(3, 0); link = p.pc + 4
        p.jalr(5, 6, immediate); p.li(3, 1); p.label(target)
        p.check(5, link, "jalr", f"immediate={immediate} link")
        p.check(3, 0, "jalr", f"immediate={immediate} wrong-path flush")
    # Check the architectural bit-zero clearing rule explicitly with AUIPC at target.
    target = p.unique("jalr_odd_target")
    p.address(6, target, 1); p.jalr(5, 6); p.li(3, 1); p.label(target)
    target_pc = p.pc
    p.emit((3 << 7) | 0x17, "auipc x3, 0")
    p.check(3, target_pc, "jalr", "odd target must clear bit 0, observed through AUIPC")

    assert len(p.coverage) == 37, sorted(p.coverage)
    assert len(p.cases) < (1 << 18), "Result must fit the board LEDR width"
    p.finish()
    assert p.pc <= (1 << 22), "Simulation instruction ROM exceeds 4 MiB"
    OUT.mkdir(parents=True, exist_ok=True)
    save(OUT / "app05_instruction.mem", "".join(f"{word:08x}\n" for word in p.words))
    save(OUT / "app05_instruction.s", ".option norvc\n.option norelax\n.text\n.globl _start\n" + "\n".join(p.listing) + "\n")
    manifest = {"app": "app05_instruction", "expected_ledr": len(p.cases), "words": len(p.words),
                "bytes": p.pc, "imem_addr_width": 22, "timeout_cycles": 20000000,
                "coverage": dict(sorted(p.coverage.items())), "cases": p.cases,
                "scope": "37 implemented RV32I instructions; exhaustive 12-bit ALU/JALR immediates, aligned load/store offsets, all 5-bit shifts; directed 32-bit operands/register roles/branches/U-type immediates. Not all 32-bit operand tuples; excludes unsupported FENCE/SYSTEM/traps and misaligned data accesses."}
    save(OUT / "app05_manifest.json", json.dumps(manifest, indent=2) + "\n")
    save(OUT / "app05_config.h", f"#define APP05_EXPECTED {len(p.cases)}u\n#define APP05_TIMEOUT 20000000ull\n")
    print(f"APP05 generated: {len(p.cases)} checks, {len(p.coverage)} instructions, {p.pc} bytes")


if __name__ == "__main__":
    generate()
