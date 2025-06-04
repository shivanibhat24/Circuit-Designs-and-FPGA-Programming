-- VGA Controller
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        h_sync    : out std_logic;
        v_sync    : out std_logic;
        pixel_x   : out std_logic_vector(9 downto 0);
        pixel_y   : out std_logic_vector(9 downto 0);
        video_on  : out std_logic
    );
end vga_controller;

architecture Behavioral of vga_controller is
    -- VGA 640x480 @ 60Hz timing
    constant H_DISPLAY  : integer := 640;
    constant H_FRONT    : integer := 16;
    constant H_SYNC     : integer := 96;
    constant H_BACK     : integer := 48;
    constant H_TOTAL    : integer := H_DISPLAY + H_FRONT + H_SYNC + H_BACK;
    
    constant V_DISPLAY  : integer := 480;
    constant V_FRONT    : integer := 10;
    constant V_SYNC     : integer := 2;
    constant V_BACK     : integer := 33;
    constant V_TOTAL    : integer := V_DISPLAY + V_FRONT + V_SYNC + V_BACK;
    
    signal h_counter : integer range 0 to H_TOTAL-1;
    signal v_counter : integer range 0 to V_TOTAL-1;
    
begin

    process(clk, rst)
    begin
        if rst = '1' then
            h_counter <= 0;
            v_counter <= 0;
        elsif rising_edge(clk) then
            if h_counter = H_TOTAL-1 then
                h_counter <= 0;
                if v_counter = V_TOTAL-1 then
                    v_counter <= 0;
                else
                    v_counter <= v_counter + 1;
                end if;
            else
                h_counter <= h_counter + 1;
            end if;
        end if;
    end process;
    
    -- Generate sync signals
    h_sync <= '0' when (h_counter >= H_DISPLAY + H_FRONT) and 
                      (h_counter < H_DISPLAY + H_FRONT + H_SYNC) else '1';
    
    v_sync <= '0' when (v_counter >= V_DISPLAY + V_FRONT) and 
                      (v_counter < V_DISPLAY + V_FRONT + V_SYNC) else '1';
    
    -- Generate pixel coordinates
    pixel_x <= std_logic_vector(to_unsigned(h_counter, 10)) when h_counter < H_DISPLAY else (others => '0');
    pixel_y <= std_logic_vector(to_unsigned(v_counter, 10)) when v_counter < V_DISPLAY else (others => '0');
    
    -- Video enable signal
    video_on <= '1' when (h_counter < H_DISPLAY) and (v_counter < V_DISPLAY) else '0';

end Behavioral;
