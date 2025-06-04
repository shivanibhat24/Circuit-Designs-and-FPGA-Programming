-- 3D Transform Engine Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity transform_engine is
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
        depth       : out signed(15 downto 0);
        valid       : out std_logic
    );
end transform_engine;

architecture Behavioral of transform_engine is
    signal world_pos : vector3d;
    signal view_pos  : vector3d;
    signal proj_x    : signed(31 downto 0);
    signal proj_y    : signed(31 downto 0);
    signal counter   : std_logic_vector(3 downto 0);
begin

    process(clk, rst)
    begin
        if rst = '1' then
            screen_x <= (others => '0');
            screen_y <= (others => '0');
            depth <= (others => '0');
            valid <= '0';
            counter <= (others => '0');
        elsif rising_edge(clk) then
            if start = '1' then
                counter <= (others => '0');
                valid <= '0';
                
                -- World to view space transformation
                world_pos.x <= position.x - camera_pos.x;
                world_pos.y <= position.y - camera_pos.y;
                world_pos.z <= position.z - camera_pos.z;
                
            elsif counter < "1000" then
                counter <= counter + 1;
                
                case counter is
                    when "0001" =>
                        -- Apply camera rotation (simplified)
                        view_pos <= world_pos;
                        
                    when "0010" =>
                        -- Perspective projection
                        if view_pos.z > 1 then
                            proj_x <= (view_pos.x * 320) / view_pos.z;
                            proj_y <= (view_pos.y * 240) / view_pos.z;
                        else
                            proj_x <= (others => '0');
                            proj_y <= (others => '0');
                        end if;
                        
                    when "0011" =>
                        -- Convert to screen coordinates
                        screen_x <= proj_x(15 downto 0) + 320;
                        screen_y <= 240 - proj_y(15 downto 0);
                        depth <= view_pos.z;
                        
                    when "0100" =>
                        valid <= '1';
                        
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
