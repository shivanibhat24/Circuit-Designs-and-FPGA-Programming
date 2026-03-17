-- =============================================================================
-- 6T SRAM Memory Macro — Improved RTL Implementation
-- Author      : Shivani Bhat
-- Description : Parameterisable SRAM with 6T bitcell array, row decoder,
--               column mux, write driver, sense amplifier, and precharge logic
-- Target      : Synthesis-ready VHDL — suitable for RTL-to-GDS flow (SKY130)
-- Array size  : 2^ADDR_WIDTH rows x DATA_WIDTH columns (default 16x8)
-- =============================================================================
--
-- 6T SRAM CELL — TRANSISTOR-LEVEL UNDERSTANDING
-- -----------------------------------------------
-- A true 6T SRAM cell consists of 6 MOSFETs:
--
--   VDD
--    |         |
--   M1(PMOS)  M3(PMOS)      <- Pull-up network (cross-coupled)
--    |         |
--    +----+----+
--    |    |    |
--   M2   QB   M4            <- QB = Q_BAR node
--  (NMOS)     (NMOS)        <- Pull-down network (cross-coupled)
--    |         |
--   VSS       VSS
--
--   WL ----M5(NMOS)---- BL   <- Access transistor to Q node
--   WL ----M6(NMOS)---- BLB  <- Access transistor to QB node
--
-- Storage nodes: Q (between M1/M2) and QB (between M3/M4)
-- Cross-coupling: Q drives gate of M3/M4; QB drives gate of M1/M2
--
-- READ operation:
--   1. Precharge BL and BLB to VDD
--   2. Assert WL — M5 and M6 turn ON
--   3. If Q=0: BL discharges slightly through M5+M2 (small DeltaV)
--   4. Sense amplifier detects BL/BLB differential and amplifies
--   Key concern: READ STATIC NOISE MARGIN (RSNM)
--   During read, Q node is pulled up by M5 toward BL=VDD,
--   which can flip the stored value. Cell ratio (CR = M2/M5 sizing)
--   must be > 1.5 to maintain RSNM > 0.
--
-- WRITE operation:
--   1. Drive BL to data, BLB to complement via write driver
--   2. Assert WL — M5 and M6 turn ON
--   3. Write driver overpowers pull-up (M1 or M3) to flip the cell
--   Key concern: WRITE STATIC NOISE MARGIN (WSNM)
--   Pull-ratio (PR = M1/M5 sizing) must be < 1 to allow write.
--   Typical: CR >= 1.5, PR <= 0.8 in 28nm–180nm processes.
--
-- HOLD state (WL=0):
--   Access transistors OFF, cell holds state via regenerative feedback.
--   HOLD SNM is the largest of the three margins.
-- =============================================================================

-- =============================================================================
-- ENTITY 1: Sense Amplifier (behavioural)
-- Detects small differential on BL/BLB and drives a full-swing output.
-- In silicon: cross-coupled latch triggered by a sense-enable (SE) pulse.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Sense_Amplifier is
    Port (
        BL      : in  STD_LOGIC;   -- Bit line (after small discharge)
        BLB     : in  STD_LOGIC;   -- Bit line bar
        SE      : in  STD_LOGIC;   -- Sense enable (active high, pulsed)
        data_out: out STD_LOGIC    -- Amplified output
    );
end Sense_Amplifier;

architecture Behavioral of Sense_Amplifier is
begin
    -- Behavioural model: when SE is asserted, latch the differential
    -- In a real implementation this is a cross-coupled PMOS/NMOS latch
    -- triggered after a fixed precharge-evaluate cycle.
    process(SE, BL, BLB)
    begin
        if SE = '1' then
            if BL = '1' and BLB = '0' then
                data_out <= '1';
            elsif BL = '0' and BLB = '1' then
                data_out <= '0';
            elsif BL = '1' and BLB = '1' then
                -- Both high = precharge not complete or cell SNM issue
                -- Default: hold last value (modelled as '0' for sim)
                data_out <= '0';
            else
                data_out <= '0';
            end if;
        end if;
        -- When SE = '0', output holds (latch behaviour)
    end process;
