#!/usr/bin/env python3
"""
Generate all RV32I test programs.

Run:  python3 tools/generate_tests.py
Then: make test_all
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from gen_test import TestProgram


def gen_test_basic():
    """ADDI, ADD, SUB, SW, LW, BEQ, JAL — the smoke test."""
    t = TestProgram("test_basic", cycles=20)

    t.addi(1, 0, 5)        # x1 = 5
    t.addi(2, 0, 3)        # x2 = 3
    t.add(3, 1, 2)         # x3 = 8
    t.sub(4, 1, 2)         # x4 = 2
    t.sw(3, 0, 0)          # mem[0] = 8
    t.lw(5, 0, 0)          # x5 = 8
    t.beq(3, 5, 8)         # taken → skip next
    t.addi(6, 0, 99)       # SKIPPED
    t.addi(7, 0, 1)        # x7 = 1 (branch target)
    t.jal(8, 8)            # x8 = PC+4 = 0x28, jump +8
    t.addi(9, 0, 99)       # SKIPPED
    t.addi(10, 0, 42)      # x10 = 42 (JAL target)

    t.expect_reg(1, 5)
    t.expect_reg(2, 3)
    t.expect_reg(3, 8)
    t.expect_reg(4, 2)
    t.expect_mem(0, 8)
    t.expect_reg(5, 8)
    t.expect_reg_not(6, 99)
    t.expect_reg(7, 1)
    t.expect_reg(8, 0x28)
    t.expect_reg_not(9, 99)
    t.expect_reg(10, 42)
    t.generate()


def gen_test_alu():
    """AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA + immediate variants."""
    t = TestProgram("test_alu", cycles=35)

    # Setup
    t.addi(1, 0, 0xFF)     # x1 = 255  (0x000000FF)
    t.addi(2, 0, 0x0F)     # x2 = 15   (0x0000000F)

    # --- AND ---
    t.and_(3, 1, 2)        # x3 = 0xFF & 0x0F = 0x0F = 15
    t.andi(4, 1, 0x0F)     # x4 = 0xFF & 0x0F = 0x0F = 15

    # --- OR ---
    t.or_(5, 1, 2)         # x5 = 0xFF | 0x0F = 0xFF = 255
    t.ori(6, 1, 0x700)     # x6 = 0xFF | 0x700 = 0x7FF = 2047

    # --- XOR ---
    t.xor(7, 1, 2)         # x7 = 0xFF ^ 0x0F = 0xF0 = 240
    t.xori(8, 1, 0x0F)     # x8 = 0xFF ^ 0x0F = 0xF0 = 240

    # --- SLT (signed) ---
    t.addi(9, 0, 5)        # x9 = 5
    t.addi(10, 0, 10)      # x10 = 10
    t.slt(11, 9, 10)       # x11 = 1 (5 < 10 signed)
    t.slt(12, 10, 9)       # x12 = 0 (10 < 5? no)
    t.slti(13, 9, 10)      # x13 = 1 (5 < 10)

    # --- SLTU (unsigned) ---
    t.addi(14, 0, -1)      # x14 = 0xFFFFFFFF
    t.sltu(15, 9, 14)      # x15 = 1 (5 < 0xFFFFFFFF unsigned)

    # --- SLL (shift left logical) ---
    t.addi(16, 0, 1)       # x16 = 1
    t.addi(17, 0, 4)       # x17 = 4
    t.sll(18, 16, 17)      # x18 = 1 << 4 = 16
    t.slli(19, 16, 4)      # x19 = 1 << 4 = 16

    # --- SRL (shift right logical) ---
    t.addi(20, 0, 256)     # x20 = 256 (0x100)
    t.srl(21, 20, 17)      # x21 = 256 >> 4 = 16
    t.srli(22, 20, 4)      # x22 = 256 >> 4 = 16

    # --- SRA (shift right arithmetic — sign extends) ---
    t.addi(23, 0, -128)    # x23 = 0xFFFFFF80 (-128)
    t.addi(24, 0, 2)       # x24 = 2
    t.sra(25, 23, 24)      # x25 = -128 >> 2 = -32 = 0xFFFFFFE0
    t.srai(26, 23, 2)      # x26 = -128 >> 2 = -32 = 0xFFFFFFE0

    t.expect_reg(1, 255)
    t.expect_reg(2, 15)
    t.expect_reg(3, 15)            # AND
    t.expect_reg(4, 15)            # ANDI
    t.expect_reg(5, 255)           # OR
    t.expect_reg(6, 2047)          # ORI
    t.expect_reg(7, 240)           # XOR
    t.expect_reg(8, 240)           # XORI
    t.expect_reg(11, 1)            # SLT true
    t.expect_reg(12, 0)            # SLT false
    t.expect_reg(13, 1)            # SLTI true
    t.expect_reg(15, 1)            # SLTU true
    t.expect_reg(18, 16)           # SLL
    t.expect_reg(19, 16)           # SLLI
    t.expect_reg(21, 16)           # SRL
    t.expect_reg(22, 16)           # SRLI
    t.expect_reg(25, 0xFFFFFFE0)   # SRA  (-32)
    t.expect_reg(26, 0xFFFFFFE0)   # SRAI (-32)
    t.generate()


def gen_test_branches():
    """All 6 branch types — both taken and not-taken paths."""
    t = TestProgram("test_branches", cycles=45)

    # Setup values
    t.addi(1, 0, 5)        # x1 = 5
    t.addi(2, 0, 5)        # x2 = 5
    t.addi(3, 0, 10)       # x3 = 10
    t.addi(4, 0, -1)       # x4 = 0xFFFFFFFF (for unsigned tests)

    # --- BEQ taken (5 == 5) ---
    t.beq(1, 2, 8)         # taken → skip next
    t.addi(5, 0, 99)       # SKIPPED
    t.addi(6, 0, 1)        # x6 = 1 (branch target)

    # --- BEQ not taken (5 != 10) ---
    t.beq(1, 3, 8)         # not taken
    t.addi(7, 0, 1)        # x7 = 1 (executed)

    # --- BNE taken (5 != 10) ---
    t.bne(1, 3, 8)         # taken → skip next
    t.addi(8, 0, 99)       # SKIPPED
    t.addi(9, 0, 1)        # x9 = 1 (branch target)

    # --- BNE not taken (5 == 5) ---
    t.bne(1, 2, 8)         # not taken
    t.addi(10, 0, 1)       # x10 = 1 (executed)

    # --- BLT taken (signed: 5 < 10) ---
    t.blt(1, 3, 8)         # taken
    t.addi(11, 0, 99)      # SKIPPED
    t.addi(12, 0, 1)       # x12 = 1 (branch target)

    # --- BLT not taken (10 < 5? no) ---
    t.blt(3, 1, 8)         # not taken
    t.addi(13, 0, 1)       # x13 = 1 (executed)

    # --- BGE taken (10 >= 5) ---
    t.bge(3, 1, 8)         # taken
    t.addi(14, 0, 99)      # SKIPPED
    t.addi(15, 0, 1)       # x15 = 1 (branch target)

    # --- BGE not taken (5 >= 10? no) ---
    t.bge(1, 3, 8)         # not taken
    t.addi(16, 0, 1)       # x16 = 1 (executed)

    # --- BLTU taken (unsigned: 5 < 0xFFFFFFFF) ---
    t.bltu(1, 4, 8)        # taken
    t.addi(17, 0, 99)      # SKIPPED
    t.addi(18, 0, 1)       # x18 = 1 (branch target)

    # --- BGEU taken (unsigned: 0xFFFFFFFF >= 5) ---
    t.bgeu(4, 1, 8)        # taken
    t.addi(19, 0, 99)      # SKIPPED
    t.addi(20, 0, 1)       # x20 = 1 (branch target)

    # Checks — taken branches: skipped instruction must NOT have run
    t.expect_reg_not(5, 99)     # BEQ taken → skipped
    t.expect_reg(6, 1)          # BEQ target reached
    t.expect_reg(7, 1)          # BEQ not-taken → executed
    t.expect_reg_not(8, 99)     # BNE taken → skipped
    t.expect_reg(9, 1)          # BNE target reached
    t.expect_reg(10, 1)         # BNE not-taken → executed
    t.expect_reg_not(11, 99)    # BLT taken → skipped
    t.expect_reg(12, 1)         # BLT target reached
    t.expect_reg(13, 1)         # BLT not-taken → executed
    t.expect_reg_not(14, 99)    # BGE taken → skipped
    t.expect_reg(15, 1)         # BGE target reached
    t.expect_reg(16, 1)         # BGE not-taken → executed
    t.expect_reg_not(17, 99)    # BLTU taken → skipped
    t.expect_reg(18, 1)         # BLTU target reached
    t.expect_reg_not(19, 99)    # BGEU taken → skipped
    t.expect_reg(20, 1)         # BGEU target reached
    t.generate()


def gen_test_memory():
    """LB, LBU, LH, LHU, SB, SH — sign-extension and byte-lane tests."""
    t = TestProgram("test_memory", cycles=30)

    # --- Store a known word: 0xFFFFFFFF at address 0 ---
    t.addi(1, 0, -1)       # x1 = 0xFFFFFFFF
    t.sw(1, 0, 0)          # mem[word 0] = 0xFFFFFFFF

    # --- LB vs LBU: byte with bit 7 set ---
    t.lb(2, 0, 0)          # x2 = sign_ext(0xFF) = 0xFFFFFFFF (-1)
    t.lbu(3, 0, 0)         # x3 = zero_ext(0xFF) = 0x000000FF (255)

    # --- LH vs LHU: halfword with bit 15 set ---
    t.lh(4, 0, 0)          # x4 = sign_ext(0xFFFF) = 0xFFFFFFFF (-1)
    t.lhu(5, 0, 0)         # x5 = zero_ext(0xFFFF) = 0x0000FFFF (65535)

    # --- SB: store a single byte, verify with LW ---
    t.sw(0, 0, 4)          # Clear mem[word 1] = 0x00000000
    t.addi(6, 0, 0x41)     # x6 = 65 (ASCII 'A')
    t.sb(6, 0, 4)          # Store byte 0 of word 1 = 0x41
    t.lw(7, 0, 4)          # x7 = 0x00000041

    # --- SH: store a halfword, verify with LH and LHU ---
    t.sw(0, 0, 8)          # Clear mem[word 2] = 0x00000000
    t.addi(8, 0, -2)       # x8 = 0xFFFFFFFE
    t.sh(8, 0, 8)          # Store lower half of word 2 = 0xFFFE
    t.lh(9, 0, 8)          # x9 = sign_ext(0xFFFE) = 0xFFFFFFFE (-2)
    t.lhu(10, 0, 8)        # x10 = zero_ext(0xFFFE) = 0x0000FFFE

    # --- LB/LBU with a positive byte (bit 7 = 0): should give same result ---
    t.lb(11, 0, 4)         # x11 = sign_ext(0x41) = 0x00000041
    t.lbu(12, 0, 4)        # x12 = zero_ext(0x41) = 0x00000041

    t.expect_reg(2, 0xFFFFFFFF)    # LB  sign-ext
    t.expect_reg(3, 0x000000FF)    # LBU zero-ext
    t.expect_reg(4, 0xFFFFFFFF)    # LH  sign-ext
    t.expect_reg(5, 0x0000FFFF)    # LHU zero-ext
    t.expect_reg(7, 0x00000041)    # LW  after SB
    t.expect_reg(9, 0xFFFFFFFE)    # LH  sign-ext (negative halfword)
    t.expect_reg(10, 0x0000FFFE)   # LHU zero-ext
    t.expect_reg(11, 0x00000041)   # LB  positive (same as LBU)
    t.expect_reg(12, 0x00000041)   # LBU positive
    t.expect_mem(0, 0xFFFFFFFF)    # SW  verification
    t.expect_mem(1, 0x00000041)    # SB  verification
    t.expect_mem(2, 0x0000FFFE)    # SH  verification
    t.generate()


def gen_test_upper():
    """LUI, AUIPC, JALR."""
    t = TestProgram("test_upper", cycles=20)

    # --- LUI: load upper immediate ---
    # 0x00: lui x1, 0x12345000  →  x1 = 0x12345000
    t.lui(1, 0x12345000)

    # --- LUI with bit 31 set ---
    # 0x04: lui x2, 0xABCDE000  →  x2 = 0xABCDE000
    t.lui(2, 0xABCDE000)

    # --- AUIPC: add upper immediate to PC ---
    # 0x08: auipc x3, 0x1000  →  x3 = 0x08 + 0x00001000 = 0x00001008
    t.auipc(3, 0x00001000)

    # --- JALR: jump and link register ---
    # 0x0C: addi x4, x0, 0x1C  →  x4 = 28 (target address)
    t.addi(4, 0, 0x1C)

    # 0x10: jalr x5, x4, 0  →  target = (28 + 0) & ~1 = 0x1C
    #                            x5 = 0x10 + 4 = 0x14 (return address)
    t.jalr(5, 4, 0)

    # 0x14: SKIPPED
    t.addi(6, 0, 99)
    # 0x18: SKIPPED
    t.addi(7, 0, 99)
    # 0x1C: JALR target
    t.addi(8, 0, 42)       # x8 = 42

    t.expect_reg(1, 0x12345000)    # LUI
    t.expect_reg(2, 0xABCDE000)    # LUI negative upper
    t.expect_reg(3, 0x00001008)    # AUIPC
    t.expect_reg(5, 0x14)          # JALR return address
    t.expect_reg_not(6, 99)        # JALR skipped
    t.expect_reg_not(7, 99)        # JALR skipped
    t.expect_reg(8, 42)            # JALR target reached
    t.generate()


def gen_test_edge():
    """Corner cases that commonly break real CPUs."""
    t = TestProgram("test_edge", cycles=30)

    # --- Write to x0 must be ignored ---
    # 0x00: addi x0, x0, 5  →  x0 must stay 0
    t.addi(0, 0, 5)

    # --- Negative immediates ---
    # 0x04: addi x1, x0, -1     →  x1 = 0xFFFFFFFF
    t.addi(1, 0, -1)
    # 0x08: addi x2, x0, -2048  →  x2 = 0xFFFFF800 (min 12-bit signed)
    t.addi(2, 0, -2048)

    # --- Max positive immediate ---
    # 0x0C: addi x3, x0, 2047   →  x3 = 0x000007FF (max 12-bit signed)
    t.addi(3, 0, 2047)

    # --- Signed vs unsigned comparison with same value ---
    # x4 = -1 = 0xFFFFFFFF, x5 = 1
    t.addi(4, 0, -1)       # x4 = 0xFFFFFFFF
    t.addi(5, 0, 1)        # x5 = 1
    t.slt(6, 4, 5)         # x6 = 1 (signed: -1 < 1)
    t.sltu(7, 4, 5)        # x7 = 0 (unsigned: 0xFFFFFFFF > 1)

    # --- Back-to-back register dependencies ---
    # Each instruction reads the result of the previous one
    t.addi(8, 0, 1)        # x8 = 1
    t.add(9, 8, 8)         # x9 = 1 + 1 = 2
    t.add(10, 9, 8)        # x10 = 2 + 1 = 3

    # --- BGE with equal values (edge: >= includes ==) ---
    t.addi(11, 0, 5)       # x11 = 5
    t.addi(12, 0, 5)       # x12 = 5
    t.bge(11, 12, 8)       # taken (5 >= 5), skip next
    t.addi(13, 0, 99)      # SKIPPED
    t.addi(14, 0, 1)       # x14 = 1 (branch target)

    # --- SUB producing negative result ---
    t.addi(15, 0, 3)       # x15 = 3
    t.addi(16, 0, 10)      # x16 = 10
    t.sub(17, 15, 16)      # x17 = 3 - 10 = -7 = 0xFFFFFFF9

    # --- SLTI with negative immediate ---
    t.addi(18, 0, -5)      # x18 = -5
    t.slti(19, 18, -1)     # x19 = 1 (signed: -5 < -1)

    t.expect_reg(1, 0xFFFFFFFF)    # -1
    t.expect_reg(2, 0xFFFFF800)    # -2048
    t.expect_reg(3, 0x000007FF)    # 2047
    t.expect_reg(6, 1)             # SLT:  -1 < 1 (signed)
    t.expect_reg(7, 0)             # SLTU: 0xFFFFFFFF > 1 (unsigned)
    t.expect_reg(8, 1)             # dependency chain
    t.expect_reg(9, 2)             # dependency chain
    t.expect_reg(10, 3)            # dependency chain
    t.expect_reg_not(13, 99)       # BGE == case skipped
    t.expect_reg(14, 1)            # BGE target reached
    t.expect_reg(17, 0xFFFFFFF9)   # SUB negative result (-7)
    t.expect_reg(19, 1)            # SLTI negative < negative
    t.generate()

def gen_test_fibonacci():
    """Fibonacci series up to 10."""
    t = TestProgram("test_fibonacci", cycles=200)
    t.addi(1, 0, 1)        # x1 = 1  (fib_prev)
    t.addi(2, 0, 1)        # x2 = 1  (fib_curr)
    t.addi(3, 0, 9)        # x3 = 9 (loop limit)
    t.addi(4, 0, 1)        # x4 = 1  (loop counter)
    t.addi(5, 0, 0)        # x5 = 0  (temp)

    # Loop start (PC=20)
    t.sltu(7, 4, 3)        # x7 = 1 if (x4 < x3)
    t.beq(7, 0, 24)        # if x7==0 (loop done), branch forward 6 instructions (+24 bytes)
    t.mv(5, 1)             # temp = fib_prev
    t.mv(1, 2)             # fib_prev = fib_curr
    t.add(2, 1, 5)         # fib_curr = fib_prev + temp
    t.addi(4, 4, 1)        # counter++
    t.jal(0, -24)          # jump backward 6 instructions (-24 bytes) to sltu
    
    # Loop end (PC=48)
    t.sw(2, 0, 4)          # store final result (x2) to memory at byte address 4 (word 1)

    # The 10th Fibonacci number is 55 (0x37)
    t.expect_reg(2, 55)
    t.expect_mem(1, 55)
    t.generate()

# ============================================================================
# Main: generate all tests
# ============================================================================
if __name__ == "__main__":
    print("=" * 60)
    print("  Generating all RV32I test programs")
    print("=" * 60)
    print()
    gen_test_basic()
    print()
    gen_test_alu()
    print()
    gen_test_branches()
    print()
    gen_test_memory()
    print()
    gen_test_upper()
    print()
    gen_test_edge()
    print()
    gen_test_fibonacci()
    print()
    print("=" * 60)
    print("  Done! Run 'make test_all' to execute all tests.")
    print("=" * 60)
