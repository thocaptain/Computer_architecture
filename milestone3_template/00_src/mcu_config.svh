// =============================================================================
// File Name:     mcu_config.svh
// Project:       Milestone 3 - Simple MCU
// Description:   Default memory settings, overridable by simulation and FPGA builds.
// =============================================================================

`ifndef MCU_CONFIG_SVH
`define MCU_CONFIG_SVH

// =========================================================================
// Simulation Device Selection
// =========================================================================
// Compile with +define+SIM_ONLY to enable the simulation tb_device.
// Leave SIM_ONLY undefined for FPGA builds. The simulation outputs then read 0.


// =========================================================================
// Data Memory Backend Selection
// =========================================================================
// +define+DMEM_USE_SRAM selects the external 16-bit SRAM controller and adds
// SRAM pins to milestone3 and the DE2 wrapper. Load/store instructions wait
// for completion in this mode. Leave it undefined for single-cycle flop DMEM.
// Example simulation flags: +define+SIM_ONLY +define+DMEM_USE_SRAM

// =========================================================================
// Instruction Memory Configuration
// =========================================================================
`ifndef IMEM_ADDR_WIDTH
`define IMEM_ADDR_WIDTH 16
`endif


// =========================================================================
// Data Memory Configuration
// =========================================================================
`ifndef DMEM_ADDR_WIDTH
`define DMEM_ADDR_WIDTH 14
`endif


// =========================================================================
// Program Image Configuration
// =========================================================================
`ifndef IMEM_FILE
// Split the leading UNC slashes for compatibility with older Quartus preprocessors.
`define IMEM_FILE {"/", "/wsl.localhost/Ubuntu-20.04/home/lqhau/RISC-V-RV32i-master/milestone3_template/apps/full_calculator/full_calculator.mem"}
`endif

`endif
