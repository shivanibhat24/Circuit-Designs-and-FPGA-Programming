-- =========================================================================
-- TOP-LEVEL MODULE
-- =========================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.self_mod_pkg.all;

entity self_modulating_engine is
    port (
        -- Clock and reset
        clk           : in  std_logic;
        rst           : in  std_logic;
        
        -- Data interface
        data_in       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        key_in        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_out      : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Control interface
        enable        : in  std_logic;
        valid_out     : out std_logic;
        ready         : out std_logic;
        
        -- Configuration interface
        config_seed   : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
        reconfig      : in  std_logic;
        
        -- Debug interface (can be removed in production)
        debug_active_path : out std_logic_vector(2 downto 0);
        debug_random      : out std_logic_vector(LFSR_WIDTH-1 downto 0)
    );
end entity;

architecture structural of self_modulating_engine is
    -- Internal signals
    signal core_enable : std_logic;
    signal core_valid : std_logic;
    signal core_data_out : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal random_debug : std_logic_vector(LFSR_WIDTH-1 downto 0);
    signal system_ready : std_logic;
    signal reset_counter : unsigned(7 downto 0);
    
    -- Configuration and state management
    signal current_seed : std_logic_vector(LFSR_WIDTH-1 downto 0);
    signal reconfig_reg : std_logic;
    signal reconfig_pulse : std_logic;
    
begin
    -- Reset and initialization logic
    process(clk, rst)
    begin
        if rst = '1' then
            reset_counter <= (others => '0');
            system_ready <= '0';
            current_seed <= x"1234"; -- Default seed
            reconfig_reg <= '0';
        elsif rising_edge(clk) then
            -- System ready after reset stabilization
            if reset_counter < 255 then
                reset_counter <= reset_counter + 1;
                system_ready <= '0';
            else
                system_ready <= '1';
            end if;
            
            -- Handle reconfiguration
            reconfig_reg <= reconfig;
            if reconfig = '1' and reconfig_reg = '0' then
                current_seed <= config_seed;
                reset_counter <= (others => '0');
                system_ready <= '0';
            end if;
        end if;
    end process;
    
    reconfig_pulse <= reconfig and not reconfig_reg;
    core_enable <= enable and system_ready;
    
    -- Main self-modulating core
    core_inst: entity work.self_mod_core
        port map (
            clk         => clk,
            rst         => rst or reconfig_pulse,
            data_in     => data_in,
            key_in      => key_in,
            enable      => core_enable,
            random_seed => current_seed,
            data_out    => core_data_out,
            valid_out   => core_valid,
            debug_path  => debug_active_path
        );
    
    -- Debug random signal tap (remove in production)
    debug_random_inst: entity work.prng_module
        port map (
            clk    => clk,
            rst    => rst,
            enable => '1',
            seed   => current_seed,
            random => random_debug
        );
    
    -- Output assignments
    data_out <= core_data_out;
    valid_out <= core_valid;
    ready <= system_ready;
    debug_random <= random_debug;
    
end architecture;
