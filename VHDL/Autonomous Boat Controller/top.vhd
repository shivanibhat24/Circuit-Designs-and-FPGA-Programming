-- Top-level FPGA module integrating sonar with processor interface
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity boat_controller_fpga is
    Port (
        clk_50mhz     : in  STD_LOGIC;
        reset_n       : in  STD_LOGIC;
        
        -- Sonar sensors (Front-Left, Front-Right, Left, Right)
        sonar_trig    : out STD_LOGIC_VECTOR(3 downto 0);
        sonar_echo    : in  STD_LOGIC_VECTOR(3 downto 0);
        
        -- Motor control outputs
        motor_left_pwm  : out STD_LOGIC;
        motor_right_pwm : out STD_LOGIC;
        motor_left_dir  : out STD_LOGIC;
        motor_right_dir : out STD_LOGIC;
        
        -- Communication with soft-core processor
        avalon_address     : in  STD_LOGIC_VECTOR(7 downto 0);
        avalon_writedata   : in  STD_LOGIC_VECTOR(31 downto 0);
        avalon_readdata    : out STD_LOGIC_VECTOR(31 downto 0);
        avalon_write       : in  STD_LOGIC;
        avalon_read        : in  STD_LOGIC;
        
        -- Status LEDs
        led_status    : out STD_LOGIC_VECTOR(7 downto 0)
    );
end boat_controller_fpga;

architecture Behavioral of boat_controller_fpga is
    signal reset : STD_LOGIC;
    signal emergency_stop : STD_LOGIC;
    signal obstacle_flags : STD_LOGIC_VECTOR(3 downto 0);
    
    component sonar_controller
        Port (
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            sonar_trigger : out STD_LOGIC_VECTOR(3 downto 0);
            sonar_echo    : in  STD_LOGIC_VECTOR(3 downto 0);
            proc_addr     : in  STD_LOGIC_VECTOR(7 downto 0);
            proc_data_out : out STD_LOGIC_VECTOR(31 downto 0);
            proc_read     : in  STD_LOGIC;
            proc_write    : in  STD_LOGIC;
            proc_data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
            obstacle_detected : out STD_LOGIC_VECTOR(3 downto 0);
            emergency_stop    : out STD_LOGIC
        );
    end component;
    
begin
    reset <= not reset_n;
    
    -- Instantiate sonar controller
    sonar_inst : sonar_controller
        port map (
            clk => clk_50mhz,
            reset => reset,
            sonar_trigger => sonar_trig,
            sonar_echo => sonar_echo,
            proc_addr => avalon_address,
            proc_data_out => avalon_readdata,
            proc_read => avalon_read,
            proc_write => avalon_write,
            proc_data_in => avalon_writedata,
            obstacle_detected => obstacle_flags,
            emergency_stop => emergency_stop
        );
    
    -- Status LED mapping
    led_status(3 downto 0) <= obstacle_flags;
    led_status(4) <= emergency_stop;
    led_status(7 downto 5) <= "000";
    
    -- Emergency stop overrides motor control
    -- (Motor control will be handled by the soft-core processor)
    motor_left_pwm <= '0' when emergency_stop = '1' else 'Z';
    motor_right_pwm <= '0' when emergency_stop = '1' else 'Z';
    motor_left_dir <= '0' when emergency_stop = '1' else 'Z';
    motor_right_dir <= '0' when emergency_stop = '1' else 'Z';
    
end Behavioral;
