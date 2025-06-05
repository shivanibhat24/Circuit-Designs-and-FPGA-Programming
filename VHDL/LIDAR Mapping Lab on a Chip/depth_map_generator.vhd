-- Depth Map Generator
-- Converts angle and distance measurements to depth map coordinates

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lidar_pkg.all;

entity depth_map_generator is
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
end depth_map_generator;

architecture rtl of depth_map_generator is
    type state_t is (IDLE, CALCULATE_ADDR, WRITE_DATA, COMPLETE);
    signal state : state_t := IDLE;
    
    signal x_coord : unsigned(5 downto 0); -- 64x64 map
    signal y_coord : unsigned(5 downto 0);
    signal map_address : unsigned(11 downto 0);
    signal pixel_count : unsigned(11 downto 0) := (others => '0');
    
    -- Map dimensions
    constant MAP_WIDTH : unsigned(5 downto 0) := to_unsigned(63, 6);
    constant MAP_HEIGHT : unsigned(5 downto 0) := to_unsigned(63, 6);
    constant TOTAL_PIXELS : unsigned(11 downto 0) := to_unsigned(4095, 12); -- 64x64 - 1
    
    -- Angle to coordinate conversion
    signal angle_x_scaled : unsigned(7 downto 0);
    signal angle_y_scaled : unsigned(7 downto 0);
    
begin
    -- Scale 8-bit angles to 6-bit coordinates (divide by 4)
    angle_x_scaled <= unsigned(beam_angle_x);
    angle_y_scaled <= unsigned(beam_angle_y);
    
    x_coord <= angle_x_scaled(7 downto 2);
    y_coord <= angle_y_scaled(7 downto 2);
    
    -- Calculate linear address from 2D coordinates
    map_address <= (y_coord & "000000") + x_coord; -- y*64 + x
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                depth_map_we <= '0';
                depth_map_addr <= (others => '0');
                depth_map_data <= (others => '0');
                map_complete <= '0';
                pixel_count <= (others => '0');
            else
                case state is
                    when IDLE =>
                        depth_map_we <= '0';
                        map_complete <= '0';
                        
                        if measurement_valid = '1' then
                            state <= CALCULATE_ADDR;
                        end if;
                    
                    when CALCULATE_ADDR =>
                        -- Address calculation completed in combinatorial logic
                        depth_map_addr <= std_logic_vector(map_address);
                        depth_map_data <= distance;
                        state <= WRITE_DATA;
                    
                    when WRITE_DATA =>
                        depth_map_we <= '1';
                        pixel_count <= pixel_count + 1;
                        state <= COMPLETE;
                    
                    when COMPLETE =>
                        depth_map_we <= '0';
                        
                        if pixel_count >= TOTAL_PIXELS then
                            map_complete <= '1';
                        end if;
                        
                        if measurement_valid = '0' then
                            state <= IDLE;
                        end if;
                    
                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
    
end rtl;
