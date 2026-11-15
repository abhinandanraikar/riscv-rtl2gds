#!/usr/bin/env python3
"""random_test.py - constrained-random RV32I programs checked against a
small Python reference model (instruction set simulator).

For each seed: generate a program, run it in the reference model, run it in
the RTL simulation, then compare all 31 registers.
Usage:  python3 scripts/random_test.py [number_of_programs] [instructions]
Run from the project root.
"""
import random, subprocess, sys, os

M = 0xFFFFFFFF
def sx(v, bits): return (v ^ (1 << (bits - 1))) - (1 << (bits - 1))
def s32(v): return sx(v & M, 32)

# ----------------------------------------------------------------- encoders
def R(f7, rs2, rs1, f3, rd, op=0x33): return f7 << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | rd << 7 | op
def I(imm, rs1, f3, rd, op): return (imm & 0xFFF) << 20 | rs1 << 15 | f3 << 12 | rd << 7 | op
def S(imm, rs2, rs1, f3):
    imm &= 0xFFF
    return (imm >> 5) << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | (imm & 31) << 7 | 0x23
def B(imm, rs2, rs1, f3):
    imm &= 0x1FFF
    return ((imm >> 12) << 31 | ((imm >> 5) & 63) << 25 | rs2 << 20 | rs1 << 15 |
            f3 << 12 | ((imm >> 1) & 15) << 8 | ((imm >> 11) & 1) << 7 | 0x63)
def U(imm20, rd, op): return (imm20 & 0xFFFFF) << 12 | rd << 7 | op
def J(imm, rd):
    imm &= 0x1FFFFF
    return ((imm >> 20) << 31 | ((imm >> 1) & 0x3FF) << 21 | ((imm >> 11) & 1) << 20 |
            ((imm >> 12) & 0xFF) << 12 | rd << 7 | 0x6F)
NOP = I(0, 0, 0, 0, 0x13)

# ---------------------------------------------------------------- generator
def gen(n, rng):
    prog = []
    reg = lambda: rng.choice([0] + list(range(1, 16)) * 3)
    for r in range(1, 16):                       # give every register a value
        prog.append(U(rng.getrandbits(20), r, 0x37))
        prog.append(I(rng.getrandbits(12), r, 0, r, 0x13))
    prog.append(I(0, 0, 0, 16, 0x13))            # x16 = address register, always in RAM
    while len(prog) < n:
        k = rng.random()
        if k < 0.30:                             # register-register
            f3 = rng.randrange(8)
            f7 = 0x20 if f3 in (0, 5) and rng.random() < 0.5 else 0
            prog.append(R(f7, reg(), reg(), f3, reg()))
        elif k < 0.55:                           # register-immediate
            f3 = rng.randrange(8)
            if f3 == 1:   imm = rng.randrange(32)
            elif f3 == 5: imm = rng.randrange(32) | (0x400 if rng.random() < 0.5 else 0)
            else:         imm = rng.getrandbits(12)
            prog.append(I(imm, reg(), f3, reg(), 0x13))
        elif k < 0.60:
            prog.append(U(rng.getrandbits(20), reg(), rng.choice([0x37, 0x17])))
        elif k < 0.80:                           # load / store
            f3 = rng.choice([0, 1, 2])
            off = rng.randrange(0, 0x400) & ~((1 << f3) - 1)
            base = 0
            if rng.random() < 0.5:               # address taken from a register
                base = 16
                prog.append(I(0x3FC, reg(), 7, 16, 0x13))        # andi x16, r, 0x3FC
                off &= 3
            if rng.random() < 0.5:
                prog.append(S(off, reg(), base, f3))
            else:
                lf3 = f3 if f3 == 2 or rng.random() < 0.5 else f3 | 4
                prog.append(I(off, base, lf3, reg(), 0x03))
        elif k < 0.95:                           # forward branch over 0-3 instrs
            skip = rng.randrange(0, 4)
            prog.append(B(4 * (skip + 1), reg(), reg(), rng.choice([0, 1, 4, 5, 6, 7])))
        else:                                    # forward jump with link
            skip = rng.randrange(0, 4)
            prog.append(J(4 * (skip + 1), reg()))
    prog += [NOP] * 8                            # landing pad + drain the pipeline
    # two NOPs let the write to x31 finish before the testbench dumps registers
    prog += [I(1, 0, 0, 31, 0x13), NOP, NOP, S(-4, 31, 0, 2), J(0, 0)]
    return prog

