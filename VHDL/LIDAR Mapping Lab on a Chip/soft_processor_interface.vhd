-- Soft Processor Interface
-- Provides register-mapped interface for CPU control of LIDAR system

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lidar_pkg.all;

entity soft_processor_interface is
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
end soft_processor_interface;

architecture rtl of soft_processor_interface is
    -- Register map addresses
    constant REG_CONTROL       : std_logic_vector(7 downto 0) := x"00";
    constant REG_STATUS        : std_logic_vector(7 downto 0) := x"04";
    constant REG_PULSE_WIDTH   : std_logic_vector(7 downto 0) := x"08";
    constant REG_SCAN_RATE     : std_logic_vector(7 downto 0) := x"0C";
    constant REG_CURRENT_ANGLE : std_logic_vector(7 downto 0) := x"10";
    constant REG_MEM_ADDR      : std_logic_vector(7 downto 0) := x"14";
    constant REG_MEM_DATA      : std_logic_vector(7 downto 0) := x"18";
    constant REG_VERSION       : std_logic_vector(7 downto 0) := x"1C";
    
    -- Internal registers
    signal control_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal pulse_width_reg : std_logic_vector(15 downto 0) := x"0064"; -- Default 1us
    signal scan_rate_reg : std_logic_vector(15 downto 0) := x"03E8";   -- Default 10us
    signal mem_addr_reg : std_logic_vector(11 downto 0) := (others => '0');
    
    signal read_data : std_logic_vector(31 downto 0);
    signal reg_select : std_logic_vector(7 downto 0);
    
    constant VERSION_ID : std_logic_vector(31 downto 0) := x"4C494441"; -- "LIDA"
    
begin
    reg_select <= addr(7 downto 0);
    mem_addr <= mem_addr_reg;
    
    -- Map control register bits to LIDAR control signals
    lidar_ctrl.start_scan <= control_reg(0);
    lidar_ctrl.reset_scan <= control_reg(1);
    lidar_ctrl.beam_enable <= control_reg(2);
    lidar_ctrl.auto_mode <= control_reg(3);
    lidar_ctrl.pulse_width <= pulse_width_reg;
    lidar_ctrl.scan_rate <= scan_rate_reg;
    
    -- Register write process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                control_reg <= (others => '0');
                pulse_width_reg <= x"0064";
                scan_rate_reg <= x"03E8";
                mem_addr_reg <= (others => '0');
            else
                if cs = '1' and we = '1' then
                    case reg_select is
                        when REG_CONTROL =>
                            control_reg <= data_in;
                        
                        when REG_PULSE_WIDTH =>
                            pulse_width_reg <= data_in(15 downto 0);
                        
                        when REG_SCAN_RATE =>
                            scan_rate_reg <= data_in(15 downto 0);
                        
                        when REG_MEM_ADDR =>
                            mem_addr_reg <= data_in(11 downto 0);
                        
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    -- Register read process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                read_data <= (others => '0');
            else
                if cs = '1' and re = '1' then
                    case reg_select is
                        when REG_CONTROL =>
                            read_data <= control_reg;
                        
                        when REG_STATUS =>
                            read_data <= (31 downto 5 => '0') &
                                       lidar_status.error_flag &
                                       lidar_status.measurement_valid &
                                       lidar_status.beam_active &
                                       lidar_status.scan_complete &
                                       '0'; -- Reserved bit
                        
                        when REG_PULSE_WIDTH =>
                            read_data <= x"0000" & pulse_width_reg;
                        
                        when REG_SCAN_RATE =>
                            read_data <= x"0000" & scan_rate_reg;
                        
                        when REG_CURRENT_ANGLE =>
                            read_data <= x"0000" & lidar_status.current_angle & x"00";
                        
                        when REG_MEM_ADDR =>
                            read_data <= x"00000" & mem_addr_reg;
                        
                        when REG_MEM_DATA =>
                            if mem_valid = '1' then
                                read_data <= x"0000" & "0000" & mem_data;
                            else
                                read_data <= (others => '0');
                            end if;
                        
                        when REG_VERSION =>
                            read_data <= VERSION_ID;
                        
                        when others =>
                            read_data <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    data_out <= read_data;
    
end rtl;
