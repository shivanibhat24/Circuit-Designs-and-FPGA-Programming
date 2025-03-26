-- fsm_controller.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fsm_controller is
    Port ( 
        clk             : in STD_LOGIC;
        reset           : in STD_LOGIC;
        uart_data       : in STD_LOGIC_VECTOR(7 downto 0);
        uart_valid      : in STD_LOGIC;
        morse_encoded   : in STD_LOGIC;
        morse_decoded   : in STD_LOGIC_VECTOR(7 downto 0);
        led_control     : out STD_LOGIC;
        buzzer_control  : out STD_LOGIC
    );
end fsm_controller;

architecture Behavioral of fsm_controller is
    type state_type is (
        IDLE, 
        RECEIVE_DATA, 
        ENCODING_START, 
        ENCODING_IN_PROGRESS, 
        DECODING_START, 
        DECODING_IN_PROGRESS, 
        OUTPUT_RESULT
    );
    
    signal current_state, next_state : state_type;
    signal timer : integer range 0 to 255;

begin
    -- State transition process
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            timer <= 0;
        elsif rising_edge(clk) then
            current_state <= next_state;
            
            case current_state is
                when IDLE =>
                    timer <= 0;
                
                when ENCODING_IN_PROGRESS | DECODING_IN_PROGRESS =>
                    if timer < 255 then
                        timer <= timer + 1;
                    end if;
                
                when others => null;
            end case;
        end if;
    end process;

    -- Next state and output logic
    process(current_state, uart_valid, morse_encoded, uart_data, morse_decoded)
    begin
        case current_state is
            when IDLE =>
                led_control <= '0';
                buzzer_control <= '0';
                
                if uart_valid = '1' then
                    next_state <= RECEIVE_DATA;
                else
                    next_state <= IDLE;
                end if;
            
            when RECEIVE_DATA =>
                -- Decide whether to encode or decode based on input
                if uart_data /= X"00" then
                    next_state <= ENCODING_START;
                else
                    next_state <= DECODING_START;
                end if;
            
            when ENCODING_START =>
                led_control <= '1';  -- Indicate encoding process
                next_state <= ENCODING_IN_PROGRESS;
            
            when ENCODING_IN_PROGRESS =>
                if morse_encoded = '1' then
                    next_state <= OUTPUT_RESULT;
                else
                    next_state <= ENCODING_IN_PROGRESS;
                end if;
            
            when DECODING_START =>
                led_control <= '1';  -- Indicate decoding process
                next_state <= DECODING_IN_PROGRESS;
            
            when DECODING_IN_PROGRESS =>
                if morse_decoded /= X"00" then
                    next_state <= OUTPUT_RESULT;
                else
                    next_state <= DECODING_IN_PROGRESS;
                end if;
            
            when OUTPUT_RESULT =>
                buzzer_control <= '1';  -- Signal output completion
                next_state <= IDLE;
            
            when others =>
                next_state <= IDLE;
        end case;
    end process;
end Behavioral;
