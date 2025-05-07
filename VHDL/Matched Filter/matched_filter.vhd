library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity matched_filter is
    generic (
        -- Filter coefficient width
        COEFF_WIDTH : integer := 16;
        -- Input signal width
        DATA_WIDTH : integer := 16;
        -- Number of taps in the filter
        FILTER_TAPS : integer := 16;
        -- Output width = DATA_WIDTH + COEFF_WIDTH + log2(FILTER_TAPS)
        OUTPUT_WIDTH : integer := 36
    );
    port (
        -- Clock and reset
        clk : in std_logic;
        rst : in std_logic;
        
        -- Input signal
        signal_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_in : in std_logic;
        
        -- Output signal
        signal_out : out std_logic_vector(OUTPUT_WIDTH-1 downto 0);
        valid_out : out std_logic;
        
        -- Detection threshold
        threshold : in std_logic_vector(OUTPUT_WIDTH-1 downto 0);
        
        -- Detection signal
        detection : out std_logic
    );
end matched_filter;

architecture Behavioral of matched_filter is
    -- Define the coefficients type
    type coefficient_array is array (0 to FILTER_TAPS-1) of signed(COEFF_WIDTH-1 downto 0);
    
    -- Filter coefficients - these would be the time-reversed expected signal shape
    -- Example coefficients: modify these according to your specific pulse shape
    constant COEFFS : coefficient_array := (
        to_signed(100, COEFF_WIDTH),    -- Coefficient 0
        to_signed(300, COEFF_WIDTH),    -- Coefficient 1
        to_signed(500, COEFF_WIDTH),    -- Coefficient 2
        to_signed(700, COEFF_WIDTH),    -- Coefficient 3
        to_signed(900, COEFF_WIDTH),    -- Coefficient 4
        to_signed(1100, COEFF_WIDTH),   -- Coefficient 5
        to_signed(1300, COEFF_WIDTH),   -- Coefficient 6
        to_signed(1500, COEFF_WIDTH),   -- Coefficient 7
        to_signed(1500, COEFF_WIDTH),   -- Coefficient 8
        to_signed(1300, COEFF_WIDTH),   -- Coefficient 9
        to_signed(1100, COEFF_WIDTH),   -- Coefficient 10
        to_signed(900, COEFF_WIDTH),    -- Coefficient 11
        to_signed(700, COEFF_WIDTH),    -- Coefficient 12
        to_signed(500, COEFF_WIDTH),    -- Coefficient 13
        to_signed(300, COEFF_WIDTH),    -- Coefficient 14
        to_signed(100, COEFF_WIDTH)     -- Coefficient 15
    );
    
    -- Shift register for input samples
    type shift_register_type is array (0 to FILTER_TAPS-1) of signed(DATA_WIDTH-1 downto 0);
    signal shift_reg : shift_register_type := (others => (others => '0'));
    
    -- Products of each tap
    type product_array is array (0 to FILTER_TAPS-1) of signed(DATA_WIDTH+COEFF_WIDTH-1 downto 0);
    signal products : product_array := (others => (others => '0'));
    
    -- Sum of products (filter output)
    signal sum : signed(OUTPUT_WIDTH-1 downto 0) := (others => '0');
    
    -- Valid signal propagation
    signal valid_pipe : std_logic_vector(2 downto 0) := (others => '0');
    
begin
    -- Main process for the filter operations
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset conditions
                shift_reg <= (others => (others => '0'));
                products <= (others => (others => '0'));
                sum <= (others => '0');
                valid_pipe <= (others => '0');
                valid_out <= '0';
                detection <= '0';
            else
                -- Input stage - shift the register when new data is valid
                if valid_in = '1' then
                    -- Shift in new sample
                    shift_reg(0) <= signed(signal_in);
                    for i in 1 to FILTER_TAPS-1 loop
                        shift_reg(i) <= shift_reg(i-1);
                    end loop;
                    
                    -- Delay the valid signal
                    valid_pipe(0) <= '1';
                else
                    valid_pipe(0) <= '0';
                end if;
                
                -- Multiplication stage
                for i in 0 to FILTER_TAPS-1 loop
                    products(i) <= shift_reg(i) * COEFFS(i);
                end loop;
                valid_pipe(1) <= valid_pipe(0);
                
                -- Accumulation stage
                if valid_pipe(1) = '1' then
                    -- Sum all products
                    sum <= (others => '0'); -- Reset sum
                    for i in 0 to FILTER_TAPS-1 loop
                        sum <= sum + resize(products(i), OUTPUT_WIDTH);
                    end loop;
                end if;
                valid_pipe(2) <= valid_pipe(1);
                
                -- Output stage
                valid_out <= valid_pipe(2);
                
                -- Detection logic - check if output exceeds threshold
                if valid_pipe(2) = '1' then
                    if abs(sum) > signed(threshold) then
                        detection <= '1';
                    else
                        detection <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Connect the sum to output signal
    signal_out <= std_logic_vector(sum);

end Behavioral;
