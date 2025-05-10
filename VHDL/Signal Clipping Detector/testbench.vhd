library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SignalClippingDetector_TB is
end SignalClippingDetector_TB;

architecture Behavioral of SignalClippingDetector_TB is
    -- Component declaration
    component SignalClippingDetector is
        Generic (
            DATA_WIDTH      : integer := 16;
            THRESHOLD       : integer := 30000;
            COUNT_THRESHOLD : integer := 10;
            COUNT_WIDTH     : integer := 8
        );
        Port (
            clk             : in  STD_LOGIC;
            rst             : in  STD_LOGIC;
            data_in         : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            clip_detect     : out STD_LOGIC;
            clip_counter    : out STD_LOGIC_VECTOR(COUNT_WIDTH-1 downto 0)
        );
    end component;
    
    -- Constants
    constant CLK_PERIOD     : time := 10 ns;  -- 100 MHz clock
    constant DATA_WIDTH     : integer := 16;
    constant THRESHOLD      : integer := 30000;
    constant COUNT_THRESHOLD : integer := 10;
    constant COUNT_WIDTH    : integer := 8;
    
    -- Signals
    signal clk              : std_logic := '0';
    signal rst              : std_logic := '1';
    signal data_in          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal clip_detect      : std_logic;
    signal clip_counter     : std_logic_vector(COUNT_WIDTH-1 downto 0);
    
    -- Test control
    signal sim_done         : boolean := false;
    
begin
    -- Instantiate the Unit Under Test (UUT)
    UUT: SignalClippingDetector
        generic map (
            DATA_WIDTH      => DATA_WIDTH,
            THRESHOLD       => THRESHOLD,
            COUNT_THRESHOLD => COUNT_THRESHOLD,
            COUNT_WIDTH     => COUNT_WIDTH
        )
        port map (
            clk             => clk,
            rst             => rst,
            data_in         => data_in,
            clip_detect     => clip_detect,
            clip_counter    => clip_counter
        );
        
    -- Clock generation process
    clk_proc: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Reset
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 2;
        
        -- Test 1: Normal operation (no clipping)
        for i in 1 to 20 loop
            data_in <= std_logic_vector(to_signed(20000, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Test 2: Brief clipping (not enough to trigger detection)
        for i in 1 to 5 loop
            data_in <= std_logic_vector(to_signed(32000, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Back to normal signal
        for i in 1 to 5 loop
            data_in <= std_logic_vector(to_signed(15000, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Test 3: Sustained clipping (should trigger detection)
        for i in 1 to 15 loop
            data_in <= std_logic_vector(to_signed(32000, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Test 4: Negative clipping
        for i in 1 to 15 loop
            data_in <= std_logic_vector(to_signed(-31000, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Back to normal
        for i in 1 to 10 loop
            data_in <= std_logic_vector(to_signed(10000, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        wait for CLK_PERIOD * 10;
        
        -- End simulation
        sim_done <= true;
        wait;
    end process;
    
end Behavioral;
