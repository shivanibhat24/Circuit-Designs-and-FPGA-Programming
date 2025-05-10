library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SignalClippingDetector is
    Generic (
        DATA_WIDTH      : integer := 16;       -- Width of input data
        THRESHOLD       : integer := 30000;    -- Clipping threshold (can be adjusted)
        COUNT_THRESHOLD : integer := 10;       -- Number of consecutive clipping samples required to trigger
        COUNT_WIDTH     : integer := 8         -- Width of counter register
    );
    Port (
        clk             : in  STD_LOGIC;                           -- System clock
        rst             : in  STD_LOGIC;                           -- Asynchronous reset
        data_in         : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0); -- Input signal
        clip_detect     : out STD_LOGIC;                           -- Clipping detection flag
        clip_counter    : out STD_LOGIC_VECTOR(COUNT_WIDTH-1 downto 0) -- Counter showing number of consecutive clipping events
    );
end SignalClippingDetector;

architecture Behavioral of SignalClippingDetector is
    signal abs_value       : unsigned(DATA_WIDTH-1 downto 0);
    signal is_clipping     : std_logic;
    signal clip_count      : unsigned(COUNT_WIDTH-1 downto 0);
    signal clipping_output : std_logic;
begin
    -- Calculate absolute value of input signal
    abs_value <= unsigned(data_in) when data_in(DATA_WIDTH-1) = '0' else
                 unsigned(not data_in) + 1; -- Two's complement for negative numbers
                 
    -- Detect if signal is above threshold
    is_clipping <= '1' when abs_value >= THRESHOLD else '0';

    -- Process for counting consecutive clipping events
    process(clk, rst)
    begin
        if rst = '1' then
            clip_count <= (others => '0');
            clipping_output <= '0';
        elsif rising_edge(clk) then
            if is_clipping = '1' then
                -- Increment counter if not already at max value
                if clip_count < (2**COUNT_WIDTH)-1 then
                    clip_count <= clip_count + 1;
                end if;
                
                -- Set output flag if counter exceeds threshold
                if clip_count >= COUNT_THRESHOLD-1 then
                    clipping_output <= '1';
                end if;
            else
                -- Reset counter and flag when signal is below threshold
                clip_count <= (others => '0');
                clipping_output <= '0';
            end if;
        end if;
    end process;

    -- Assign outputs
    clip_detect <= clipping_output;
    clip_counter <= std_logic_vector(clip_count);
    
end Behavioral;
