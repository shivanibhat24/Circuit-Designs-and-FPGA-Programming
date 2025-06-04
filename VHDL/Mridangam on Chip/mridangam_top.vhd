-- Mridangam-on-Chip: Complete FPGA Implementation
-- Traditional Indian percussion instrument synthesizer with MIDI input
-- Ultra-fast triggering with physical modeling synthesis

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

-- Top-level entity
entity mridangam_chip is
    Port (
        clk         : in  STD_LOGIC;  -- System clock (e.g., 100 MHz)
        reset       : in  STD_LOGIC;
        -- MIDI Interface
        midi_rx     : in  STD_LOGIC;  -- MIDI serial input
        -- Audio Output
        audio_out   : out STD_LOGIC_VECTOR(15 downto 0);  -- 16-bit audio
        audio_valid : out STD_LOGIC;
        -- Control Interface
        velocity_in : in  STD_LOGIC_VECTOR(7 downto 0);   -- Manual velocity
        note_trigger: in  STD_LOGIC;  -- Manual trigger
        -- Status
        active      : out STD_LOGIC
    );
end mridangam_chip;

architecture Behavioral of mridangam_chip is

    -- Constants for audio processing
    constant SAMPLE_RATE : integer := 48000;
    constant CLOCK_FREQ  : integer := 100000000;
    constant SAMPLE_DIV  : integer := CLOCK_FREQ / SAMPLE_RATE;
    
    -- Mridangam-specific constants
    constant NUM_VOICES  : integer := 8;  -- Polyphonic voices
    constant DECAY_RATE  : integer := 32; -- Decay speed
    
    -- Component declarations
    component midi_decoder is
        Port (
            clk        : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            midi_rx    : in  STD_LOGIC;
            note_on    : out STD_LOGIC;
            note_off   : out STD_LOGIC;
            note_num   : out STD_LOGIC_VECTOR(7 downto 0);
            velocity   : out STD_LOGIC_VECTOR(7 downto 0);
            valid      : out STD_LOGIC
        );
    end component;
    
    component mridangam_voice is
        Port (
            clk        : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            trigger    : in  STD_LOGIC;
            note       : in  STD_LOGIC_VECTOR(7 downto 0);
            velocity   : in  STD_LOGIC_VECTOR(7 downto 0);
            sample_en  : in  STD_LOGIC;
            audio_out  : out STD_LOGIC_VECTOR(15 downto 0);
            active     : out STD_LOGIC
        );
    end component;
    
    component audio_mixer is
        generic (
            NUM_INPUTS : integer := NUM_VOICES
        );
        Port (
            clk        : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            inputs     : in  STD_LOGIC_VECTOR((16 * NUM_INPUTS) - 1 downto 0);
            output     : out STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;
    
    -- Internal signals
    signal sample_counter : integer range 0 to SAMPLE_DIV := 0;
    signal sample_enable  : STD_LOGIC := '0';
    
    -- MIDI signals
    signal midi_note_on   : STD_LOGIC;
    signal midi_note_off  : STD_LOGIC;
    signal midi_note_num  : STD_LOGIC_VECTOR(7 downto 0);
    signal midi_velocity  : STD_LOGIC_VECTOR(7 downto 0);
    signal midi_valid     : STD_LOGIC;
    
    -- Voice management
    type voice_array is array (0 to NUM_VOICES-1) of STD_LOGIC_VECTOR(15 downto 0);
    signal voice_outputs  : voice_array;
    signal voice_active   : STD_LOGIC_VECTOR(NUM_VOICES-1 downto 0);
    signal voice_triggers : STD_LOGIC_VECTOR(NUM_VOICES-1 downto 0);
    signal voice_notes    : STD_LOGIC_VECTOR((8 * NUM_VOICES) - 1 downto 0);
    signal voice_velocities : STD_LOGIC_VECTOR((8 * NUM_VOICES) - 1 downto 0);
    
    -- Voice allocation
    signal next_voice     : integer range 0 to NUM_VOICES-1 := 0;
    signal trigger_pulse  : STD_LOGIC;
    signal trigger_note   : STD_LOGIC_VECTOR(7 downto 0);
    signal trigger_vel    : STD_LOGIC_VECTOR(7 downto 0);
    
    -- Audio mixing
    signal mixer_inputs   : STD_LOGIC_VECTOR((16 * NUM_VOICES) - 1 downto 0);
    signal mixed_audio    : STD_LOGIC_VECTOR(15 downto 0);

begin

    -- Sample rate clock generation
    process(clk, reset)
    begin
        if reset = '1' then
            sample_counter <= 0;
            sample_enable <= '0';
        elsif rising_edge(clk) then
            if sample_counter = SAMPLE_DIV - 1 then
                sample_counter <= 0;
                sample_enable <= '1';
            else
                sample_counter <= sample_counter + 1;
                sample_enable <= '0';
            end if;
        end if;
    end process;
    
    -- MIDI decoder instance
    midi_dec: midi_decoder
        port map (
            clk        => clk,
            reset      => reset,
            midi_rx    => midi_rx,
            note_on    => midi_note_on,
            note_off   => midi_note_off,
            note_num   => midi_note_num,
            velocity   => midi_velocity,
            valid      => midi_valid
        );
    
    -- Trigger logic (MIDI or manual)
    process(clk, reset)
    begin
        if reset = '1' then
            trigger_pulse <= '0';
            trigger_note <= (others => '0');
            trigger_vel <= (others => '0');
        elsif rising_edge(clk) then
            trigger_pulse <= '0';
            
            -- MIDI trigger
            if midi_valid = '1' and midi_note_on = '1' then
                trigger_pulse <= '1';
                trigger_note <= midi_note_num;
                trigger_vel <= midi_velocity;
            -- Manual trigger
            elsif note_trigger = '1' then
                trigger_pulse <= '1';
                trigger_note <= x"3C"; -- Middle C as default
                trigger_vel <= velocity_in;
            end if;
        end if;
    end process;
    
    -- Voice allocation (round-robin)
    process(clk, reset)
    begin
        if reset = '1' then
            next_voice <= 0;
            voice_triggers <= (others => '0');
        elsif rising_edge(clk) then
            voice_triggers <= (others => '0');
            
            if trigger_pulse = '1' then
                voice_triggers(next_voice) <= '1';
                
                -- Update voice parameters
                voice_notes((next_voice + 1) * 8 - 1 downto next_voice * 8) <= trigger_note;
                voice_velocities((next_voice + 1) * 8 - 1 downto next_voice * 8) <= trigger_vel;
                
                -- Move to next voice
                if next_voice = NUM_VOICES - 1 then
                    next_voice <= 0;
                else
                    next_voice <= next_voice + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Generate voice instances
    voice_gen: for i in 0 to NUM_VOICES-1 generate
        voice_inst: mridangam_voice
            port map (
                clk        => clk,
                reset      => reset,
                trigger    => voice_triggers(i),
                note       => voice_notes((i + 1) * 8 - 1 downto i * 8),
                velocity   => voice_velocities((i + 1) * 8 - 1 downto i * 8),
                sample_en  => sample_enable,
                audio_out  => voice_outputs(i),
                active     => voice_active(i)
            );
            
        -- Pack voice outputs for mixer
        mixer_inputs((i + 1) * 16 - 1 downto i * 16) <= voice_outputs(i);
    end generate;
    
    -- Audio mixer
    mixer_inst: audio_mixer
        generic map (
            NUM_INPUTS => NUM_VOICES
        )
        port map (
            clk        => clk,
            reset      => reset,
            inputs     => mixer_inputs,
            output     => mixed_audio
        );
    
    -- Output assignments
    audio_out <= mixed_audio;
    audio_valid <= sample_enable;
    active <= '1' when voice_active /= (voice_active'range => '0') else '0';

end Behavioral;
