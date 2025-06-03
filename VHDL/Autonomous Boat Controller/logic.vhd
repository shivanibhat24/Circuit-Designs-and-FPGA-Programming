-- Autonomous Boat Controller - FPGA Sonar Processing Module
-- Handles ultrasonic sonar data processing for obstacle detection

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sonar_controller is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        
        -- Sonar interface
        sonar_trigger : out STD_LOGIC_VECTOR(3 downto 0); -- 4 sonar sensors
        sonar_echo    : in  STD_LOGIC_VECTOR(3 downto 0);
        
        -- Processor interface
        proc_addr     : in  STD_LOGIC_VECTOR(7 downto 0);
        proc_data_out : out STD_LOGIC_VECTOR(31 downto 0);
        proc_read     : in  STD_LOGIC;
        proc_write    : in  STD_LOGIC;
        proc_data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
        
        -- Status outputs
        obstacle_detected : out STD_LOGIC_VECTOR(3 downto 0);
        emergency_stop    : out STD_LOGIC
    );
end sonar_controller;

architecture Behavioral of sonar_controller is
    -- Constants
    constant TRIGGER_WIDTH : integer := 500;    -- 10us at 50MHz
    constant MAX_DISTANCE  : integer := 250000; -- 5ms max echo time
    constant MIN_DISTANCE  : integer := 1000;   -- 20us min distance (safe threshold)
    
    -- Internal signals
    type state_type is (IDLE, TRIGGER, WAIT_ECHO, CALCULATE);
    signal state : state_type := IDLE;
    
    signal trigger_counter : integer range 0 to TRIGGER_WIDTH := 0;
    signal echo_counter    : integer range 0 to MAX_DISTANCE := 0;
    signal sensor_select   : integer range 0 to 3 := 0;
    
    -- Distance measurements (in clock cycles)
    type distance_array is array (0 to 3) of integer range 0 to MAX_DISTANCE;
    signal distances : distance_array := (others => MAX_DISTANCE);
    
    -- Register map
    signal reg_distances   : STD_LOGIC_VECTOR(127 downto 0); -- 4x32-bit distances
    signal reg_status      : STD_LOGIC_VECTOR(31 downto 0);
    signal reg_control     : STD_LOGIC_VECTOR(31 downto 0);
    
    signal scan_enable     : STD_LOGIC := '1';
    signal threshold       : integer range 0 to MAX_DISTANCE := 50000; -- 1ms default
    
begin
    -- Main sonar scanning process
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            trigger_counter <= 0;
            echo_counter <= 0;
            sensor_select <= 0;
            distances <= (others => MAX_DISTANCE);
            sonar_trigger <= (others => '0');
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    sonar_trigger <= (others => '0');
                    if scan_enable = '1' then
                        state <= TRIGGER;
                        trigger_counter <= 0;
                    end if;
                
                when TRIGGER =>
                    sonar_trigger(sensor_select) <= '1';
                    trigger_counter <= trigger_counter + 1;
                    if trigger_counter >= TRIGGER_WIDTH then
                        sonar_trigger(sensor_select) <= '0';
                        state <= WAIT_ECHO;
                        echo_counter <= 0;
                    end if;
                
                when WAIT_ECHO =>
                    if sonar_echo(sensor_select) = '1' then
                        state <= CALCULATE;
                    elsif echo_counter >= MAX_DISTANCE then
                        distances(sensor_select) <= MAX_DISTANCE;
                        state <= CALCULATE;
                    else
                        echo_counter <= echo_counter + 1;
                    end if;
                
                when CALCULATE =>
                    if sonar_echo(sensor_select) = '0' then
                        distances(sensor_select) <= echo_counter;
                    end if;
                    
                    -- Move to next sensor
                    if sensor_select = 3 then
                        sensor_select <= 0;
                        state <= IDLE;
                    else
                        sensor_select <= sensor_select + 1;
                        state <= TRIGGER;
                        trigger_counter <= 0;
                    end if;
            end case;
        end if;
    end process;
    
    -- Obstacle detection logic
    process(clk)
    begin
        if rising_edge(clk) then
            for i in 0 to 3 loop
                if distances(i) < threshold and distances(i) > MIN_DISTANCE then
                    obstacle_detected(i) <= '1';
                else
                    obstacle_detected(i) <= '0';
                end if;
            end loop;
            
            -- Emergency stop if front sensors detect close obstacles
            if (distances(0) < MIN_DISTANCE or distances(1) < MIN_DISTANCE) then
                emergency_stop <= '1';
            else
                emergency_stop <= '0';
            end if;
        end if;
    end process;
    
    -- Register interface for processor communication
    process(clk, reset)
    begin
        if reset = '1' then
            reg_control <= (others => '0');
            reg_control(0) <= '1'; -- scan_enable default
            
        elsif rising_edge(clk) then
            -- Update distance registers
            for i in 0 to 3 loop
                reg_distances(32*i+31 downto 32*i) <= std_logic_vector(to_unsigned(distances(i), 32));
            end loop;
            
            -- Update status register
            reg_status(3 downto 0) <= obstacle_detected;
            reg_status(4) <= emergency_stop;
            reg_status(7 downto 5) <= std_logic_vector(to_unsigned(sensor_select, 3));
            reg_status(31 downto 8) <= (others => '0');
            
            -- Handle processor writes
            if proc_write = '1' then
                case to_integer(unsigned(proc_addr)) is
                    when 16#10# => -- Control register
                        reg_control <= proc_data_in;
                        scan_enable <= proc_data_in(0);
                        threshold <= to_integer(unsigned(proc_data_in(31 downto 16)));
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
    
    -- Processor read multiplexer
    process(proc_addr, reg_distances, reg_status, reg_control)
    begin
        case to_integer(unsigned(proc_addr)) is
            when 16#00# => proc_data_out <= reg_distances(31 downto 0);   -- Distance 0
            when 16#04# => proc_data_out <= reg_distances(63 downto 32);  -- Distance 1
            when 16#08# => proc_data_out <= reg_distances(95 downto 64);  -- Distance 2
            when 16#0C# => proc_data_out <= reg_distances(127 downto 96); -- Distance 3
            when 16#10# => proc_data_out <= reg_control;                  -- Control
            when 16#14# => proc_data_out <= reg_status;                   -- Status
            when others => proc_data_out <= (others => '0');
        end case;
    end process;

end Behavioral;
