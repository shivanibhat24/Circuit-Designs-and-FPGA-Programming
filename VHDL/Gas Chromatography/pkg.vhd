-- Gas Chromatography Package
-- Common types, constants, and functions for GC system

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gc_package is
    -- System constants
    constant CLOCK_FREQ         : integer := 100_000_000; -- 100 MHz
    constant ADC_RESOLUTION     : integer := 12;
    constant NUM_SENSORS        : integer := 8;
    constant SAMPLE_RATE        : integer := 1000; -- 1 kHz per sensor
    constant PATTERN_WIDTH      : integer := 16;
    constant MEMORY_DEPTH       : integer := 1024;
    constant NUM_TEMPLATES      : integer := 16;
    
    -- Data types
    subtype adc_data_t is std_logic_vector(ADC_RESOLUTION-1 downto 0);
    type sensor_array_t is array (0 to NUM_SENSORS-1) of adc_data_t;
    type pattern_array_t is array (0 to PATTERN_WIDTH-1) of std_logic_vector(7 downto 0);
    type template_array_t is array (0 to NUM_TEMPLATES-1) of pattern_array_t;
    
    -- State machine types
    type gc_state_t is (
        IDLE,
        INIT_SEQUENCE,
        SAMPLING,
        PROCESSING,
        PATTERN_MATCH,
        RESULT_OUTPUT,
        ERROR_STATE
    );
    
    type sensor_seq_state_t is (
        SEQ_IDLE,
        SEQ_SELECT,
        SEQ_SETTLE,
        SEQ_CONVERT,
        SEQ_READ,
        SEQ_NEXT
    );
    
    -- Control signals record
    type gc_control_t is record
        start           : std_logic;
        reset           : std_logic;
        enable          : std_logic;
        sample_trigger  : std_logic;
        process_enable  : std_logic;
    end record;
    
    -- Status signals record
    type gc_status_t is record
        ready           : std_logic;
        busy            : std_logic;
        error           : std_logic;
        pattern_found   : std_logic;
        data_valid      : std_logic;
    end record;
    
    -- ADC interface record
    type adc_interface_t is record
        cs_n            : std_logic;
        sclk            : std_logic;
        mosi            : std_logic;
        miso            : std_logic;
        conv_start      : std_logic;
        busy            : std_logic;
    end record;
    
    -- Functions
    function log2_ceil(n : integer) return integer;
    function hamming_distance(a, b : pattern_array_t) return integer;
    function normalize_data(data : adc_data_t; ref_val : adc_data_t) return std_logic_vector;
    
end package gc_package;

package body gc_package is
    
    function log2_ceil(n : integer) return integer is
        variable temp : integer := n;
        variable result : integer := 0;
    begin
        while temp > 1 loop
            temp := temp / 2;
            result := result + 1;
        end loop;
        if 2**result < n then
            result := result + 1;
        end if;
        return result;
    end function;
    
    function hamming_distance(a, b : pattern_array_t) return integer is
        variable distance : integer := 0;
        variable diff : std_logic_vector(7 downto 0);
        variable bit_count : integer;
    begin
        for i in 0 to PATTERN_WIDTH-1 loop
            diff := a(i) xor b(i);
            bit_count := 0;
            for j in 0 to 7 loop
                if diff(j) = '1' then
                    bit_count := bit_count + 1;
                end if;
            end loop;
            distance := distance + bit_count;
        end loop;
        return distance;
    end function;
    
    function normalize_data(data : adc_data_t; ref_val : adc_data_t) return std_logic_vector is
        variable normalized : std_logic_vector(7 downto 0);
        variable data_int, ref_int : integer;
        variable ratio : integer;
    begin
        data_int := to_integer(unsigned(data));
        ref_int := to_integer(unsigned(ref_val));
        
        if ref_int > 0 then
            ratio := (data_int * 255) / ref_int;
            if ratio > 255 then
                ratio := 255;
            end if;
        else
            ratio := 0;
        end if;
        
        normalized := std_logic_vector(to_unsigned(ratio, 8));
        return normalized;
    end function;
    
end package body gc_package;
