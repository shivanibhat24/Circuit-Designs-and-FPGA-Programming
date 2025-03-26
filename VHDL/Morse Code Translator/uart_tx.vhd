-- uart_tx.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    Generic (
        CLOCK_FREQ     : integer := 100_000_000;  -- 100 MHz
        BAUD_RATE      : integer := 9600
    );
    Port ( 
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        data_in     : in STD_LOGIC_VECTOR(7 downto 0);
        data_valid  : in STD_LOGIC;
        tx          : out STD_LOGIC;
        tx_done     : out STD_LOGIC
    );
end uart_tx;

architecture Behavioral of uart_tx is
    type tx_state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    
    signal current_state : tx_state_type := IDLE;
    signal bit_counter   : integer range 0 to 7 := 0;
    signal baud_counter  : integer range 0 to (CLOCK_FREQ/BAUD_RATE) := 0;
    signal shift_reg     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
begin
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            tx <= '1';  -- Idle state is high
            tx_done <= '0';
            bit_counter <= 0;
            baud_counter <= 0;
        elsif rising_edge(clk) then
            case current_state is
                when IDLE =>
                    tx <= '1';  -- Keep line high
                    tx_done <= '0';
                    
                    if data_valid = '1' then
                        shift_reg <= data_in;
                        current_state <= START_BIT;
                    end if;
                
                when START_BIT =>
                    if baud_counter = (CLOCK_FREQ/BAUD_RATE) - 1 then
                        tx <= '0';  -- Send start bit (low)
                        baud_counter <= 0;
                        current_state <= DATA_BITS;
                    else
                        baud_counter <= baud_counter + 1;
                    end if;
                
                when DATA_BITS =>
                    if baud_counter = (CLOCK_FREQ/BAUD_RATE) - 1 then
                        tx <= shift_reg(0);  -- Send least significant bit first
                        shift_reg <= '0' & shift_reg(7 downto 1);
                        baud_counter <= 0;
                        
                        if bit_counter = 7 then
                            bit_counter <= 0;
                            current_state <= STOP_BIT;
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                    else
                        baud_counter <= baud_counter + 1;
                    end if;
                
                when STOP_BIT =>
                    if baud_counter = (CLOCK_FREQ/BAUD_RATE) - 1 then
                        tx <= '1';  -- Send stop bit (high)
                        tx_done <= '1';
                        current_state <= IDLE;
                    else
                        baud_counter <= baud_counter + 1;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;
