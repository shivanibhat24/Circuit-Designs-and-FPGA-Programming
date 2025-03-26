-- uart_rx.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    Generic (
        CLOCK_FREQ     : integer := 100_000_000;  -- 100 MHz
        BAUD_RATE      : integer := 9600
    );
    Port ( 
        clk     : in STD_LOGIC;
        rx      : in STD_LOGIC;
        data    : out STD_LOGIC_VECTOR(7 downto 0);
        valid   : out STD_LOGIC
    );
end uart_rx;

architecture Behavioral of uart_rx is
    type rx_state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    
    signal current_state : rx_state_type := IDLE;
    signal bit_counter   : integer range 0 to 7 := 0;
    signal baud_counter  : integer range 0 to (CLOCK_FREQ/BAUD_RATE) := 0;
    signal shift_reg     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal sample_point  : STD_LOGIC := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            case current_state is
                when IDLE =>
                    valid <= '0';
                    
                    -- Detect start bit (falling edge)
                    if rx = '0' then
                        current_state <= START_BIT;
                        baud_counter <= 0;
                        bit_counter <= 0;
                    end if;
                
                when START_BIT =>
                    -- Sample at middle of bit period
                    if baud_counter = (CLOCK_FREQ/BAUD_RATE)/2 then
                        if rx = '0' then
                            baud_counter <= 0;
                            current_state <= DATA_BITS;
                        else
                            current_state <= IDLE;
                        end if;
                    else
                        baud_counter <= baud_counter + 1;
                    end if;
                
                when DATA_BITS =>
                    -- Sample at middle of bit period
                    if baud_counter = (CLOCK_FREQ/BAUD_RATE) - 1 then
                        shift_reg <= rx & shift_reg(7 downto 1);
                        baud_counter <= 0;
                        
                        if bit_counter = 7 then
                            current_state <= STOP_BIT;
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                    else
                        baud_counter <= baud_counter + 1;
                    end if;
                
                when STOP_BIT =>
                    -- Wait for stop bit
                    if baud_counter = (CLOCK_FREQ/BAUD_RATE) - 1 then
                        if rx = '1' then
                            data <= shift_reg;
                            valid <= '1';
                        end if;
                        current_state <= IDLE;
                    else
                        baud_counter <= baud_counter + 1;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;
