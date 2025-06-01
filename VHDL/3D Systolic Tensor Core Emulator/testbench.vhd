-- ==============================================================================
-- Testbench for Tensor Core Emulator
-- ==============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.tensor_core_pkg.all;

entity tensor_core_tb is
end entity;

architecture testbench of tensor_core_tb is
    signal clk, rst : std_logic := '0';
    signal start_op : std_logic := '0';
    signal op_type : tensor_op_type := MATRIX_MUL;
    signal precision_mode : precision_type := FP16;
    signal operation_done, result_valid : std_logic;
    
    -- Memory interface signals
    signal mem_addr : std_logic_vector(31 downto 0);
    signal mem_data_in, mem_data_out : std_logic_vector(31 downto 0);
    signal mem_we, mem_enable : std_logic;
    
    component tensor_core_emulator is
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            start_op        : in  std_logic;
            op_type         : in  tensor_op_type;
            precision_mode  : in  precision_type;
            mem_addr        : out std_logic_vector(31 downto 0);
            mem_data_in     : in  std_logic_vector(31 downto 0);
            mem_data_out    : out std_logic_vector(31 downto 0);
            mem_we          : out std_logic;
            mem_enable      : out std_logic;
            operation_done  : out std_logic;
            result_valid    : out std_logic
        );
    end component;
    
begin
    -- Clock generation
    clk <= not clk after 5 ns;
    
    -- DUT instantiation
    dut: tensor_core_emulator
    port map (
        clk => clk,
        rst => rst,
        start_op => start_op,
        op_type => op_type,
        precision_mode => precision_mode,
        mem_addr => mem_addr,
        mem_data_in => mem_data_in,
        mem_data_out => mem_data_out,
        mem_we => mem_we,
        mem_enable => mem_enable,
        operation_done => operation_done,
        result_valid => result_valid
    );
    
    -- Test stimulus
    process
    begin
        -- Reset
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 20 ns;
        
        -- Test matrix multiplication
        op_type <= MATRIX_MUL;
        precision_mode <= FP16;
        start_op <= '1';
        wait for 10 ns;
        start_op <= '0';
        
        -- Wait for completion
        wait until operation_done = '1';
        wait for 50 ns;
        
        -- Test convolution operation
        op_type <= CONV_2D;
        precision_mode <= FP16;
        start_op <= '1';
        wait for 10 ns;
        start_op <= '0';
        
        wait until operation_done = '1';
        wait for 50 ns;
        
        -- Test 3D convolution
        op_type <= CONV_3D;
        start_op <= '1';
        wait for 10 ns;
        start_op <= '0';
        
        wait until operation_done = '1';
        wait for 100 ns;
        
        report "Tensor Core Emulation Tests Completed" severity note;
        wait;
    end process;
    
end architecture;
