library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FrequencyAnomalyDetector is
    Generic (
        DATA_WIDTH      : integer := 16;       -- Input data width
        FFT_SIZE        : integer := 1024;     -- FFT size (power of 2)
        THRESHOLD_MULT  : integer := 3;        -- Multiplier for threshold (e.g., 3 means 3x avg)
        WINDOW_SIZE     : integer := 10;       -- Size of averaging window
        ANOMALY_COUNT   : integer := 5         -- Number of bins above threshold to trigger anomaly
    );
    Port (
        clk             : in  STD_LOGIC;                              -- System clock
        rst             : in  STD_LOGIC;                              -- Reset
        fft_valid       : in  STD_LOGIC;                              -- FFT output valid flag
        fft_data_re     : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);-- Real part of FFT output
        fft_data_im     : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);-- Imaginary part of FFT output
        bin_index       : in  STD_LOGIC_VECTOR(log2(FFT_SIZE)-1 downto 0);-- Current FFT bin
        
        anomaly_detected: out STD_LOGIC;                              -- Anomaly detection flag
        anomaly_bin     : out STD_LOGIC_VECTOR(log2(FFT_SIZE)-1 downto 0);-- Bin with highest anomaly
        anomaly_strength: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) -- Strength of the anomaly
    );
end FrequencyAnomalyDetector;

architecture Behavioral of FrequencyAnomalyDetector is
    -- Function to calculate log2 (ceiling)
    function log2(val: integer) return integer is
        variable res : integer;
    begin
        res := 0;
        while (2**res < val) loop
            res := res + 1;
        end loop;
        return res;
    end function;
    
    -- Types for storing spectrum and baseline
    type magnitude_array is array (0 to FFT_SIZE-1) of unsigned(DATA_WIDTH-1 downto 0);
    type baseline_array is array (0 to FFT_SIZE-1) of unsigned(DATA_WIDTH+log2(WINDOW_SIZE)-1 downto 0);
    
    -- Current magnitude spectrum
    signal current_spectrum : magnitude_array := (others => (others => '0'));
    
    -- Baseline (averaged) spectrum
    signal baseline_spectrum : baseline_array := (others => (others => '0'));
    
    -- History buffer for moving average
    type history_buffer is array (0 to WINDOW_SIZE-1) of magnitude_array;
    signal spectrum_history : history_buffer := (others => (others => (others => '0')));
    
    -- Counters and control signals
    signal history_index : integer range 0 to WINDOW_SIZE-1 := 0;
    signal history_valid : std_logic := '0';
    signal bin_count : integer range 0 to FFT_SIZE := 0;
    signal anomaly_count : integer range 0 to FFT_SIZE := 0;
    signal max_deviation : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    signal max_deviation_bin : unsigned(log2(FFT_SIZE)-1 downto 0) := (others => '0');
    
    -- Intermediate signals
    signal magnitude : unsigned(DATA_WIDTH-1 downto 0);
    signal bin_idx : integer range 0 to FFT_SIZE-1;
    signal threshold : unsigned(DATA_WIDTH-1 downto 0);
    
