# RF Signal Clipping Detector

## Overview

This project implements a Signal Clipping Detector in VHDL designed to protect RF chains from overdriven input signals. The detector continuously monitors the amplitude of incoming signals and triggers an alert when sustained clipping is detected, allowing protective measures to be implemented.

## Features

- **Configurable Threshold Detection**: Customizable amplitude threshold to define clipping levels
- **Debouncing Mechanism**: Requires a configurable number of consecutive samples exceeding the threshold to prevent false triggers
- **Absolute Value Processing**: Detects clipping on both positive and negative signal excursions
- **Clipping Counter**: Provides a count of consecutive clipping events for monitoring severity
- **Fast Response**: Designed for minimal latency to protect sensitive RF components

## Technical Specifications

- **Data Width**: 16-bit input signals (configurable)
- **Default Threshold**: 30,000 (configurable)
- **Consecutive Sample Threshold**: 10 samples (configurable)
- **Counter Width**: 8 bits (configurable)
- **Clock**: Synchronous design, clock frequency determined by system requirements

## Module Interface

```
entity SignalClippingDetector is
    Generic (
        DATA_WIDTH      : integer := 16;       -- Width of input data
        THRESHOLD       : integer := 30000;    -- Clipping threshold
        COUNT_THRESHOLD : integer := 10;       -- Consecutive clipping samples
        COUNT_WIDTH     : integer := 8         -- Width of counter register
    );
    Port (
        clk             : in  STD_LOGIC;                           -- System clock
        rst             : in  STD_LOGIC;                           -- Asynchronous reset
        data_in         : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0); -- Input signal
        clip_detect     : out STD_LOGIC;                           -- Clipping detection flag
        clip_counter    : out STD_LOGIC_VECTOR(COUNT_WIDTH-1 downto 0) -- Counter output
    );
end SignalClippingDetector;
```

## Implementation Details

The clipping detector works by:

1. **Absolute Value Calculation**: Converts input to absolute value to detect both positive and negative clipping
2. **Threshold Comparison**: Compares absolute value against the configured threshold
3. **Consecutive Count Logic**: Increments counter when threshold is exceeded, resets when signal returns to normal range
4. **Alert Generation**: Asserts clip_detect signal when counter exceeds the configured count threshold

## Integration Guide

### Instantiation Example

```vhdl
-- In your top-level design:
signal adc_data  : std_logic_vector(15 downto 0);
signal clip_flag : std_logic;
signal clip_cnt  : std_logic_vector(7 downto 0);

-- Instantiate the detector
clip_detector: entity work.SignalClippingDetector
    generic map (
        DATA_WIDTH      => 16,
        THRESHOLD       => 28000,  -- Adjust based on your ADC range
        COUNT_THRESHOLD => 8,      -- Adjust sensitivity as needed
        COUNT_WIDTH     => 8
    )
    port map (
        clk          => system_clk,
        rst          => system_rst,
        data_in      => adc_data,
        clip_detect  => clip_flag,
        clip_counter => clip_cnt
    );
```

### Downstream Protection Strategies

The `clip_detect` output can be used to implement various protection mechanisms:

1. **Attenuator Control**: Automatically increase attenuation when clipping is detected
2. **Gain Adjustment**: Reduce gain in amplifier stages
3. **Circuit Isolation**: Temporarily disconnect sensitive components
4. **Alert System**: Trigger warnings or system status indicators
5. **Automatic Gain Control (AGC)**: Feed into an AGC loop

## Performance Considerations

- The detector adds minimal latency (1-2 clock cycles)
- Resource utilization is very low (primarily a comparator and counter)
- Power consumption is negligible compared to typical RF components

## Customization

### Adjusting Sensitivity

- Decrease `THRESHOLD` to detect clipping earlier (more sensitive)
- Increase `COUNT_THRESHOLD` to require more consecutive samples (more robust against noise)

### Input Signal Range

- Match `DATA_WIDTH` to your ADC bit width
- Adjust `THRESHOLD` based on your expected signal range and headroom requirements

## Testing

A comprehensive testbench is included that verifies:

- Normal operation (no clipping)
- Brief clipping (below count threshold)
- Sustained clipping (detection triggered)
- Negative signal clipping
- Reset functionality

To run the simulation:
1. Compile both the SignalClippingDetector.vhd and SignalClippingDetector_TB.vhd files
2. Run the simulation for at least 1 μs
3. Monitor the clip_detect and clip_counter signals

## Recommended Applications

- **SDR Systems**: Protect sensitive RF components in Software Defined Radio applications
- **RF Front-Ends**: Monitor input levels before LNA stages
- **ADC Protection**: Detect potentially damaging input levels
- **Signal Quality Monitoring**: Track signal quality in communications systems
- **Automatic Level Control**: Input to level control feedback loops

## License

This implementation is provided under the MIT License.

## Author

Copyright © 2025ssss
