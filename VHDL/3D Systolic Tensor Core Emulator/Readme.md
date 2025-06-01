# 3D Systolic Tensor Core Emulator

A comprehensive VHDL implementation that emulates NVIDIA's Tensor Core architecture using a 3D systolic array design. This project demonstrates advanced parallel computing concepts and provides insights into modern AI accelerator architectures.

## 🚀 Overview

This tensor core emulator implements a **4×4×4 systolic processing element (PE) mesh** that performs high-throughput matrix operations essential for deep learning workloads. The design supports mixed-precision arithmetic and multiple operation types commonly found in modern neural networks.

### Key Features

- **🔥 64 Processing Elements** in 3D systolic arrangement
- **⚡ Mixed Precision Support**: FP16/BF16 inputs with FP32 accumulation
- **🧠 Multiple AI Operations**: Matrix multiplication, convolutions, attention mechanisms
- **🌊 3D Data Flow**: Multi-dimensional systolic data propagation
- **⚙️ Configurable Operations**: Supports various neural network layer types
- **🎯 High Throughput**: Parallel processing across all dimensions

## 📋 Architecture Details

### Processing Element (PE) Design
```
┌─────────────────────────────────────────┐
│              Processing Element          │
├─────────────────────────────────────────┤
│  Data Inputs:  X, Y, Z (FP16)          │
│  Weight Input: W (FP16)                 │
│  Accumulator:  ACC (FP32)               │
│                                         │
│  Operation: ACC = ACC + (Data × Weight) │
│                                         │
│  Data Outputs: X', Y', Z' (systolic)    │
│  Acc Output:   ACC' (FP32)              │
└─────────────────────────────────────────┘
```

### 3D Systolic Array Layout
```
     Z-axis (depth)
         ↗
        /
       /     Y-axis
      /       ↗
     /       /
    /       /
   ────────→ X-axis
   
4×4×4 PE Grid:
- 64 total processing elements
- Data flows in X, Y, Z directions
- Weights broadcast to respective PEs
- Results accumulate through pipeline
```

### Supported Operations

| Operation Type | Description | Use Case |
|----------------|-------------|----------|
| `MATRIX_MUL` | Dense matrix multiplication | Fully connected layers |
| `CONV_2D` | 2D convolution | Convolutional neural networks |
| `CONV_3D` | 3D convolution | Video processing, 3D CNNs |
| `GEMM` | General matrix-matrix multiply | BLAS operations |
| `ATTENTION` | Attention mechanism | Transformers, BERT, GPT |

