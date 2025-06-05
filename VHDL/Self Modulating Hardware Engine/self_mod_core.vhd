-- =========================================================================
-- SELF-MODULATING CORE MODULE
-- =========================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.self_mod_pkg.all;

entity self_mod_core is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        data_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        key_in       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        enable       : in  std_logic;
        random_seed  : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
        data_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_out    : out std_logic;
        debug_path   : out std_logic_vector(2 downto 0)
    );
end entity;

architecture behavioral of self_mod_core is
    -- Internal signals
    signal random_bits : std_logic_vector(LFSR_WIDTH-1 downto 0);
    signal path_enables : std_logic_vector(PATH_COUNT-1 downto 0);
    signal path_operations : op_array_t;
    signal active_path_idx : std_logic_vector(2 downto 0);
    signal path_outputs : path_array_t;
    signal path_valids : std_logic_vector(PATH_COUNT-1 downto 0);
    signal final_output : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal output_valid : std_logic;
    
    -- Dummy operation signals for timing obfuscation
    signal dummy_results : dummy_array_t;
    signal timing_offset : unsigned(3 downto 0);
    
begin
    -- Pseudo-random number generator
    prng_inst: entity work.prng_module
        port map (
            clk    => clk,
            rst    => rst,
            enable => enable,
            seed   => random_seed,
            random => random_bits
        );
    
    -- Path selector and obfuscation controller
    selector_inst: entity work.path_selector
        port map (
            clk         => clk,
            rst         => rst,
            random_bits => random_bits,
            enable      => enable,
            path_enable => path_enables,
            operations  => path_operations,
            active_path => active_path_idx
        );
    
    -- Generate multiple dynamic logic paths
    path_gen: for i in 0 to PATH_COUNT-1 generate
        path_inst: entity work.dynamic_path
            port map (
                clk       => clk,
                rst       => rst,
                data_in   => data_in,
                key_in    => key_in,
                operation => path_operations(i),
                enable    => path_enables(i),
                data_out  => path_outputs(i),
                valid_out => path_valids(i)
            );
    end generate;
    
    -- Output selection and timing obfuscation
    process(clk, rst)
        variable selected_idx : integer;
    begin
        if rst = '1' then
            final_output <= (others => '0');
            output_valid <= '0';
            timing_offset <= (others => '0');
            dummy_results <= (others => (others => '0'));
        elsif rising_edge(clk) then
            -- Update timing offset for additional obfuscation
            timing_offset <= timing_offset + unsigned(random_bits(3 downto 0));
            
            -- Generate dummy results to maintain consistent power consumption
            for i in 0 to DUMMY_OPS-1 loop
                dummy_results(i) <= std_logic_vector(
                    unsigned(data_in) xor unsigned(key_in) xor 
                    unsigned(random_bits) xor to_unsigned(i, DATA_WIDTH)
                );
            end loop;
            
            -- Select output from active path
            selected_idx := to_integer(unsigned(active_path_idx));
            if selected_idx < PATH_COUNT and path_valids(selected_idx) = '1' then
                final_output <= path_outputs(selected_idx);
                output_valid <= '1';
            else
                output_valid <= '0';
            end if;
        end if;
    end process;
    
    -- Output assignments
    data_out <= final_output;
    valid_out <= output_valid;
    debug_path <= active_path_idx;
    
end architecture;
