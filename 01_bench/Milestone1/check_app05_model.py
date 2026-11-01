"""Execute the emitted ROM with an independent simple RV32I software model."""
import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[2] / "02_test" / "Milestone1" / "apps"
MASK = 0xFFFFFFFF


def sx(value, bits):
    return value - (1 << bits) if value & (1 << (bits-1)) else value


def main():
    manifest = json.loads((BASE / "app05_manifest.json").read_text())
    rom = [int(line, 16) for line in (BASE / "app05_instruction.mem").read_text().splitlines()]
    regs, memory = [0]*32, {}
    pc = 0
    for steps in range(5000000):
        assert pc % 4 == 0 and 0 <= pc//4 < len(rom), hex(pc)
        inst = rom[pc//4]
        op, rd, f3 = inst & 127, (inst >> 7) & 31, (inst >> 12) & 7
        rs1, rs2, f7 = (inst >> 15) & 31, (inst >> 20) & 31, inst >> 25
        a, b = regs[rs1], regs[rs2]
        imm = sx(inst >> 20, 12)
        next_pc, result, writes = pc+4, 0, False
        if op in (0x33, 0x13):
            operand = b if op == 0x33 else imm & MASK
            amount = operand & 31
            subtract = op == 0x33 and f7 == 32
            arithmetic = f3 == 5 and f7 == 32
            if f3 == 0: result = a-operand if subtract else a+operand
            elif f3 == 1: result = a << amount
            elif f3 == 2: result = int(sx(a, 32) < sx(operand, 32))
            elif f3 == 3: result = int(a < operand)
            elif f3 == 4: result = a ^ operand
            elif f3 == 5: result = sx(a, 32) >> amount if arithmetic else a >> amount
            elif f3 == 6: result = a | operand
            else: result = a & operand
            writes = True
        elif op in (0x37, 0x17):
            result = (inst & 0xFFFFF000) + (pc if op == 0x17 else 0)
            writes = True
        elif op == 0x63:
            offset = sx(((inst >> 31) << 12) | (((inst >> 7) & 1) << 11) | (((inst >> 25) & 63) << 5) | (((inst >> 8) & 15) << 1), 13)
            condition = {0: a == b, 1: a != b, 4: sx(a, 32) < sx(b, 32),
                         5: sx(a, 32) >= sx(b, 32), 6: a < b, 7: a >= b}[f3]
            if condition: next_pc = pc+offset
        elif op == 0x6F:
            offset = sx(((inst >> 31) << 20) | (((inst >> 12) & 255) << 12) | (((inst >> 20) & 1) << 11) | (((inst >> 21) & 1023) << 1), 21)
            result, writes, next_pc = pc+4, True, pc+offset
        elif op == 0x67:
            result, writes, next_pc = pc+4, True, (a+imm) & MASK & ~1
        elif op == 3:
            address = (a+imm) & MASK
            size = 1 << (f3 & 3)
            assert address % size == 0
            result = sum(memory.get(address+idx, 0) << (idx*8) for idx in range(size))
            if not (f3 & 4): result = sx(result, size*8)
            writes = True
        elif op == 0x23:
            offset = sx(((inst >> 25) << 5) | ((inst >> 7) & 31), 12)
            address, size = (a+offset) & MASK, 1 << f3
            assert address % size == 0
            if address == 0x7010:
                actual = sum(memory.get(0x7000+idx, 0) << (idx*8) for idx in range(4))
                assert b == 0x600D and actual == manifest["expected_ledr"], (hex(b), actual, manifest["cases"][actual-1])
                print(f"APP05 software model PASS: {actual} checks, {steps+1} instructions")
                return
            for idx in range(size): memory[address+idx] = (b >> (idx*8)) & 255
        else:
            raise AssertionError((hex(pc), hex(inst)))
        if writes and rd: regs[rd] = result & MASK
        regs[0] = 0
        pc = next_pc & MASK
    raise AssertionError("Software model timeout")


if __name__ == "__main__":
    main()
