-- Gas Pattern Recognition Engine
-- Analyzes sensor data patterns and matches against templates

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gc_package.all;

entity pattern_recognizer is
    port (
        clk                 : in  std_logic;
        rst_n               : in  std_logic;
        enable              : in  std_logic;
        
        -- Data input interface
        sensor_data         : in  sensor_array_t;
        data_valid          : in  std_logic;
        baseline_data       : in  sensor_array_t;
        
        -- Control interface
        start_analysis      : in  std_logic;
        clear_pattern       : in  std_logic;
        sensitivity_level   : in  std_logic_vector(3 downto 0);
        
        -- Template programming interface
        template_write      : in  std_logic;
        template_addr       : in  std_logic_vector(log2_ceil(NUM_TEMPLATES)-1 downto 0);
        template_data       : in  pattern_array_t;
        
        -- Results interface
        pattern_detected    : out std_logic;
        pattern_id          : out std_logic_vector(log2_ceil(NUM_TEMPLATES)-1 downto 0);
        confidence_level    : out std_logic_vector(7 downto 0);
        analysis_complete   : out std_logic;
        
        -- Debug interface
        current_pattern     : out pattern_array_t;
        match_distances     : out std_logic_vector(127 downto 0) -- 8 distances x 16 bits
    );
end entity pattern_recognizer;

architecture rtl of pattern_recognizer is
    
    -- Internal signals
    type pr_state_t is (
        PR_IDLE,
        PR_NORMALIZE,
        PR_EXTRACT_FEATURES,
        PR_COMPARE_TEMPLATES,
        PR_CALCULATE_CONFIDENCE,
        PR_OUTPUT_RESULT
    );
    
    signal state                : pr_state_t;
    signal next_state           : pr_state_t;
    
    -- Pattern storage
    signal current_pattern_int  : pattern_array_t;
    signal template_memory      : template_array_t;
    signal normalized_data      : sensor_array_t;
    
    -- Comparison logic
    signal compare_counter      : unsigned(log2_ceil(NUM_TEMPLATES)-1 downto 0);
    signal distance_array       : std_logic_vector(127 downto 0);
    signal min_distance         : integer range 0 to 2047;
    signal best_match_id        : unsigned(log2_ceil(NUM_TEMPLATES)-1 downto 0);
    signal threshold            : integer;
    
    -- Feature extraction
    signal feature_counter      : unsigned(3 downto 0);
    signal peak_detector        : std_logic_vector(NUM_SENSORS-1 downto 0);
    signal gradient_calc        : std_logic_vector(NUM_SENSORS-1 downto 0);
    
    -- Pipeline registers
    signal data_pipeline        : sensor_array_t;
    signal baseline_pipeline    : sensor_array_t;
    