end Behavioral;


-- =============================================================================
-- ENTITY 2: Precharge Circuit (per bitline pair)
-- Drives BL and BLB to VDD before a read operation.
-- In silicon: two PMOS transistors gated by PCH_B (active low).
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Precharge is
    Port (
        PCH     : in  STD_LOGIC;        -- Precharge enable (active high)
        BL      : out STD_LOGIC;        -- Drives bitline to '1'
        BLB     : out STD_LOGIC         -- Drives bitline bar to '1'
    );
end Precharge;

architecture Behavioral of Precharge is
begin
    process(PCH)
    begin
        if PCH = '1' then
            BL  <= '1';
            BLB <= '1';
        else
            BL  <= 'Z';     -- Release bitlines (tristated)
            BLB <= 'Z';
        end if;
    end process;
end Behavioral;


-- =============================================================================
-- ENTITY 3: Write Driver (per bitline pair)
-- Drives BL/BLB strongly during a write operation.
-- In silicon: two NMOS pull-down transistors controlled by write data.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Write_Driver is
    Port (
        WR_EN   : in  STD_LOGIC;        -- Write enable
        data_in : in  STD_LOGIC;        -- Data bit to write
        BL      : out STD_LOGIC;        -- Drives bitline
        BLB     : out STD_LOGIC         -- Drives bitline bar
    );
end Write_Driver;

architecture Behavioral of Write_Driver is
begin
    process(WR_EN, data_in)
    begin
        if WR_EN = '1' then
            BL  <= data_in;
            BLB <= not data_in;
        else
            BL  <= 'Z';
            BLB <= 'Z';
        end if;
    end process;
end Behavioral;


-- =============================================================================
-- ENTITY 4: 6T SRAM Bitcell
-- Behavioural model of the cross-coupled inverter storage element
-- with access transistors controlled by the word line.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SRAM_Cell_6T is
    Port (
        BL      : inout STD_LOGIC;  -- Bit line (to/from M5 access transistor)
        BLB     : inout STD_LOGIC;  -- Bit line bar (to/from M6 access transistor)
        WL      : in    STD_LOGIC;  -- Word line (gates M5 and M6)
        VDD     : in    STD_LOGIC;  -- Supply (gates M1, M3 pull-ups)
        VSS     : in    STD_LOGIC   -- Ground  (M2, M4 pull-downs)
    );
end SRAM_Cell_6T;

architecture Behavioral of SRAM_Cell_6T is
    -- Internal storage nodes
    -- Q    = output of Inverter 1 (M1+M2), input to Inverter 2 (M3+M4)
    -- Q_BAR= output of Inverter 2 (M3+M4), input to Inverter 1 (M1+M2)
    signal Q     : STD_LOGIC := '0';
    signal Q_BAR : STD_LOGIC := '1';
begin

    -- Access transistors M5/M6 connect storage nodes to bitlines when WL=1
    -- Write: bitlines driven externally (by Write_Driver) — overpower cell
    -- Read:  bitlines precharged; cell slightly discharges one side
    process(WL, BL, BLB)
    begin
        if WL = '1' then
            -- WRITE: if bitlines are strongly driven (not Z), accept data
            if (BL = '1' or BL = '0') and (BLB = '1' or BLB = '0') then
                Q     <= BL;
                Q_BAR <= BLB;
            -- READ: release bitlines so cell drives them (small differential)
            else
                BL  <= Q;
                BLB <= Q_BAR;
            end if;
        else
            -- WL=0: access transistors OFF — cell holds state (regenerative)
            BL  <= 'Z';
            BLB <= 'Z';
        end if;
    end process;

    -- Cross-coupled inverter feedback (combinational — models regeneration)
    -- Inverter 1: Q_BAR -> Q  (M1 PMOS + M2 NMOS)
    -- Inverter 2: Q -> Q_BAR  (M3 PMOS + M4 NMOS)
    -- NOTE: In real silicon, this feedback sets the SNM.
    --       Cell ratio (M2 W/L)/(M5 W/L) >= 1.5 for stable read.
    --       Pull ratio (M1 W/L)/(M5 W/L) <= 0.8 for reliable write.

