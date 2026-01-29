# NFC Reader-Tag System (VHDL)

A comprehensive FPGA-based NFC (Near Field Communication) reader-tag system implementation in VHDL, supporting ISO/IEC 14443 Type A protocol communication.

## Overview

This project implements a complete NFC communication system in hardware description language (VHDL), designed for FPGA deployment. It includes both reader and tag simulation capabilities, supporting fundamental NFC operations including tag detection, anti-collision, selection, authentication, and data transfer.

## Features

### Reader Functionality
- **13.56 MHz Carrier Generation**: RF carrier signal generation with configurable divider
- **ASK Modulation**: Amplitude Shift Keying for reader-to-tag communication (10% modulation depth)
- **Load Modulation Demodulation**: Tag response detection via load modulation
- **ISO 14443 Type A Protocol**: Full protocol stack implementation
- **Anti-collision Support**: Multi-tag collision detection and resolution
- **MIFARE Authentication**: Support for Key A and Key B authentication

### Tag Simulation
- **Tag Emulation**: Simulated NFC tag behavior
- **Configurable UID**: 32-bit unique identifier
- **Command Response**: REQA, WUPA, and anti-collision response handling
- **Manchester Encoding**: Load modulation with Manchester encoding for data transmission

### Additional Features
- **CRC-16 Calculation**: ISO/IEC 14443 compliant error checking (polynomial: x^16 + x^12 + x^5 + 1)
- **Timeout Management**: Robust timeout handling for protocol states
- **Error Detection**: Comprehensive error status reporting
- **State Machine Design**: Well-structured FSM for reliable operation

## Architecture

### System Block Diagram

```
┌─────────────────────────────────────────────────────┐
│                   NFC System (Top)                   │
│                                                      │
│  ┌──────────────┐    ┌──────────────┐               │
│  │   Carrier    │───▶│  Modulator   │──┐            │
│  │  Generator   │    └──────────────┘  │            │
│  └──────────────┘                      │            │
│                                        ▼            │
│  ┌──────────────┐    ┌──────────────┐ RF Out       │
│  │   Protocol   │───▶│ Demodulator  │              │
│  │  Controller  │◀───└──────────────┘              │
│  └──────────────┘           ▲                       │
│         │                   │                       │
│         │              Load Mod In                  │
│         ▼                                           │
│  ┌──────────────┐    ┌──────────────┐              │
│  │  MIFARE Auth │    │   NFC CRC    │              │
│  └──────────────┘    └──────────────┘              │
└─────────────────────────────────────────────────────┘
```

## Module Descriptions

### 1. Top Module (`top.vhd`)
**Entity**: `nfc_system`

Main system integration module that instantiates and connects all sub-components.

**Ports**:
- `clk`: System clock input (108.48 MHz typical)
- `rst`: Asynchronous reset
- `start_transaction`: Initiates NFC transaction
- `command_in[7:0]`: Command byte to transmit
- `data_in[7:0]`: Data byte to transmit
- `data_ready`: Received data valid flag
- `data_out[7:0]`: Received data output
- `carrier_out`: 13.56 MHz carrier output
- `modulation_out`: ASK modulation signal
- `field_detect_in`: Tag field presence detection
- `load_modulation`: Tag response load modulation input

**Sub-modules**:
- Carrier Generator
- Modulator
- Demodulator
- Protocol Controller

### 2. Protocol Controller (`protocol_controller.vhd`)
**Entity**: `enhanced_protocol_controller`

State machine that manages the NFC communication protocol and command sequences.

**States**:
- `IDLE`: Waiting for transaction start
- `FIELD_ON`: RF field activation and stabilization
- `SEND_COMMAND`: Transmitting command to tag
- `WAIT_RESPONSE`: Waiting for tag response
- `PROCESS_RESPONSE`: Processing received data
- `ANTICOLLISION`: Executing anti-collision procedure
- `SELECT_TAG`: Tag selection procedure
- `READ_DATA`: Reading data from tag
- `WRITE_DATA`: Writing data to tag
- `AUTHENTICATE`: Authentication procedure
- `ERROR`: Error handling state
- `FIELD_OFF`: RF field deactivation

**Commands Supported**:
- `REQA (0x26)`: Request Type A
- `WUPA (0x52)`: Wake-up Type A
- `ANTICOL (0x93)`: Anti-collision/Select Cascade Level 1
- `SELECT (0x95)`: Select Cascade Level 2
- `HALT (0x50)`: Halt command
- `READ (0x30)`: Read block
- `WRITE (0xA0)`: Write block

**Additional Outputs**:
- `tag_uid_out[31:0]`: Extracted tag UID
- `tag_selected`: Tag selection status
- `error_status[3:0]`: Error code output

### 3. Modulator (`modulator.vhd`)
**Entity**: `modulator`

Implements ASK (Amplitude Shift Keying) modulation for reader-to-tag communication.

**Features**:
- 106 kbps data rate (128 carrier cycles per bit)
- LSB first transmission
- 100% modulation for logic '0', no modulation for logic '1'
- FSM-based bit timing control

**States**:
- `IDLE`: No modulation
- `SENDING`: Transmitting data bits
- `BIT_PAUSE`: Inter-bit pause

### 4. Demodulator (`demodulator.vhd`)
**Entity**: `demodulator`

Decodes load-modulated signals from NFC tags.

**Features**:
- Edge detection for synchronization
- Mid-bit sampling for reliable data recovery
- 8-bit shift register for byte assembly
- Data valid flag generation

