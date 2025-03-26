# FPGA Morse Code Translator

## Project Overview
This FPGA-based Morse Code Translator is a versatile system that converts text to Morse code and vice versa. It supports multiple input methods and provides flexible output options.

## Features
- Text-to-Morse Code Conversion
- Morse Code-to-Text Decoding
- UART Serial Interface Support
- LED and Buzzer Output
- Finite State Machine (FSM) Based Control

## Hardware Requirements
- FPGA Development Board (Recommended: Xilinx Artix-7)
- USB-UART Converter (if not integrated)
- LED
- Buzzer/Piezo Speaker

## Timing Specifications
- Dot (•): 1 time unit
- Dash (—): 3 time units
- Inter-element Gap: 1 time unit
- Inter-letter Gap: 3 time units
- Inter-word Gap: 7 time units

## File Structure
- `top_level.vhd`: System integration module
- `morse_encoder.vhd`: Text to Morse code conversion
- `morse_decoder.vhd`: Morse code to text conversion
- `fsm_controller.vhd`: State machine management
- `uart_tx.vhd`: UART transmitter
- `uart_rx.vhd`: UART receiver
- `clock_divider.vhd`: Timing signal generation
- `led_buzzer_control.vhd`: Output control
- `constraints.xdc`: FPGA pin assignments

## Setup and Configuration
1. Open project in Xilinx Vivado
2. Add all VHDL source files
3. Add constraint file
4. Synthesize and implement design
5. Generate bitstream
6. Program FPGA

## Input Methods
- UART Serial Communication
- Keypad Input
- Push Buttons

## Output Methods
- LED Signaling
- Buzzer/Audio Tone

## Testbench
Testbenches are provided in the `testbench/` directory for:
- Morse Encoder
- Morse Decoder
- Finite State Machine

## Customization
- Modify Morse code lookup tables
- Adjust timing parameters
- Add more input/output methods

## Limitations
- Currently supports ASCII characters
- Fixed timing specifications
- Limited to standard Morse code alphabet
