# constraints.xdc
# Pin assignments and timing constraints for FPGA implementation

# Clock input
set_property PACKAGE_PIN Y9 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset button
set_property PACKAGE_PIN T18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# UART RX/TX Pins
set_property PACKAGE_PIN V18 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property PACKAGE_PIN W16 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LED Output
set_property PACKAGE_PIN V16 [get_ports led_output]
set_property IOSTANDARD LVCMOS33 [get_ports led_output]

# Buzzer Output
set_property PACKAGE_PIN V15 [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]

# Keypad Input
set_property PACKAGE_PIN W17 [get_ports {keypad_in[0]}]
set_property PACKAGE_PIN W16 [get_ports {keypad_in[1]}]
set_property PACKAGE_PIN W15 [get_ports {keypad_in[2]}]
set_property PACKAGE_PIN V15 [get_ports {keypad_in[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {keypad_in[*]}]

# Clock constraints
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]
