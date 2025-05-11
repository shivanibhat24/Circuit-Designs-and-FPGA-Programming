library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DigitalSignalSanitizer is
    Generic (
        DATA_WIDTH      : integer := 16;      -- Width of input/output data
        FILTER_ORDER    : integer := 32;      -- FIR filter order (taps)
        THRESHOLD_VALUE : integer := 100      -- Threshold for spike detection
    );
    Port (
        clk             : in  STD_LOGIC;                                -- System clock
        rst             : in  STD_LOGIC;                                -- Reset signal
        data_in         : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);  -- Input signal data
        data_valid_in   : in  STD_LOGIC;                                -- Input data valid flag
        data_out        : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);  -- Output clean signal
        data_valid_out  : out STD_LOGIC;                                -- Output data valid flag
        signal_locked   : out STD_LOGIC;                                -- Indicates steady signal lock
        tamper_detected : out STD_LOGIC                                 -- Indicates possible tampering
    );
end DigitalSignalSanitizer;

architecture Behavioral of DigitalSignalSanitizer is
    -- Signal shift register for FIR filtering
    type shift_register_type is array (0 to FILTER_ORDER-1) of SIGNED(DATA_WIDTH-1 downto 0);
    signal shift_reg : shift_register_type := (others => (others => '0'));
    
    -- FIR filter coefficients (low-pass filter, normalized to 1.0)
    -- These would typically be calculated based on the desired cutoff frequency
    type coefficient_array is array (0 to FILTER_ORDER-1) of SIGNED(15 downto 0);
    constant FIR_COEFF : coefficient_array := (
        to_signed(100, 16),  to_signed(150, 16),  to_signed(200, 16),  to_signed(250, 16),
        to_signed(300, 16),  to_signed(350, 16),  to_signed(400, 16),  to_signed(450, 16),
        to_signed(500, 16),  to_signed(550, 16),  to_signed(600, 16),  to_signed(650, 16),
        to_signed(700, 16),  to_signed(750, 16),  to_signed(800, 16),  to_signed(850, 16),
        to_signed(850, 16),  to_signed(800, 16),  to_signed(750, 16),  to_signed(700, 16),
        to_signed(650, 16),  to_signed(600, 16),  to_signed(550, 16),  to_signed(500, 16),
        to_signed(450, 16),  to_signed(400, 16),  to_signed(350, 16),  to_signed(300, 16),
        to_signed(250, 16),  to_signed(200, 16),  to_signed(150, 16),  to_signed(100, 16)
    );
    
    -- Median filter buffer
    constant MEDIAN_WINDOW : integer := 5;
    type median_buffer_type is array (0 to MEDIAN_WINDOW-1) of SIGNED(DATA_WIDTH-1 downto 0);
    signal median_buffer : median_buffer_type := (others => (others => '0'));
    
    -- Signal statistics tracking
    signal signal_mean        : SIGNED(DATA_WIDTH+7 downto 0) := (others => '0');  -- Extra bits for accumulation
    signal signal_variance    : UNSIGNED(DATA_WIDTH*2-1 downto 0) := (others => '0');
    signal prev_sample        : SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');
    signal sample_count       : UNSIGNED(9 downto 0) := (others => '0');  -- Count up to 1024 samples
    
    -- Signal processing flags
    signal spike_detected     : STD_LOGIC := '0';
    signal noise_level_high   : STD_LOGIC := '0';
    signal filter_output      : SIGNED(DATA_WIDTH+15 downto 0) := (others => '0');  -- Extra bits for multiplication
    signal filtered_data      : SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');
    signal median_data        : SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');
    signal processed_data     : SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');
    
    -- Pipeline signals
    signal data_valid_pipe    : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal lock_counter       : UNSIGNED(7 downto 0) := (others => '0');
    signal tamper_counter     : UNSIGNED(7 downto 0) := (others => '0');
    
    -- Function to sort and find median
    function find_median(window: median_buffer_type) return SIGNED is
        variable sorted : median_buffer_type;
        variable temp   : SIGNED(DATA_WIDTH-1 downto 0);
    begin
        -- Copy input array to sorting array
        sorted := window;
        
        -- Simple bubble sort (efficient for small arrays)
        for i in 0 to MEDIAN_WINDOW-2 loop
            for j in 0 to MEDIAN_WINDOW-2-i loop
                if sorted(j) > sorted(j+1) then
                    temp := sorted(j);
                    sorted(j) := sorted(j+1);
                    sorted(j+1) := temp;
                end if;
            end loop;
        end loop;
        
        -- Return the middle element
        return sorted(MEDIAN_WINDOW/2);
    end function;

