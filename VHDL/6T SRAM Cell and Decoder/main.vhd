-- SRAM Memory with 6T Cells and Decoder
-- This implementation includes:
-- 1. 6T SRAM Cell
-- 2. Row Decoder
-- 3. Memory Array
-- 4. Control Logic

-- 6T SRAM Cell Entity
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SRAM_Cell_6T is
    Port (
        BL      : inout STD_LOGIC;  -- Bit Line
        BLB     : inout STD_LOGIC;  -- Bit Line Bar (complement)
        WL      : in STD_LOGIC;     -- Word Line
        VDD     : in STD_LOGIC;     -- Power Supply
        VSS     : in STD_LOGIC      -- Ground
    );
end SRAM_Cell_6T;

architecture Behavioral of SRAM_Cell_6T is
    -- Internal signals for the cross-coupled inverters
    signal Q, Q_BAR : STD_LOGIC := '0';
begin
    -- Access transistors and cross-coupled inverters behavior
    process(WL, BL, BLB)
    begin
        -- When word line is activated
        if WL = '1' then
            -- Write operation
            if BL /= 'Z' and BLB /= 'Z' then
                Q <= BL;
                Q_BAR <= BLB;
            -- Read operation
            else
                BL <= Q;
                BLB <= Q_BAR;
            end if;
        end if;
    end process;
end Behavioral;

-- Row Decoder Entity
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Row_Decoder is
    Generic (
        ADDR_WIDTH : integer := 4  -- 4-bit address = 16 rows
    );
    Port (
        address : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        en      : in STD_LOGIC;
        word_lines : out STD_LOGIC_VECTOR((2**ADDR_WIDTH)-1 downto 0)
    );
end Row_Decoder;

architecture Behavioral of Row_Decoder is
begin
    process(address, en)
    begin
        -- Initialize all word lines to '0'
        word_lines <= (others => '0');
        
        -- If enabled, activate the selected word line
        if en = '1' then
            word_lines(to_integer(unsigned(address))) <= '1';
        end if;
    end process;
end Behavioral;

-- SRAM Memory Array Entity
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SRAM_Array is
    Generic (
        ADDR_WIDTH : integer := 4;  -- 4-bit address = 16 rows
        DATA_WIDTH : integer := 8   -- 8-bit data word
    );
    Port (
        clk     : in STD_LOGIC;
        reset   : in STD_LOGIC;
        address : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        data_in : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        data_out: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        rd_en   : in STD_LOGIC;
        wr_en   : in STD_LOGIC
    );
end SRAM_Array;

architecture Behavioral of SRAM_Array is
    -- Component declarations
    component SRAM_Cell_6T is
        Port (
            BL      : inout STD_LOGIC;
            BLB     : inout STD_LOGIC;
            WL      : in STD_LOGIC;
            VDD     : in STD_LOGIC;
            VSS     : in STD_LOGIC
        );
    end component;
    
    component Row_Decoder is
        Generic (
            ADDR_WIDTH : integer := 4
        );
        Port (
            address : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
            en      : in STD_LOGIC;
            word_lines : out STD_LOGIC_VECTOR((2**ADDR_WIDTH)-1 downto 0)
        );
    end component;
    
    -- Signals for the memory array
    signal word_lines : STD_LOGIC_VECTOR((2**ADDR_WIDTH)-1 downto 0);
    signal bit_lines : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal bit_lines_bar : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal decoder_en : STD_LOGIC;
    
begin
    -- Row decoder instantiation
    row_dec: Row_Decoder
        generic map (
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            address => address,
            en => decoder_en,
            word_lines => word_lines
        );
    
    -- Generate the 2D array of SRAM cells
    memory_array: for row in 0 to (2**ADDR_WIDTH)-1 generate
        bit_cells: for col in 0 to DATA_WIDTH-1 generate
            sram_cell: SRAM_Cell_6T
                port map (
                    BL => bit_lines(col),
                    BLB => bit_lines_bar(col),
                    WL => word_lines(row),
                    VDD => '1',  -- Connected to power
                    VSS => '0'   -- Connected to ground
                );
        end generate bit_cells;
    end generate memory_array;
    
    -- Control logic process
    process(clk, reset)
    begin
        if reset = '1' then
            data_out <= (others => '0');
            bit_lines <= (others => 'Z');
            bit_lines_bar <= (others => 'Z');
            decoder_en <= '0';
        elsif rising_edge(clk) then
            -- Default state
            bit_lines <= (others => 'Z');
            bit_lines_bar <= (others => 'Z');
            
            -- Read operation
            if rd_en = '1' and wr_en = '0' then
                decoder_en <= '1';
                -- Precharge bit lines (in real hardware, this would be done by separate circuitry)
                bit_lines <= (others => '1');
                bit_lines_bar <= (others => '1');
                -- After precharge, allow cells to drive bit lines
                bit_lines <= (others => 'Z');
                bit_lines_bar <= (others => 'Z');
                -- Sample bit lines for output
                data_out <= bit_lines;
            
            -- Write operation
            elsif wr_en = '1' and rd_en = '0' then
                decoder_en <= '1';
                -- Drive bit lines with input data
                for i in 0 to DATA_WIDTH-1 loop
                    bit_lines(i) <= data_in(i);
                    bit_lines_bar(i) <= not data_in(i);
                end loop;
            
            -- No operation
            else
                decoder_en <= '0';
                bit_lines <= (others => 'Z');
                bit_lines_bar <= (others => 'Z');
            end if;
        end if;
    end process;
    
