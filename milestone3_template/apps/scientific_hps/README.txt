SCIENTIFIC HPS APPLICATION: ADD / SUBTRACT / MULTIPLY / DIVIDE / EXP / SIN / COS

Type one expression in PuTTY, then press Enter:
  12 + 34      -> 46
  12 - 34      -> -22
  -12 * 5      -> -60
  -17 / 5      -> -3 (remainder -2)
Arithmetic operands/results are signed 32-bit integers. Division truncates toward
zero; the remainder has the dividend sign. Division by zero and overflow report
an error. Decimal operands are supported only for exp/sin/cos.
  exp 1        -> exp(1.000) = 2.718
  exp 1.5      -> exp(1.500) = 4.482
  exp -1       -> exp(-1.000) = 0.368
  sin 30       -> sin(30.000 deg) = 0.500
  cos 60       -> cos(60.000 deg) = 0.500
  sin -90      -> sin(-90.000 deg) = -1.000
  cos 180      -> cos(180.000 deg) = -1.000
Type q, quit or exit to close the program.

exp means e raised to x; it is not x raised to an arbitrary power.
sin/cos arguments are DEGREES, not radians.
Supported input precision: up to three decimal places (0.001).
Supported ranges: exp [-9,9]; sin/cos [-360000,360000] degrees.
Output is an approximation rounded to three decimal places. Small positive exp
values may round to 0.000. No scientific notation or compound expressions.

WHERE THE COMPUTATION HAPPENS
  PC keyboard -> PuTTY/UART -> HPS decimal parser -> Avalon mailbox -> RV32I
  RV32I result -> mailbox -> HPS decimal formatting -> terminal and HPS LCD
The HPS client does not call exp/sin/cos to calculate the result.
RISC-V uses software integer arithmetic: no MUL/DIV, F or D extension required.

ALGORITHMS
  exp_milli is extracted unchanged from ../exponential/exponential.s.
  It reduces by ln(2), evaluates an 18-term series in Q48 and scales the result.
  sincos_milli reduces the input modulo 360 degrees, folds quadrants and performs
  30 CORDIC rotations. Coordinates use Q30; angles use a 2^32 full-turn scale.
  The generated arctangent constants are placed in DMEM at startup. They cannot
  be loaded from IMEM because this CPU has separate instruction/data buses.
  For exp/sin/cos, inputs/results are scaled by 1000. Arithmetic uses unscaled
  signed 32-bit integers and reuses the original full_calculator routines.

BUILD AND TEST (WSL/Linux)
  python3 build.py
  python3 tests/run_tests.py
The firmware image has 1024 words (4 KiB); actual code is 2520 bytes.
The build does not change the active calculator project or its default firmware.
999 real-RTL numeric cases plus parser/protocol/reset tests passed locally.
The numeric cases cover boundaries, signs, quadrant boundaries, many revolutions,
and reproducible random inputs. Rounded results matched the reference in all
numeric test cases; this is test coverage, not an exhaustive error proof.
Tests allow a one-thousandth approximation error. No board test was performed
for this application yet.

SELECT THE NEW APPLICATION IN QUARTUS
The existing full_calculator application remains separate.
1. In F:/master/CTMT/milestone3_de10_lcd, open soc_system.qsys.
2. Open hps_mcu_0 and change PROGRAMFILE to:
     F:/master/CTMT/milestone3_de10_lcd/ip/hps_mcu/scientific_hps.mem
3. Save and Generate HDL, then run full Quartus compilation and check timing.
   The existing mailbox address and RTL connections remain the same.
4. Boot Linux as before and load the new .sof over JTAG, with no MMIO clients
   accessing the bridge during reconfiguration. Verify bridge readiness.
5. Transfer the new ARM binary to the board and run:
     ./hps_scientific_lcd 0xff206000
   Or use ./hps_scientific 0xff206000 for terminal output only.
The SCI2 version check rejects a calculator or old input+1 bitstream.
To return to the calculator, select full_calculator_hps.mem, generate and compile
again, then load its .sof and run hps_calculator_lcd.

HPS PROGRAMS
  ../../00_src_hps/software/hps_scientific.c
  ../../00_src_hps/software/scientific_protocol.c/.h
  ../../00_src_hps/software/install_scientific.sh
Build ARM binaries with:
  make hps_scientific
  make hps_scientific_lcd HWLIBS_ROOT=/path/to/CycloneV/hwlib
The static ARM binaries work with the existing Linux image; no SD re-imaging.
The LCD still uses Terasic's HPS SPI/GPIO library and its working pin mux.
Calculator and scientific apps use the same host lock: run one mailbox client
at a time. Other mailbox clients, including hps_demo, must also be stopped.

MAILBOX COMMANDS (one START/COMPLETE/ACK exchange per command)
  0x53430000: HELLO, clear input/result state; reply 0x53434932 (SCI2).
  0x5341hhhh: set input bits 15:0; reply 0.
  0x5342hhhh: set input bits 31:16; reply 0.
  0x5344hhhh / 0x5345hhhh: set second operand low/high halves.
  0x5350000f: execute f=0 exp,1 sin,2 cos,3 add,4 subtract,5 multiply,6 divide.
    Reply 0=OK,1=divide by zero,2=overflow,4=argument range error.
  0x53510000: get signed result (scientific scaled by 1000, arithmetic unscaled).
  0x53520000: get signed integer division remainder.
  Error 0x80000001: invalid command/function.
  Error 0x80000002: execute before all required operand halves are written.
  Error 0x80000003: no result available.
No mailbox RTL change or larger instruction memory is required.
