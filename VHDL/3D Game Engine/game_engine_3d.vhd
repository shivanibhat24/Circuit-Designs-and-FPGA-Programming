-- FPGA-Based 3D Game Engine
-- Main Hardware Accelerator Module
-- Handles sprite movement, 3D transformations, and render buffer management

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Main Game Engine Entity
entity game_engine_3d is
    generic (
        SCREEN_WIDTH  : integer := 640;
        SCREEN_HEIGHT : integer := 480;
        MAX_SPRITES   : integer := 64;
        DEPTH_BITS    : integer := 16
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        -- CPU Interface
        cpu_addr      : in  std_logic_vector(15 downto 0);
        cpu_data_in   : in  std_logic_vector(31 downto 0);
        cpu_data_out  : out std_logic_vector(31 downto 0);
        cpu_wr        : in  std_logic;
        cpu_rd        : in  std_logic;
        -- VGA Output
        vga_clk       : out std_logic;
        vga_hsync     : out std_logic;
        vga_vsync     : out std_logic;
        vga_r         : out std_logic_vector(7 downto 0);
        vga_g         : out std_logic_vector(7 downto 0);
        vga_b         : out std_logic_vector(7 downto 0);
        -- Memory Interface
        mem_addr      : out std_logic_vector(23 downto 0);
        mem_data      : inout std_logic_vector(31 downto 0);
        mem_we        : out std_logic;
        mem_oe        : out std_logic
    );
end game_engine_3d;

architecture Behavioral of game_engine_3d is

    -- 3D Vector and Matrix Types
    type vector3d is record
        x : signed(15 downto 0);
        y : signed(15 downto 0);
        z : signed(15 downto 0);
    end record;
    
    type matrix3x3 is array(0 to 2, 0 to 2) of signed(15 downto 0);
    
    -- Sprite Structure
    type sprite_t is record
        position    : vector3d;
        velocity    : vector3d;
        rotation    : vector3d;
        scale       : signed(15 downto 0);
        texture_id  : std_logic_vector(7 downto 0);
        active      : std_logic;
        depth       : signed(DEPTH_BITS-1 downto 0);
    end record;
    
    type sprite_array is array(0 to MAX_SPRITES-1) of sprite_t;
    
    -- Camera Structure
    type camera_t is record
        position : vector3d;
        rotation : vector3d;
        fov      : signed(15 downto 0);
    end record;
    
    -- Component Declarations
    component transform_engine is
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            start       : in  std_logic;
            position    : in  vector3d;
            rotation    : in  vector3d;
            camera_pos  : in  vector3d;
            camera_rot  : in  vector3d;
            screen_x    : out signed(15 downto 0);
            screen_y    : out signed(15 downto 0);
            depth       : out signed(DEPTH_BITS-1 downto 0);
            valid       : out std_logic
        );
    end component;
    
    component render_buffer is
        generic (
            WIDTH  : integer := SCREEN_WIDTH;
            HEIGHT : integer := SCREEN_HEIGHT
        );
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            wr_en      : in  std_logic;
            wr_x       : in  std_logic_vector(9 downto 0);
            wr_y       : in  std_logic_vector(9 downto 0);
            wr_color   : in  std_logic_vector(23 downto 0);
            wr_depth   : in  signed(DEPTH_BITS-1 downto 0);
            rd_x       : in  std_logic_vector(9 downto 0);
            rd_y       : in  std_logic_vector(9 downto 0);
            rd_color   : out std_logic_vector(23 downto 0);
            clear      : in  std_logic
        );
    end component;
    
    component vga_controller is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            h_sync    : out std_logic;
            v_sync    : out std_logic;
            pixel_x   : out std_logic_vector(9 downto 0);
            pixel_y   : out std_logic_vector(9 downto 0);
            video_on  : out std_logic
        );
    end component;
    
    -- Internal Signals
    signal sprites        : sprite_array;
    signal camera         : camera_t;
    signal current_sprite : integer range 0 to MAX_SPRITES-1;
    signal transform_start: std_logic;
    signal transform_valid: std_logic;
    signal screen_x       : signed(15 downto 0);
    signal screen_y       : signed(15 downto 0);
    signal sprite_depth   : signed(DEPTH_BITS-1 downto 0);
    
    -- Render Buffer Signals
    signal rb_wr_en       : std_logic;
    signal rb_wr_x        : std_logic_vector(9 downto 0);
    signal rb_wr_y        : std_logic_vector(9 downto 0);
    signal rb_wr_color    : std_logic_vector(23 downto 0);
    signal rb_wr_depth    : signed(DEPTH_BITS-1 downto 0);
    signal rb_rd_x        : std_logic_vector(9 downto 0);
    signal rb_rd_y        : std_logic_vector(9 downto 0);
    signal rb_rd_color    : std_logic_vector(23 downto 0);
    signal rb_clear       : std_logic;
    
    -- VGA Signals
    signal vga_h_sync     : std_logic;
    signal vga_v_sync     : std_logic;
    signal vga_pixel_x    : std_logic_vector(9 downto 0);
    signal vga_pixel_y    : std_logic_vector(9 downto 0);
    signal vga_video_on   : std_logic;
    
    -- State Machine
    type state_t is (IDLE, UPDATE_SPRITES, TRANSFORM, RENDER, DISPLAY);
    signal state : state_t;
    
    -- Clock Generation
    signal clk_25mhz      : std_logic;
    signal clk_div        : std_logic_vector(1 downto 0);

