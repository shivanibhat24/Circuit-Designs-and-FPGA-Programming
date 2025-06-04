-- Gas Chromatography Core Module
-- Integrates sensor sequencing, data processing, and pattern recognition

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gc_package.all;

entity gc_core is
    port (
        clk                 : in  std_logic;
        rst_n               : in  std_logic;
        
        -- Control interface
        gc_control          : in  gc_control_t;
        gc_status           : out gc_status_t;
        
        -- Configuration
        sample_rate_div     : in  std_logic_vector(15 downto 0);
        sensitivity_level   : in  std_logic_vector(3 downto 0);
        num_samples         : in  std_logic_vector(15 downto 0);
        
        -- ADC interface
        adc_interface       : out adc_interface_t;
        adc_miso            : in  std_logic;
        
        -- Sensor multiplexer
        sensor_select       : out std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
        sensor_enable       : out std_logic;
        
        -- Results interface
        pattern_detected    : out std_logic;
        pattern_id          : out std_logic_vector(log2_ceil(NUM_TEMPLATES)-1 downto 0);
        confidence_level    : out std_logic_vector(7 downto 0);
        
        -- Memory interface for templates and data
        mem_addr            : out std_logic_vector(15 downto 0);
        mem_data_out        : out std_logic_vector(31 downto 0);
        mem_data_in         : in  std_logic_vector(31 downto 0);
        mem_we              : out std_logic;
        mem_re              : out std_logic;
        
        -- Debug and monitoring
        current_sensor      : out std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
        sample_count        : out std_logic_vector(15 downto 0);
        debug_pattern       : out pattern_array_t
    );
end entity gc_core;

architecture rtl of gc_core is
    
    -- Component instantiations
    component sensor_sequencer is
        port (
            clk             : in  std_logic;
            rst_n           : in  std_logic;
            enable          : in  std_logic;
            start_sequence  : in  std_logic;
            sequence_done   : out std_logic;
            current_sensor  : out std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
            adc_cs_n        : out std_logic;
            adc_sclk        : out std_logic;
            adc_mosi        : out std_logic;
            adc_miso        : in  std_logic;
            adc_conv_start  : out std_logic;
            adc_busy        : in  std_logic;
            sensor_select   : out std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
            sensor_enable   : out std_logic;
            sensor_data     : out sensor_array_t;
            data_valid      : out std_logic;
            sensor_ready    : out std_logic
        );
    end component;
    
    component pattern_recognizer is
        port (
            clk                 : in  std_logic;
            rst_n               : in  std_logic;
            enable              : in  std_logic;
            sensor_data         : in  sensor_array_t;
            data_valid          : in  std_logic;
            baseline_data       : in  sensor_array_t;
            start_analysis      : in  std_logic;
            clear_pattern       : in  std_logic;
            sensitivity_level   : in  std_logic_vector(3 downto 0);
            template_write      : in  std_logic;
            template_addr       : in  std_logic_vector(log2_ceil(NUM_TEMPLATES)-1 downto 0);
            template_data       : in  pattern_array_t;
            pattern_detected    : out std_logic;
            pattern_id          : out std_logic_vector(log2_ceil(NUM_TEMPLATES)-1 downto 0);
            confidence_level    : out std_logic_vector(7 downto 0);
            analysis_complete   : out std_logic;
            current_pattern     : out pattern_array_t;
            match_distances     : out std_logic_vector(127 downto 0)
        );
    end component;
    
    -- Internal signals
    signal main_state           : gc_state_t;
    signal next_state           : gc_state_t;
    
    -- Sensor sequencer signals
    signal seq_enable           : std_logic;
    signal seq_start            : std_logic;
    signal seq_done             : std_logic;
    signal seq_sensor_data      : sensor_array_t;
    signal seq_data_valid       : std_logic;
    signal seq_ready            : std_logic;
    signal seq_current_sensor   : std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
    
    -- Pattern recognizer signals
    signal pr_enable            : std_logic;
    signal pr_start             : std_logic;
    signal pr_pattern_detected  : std_logic;
    signal pr_pattern_id        : std_logic_vector(log2_ceil(NUM_TEMPLATES)-1 downto 0);
    signal pr_confidence        : std_logic_vector(7 downto 0);
    signal pr_complete          : std_logic;
    signal pr_current_pattern   : pattern_array_t;
    
    -- Data processing
    signal sample_counter       : unsigned(15 downto 0);
    signal baseline_data        : sensor_array_t;
    signal baseline_valid       : std_logic;
    signal data_accumulator     : sensor_array_t;
    signal accumulator_count    : unsigned(7 downto 0);
    
    -- Timing and control
    signal sample_timer         : unsigned(15 downto 0);
    signal processing_timer     : unsigned(15 downto 0);
    signal error_flags          : std_logic_vector(7 downto 0);
    
    -- Memory management
    signal mem_state            : std_logic_vector(2 downto 0);
    signal mem_addr_int         : unsigned(15 downto 0);
    signal template_load_addr   : unsigned(log2_ceil(NUM_TEMPLATES)-1 downto 0);
    
begin
    
    -- Sensor sequencer instantiation
    u_sensor_seq: sensor_sequencer
        port map (
            clk             => clk,
            rst_n           => rst_n,
            enable          => seq_enable
