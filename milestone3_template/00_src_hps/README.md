# RV32I MCU communicating with DE10-Standard HPS

The active default firmware is now the interactive HPS calculator. See
`../apps/full_calculator_hps/README.txt` and run `software/hps_calculator_lcd`.
The input+1 files below remain available as a transport regression demo; select
`hps_mailbox.mem` explicitly when using that older demo.

This is a separate source variant copied from `../00_src`. Its new peripheral is
a two-way mailbox. Use only this source variant in a design: the copied CPU
modules have the same names as those in `00_src` and `00_src_lcd`.

```text
HPS ARM / Linux application
    -> Lightweight HPS-to-FPGA AXI master
    -> Platform Designer AXI-to-Avalon interconnect
    -> hps_mcu.avs (32-bit Avalon-MM slave)
    -> hps_mailbox
    <-> RV32I CPU MMIO page 0x40006000

RV32I result -> mailbox -> HPS C application -> HPS SPI/GPIO -> board LCD
```

The HPS bridge uses AXI; our component implements Avalon-MM. Platform Designer
generates the protocol adapter. The CPU keeps its existing local memory bus.
It does not need to implement AXI, access HPS DDR, or arbitrate with the HPS over
its instruction/data memories for this first demonstration.

## Delivered files

- `hps_mailbox.sv`: host/CPU register block, byte enables, one command in flight,
  response acknowledgement, and optional level IRQ.
- `hps_mcu.sv`: Platform Designer top integrating the real RV32I MCU and mailbox.
- `hps_mcu_hw.tcl`: component description for Quartus/Platform Designer 18.1.
- `milestone3.sv`, `simple_bus.sv`: mailbox attached at CPU address `0x40006000`.
- `hps_mailbox.s`, `hps_mailbox.mem`, `build_firmware.py`: firmware that returns
  `command + 1` modulo 2^32. The IMEM image is padded to 4 KiB.
- `software/hps_demo.c`: Linux host, polling with a two-second timeout.
- `software/lcd/`: original Terasic HPS LCD library and its original notices.
  It is for Terasic boards under the notices included in those source files.
- `tests/`: directed mailbox tests and actual CPU/firmware round-trip tests.

`PROGRAMFILE` selects the firmware at FPGA compilation time. The existing
switch/key calculator firmware does not poll the new mailbox; use the supplied
`full_calculator_hps` frontend for terminal input. This version has no HPS program
loader, CPU start/reset register, shared RAM, DMA, or framebuffer.

## Registers and protocol

All entries are 32-bit little-endian registers. Host offsets below are byte
offsets relative to the component base; CPU offsets are relative to `0x40006000`.
The RTL Avalon `avs_address` is a **word index**, i.e. offset / 4. The IP describes
`addressUnits=WORDS`, aperture 32 bytes, combinational reads, readLatency=0,
and waitrequest=0. Registers are sampled/written on the rising clock edge.

| Byte offset | Name | Read | Host write | CPU write |
|---|---|---|---|---|
| 0x00 | ID | `0x48505331` (HPS1) | ignored | ignored |
| 0x04 | STATUS | bit 0 command pending; bit 1 response pending | ignored | ignored |
| 0x08 | COMMAND | command data | stage data while STATUS=0 | ignored |
| 0x0c | RESPONSE | response data | ignored | stage result while command pending |
| 0x10 | CONTROL | zero | bit 0 START; bit 1 ACK | bit 0 COMPLETE |
| 0x14 | IRQ_ENABLE | bit 0 enable | bit 0 enable | ignored |
| 0x18, 0x1c | reserved | zero | ignored | ignored |

1. Host checks ID, then STATUS=0 and writes COMMAND. Byte-enable writes merge
   enabled lanes with the previous stored word; software normally writes a word.
2. Host writes CONTROL=1 in a **separate transaction** to start.
3. CPU sees STATUS bit 0, reads COMMAND, writes RESPONSE, then CONTROL=1 to finish.
4. Host waits for STATUS bit 1, reads RESPONSE and writes CONTROL=2 to acknowledge.
5. Only after acknowledgement may the next command be staged and started.

New START/data writes while busy are ignored; they are not queued. Keep one
host process. A combined ACK|START write does not start a new command when an old
response is pending: ACK and the next START must be separate transactions.
Read accesses have no side effects. CONTROL and IRQ_ENABLE require byte lane 0.
IRQ is `response_pending && IRQ_ENABLE[0]`; the provided host uses polling.
Reset clears both pending flags, data registers and IRQ enable together with the
CPU. Reset deassertion must be synchronized to the common fabric clock.

## Integrate into a DE10-Standard Platform Designer system

Start from the board's `DE10_Standard_GHRD/soc_system.qsys` or your own equivalent
HPS system retaining the correct DDR and HPS peripheral/pin-mux settings.
The old CPU-only `example_de10_wrapper` project has no HPS subsystem, and is not
the top for this variant. The legacy `example_de2_wrapper.sv` and
`example_de10_wrapper.sv` copies are references only; the new component uses
`hps_mcu`, with direct single-clock connections to `milestone3`.