begin
    -- Main processing block
    process(clk)
        variable sum : SIGNED(DATA_WIDTH+15 downto 0);
        variable diff : SIGNED(DATA_WIDTH downto 0);
        variable abs_diff : UNSIGNED(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset all registers and state
                shift_reg <= (others => (others => '0'));
                median_buffer <= (others => (others => '0'));
                signal_mean <= (others => '0');
                signal_variance <= (others => '0');
                sample_count <= (others => '0');
                spike_detected <= '0';
                noise_level_high <= '0';
                data_valid_pipe <= (others => '0');
                lock_counter <= (others => '0');
                tamper_counter <= (others => '0');
                signal_locked <= '0';
                tamper_detected <= '0';
                data_out <= (others => '0');
                data_valid_out <= '0';
            else
                -- Shift the data valid pipeline
                data_valid_pipe <= data_valid_pipe(2 downto 0) & data_valid_in;
                
                if data_valid_in = '1' then
                    -- Stage 1: Shift register update for FIR filter
                    for i in FILTER_ORDER-1 downto 1 loop
                        shift_reg(i) <= shift_reg(i-1);
                    end loop;
                    shift_reg(0) <= SIGNED(data_in);
                    
                    -- Calculate difference from previous sample for spike detection
                    diff := resize(SIGNED(data_in), DATA_WIDTH+1) - resize(prev_sample, DATA_WIDTH+1);
                    if diff < 0 then
                        abs_diff := UNSIGNED(- diff(DATA_WIDTH-1 downto 0));
                    else
                        abs_diff := UNSIGNED(diff(DATA_WIDTH-1 downto 0));
                    end if;
                    
                    -- Spike detection
                    if abs_diff > THRESHOLD_VALUE then
                        spike_detected <= '1';
                        tamper_counter <= tamper_counter + 1;
                    else
                        spike_detected <= '0';
                        if tamper_counter > 0 then
                            tamper_counter <= tamper_counter - 1;
                        end if;
                    end if;
                    
                    -- Update previous sample
                    prev_sample <= SIGNED(data_in);
                    
                    -- Update running statistics
                    if sample_count < 1023 then
                        sample_count <= sample_count + 1;
                        signal_mean <= signal_mean + resize(SIGNED(data_in), DATA_WIDTH+8);
                    else
                        -- Update exponential moving average of mean
                        signal_mean <= signal_mean - signal_mean(signal_mean'high downto 10) + resize(SIGNED(data_in), DATA_WIDTH+8);
                    end if;
                    
                    -- FIR filter calculation
                    sum := (others => '0');
                    for i in 0 to FILTER_ORDER-1 loop
                        sum := sum + resize(shift_reg(i) * FIR_COEFF(i), DATA_WIDTH+16);
                    end loop;
                    filter_output <= sum;
                end if;
                
                -- Stage 2: Convert FIR filter output to correct range
                if data_valid_pipe(0) = '1' then
                    -- Normalize the filter output (divide by a power of 2)
                    filtered_data <= filter_output(filter_output'high downto 16);
                    
                    -- Update median filter buffer
                    for i in MEDIAN_WINDOW-1 downto 1 loop
                        median_buffer(i) <= median_buffer(i-1);
                    end loop;
                    median_buffer(0) <= filtered_data;
                end if;
                
                -- Stage 3: Calculate median and choose processing path
                if data_valid_pipe(1) = '1' then
                    -- Find median value
                    median_data <= find_median(median_buffer);
                    
                    -- Decide which signal to use based on detection flags
                    if spike_detected = '1' then
                        -- Use median filter output if spike detected
                        processed_data <= median_data;
                    else
                        -- Use FIR filter output in normal conditions
                        processed_data <= filtered_data;
                    end if;
                end if;
                
                -- Stage 4: Final output stage
                if data_valid_pipe(2) = '1' then
                    -- Output the processed data
                    data_out <= STD_LOGIC_VECTOR(processed_data);
                    data_valid_out <= '1';
                    
                    -- Update lock status - increase counter when stable
                    if spike_detected = '0' and noise_level_high = '0' then
                        if lock_counter < 255 then
                            lock_counter <= lock_counter + 1;
                        end if;
                    else
                        if lock_counter > 0 then
                            lock_counter <= lock_counter - 1;
                        end if;
                    end if;
                    
                    -- Set output flags based on counters
                    if lock_counter > 200 then
                        signal_locked <= '1';
                    else
                        signal_locked <= '0';
                    end if;
                    
                    if tamper_counter > 50 then
                        tamper_detected <= '1';
                    else
                        tamper_detected <= '0';
                    end if;
                else
                    data_valid_out <= '0';
                end if;
            end if;
        end if;
    end process;

end Behavioral;