# ---------------------------------------------------------- reference model
def run_model(prog):
    x = [0] * 32; mem = {}; pc = 0
    rd_w = lambda a: mem.get(a >> 2, 0)
    for _ in range(100000):
        ins = prog[pc >> 2] if (pc >> 2) < len(prog) else NOP
        op, rd, f3 = ins & 0x7F, (ins >> 7) & 31, (ins >> 12) & 7
        rs1, rs2, f7 = (ins >> 15) & 31, (ins >> 20) & 31, ins >> 25
        a, b = x[rs1], x[rs2]
        npc, val = pc + 4, None
        def alu(f3, a, b, alt):
            sh = b & 31
            return [(a - b) if alt else (a + b), a << sh, int(s32(a) < s32(b)), int(a < b),
                    a ^ b, (s32(a) >> sh) if alt else (a >> sh), a | b, a & b][f3] & M
        if op == 0x33:   val = alu(f3, a, b, f7 == 0x20)
        elif op == 0x13: val = alu(f3, a, sx(ins >> 20, 12) & M, f3 == 5 and f7 == 0x20)
        elif op == 0x37: val = ins & 0xFFFFF000
        elif op == 0x17: val = (pc + (ins & 0xFFFFF000)) & M
        elif op == 0x6F:
            imm = sx(((ins >> 31) << 20) | (((ins >> 12) & 0xFF) << 12) |
                     (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1), 21)
            val, npc = pc + 4, (pc + imm) & M
        elif op == 0x63:
            imm = sx(((ins >> 31) << 12) | (((ins >> 7) & 1) << 11) |
                     (((ins >> 25) & 63) << 5) | (((ins >> 8) & 15) << 1), 13)
            t = {0: a == b, 1: a != b, 4: s32(a) < s32(b), 5: s32(a) >= s32(b),
                 6: a < b, 7: a >= b}[f3]
            if t: npc = (pc + imm) & M
        elif op == 0x03:
            addr = (a + sx(ins >> 20, 12)) & M
            w = rd_w(addr) >> (8 * (addr & 3))
            val = {0: sx(w & 0xFF, 8), 1: sx(w & 0xFFFF, 16), 2: w, 4: w & 0xFF, 5: w & 0xFFFF}[f3] & M
        elif op == 0x23:
            addr = (a + sx((f7 << 5) | rd, 12)) & M
            if addr == 0xFFFFFFFC: return x, mem
            size = 8 << f3; mask = ((1 << size) - 1) << (8 * (addr & 3))
            mem[addr >> 2] = (rd_w(addr) & ~mask | (b << (8 * (addr & 3))) & mask) & M
        if val is not None and op != 0x23 and op != 0x63 and rd: x[rd] = val & M
        pc = npc
    raise RuntimeError("model did not finish")

# --------------------------------------------------------------------- main
def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    length = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    os.makedirs("results/sim", exist_ok=True)
    hexf, dump, vvp = "results/sim/random.hex", "results/sim/random.regs", "results/sim/random.vvp"
    rtl = sorted("rtl/" + f for f in os.listdir("rtl") if f.endswith(".v"))
    subprocess.run(["iverilog", "-g2005", "-o", vvp, f'-Priscv_tb.INIT_FILE="{hexf}"',
                    "tb/riscv_tb.v"] + rtl, check=True)
    bad = 0
    for seed in range(count):
        prog = gen(length, random.Random(seed))
        open(hexf, "w").write("".join(f"{w:08x}\n" for w in prog))
        x, _ = run_model(prog)
        out = subprocess.run(["vvp", "-n", vvp, f"+regdump={dump}"], capture_output=True, text=True).stdout
        got = [0 if 'x' in l else int(l, 16) for l in open(dump)]   # x = never written
        if got != x[1:]:
            bad += 1
            print(f"seed {seed}: MISMATCH")
            if got:
                for i, (g, e) in enumerate(zip(got, x[1:]), 1):
                    if g != e: print(f"   x{i}: rtl={g:08x} model={e:08x}")
            else:
                print("   " + out.strip().splitlines()[-1])
    print(f"{count - bad}/{count} random programs matched the reference model")
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
