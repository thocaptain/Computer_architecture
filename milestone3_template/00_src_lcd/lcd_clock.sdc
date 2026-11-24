# CLOCK_DIV_LOG2=1: 50 MHz board oscillator -> 25 MHz MCU clock.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
create_generated_clock -name MCU_CLK \
    -source [get_ports {CLOCK_50}] -divide_by 2 \
    [get_registers {*g_divided_clock*clock_count[0]}]
derive_clock_uncertainty