begin
    
    -- Template memory write process
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            template_memory <= (others => (others => (others => '0')));
        elsif rising_edge(clk) then
            if template_write = '1' then
                template_memory(to_integer(unsigned(template_addr))) <= template_data;
            end if;
        end if;
    end process;
    
    -- Main state machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= PR_IDLE;
            compare_counter <= (others => '0');
            feature_counter <= (others => '0');
            min_distance <= 2047;
            best_match_id <= (others => '0');
            current_pattern_int <= (others => (others => '0'));
            normalized_data <= (others => (others => '0'));
            data_pipeline <= (others => (others => '0'));
            baseline_pipeline <= (others => (others => '0'));
        elsif rising_edge(clk) then
            state <= next_state;
            
            -- Pipeline input data
            if data_valid = '1' then
                data_pipeline <= sensor_data;
                baseline_pipeline <= baseline_data;
            end if;
            
            case state is
                when PR_IDLE =>
                    compare_counter <= (others => '0');
                    feature_counter <= (others => '0');
                    min_distance <= 2047;
                    best_match_id <= (others => '0');
                    
                when PR_NORMALIZE =>
                    -- Normalize sensor data against baseline
                    for i in 0 to NUM_SENSORS-1 loop
                        normalized_data(i) <= normalize_data(data_pipeline(i), baseline_pipeline(i));
                    end loop;
                    
                when PR_EXTRACT_FEATURES =>
                    -- Extract features and build pattern
                    if feature_counter < PATTERN_WIDTH then
                        feature_counter <= feature_counter + 1;
                        
                        -- Simple feature extraction: sensor ratios and peaks
                        if feature_counter < NUM_SENSORS then
                            current_pattern_int(to_integer(feature_counter)) <= 
                                normalized_data(to_integer(feature_counter));
                        elsif feature_counter < NUM_SENSORS + 4 then
                            -- Calculate gradients between adjacent sensors
                            current_pattern_int(to_integer(feature_counter)) <= 
                                std_logic_vector(
                                    unsigned(normalized_data(to_integer(feature_counter-NUM_SENSORS))) - 
                                    unsigned(normalized_data(to_integer(feature_counter-NUM_SENSORS+1)))
                                );
                        else
                            -- Statistical features (mean, variance approximation)
                            current_pattern_int(to_integer(feature_counter)) <= (others => '0');
                        end if;
                    end if;
                    
                when PR_COMPARE_TEMPLATES =>
                    if compare_counter < NUM_TEMPLATES then
                        -- Calculate Hamming distance for current template
                        declare
                            variable distance : integer;
                        begin
                            distance := hamming_distance(current_pattern_int, 
                                                       template_memory(to_integer(compare_counter)));
                            
                            -- Store distance in output array
                            distance_array(to_integer(compare_counter)*8+7 downto to_integer(compare_counter)*8) <= 
                                std_logic_vector(to_unsigned(distance mod 256, 8));
                            
                            -- Track minimum distance
                            if distance < min_distance then
                                min_distance <= distance;
                                best_match_id <= compare_counter;
                            end if;
                        end;
                        
                        compare_counter <= compare_counter + 1;
                    end if;
                    
                when PR_CALCULATE_CONFIDENCE =>
                    -- Calculate confidence based on distance and sensitivity
                    null; -- Implemented in combinational logic below
                    
                when PR_OUTPUT_RESULT =>
                    null; -- Results are output continuously
                    
                when others =>
                    null;
            end case;
        end if;
    end process;
    
    -- Next state logic
    process(state, enable, start_analysis, data_valid, feature_counter, compare_counter)
    begin
        next_state <= state;
        
        case state is
            when PR_IDLE =>
                if enable = '1' and start_analysis = '1' and data_valid = '1' then
                    next_state <= PR_NORMALIZE;
                end if;
                
            when PR_NORMALIZE =>
                next_state <= PR_EXTRACT_FEATURES;
                
            when PR_EXTRACT_FEATURES =>
                if feature_counter >= PATTERN_WIDTH then
                    next_state <= PR_COMPARE_TEMPLATES;
                end if;
                
            when PR_COMPARE_TEMPLATES =>
                if compare_counter >= NUM_TEMPLATES then
                    next_state <= PR_CALCULATE_CONFIDENCE;
                end if;
                
            when PR_CALCULATE_CONFIDENCE =>
                next_state <= PR_OUTPUT_RESULT;
                
            when PR_OUTPUT_RESULT =>
                next_state <= PR_IDLE;
                
            when others =>
                next_state <= PR_IDLE;
        end case;
    end process;
    
    -- Threshold calculation based on sensitivity
    threshold <= 32 when sensitivity_level = "0000" else  -- Very sensitive
                 64 when sensitivity_level = "0001" else
                 96 when sensitivity_level = "0010" else
                 128 when sensitivity_level = "0011" else
                 160 when sensitivity_level = "0100" else
                 192 when sensitivity_level = "0101" else
                 224 when sensitivity_level = "0110" else
                 256; -- Least sensitive
    
    -- Confidence calculation
    process(min_distance, threshold)
        variable confidence : integer;
    begin
        if min_distance < threshold then
            confidence := ((threshold - min_distance) * 255) / threshold;
            if confidence > 255 then
                confidence := 255;
            end if;
        else
            confidence := 0;
        end if;
        confidence_level <= std_logic_vector(to_unsigned(confidence, 8));
    end process;
    
    -- Output assignments
    pattern_detected <= '1' when min_distance < threshold and state = PR_OUTPUT_RESULT else '0';
    pattern_id <= std_logic_vector(best_match_id);
    analysis_complete <= '1' when state = PR_OUTPUT_RESULT else '0';
    current_pattern <= current_pattern_int;
    match_distances <= distance_array;
    
end architecture rtl;
