-- Pulse Timing Generator
-- Generates precise laser pulses and timing gates for ToF measurement

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lidar_pkg.all;

entity pulse_timing_generator is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        trigger         : in  std_logic;
        pulse_width     : in  std_logic_vector(15 downto 0);
        laser_pulse     : out std_logic;
        timing_gate     : out std_logic;
        pulse_complete  : out std_logic
    );
end pulse_timing_generator;

architecture rtl of pulse_timing_generator is
    type state_t is (IDLE, PULSE_ACTIVE, TIMING_WINDOW, COMPLETE);
    signal state : state_t := IDLE;
    
    signal pulse_counter : unsigned(15 downto 0) := (others => '0');
    signal timing_counter : unsigned(19 downto 0) := (others => '0');
    signal pulse_width_reg : unsigned(15 downto 0);
    
    -- Timing constants
    constant TIMING_WINDOW_MAX : unsigned(19 downto 0) := to_unsigned(1000000, 20); -- 10ms max
    constant MIN_PULSE_WIDTH : unsigned(15 downto 0) := to_unsigned(10, 16); -- 100ns min
    
begin
    pulse_width_reg <= unsigned(pulse_width) when unsigned(pulse_width) >= MIN_PULSE_WIDTH 
                       else MIN_PULSE_WIDTH;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                pulse_counter <= (others => '0');
                timing_counter <= (others => '0');
                laser_pulse <= '0';
                timing_gate <= '0';
                pulse_complete <= '0';
            else
                case state is
                    when IDLE =>
                        laser_pulse <= '0';
                        timing_gate <= '0';
                        pulse_complete <= '0';
                        pulse_counter <= (others => '0');
                        timing_counter <= (others => '0');
                        
                        if trigger = '1' then
                            state <= PULSE_ACTIVE;
                            laser_pulse <= '1';
                        end if;
                    
                    when PULSE_ACTIVE =>
                        if pulse_counter >= pulse_width_reg then
                            laser_pulse <= '0';
                            timing_gate <= '1';
                            state <= TIMING_WINDOW;
                            pulse_counter <= (others => '0');
                        else
                            pulse_counter <= pulse_counter + 1;
                        end if;
                    
                    when TIMING_WINDOW =>
                        -- Keep timing gate open for maximum range measurement
                        if timing_counter >= TIMING_WINDOW_MAX then
                            timing_gate <= '0';
                            state <= COMPLETE;
                        else
                            timing_counter <= timing_counter + 1;
                        end if;
                    
                    when COMPLETE =>
                        pulse_complete <= '1';
                        if trigger = '0' then
                            state <= IDLE;
                        end if;
                    
                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
    
end rtl;