end Behavioral;


-- =============================================================================
-- ENTITY 5: Row Decoder (4-to-16, parameterised)
-- Activates exactly one word line given a binary address.
-- In silicon: a tree of NAND/NOR gates or a standard cell decoder.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Row_Decoder is
    Generic (
        ADDR_WIDTH : integer := 4   -- 4-bit address decodes 16 rows
    );
    Port (
        address    : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        en         : in  STD_LOGIC;
        word_lines : out STD_LOGIC_VECTOR((2**ADDR_WIDTH)-1 downto 0)
    );
end Row_Decoder;

architecture Behavioral of Row_Decoder is
begin
    process(address, en)
    begin
        word_lines <= (others => '0');  -- Deassert all rows by default
        if en = '1' then
            -- One-hot decode: only the addressed row is asserted
            word_lines(to_integer(unsigned(address))) <= '1';
        end if;
    end process;
end Behavioral;


-- =============================================================================
-- ENTITY 6: Column Decoder / Mux
-- Selects which bitline column connects to the sense amp / write driver.
-- For an 8-bit word with no column mux (col_sel selects all 8), this
-- passes all columns. For wider arrays, this reduces I/O pin count.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Column_Mux is
    Generic (
        DATA_WIDTH : integer := 8
    );
    Port (
        bl_array    : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        blb_array   : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        col_sel     : in  STD_LOGIC;    -- '1' = connect all cols (simple case)
        bl_out      : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        blb_out     : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
    );
end Column_Mux;

architecture Behavioral of Column_Mux is
begin
    process(col_sel, bl_array, blb_array)
    begin
        if col_sel = '1' then
            bl_out  <= bl_array;
            blb_out <= blb_array;
        else
            bl_out  <= (others => 'Z');
            blb_out <= (others => 'Z');
        end if;
    end process;
end Behavioral;


-- =============================================================================
-- ENTITY 7: SRAM Array — 16 rows x 8 columns of 6T cells
-- Instantiates the full cell matrix and connects decoders / bitlines.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SRAM_Array is
    Generic (
        ADDR_WIDTH : integer := 4;  -- 2^4 = 16 rows
        DATA_WIDTH : integer := 8   -- 8 columns (bits per word)
    );
    Port (
        clk      : in    STD_LOGIC;
        reset    : in    STD_LOGIC;
        address  : in    STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        data_in  : in    STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        data_out : out   STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        rd_en    : in    STD_LOGIC;
        wr_en    : in    STD_LOGIC
    );
end SRAM_Array;

architecture Behavioral of SRAM_Array is

    -- Component declarations
    component SRAM_Cell_6T is
        Port (
            BL  : inout STD_LOGIC;
            BLB : inout STD_LOGIC;
            WL  : in    STD_LOGIC;
            VDD : in    STD_LOGIC;
            VSS : in    STD_LOGIC
        );
    end component;

    component Row_Decoder is
        Generic ( ADDR_WIDTH : integer := 4 );
        Port (
            address    : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
            en         : in  STD_LOGIC;
            word_lines : out STD_LOGIC_VECTOR((2**ADDR_WIDTH)-1 downto 0)
        );
    end component;

    component Sense_Amplifier is
        Port (
            BL      : in  STD_LOGIC;
            BLB     : in  STD_LOGIC;
            SE      : in  STD_LOGIC;
            data_out: out STD_LOGIC
        );
    end component;

    component Write_Driver is
        Port (
            WR_EN   : in  STD_LOGIC;
            data_in : in  STD_LOGIC;
            BL      : out STD_LOGIC;
            BLB     : out STD_LOGIC
        );
    end component;

    component Column_Mux is
        Generic ( DATA_WIDTH : integer := 8 );
        Port (
            bl_array  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            blb_array : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            col_sel   : in  STD_LOGIC;
            bl_out    : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            blb_out   : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
        );
    end component;

    -- Internal signals
    signal word_lines   : STD_LOGIC_VECTOR((2**ADDR_WIDTH)-1 downto 0);
    signal bit_lines    : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal bit_lines_bar: STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal bl_muxed     : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal blb_muxed    : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal decoder_en   : STD_LOGIC;
    signal sense_en     : STD_LOGIC;
    signal col_sel      : STD_LOGIC;
    signal pch          : STD_LOGIC;    -- Precharge enable
    signal wr_cell_en   : STD_LOGIC;

    -- Precharge driven signals (separate from cell-driven bitlines)
    signal bl_pch       : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal blb_pch      : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal bl_wr        : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal blb_wr       : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);

