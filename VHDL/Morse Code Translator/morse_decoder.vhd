-- morse_decoder.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity morse_decoder is
    Port ( 
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        morse_in    : in STD_LOGIC;
        char_out    : out STD_LOGIC_VECTOR(7 downto 0);
        valid       : out STD_LOGIC
    );
end morse_decoder;

architecture Behavioral of morse_decoder is
    type state_type is (IDLE, DETECT_PULSE, MEASURE_PULSE, PROCESS_CODE);
    signal current_state, next_state : state_type;
    
    -- Morse code signal detection variables
    signal pulse_duration : integer range 0 to 7 := 0;
    signal current_morse_code : STD_LOGIC_VECTOR(4 downto 0);
    signal morse_bit_count : integer range 0 to 5;
    
    -- Decoding lookup table (reverse of encoder)
    type morse_decode_table is array (0 to 31) of STD_LOGIC_VECTOR(7 downto 0);
    constant MORSE_DECODE : morse_decode_table := (
        -- Example mappings (binary Morse pattern to ASCII)
        "00001" => X"41",  -- .- : A
        "00010" => X"42",  -- -...: B
        "00011" => X"43",  -- -.-.: C
        -- Add more decode mappings
        others => X"00"
    );

begin
    -- State transition process
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            pulse_duration <= 0;
            current_morse_code <= (others => '0');
            morse_bit_count <= 0;
        elsif rising_edge(clk) then
            current_state <= next_state;
            
            case current_state is
                when IDLE =>
                    pulse_duration <= 0;
                    current_morse_code <= (others => '0');
                    morse_bit_count <= 0;
                
                when DETECT_PULSE =>
                    if morse_in = '1' then
                        pulse_duration <= pulse_duration + 1;
                    end if;
                
                when MEASURE_PULSE =>
                    -- Classify pulse as dot or dash
                    if pulse_duration <= 2 then  -- Dot (1-2 time units)
                        current_morse_code <= current_morse_code(3 downto 0) & '0';
                    elsif pulse_duration > 2 then  -- Dash (3 time units)
                        current_morse_code <= current_morse_code(3 downto 0) & '1';
                    end if;
                    morse_bit_count <= morse_bit_count + 1;
                
                when PROCESS_CODE =>
                    -- Reset for next character
                    current_morse_code <= (others => '0');
                    morse_bit_count <= 0;
                
                when others => null;
            end case;
        end if;
    end process;

    -- Next state and output logic
    process(current_state, morse_in, pulse_duration, morse_bit_count)
    begin
        case current_state is
            when IDLE =>
                char_out <= (others => '0');
                valid <= '0';
                next_state <= DETECT_PULSE when morse_in = '1' else IDLE;
            
            when DETECT_PULSE =>
                if morse_in = '0' then  -- Pulse ended
                    next_state <= MEASURE_PULSE;
                else
                    next_state <= DETECT_PULSE;
                end if;
            
            when MEASURE_PULSE =>
                if morse_bit_count = 4 then  -- Completed a character
                    char_out <= MORSE_DECODE(to_integer(unsigned(current_morse_code)));
                    valid <= '1';
                    next_state <= PROCESS_CODE;
                else
                    next_state <= IDLE;
                end if;
            
            when PROCESS_CODE =>
                valid <= '0';
                next_state <= IDLE;
            
            when others =>
                next_state <= IDLE;
        end case;
    end process;
end Behavioral;
