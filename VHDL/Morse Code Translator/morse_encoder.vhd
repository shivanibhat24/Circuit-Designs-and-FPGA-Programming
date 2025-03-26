-- morse_encoder.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity morse_encoder is
    Port ( 
        clk             : in STD_LOGIC;
        reset           : in STD_LOGIC;
        char_in         : in STD_LOGIC_VECTOR(7 downto 0);
        morse_out       : out STD_LOGIC;
        encoding_done   : out STD_LOGIC
    );
end morse_encoder;

architecture Behavioral of morse_encoder is
    type morse_lookup_table is array (0 to 255) of STD_LOGIC_VECTOR(20 downto 0);
    
    constant MORSE_CODE : morse_lookup_table := (
        -- Mapping ASCII characters to Morse code
        -- Example mappings (would be complete in full implementation)
        X"41" => "001010100000000000000", -- 'A': .- 
        X"42" => "010101000000000000000", -- 'B': -...
        X"43" => "010101010000000000000", -- 'C': -.-.
        -- Add more character mappings
        others => (others => '0')
    );

    type state_type is (IDLE, START_BIT, DOT, DASH, ELEMENT_GAP, LETTER_GAP, DONE);
    signal current_state, next_state : state_type;
    
    signal char_morse_code : STD_LOGIC_VECTOR(20 downto 0);
    signal bit_counter     : integer range 0 to 20;
    signal timer           : integer range 0 to 7;  -- Base time unit counter

begin
    -- State transition process
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            bit_counter <= 0;
            timer <= 0;
        elsif rising_edge(clk) then
            current_state <= next_state;
            
            case current_state is
                when IDLE =>
                    bit_counter <= 0;
                    timer <= 0;
                
                when START_BIT =>
                    char_morse_code <= MORSE_CODE(to_integer(unsigned(char_in)));
                
                when DOT | DASH =>
                    if timer = 0 then
                        bit_counter <= bit_counter + 1;
                    end if;
                
                when ELEMENT_GAP | LETTER_GAP =>
                    if timer = 0 then
                        bit_counter <= bit_counter + 1;
                    end if;
                
                when DONE =>
                    bit_counter <= 0;
                
                when others => null;
            end case;
        end if;
    end process;

    -- Next state and output logic
    process(current_state, char_in, bit_counter, char_morse_code)
    begin
        case current_state is
            when IDLE =>
                morse_out <= '0';
                encoding_done <= '0';
                next_state <= START_BIT;
            
            when START_BIT =>
                morse_out <= '0';
                next_state <= DOT when char_morse_code(20) = '1' else
                              DASH when char_morse_code(20) = '0' else
                              DONE;
            
            when DOT =>
                morse_out <= '1';  -- 1 time unit
                next_state <= ELEMENT_GAP;
            
            when DASH =>
                morse_out <= '1';  -- 3 time units
                next_state <= ELEMENT_GAP;
            
            when ELEMENT_GAP =>
                morse_out <= '0';  -- 1 time unit gap
                next_state <= LETTER_GAP when bit_counter = 20 else
                              START_BIT;
            
            when LETTER_GAP =>
                morse_out <= '0';  -- 3 time units gap between letters
                next_state <= DONE;
            
            when DONE =>
                morse_out <= '0';
                encoding_done <= '1';
                next_state <= IDLE;
            
            when others =>
                morse_out <= '0';
                next_state <= IDLE;
        end case;
    end process;
end Behavioral;
