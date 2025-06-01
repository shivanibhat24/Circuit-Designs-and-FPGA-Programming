-- ==============================================================================
-- Processing Element (PE) - Core computational unit
-- ==============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.tensor_core_pkg.all;

entity processing_element is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        enable        : in  std_logic;
        
        -- Data inputs (from neighboring PEs)
        data_in_x     : in  std_logic_vector(FP16_WIDTH-1 downto 0);
        data_in_y     : in  std_logic_vector(FP16_WIDTH-1 downto 0);
        data_in_z     : in  std_logic_vector(FP16_WIDTH-1 downto 0);
        
        -- Weight input
        weight_in     : in  std_logic_vector(FP16_WIDTH-1 downto 0);
        
        -- Accumulator input
        acc_in        : in  std_logic_vector(FP32_WIDTH-1 downto 0);
        
        -- Data outputs (to neighboring PEs)
        data_out_x    : out std_logic_vector(FP16_WIDTH-1 downto 0);
        data_out_y    : out std_logic_vector(FP16_WIDTH-1 downto 0);
        data_out_z    : out std_logic_vector(FP16_WIDTH-1 downto 0);
        
        -- Accumulator output
        acc_out       : out std_logic_vector(FP32_WIDTH-1 downto 0);
        
        -- Control signals
        op_type       : in  tensor_op_type;
        precision     : in  precision_type
    );
end entity;

architecture behavioral of processing_element is
    -- Internal registers
    signal data_reg_x, data_reg_y, data_reg_z : std_logic_vector(FP16_WIDTH-1 downto 0);
    signal weight_reg : std_logic_vector(FP16_WIDTH-1 downto 0);
    signal acc_reg : std_logic_vector(FP32_WIDTH-1 downto 0);
    
    -- Multiplication result (extended precision)
    signal mult_result : std_logic_vector(FP32_WIDTH-1 downto 0);
    signal mac_result : std_logic_vector(FP32_WIDTH-1 downto 0);
    
    -- Simple FP16 to FP32 conversion (simplified for demonstration)
    function fp16_to_fp32(fp16_val : std_logic_vector(15 downto 0)) 
                         return std_logic_vector is
        variable fp32_val : std_logic_vector(31 downto 0);
    begin
        -- Simplified conversion - in real implementation would need proper IEEE754 handling
        fp32_val := x"0000" & fp16_val;
        return fp32_val;
    end function;
    
    -- Multiply-accumulate operation
    function mac_operation(a, b, acc : std_logic_vector) return std_logic_vector is
        variable result : std_logic_vector(FP32_WIDTH-1 downto 0);
        variable mult_temp : signed(FP32_WIDTH-1 downto 0);
        variable acc_temp : signed(FP32_WIDTH-1 downto 0);
    begin
        -- Simplified MAC - in real implementation would use proper floating-point units
        mult_temp := signed(a(15 downto 0)) * signed(b(15 downto 0));
        acc_temp := signed(acc);
        result := std_logic_vector(mult_temp + acc_temp);
        return result;
    end function;
    
begin
    process (clk, rst)
    begin
        if rst = '1' then
            data_reg_x <= (others => '0');
            data_reg_y <= (others => '0');
            data_reg_z <= (others => '0');
            weight_reg <= (others => '0');
            acc_reg <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Register inputs for systolic flow
                data_reg_x <= data_in_x;
                data_reg_y <= data_in_y;
                data_reg_z <= data_in_z;
                weight_reg <= weight_in;
                
                -- Perform computation based on operation type
                case op_type is
                    when MATRIX_MUL | GEMM =>
                        -- Standard matrix multiplication: C = A * B + C
                        acc_reg <= mac_operation(
                            fp16_to_fp32(data_reg_x), 
                            fp16_to_fp32(weight_reg), 
                            acc_in
                        );
                        
                    when CONV_2D =>
                        -- 2D convolution operation
                        acc_reg <= mac_operation(
                            fp16_to_fp32(data_reg_x), 
                            fp16_to_fp32(weight_reg), 
                            acc_in
                        );
                        
                    when CONV_3D =>
                        -- 3D convolution using all three data dimensions
                        acc_reg <= mac_operation(
                            fp16_to_fp32(data_reg_x xor data_reg_y xor data_reg_z), 
                            fp16_to_fp32(weight_reg), 
                            acc_in
                        );
                        
                    when ATTENTION =>
                        -- Attention mechanism computation
                        acc_reg <= mac_operation(
                            fp16_to_fp32(data_reg_x), 
                            fp16_to_fp32(data_reg_y), 
                            acc_in
                        );
                        
                    when others =>
                        acc_reg <= acc_in;
                end case;
            end if;
        end if;
    end process;
    
    -- Output assignments (systolic data flow)
    data_out_x <= data_reg_x;
    data_out_y <= data_reg_y;
    data_out_z <= data_reg_z;
    acc_out <= acc_reg;
    
end architecture;
