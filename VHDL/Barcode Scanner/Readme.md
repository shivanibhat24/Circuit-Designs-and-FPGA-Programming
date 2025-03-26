# FPGA Barcode Recognition System

## Project Overview
This project implements a real-time barcode recognition system using VHDL for FPGA acceleration. The system is designed to capture, process, and decode barcodes from camera or sensor inputs with high-speed performance.

## Key Features
- Real-time barcode detection and decoding
- Hardware-accelerated image processing
- Support for multiple barcode formats
- Low-latency UART data transmission

## System Architecture
The system is composed of several key modules:
1. **Clock Divider**: Manages system clock frequencies
2. **Image Capture**: Interfaces with camera/sensor
3. **Grayscale Conversion**: Reduces color complexity
4. **Edge Detection**: Identifies barcode boundaries
5. **Binarization**: Converts to black and white
6. **Barcode Detection**: Identifies barcode patterns
7. **Decoder**: Extracts barcode information
8. **UART Transmitter**: Sends decoded data

## Supported Barcode Formats
- EAN-13
- UPC-A
- Basic QR Code support

## Hardware Requirements
- FPGA Board (Xilinx Recommended)
- CMOS Camera or Image Sensor
- UART Interface

## Build Instructions
```bash
# Synthesize the project
make synthesis

# Generate bitstream
make bitstream

# Program FPGA
make program
```

## Performance Characteristics
- Image Processing: Up to 60 FPS
- Decoding Latency: < 10ms
- Power Consumption: Low-power design

## Potential Applications
- Industrial Logistics
- Inventory Management
- Embedded Scanning Systems
