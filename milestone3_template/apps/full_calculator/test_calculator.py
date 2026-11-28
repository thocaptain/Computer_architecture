#!/usr/bin/env python3
"""Execute actual assembled RV32I words, compare arithmetic and exercise UI."""
from pathlib import Path
import random
import subprocess

ROOT = Path(__file__).resolve().parent
MASK = 0xffffffff
BASE = 0x80000000
RAM = 0x84000000

def signed(v):
    return (v & 0x7fffffff) - (v & 0x80000000)

def sext(v, bits):
    return (v ^ (1 << (bits-1))) - (1 << (bits-1))

class Machine:
    def __init__(self):
        data = (ROOT/'full_calculator.bin').read_bytes()
        self.mem = {BASE+i: b for i, b in enumerate(data)}
        self.r = [0]*32
        self.pc = BASE
        self.sw = 0
        self.key = 15
        self.timer = 0
        self.timer_reads = 0
        self.io = {}
        self.steps = 0

    def load(self, addr, size):
        if addr == 0x40002000:
            return self.sw
        if addr == 0x40003000:
            return (~self.key) & 15
        if addr == 0x40004004:
            self.timer += 500000 # accelerate polling, retaining debounce samples
            self.timer_reads += 1
            return self.timer & MASK
        return sum(self.mem.get(addr+i, 0) << (i*8) for i in range(size))

    def store(self, addr, size, value):
        if 0x40000000 <= addr < 0x40010000:
            self.io[addr] = value & MASK
            return
        assert RAM <= addr < RAM+1024, hex(addr)
        for i in range(size):
            self.mem[addr+i] = (value >> (8*i)) & 255

    def step(self):
        self.steps += 1
        ins = self.load(self.pc, 4)
        op, rd, f = ins & 127, ins >> 7 & 31, ins >> 12 & 7
        a, b = self.r[ins >> 15 & 31], self.r[ins >> 20 & 31]
        imm = sext(ins >> 20, 12)
        nxt, value, write = (self.pc+4)&MASK, 0, True
        if op == 0x37:
            value = ins & 0xfffff000
        elif op == 0x17:
            value = self.pc + (ins & 0xfffff000)
        elif op in (0x13, 0x33):
            right = imm & MASK if op == 0x13 else b
            shift = right & 31
            if f == 0:
                value = a-b if op == 0x33 and ins >> 25 == 32 else a+right
            elif f == 1:
                value = a << shift
            elif f == 2:
                value = int(signed(a) < signed(right))
            elif f == 3:
                value = int(a < right)
            elif f == 4:
                value = a ^ right
            elif f == 5:
                value = signed(a) >> shift if ins & (1<<30) else a >> shift
            elif f == 6:
                value = a | right
            elif f == 7:
                value = a & right
            else:
                raise AssertionError(hex(ins))
        elif op == 3:
            size = {0:1,1:2,2:4,4:1,5:2}[f]
            assert RAM <= (a+imm)&MASK < RAM+1024 or 0x40000000 <= (a+imm)&MASK < 0x40010000, 'Data bus cannot read IMEM'
            value = self.load((a+imm)&MASK, size)
            if f in (0,1):
                value = sext(value, size*8)
        elif op == 0x23:
            offset = sext((ins >> 25 << 5) | (ins >> 7 & 31), 12)
            self.store((a+offset)&MASK, {0:1,1:2,2:4}[f], b)
            write = False
        elif op == 0x63:
            offset = sext((ins>>31<<12) | ((ins>>7&1)<<11) |
                          ((ins>>25&63)<<5) | ((ins>>8&15)<<1), 13)
            take = {0:a==b,1:a!=b,4:signed(a)<signed(b),5:signed(a)>=signed(b),
                    6:a<b,7:a>=b}[f]
            if take:
                nxt = (self.pc+offset)&MASK
            write = False
        elif op == 0x6f:
            offset = sext((ins>>31<<20) | ((ins>>12&255)<<12) |
                          ((ins>>20&1)<<11) | ((ins>>21&1023)<<1), 21)
            value, nxt = nxt, (self.pc+offset)&MASK
        elif op == 0x67:
            value, nxt = nxt, (a+imm)&MASK&~1
        else:
            raise AssertionError((hex(self.pc),hex(ins)))
        if write and rd:
            self.r[rd] = value & MASK
        self.pc = nxt

    def call(self, addr, a, b, op):
        self.pc = addr
        self.r[1] = 0
        self.r[2] = RAM+1024
        self.r[10:13] = [a&MASK,b&MASK,op]
        for _ in range(5000):
            self.step()
            if self.pc == 0:
                return signed(self.r[10]),signed(self.r[11]),self.r[12]
        raise AssertionError('function timeout')

    def ticks(self, count=4):
        target = self.timer_reads+count
        for _ in range(100000):
            self.step()
            if self.timer_reads >= target:
                return
        raise AssertionError('UI timeout')

    def press(self, bit):
        self.key = 15 ^ (1<<bit)
        self.ticks()
        self.key = 15
        self.ticks()

    def enter(self, n):
        negative = n < 0
        for ch in str(abs(n)):
            self.sw = int(ch) | (16 if negative else 0)
            self.press(1)
        self.press(2)

    def ram(self, offset):
        return self.load(RAM+offset,4)

