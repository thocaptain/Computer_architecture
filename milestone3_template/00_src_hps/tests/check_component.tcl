package require -exact qsys 18.1
set root [pwd]
create_system hps_mcu_check
set_project_property DEVICE_FAMILY "Cyclone V"
set_project_property DEVICE 5CSXFC6D6F31C6
add_instance mcu hps_mcu 1.0
set_instance_parameter_value mcu PROGRAMFILE [file join $root hps_mailbox.mem]
foreach {name type direction target} {
    clk clock sink clock
    reset reset sink reset
    avs avalon slave avs
    irq interrupt sender interrupt
    io conduit end io
} {
    add_interface $name $type $direction
    set_interface_property $name EXPORT_OF mcu.$target
}
save_system [file join $root tests hps_mcu_check.qsys]