begin
    -- Convert bin_index to integer for easier indexing
    bin_idx <= to_integer(unsigned(bin_index));
    
    -- Calculate magnitude of complex FFT output (approximation: |z| ≈ max(|re|, |im|) + 0.5*min(|re|, |im|))
    -- This approximation avoids needing a square root operation
    process(fft_data_re, fft_data_im)
        variable re_abs, im_abs : unsigned(DATA_WIDTH-1 downto 0);
        variable max_val, min_val : unsigned(DATA_WIDTH-1 downto 0);
        variable half_min : unsigned(DATA_WIDTH-1 downto 0);
    begin
        -- Get absolute values
        if fft_data_re(DATA_WIDTH-1) = '1' then
            re_abs := unsigned(not fft_data_re) + 1;
        else
            re_abs := unsigned(fft_data_re);
        end if;
        
        if fft_data_im(DATA_WIDTH-1) = '1' then
            im_abs := unsigned(not fft_data_im) + 1;
        else
            im_abs := unsigned(fft_data_im);
        end if;
        
        -- Find max and min
        if re_abs > im_abs then
            max_val := re_abs;
            min_val := im_abs;
        else
            max_val := im_abs;
            min_val := re_abs;
        end if;
        
        -- Calculate approximation
        half_min := '0' & min_val(DATA_WIDTH-1 downto 1); -- Divide by 2
        magnitude <= max_val + half_min;
    end process;

    -- Main process to update spectrum and detect anomalies
    process(clk)
        variable sum : unsigned(DATA_WIDTH+log2(WINDOW_SIZE)-1 downto 0);
        variable deviation : unsigned(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset all signals
                current_spectrum <= (others => (others => '0'));
                baseline_spectrum <= (others => (others => '0'));
                spectrum_history <= (others => (others => (others => '0')));
                history_index <= 0;
                history_valid <= '0';
                bin_count <= 0;
                anomaly_count <= 0;
                max_deviation <= (others => '0');
                max_deviation_bin <= (others => '0');
                anomaly_detected <= '0';
                anomaly_bin <= (others => '0');
                anomaly_strength <= (others => '0');
            else
                -- Process valid FFT data
                if fft_valid = '1' then
                    -- Store current magnitude in spectrum
                    current_spectrum(bin_idx) <= magnitude;
                    
                    -- Store in history buffer
                    spectrum_history(history_index)(bin_idx) <= magnitude;
                    
                    -- Check if we've completed processing all bins
                    if bin_idx = FFT_SIZE-1 then
                        -- Move to next index in history buffer
                        if history_index = WINDOW_SIZE-1 then
                            history_index <= 0;
                        else
                            history_index <= history_index + 1;
                        end if;
                        
                        -- Mark history as valid after first complete cycle
                        if history_valid = '0' and history_index = WINDOW_SIZE-1 then
                            history_valid <= '1';
                        end if;
                        
                        -- Reset bin counter and anomaly detection
                        bin_count <= 0;
                        anomaly_count <= 0;
                        max_deviation <= (others => '0');
                        max_deviation_bin <= (others => '0');
                        anomaly_detected <= '0';
                    else
                        bin_count <= bin_count + 1;
                    end if;
                    
                    -- Update baseline for this bin and check for anomalies
                    if history_valid = '1' then
                        -- Calculate sum for this bin across history
                        sum := (others => '0');
                        for i in 0 to WINDOW_SIZE-1 loop
                            sum := sum + resize(spectrum_history(i)(bin_idx), sum'length);
                        end loop;
                        
                        -- Update baseline (moving average)
                        baseline_spectrum(bin_idx) <= sum;
                        
                        -- Calculate threshold (baseline average * THRESHOLD_MULT)
                        threshold <= resize(sum / WINDOW_SIZE, threshold'length) * THRESHOLD_MULT;
                        
                        -- Compare current value with threshold
                        if magnitude > threshold then
                            -- Anomaly detected in this bin
                            anomaly_count <= anomaly_count + 1;
                            
                            -- Calculate deviation (magnitude - baseline average)
                            deviation := magnitude - resize(sum / WINDOW_SIZE, deviation'length);
                            
                            -- Update maximum deviation if this is higher
                            if deviation > max_deviation then
                                max_deviation <= deviation;
                                max_deviation_bin <= to_unsigned(bin_idx, max_deviation_bin'length);
                            end if;
                        end if;
                        
                        -- Check if we've detected enough anomalies to trigger
                        if anomaly_count >= ANOMALY_COUNT then
                            anomaly_detected <= '1';
                            anomaly_bin <= std_logic_vector(max_deviation_bin);
                            anomaly_strength <= std_logic_vector(max_deviation);
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;

-- Test bench for Frequency Anomaly Detector
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL; -- For sine/cosine in test stimulus

entity FrequencyAnomalyDetector_tb is
-- Testbench has no ports
end FrequencyAnomalyDetector_tb;

architecture Behavioral of FrequencyAnomalyDetector_tb is
    -- Constants
    constant CLK_PERIOD : time := 10 ns;
    constant DATA_WIDTH : integer := 16;
    constant FFT_SIZE   : integer := 128; -- Smaller size for simulation
    
    -- Helper function to calculate log2 (ceiling)
    function log2(val: integer) return integer is
        variable res : integer;
    begin
        res := 0;
        while (2**res < val) loop
            res := res + 1;
        end loop;
        return res;
    end function;
    
    -- Clock and reset signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    
    -- Input signals
    signal fft_valid : std_logic := '0';
    signal fft_data_re : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal fft_data_im : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal bin_index : std_logic_vector(log2(FFT_SIZE)-1 downto 0) := (others => '0');
    
    -- Output signals
    signal anomaly_detected : std_logic;
    signal anomaly_bin : std_logic_vector(log2(FFT_SIZE)-1 downto 0);
    signal anomaly_strength : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Test signals
    signal sim_done : boolean := false;
    signal current_bin : integer := 0;
    signal frame_count : integer := 0;
    
    -- Component declaration
    component FrequencyAnomalyDetector
        Generic (
            DATA_WIDTH      : integer;
            FFT_SIZE        : integer;
            THRESHOLD_MULT  : integer;
            WINDOW_SIZE     : integer;
            ANOMALY_COUNT   : integer
        );
        Port (
            clk             : in  STD_LOGIC;
            rst             : in  STD_LOGIC;
            fft_valid       : in  STD_LOGIC;
            fft_data_re     : in  STD_LOGIC_VECTOR;
            fft_data_im     : in  STD_LOGIC_VECTOR;
            bin_index       : in  STD_LOGIC_VECTOR;
            anomaly_detected: out STD_LOGIC;
            anomaly_bin     : out STD_LOGIC_VECTOR;
            anomaly_strength: out STD_LOGIC_VECTOR
        );
    end component;
    
begin
    -- DUT instantiation
    DUT: FrequencyAnomalyDetector
        generic map (
            DATA_WIDTH      => DATA_WIDTH,
            FFT_SIZE        => FFT_SIZE,
            THRESHOLD_MULT  => 3,
            WINDOW_SIZE     => 5,
            ANOMALY_COUNT   => 3
        )
        port map (
            clk             => clk,
            rst             => rst,
            fft_valid       => fft_valid,
            fft_data_re     => fft_data_re,
            fft_data_im     => fft_data_im,
            bin_index       => bin_index,
            anomaly_detected => anomaly_detected,
            anomaly_bin     => anomaly_bin,
            anomaly_strength => anomaly_strength
        );
    
    -- Clock generation
    clk <= not clk after CLK_PERIOD/2 when not sim_done else '0';
    
    -- Stimulus process
    stimulus: process
        variable seed1, seed2 : positive := 1;
        variable rand : real;
        variable int_rand : integer;
        
        -- Function to generate FFT-like data with specified noise level and anomaly
        procedure generate_fft_frame(
            anomaly_present : in boolean;
            anomaly_bin_pos : in integer;
            anomaly_strength_factor : in real
        ) is
            variable amplitude : real;
            variable noise : real;
            variable re, im : real;
            variable anomaly_added : boolean := false;
        begin
            current_bin <= 0;
            
            for i in 0 to FFT_SIZE-1 loop
                -- Base signal: declining amplitude with frequency + noise
                amplitude := 1000.0 * (1.0 - real(i)/real(FFT_SIZE)) + 100.0;
                
                -- Add noise
                uniform(seed1, seed2, rand);
                noise := (rand - 0.5) * 200.0;
                
                -- Add anomaly if requested
                if anomaly_present and i = anomaly_bin_pos then
                    amplitude := amplitude * anomaly_strength_factor;
                    anomaly_added := true;
                end if;
                
                -- Convert to rectangular form with random phase
                uniform(seed1, seed2, rand);
                re := (amplitude + noise) * cos(rand * 2.0 * MATH_PI);
                im := (amplitude + noise) * sin(rand * 2.0 * MATH_PI);
                
                -- Wait for clock
                wait until rising_edge(clk);
                
                -- Set bin index and FFT values
                bin_index <= std_logic_vector(to_unsigned(i, bin_index'length));
                
                -- Convert real values to fixed-point representation
                if re >= 0.0 then
                    fft_data_re <= std_logic_vector(to_unsigned(integer(re), DATA_WIDTH));
                else
                    fft_data_re <= std_logic_vector(to_signed(integer(re), DATA_WIDTH));
                end if;
                
                if im >= 0.0 then
                    fft_data_im <= std_logic_vector(to_unsigned(integer(im), DATA_WIDTH));
                else
                    fft_data_im <= std_logic_vector(to_signed(integer(im), DATA_WIDTH));
                end if;
                
                fft_valid <= '1';
                current_bin <= i;
                
                -- Wait one clock for data to be processed
                wait until rising_edge(clk);
            end loop;
            
            -- Record that we've sent a frame
            frame_count <= frame_count + 1;
            
            -- Deassert valid signal
            fft_valid <= '0';
            
            -- Small delay between frames
            wait for CLK_PERIOD * 5;
            
            if anomaly_added then
                report "Added anomaly at bin " & integer'image(anomaly_bin_pos) 
                      & " with strength factor " & real'image(anomaly_strength_factor);
            end if;
        end procedure;
        
    begin
        -- Initialize
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD * 5;
        
        report "Starting simulation...";
        
        -- Send normal frames to establish baseline
        for i in 1 to 10 loop
            report "Generating normal frame " & integer'image(i);
            generate_fft_frame(false, 0, 1.0);
            wait for CLK_PERIOD * 10;
        end loop;
        
        -- Send frame with anomaly
        report "Generating frame with anomaly";
        generate_fft_frame(true, 40, 5.0);
        wait for CLK_PERIOD * 20;
        
        -- Send more normal frames
        for i in 1 to 5 loop
            report "Generating post-anomaly normal frame " & integer'image(i);
            generate_fft_frame(false, 0, 1.0);
            wait for CLK_PERIOD * 10;
        end loop;
        
        -- Send stronger anomaly
        report "Generating frame with stronger anomaly";
        generate_fft_frame(true, 60, 8.0);
        wait for CLK_PERIOD * 20;
        
        -- End simulation
        report "Simulation complete";
        sim_done <= true;
        wait;
    end process;
    
    -- Monitor process to check for anomaly detection
    monitor: process
    begin
        wait until rising_edge(clk);
        if anomaly_detected = '1' then
            report "ANOMALY DETECTED! Bin: " & integer'image(to_integer(unsigned(anomaly_bin))) 
                  & ", Strength: " & integer'image(to_integer(unsigned(anomaly_strength)));
        end if;
        
        if sim_done then
            wait;
        end if;
    end process;
    
end Behavioral;
