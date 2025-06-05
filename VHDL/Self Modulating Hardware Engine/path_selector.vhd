-- =========================================================================
-- PATH SELECTOR AND OBFUSCATION MODULE
-- =========================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.self_mod_pkg.all;

entity path_selector is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        random_bits   : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
        enable        : in  std_logic;
        path_enable   : out std_logic_vector(PATH_COUNT-1 downto 0);
        operations    : out op_array_t;
        active_path   : out std_logic_vector(2 downto 0)
    );
end entity;

architecture behavioral of path_selector is
    signal path_counter : unsigned(2 downto 0);
    signal obfusc_counter : unsigned(7 downto 0);
begin
    process(clk, rst)
        variable rand_ops : op_array_t;
        variable selected_path : integer;
    begin
        if rst = '1' then
            path_enable <= (others => '0');
            path_counter <= (others => '0');
            obfusc_counter <= (others => '0');
            active_path <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Update obfuscation counter
                obfusc_counter <= obfusc_counter + 1;
                
                -- Generate operations for all paths based on random bits
                for i in 0 to PATH_COUNT-1 loop
                    rand_ops(i) := select_operation(
                        random_bits((i*3+2) mod LFSR_WIDTH downto (i*3) mod LFSR_WIDTH)
                    );
                end loop;
                operations <= rand_ops;
                
                -- Select active path with obfuscation
                selected_path := to_integer(unsigned(random_bits(2 downto 0))) mod PATH_COUNT;
                active_path <= std_logic_vector(to_unsigned(selected_path, 3));
                
                -- Enable multiple paths for obfuscation (including dummy operations)
                path_enable <= (others => '0');
                for i in 0 to PATH_COUNT-1 loop
                    if (i = selected_path) or 
                       (obfusc_counter(1 downto 0) = to_unsigned(i mod 4, 2)) then
                        path_enable(i) <= '1';
                    end if;
                end loop;
                
                path_counter <= path_counter + 1;
            else
                path_enable <= (others => '0');
            end if;
        end if;
    end process;
end architecture;
