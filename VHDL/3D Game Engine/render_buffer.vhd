-- Render Buffer with Z-Buffer
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity render_buffer is
    generic (
        WIDTH  : integer := 640;
        HEIGHT : integer := 480
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        wr_en      : in  std_logic;
        wr_x       : in  std_logic_vector(9 downto 0);
        wr_y       : in  std_logic_vector(9 downto 0);
        wr_color   : in  std_logic_vector(23 downto 0);
        wr_depth   : in  signed(15 downto 0);
        rd_x       : in  std_logic_vector(9 downto 0);
        rd_y       : in  std_logic_vector(9 downto 0);
        rd_color   : out std_logic_vector(23 downto 0);
        clear      : in  std_logic
    );
end render_buffer;

architecture Behavioral of render_buffer is
    type color_buffer_t is array(0 to WIDTH*HEIGHT-1) of std_logic_vector(23 downto 0);
    type depth_buffer_t is array(0 to WIDTH*HEIGHT-1) of signed(15 downto 0);
    
    signal color_buffer : color_buffer_t;
    signal depth_buffer : depth_buffer_t;
    
    signal wr_addr : integer;
    signal rd_addr : integer;
begin

    wr_addr <= to_integer(unsigned(wr_y)) * WIDTH + to_integer(unsigned(wr_x));
    rd_addr <= to_integer(unsigned(rd_y)) * WIDTH + to_integer(unsigned(rd_x));

    process(clk, rst)
    begin
        if rst = '1' then
            rd_color <= (others => '0');
        elsif rising_edge(clk) then
            if clear = '1' then
                for i in 0 to WIDTH*HEIGHT-1 loop
                    color_buffer(i) <= (others => '0');
                    depth_buffer(i) <= (others => '1'); -- Max depth
                end loop;
            elsif wr_en = '1' and wr_addr < WIDTH*HEIGHT then
                -- Z-buffer test
                if wr_depth < depth_buffer(wr_addr) then
                    color_buffer(wr_addr) <= wr_color;
                    depth_buffer(wr_addr) <= wr_depth;
                end if;
            end if;
            
            -- Read operation
            if rd_addr < WIDTH*HEIGHT then
                rd_color <= color_buffer(rd_addr);
            else
                rd_color <= (others => '0');
            end if;
        end if;
    end process;

end Behavioral;