end Behavioral;

-- Top-level entity that incorporates all components
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SRAM_Memory is
    Generic (
        ADDR_WIDTH : integer := 4;  -- 4-bit address = 16 rows
        DATA_WIDTH : integer := 8   -- 8-bit data word
    );
    Port (
        clk     : in STD_LOGIC;
        reset   : in STD_LOGIC;
        cs      : in STD_LOGIC;  -- Chip Select
        rw      : in STD_LOGIC;  -- Read/Write (1 for read, 0 for write)
        address : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        data_in : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        data_out: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
    );
end SRAM_Memory;

architecture Behavioral of SRAM_Memory is
    -- Component declaration
    component SRAM_Array is
        Generic (
            ADDR_WIDTH : integer;
            DATA_WIDTH : integer
        );
        Port (
            clk     : in STD_LOGIC;
            reset   : in STD_LOGIC;
            address : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
            data_in : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            data_out: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            rd_en   : in STD_LOGIC;
            wr_en   : in STD_LOGIC
        );
    end component;
    
    -- Control signals
    signal rd_en : STD_LOGIC;
    signal wr_en : STD_LOGIC;
    
begin
    -- Generate control signals
    rd_en <= cs and rw;
    wr_en <= cs and (not rw);
    
    -- Instantiate the memory array
    sram: SRAM_Array
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk => clk,
            reset => reset,
            address => address,
            data_in => data_in,
            data_out => data_out,
            rd_en => rd_en,
            wr_en => wr_en
        );
    
end Behavioral;

-- Test Bench for verification
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SRAM_Memory_TB is
end SRAM_Memory_TB;

architecture Behavioral of SRAM_Memory_TB is
    -- Component declaration
    component SRAM_Memory is
        Generic (
            ADDR_WIDTH : integer := 4;
            DATA_WIDTH : integer := 8
        );
        Port (
            clk     : in STD_LOGIC;
            reset   : in STD_LOGIC;
            cs      : in STD_LOGIC;
            rw      : in STD_LOGIC;
            address : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
            data_in : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            data_out: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    -- Test bench signals
    constant ADDR_WIDTH : integer := 4;
    constant DATA_WIDTH : integer := 8;
    constant CLK_PERIOD : time := 10 ns;
    
    signal clk     : STD_LOGIC := '0';
    signal reset   : STD_LOGIC := '1';
    signal cs      : STD_LOGIC := '0';
    signal rw      : STD_LOGIC := '0';
    signal address : STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal data_in : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_out: STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    
begin
    -- Instantiate the Unit Under Test (UUT)
    uut: SRAM_Memory
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk => clk,
            reset => reset,
            cs => cs,
            rw => rw,
            address => address,
            data_in => data_in,
            data_out => data_out
        );
    
    -- Clock process
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Hold reset for a few clock cycles
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';
        wait for CLK_PERIOD * 2;
        
        -- Write operation to address 0
        cs <= '1';
        rw <= '0';  -- Write
        address <= "0000";
        data_in <= "10101010";
        wait for CLK_PERIOD;
        cs <= '0';
        wait for CLK_PERIOD;
        
        -- Write operation to address 1
        cs <= '1';
        rw <= '0';  -- Write
        address <= "0001";
        data_in <= "11001100";
        wait for CLK_PERIOD;
        cs <= '0';
        wait for CLK_PERIOD;
        
        -- Read operation from address 0
        cs <= '1';
        rw <= '1';  -- Read
        address <= "0000";
        wait for CLK_PERIOD;
        cs <= '0';
        wait for CLK_PERIOD;
        
        -- Read operation from address 1
        cs <= '1';
        rw <= '1';  -- Read
        address <= "0001";
        wait for CLK_PERIOD;
        cs <= '0';
        wait for CLK_PERIOD;
        
        -- End simulation
        wait;
    end process;
    
end Behavioral;
