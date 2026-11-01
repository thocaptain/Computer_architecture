create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
create_generated_clock -name CPU_5MHZ -source [get_ports {CLOCK_50}] -divide_by 10 [get_pins {cpu_clk|q}]
derive_clock_uncertainty
# Mechanical inputs are asynchronous. Only the first stage is exempt.
set_false_path -from [get_ports {SW[*] KEY[0] KEY[1] KEY[2]}] -to [get_registers {*input_meta*}]
set_false_path -from [get_ports {KEY[3]}]
set_output_delay -clock CPU_5MHZ -max 10.000 [get_ports {LEDR[*] LEDG[*] HEX* LCD*}]
set_output_delay -clock CPU_5MHZ -min 0.000 [get_ports {LEDR[*] LEDG[*] HEX* LCD*}]