**States**:
- `WAITING`: Waiting for start of frame
- `SYNCING`: Synchronizing with bit stream
- `RECEIVING`: Receiving and sampling data bits

### 5. CRC Calculator (`crc.vhd`)
**Entity**: `nfc_crc`

Computes ISO/IEC 14443 Type A compliant CRC-16.

**Specifications**:
- Polynomial: x^16 + x^12 + x^5 + 1 (0x1021)
- Bit-serial implementation
- Initialize and continuous calculation modes

### 6. MIFARE Authentication (`mifare_auth.vhd`)
**Entity**: `mifare_auth`

Handles MIFARE Classic authentication with cryptographic key exchange.

**Features**:
- Key A (0x60) and Key B (0x61) authentication
- 48-bit key support
- UID-based authentication
- LFSR for random number generation

**States**:
- `IDLE`: Waiting for authentication request
- `SEND_AUTH_CMD`: Sending authentication command
- `SEND_BLOCK`: Sending block address
- `SEND_KEY_PART1`: Sending key bytes 0-3
- `SEND_KEY_PART2`: Sending key bytes 4-5
- `WAIT_RESPONSE`: Waiting for authentication response
- `AUTH_SUCCESS`: Authentication successful
- `AUTH_FAILED`: Authentication failed

### 7. Tag Simulation (`tag_simulation.vhd`)
**Entity**: `nfc_tag_sim`

Emulates an NFC Type A tag for testing and development.

**Features**:
- Configurable 32-bit UID
- Power-on detection via carrier sensing
- Command reception and processing
- Manchester-encoded load modulation response
- ATQA (Answer to Request Type A) response

**Supported Commands**:
- REQA (0x26)
- WUPA (0x52)
- ANTICOL (0x93)

## Timing Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| System Clock | 108.48 MHz | Main FPGA clock |
| RF Carrier | 13.56 MHz | NFC carrier frequency |
| Data Rate | 106 kbps | ISO 14443 Type A standard |
| Bit Period | 128 cycles | Carrier cycles per data bit |
| Field Stabilization | 1000 cycles | Startup delay for RF field |
| Response Timeout | 5000 cycles | Max wait time for tag response |

## Usage Example

### Basic Reader Transaction

```vhdl
-- Initialize system
rst <= '1';
wait for 100 ns;
rst <= '0';

-- Start REQA command
command_in <= x"26";  -- REQA
start_transaction <= '1';
wait for 10 ns;
start_transaction <= '0';

-- Wait for response
wait until data_ready = '1';
tag_response <= data_out;

-- Read received data
if data_ready = '1' then
    -- Process ATQA response
    atqa <= data_out;
end if;
```

### Anti-collision Sequence

```vhdl
-- 1. Send REQA
command_in <= x"26";
start_transaction <= '1';
wait until data_ready = '1';

-- 2. Send Anti-collision
command_in <= x"93";
start_transaction <= '1';
wait until data_ready = '1';

-- 3. Extract UID bytes
-- (handled automatically by protocol controller)

-- 4. Check tag_selected signal
if tag_selected = '1' then
    -- Tag successfully selected
    uid <= tag_uid_out;
end if;
```

## Error Codes

| Code | Description |
|------|-------------|
| 0000 | No error |
| 0001 | Field not detected |
| 0010 | Response timeout |
| 0011 | Write acknowledgment error |
| 0100-1111 | Reserved for future use |

## Pin Assignment Recommendations

### Reader Interface
```
carrier_out      → RF driver (13.56 MHz)
modulation_out   → ASK modulation control
field_detect_in  ← Field strength detector
load_modulation  ← Envelope detector for tag response
```

### Control Interface
```
clk              ← System clock (108.48 MHz recommended)
rst              ← Active-high reset
start_transaction← Transaction trigger (edge-sensitive)
```

## Design Considerations

### Clock Domain
All modules operate in a single clock domain (synchronous design). The system clock should be at least 8x the carrier frequency for proper operation.

### Reset Strategy
Asynchronous reset is used throughout the design. Assert reset for at least 100 clock cycles during initialization.

### Synthesis Guidelines
- Target device: Xilinx or Altera FPGAs
- Estimated resource usage: ~500-1000 LUTs, ~300 registers
- Maximum clock frequency: >150 MHz on modern FPGAs
- No external memory required

### Timing Constraints
Recommended timing constraints for Xilinx synthesis:

```tcl
create_clock -period 9.216 -name clk [get_ports clk]
set_input_delay -clock clk 2.0 [get_ports {field_detect_in load_modulation}]
set_output_delay -clock clk 2.0 [get_ports {carrier_out modulation_out}]
```

## Testing

### Simulation Testbench Structure
1. Initialize system with reset
2. Enable carrier generator
3. Send REQA command
4. Verify ATQA response from tag simulation
5. Execute anti-collision sequence
6. Verify UID extraction
7. Perform read/write operations
8. Test error conditions and timeouts

### Verification Points
- Carrier frequency accuracy (13.56 MHz ±7 kHz)
- Modulation depth (10% for ASK)
- Bit timing accuracy (106 kbps ±1%)
- CRC calculation correctness
- Protocol state transitions
- Timeout handling

## License

This project is provided as-is for educational and development purposes. Please ensure compliance with relevant NFC Forum and ISO/IEC specifications for commercial applications.

## References

- ISO/IEC 14443-2: Radio frequency power and signal interface
- ISO/IEC 14443-3: Initialization and anticollision
- ISO/IEC 14443-4: Transmission protocol
- NXP MIFARE Classic documentation
- NFC Forum specifications
