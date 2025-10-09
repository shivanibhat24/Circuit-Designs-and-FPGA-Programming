# RISC-V Vector Coprocessor with Half-Precision Floating-Point Support

## Project Overview

This project implements a hardware vector coprocessor for RISC-V embedded systems, featuring comprehensive support for the RISC-V Vector Extension with enhanced half-precision (FP16) floating-point capabilities. The design targets resource-constrained embedded applications requiring efficient vector processing, such as digital signal processing, machine learning inference, and scientific computing workloads.

## Key Features

### Vector Extension Support
- **ZVE32X**: Integer-only vector operations for embedded systems
- **ZVE32F**: Single-precision (FP32) floating-point vector operations
- **ZVFH**: Half-precision (FP16) floating-point extension for memory-efficient computation

### Floating-Point Capabilities
- IEEE 754-compliant FP16 and FP32 arithmetic units
- Comprehensive operation support including:
  - Basic arithmetic (add, subtract, multiply, divide)
  - Fused multiply-add operations (MADD, MSUB, NMADD, NMSUB)
  - Comparison operations (equal, less than, less than or equal)
  - Min/max operations
  - Sign injection variants (SGNJ, SGNJN, SGNJX)
  - Type conversion between integer and floating-point formats
- Configurable rounding modes (RNE, RTZ, RDN, RUP, RMM)
- Exception flag generation (invalid, divide-by-zero, overflow, underflow, inexact)

### Architecture Highlights
- Multi-stage configurable pipeline for high throughput
- Parallel vector lanes with independent FPU units
- Vector register file with multi-port access and optional ECC protection
- Load/Store Unit with outstanding transaction support for improved memory bandwidth
- Core-V eXtension Interface (XIF) compliant for seamless processor integration

### Design Parameters
- Configurable vector register width (default 256-bit)
- Adjustable vector lane width (default 128-bit)
- Scalable pipeline depth (default 3 stages)
- Support for element widths: 8-bit, 16-bit, 32-bit, and 64-bit
- Vector length multiplier (LMUL) from 1/8 to 8

## Architecture

### Module Hierarchy

```
vicuna2_coprocessor_top
├── vector_decoder (Instruction decode)
├── vector_regfile_enhanced (32 vector registers)
├── vector_execute_pipeline
│   ├── vector_fpu_enhanced
│   │   ├── fp16_alu_enhanced (Multiple instances)
│   │   └── fp32_alu_enhanced (Multiple instances)
│   └── Integer ALU pipeline
└── vector_lsu (Load/Store Unit)
```

### Interface Specifications

#### XIF Issue Interface
Accepts vector instructions from the host processor with ready/valid handshaking protocol.

#### XIF Result Interface
Returns computation results and exception information to the host processor.

#### XIF Memory Interface
Provides access to system memory for vector load/store operations with support for multiple outstanding transactions.

## Implementation Details

### Floating-Point Units

The FP16 and FP32 ALU modules implement IEEE 754 semantics with proper handling of:
- Normal numbers
- Subnormal numbers
- Infinity values
- Not-a-Number (NaN) representations
- Signed zero

### Vector Register File

Features include:
- 32 vector registers with parameterized width
- Multiple simultaneous read ports (default 3)
- Write port with byte-enable granularity
- Bypass logic for hazard avoidance
- Optional Error Correction Code (ECC) for fault tolerance

### Load/Store Unit

Capabilities:
- Unit-stride and strided memory access patterns
- Configurable number of outstanding transactions
- Automatic address generation
- Support for various element widths
- Response tracking and data alignment

## Configuration

Key parameters can be adjusted to meet specific design requirements:

```systemverilog
parameter int VREG_W = 256;              // Vector register width
parameter int VLANE_W = 128;             // Vector lane width
parameter int PIPELINE_STAGES = 3;       // Pipeline depth
parameter vext_type_e VEXT_TYPE = ZVFH;  // Extension type
parameter int XIF_ID_WIDTH = 4;          // Transaction ID width
```

## Usage

### Instantiation Example

```systemverilog
vicuna2_coprocessor_top #(
    .VREG_W(256),
    .VLANE_W(128),
    .VEXT_TYPE(ZVFH)
) coprocessor (
    .clk(clk),
    .rst_n(rst_n),
    .issue_if(issue_interface),
    .result_if(result_interface),
    .mem_if(memory_interface),
    .vtype(vector_type_config),
    .vl(vector_length),
    .vstart(vector_start),
    .idle(idle_status),
    .fflags(fp_flags)
);
```

## Standards Compliance

- RISC-V Vector Extension Specification v1.0
- IEEE 754-2019 Floating-Point Arithmetic Standard
- OpenHW Group Core-V eXtension Interface (CV-X-IF)

## Performance Considerations

The design incorporates several optimizations:
- Parallel processing of multiple vector elements per cycle
- Multi-stage pipelines to maximize clock frequency
- Efficient hazard detection and resolution
- Memory access coalescing in the LSU
- Configurable pipeline depth for area/performance trade-offs

## Synthesis and Verification

The design is written in SystemVerilog and utilizes:
- Parameterized modules for design flexibility
- Enumerated types for improved readability
- Packages for shared definitions
- Interfaces for clean module boundaries
- Generate blocks for scalable instantiation

## Future Enhancements

Potential improvements include:
- Support for 64-bit element operations
- Masked vector operations
- Segmented load/store instructions
- Vector reduction operations
- Enhanced power management features
- Formal verification of IEEE 754 compliance

