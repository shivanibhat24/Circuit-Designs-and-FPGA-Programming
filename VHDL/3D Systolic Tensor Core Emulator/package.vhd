-- ==============================================================================
-- 3D Systolic Tensor Core Emulator
-- Mimics NVIDIA Tensor Core architecture with 4x4x4 PE mesh
-- Supports mixed-precision matrix operations (FP16/BF16 input, FP32 accumulation)
-- ==============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

-- ==============================================================================
-- Package for Tensor Core Types and Constants
-- ==============================================================================
package tensor_core_pkg is
    -- Array dimensions
    constant ARRAY_SIZE_X : integer := 4;
    constant ARRAY_SIZE_Y : integer := 4;
    constant ARRAY_SIZE_Z : integer := 4;
    
    -- Data precision
    constant FP16_WIDTH : integer := 16;
    constant FP32_WIDTH : integer := 32;
    constant INT8_WIDTH : integer := 8;
    
    -- Matrix dimensions for tensor operations
    constant MATRIX_SIZE : integer := 4;
    
    -- Custom types
    type fp16_array is array (0 to MATRIX_SIZE-1) of std_logic_vector(FP16_WIDTH-1 downto 0);
    type fp32_array is array (0 to MATRIX_SIZE-1) of std_logic_vector(FP32_WIDTH-1 downto 0);
    type int8_array is array (0 to MATRIX_SIZE-1) of std_logic_vector(INT8_WIDTH-1 downto 0);
    
    -- 3D arrays for systolic data flow
    type pe_data_3d is array (0 to ARRAY_SIZE_X-1, 0 to ARRAY_SIZE_Y-1, 0 to ARRAY_SIZE_Z-1) 
                      of std_logic_vector(FP32_WIDTH-1 downto 0);
    type pe_weight_3d is array (0 to ARRAY_SIZE_X-1, 0 to ARRAY_SIZE_Y-1, 0 to ARRAY_SIZE_Z-1) 
                        of std_logic_vector(FP16_WIDTH-1 downto 0);
    
    -- Operation types
    type tensor_op_type is (MATRIX_MUL, CONV_2D, CONV_3D, GEMM, ATTENTION);
    type precision_type is (FP16, BF16, INT8, FP32);
end package;
