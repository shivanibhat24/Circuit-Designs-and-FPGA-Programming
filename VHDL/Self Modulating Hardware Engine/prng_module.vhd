-- =========================================================================
-- PSEUDO-RANDOM NUMBER GENERATOR MODULE
-- =========================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.self_mod_pkg.all;

entity prng_module is
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        enable  : in  std_logic;
        seed    : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
        random  : out std_logic_vector(LFSR_WIDTH-1 downto 0)
    );
end entity;

architecture behavioral of prng_module is
    signal lfsr_reg : std_logic_vector(LFSR_WIDTH-1 downto 0);
begin
    process(clk, rst)
    begin
        if rst = '1' then
            lfsr_reg <= seed when seed /= (seed'range => '0') else x"ABCD";
        elsif rising_edge(clk) then
            if enable = '1' then
                lfsr_reg <= lfsr_next(lfsr_reg);
            end if;
        end if;
    end process;
    
    random <= lfsr_reg;
end architecture;
