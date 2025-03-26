-- clock_divider.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clock_divider is
    Port ( 
        clk_in  : in STD_LOGIC;
        clk_out : out STD_LOGIC
    );
end clock_divider;

architecture Behavioral of clock_divider is
    signal counter : unsigned(23 downto 0) := (others => '0');
    signal divided_clk : STD_LOGIC := '0';
begin
    process(clk_in)
    begin
        if rising_edge(clk_in) then
            -- Divide clock to create slower clock for Morse timing
            -- Adjust these values based on your specific FPGA clock frequency
            if counter = X"FFFFFF" then  -- Divide by 2^24
                counter <= (others => '0');
                divided_clk <= not divided_clk;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    clk_out <= divided_clk;
end Behavioral;
