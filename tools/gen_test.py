#!/usr/bin/env python3
"""
RISC-V RV32I Test Generator

Encodes RV32I assembly instructions into machine code (.hex) and
generates expected results (.expected) for the universal testbench.

Usage:
    from gen_test import TestProgram

    t = TestProgram("test_branches", cycles=30)
    t.addi(1, 0, 5)          # x1 = 5
    t.addi(2, 0, 5)          # x2 = 5
    t.beq(1, 2, 8)           # if x1 == x2, skip next instr
    t.addi(3, 0, 99)         # SKIPPED
    t.addi(4, 0, 1)          # branch target
    t.nop()

    t.expect_reg(1, 5)
    t.expect_reg(2, 5)
    t.expect_reg_not(3, 99)
    t.expect_reg(4, 1)
    t.generate()              # writes .hex and .expected to sw/asm/
"""

import os


# ============================================================================
# Encoding helpers
# ============================================================================

def _bits(value, width):
    """Mask value to width bits (handles negative via two's complement)."""
    return value & ((1 << width) - 1)


def _encode_r(funct7, rs2, rs1, funct3, rd, opcode=0b0110011):
    return (_bits(funct7, 7) << 25 | _bits(rs2, 5) << 20 |
            _bits(rs1, 5) << 15 | _bits(funct3, 3) << 12 |
            _bits(rd, 5) << 7 | _bits(opcode, 7))


def _encode_i(imm, rs1, funct3, rd, opcode):
    return (_bits(imm, 12) << 20 | _bits(rs1, 5) << 15 |
            _bits(funct3, 3) << 12 | _bits(rd, 5) << 7 |
            _bits(opcode, 7))


def _encode_s(imm, rs2, rs1, funct3, opcode=0b0100011):
    imm = _bits(imm, 12)
    return (((imm >> 5) & 0x7F) << 25 | _bits(rs2, 5) << 20 |
            _bits(rs1, 5) << 15 | _bits(funct3, 3) << 12 |
            (imm & 0x1F) << 7 | _bits(opcode, 7))


def _encode_b(imm, rs2, rs1, funct3, opcode=0b1100011):
    imm = _bits(imm, 13)
    bit12  = (imm >> 12) & 1
    bit11  = (imm >> 11) & 1
    bit10_5 = (imm >> 5) & 0x3F
    bit4_1  = (imm >> 1) & 0xF
    return ((bit12 << 31) | (bit10_5 << 25) | _bits(rs2, 5) << 20 |
            _bits(rs1, 5) << 15 | _bits(funct3, 3) << 12 |
            (bit4_1 << 8) | (bit11 << 7) | _bits(opcode, 7))


def _encode_u(imm, rd, opcode):
    return (_bits(imm >> 12, 20) << 12 | _bits(rd, 5) << 7 |
            _bits(opcode, 7))


def _encode_j(imm, rd, opcode=0b1101111):
    imm = _bits(imm, 21)
    bit20    = (imm >> 20) & 1
    bit19_12 = (imm >> 12) & 0xFF
    bit11    = (imm >> 11) & 1
    bit10_1  = (imm >> 1) & 0x3FF
    return ((bit20 << 31) | (bit10_1 << 21) | (bit11 << 20) |
            (bit19_12 << 12) | _bits(rd, 5) << 7 | _bits(opcode, 7))


# ============================================================================
# TestProgram class
# ============================================================================

