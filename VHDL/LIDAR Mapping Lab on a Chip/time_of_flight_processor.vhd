-- Time-of-Flight Processor
-- Measures time between laser pulse and photodetector response

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lidar_pkg.all;

entity time_of_flight_processor is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        laser_pulse     : in  std_logic;
        photodetector   : in  std_logic;
        timing_gate     : in  std_logic;
        distance        : out std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
        measurement_valid : out std_logic;
        timeout_error   : out std_logic
    );
end time_of_flight_processor;

architecture rtl of time_of_flight_processor is
    type state_t is (IDLE, WAIT_PULSE, MEASURING, CALCULATE, VALID_OUTPUT);
    signal state : state_t := IDLE;
    
    signal time_counter : unsigned(19 downto 0) := (others => '0');
    signal pulse_start_time : unsigned(19 downto 0) := (others => '0');
    signal flight_time : unsigned(19 downto 0) := (others => '0');
    signal calculated_distance : unsigned(DEPTH_RESOLUTION-1 downto 0);
    
    signal photodetector_sync : std_logic_vector(2 downto 0) := (others => '0');
    signal photodetector_edge : std_logic;
    signal laser_pulse_sync : std_logic_vector(2 downto 0) := (others => '0');
    signal laser_pulse_edge : std_logic;
    
    -- Constants for distance calculation
    -- Distance = (time * speed_of_light) / 2
    -- For 100MHz clock: 1 tick = 10ns
    -- Speed of light ≈ 3e8 m/s = 3 m/10ns
    -- So distance_in_cm = (time_ticks * 1.5) or (time_ticks * 3/2)
    constant DISTANCE_SCALE : unsigned(7 downto 0) := to_unsigned(3, 8); -- Scale factor
    constant MAX_DISTANCE : unsigned(DEPTH_RESOLUTION-1 downto 0) := (others => '1');
    
begin
    -- Edge detection for photodetector
    photodetector_edge <= photodetector_sync(1) and not photodetector_sync(2);
    laser_pulse_edge <= laser_pulse_sync(1) and not laser_pulse_sync(2);
    
    -- Synchronize inputs
    process(clk)
    begin
        if rising_edge(clk) then
            photodetector_sync <= photodetector_sync(1 downto 0) & photodetector;
            laser_pulse_sync <= laser_pulse_sync(1 downto 0) & laser_pulse;
        end if;
    end process;
    
    -- Main ToF measurement process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                time_counter <= (others => '0');
                pulse_start_time <= (others => '0');
                flight_time <= (others => '0');
                calculated_distance <= (others => '0');
                measurement_valid <= '0';
                timeout_error <= '0';
            else
                case state is
                    when IDLE =>
                        measurement_valid <= '0';
                        timeout_error <= '0';
                        time_counter <= time_counter + 1;
                        
                        if timing_gate = '1' then
                            state <= WAIT_PULSE;
                        end if;
                    
                    when WAIT_PULSE =>
                        time_counter <= time_counter + 1;
                        
                        if laser_pulse_edge = '1' then
                            pulse_start_time <= time_counter;
                            state <= MEASURING;
                        elsif timing_gate = '0' then
                            state <= IDLE;
                        end if;
                    
                    when MEASURING =>
                        time_counter <= time_counter + 1;
                        
                        if photodetector_edge = '1' then
                            flight_time <= time_counter - pulse_start_time;
                            state <= CALCULATE;
                        elsif timing_gate = '0' then
                            -- Timeout occurred
                            timeout_error <= '1';
                            state <= IDLE;
                        end if;
                    
                    when CALCULATE =>
                        -- Calculate distance: (flight_time * 3) / 2 / 100 (for cm)
                        -- Simplified: flight_time * 3 >> 7 (divide by 128 ≈ divide by 200/2)
                        if flight_time > 0 then
                            calculated_distance <= resize((flight_time * DISTANCE_SCALE) srl 7, DEPTH_RESOLUTION);
                            if calculated_distance > MAX_DISTANCE then
                                calculated_distance <= MAX_DISTANCE;
                            end if;
                        else
                            calculated_distance <= (others => '0');
                        end if;
                        state <= VALID_OUTPUT;
                    
                    when VALID_OUTPUT =>
                        measurement_valid <= '1';
                        if timing_gate = '0' then
                            state <= IDLE;
                        end if;
                    
                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
    
    distance <= std_logic_vector(calculated_distance);
    
end rtl;
