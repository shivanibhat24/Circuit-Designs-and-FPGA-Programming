library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity image_capture is
    Port ( 
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        cam_data    : in STD_LOGIC_VECTOR(7 downto 0);
        cam_valid   : in STD_LOGIC;
        gray_data   : out STD_LOGIC_VECTOR(7 downto 0);
        frame_ready : out STD_LOGIC
    );
end image_capture;

architecture Behavioral of image_capture is
    -- Frame buffer types
    type frame_buffer is array(0 to 255, 0 to 255) of STD_LOGIC_VECTOR(7 downto 0);
    
    signal current_buffer   : frame_buffer;
    signal x_coord          : integer range 0 to 255 := 0;
    signal y_coord          : integer range 0 to 255 := 0;
    signal capture_state    : STD_LOGIC_VECTOR(1 downto 0) := "00";

begin
    process(clk, reset)
    begin
        if reset = '1' then
            x_coord <= 0;
            y_coord <= 0;
            frame_ready <= '0';
            capture_state <= "00";
        elsif rising_edge(clk) then
            -- Capture image frame
            if cam_valid = '1' then
                -- Store pixel in buffer
                current_buffer(y_coord, x_coord) <= cam_data;
                
                -- Increment coordinates
                if x_coord < 255 then
                    x_coord <= x_coord + 1;
                else
                    x_coord <= 0;
                    if y_coord < 255 then
                        y_coord <= y_coord + 1;
                    else
                        -- Full frame captured
                        frame_ready <= '1';
                        y_coord <= 0;
                    end if;
                end if;
            end if;
            
            -- Output grayscale data for processing
            if frame_ready = '1' then
                gray_data <= current_buffer(y_coord, x_coord);
            end if;
        end if;
    end process;
end Behavioral;
