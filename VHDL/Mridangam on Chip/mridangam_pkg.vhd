-- Mridangam-on-Chip Package
-- Common types, constants, and functions for the mridangam synthesizer
-- Author: Generated for FPGA Indian Percussion Project
-- Version: 1.0

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

package mridangam_pkg is

    -- System Configuration Constants
    constant SYSTEM_CLK_FREQ    : integer := 100_000_000;  -- 100 MHz system clock
    constant SAMPLE_RATE        : integer := 48_000;       -- 48 kHz audio sample rate
    constant AUDIO_WIDTH        : integer := 16;           -- 16-bit audio resolution
    constant MIDI_BAUD_RATE     : integer := 31_250;       -- Standard MIDI baud rate
    
    -- Voice Configuration
    constant MAX_VOICES         : integer := 8;            -- Maximum polyphonic voices
    constant VELOCITY_WIDTH     : integer := 8;            -- MIDI velocity resolution
    constant NOTE_WIDTH         : integer := 8;            -- MIDI note number width
    
    -- Synthesis Parameters
    constant PHASE_ACC_WIDTH    : integer := 32;           -- Phase accumulator width
    constant ENVELOPE_WIDTH     : integer := 16;           -- Envelope generator width
    constant DECAY_SHIFT        : integer := 5;            -- Decay rate (2^5 = 32 samples)
    constant NOISE_WIDTH        : integer := 16;           -- Noise generator width
    
    -- Mridangam-specific Constants
    constant FUNDAMENTAL_WEIGHT : integer := 8;            -- Weight for fundamental frequency
    constant HARMONIC2_WEIGHT   : integer := 4;            -- Weight for 2nd harmonic
    constant HARMONIC3_WEIGHT   : integer := 2;            -- Weight for 3rd harmonic
    constant NOISE_WEIGHT       : integer := 1;            -- Weight for noise component
    
    -- Filter Parameters
    constant FILTER_CUTOFF      : integer := 4000;         -- Low-pass filter cutoff (Hz)
    constant RESONANCE_Q        : integer := 2;            -- Filter resonance factor
    
    -- MIDI Constants
    constant MIDI_NOTE_ON       : std_logic_vector(3 downto 0) := x"9";
    constant MIDI_NOTE_OFF      : std_logic_vector(3 downto 0) := x"8";
    constant MIDI_CC            : std_logic_vector(3 downto 0) := x"B";
    
    -- Mridangam Note Mappings (MIDI note to mridangam stroke)
    constant MRIDANGAM_TA       : std_logic_vector(7 downto 0) := x"24"; -- C1 (36)
    constant MRIDANGAM_DHIMI    : std_logic_vector(7 downto 0) := x"26"; -- D1 (38)
    constant MRIDANGAM_CHAPU    : std_logic_vector(7 downto 0) := x"28"; -- E1 (40)
    constant MRIDANGAM_NAM      : std_logic_vector(7 downto 0) := x"2A"; -- F#1 (42)
    constant MRIDANGAM_DHEEM    : std_logic_vector(7 downto 0) := x"2C"; -- G#1 (44)
    constant MRIDANGAM_TOM      : std_logic_vector(7 downto 0) := x"2E"; -- A#1 (46)
    constant MRIDANGAM_KA       : std_logic_vector(7 downto 0) := x"30"; -- C2 (48)
    constant MRIDANGAM_TAM      : std_logic_vector(7 downto 0) := x"32"; -- D2 (50)
    
    -- Custom Types
    type voice_state_type is (IDLE, ATTACK, DECAY, SUSTAIN, RELEASE);
    
    type voice_params_type is record
        state       : voice_state_type;
        note        : std_logic_vector(NOTE_WIDTH-1 downto 0);
        velocity    : std_logic_vector(VELOCITY_WIDTH-1 downto 0);
        envelope    : std_logic_vector(ENVELOPE_WIDTH-1 downto 0);
        phase_acc   : std_logic_vector(PHASE_ACC_WIDTH-1 downto 0);
        decay_count : integer range 0 to (2**DECAY_SHIFT)-1;
        active      : std_logic;
    end record;
    
    type voice_array_type is array (0 to MAX_VOICES-1) of voice_params_type;
    
    type audio_array_type is array (0 to MAX_VOICES-1) of 
         std_logic_vector(AUDIO_WIDTH-1 downto 0);
    
    type freq_lut_type is array (0 to 127) of std_logic_vector(PHASE_ACC_WIDTH-1 downto 0);
    
    -- MIDI Message Types
    type midi_msg_type is record
        status      : std_logic_vector(7 downto 0);
        data1       : std_logic_vector(7 downto 0);
        data2       : std_logic_vector(7 downto 0);
        valid       : std_logic;
        note_on     : std_logic;
        note_off    : std_logic;
    end record;
    
    -- Oscillator Types
    type osc_type is (OSC_SINE, OSC_TRIANGLE, OSC_SAWTOOTH, OSC_SQUARE, OSC_NOISE);
    
    type harmonic_config_type is record
        freq_mult   : integer range 1 to 16;   -- Frequency multiplier
        amplitude   : integer range 0 to 255;  -- Amplitude weight
        osc_type    : osc_type;                 -- Oscillator waveform
    end record;
    
    type harmonic_array_type is array (0 to 7) of harmonic_config_type;
    
    -- Mridangam Stroke Configurations
    constant STROKE_TA_CONFIG : harmonic_array_type := (
        0 => (freq_mult => 1, amplitude => 255, osc_type => OSC_TRIANGLE),  -- Fundamental
        1 => (freq_mult => 2, amplitude => 128, osc_type => OSC_TRIANGLE),  -- 2nd harmonic
        2 => (freq_mult => 3, amplitude => 64,  osc_type => OSC_SINE),      -- 3rd harmonic
        3 => (freq_mult => 1, amplitude => 32,  osc_type => OSC_NOISE),     -- Noise component
        others => (freq_mult => 1, amplitude => 0, osc_type => OSC_SINE)
    );
    
    constant STROKE_DHIMI_CONFIG : harmonic_array_type := (
        0 => (freq_mult => 1, amplitude => 200, osc_type => OSC_SINE),      -- Fundamental
        1 => (freq_mult => 2, amplitude => 150, osc_type => OSC_TRIANGLE),  -- 2nd harmonic
        2 => (freq_mult => 4, amplitude => 80,  osc_type => OSC_SINE),      -- 4th harmonic
        3 => (freq_mult => 1, amplitude => 64,  osc_type => OSC_NOISE),     -- Noise component
        others => (freq_mult => 1, amplitude => 0, osc_type => OSC_SINE)
    );
    
    -- Function Declarations
    function note_to_freq_word(note : std_logic_vector(7 downto 0)) 
             return std_logic_vector;
    
    function velocity_to_amplitude(velocity : std_logic_vector(7 downto 0)) 
             return std_logic_vector;
    
    function saturate_audio(input : signed; width : integer) 
             return std_logic_vector;
    
    function get_stroke_config(note : std_logic_vector(7 downto 0)) 
             return harmonic_array_type;
    
    -- Sine/Cosine Lookup Table (reduced size for FPGA efficiency)
    type sine_lut_type is array (0 to 255) of std_logic_vector(15 downto 0);
    
    -- Pre-calculated sine lookup table (first 256 samples of sine wave)
    constant SINE_LUT : sine_lut_type := (
        x"0000", x"0324", x"0647", x"096A", x"0C8B", x"0FAB", x"12C8", x"15E2",
        x"18F8", x"1C0B", x"1F19", x"2223", x"2528", x"2826", x"2B1F", x"2E11",
        x"30FB", x"33DE", x"36BA", x"398C", x"3C56", x"3F17", x"41CE", x"447A",
        x"471C", x"49B4", x"4C3F", x"4EBF", x"5133", x"539B", x"55F5", x"5842",
        x"5A82", x"5CB4", x"5ED7", x"60EC", x"62F2", x"64E8", x"66CF", x"68A6",
        x"6A6D", x"6C24", x"6DCA", x"6F5F", x"70E2", x"7255", x"73B5", x"7504",
        x"7641", x"776C", x"7884", x"798A", x"7A7D", x"7B5D", x"7C29", x"7CE3",
        x"7D8A", x"7E1D", x"7E9D", x"7F09", x"7F62", x"7FA7", x"7FD8", x"7FF6",
        x"7FFF", x"7FF6", x"7FD8", x"7FA7", x"7F62", x"7F09", x"7E9D", x"7E1D",
        x"7D8A", x"7CE3", x"7C29", x"7B5D", x"7A7D", x"798A", x"7884", x"776C",
        x"7641", x"7504", x"73B5", x"7255", x"70E2", x"6F5F", x"6DCA", x"6C24",
        x"6A6D", x"68A6", x"66CF", x"64E8", x"62F2", x"60EC", x"5ED7", x"5CB4",
        x"5A82", x"5842", x"55F5", x"539B", x"5133", x"4EBF", x"4C3F", x"49B4",
        x"471C", x"447A", x"41CE", x"3F17", x"3C56", x"398C", x"36BA", x"33DE",
        x"30FB", x"2E11", x"2B1F", x"2826", x"2528", x"2223", x"1F19", x"1C0B",
        x"18F8", x"15E2", x"12C8", x"0FAB", x"0C8B", x"096A", x"0647", x"0324",
        x"0000", x"FCDC", x"F9B9", x"F696", x"F375", x"F055", x"ED38", x"EA1E",
        x"E708", x"E3F5", x"E0E7", x"DDDD", x"DAD8", x"D7DA", x"D4E1", x"D1EF",
        x"CF05", x"CC22", x"C946", x"C674", x"C3AA", x"C0E9", x"BE32", x"BB86",
        x"B8E4", x"B64C", x"B3C1", x"B141", x"AECD", x"AC65", x"AA0B", x"A7BE",
        x"A57E", x"A34C", x"A129", x"9F14", x"9D0E", x"9B18", x"9931", x"975A",
        x"9593", x"93DC", x"9236", x"90A1", x"8F1E", x"8DAB", x"8C4B", x"8AFC",
        x"89BF", x"8894", x"877C", x"8676", x"8583", x"84A3", x"83D7", x"831D",
        x"8276", x"81E3", x"8163", x"80F7", x"809E", x"8059", x"8028", x"800A",
        x"8001", x"800A", x"8028", x"8059", x"809E", x"80F7", x"8163", x"81E3",
        x"8276", x"831D", x"83D7", x"84A3", x"8583", x"8676", x"877C", x"8894",
        x"89BF", x"8AFC", x"8C4B", x"8DAB", x"8F1E", x"90A1", x"9236", x"93DC",
        x"9593", x"975A", x"9931", x"9B18", x"9D0E", x"9F14", x"A129", x"A34C",
        x"A57E", x"A7BE", x"AA0B", x"AC65", x"AECD", x"B141", x"B3C1", x"B64C",
        x"B8E4", x"BB86", x"BE32", x"C0E9", x"C3AA", x"C674", x"C946", x"CC22",
        x"CF05", x"D1EF", x"D4E1", x"D7DA", x"DAD8", x"DDDD", x"E0E7", x"E3F5",
        x"E708", x"EA1E", x"ED38", x"F055", x"F375", x"F696", x"F9B9", x"FCDC"
    );

