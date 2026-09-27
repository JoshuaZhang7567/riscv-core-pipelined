# 50 MHz board oscillator
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# Push-buttons and switches are asynchronous human inputs (synchronized in
# de1soc_top); LEDs and 7-segment displays are static outputs.
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX*}]