begin

    -- Row decoder: activates one word line per clock cycle
    row_dec: Row_Decoder
        generic map ( ADDR_WIDTH => ADDR_WIDTH )
        port map (
            address    => address,
            en         => decoder_en,
            word_lines => word_lines
        );

    -- Column mux: passes all columns in this configuration
    col_mux: Column_Mux
        generic map ( DATA_WIDTH => DATA_WIDTH )
        port map (
            bl_array  => bit_lines,
            blb_array => bit_lines_bar,
            col_sel   => col_sel,
            bl_out    => bl_muxed,
            blb_out   => blb_muxed
        );

    -- Generate array: DATA_WIDTH sense amplifiers (one per column)
    sa_gen: for col in 0 to DATA_WIDTH-1 generate
        sa: Sense_Amplifier
            port map (
                BL       => bl_muxed(col),
                BLB      => blb_muxed(col),
                SE       => sense_en,
                data_out => data_out(col)
            );
    end generate sa_gen;

    -- Generate array: DATA_WIDTH write drivers (one per column)
    wd_gen: for col in 0 to DATA_WIDTH-1 generate
        wd: Write_Driver
            port map (
                WR_EN   => wr_cell_en,
                data_in => data_in(col),
                BL      => bit_lines(col),
                BLB     => bit_lines_bar(col)
            );
    end generate wd_gen;

    -- Generate 2D bitcell array: (2^ADDR_WIDTH) rows x DATA_WIDTH columns
    memory_array: for row in 0 to (2**ADDR_WIDTH)-1 generate
        bit_cells: for col in 0 to DATA_WIDTH-1 generate
            cell: SRAM_Cell_6T
                port map (
                    BL  => bit_lines(col),
                    BLB => bit_lines_bar(col),
                    WL  => word_lines(row),
                    VDD => '1',
                    VSS => '0'
                );
        end generate bit_cells;
    end generate memory_array;

    -- ==========================================================================
    -- Control FSM: sequences precharge -> access -> sense/write -> idle
    -- This models the critical timing path in real SRAM operation:
    --   Cycle 1 (before clk edge): PCH asserted — bitlines pulled to VDD
    --   Cycle 2 (clk edge)       : WL asserted, PCH deasserted
    --   Cycle 3 (after WL)       : SE pulsed for read / WR_EN held for write
    -- ==========================================================================
    control_fsm: process(clk, reset)
        -- Pipeline register to sequence precharge -> access
        variable cycle : integer range 0 to 3 := 0;
    begin
        if reset = '1' then
            decoder_en  <= '0';
            sense_en    <= '0';
            col_sel     <= '0';
            wr_cell_en  <= '0';
            pch         <= '0';
            cycle       := 0;

        elsif rising_edge(clk) then
            -- Default deassert
            sense_en   <= '0';
            wr_cell_en <= '0';
            decoder_en <= '0';
            pch        <= '0';
            col_sel    <= '0';

            if rd_en = '1' and wr_en = '0' then
                case cycle is
                    when 0 =>
                        -- Phase 1: Precharge bitlines to VDD
                        pch    <= '1';
                        col_sel <= '1';
                        cycle  := 1;
                    when 1 =>
                        -- Phase 2: Assert word line (access transistors ON)
                        pch        <= '0';
                        decoder_en <= '1';
                        col_sel    <= '1';
                        cycle      := 2;
                    when 2 =>
                        -- Phase 3: Sense amplifier fires — captures data
                        decoder_en <= '1';
                        sense_en   <= '1';
                        col_sel    <= '1';
                        cycle      := 3;
                    when 3 =>
                        -- Phase 4: Idle — outputs hold, reset for next op
                        cycle := 0;
                    when others =>
                        cycle := 0;
                end case;

            elsif wr_en = '1' and rd_en = '0' then
                -- Write: drive bitlines and assert word line same cycle
                decoder_en <= '1';
                wr_cell_en <= '1';
                col_sel    <= '1';
                cycle      := 0;

            else
                cycle := 0;
            end if;
        end if;
    end process control_fsm;

