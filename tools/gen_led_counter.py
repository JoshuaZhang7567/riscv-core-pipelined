#!/usr/bin/env python3
"""
Generate the DE1-SoC demo program: a counter shown on LEDR and HEX0-HEX5.

Run:  python3 tools/gen_led_counter.py
Writes fpga/de1soc/led_counter.hex (plain hex, one word per line, padded
with NOPs to the FPGA IMEM depth so every ROM word is initialized).

Program (uses the memory-mapped I/O in riscv_top):
    0x00  lui  x6, 0x80000       x6 = 0x8000_0000 (I/O base)
    0x04  addi x5, x0, 0         count = 0
  loop:
    0x08  sw   x5, 0(x6)         io_out = count  (LEDs / 7-seg)
    0x0C  lw   x7, 4(x6)         x7 = io_in = switches
    0x10  addi x7, x7, 1
    0x14  slli x7, x7, 14        delay = (SW + 1) << 14 iterations
  delay:
    0x18  addi x7, x7, -1
    0x1C  bne  x7, x0, delay     4 cycles per iteration (2-cycle flush)
    0x20  addi x5, x5, 1
    0x24  jal  x0, loop

At 50 MHz: SW = 0 → ~760 counts/s, all switches up → ~1.3 s per count.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from gen_test import TestProgram

IMEM_DEPTH = 256
OUT_PATH = os.path.join(os.path.dirname(__file__), "..", "fpga", "de1soc", "led_counter.hex")


def build():
    t = TestProgram("led_counter")
    t.lui(6, 0x80000000)   # I/O base
    t.addi(5, 0, 0)        # count = 0
    loop = t.pc
    t.sw(5, 6, 0)          # io_out = count
    t.lw(7, 6, 4)          # x7 = switches
    t.addi(7, 7, 1)
    t.slli(7, 7, 14)
    delay = t.pc
    t.addi(7, 7, -1)
    t.bne(7, 0, delay - t.pc)
    t.addi(5, 5, 1)
    t.jal(0, loop - t.pc)
    return t


def main():
    t = build()
    words = [w for w, _ in t.instructions]
    words += [0x00000013] * (IMEM_DEPTH - len(words))   # NOP padding

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w") as f:
        for w in words:
            f.write(f"{w:08X}\n")

    for i, (w, comment) in enumerate(t.instructions):
        print(f"  0x{i * 4:02X}: {w:08X}  {comment}")
    print(f"Generated: {os.path.normpath(OUT_PATH)} ({IMEM_DEPTH} words)")


if __name__ == "__main__":
    main()
