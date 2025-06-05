-- LIDAR Lab-on-a-Chip Package
-- Defines constants, types, and component declarations

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package lidar_pkg is
    -- System constants
    constant CLK_FREQ           : integer := 100_000_000; -- 100 MHz
    constant LASER_PULSE_WIDTH  : integer := 100;         -- 1 us at 100MHz
    constant MAX_RANGE_TICKS    : integer := 1_000_000;   -- 10ms max range
    constant BEAM_ANGLES        : integer := 64;          -- 64 beam positions
    constant DEPTH_RESOLUTION   : integer := 12;          -- 12-bit depth
    constant ANGLE_RESOLUTION   : integer := 8;           -- 8-bit angle
    
    -- Data types
    type depth_array_t is array (0 to BEAM_ANGLES-1) of std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
    type angle_array_t is array (0 to BEAM_ANGLES-1) of std_logic_vector(ANGLE_RESOLUTION-1 downto 0);
    
    -- Control signals type
    type lidar_control_t is record
        start_scan      : std_logic;
        reset_scan      : std_logic;
        beam_enable     : std_logic;
        auto_mode       : std_logic;
        pulse_width     : std_logic_vector(15 downto 0);
        scan_rate       : std_logic_vector(15 downto 0);
    end record;
    
    -- Status signals type
    type lidar_status_t is record
        scan_complete   : std_logic;
        beam_active     : std_logic;
        current_angle   : std_logic_vector(ANGLE_RESOLUTION-1 downto 0);
        measurement_valid : std_logic;
        error_flag      : std_logic;
    end record;
    
    -- Component declarations
    component beam_steering_controller is
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            start_scan      : in  std_logic;
            angle_step      : in  std_logic_vector(7 downto 0);
            scan_rate       : in  std_logic_vector(15 downto 0);
            beam_angle_x    : out std_logic_vector(7 downto 0);
            beam_angle_y    : out std_logic_vector(7 downto 0);
            scan_complete   : out std_logic;
            beam_valid      : out std_logic
        );
    end component;
    
    component pulse_timing_generator is
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            trigger         : in  std_logic;
            pulse_width     : in  std_logic_vector(15 downto 0);
            laser_pulse     : out std_logic;
            timing_gate     : out std_logic;
            pulse_complete  : out std_logic
        );
    end component;
    
    component time_of_flight_processor is
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
    end component;
    
    component depth_map_generator is
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            beam_angle_x    : in  std_logic_vector(7 downto 0);
            beam_angle_y    : in  std_logic_vector(7 downto 0);
            distance        : in  std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
            measurement_valid : in  std_logic;
            depth_map_addr  : out std_logic_vector(11 downto 0);
            depth_map_data  : out std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
            depth_map_we    : out std_logic;
            map_complete    : out std_logic
        );
    end component;
    
    component soft_processor_interface is
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            -- Processor bus interface
            addr            : in  std_logic_vector(31 downto 0);
            data_in         : in  std_logic_vector(31 downto 0);
            data_out        : out std_logic_vector(31 downto 0);
            we              : in  std_logic;
            re              : in  std_logic;
            cs              : in  std_logic;
            -- LIDAR control interface
            lidar_ctrl      : out lidar_control_t;
            lidar_status    : in  lidar_status_t;
            -- Memory interface for depth map
            mem_addr        : out std_logic_vector(11 downto 0);
            mem_data        : in  std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
            mem_valid       : in  std_logic
        );
    end component;

end package lidar_pkg;
