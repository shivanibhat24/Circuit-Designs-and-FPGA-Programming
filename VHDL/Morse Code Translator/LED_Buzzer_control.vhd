-- led_buzzer_control.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_buzzer_control is
    Port ( 
        clk             : in STD_LOGIC;
        reset           : in STD_LOGIC;
        morse_signal    : in STD_LOGIC;
        led_output      : out STD_LOGIC;
        buzzer_output   : out STD_LOGIC
    );
end led_buzzer_control;

architecture Behavioral of led_buzzer_control is
    signal timer : integer range 0 to 255 := 0;
begin
    process(clk, reset)
    begin
        if reset = '1' then
            led_output <= '0';
            buzzer_output <= '0';
            timer <= 0;
        elsif rising_edge(clk) then
            -- Synchronized LED and Buzzer control based on Morse signal
            if morse_signal = '1' then
                -- Light up LED and activate buzzer during Morse signal
                led_output <= '1';
                buzzer_output <= '1';
                
                -- Optional: Timer for signal duration control
                if timer < 255 then
                    timer <= timer + 1;
                end if;
            else
                -- Turn off LED and buzzer during gaps
                led_output <= '0';
                buzzer_output <= '0';
                timer <= 0;
            end if;
        end if;
    end process;
end Behavioral;
