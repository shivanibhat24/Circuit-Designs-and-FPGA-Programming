# VHDL Matched Filter for Radar Signal Detection

[![VHDL Standard](https://img.shields.io/badge/VHDL-IEEE%201076--2008-blue)](https://standards.ieee.org/standard/1076-2008.html)

A high-performance, configurable matched filter implementation in VHDL. This repository provides a complete solution for detecting specific pulse shapes in noisy environments.


## Overview

Matched filters are the optimal linear filters for maximizing the signal-to-noise ratio (SNR) in the presence of additive stochastic noise. This implementation is specifically designed for radar applications where the goal is to detect a known pulse shape within a noisy signal.

## Features

- **High-Performance Pipelined Architecture**
  - Multi-stage pipeline design for high throughput
  - Optimized for FPGA implementation

- **Fully Parameterizable Design**
  - Configurable filter tap count
  - Adjustable coefficient and data widths
  - Customizable output width

- **Detection Logic**
  - Built-in threshold comparator
  - Dedicated detection output signal
  - Configurable detection threshold

- **Comprehensive Testbench**
  - Automatic test vector generation
  - Configurable SNR for robustness testing
  - Detection performance analysis

## Implementation Details

The matched filter implementation consists of the following key components:

1. **Shift Register**: Stores the most recent input samples
2. **Coefficient ROM**: Contains the time-reversed expected pulse shape
3. **Multiply-Accumulate Units**: Compute the correlation between input and coefficients
4. **Threshold Detector**: Determines when a signal has been detected

The design is fully pipelined to maximize throughput, with separate stages for:
- Input data shifting
- Multiplication
- Accumulation
- Threshold comparison


## Usage

To use the matched filter in your design:

1. Include the source files in your project
2. Instantiate the matched filter component:

```vhdl
-- Example instantiation
matched_filter_inst : entity work.matched_filter
    generic map (
        COEFF_WIDTH  => 16,
        DATA_WIDTH   => 16,
        FILTER_TAPS  => 16,
        OUTPUT_WIDTH => 36
    )
    port map (
        clk        => system_clk,
        rst        => system_rst,
        signal_in  => adc_data,
        valid_in   => adc_valid,
        signal_out => filter_out,
        valid_out  => filter_valid,
        threshold  => detection_threshold,
        detection  => target_detected
    );
```

## Customization

### Coefficient Customization

To adapt the filter for your specific pulse shape, modify the coefficient array in the matched_filter.vhd file:

```vhdl
constant COEFFS : coefficient_array := (
    to_signed(100, COEFF_WIDTH),     -- First coefficient
    to_signed(300, COEFF_WIDTH),
    -- ... other coefficients
    to_signed(100, COEFF_WIDTH)      -- Last coefficient
);
```

The coefficients should be the time-reversed version of your expected pulse shape for optimal detection.

### Parameter Tuning

Key parameters to tune for your application:

- **FILTER_TAPS**: Number of filter taps (should match your pulse length)
- **COEFF_WIDTH**: Bit width for coefficients (affects dynamic range)
- **DATA_WIDTH**: Bit width for input samples (typically matches ADC resolution)
- **Threshold Value**: Set according to expected SNR and desired false alarm rate

## Performance

The matched filter implementation is optimized for FPGA resources while maintaining high throughput:

- **Throughput**: 1 sample per clock cycle
- **Latency**: FILTER_TAPS + 2 clock cycles
- **Resource Usage**: Scales linearly with number of taps

## Simulation

To run the simulation:

1. Open your VHDL simulator (ModelSim, GHDL, etc.)
2. Load the provided TCL script:
   ```
   source scripts/run_simulation.tcl
   ```
3. The testbench generates test vectors with:
   - Clean pulse shape
   - Pulse with 10dB SNR
   - Pulse with 5dB SNR
   - Pure noise sections

Expected simulation results:
- Detection signal should activate when the matched filter output exceeds the threshold
- Higher correlation peaks for cleaner signals
- Lower correlation peaks for noisier signals