1. Add this directory to the Platform Designer IP search path and refresh the
   catalog. Select **RV32I MCU with HPS mailbox**, type `hps_mcu`.
2. Keep internal DMEM (`DMEM_USE_SRAM` undefined) and FPGA mode (`SIM_ONLY`
   undefined). Default IMEM=4 KiB and DMEM=1 KiB. Verify `PROGRAMFILE` points to
   this directory's `hps_mailbox.mem`; the component supplies an absolute path.
3. Connect `hps_0.h2f_lw_axi_master` to `hps_mcu.avs`. If using GHRD's existing
   `mm_bridge_0`, connect its master instead. Assign a free, 32-byte-aligned base,
   for example `0x6000` **only if the address map confirms it is free**.
4. Connect the component clock and reset to the same fabric clock/reset domain
   used for that bridge/interconnect. Use a PLL-generated clock such as 25 MHz
   for this single-cycle core, and constrain/verify timing. If an existing
   50 MHz system is used, either prove CPU timing at that frequency or insert a
   Platform Designer clock-crossing bridge to a 25 MHz domain. Do not divide the
   CPU clock alone or cross these mailbox signals directly between clocks.
5. Export the `io` conduit, connect physical switch/key signals with appropriate
   synchronization, or tie unused inputs to constants (`i_sw=0`, `i_key=15`,
   `i_gpio_in=0`). GPIO input/output/direction are separate signals; any physical
   tri-state buffers belong at the board top. Unused outputs may remain open.
6. Optionally connect `interrupt` to an HPS FPGA-to-HPS interrupt input. It may
   stay unconnected for this polling demonstration.
7. Generate HDL, instantiate the resulting HPS system in the board top with the
   correct HPS DDR/I/O pins, and compile a new FPGA bitstream. The resulting
   design must pass fitting and timing before board use.
8. Boot Linux with matching HPS configuration, load that bitstream and enable
   the Lightweight bridge using the board BSP's supported FPGA-manager/bridge
   sequence. Disable bridge traffic while reconfiguring. Loading the old
   CPU-only `.sof` does not provide this mailbox. Avoid MMIO accesses until
   the FPGA is configured, reset is released and the bridge is enabled.

There is no complete board `.qsys`/pin-assigned `.sof` generated here. The
delivered component is ready to add to the board-specific HPS design; it does
not replace that design or the Linux boot image.

## HPS program and LCD

Run in `software/`, using the ARM Linux toolchain:

```sh
make
# Cyclone V HWLIB path, from SoC EDS or the official HWLIB repository:
make hps_demo_lcd HWLIBS_ROOT=/path/to/hwlib
```

Default linking is static so the binary does not require the host toolchain's
glibc version on the older board Linux. The LCD target needs
`include/soc_cv_av` in HWLIB; Arria 10 headers are not a substitute.

Copy `hps_demo` or `hps_demo_lcd` to Linux on the board, mark executable and run
as root. Pass the **physical address actually assigned in your generated map**.
For example, if the lightweight window is `0xff200000`, and the complete
component offset is `0x6000`, the physical address is `0xff206000`:

```sh
chmod +x hps_demo_lcd
./hps_demo_lcd 0xff206000 41
```

Expected terminal: `HPS sent 41; RV32I returned 42`.
Expected LCD: `RV32I`, `0000002A`, `HEX` (eight hexadecimal digits fit 128 pixels).
The LCD is driven by the HPS using the same SPI0/GPIO path as Terasic's
`hps_lcd`; retain its working pin-mux configuration and do not let another
program or SPI driver own that controller concurrently. This demo targets the
board LCD, not a VGA/HDMI monitor.

The physical address argument is deliberately required. An incorrect MMIO
address or disabled bridge may hang a bus read; the response timeout cannot
recover a transaction that never reaches the peripheral.

## Validation

```sh
python3 build_firmware.py
python3 tests/run_tests.py
```

Tests cover command/response ownership, byte enables, busy-command rejection,
IRQ/ACK, reserved reads, reset and real RV32I firmware round trips, including
unsigned overflow. Verilator 5 with timing support is required.

Checked locally: RTL tests passed; Quartus 18.1 Analysis & Elaboration for
`hps_mcu` passed with zero errors; ARM host and LCD host both compiled. The
Platform Designer component was instantiated and its interfaces exported using
`tests/check_component.tcl`. Full board synthesis/timing and physical LCD
operation with the new component have not been tested.

## References

- [Cyclone V HPS-to-FPGA bridges and AXI-to-Avalon adaptation](https://docs.altera.com/r/docs/683126/21.2/cyclone-v-hard-processor-system-technical-reference-manual/hps-to-fpga-and-lightweight-hps-to-fpga-bridges)
- [Avalon interface specification](https://cdrdv2-public.intel.com/667068/mnl_avalon_spec-683091-667068.pdf)
- [Official SoC HWLIB source](https://github.com/altera-opensource/intel-socfpga-hwlib)