end package mridangam_pkg;

package body mridangam_pkg is

    -- Convert MIDI note number to phase accumulator frequency word
    function note_to_freq_word(note : std_logic_vector(7 downto 0)) 
             return std_logic_vector is
        variable note_num : integer;
        variable freq_hz  : real;
        variable freq_word : std_logic_vector(PHASE_ACC_WIDTH-1 downto 0);
    begin
        note_num := to_integer(unsigned(note));
        
        -- Convert MIDI note to frequency using A4 = 440 Hz as reference
        -- Frequency = 440 * 2^((note - 69)/12)
        freq_hz := 440.0 * (2.0 ** (real(note_num - 69) / 12.0));
        
        -- Convert to phase accumulator word
        -- freq_word = (freq_hz * 2^32) / sample_rate
        freq_word := std_logic_vector(to_unsigned(
            integer(freq_hz * real(2**PHASE_ACC_WIDTH) / real(SAMPLE_RATE)), 
            PHASE_ACC_WIDTH));
        
        return freq_word;
    end function;
    
    -- Convert MIDI velocity to amplitude scaling factor
    function velocity_to_amplitude(velocity : std_logic_vector(7 downto 0)) 
             return std_logic_vector is
        variable vel_int : integer;
        variable amplitude : std_logic_vector(ENVELOPE_WIDTH-1 downto 0);
    begin
        vel_int := to_integer(unsigned(velocity));
        
        -- Non-linear velocity curve for more natural feel
        -- amplitude = velocity^2 / 127 (squared response)
        amplitude := std_logic_vector(to_unsigned(
            (vel_int * vel_int) / 127, ENVELOPE_WIDTH));
        
        return amplitude;
    end function;
    
    -- Saturate audio signal to prevent clipping
    function saturate_audio(input : signed; width : integer) 
             return std_logic_vector is
        variable max_val : signed(width-1 downto 0);
        variable min_val : signed(width-1 downto 0);
        variable result  : signed(width-1 downto 0);
    begin
        max_val := to_signed(2**(width-1) - 1, width);
        min_val := to_signed(-(2**(width-1)), width);
        
        if input > max_val then
            result := max_val;
        elsif input < min_val then
            result := min_val;
        else
            result := resize(input, width);
        end if;
        
        return std_logic_vector(result);
    end function;
    
    -- Get harmonic configuration based on mridangam stroke
    function get_stroke_config(note : std_logic_vector(7 downto 0)) 
             return harmonic_array_type is
        variable config : harmonic_array_type;
    begin
        case note is
            when MRIDANGAM_TA =>
                config := STROKE_TA_CONFIG;
            when MRIDANGAM_DHIMI =>
                config := STROKE_DHIMI_CONFIG;
            when others =>
                config := STROKE_TA_CONFIG; -- Default to TA stroke
        end case;
        
        return config;
    end function;

end package body mridangam_pkg;
