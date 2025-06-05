-- =========================================================================
-- TESTBENCH (Optional - for simulation)
-- =========================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.self_mod_pkg.all;

entity tb_self_modulating_engine is
end entity;

architecture behavioral of tb_self_modulating_engine is
    -- Testbench signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal data_in : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal key_in : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal data_out : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal enable : std_logic := '0';
    signal valid_out : std_logic;
    signal ready : std_logic;
    signal config_seed : std_logic_vector(LFSR_WIDTH-1 downto 0);
    signal reconfig : std_logic := '0';
    signal debug_path : std_logic_vector(2 downto 0);
    signal debug_random : std_logic_vector(LFSR_WIDTH-1 downto 0);
    
    constant CLK_PERIOD : time := 10 ns;
    
begin
    -- Clock generation
    clk <= not clk after CLK_PERIOD/2;
    
    -- DUT instantiation
    dut: entity work.self_modulating_engine
        port map (
            clk => clk,
            rst => rst,
            data_in => data_in,
            key_in => key_in,
            data_out => data_out,
            enable => enable,
            valid_out => valid_out,
            ready => ready,
            config_seed => config_seed,
            reconfig => reconfig,
            debug_active_path => debug_path,
            debug_random => debug_random
        );
    
    -- Stimulus process
    stimulus: process
    begin
        -- Initialize
        rst <= '1';
        data_in <= x"12345678";
        key_in <= x"ABCDEF00";
        config_seed <= x"DEAD";
        wait for 100 ns;
        
        -- Release reset
        rst <= '0';
        wait until ready = '1';
        wait for CLK_PERIOD * 10;
        
        -- Test operations
        enable <= '1';
        for i in 0 to 15 loop
            data_in <= std_logic_vector(to_unsigned(i * 12345, DATA_WIDTH));
            key_in <= std_logic_vector(to_unsigned(i * 67890, DATA_WIDTH));
            wait for CLK_PERIOD * 5;
        end loop;
        
        -- Test reconfiguration
        reconfig <= '1';
        config_seed <= x"BEEF";
        wait for CLK_PERIOD;
        reconfig <= '0';
        wait until ready = '1';
        
        -- Continue testing with new configuration
        for i in 0 to 10 loop
            data_in <= std_logic_vector(to_unsigned(i * 11111, DATA_WIDTH));
            key_in <= std_logic_vector(to_unsigned(i * 22222, DATA_WIDTH));
            wait for CLK_PERIOD * 3;
        end loop;
        
        enable <= '0';
        wait for CLK_PERIOD * 10;
        
        report "Testbench completed successfully";
        wait;
    end process;
    
end architecture;
