package require -exact qsys 14.0
set_module_property NAME hps_mcu
set_module_property DISPLAY_NAME "RV32I MCU with HPS mailbox"
set_module_property VERSION 1.0
set_module_property GROUP "User Components"
set_module_property DESCRIPTION "Single-clock RV32I MCU, Avalon-MM mailbox and GPIO conduit"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false
set src_dir [get_module_property MODULE_DIRECTORY]

add_parameter PROGRAMFILE STRING [file join $src_dir full_calculator_hps.mem]
set_parameter_property PROGRAMFILE HDL_PARAMETER true
add_parameter IMEM_ADDR_WIDTH INTEGER 12
set_parameter_property IMEM_ADDR_WIDTH HDL_PARAMETER true
add_parameter DMEM_ADDR_WIDTH INTEGER 10
set_parameter_property DMEM_ADDR_WIDTH HDL_PARAMETER true

add_fileset synthesis_fileset QUARTUS_SYNTH ""
set_fileset_property synthesis_fileset TOP_LEVEL hps_mcu
add_fileset_file rv32i_pkg.sv SYSTEM_VERILOG PATH [file join $src_dir rv32i_pkg.sv]
foreach src [lsort [glob -directory $src_dir *.sv]] {
    set name [file tail $src]
    if {$name ne "rv32i_pkg.sv" && ![string match "example_*" $name]} {
        add_fileset_file $name SYSTEM_VERILOG PATH $src
    }
}
add_fileset_file mcu_config.svh SYSTEM_VERILOG_INCLUDE PATH [file join $src_dir mcu_config.svh]

add_interface clock clock end
add_interface_port clock clk clk Input 1
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
add_interface_port reset reset_n reset_n Input 1

add_interface avs avalon end
set_interface_property avs associatedClock clock
set_interface_property avs associatedReset reset
set_interface_property avs addressUnits WORDS
set_interface_property avs bitsPerSymbol 8
set_interface_property avs readLatency 0
set_interface_property avs readWaitTime 0
set_interface_property avs writeWaitTime 0
set_interface_property avs maximumPendingReadTransactions 0
set_interface_property avs timingUnits Cycles
add_interface_port avs avs_address address Input 3
add_interface_port avs avs_read read Input 1
add_interface_port avs avs_write write Input 1
add_interface_port avs avs_writedata writedata Input 32
add_interface_port avs avs_byteenable byteenable Input 4
add_interface_port avs avs_readdata readdata Output 32
add_interface_port avs avs_waitrequest waitrequest Output 1

add_interface interrupt interrupt sender
set_interface_property interrupt associatedClock clock
set_interface_property interrupt associatedReset reset
set_interface_property interrupt associatedAddressablePoint avs
add_interface_port interrupt irq irq Output 1

add_interface io conduit end
set_interface_property io associatedClock clock
set_interface_property io associatedReset reset
foreach {name direction width} {
    i_sw Input 18 i_key Input 4 i_gpio_in Input 32
    o_gpio_out Output 32 o_gpio_dir Output 32
    o_ledr Output 32 o_ledg Output 32 o_ledb Output 32 o_hex Output 56
} {
    add_interface_port io $name export $direction $width
}
