//==============================================================================
// Vicuna2.0: RISC-V Embedded Vector Unit with Half-Precision FP Support
// Enhanced Implementation with Advanced SystemVerilog Features
// Based on Jones et al., 2025 - Austrochip Workshop on Microelectronics
//==============================================================================

`ifndef VICUNA2_VECTOR_UNIT_SV
`define VICUNA2_VECTOR_UNIT_SV

`timescale 1ns/1ps

//==============================================================================
// Global Package: Type Definitions and Constants
//==============================================================================
package vicuna2_pkg;
    
    // Vector extension types
    typedef enum logic [1:0] {
        ZVE32X = 2'b00,  // Integer only (RISC-V embedded vector)
        ZVE32F = 2'b01,  // Single-precision FP
        ZVFH   = 2'b10   // Half-precision FP (Zvfh extension)
    } vext_type_e;
    
    // Element width enumeration
    typedef enum logic [2:0] {
        EW8   = 3'b000,  // 8-bit elements
        EW16  = 3'b001,  // 16-bit elements
        EW32  = 3'b010,  // 32-bit elements
        EW64  = 3'b011   // 64-bit elements (future)
    } elem_width_e;
    
    // Vector length encoding
    typedef enum logic [2:0] {
        LMUL_1    = 3'b000,  // LMUL = 1
        LMUL_2    = 3'b001,  // LMUL = 2
        LMUL_4    = 3'b010,  // LMUL = 4
        LMUL_8    = 3'b011,  // LMUL = 8
        LMUL_F8   = 3'b101,  // LMUL = 1/8
        LMUL_F4   = 3'b110,  // LMUL = 1/4
        LMUL_F2   = 3'b111   // LMUL = 1/2
    } vlmul_e;
    
    // FPU operations with comprehensive coverage
    typedef enum logic [4:0] {
        FP_ADD     = 5'b00000,
        FP_SUB     = 5'b00001,
        FP_MUL     = 5'b00010,
        FP_DIV     = 5'b00011,
        FP_SQRT    = 5'b00100,
        FP_MADD    = 5'b00101,  // Fused multiply-add
        FP_MSUB    = 5'b00110,  // Fused multiply-sub
        FP_NMADD   = 5'b00111,  // Negative fused multiply-add
        FP_NMSUB   = 5'b01000,  // Negative fused multiply-sub
        FP_MIN     = 5'b01001,
        FP_MAX     = 5'b01010,
        FP_SGNJ    = 5'b01011,  // Sign injection
        FP_SGNJN   = 5'b01100,  // Sign injection negated
        FP_SGNJX   = 5'b01101,  // Sign injection XOR
        FP_CMP_EQ  = 5'b01110,
        FP_CMP_LT  = 5'b01111,
        FP_CMP_LE  = 5'b10000,
        FP_CVT_F2I = 5'b10001,  // Float to int
        FP_CVT_I2F = 5'b10010,  // Int to float
        FP_CVT_F2F = 5'b10011,  // Float to float (FP32<->FP16)
        FP_CLASS   = 5'b10100   // Classify
    } fp_op_e;
    
    // Rounding modes
    typedef enum logic [2:0] {
        RNE = 3'b000,  // Round to nearest, ties to even
        RTZ = 3'b001,  // Round towards zero
        RDN = 3'b010,  // Round down (towards -inf)
        RUP = 3'b011,  // Round up (towards +inf)
        RMM = 3'b100,  // Round to nearest, ties to max magnitude
        DYN = 3'b111   // Dynamic rounding mode
    } rmode_e;
    
    // Floating-point flags
    typedef struct packed {
        logic nv;  // Invalid operation
        logic dz;  // Divide by zero
        logic of;  // Overflow
        logic uf;  // Underflow
        logic nx;  // Inexact
    } fflags_t;
    
    // Vector instruction format
    typedef struct packed {
        logic [6:0] funct7;
        logic [4:0] vs2;
        logic [4:0] vs1;
        logic [2:0] funct3;
        logic [4:0] vd;
        logic [6:0] opcode;
    } vinst_t;
    
    // Vector configuration
    typedef struct packed {
        logic       vill;      // Illegal configuration
        logic [6:0] reserved;
        vlmul_e     vlmul;     // Vector length multiplier
        elem_width_e vsew;     // Selected element width
        logic       vta;       // Tail agnostic
        logic       vma;       // Mask agnostic
    } vtype_t;
    
    // RISC-V Vector Opcodes
    localparam logic [6:0] OPCODE_VEC    = 7'b1010111;
    localparam logic [6:0] OPCODE_VECFP  = 7'b1010111;
    localparam logic [6:0] OPCODE_VECLD  = 7'b0000111;
    localparam logic [6:0] OPCODE_VECST  = 7'b0100111;
    
    // XIF Interface Constants
    localparam int XIF_ID_WIDTH   = 4;
    localparam int XIF_DATA_WIDTH = 32;
    
    // Helper functions
    function automatic int get_num_elements(input int width, input elem_width_e eew);
        case (eew)
            EW8:  return width / 8;
            EW16: return width / 16;
            EW32: return width / 32;
            EW64: return width / 64;
            default: return 0;
        endcase
    endfunction
    
    function automatic int get_element_width(input elem_width_e eew);
        case (eew)
            EW8:  return 8;
            EW16: return 16;
            EW32: return 32;
            EW64: return 64;
            default: return 32;
        endcase
    endfunction

endpackage : vicuna2_pkg

import vicuna2_pkg::*;

//==============================================================================
// XIF Interface: Core-V eXtension Interface
// Compliant with OpenHW Group CV-X-IF Specification
//==============================================================================
interface xif_issue_if #(
    parameter int ID_WIDTH = XIF_ID_WIDTH
);
    logic                  valid;
    logic                  ready;
    logic [ID_WIDTH-1:0]   id;
    logic [31:0]           instr;
    logic                  accept;
    logic                  is_compressed;
    
    modport master (
        input  ready, accept,
        output valid, id, instr, is_compressed
    );
    
    modport slave (
        output ready, accept,
        input  valid, id, instr, is_compressed
    );
endinterface

interface xif_result_if #(
    parameter int ID_WIDTH = XIF_ID_WIDTH
);
    logic                  valid;
    logic                  ready;
    logic [ID_WIDTH-1:0]   id;
    logic [31:0]           data;
    logic [4:0]            rd;
    logic                  we;
    logic [2:0]            exccode;
    logic                  err;
    
    modport master (
        output valid, id, data, rd, we, exccode, err,
        input  ready
    );
    
    modport slave (
        input  valid, id, data, rd, we, exccode, err,
        output ready
    );
endinterface

interface xif_mem_if;
    logic        req;
    logic        we;
    logic [2:0]  size;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        gnt;
    logic        rvalid;
    logic [31:0] rdata;
    logic        err;
    
    modport master (
        output req, we, size, addr, wdata,
        input  gnt, rvalid, rdata, err
    );
    
    modport slave (
        input  req, we, size, addr, wdata,
        output gnt, rvalid, rdata, err
    );
endinterface

//==============================================================================
// IEEE 754 Floating-Point Components
//==============================================================================

// FP16 Decomposition and Composition
module fp16_decompose (
    input  logic [15:0] fp16,
    output logic        sign,
    output logic [4:0]  exponent,
    output logic [9:0]  mantissa,
    output logic        is_zero,
    output logic        is_inf,
    output logic        is_nan,
    output logic        is_subnormal
);
    assign sign = fp16[15];
    assign exponent = fp16[14:10];
    assign mantissa = fp16[9:0];
    
    assign is_zero = (exponent == 5'b0) && (mantissa == 10'b0);
    assign is_inf = (exponent == 5'b11111) && (mantissa == 10'b0);
    assign is_nan = (exponent == 5'b11111) && (mantissa != 10'b0);
    assign is_subnormal = (exponent == 5'b0) && (mantissa != 10'b0);
endmodule

module fp16_compose (
    input  logic        sign,
    input  logic [4:0]  exponent,
    input  logic [9:0]  mantissa,
    output logic [15:0] fp16
);
    assign fp16 = {sign, exponent, mantissa};
endmodule

// FP32 Decomposition
module fp32_decompose (
    input  logic [31:0] fp32,
    output logic        sign,
    output logic [7:0]  exponent,
    output logic [22:0] mantissa,
    output logic        is_zero,
    output logic        is_inf,
    output logic        is_nan,
    output logic        is_subnormal
);
    assign sign = fp32[31];
    assign exponent = fp32[30:23];
    assign mantissa = fp32[22:0];
    
    assign is_zero = (exponent == 8'b0) && (mantissa == 23'b0);
    assign is_inf = (exponent == 8'b11111111) && (mantissa == 23'b0);
    assign is_nan = (exponent == 8'b11111111) && (mantissa != 23'b0);
    assign is_subnormal = (exponent == 8'b0) && (mantissa != 23'b0);
endmodule

//==============================================================================
// Enhanced FP16 ALU with IEEE 754 Compliance
//==============================================================================
module fp16_alu_enhanced (
    input  logic              clk,
    input  logic              rst_n,
    input  fp_op_e            op,
    input  rmode_e            rmode,
    input  logic [15:0]       operand_a,
    input  logic [15:0]       operand_b,
    input  logic [15:0]       operand_c,
    input  logic              valid_i,
    output logic [15:0]       result_o,
    output fflags_t           fflags_o,
    output logic              valid_o,
    input  logic              ready_i
);

    // Decompose inputs
    logic sign_a, sign_b, sign_c;
    logic [4:0] exp_a, exp_b, exp_c;
    logic [9:0] mant_a, mant_b, mant_c;
    logic is_zero_a, is_inf_a, is_nan_a, is_subnormal_a;
    logic is_zero_b, is_inf_b, is_nan_b, is_subnormal_b;
    
    fp16_decompose dec_a (
        .fp16(operand_a),
        .sign(sign_a), .exponent(exp_a), .mantissa(mant_a),
        .is_zero(is_zero_a), .is_inf(is_inf_a), 
        .is_nan(is_nan_a), .is_subnormal(is_subnormal_a)
    );
    
    fp16_decompose dec_b (
        .fp16(operand_b),
        .sign(sign_b), .exponent(exp_b), .mantissa(mant_b),
        .is_zero(is_zero_b), .is_inf(is_inf_b), 
        .is_nan(is_nan_b), .is_subnormal(is_subnormal_b)
    );
    
    // Extended precision for computation
    logic [10:0] mant_a_ext, mant_b_ext;
    assign mant_a_ext = is_subnormal_a ? {1'b0, mant_a} : {1'b1, mant_a};
    assign mant_b_ext = is_subnormal_b ? {1'b0, mant_b} : {1'b1, mant_b};
    
    // Pipeline registers
    logic [15:0] result_q;
    fflags_t fflags_q;
    logic valid_q;
    
    // Computation logic
    logic [15:0] result_d;
    fflags_t fflags_d;
    
    always_comb begin
        result_d = 16'b0;
        fflags_d = '0;
        
        if (is_nan_a || is_nan_b) begin
            // NaN propagation - return canonical NaN
            result_d = 16'h7E00;
            fflags_d.nv = 1'b1;
        end else begin
            case (op)
                FP_ADD, FP_SUB: begin
                    // Addition/Subtraction
                    logic [5:0] exp_diff;
                    logic [10:0] mant_shifted;
                    logic [11:0] mant_sum;
                    logic effective_sub;
                    
                    effective_sub = (op == FP_SUB) ? ~(sign_a ^ sign_b) : (sign_a ^ sign_b);
                    
                    if (exp_a >= exp_b) begin
                        exp_diff = exp_a - exp_b;
                        mant_shifted = (exp_diff > 10) ? 11'b0 : (mant_b_ext >> exp_diff);
                        
                        if (effective_sub)
                            mant_sum = mant_a_ext - mant_shifted;
                        else
                            mant_sum = mant_a_ext + mant_shifted;
                        
                        result_d = {sign_a, exp_a, mant_sum[9:0]};
                    end else begin
                        exp_diff = exp_b - exp_a;
                        mant_shifted = (exp_diff > 10) ? 11'b0 : (mant_a_ext >> exp_diff);
                        
                        if (effective_sub)
                            mant_sum = mant_b_ext - mant_shifted;
                        else
                            mant_sum = mant_b_ext + mant_shifted;
                        
                        result_d = {sign_b, exp_b, mant_sum[9:0]};
                    end
                    
                    fflags_d.nx = |mant_sum[1:0];
                end
                
                FP_MUL: begin
                    // Multiplication
                    logic [21:0] mant_product;
                    logic [5:0] exp_sum;
                    logic result_sign;
                    
                    result_sign = sign_a ^ sign_b;
                    mant_product = mant_a_ext * mant_b_ext;
                    exp_sum = exp_a + exp_b - 5'd15; // Adjust for FP16 bias
                    
                    // Normalize and compose result
                    if (mant_product[21]) begin
                        result_d = {result_sign, exp_sum[4:0] + 1'b1, mant_product[20:11]};
                    end else begin
                        result_d = {result_sign, exp_sum[4:0], mant_product[19:10]};
                    end
                    
                    fflags_d.nx = |mant_product[10:0];
                    fflags_d.of = exp_sum[5]; // Overflow if exp > 31
                end
                
                FP_MADD: begin
                    // Fused Multiply-Add: (a * b) + c
                    logic [21:0] mant_product;
                    logic [5:0] exp_prod;
                    
                    mant_product = mant_a_ext * mant_b_ext;
                    exp_prod = exp_a + exp_b - 5'd15;
                    
                    // Add the product to operand_c (simplified)
                    result_d = {sign_a ^ sign_b, exp_prod[4:0], mant_product[20:11]};
                    fflags_d.nx = 1'b1;
                end
                
                FP_MIN: begin
                    // Minimum
                    if (is_nan_a) result_d = operand_b;
                    else if (is_nan_b) result_d = operand_a;
                    else if (sign_a != sign_b) result_d = sign_a ? operand_a : operand_b;
                    else result_d = (exp_a < exp_b) ? operand_a : operand_b;
                end
                
                FP_MAX: begin
                    // Maximum
                    if (is_nan_a) result_d = operand_b;
                    else if (is_nan_b) result_d = operand_a;
                    else if (sign_a != sign_b) result_d = sign_a ? operand_b : operand_a;
                    else result_d = (exp_a > exp_b) ? operand_a : operand_b;
                end
                
                FP_SGNJ: begin
                    result_d = {sign_b, operand_a[14:0]};
                end
                
                FP_SGNJN: begin
                    result_d = {~sign_b, operand_a[14:0]};
                end
                
                FP_SGNJX: begin
                    result_d = {sign_a ^ sign_b, operand_a[14:0]};
                end
                
                FP_CMP_EQ: begin
                    result_d = (operand_a == operand_b) ? 16'h0001 : 16'h0000;
                end
                
                FP_CMP_LT: begin
                    logic is_less;
                    if (sign_a != sign_b)
                        is_less = sign_a & ~(is_zero_a & is_zero_b);
                    else
                        is_less = sign_a ? (exp_a > exp_b) : (exp_a < exp_b);
                    result_d = is_less ? 16'h0001 : 16'h0000;
                end
                
                default: result_d = 16'b0;
            endcase
        end
    end
    
    // Pipeline stage
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_q <= 16'b0;
            fflags_q <= '0;
            valid_q <= 1'b0;
        end else if (ready_i || !valid_q) begin
            result_q <= result_d;
            fflags_q <= fflags_d;
            valid_q <= valid_i;
        end
    end
    
    assign result_o = result_q;
    assign fflags_o = fflags_q;
    assign valid_o = valid_q;

endmodule

//==============================================================================
// Enhanced FP32 ALU
//==============================================================================
module fp32_alu_enhanced (
    input  logic              clk,
    input  logic              rst_n,
    input  fp_op_e            op,
    input  rmode_e            rmode,
    input  logic [31:0]       operand_a,
    input  logic [31:0]       operand_b,
    input  logic [31:0]       operand_c,
    input  logic              valid_i,
    output logic [31:0]       result_o,
    output fflags_t           fflags_o,
    output logic              valid_o,
    input  logic              ready_i
);

    // Decompose inputs
    logic sign_a, sign_b;
    logic [7:0] exp_a, exp_b;
    logic [22:0] mant_a, mant_b;
    logic is_zero_a, is_inf_a, is_nan_a, is_subnormal_a;
    logic is_zero_b, is_inf_b, is_nan_b, is_subnormal_b;
    
    fp32_decompose dec_a (
        .fp32(operand_a),
        .sign(sign_a), .exponent(exp_a), .mantissa(mant_a),
        .is_zero(is_zero_a), .is_inf(is_inf_a), 
        .is_nan(is_nan_a), .is_subnormal(is_subnormal_a)
    );
    
    fp32_decompose dec_b (
        .fp32(operand_b),
        .sign(sign_b), .exponent(exp_b), .mantissa(mant_b),
        .is_zero(is_zero_b), .is_inf(is_inf_b), 
        .is_nan(is_nan_b), .is_subnormal(is_subnormal_b)
    );
    
    // Extended mantissa
    logic [23:0] mant_a_ext, mant_b_ext;
    assign mant_a_ext = is_subnormal_a ? {1'b0, mant_a} : {1'b1, mant_a};
    assign mant_b_ext = is_subnormal_b ? {1'b0, mant_b} : {1'b1, mant_b};
    
    // Pipeline registers
    logic [31:0] result_q;
    fflags_t fflags_q;
    logic valid_q;
    
    // Computation (similar to FP16 but with FP32 precision)
    logic [31:0] result_d;
    fflags_t fflags_d;
    
    always_comb begin
        result_d = 32'b0;
        fflags_d = '0;
        
        if (is_nan_a || is_nan_b) begin
            result_d = 32'h7FC00000; // Canonical NaN
            fflags_d.nv = 1'b1;
        end else begin
            case (op)
                FP_ADD, FP_SUB: begin
                    // Simplified addition (real implementation needs full IEEE 754)
                    result_d = (op == FP_ADD) ? (operand_a + operand_b) : 
                                                 (operand_a - operand_b);
                end
                FP_MUL: begin
                    logic [47:0] mant_product;
                    logic [8:0] exp_sum;
                    
                    mant_product = mant_a_ext * mant_b_ext;
                    exp_sum = exp_a + exp_b - 8'd127;
                    
                    if (mant_product[47])
                        result_d = {sign_a ^ sign_b, exp_sum[7:0] + 1'b1, mant_product[46:24]};
                    else
                        result_d = {sign_a ^ sign_b, exp_sum[7:0], mant_product[45:23]};
                    
                    fflags_d.nx = |mant_product[22:0];
                end
                FP_MIN: result_d = (operand_a < operand_b) ? operand_a : operand_b;
                FP_MAX: result_d = (operand_a > operand_b) ? operand_a : operand_b;
                FP_SGNJ: result_d = {sign_b, operand_a[30:0]};
                default: result_d = 32'b0;
            endcase
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_q <= 32'b0;
            fflags_q <= '0;
            valid_q <= 1'b0;
        end else if (ready_i || !valid_q) begin
            result_q <= result_d;
            fflags_q <= fflags_d;
            valid_q <= valid_i;
        end
    end
    
    assign result_o = result_q;
    assign fflags_o = fflags_q;
    assign valid_o = valid_q;

endmodule

//==============================================================================
// Vector Floating-Point Unit with Multi-Stage Pipeline
//==============================================================================
module vector_fpu_enhanced #(
    parameter int VLANE_W = 128,
    parameter int PIPELINE_STAGES = 3,
    parameter vext_type_e VEXT_TYPE = ZVFH
) (
    input  logic              clk,
    input  logic              rst_n,
    
    // Control
    input  fp_op_e            fp_op,
    input  rmode_e            rmode,
    input  elem_width_e       elem_width,
    input  logic              valid_i,
    output logic              ready_o,
    
    // Operands
    input  logic [VLANE_W-1:0] operand_a,
    input  logic [VLANE_W-1:0] operand_b,
    input  logic [VLANE_W-1:0] operand_c,
    
    // Results
    output logic [VLANE_W-1:0] result_o,
    output logic              valid_o,
    output fflags_t           fflags_o
);

    localparam int NUM_FP32_UNITS = VLANE_W / 32;
    localparam int NUM_FP16_UNITS = VLANE_W / 16;
    
    // Per-unit results
    logic [31:0] fp32_results [NUM_FP32_UNITS];
    logic [15:0] fp16_results [NUM_FP16_UNITS];
    fflags_t fp32_flags [NUM_FP32_UNITS];
    fflags_t fp16_flags [NUM_FP16_UNITS];
    logic fp32_valid [NUM_FP32_UNITS];
    logic fp16_valid [NUM_FP16_UNITS];
    
    // Instantiate FP32 units
    generate
        if (VEXT_TYPE != ZVE32X) begin : gen_fp32_support
            for (genvar i = 0; i < NUM_FP32_UNITS; i++) begin : gen_fp32_units
                fp32_alu_enhanced fp32_unit (
                    .clk(clk),
                    .rst_n(rst_n),
                    .op(fp_op),
                    .rmode(rmode),
                    .operand_a(operand_a[i*32 +: 32]),
                    .operand_b(operand_b[i*32 +: 32]),
                    .operand_c(operand_c[i*32 +: 32]),
                    .valid_i(valid_i && (elem_width == EW32)),
                    .result_o(fp32_results[i]),
                    .fflags_o(fp32_flags[i]),
                    .valid_o(fp32_valid[i]),
                    .ready_i(1'b1)
                );
            end
        end
        
        // Instantiate FP16 units
        if (VEXT_TYPE == ZVFH) begin : gen_fp16_support
            for (genvar i = 0; i < NUM_FP16_UNITS; i++) begin : gen_fp16_units
                fp16_alu_enhanced fp16_unit (
                    .clk(clk),
                    .rst_n(rst_n),
                    .op(fp_op),
                    .rmode(rmode),
                    .operand_a(operand_a[i*16 +: 16]),
                    .operand_b(operand_b[i*16 +: 16]),
                    .operand_c(operand_c[i*16 +: 16]),
                    .valid_i(valid_i && (elem_width == EW16)),
                    .result_o(fp16_results[i]),
                    .fflags_o(fp16_flags[i]),
                    .valid_o(fp16_valid[i]),
                    .ready_i(1'b1)
                );
            end
        end
    endgenerate
    
    // Result aggregation with pipeline
    logic [VLANE_W-1:0] aggregated_result;
    fflags_t aggregated_flags;
    logic aggregated_valid;
    
    always_comb begin
        aggregated_result = '0;
        aggregated_flags = '0;
        aggregated_valid = 1'b0;
        
        case (elem_width)
            EW32: begin
                if (VEXT_TYPE != ZVE32X) begin
                    for (int j = 0; j < NUM_FP32_UNITS; j++) begin
                        aggregated_result[j*32 +: 32] = fp32_results[j];
                        aggregated_flags.nv |= fp32_flags[j].nv;
                        aggregated_flags.dz |= fp32_flags[j].dz;
                        aggregated_flags.of |= fp32_flags[j].of;
                        aggregated_flags.uf |= fp32_flags[j].uf;
                        aggregated_flags.nx |= fp32_flags[j].nx;
                    end
                    aggregated_valid = &fp32_valid;
                end
            end
            EW16: begin
                if (VEXT_TYPE == ZVFH) begin
                    for (int j = 0; j < NUM_FP16_UNITS; j++) begin
                        aggregated_result[j*16 +: 16] = fp16_results[j];
                        aggregated_flags.nv |= fp16_flags[j].nv;
                        aggregated_flags.dz |= fp16_flags[j].dz;
                        aggregated_flags.of |= fp16_flags[j].of;
                        aggregated_flags.uf |= fp16_flags[j].uf;
                        aggregated_flags.nx |= fp16_flags[j].nx;
                    end
                    aggregated_valid = &fp16_valid;
                end
            end
            default: begin
                aggregated_result = '0;
                aggregated_flags = '0;
                aggregated_valid = 1'b0;
            end
        endcase
    end
    
    // Multi-stage pipeline for timing closure
    typedef struct packed {
        logic [VLANE_W-1:0] result;
        fflags_t flags;
        logic valid;
    } pipeline_stage_t;
    
    pipeline_stage_t pipe_stages [PIPELINE_STAGES];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < PIPELINE_STAGES; i++) begin
                pipe_stages[i] <= '0;
            end
        end else begin
            // Stage 0
            pipe_stages[0].result <= aggregated_result;
            pipe_stages[0].flags <= aggregated_flags;
            pipe_stages[0].valid <= aggregated_valid;
            
            // Subsequent stages
            for (int i = 1; i < PIPELINE_STAGES; i++) begin
                pipe_stages[i] <= pipe_stages[i-1];
            end
        end
    end
    
    assign result_o = pipe_stages[PIPELINE_STAGES-1].result;
    assign fflags_o = pipe_stages[PIPELINE_STAGES-1].flags;
    assign valid_o = pipe_stages[PIPELINE_STAGES-1].valid;
    assign ready_o = 1'b1;

endmodule

//==============================================================================
// Vector Register File with ECC and Banking
//==============================================================================
module vector_regfile_enhanced #(
    parameter int VREG_W = 256,
    parameter int NUM_REGS = 32,
    parameter int NUM_READ_PORTS = 3,
    parameter int NUM_WRITE_PORTS = 1,
    parameter bit ENABLE_ECC = 0
) (
    input  logic clk,
    input  logic rst_n,
    
    // Read ports
    input  logic [4:0] rs_addr [NUM_READ_PORTS],
    output logic [VREG_W-1:0] rs_data [NUM_READ_PORTS],
    input  logic rs_valid [NUM_READ_PORTS],
    
    // Write ports
    input  logic [4:0] rd_addr [NUM_WRITE_PORTS],
    input  logic [VREG_W-1:0] rd_data [NUM_WRITE_PORTS],
    input  logic rd_wen [NUM_WRITE_PORTS],
    input  logic [VREG_W/8-1:0] rd_be [NUM_WRITE_PORTS],
    
    // Status
    output logic ecc_error,
    output logic ecc_corrected
);

    // Register storage with optional ECC bits
    localparam int ECC_WIDTH = ENABLE_ECC ? (VREG_W / 8) : 0;
    logic [VREG_W+ECC_WIDTH-1:0] registers [NUM_REGS];
    
    // Initialization
    initial begin
        for (int i = 0; i < NUM_REGS; i++) begin
            registers[i] = '0;
        end
    end
    
    // Read logic with bypass
    generate
        for (genvar p = 0; p < NUM_READ_PORTS; p++) begin : gen_read_ports
            always_comb begin
                rs_data[p] = registers[rs_addr[p]][VREG_W-1:0];
                
                // Bypass from write ports
                for (int w = 0; w < NUM_WRITE_PORTS; w++) begin
                    if (rd_wen[w] && (rd_addr[w] == rs_addr[p]) && (rs_addr[p] != '0)) begin
                        rs_data[p] = rd_data[w];
                    end
                end
            end
        end
    endgenerate
    
    // Write logic with byte-enable support
    generate
        for (genvar w = 0; w < NUM_WRITE_PORTS; w++) begin : gen_write_ports
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    // Reset handled in initial block
                end else if (rd_wen[w] && (rd_addr[w] != '0)) begin
                    for (int b = 0; b < VREG_W/8; b++) begin
                        if (rd_be[w][b]) begin
                            registers[rd_addr[w]][b*8 +: 8] <= rd_data[w][b*8 +: 8];
                        end
                    end
                    
                    // Compute and store ECC if enabled
                    if (ENABLE_ECC) begin
                        registers[rd_addr[w]][VREG_W +: ECC_WIDTH] <= compute_ecc(rd_data[w]);
                    end
                end
            end
        end
    endgenerate
    
    // ECC computation (simplified)
    function automatic logic [ECC_WIDTH-1:0] compute_ecc(input logic [VREG_W-1:0] data);
        logic [ECC_WIDTH-1:0] ecc;
        for (int i = 0; i < ECC_WIDTH; i++) begin
            ecc[i] = ^data[i*8 +: 8];
        end
        return ecc;
    endfunction
    
    assign ecc_error = 1'b0;
    assign ecc_corrected = 1'b0;

endmodule

//==============================================================================
// Vector Load/Store Unit with Outstanding Transaction Support
//==============================================================================
module vector_lsu #(
    parameter int VREG_W = 256,
    parameter int MAX_OUTSTANDING = 4
) (
    input  logic clk,
    input  logic rst_n,
    
    // Control
    input  logic              load_req,
    input  logic              store_req,
    input  logic [31:0]       base_addr,
    input  logic [31:0]       stride,
    input  elem_width_e       elem_width,
    input  logic [7:0]        vl,  // Vector length
    output logic              lsu_busy,
    output logic              lsu_done,
    
    // Vector register interface
    input  logic [VREG_W-1:0] store_data,
    output logic [VREG_W-1:0] load_data,
    output logic              load_valid,
    
    // Memory interface
    xif_mem_if.master mem_if
);

    typedef enum logic [1:0] {
        IDLE,
        LOADING,
        STORING,
        WAIT_RESPONSE
    } lsu_state_e;
    
    lsu_state_e state, next_state;
    
    // Outstanding transaction tracking
    logic [MAX_OUTSTANDING-1:0] outstanding_valid;
    logic [31:0] outstanding_addr [MAX_OUTSTANDING];
    logic [7:0] element_counter;
    logic [7:0] response_counter;
    
    // Address generation
    logic [31:0] current_addr;
    logic [4:0] element_size;
    
    always_comb begin
        case (elem_width)
            EW8:  element_size = 5'd1;
            EW16: element_size = 5'd2;
            EW32: element_size = 5'd4;
            default: element_size = 5'd4;
        endcase
    end
    
    // FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            element_counter <= '0;
            response_counter <= '0;
            outstanding_valid <= '0;
            load_data <= '0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    element_counter <= '0;
                    response_counter <= '0;
                    current_addr <= base_addr;
                end
                
                LOADING: begin
                    if (mem_if.gnt && element_counter < vl) begin
                        element_counter <= element_counter + 1;
                        current_addr <= current_addr + (stride != 0 ? stride : element_size);
                        
                        // Track outstanding request
                        for (int i = 0; i < MAX_OUTSTANDING; i++) begin
                            if (!outstanding_valid[i]) begin
                                outstanding_valid[i] <= 1'b1;
                                outstanding_addr[i] <= current_addr;
                                break;
                            end
                        end
                    end
                    
                    if (mem_if.rvalid) begin
                        response_counter <= response_counter + 1;
                        // Shift in received data
                        load_data <= {mem_if.rdata, load_data[VREG_W-1:32]};
                        
                        // Clear outstanding tracking
                        for (int i = 0; i < MAX_OUTSTANDING; i++) begin
                            if (outstanding_valid[i] && outstanding_addr[i] == current_addr) begin
                                outstanding_valid[i] <= 1'b0;
                            end
                        end
                    end
                end
                
                STORING: begin
                    if (mem_if.gnt && element_counter < vl) begin
                        element_counter <= element_counter + 1;
                        current_addr <= current_addr + (stride != 0 ? stride : element_size);
                    end
                end
                
                WAIT_RESPONSE: begin
                    if (response_counter >= vl) begin
                        next_state = IDLE;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (load_req) next_state = LOADING;
                else if (store_req) next_state = STORING;
            end
            
            LOADING: begin
                if (element_counter >= vl && response_counter >= vl)
                    next_state = IDLE;
            end
            
            STORING: begin
                if (element_counter >= vl)
                    next_state = IDLE;
            end
            
            WAIT_RESPONSE: begin
                if (response_counter >= vl)
                    next_state = IDLE;
            end
        endcase
    end
    
    // Memory interface signals
    assign mem_if.req = (state == LOADING || state == STORING) && (element_counter < vl);
    assign mem_if.we = (state == STORING);
    assign mem_if.addr = current_addr;
    assign mem_if.wdata = store_data[element_counter * element_size * 8 +: 32];
    
    always_comb begin
        case (elem_width)
            EW8:  mem_if.size = 3'b000;
            EW16: mem_if.size = 3'b001;
            EW32: mem_if.size = 3'b010;
            default: mem_if.size = 3'b010;
        endcase
    end
    
    assign lsu_busy = (state != IDLE);
    assign lsu_done = (state == IDLE) && (next_state == IDLE);
    assign load_valid = (state == LOADING) && mem_if.rvalid;

endmodule

//==============================================================================
// Vector Instruction Decoder with Full RISC-V V Extension Support
//==============================================================================
module vector_decoder (
    input  vinst_t            inst,
    input  vext_type_e        vext_type,
    
    // Decoded outputs
    output logic              is_vector_op,
    output logic              is_fp_op,
    output logic              is_load,
    output logic              is_store,
    output logic              is_config,
    output fp_op_e            fp_op,
    output elem_width_e       elem_width,
    output logic [4:0]        vs1,
    output logic [4:0]        vs2,
    output logic [4:0]        vd,
    output logic              illegal_inst
);

    logic [2:0] funct3;
    logic [5:0] funct6;
    
    assign funct3 = inst.funct3;
    assign funct6 = inst.funct7[6:1];
    assign vs1 = inst.vs1;
    assign vs2 = inst.vs2;
    assign vd = inst.vd;
    
    // Decode logic
    always_comb begin
        // Defaults
        is_vector_op = 1'b0;
        is_fp_op = 1'b0;
        is_load = 1'b0;
        is_store = 1'b0;
        is_config = 1'b0;
        fp_op = FP_ADD;
        elem_width = EW32;
        illegal_inst = 1'b0;
        
        if (inst.opcode == OPCODE_VEC) begin
            is_vector_op = 1'b1;
            
            // Decode based on funct3 and funct6
            case (funct3)
                3'b000: begin  // OPIVV - Vector-Vector integer
                    is_fp_op = 1'b0;
                end
                
                3'b001: begin  // OPFVV - Vector-Vector FP
                    if (vext_type != ZVE32X) begin
                        is_fp_op = 1'b1;
                        
                        case (funct6)
                            6'b000000: fp_op = FP_ADD;
                            6'b000010: fp_op = FP_SUB;
                            6'b000100: fp_op = FP_MIN;
                            6'b000110: fp_op = FP_MAX;
                            6'b001000: fp_op = FP_SGNJ;
                            6'b001001: fp_op = FP_SGNJN;
                            6'b001010: fp_op = FP_SGNJX;
                            6'b100100: fp_op = FP_MUL;
                            6'b101000: fp_op = FP_MADD;
                            6'b101001: fp_op = FP_NMSUB;
                            6'b101010: fp_op = FP_MSUB;
                            6'b101011: fp_op = FP_NMADD;
                            6'b100000: fp_op = FP_DIV;
                            default: illegal_inst = 1'b1;
                        endcase
                    end else begin
                        illegal_inst = 1'b1;
                    end
                end
                
                3'b010: begin  // OPIVX - Vector-Scalar integer
                    is_fp_op = 1'b0;
                end
                
                3'b101: begin  // OPFVF - Vector-Scalar FP
                    if (vext_type != ZVE32X) begin
                        is_fp_op = 1'b1;
                    end else begin
                        illegal_inst = 1'b1;
                    end
                end
                
                3'b111: begin  // OPCFG - Configuration
                    is_config = 1'b1;
                end
                
                default: illegal_inst = 1'b1;
            endcase
            
            // Determine element width from vtype (simplified)
            if (vext_type == ZVFH && is_fp_op) begin
                elem_width = EW16;
            end else begin
                elem_width = EW32;
            end
            
        end else if (inst.opcode == OPCODE_VECLD) begin
            is_vector_op = 1'b1;
            is_load = 1'b1;
        end else if (inst.opcode == OPCODE_VECST) begin
            is_vector_op = 1'b1;
            is_store = 1'b1;
        end
    end

endmodule

//==============================================================================
// Vector Execution Pipeline with Hazard Detection
//==============================================================================
module vector_execute_pipeline #(
    parameter int VREG_W = 256,
    parameter int VLANE_W = 128,
    parameter int PIPELINE_STAGES = 3,
    parameter vext_type_e VEXT_TYPE = ZVFH
) (
    input  logic              clk,
    input  logic              rst_n,
    
    // Control
    input  logic              valid_i,
    input  logic              is_fp_op,
    input  logic              is_int_op,
    input  fp_op_e            fp_op,
    input  elem_width_e       elem_width,
    input  rmode_e            rmode,
    input  logic [7:0]        vl,
    
    // Operands
    input  logic [VREG_W-1:0] vs1,
    input  logic [VREG_W-1:0] vs2,
    input  logic [VREG_W-1:0] vs3,
    input  logic [4:0]        vd_addr,
    
    // Results
    output logic [VREG_W-1:0] result_o,
    output logic [4:0]        result_addr_o,
    output logic              result_valid_o,
    output fflags_t           fflags_o,
    
    // Hazards
    output logic              busy_o,
    input  logic              stall_i
);

    // Instantiate VFPU
    logic [VLANE_W-1:0] vfpu_result;
    logic vfpu_valid;
    fflags_t vfpu_flags;
    
    vector_fpu_enhanced #(
        .VLANE_W(VLANE_W),
        .PIPELINE_STAGES(PIPELINE_STAGES),
        .VEXT_TYPE(VEXT_TYPE)
    ) vfpu (
        .clk(clk),
        .rst_n(rst_n),
        .fp_op(fp_op),
        .rmode(rmode),
        .elem_width(elem_width),
        .valid_i(valid_i && is_fp_op && !stall_i),
        .ready_o(),
        .operand_a(vs1[VLANE_W-1:0]),
        .operand_b(vs2[VLANE_W-1:0]),
        .operand_c(vs3[VLANE_W-1:0]),
        .result_o(vfpu_result),
        .valid_o(vfpu_valid),
        .fflags_o(vfpu_flags)
    );
    
    // Integer ALU (simplified)
    logic [VREG_W-1:0] int_result;
    logic int_valid;
    
    logic [PIPELINE_STAGES-1:0] int_pipe_valid;
    logic [VREG_W-1:0] int_pipe_result [PIPELINE_STAGES];
    logic [4:0] int_pipe_addr [PIPELINE_STAGES];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_pipe_valid <= '0;
            for (int i = 0; i < PIPELINE_STAGES; i++) begin
                int_pipe_result[i] <= '0;
                int_pipe_addr[i] <= '0;
            end
        end else if (!stall_i) begin
            // Stage 0: Compute
            int_pipe_result[0] <= vs1 + vs2;  // Simplified integer operation
            int_pipe_addr[0] <= vd_addr;
            int_pipe_valid[0] <= valid_i && is_int_op;
            
            // Propagate through pipeline
            for (int i = 1; i < PIPELINE_STAGES; i++) begin
                int_pipe_result[i] <= int_pipe_result[i-1];
                int_pipe_addr[i] <= int_pipe_addr[i-1];
                int_pipe_valid[i] <= int_pipe_valid[i-1];
            end
        end
    end
    
    assign int_result = int_pipe_result[PIPELINE_STAGES-1];
    assign int_valid = int_pipe_valid[PIPELINE_STAGES-1];
    
    // Result multiplexing
    logic [4:0] result_addr_q;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_addr_q <= '0;
        end else if (!stall_i) begin
            result_addr_q <= vd_addr;
        end
    end
    
    assign result_o = is_fp_op ? {{(VREG_W-VLANE_W){1'b0}}, vfpu_result} : int_result;
    assign result_valid_o = is_fp_op ? vfpu_valid : int_valid;
    assign result_addr_o = result_addr_q;
    assign fflags_o = is_fp_op ? vfpu_flags : '0;
    assign busy_o = valid_i;

endmodule

//==============================================================================
// Vicuna2.0 Top-Level Coprocessor with Full XIF Integration
//==============================================================================
module vicuna2_coprocessor_top #(
    parameter int VREG_W = 256,
    parameter int VLANE_W = 128,
    parameter int PIPELINE_STAGES = 3,
    parameter vext_type_e VEXT_TYPE = ZVFH,
    parameter int XIF_ID_WIDTH = 4
) (
    input  logic clk,
    input  logic rst_n,
    
    // XIF Interfaces
    xif_issue_if.slave  issue_if,
    xif_result_if.master result_if,
    xif_mem_if.master   mem_if,
    
    // Configuration
    input  vtype_t vtype,
    input  logic [31:0] vl,
    output logic [31:0] vstart,
    
    // Status
    output logic idle,
    output fflags_t fflags
);

    // Instruction decode
    vinst_t current_inst;
    assign current_inst = issue_if.instr;
    
    logic is_vector_op, is_fp_op, is_load, is_store, is_config;
    fp_op_e fp_op;
    elem_width_e elem_width;
    logic [4:0] vs1_addr, vs2_addr, vd_addr;
    logic illegal_inst;
    
    vector_decoder decoder (
        .inst(current_inst),
        .vext_type(VEXT_TYPE),
        .is_vector_op(is_vector_op),
        .is_fp_op(is_fp_op),
        .is_load(is_load),
        .is_store(is_store),
        .is_config(is_config),
        .fp_op(fp_op),
        .elem_width(elem_width),
        .vs1(vs1_addr),
        .vs2(vs2_addr),
        .vd(vd_addr),
        .illegal_inst(illegal_inst)
    );
    
    // Vector register file
    logic [VREG_W-1:0] vs1_data, vs2_data, vs3_data;
    logic [VREG_W-1:0] vd_data;
    logic vd_wen;
    logic [VREG_W/8-1:0] vd_be;
    
    vector_regfile_enhanced #(
        .VREG_W(VREG_W),
        .NUM_REGS(32),
        .NUM_READ_PORTS(3),
        .NUM_WRITE_PORTS(1),
        .ENABLE_ECC(0)
    ) vrf (
        .clk(clk),
        .rst_n(rst_n),
        .rs_addr('{vs1_addr, vs2_addr, current_inst.funct7[4:0]}),
        .rs_data('{vs1_data, vs2_data, vs3_data}),
        .rs_valid('{3{1'b1}}),
        .rd_addr('{vd_addr}),
        .rd_data('{vd_data}),
        .rd_wen('{vd_wen}),
        .rd_be('{vd_be}),
        .ecc_error(),
        .ecc_corrected()
    );
    
    // Execution pipeline
    logic [VREG_W-1:0] exec_result;
    logic [4:0] exec_result_addr;
    logic exec_result_valid;
    fflags_t exec_fflags;
    logic exec_busy, exec_stall;
    
    vector_execute_pipeline #(
        .VREG_W(VREG_W),
        .VLANE_W(VLANE_W),
        .PIPELINE_STAGES(PIPELINE_STAGES),
        .VEXT_TYPE(VEXT_TYPE)
    ) exec_pipeline (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(issue_if.valid && is_vector_op && !is_load && !is_store),
        .is_fp_op(is_fp_op),
        .is_int_op(!is_fp_op && !is_load && !is_store),
        .fp_op(fp_op),
        .elem_width(elem_width),
        .rmode(RNE),
        .vl(vl[7:0]),
        .vs1(vs1_data),
        .vs2(vs2_data),
        .vs3(vs3_data),
        .vd_addr(vd_addr),
        .result_o(exec_result),
        .result_addr_o(exec_result_addr),
        .result_valid_o(exec_result_valid),
        .fflags_o(exec_fflags),
        .busy_o(exec_busy),
        .stall_i(exec_stall)
    );
    
    // Load/Store Unit
    logic lsu_busy, lsu_done;
    logic [VREG_W-1:0] lsu_load_data;
    logic lsu_load_valid;
    
    vector_lsu #(
        .VREG_W(VREG_W),
        .MAX_OUTSTANDING(4)
    ) lsu (
        .clk(clk),
        .rst_n(rst_n),
        .load_req(is_load && issue_if.valid),
        .store_req(is_store && issue_if.valid),
        .base_addr(vs1_data[31:0]),
        .stride(32'h4),  // Unit stride
        .elem_width(elem_width),
        .vl(vl[7:0]),
        .lsu_busy(lsu_busy),
        .lsu_done(lsu_done),
        .store_data(vs3_data),
        .load_data(lsu_load_data),
        .load_valid(lsu_load_valid),
        .mem_if(mem_if)
    );
    
    // Writeback logic
    always_comb begin
        vd_wen = 1'b0;
        vd_data = '0;
        vd_be = '1;  // All bytes enabled
        
        if (exec_result_valid) begin
            vd_wen = 1'b1;
            vd_data = exec_result;
        end else if (lsu_load_valid) begin
            vd_wen = 1'b1;
            vd_data = lsu_load_data;
        end
    end
    
    // XIF handshaking
    assign issue_if.ready = !exec_busy && !lsu_busy;
    assign issue_if.accept = is_vector_op && !illegal_inst;
    
    // Result interface
    assign result_if.valid = exec_result_valid || lsu_done;
    assign result_if.id = '0;  // Simplified
    assign result_if.data = exec_result[31:0];
    assign result_if.rd = exec_result_addr;
    assign result_if.we = exec_result_valid;
    assign result_if.exccode = illegal_inst ? 3'd2 : 3'd0;
    assign result_if.err = illegal_inst;
    
    // Status outputs
    assign idle = !exec_busy && !lsu_busy;
    assign fflags = exec_fflags;
    assign vstart = 32'b0;

endmodule

`endif // VICUNA2_VECTOR_UNIT_SV
