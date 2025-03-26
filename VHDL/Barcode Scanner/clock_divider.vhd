library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clock_divider is
    Port ( 
        clk_in     : in STD_LOGIC;
        reset      : in STD_LOGIC;
        clk_proc   : out STD_LOGIC;
        clk_uart   : out STD_LOGIC
    );
end clock_divider;

architecture Behavioral of clock_divider is
    signal cnt_proc : unsigned(3 downto 0) := (others => '0');
    signal cnt_uart : unsigned(3 downto 0) := (others => '0');
    signal clk_proc_int : STD_LOGIC := '0';
    signal clk_uart_int : STD_LOGIC := '0';

begin
    -- Process Clock Division (50 MHz)
    process(clk_in, reset)
    begin
        if reset = '1' then
            cnt_proc <= (others => '0');
            clk_proc_int <= '0';
        elsif rising_edge(clk_in) then
            if cnt_proc = "0011" then  -- Divide by 4 for 50 MHz
                cnt_proc <= (others => '0');
                clk_proc_int <= not clk_proc_int;
            else
                cnt_proc <= cnt_proc + 1;
            end if;
        end if;
    end process;

    -- UART Clock Division (9600 Baud)
    process(clk_in, reset)
    begin
        if reset = '1' then
            cnt_uart <= (others => '0');
            clk_uart_int <= '0';
        elsif rising_edge(clk_in) then
            if cnt_uart = "1001" then  -- Divide by 10 for UART clock
                cnt_uart <= (others => '0');
                clk_uart_int <= not clk_uart_int;
            else
                cnt_uart <= cnt_uart + 1;
            end if;
        end if;
    end process;

    -- Output assignments
    clk_proc <= clk_proc_int;
    clk_uart <= clk_uart_int;
end Behavioral;
