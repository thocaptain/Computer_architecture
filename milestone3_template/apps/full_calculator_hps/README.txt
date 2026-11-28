FULL CALCULATOR OVER HPS MAILBOX

Interaction: type A op B in the PuTTY terminal, then press Enter.
Examples: 12 + 34, -12 * 5, -12 / 5. Type q to quit.
Operands and results are signed 32-bit integers. Supported operators: + - * /.
Division truncates toward zero and reports the signed remainder.
Division by zero and signed overflow are reported as errors.
Decimal fractions and compound expressions are not supported.

ARCHITECTURE
  PC keyboard -> PuTTY UART -> HPS parser -> mailbox -> RISC-V arithmetic
  RISC-V result -> mailbox -> HPS terminal + optional board LCD
The HPS does not calculate the arithmetic result. It parses operands and formats
the result returned by RISC-V. The LCD shows signed DECIMAL values, not hex.

calculator_core.s is extracted unchanged from the calculate/udiv32 routines in
../full_calculator/full_calculator.s. The original switch/key frontend is retained
in that original application; this directory supplies a different mailbox frontend.
No changes to mailbox RTL or CPU instruction set are needed.

BUILD FIRMWARE (WSL/Linux)
  python3 build.py
Outputs: full_calculator_hps.mem, 1024 32-bit words (4 KiB), calculator_core.s,
and an additional copy of the image in ../../00_src_hps/full_calculator_hps.mem.
GNU riscv64-unknown-elf binutils are required; the ISA target is RV32I/ILP32.

TESTS
  python3 tests/run_tests.py
Checks the host parser/protocol, then runs real MCU RTL with this firmware.
596 signed/boundary/random calculation cases, protocol errors and reset are covered.
Host test uses UndefinedBehaviorSanitizer; RTL test requires Verilator 5.

HPS PROGRAMS
  ../../00_src_hps/software/hps_calculator: terminal only
  ../../00_src_hps/software/hps_calculator_lcd: terminal and LCD
Build with the supplied Makefile and the Cyclone V SoC HWLIB for the LCD target.
The resulting executables are static ARM Linux binaries.

BOARD UPDATE
1. Keep the known-good input+1 .sof as a backup.
2. Copy full_calculator_hps.mem into the project IP directory.
3. Set hps_mcu_0.PROGRAMFILE in soc_system.qsys to that image.
4. Generate HDL, then run a full Quartus compilation and check timing.
5. Load the NEW .sof using JTAG after booting Linux, as in the working demo.
6. Install hps_calculator or hps_calculator_lcd on Linux and run:
     ./hps_calculator_lcd 0xff206000
7. Type a single expression, then Enter:
     calc> 12 + 34
     12 + 34 = 46
     calc> -12 / 5
     -12 / 5 = -2 (remainder -2)

Use the current project's actual physical mailbox address. FPGA must be configured
and the lightweight bridge released before starting any host program. Only one
mailbox client may run at a time. A wrong/disabled MMIO address can hang a read.
The startup CAL1 handshake rejects the old input+1 .sof and prevents it from being
mistaken for the calculator firmware. Pressing KEY[0] resets the CPU/transaction;
it does not remove the loaded FPGA bitstream.

MAILBOX PROTOCOL (one transport request/response per command)
  0xca000000: HELLO, clears calculator state and returns 0x43414c31 (CAL1).
  0xca01hhhh: set A bits 15:0, ACK=0.
  0xca02hhhh: set A bits 31:16, ACK=0.
  0xca03hhhh: set B bits 15:0, ACK=0.
  0xca04hhhh: set B bits 31:16, ACK=0.
  0xca10000p: calculate; p=0 add,1 subtract,2 multiply,3 divide.
              reply=0 OK,1 divide-by-zero,2 signed overflow.
  0xca110000: fetch result bits.
  0xca120000: fetch remainder bits.
  0x80000001: protocol error/invalid command.
  0x80000002: execute before all four operand halves were written.
  0x80000003: result requested before execution or after operands changed.
All operand bit patterns are supported because tags and data occupy separate halves.
Each host expression starts with HELLO, then four operand writes, execute and reads.
Transport START/COMPLETE/ACK remains unchanged from the original mailbox demo.
