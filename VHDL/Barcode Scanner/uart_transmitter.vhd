library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_transmitter is
    Port ( 
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        data_in     : in STD_LOGIC_VECTOR(31 downto 0);
        valid_in    : in STD_LOGIC;
        tx_out      : out STD_LOGIC
    );
end uart_transmitter;

architecture Behavioral of uart_transmitter is
    type uart_state is (IDLE, START, TRANSMIT, STOP);
    signal current_state : uart_state := IDLE;
    signal shift_reg     : STD_LOGIC_VECTOR(31 downto 0);
    signal bit_cnt       : integer range 0 to 31 := 0;
    signal tx_reg        : STD_LOGIC := '1';

begin
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            tx_reg <= '1';
            bit_cnt <= 0;
        elsif rising_edge(clk) then
            case current_state is
                when IDLE =>
                    tx_reg <= '1';  -- Idle state is high
                    if valid_in = '1' then
                        current_state <= START;
                        shift_reg <= data_in;
                    end if;

                when START =>
                    tx_reg <= '0';  -- Start bit is low
                    current_state <= TRANSMIT;
                    bit_cnt <= 0;

                when TRANSMIT =>
                    -- Transmit least significant bit first
                    tx_reg <= shift_reg(0);
                    shift_reg <= '0' & shift_reg(31 downto 1);
                    bit_cnt <= bit_cnt + 1;

                    if bit_cnt = 31 then
                        current_state <= STOP;
                    end if;

                when STOP =>
                    tx_reg <= '1';  -- Stop bit is high
                    current_state <= IDLE;
            end case;
        end if;
    end process;

    -- Output assignment
    tx_out <= tx_reg;
end Behavioral;
