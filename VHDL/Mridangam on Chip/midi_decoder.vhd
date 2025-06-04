-- MIDI Decoder Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity midi_decoder is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        midi_rx    : in  STD_LOGIC;
        note_on    : out STD_LOGIC;
        note_off   : out STD_LOGIC;
        note_num   : out STD_LOGIC_VECTOR(7 downto 0);
        velocity   : out STD_LOGIC_VECTOR(7 downto 0);
        valid      : out STD_LOGIC
    );
end midi_decoder;

architecture Behavioral of midi_decoder is
    constant BAUD_RATE : integer := 31250;  -- MIDI baud rate
    constant CLOCK_FREQ : integer := 100000000;
    constant BAUD_DIV : integer := CLOCK_FREQ / BAUD_RATE;
    
    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_type := IDLE;
    
    signal baud_counter : integer range 0 to BAUD_DIV := 0;
    signal bit_counter : integer range 0 to 7 := 0;
    signal rx_data : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_ready : STD_LOGIC := '0';
    
    -- MIDI message parsing
    type midi_state_type is (WAIT_STATUS, WAIT_NOTE, WAIT_VELOCITY);
    signal midi_state : midi_state_type := WAIT_STATUS;
    signal status_byte : STD_LOGIC_VECTOR(7 downto 0);
    signal note_byte : STD_LOGIC_VECTOR(7 downto 0);
    
begin

    -- UART receiver for MIDI
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            baud_counter <= 0;
            bit_counter <= 0;
            rx_ready <= '0';
        elsif rising_edge(clk) then
            rx_ready <= '0';
            
            case state is
                when IDLE =>
                    if midi_rx = '0' then  -- Start bit detected
                        state <= START_BIT;
                        baud_counter <= BAUD_DIV / 2;  -- Sample in middle
                    end if;
                    
                when START_BIT =>
                    if baud_counter = 0 then
                        if midi_rx = '0' then  -- Valid start bit
                            state <= DATA_BITS;
                            baud_counter <= BAUD_DIV;
                            bit_counter <= 0;
                        else
                            state <= IDLE;  -- False start
                        end if;
                    else
                        baud_counter <= baud_counter - 1;
                    end if;
                    
                when DATA_BITS =>
                    if baud_counter = 0 then
                        rx_data(bit_counter) <= midi_rx;
                        baud_counter <= BAUD_DIV;
                        
                        if bit_counter = 7 then
                            state <= STOP_BIT;
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                    else
                        baud_counter <= baud_counter - 1;
                    end if;
                    
                when STOP_BIT =>
                    if baud_counter = 0 then
                        if midi_rx = '1' then  -- Valid stop bit
                            rx_ready <= '1';
                        end if;
                        state <= IDLE;
                    else
                        baud_counter <= baud_counter - 1;
                    end if;
            end case;
        end if;
    end process;
    
    -- MIDI message parser
    process(clk, reset)
    begin
        if reset = '1' then
            midi_state <= WAIT_STATUS;
            note_on <= '0';
            note_off <= '0';
            valid <= '0';
        elsif rising_edge(clk) then
            note_on <= '0';
            note_off <= '0';
            valid <= '0';
            
            if rx_ready = '1' then
                case midi_state is
                    when WAIT_STATUS =>
                        if rx_data(7) = '1' then  -- Status byte
                            status_byte <= rx_data;
                            if rx_data(7 downto 4) = x"9" or rx_data(7 downto 4) = x"8" then
                                midi_state <= WAIT_NOTE;
                            end if;
                        end if;
                        
                    when WAIT_NOTE =>
                        note_byte <= rx_data;
                        midi_state <= WAIT_VELOCITY;
                        
                    when WAIT_VELOCITY =>
                        note_num <= note_byte;
                        velocity <= rx_data;
                        valid <= '1';
                        
                        if status_byte(7 downto 4) = x"9" and rx_data /= x"00" then
                            note_on <= '1';
                        else
                            note_off <= '1';
                        end if;
                        
                        midi_state <= WAIT_STATUS;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