def expected(a,b,op):
    rem = 0
    if op == 0:
        answer = a+b
    elif op == 1:
        answer = a-b
    elif op == 2:
        answer = a*b
    else:
        if b == 0:
            return 0,0,1
        answer = abs(a)//abs(b)
        if (a<0) != (b<0):
            answer = -answer
        rem = a-answer*b
    if not -(1<<31) <= answer < (1<<31):
        return 0,0,2
    return answer,rem,0

SEG = [0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f]
def check_display(m, n, upper=False):
    mag = abs(n)
    digits = str(mag)[::-1]
    digits = digits[7:] if upper else digits[:7]
    if not digits:
        digits = '0'
    want = [SEG[int(c)] for c in digits] + [0]*(7-len(digits))
    want += [0x40 if n<0 else 0]
    actual = [m.io.get(0x40001000+i*4,0) for i in range(8)]
    assert actual == want, (n, upper, actual, want)

def main():
    nm = subprocess.check_output(['riscv64-unknown-elf-nm', str(ROOT/'full_calculator.elf')],text=True)
    symbols = {parts[2]:int(parts[0],16) for line in nm.splitlines()
               if len(parts:=line.split()) == 3}
    m = Machine()
    vals = [-(1<<31),-(1<<31)+1,-10000000,-65536,-46341,-1,0,1,2,46340,65536,10000000,(1<<31)-1]
    count = 0
    rng = random.Random(20261118)
    pairs = [(a,b) for a in vals for b in vals]
    pairs += [(rng.randint(-(1<<31),(1<<31)-1),rng.randint(-(1<<31),(1<<31)-1)) for _ in range(1500)]
    for a,b in pairs:
        for op in range(4):
            got = m.call(symbols['calculate'],a,b,op)
            assert got == expected(a,b,op), (a,b,op,got,expected(a,b,op))
            count += 1
    print(f'PASS {count} arithmetic cases on assembled instructions')
    ui_cases = [(-12,5,2),(-12,5,3),(12,-5,3),(-12,-5,3),
                (2147483647,0,0),(-2147483648,1,3),(1,0,3),
                (2147483647,1,0),(-2147483648,-1,3),(65536,65536,2),
                (0,-5,2),(12345678,-12345678,1),(-2147483648,-2147483648,1)]
    m = Machine()
    m.ticks()
    for a,b,op in ui_cases:
        assert m.ram(8) == 0
        m.enter(a)
        assert signed(m.ram(0)) == a and m.ram(8) == 1
        m.enter(b)
        assert signed(m.ram(4)) == b and m.ram(8) == 2
        m.sw = op<<5
        m.ticks()
        m.sw |= 1<<17
        m.ticks()
        answer,rem,error = expected(a,b,op)
        assert m.ram(8) == 3
        assert (signed(m.ram(28)),signed(m.ram(32)),m.ram(36)) == (answer,rem,error)
        if not error:
            check_display(m,answer)
            # A held key must not trigger multiple view changes.
            m.press(3)
            if abs(answer)>=10000000:
                check_display(m,answer,True)
                m.press(3)
            if op == 3:
                check_display(m,rem)
            else:
                check_display(m,answer)
        else:
            assert m.io[0x40000004] & 128
            assert m.io[0x40001000] == SEG[error]
        m.sw = 0
        m.ticks()
    print(f'PASS {len(ui_cases)} complete A/B/operation/RUN/display/restart scenarios')
    m.sw=10
    m.press(1)
    assert m.ram(36)==3 and m.ram(12)==0
    m.sw=7
    m.press(1)
    assert m.ram(36)==0 and m.ram(12)==7
    m.press(3)
    assert m.ram(12)==0
    # Held KEY1 adds once; single-sample bounce must add nothing.
    m.sw=9
    m.key=13
    m.ticks(12)
    assert m.ram(12)==9
    m.key=15
    m.ticks()
    # Reject unsigned +2147483648 at confirmation; allow changing sign.
    m = Machine()
    m.ticks()
    for ch in '2147483648':
        m.sw=int(ch)
        m.press(1)
    m.press(2)
    assert m.ram(36)==4 and m.ram(8)==0
    m.sw=16
    m.press(2)
    assert signed(m.ram(0)) == -2147483648 and m.ram(8)==1
    print('PASS invalid digits, backspace, held button and signed input boundary')

if __name__ == '__main__':
    main()