begin

    -- 25MHz VGA Clock Generation
    process(clk, rst)
    begin
        if rst = '1' then
            clk_div <= "00";
        elsif rising_edge(clk) then
            clk_div <= clk_div + 1;
        end if;
    end process;
    
    clk_25mhz <= clk_div(1);
    vga_clk <= clk_25mhz;

    -- Transform Engine Instance
    transform_inst: transform_engine
        port map (
            clk         => clk,
            rst         => rst,
            start       => transform_start,
            position    => sprites(current_sprite).position,
            rotation    => sprites(current_sprite).rotation,
            camera_pos  => camera.position,
            camera_rot  => camera.rotation,
            screen_x    => screen_x,
            screen_y    => screen_y,
            depth       => sprite_depth,
            valid       => transform_valid
        );
    
    -- Render Buffer Instance
    render_buffer_inst: render_buffer
        generic map (
            WIDTH  => SCREEN_WIDTH,
            HEIGHT => SCREEN_HEIGHT
        )
        port map (
            clk        => clk,
            rst        => rst,
            wr_en      => rb_wr_en,
            wr_x       => rb_wr_x,
            wr_y       => rb_wr_y,
            wr_color   => rb_wr_color,
            wr_depth   => rb_wr_depth,
            rd_x       => rb_rd_x,
            rd_y       => rb_rd_y,
            rd_color   => rb_rd_color,
            clear      => rb_clear
        );
    
    -- VGA Controller Instance
    vga_inst: vga_controller
        port map (
            clk       => clk_25mhz,
            rst       => rst,
            h_sync    => vga_h_sync,
            v_sync    => vga_v_sync,
            pixel_x   => vga_pixel_x,
            pixel_y   => vga_pixel_y,
            video_on  => vga_video_on
        );
    
    -- Main State Machine
    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            current_sprite <= 0;
            transform_start <= '0';
            rb_clear <= '1';
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    rb_clear <= '1';
                    current_sprite <= 0;
                    state <= UPDATE_SPRITES;
                    
                when UPDATE_SPRITES =>
                    rb_clear <= '0';
                    -- Update sprite positions based on velocity
                    for i in 0 to MAX_SPRITES-1 loop
                        if sprites(i).active = '1' then
                            sprites(i).position.x <= sprites(i).position.x + sprites(i).velocity.x;
                            sprites(i).position.y <= sprites(i).position.y + sprites(i).velocity.y;
                            sprites(i).position.z <= sprites(i).position.z + sprites(i).velocity.z;
                        end if;
                    end loop;
                    state <= TRANSFORM;
                    
                when TRANSFORM =>
                    if sprites(current_sprite).active = '1' then
                        transform_start <= '1';
                        if transform_valid = '1' then
                            transform_start <= '0';
                            state <= RENDER;
                        end if;
                    else
                        if current_sprite < MAX_SPRITES-1 then
                            current_sprite <= current_sprite + 1;
                        else
                            state <= DISPLAY;
                        end if;
                    end if;
                    
                when RENDER =>
                    -- Render sprite to buffer
                    if screen_x >= 0 and screen_x < SCREEN_WIDTH and 
                       screen_y >= 0 and screen_y < SCREEN_HEIGHT then
                        rb_wr_en <= '1';
                        rb_wr_x <= std_logic_vector(to_unsigned(to_integer(screen_x), 10));
                        rb_wr_y <= std_logic_vector(to_unsigned(to_integer(screen_y), 10));
                        rb_wr_color <= x"FFFFFF"; -- White for now
                        rb_wr_depth <= sprite_depth;
                    else
                        rb_wr_en <= '0';
                    end if;
                    
                    if current_sprite < MAX_SPRITES-1 then
                        current_sprite <= current_sprite + 1;
                        state <= TRANSFORM;
                    else
                        state <= DISPLAY;
                    end if;
                    
                when DISPLAY =>
                    rb_wr_en <= '0';
                    state <= IDLE;
                    
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
    
    -- CPU Interface
    process(clk, rst)
    begin
        if rst = '1' then
            cpu_data_out <= (others => '0');
        elsif rising_edge(clk) then
            if cpu_rd = '1' then
                case cpu_addr(15 downto 8) is
                    when x"00" => -- Sprite data
                        -- Read sprite information
                        cpu_data_out <= (others => '0');
                    when x"01" => -- Camera data
                        -- Read camera information
                        cpu_data_out <= (others => '0');
                    when others =>
                        cpu_data_out <= (others => '0');
                end case;
            elsif cpu_wr = '1' then
                case cpu_addr(15 downto 8) is
                    when x"00" => -- Sprite data
                        -- Write sprite information
                        null;
                    when x"01" => -- Camera data
                        -- Write camera information
                        null;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
    
    -- VGA Output
    rb_rd_x <= vga_pixel_x;
    rb_rd_y <= vga_pixel_y;
    
    vga_hsync <= vga_h_sync;
    vga_vsync <= vga_v_sync;
    
    vga_r <= rb_rd_color(23 downto 16) when vga_video_on = '1' else (others => '0');
    vga_g <= rb_rd_color(15 downto 8)  when vga_video_on = '1' else (others => '0');
    vga_b <= rb_rd_color(7 downto 0)   when vga_video_on = '1' else (others => '0');

end Behavioral;