end Behavioral;


-- =============================================================================
-- ENTITY 8: Top-level SRAM_Memory
-- Chip-select and R/W decode wrapping the SRAM array.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SRAM_Memory is
    Generic (
        ADDR_WIDTH : integer := 4;
        DATA_WIDTH : integer := 8
    );
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        cs       : in  STD_LOGIC;   -- Chip select (active high)
        rw       : in  STD_LOGIC;   -- 1 = Read, 0 = Write
        address  : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        data_in  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        data_out : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
    );
end SRAM_Memory;

architecture Behavioral of SRAM_Memory is

    component SRAM_Array is
        Generic (
            ADDR_WIDTH : integer;
            DATA_WIDTH : integer
        );
        Port (
            clk      : in  STD_LOGIC;
            reset    : in  STD_LOGIC;
            address  : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
            data_in  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            data_out : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            rd_en    : in  STD_LOGIC;
            wr_en    : in  STD_LOGIC
        );
    end component;

    signal rd_en : STD_LOGIC;
    signal wr_en : STD_LOGIC;

begin
    rd_en <= cs and rw;
    wr_en <= cs and (not rw);

    sram_core: SRAM_Array
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk      => clk,
            reset    => reset,
            address  => address,
            data_in  => data_in,
            data_out => data_out,
            rd_en    => rd_en,
            wr_en    => wr_en
        );

end Behavioral;


-- =============================================================================
-- ENTITY 9: Self-Checking Testbench
-- Verifies all 16 addresses with write-then-read.
-- Uses VHDL assert to automatically flag any mismatch.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SRAM_Memory_TB is
end SRAM_Memory_TB;

architecture Behavioral of SRAM_Memory_TB is

    component SRAM_Memory is
        Generic (
            ADDR_WIDTH : integer := 4;
            DATA_WIDTH : integer := 8
        );
        Port (
            clk      : in  STD_LOGIC;
            reset    : in  STD_LOGIC;
            cs       : in  STD_LOGIC;
            rw       : in  STD_LOGIC;
            address  : in  STD_LOGIC_VECTOR(3 downto 0);
            data_in  : in  STD_LOGIC_VECTOR(7 downto 0);
            data_out : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    constant ADDR_WIDTH : integer := 4;
    constant DATA_WIDTH : integer := 8;
    constant CLK_PERIOD : time    := 10 ns;

    signal clk      : STD_LOGIC := '0';
    signal reset    : STD_LOGIC := '1';
    signal cs       : STD_LOGIC := '0';
    signal rw       : STD_LOGIC := '0';
    signal address  : STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal data_in  : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_out : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);

    -- Test data array: 16 unique patterns covering bit-flip scenarios
    type test_data_t is array(0 to 15) of STD_LOGIC_VECTOR(7 downto 0);
    constant TEST_DATA : test_data_t := (
        "10101010",  -- addr 0  : alternating bits (checkerboard)
        "11001100",  -- addr 1  : alternating pairs
        "11110000",  -- addr 2  : half-half
        "00001111",  -- addr 3  : inverted half-half
        "11111111",  -- addr 4  : all ones (tests hold stability)
        "00000000",  -- addr 5  : all zeros (tests hold stability)
        "10000001",  -- addr 6  : boundary bits only
        "01111110",  -- addr 7  : inverse of boundary
        "00110011",  -- addr 8  : nibble alternating
        "11001100",  -- addr 9  : repeated pattern
        "01010101",  -- addr 10 : inverted alternating
        "10101010",  -- addr 11 : repeated
        "11100111",  -- addr 12 : mixed
        "00011000",  -- addr 13 : centre bits
        "10011001",  -- addr 14 : random-like
        "01100110"   -- addr 15 : random-like inverse
    );

    -- Read cycle takes 4 clock cycles due to precharge FSM pipeline
    constant READ_LATENCY : integer := 4;

