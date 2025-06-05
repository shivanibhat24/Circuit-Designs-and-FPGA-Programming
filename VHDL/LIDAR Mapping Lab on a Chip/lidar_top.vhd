-- LIDAR Lab-on-a-Chip Top Module
-- Integrates all LIDAR components with memory and processor interface

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lidar_pkg.all;

entity lidar_top is
    port (
        -- System clock and reset
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- External interfaces
        laser_driver    : out std_logic;
        photodetector   : in  std_logic;
        beam_ctrl_x     : out std_logic_vector(7 downto 0);
        beam_ctrl_y     : out std_logic_vector(7 downto 0);
        
        -- Processor interface (Avalon/AXI-like)
        cpu_addr        : in  std_logic_vector(31 downto 0);
        cpu_data_in     : in  std_logic_vector(31 downto 0);
        cpu_data_out    : out std_logic_vector(31 downto 0);
        cpu_we          : in  std_logic;
        cpu_re          : in  std_logic;
        cpu_cs          : in  std_logic;
        
        -- Status outputs
        scan_active     : out std_logic;
        measurement_ready : out std_logic;
        error_status    : out std_logic
    );
end lidar_top;

architecture rtl of lidar_top is
    -- Internal control and status signals
    signal lidar_ctrl : lidar_control_t;
    signal lidar_status : lidar_status_t;
    
    -- Beam steering signals
    signal beam_angle_x : std_logic_vector(7 downto 0);
    signal beam_angle_y : std_logic_vector(7 downto 0);
    signal scan_complete : std_logic;
    signal beam_valid : std_logic;
    
    -- Pulse timing signals
    signal laser_pulse : std_logic;
    signal timing_gate : std_logic;
    signal pulse_complete : std_logic;
    signal pulse_trigger : std_logic;
    
    -- Time-of-flight signals
    signal distance : std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
    signal measurement_valid : std_logic;
    signal timeout_error : std_logic;
    
    -- Depth map signals
    signal depth_map_addr : std_logic_vector(11 downto 0);
    signal depth_map_data : std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
    signal depth_map_we : std_logic;
    signal map_complete : std_logic;
    
    -- Memory interface signals
    signal mem_addr : std_logic_vector(11 downto 0);
    signal mem_data_out : std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
    signal mem_valid : std_logic;
    
    -- Memory array for depth map storage
    type depth_memory_t is array (0 to 4095) of std_logic_vector(DEPTH_RESOLUTION-1 downto 0);
    signal depth_memory : depth_memory_t := (others => (others => '0'));
    signal mem_read_addr : unsigned(11 downto 0);
    
begin
    -- Connect external outputs
    laser_driver <= laser_pulse;
    beam_ctrl_x <= beam_angle_x;
    beam_ctrl_y <= beam_angle_y;
    scan_active <= lidar_status.beam_active;
    measurement_ready <= lidar_status.measurement_valid;
    error_status <= lidar_status.error_flag;
    
    -- Trigger pulse generation when beam is valid
    pulse_trigger <= beam_valid and lidar_ctrl.beam_enable;
    
    -- Status signal aggregation
    lidar_status.scan_complete <= scan_complete;
    lidar_status.beam_active <= beam_valid;
    lidar_status.current_angle <= beam_angle_x; -- Use X angle as primary
    lidar_status.measurement_valid <= measurement_valid;
    lidar_status.error_flag <= timeout_error;
    
    -- Beam Steering Controller
    beam_steering_inst : beam_steering_controller
        port map (
            clk => clk,
            rst => rst,
            start_scan => lidar_ctrl.start_scan,
            angle_step => x"04", -- 4-degree steps
            scan_rate => lidar_ctrl.scan_rate,
            beam_angle_x => beam_angle_x,
            beam_angle_y => beam_angle_y,
            scan_complete => scan_complete,
            beam_valid => beam_valid
        );
    
    -- Pulse Timing Generator
    pulse_timing_inst : pulse_timing_generator
        port map (
            clk => clk,
            rst => rst,
            trigger => pulse_trigger,
            pulse_width => lidar_ctrl.pulse_width,
            laser_pulse => laser_pulse,
            timing_gate => timing_gate,
            pulse_complete => pulse_complete
        );
    
    -- Time-of-Flight Processor
    tof_processor_inst : time_of_flight_processor
        port map (
            clk => clk,
            rst => rst,
            laser_pulse => laser_pulse,
            photodetector => photodetector,
            timing_gate => timing_gate,
            distance => distance,
            measurement_valid => measurement_valid,
            timeout_error => timeout_error
        );
    
    -- Depth Map Generator
    depth_map_inst : depth_map_generator
        port map (
            clk => clk,
            rst => rst,
            beam_angle_x => beam_angle_x,
            beam_angle_y => beam_angle_y,
            distance => distance,
            measurement_valid => measurement_valid,
            depth_map_addr => depth_map_addr,
            depth_map_data => depth_map_data,
            depth_map_we => depth_map_we,
            map_complete => map_complete
        );
    
    -- Soft Processor Interface
    processor_interface_inst : soft_processor_interface
        port map (
            clk => clk,
            rst => rst,
            addr => cpu_addr,
            data_in => cpu_data_in,
            data_out => cpu_data_out,
            we => cpu_we,
            re => cpu_re,
            cs => cpu_cs,
            lidar_ctrl => lidar_ctrl,
            lidar_status => lidar_status,
            mem_addr => mem_addr,
            mem_data => mem_data_out,
            mem_valid => mem_valid
        );
    
    -- Depth Map Memory
    mem_read_addr <= unsigned(mem_addr);
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                depth_memory <= (others => (others => '0'));
                mem_data_out <= (others => '0');
                mem_valid <= '0';
            else
                -- Write to memory
                if depth_map_we = '1' then
                    depth_memory(to_integer(unsigned(depth_map_addr))) <= depth_map_data;
                end if;
                
                -- Read from memory
                mem_data_out <= depth_memory(to_integer(mem_read_addr));
                mem_valid <= '1'; -- Always valid for this simple implementation
            end if;
        end if;
    end process;
    
end rtl;
