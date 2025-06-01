-- ==============================================================================
-- Tensor Core Top-Level Module
-- ==============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.tensor_core_pkg.all;

entity tensor_core_emulator is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- Host interface
        start_op        : in  std_logic;
        op_type         : in  tensor_op_type;
        precision_mode  : in  precision_type;
        
        -- Memory interface (simplified)
        mem_addr        : out std_logic_vector(31 downto 0);
        mem_data_in     : in  std_logic_vector(31 downto 0);
        mem_data_out    : out std_logic_vector(31 downto 0);
        mem_we          : out std_logic;
        mem_enable      : out std_logic;
        
        -- Status
        operation_done  : out std_logic;
        result_valid    : out std_logic
    );
end entity;

architecture top_level of tensor_core_emulator is
    -- Internal matrices
    signal matrix_a, matrix_c, result_matrix : pe_data_3d;
    signal matrix_b : pe_weight_3d;
    
    -- Control signals
    signal systolic_start, systolic_done : std_logic;
    signal load_state : integer range 0 to 3;
    
    component systolic_array_3d is
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            start         : in  std_logic;
            matrix_a      : in  pe_data_3d;
            matrix_b      : in  pe_weight_3d;
            matrix_c      : in  pe_data_3d;
            result_matrix : out pe_data_3d;
            op_type       : in  tensor_op_type;
            precision     : in  precision_type;
            done          : out std_logic
        );
    end component;
    
begin
    -- Instantiate 3D systolic array
    systolic_inst: systolic_array_3d
    port map (
        clk => clk,
        rst => rst,
        start => systolic_start,
        matrix_a => matrix_a,
        matrix_b => matrix_b,
        matrix_c => matrix_c,
        result_matrix => result_matrix,
        op_type => op_type,
        precision => precision_mode,
        done => systolic_done
    );
    
    -- Main control process
    process (clk, rst)
    begin
        if rst = '1' then
            load_state <= 0;
            systolic_start <= '0';
            operation_done <= '0';
            result_valid <= '0';
            mem_enable <= '0';
            mem_we <= '0';
        elsif rising_edge(clk) then
            case load_state is
                when 0 => -- Idle
                    if start_op = '1' then
                        load_state <= 1;
                        mem_enable <= '1';
                        -- Initialize matrices with simple test data
                        for i in 0 to ARRAY_SIZE_X-1 loop
                            for j in 0 to ARRAY_SIZE_Y-1 loop
                                for k in 0 to ARRAY_SIZE_Z-1 loop
                                    matrix_a(i, j, k) <= std_logic_vector(to_unsigned(i+j+k+1, FP32_WIDTH));
                                    matrix_b(i, j, k) <= std_logic_vector(to_unsigned(i*j+k+1, FP16_WIDTH));
                                    matrix_c(i, j, k) <= (others => '0');
                                end loop;
                            end loop;
                        end loop;
                    end if;
                    
                when 1 => -- Load complete, start computation
                    systolic_start <= '1';
                    load_state <= 2;
                    
                when 2 => -- Computing
                    systolic_start <= '0';
                    if systolic_done = '1' then
                        load_state <= 3;
                        result_valid <= '1';
                        operation_done <= '1';
                    end if;
                    
                when 3 => -- Done
                    if start_op = '0' then
                        load_state <= 0;
                        operation_done <= '0';
                        result_valid <= '0';
                        mem_enable <= '0';
                    end if;
            end case;
        end if;
    end process;
    
    -- Memory interface (simplified)
    mem_addr <= (others => '0');
    mem_data_out <= result_matrix(0, 0, 0);
    
end architecture;