class TestProgram:
    """Build a test program instruction by instruction."""

    OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "sw", "asm")

    def __init__(self, name, cycles=30):
        self.name = name
        self.cycles = cycles
        self.instructions = []  # list of (hex_word, comment_string)
        self.checks = []        # list of (type, addr, value)

    @property
    def pc(self):
        """Current PC (byte address of next instruction to be added)."""
        return len(self.instructions) * 4

    # ----------------------------------------------------------------
    # R-type instructions
    # ----------------------------------------------------------------
    def add(self, rd, rs1, rs2):
        self._emit(_encode_r(0x00, rs2, rs1, 0b000, rd), f"add  x{rd}, x{rs1}, x{rs2}")

    def sub(self, rd, rs1, rs2):
        self._emit(_encode_r(0x20, rs2, rs1, 0b000, rd), f"sub  x{rd}, x{rs1}, x{rs2}")

    def and_(self, rd, rs1, rs2):
        self._emit(_encode_r(0x00, rs2, rs1, 0b111, rd), f"and  x{rd}, x{rs1}, x{rs2}")

    def or_(self, rd, rs1, rs2):
        self._emit(_encode_r(0x00, rs2, rs1, 0b110, rd), f"or   x{rd}, x{rs1}, x{rs2}")

    def xor(self, rd, rs1, rs2):
        self._emit(_encode_r(0x00, rs2, rs1, 0b100, rd), f"xor  x{rd}, x{rs1}, x{rs2}")

    def slt(self, rd, rs1, rs2):
        self._emit(_encode_r(0x00, rs2, rs1, 0b010, rd), f"slt  x{rd}, x{rs1}, x{rs2}")

    def sltu(self, rd, rs1, rs2):
        self._emit(_encode_r(0x00, rs2, rs1, 0b011, rd), f"sltu x{rd}, x{rs1}, x{rs2}")

    def sll(self, rd, rs1, rs2):
        self._emit(_encode_r(0x00, rs2, rs1, 0b001, rd), f"sll  x{rd}, x{rs1}, x{rs2}")

    def srl(self, rd, rs1, rs2):
        self._emit(_encode_r(0x00, rs2, rs1, 0b101, rd), f"srl  x{rd}, x{rs1}, x{rs2}")

    def sra(self, rd, rs1, rs2):
        self._emit(_encode_r(0x20, rs2, rs1, 0b101, rd), f"sra  x{rd}, x{rs1}, x{rs2}")

    # ----------------------------------------------------------------
    # I-type ALU instructions
    # ----------------------------------------------------------------
    def addi(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b000, rd, 0b0010011), f"addi x{rd}, x{rs1}, {imm}")

    def andi(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b111, rd, 0b0010011), f"andi x{rd}, x{rs1}, {imm}")

    def ori(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b110, rd, 0b0010011), f"ori  x{rd}, x{rs1}, {imm}")

    def xori(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b100, rd, 0b0010011), f"xori x{rd}, x{rs1}, {imm}")

    def slti(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b010, rd, 0b0010011), f"slti x{rd}, x{rs1}, {imm}")

    def sltiu(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b011, rd, 0b0010011), f"sltiu x{rd}, x{rs1}, {imm}")

    def slli(self, rd, rs1, shamt):
        self._emit(_encode_i(shamt & 0x1F, rs1, 0b001, rd, 0b0010011), f"slli x{rd}, x{rs1}, {shamt}")

    def srli(self, rd, rs1, shamt):
        self._emit(_encode_i(shamt & 0x1F, rs1, 0b101, rd, 0b0010011), f"srli x{rd}, x{rs1}, {shamt}")

    def srai(self, rd, rs1, shamt):
        self._emit(_encode_i((0x20 << 5) | (shamt & 0x1F), rs1, 0b101, rd, 0b0010011), f"srai x{rd}, x{rs1}, {shamt}")

    # ----------------------------------------------------------------
    # Load instructions
    # ----------------------------------------------------------------
    def lw(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b010, rd, 0b0000011), f"lw   x{rd}, {imm}(x{rs1})")

    def lh(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b001, rd, 0b0000011), f"lh   x{rd}, {imm}(x{rs1})")

    def lb(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b000, rd, 0b0000011), f"lb   x{rd}, {imm}(x{rs1})")

    def lhu(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b101, rd, 0b0000011), f"lhu  x{rd}, {imm}(x{rs1})")

    def lbu(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b100, rd, 0b0000011), f"lbu  x{rd}, {imm}(x{rs1})")

    # ----------------------------------------------------------------
    # Store instructions
    # ----------------------------------------------------------------
    def sw(self, rs2, rs1, imm):
        self._emit(_encode_s(imm, rs2, rs1, 0b010), f"sw   x{rs2}, {imm}(x{rs1})")

    def sh(self, rs2, rs1, imm):
        self._emit(_encode_s(imm, rs2, rs1, 0b001), f"sh   x{rs2}, {imm}(x{rs1})")

    def sb(self, rs2, rs1, imm):
        self._emit(_encode_s(imm, rs2, rs1, 0b000), f"sb   x{rs2}, {imm}(x{rs1})")

    # ----------------------------------------------------------------
    # Branch instructions (imm is byte offset from current PC)
    # ----------------------------------------------------------------
    def beq(self, rs1, rs2, imm):
        self._emit(_encode_b(imm, rs2, rs1, 0b000), f"beq  x{rs1}, x{rs2}, {imm:+d}")

    def bne(self, rs1, rs2, imm):
        self._emit(_encode_b(imm, rs2, rs1, 0b001), f"bne  x{rs1}, x{rs2}, {imm:+d}")

    def blt(self, rs1, rs2, imm):
        self._emit(_encode_b(imm, rs2, rs1, 0b100), f"blt  x{rs1}, x{rs2}, {imm:+d}")

    def bge(self, rs1, rs2, imm):
        self._emit(_encode_b(imm, rs2, rs1, 0b101), f"bge  x{rs1}, x{rs2}, {imm:+d}")

    def bltu(self, rs1, rs2, imm):
        self._emit(_encode_b(imm, rs2, rs1, 0b110), f"bltu x{rs1}, x{rs2}, {imm:+d}")

    def bgeu(self, rs1, rs2, imm):
        self._emit(_encode_b(imm, rs2, rs1, 0b111), f"bgeu x{rs1}, x{rs2}, {imm:+d}")

    # ----------------------------------------------------------------
    # Jump instructions
    # ----------------------------------------------------------------
    def jal(self, rd, imm):
        self._emit(_encode_j(imm, rd), f"jal  x{rd}, {imm:+d}")

    def jalr(self, rd, rs1, imm):
        self._emit(_encode_i(imm, rs1, 0b000, rd, 0b1100111), f"jalr x{rd}, x{rs1}, {imm}")

    # ----------------------------------------------------------------
    # Upper immediate instructions
    # ----------------------------------------------------------------
    def lui(self, rd, imm):
        self._emit(_encode_u(imm, rd, 0b0110111), f"lui  x{rd}, 0x{_bits(imm >> 12, 20):05X}")

    def auipc(self, rd, imm):
        self._emit(_encode_u(imm, rd, 0b0010111), f"auipc x{rd}, 0x{_bits(imm >> 12, 20):05X}")

    # ----------------------------------------------------------------
    # Pseudo-instructions
    # ----------------------------------------------------------------
    def nop(self):
        self.addi(0, 0, 0)

    def li(self, rd, value):
        """Load a 32-bit immediate into rd (uses LUI + ADDI)."""
        value = _bits(value, 32)
        upper = (value + 0x800) & 0xFFFFF000  # adjust for sign of lower 12
        lower = value - upper
        if upper:
            self.lui(rd, upper)
            if lower:
                self.addi(rd, rd, _sign_extend(lower, 12))
        else:
            self.addi(rd, 0, _sign_extend(value, 12))

    def mv(self, rd, rs1):
        self.addi(rd, rs1, 0)

    # ----------------------------------------------------------------
    # Expected result declarations
    # ----------------------------------------------------------------
    def expect_reg(self, reg, value):
        """After execution, register 'reg' must equal 'value'."""
        self.checks.append((0, reg, _bits(value, 32)))

    def expect_reg_not(self, reg, bad_value):
        """After execution, register 'reg' must NOT equal 'bad_value'."""
        self.checks.append((1, reg, _bits(bad_value, 32)))

    def expect_mem(self, word_addr, value):
        """After execution, memory word at 'word_addr' must equal 'value'."""
        self.checks.append((2, word_addr, _bits(value, 32)))

    # ----------------------------------------------------------------
    # Output generation
    # ----------------------------------------------------------------
    def generate(self):
        """Write .hex and .expected files to sw/asm/."""
        os.makedirs(self.OUTPUT_DIR, exist_ok=True)

        hex_path = os.path.join(self.OUTPUT_DIR, f"{self.name}.hex")
        exp_path = os.path.join(self.OUTPUT_DIR, f"{self.name}.expected")

        # Pad with NOPs
        for _ in range(4):
            self.nop()

        # Write .hex
        with open(hex_path, "w") as f:
            for i, (word, comment) in enumerate(self.instructions):
                addr = i * 4
                f.write(f"{word:08X}  // 0x{addr:02X}: {comment}\n")

        # Write .expected
        with open(exp_path, "w") as f:
            f.write(f"{self.cycles}\n")
            for check_type, addr, value in self.checks:
                f.write(f"{check_type} {addr} {value:08X}\n")

        print(f"Generated: {hex_path}")
        print(f"Generated: {exp_path}")
        print(f"  {len(self.instructions)} instructions, {len(self.checks)} checks, {self.cycles} cycles")
        return hex_path, exp_path

    # ----------------------------------------------------------------
    # Internal
    # ----------------------------------------------------------------
    def _emit(self, word, comment):
        self.instructions.append((_bits(word, 32), comment))


def _sign_extend(value, bits):
    """Sign-extend a value from 'bits' width to Python int."""
    mask = 1 << (bits - 1)
    return ((value & ((1 << bits) - 1)) ^ mask) - mask