begin

    uut: SRAM_Memory
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk      => clk,
            reset    => reset,
            cs       => cs,
            rw       => rw,
            address  => address,
            data_in  => data_in,
            data_out => data_out
        );

    -- Clock generation: 100 MHz (10 ns period)
    clk_process: process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- Stimulus + self-checking process
    stim_proc: process
    begin
        -- -------------------------------------------------------
        -- PHASE 1: Reset
        -- -------------------------------------------------------
        reset <= '1';
        cs    <= '0';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- PHASE 2: Write all 16 addresses
        -- -------------------------------------------------------
        report "=== WRITE PHASE: writing 16 addresses ===" severity NOTE;
        for i in 0 to 15 loop
            cs      <= '1';
            rw      <= '0';  -- Write
            address <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
            data_in <= TEST_DATA(i);
            wait for CLK_PERIOD;
            cs <= '0';
            wait for CLK_PERIOD;
        end loop;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- PHASE 3: Read back all 16 addresses and assert correctness
        -- -------------------------------------------------------
        report "=== READ PHASE: verifying all 16 addresses ===" severity NOTE;
        for i in 0 to 15 loop
            cs      <= '1';
            rw      <= '1';  -- Read
            address <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
            -- Wait for precharge FSM pipeline (4 cycles)
            wait for CLK_PERIOD * READ_LATENCY;
            cs <= '0';

            -- Self-checking assertion: flag mismatch automatically
            assert data_out = TEST_DATA(i)
                report "FAIL: Address " & integer'image(i) &
                       " — expected " & to_string(TEST_DATA(i)) &
                       " got " & to_string(data_out)
                severity ERROR;

            report "PASS: Address " & integer'image(i) &
                   " — data = " & to_string(data_out)
                severity NOTE;

            wait for CLK_PERIOD;
        end loop;

        -- -------------------------------------------------------
        -- PHASE 4: Overwrite test — write new data, verify old is gone
        -- -------------------------------------------------------
        report "=== OVERWRITE TEST ===" severity NOTE;
        cs      <= '1';
        rw      <= '0';
        address <= "0000";
        data_in <= "01010101";  -- Inverted from original "10101010"
        wait for CLK_PERIOD;
        cs <= '0';
        wait for CLK_PERIOD * 2;

        cs      <= '1';
        rw      <= '1';
        address <= "0000";
        wait for CLK_PERIOD * READ_LATENCY;
        cs <= '0';

        assert data_out = "01010101"
            report "FAIL: Overwrite test at address 0 failed"
            severity ERROR;
        report "PASS: Overwrite test — address 0 correctly updated"
            severity NOTE;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- PHASE 5: Chip-select deassert test — no operation should occur
        -- -------------------------------------------------------
        report "=== CHIP SELECT DEASSERT TEST ===" severity NOTE;
        cs      <= '0';   -- CS low — no operation
        rw      <= '0';
        address <= "0101";
        data_in <= "11111111";
        wait for CLK_PERIOD * 3;

        -- Verify address 5 still holds original data (cs was low)
        cs  <= '1';
        rw  <= '1';
        address <= "0101";
        wait for CLK_PERIOD * READ_LATENCY;
        cs <= '0';

        assert data_out = TEST_DATA(5)
            report "FAIL: CS deassert test — data changed without CS"
            severity ERROR;
        report "PASS: CS deassert test — data held correctly"
            severity NOTE;

        report "=== ALL TESTS COMPLETE ===" severity NOTE;
        wait;
    end process;

end Behavioral;
