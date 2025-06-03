-- FIFO Buffer Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo_buffer is
    Generic (
        DATA_WIDTH : integer := 16;
        DEPTH      : integer := 1024
    );
    Port (
        clk        : in  STD_LOGIC;
        reset_n    : in  STD_LOGIC;
        wr_en      : in  STD_LOGIC;
        wr_data    : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        rd_en      : in  STD_LOGIC;
        rd_data    : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        full       : out STD_LOGIC;
        empty      : out STD_LOGIC;
        almost_full: out STD_LOGIC
    );
end fifo_buffer;

architecture Behavioral of fifo_buffer is
    
    type memory_array is array (0 to DEPTH-1) of STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal memory : memory_array;
    
    signal wr_ptr : unsigned(15 downto 0) := (others => '0');
    signal rd_ptr : unsigned(15 downto 0) := (others => '0');
    signal count  : unsigned(15 downto 0) := (others => '0');
    
    signal full_int : STD_LOGIC;
    signal empty_int : STD_LOGIC;
    signal almost_full_int : STD_LOGIC;

begin

    full_int <= '1' when count = DEPTH else '0';
    empty_int <= '1' when count = 0 else '0';
    almost_full_int <= '1' when count >= DEPTH - 4 else '0';
    
    full <= full_int;
    empty <= empty_int;
    almost_full <= almost_full_int;
    
    -- Write process
    write_proc : process(clk, reset_n)
    begin
        if reset_n = '0' then
            wr_ptr <= (others => '0');
        elsif rising_edge(clk) then
            if wr_en = '1' and full_int = '0' then
                memory(to_integer(wr_ptr mod DEPTH)) <= wr_data;
                wr_ptr <= wr_ptr + 1;
            end if;
        end if;
    end process;
    
    -- Read process
    read_proc : process(clk, reset_n)
    begin
        if reset_n = '0' then
            rd_ptr <= (others => '0');
            rd_data <= (others => '0');
        elsif rising_edge(clk) then
            if rd_en = '1' and empty_int = '0' then
                rd_data <= memory(to_integer(rd_ptr mod DEPTH));
                rd_ptr <= rd_ptr + 1;
            end if;
        end if;
    end process;
    
    -- Count process
    count_proc : process(clk, reset_n)
    begin
        if reset_n = '0' then
            count <= (others => '0');
        elsif rising_edge(clk) then
            if wr_en = '1' and rd_en = '0' and full_int = '0' then
                count <= count + 1;
            elsif wr_en = '0' and rd_en = '1' and empty_int = '0' then
                count <= count - 1;
            end if;
        end if;
    end process;

end Behavioral;
