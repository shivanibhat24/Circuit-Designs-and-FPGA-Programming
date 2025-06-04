-- Mridangam Voice Synthesizer
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity mridangam_voice is
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
end mridangam_voice;

architecture Behavioral of mridangam_voice is
    -- Voice state
    signal voice_active : STD_LOGIC := '0';
    signal envelope : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal decay_counter : integer range 0 to 65535 := 0;
    
    -- Oscillators for different frequency components
    signal phase_acc1 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal phase_acc2 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal phase_acc3 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal freq_word1 : STD_LOGIC_VECTOR(31 downto 0);
    signal freq_word2 : STD_LOGIC_VECTOR(31 downto 0);
    signal freq_word3 : STD_LOGIC_VECTOR(31 downto 0);
    
    -- Waveform outputs
    signal osc1_out : STD_LOGIC_VECTOR(15 downto 0);
    signal osc2_out : STD_LOGIC_VECTOR(15 downto 0);
    signal osc3_out : STD_LOGIC_VECTOR(15 downto 0);
    signal mixed_osc : STD_LOGIC_VECTOR(15 downto 0);
    
    -- Noise generator for realistic percussion
    signal noise_lfsr : STD_LOGIC_VECTOR(15 downto 0) := x"ACED";
    signal noise_out : STD_LOGIC_VECTOR(15 downto 0);
    
    -- Filter state
    signal filter_acc : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    
begin

    -- Note to frequency conversion (simplified for mridangam)
    process(clk, reset)
        variable note_int : integer;
        variable base_freq : integer;
    begin
        if reset = '1' then
            freq_word1 <= (others => '0');
            freq_word2 <= (others => '0');
            freq_word3 <= (others => '0');
        elsif rising_edge(clk) then
            if trigger = '1' then
                note_int := to_integer(unsigned(note));
                
                -- Base frequency calculation (simplified)
                case note_int mod 12 is
                    when 0 => base_freq := 65;   -- C
                    when 1 => base_freq := 69;   -- C#
                    when 2 => base_freq := 73;   -- D  
                    when 3 => base_freq := 78;   -- D#
                    when 4 => base_freq := 82;   -- E
                    when 5 => base_freq := 87;   -- F
                    when 6 => base_freq := 92;   -- F#
                    when 7 => base_freq := 98;   -- G
                    when 8 => base_freq := 104;  -- G#
                    when 9 => base_freq := 110;  -- A
                    when 10 => base_freq := 117; -- A#
                    when others => base_freq := 123; -- B
                end case;
                
                -- Scale by octave
                for i in 0 to (note_int / 12) loop
                    base_freq := base_freq * 2;
                end loop;
                
                -- Mridangam-specific harmonics
                freq_word1 <= std_logic_vector(to_unsigned(base_freq * 65536, 32));      -- Fundamental
                freq_word2 <= std_logic_vector(to_unsigned(base_freq * 2 * 65536, 32));  -- 2nd harmonic
                freq_word3 <= std_logic_vector(to_unsigned(base_freq * 3 * 65536, 32));  -- 3rd harmonic
            end if;
        end if;
    end process;
    
    -- Voice trigger and envelope
    process(clk, reset)
    begin
        if reset = '1' then
            voice_active <= '0';
            envelope <= (others => '0');
            decay_counter <= 0;
        elsif rising_edge(clk) then
            if trigger = '1' then
                voice_active <= '1';
                envelope <= velocity & velocity; -- Initial amplitude based on velocity
                decay_counter <= 0;
            elsif sample_en = '1' and voice_active = '1' then
                -- Exponential decay
                if decay_counter = 31 then
                    decay_counter <= 0;
                    if envelope > 1 then
                        envelope <= envelope - 1;
                    else
                        voice_active <= '0';
                        envelope <= (others => '0');
                    end if;
                else
                    decay_counter <= decay_counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Phase accumulators for oscillators
    process(clk, reset)
    begin
        if reset = '1' then
            phase_acc1 <= (others => '0');
            phase_acc2 <= (others => '0');
            phase_acc3 <= (others => '0');
        elsif rising_edge(clk) and sample_en = '1' and voice_active = '1' then
            phase_acc1 <= phase_acc1 + freq_word1;
            phase_acc2 <= phase_acc2 + freq_word2;
            phase_acc3 <= phase_acc3 + freq_word3;
        end if;
    end process;
    
    -- Waveform generation (sine approximation using triangle wave)
    osc1_out <= phase_acc1(31 downto 16) when phase_acc1(31) = '0' else 
                not phase_acc1(31 downto 16);
    osc2_out <= phase_acc2(31 downto 16) when phase_acc2(31) = '0' else 
                not phase_acc2(31 downto 16);
    osc3_out <= phase_acc3(31 downto 16) when phase_acc3(31) = '0' else 
                not phase_acc3(31 downto 16);
    
    -- Noise generator (LFSR)
    process(clk, reset)
    begin
        if reset = '1' then
            noise_lfsr <= x"ACED";
        elsif rising_edge(clk) and sample_en = '1' then
            noise_lfsr <= noise_lfsr(14 downto 0) & (noise_lfsr(15) xor noise_lfsr(13));
        end if;
    end process;
    
    noise_out <= noise_lfsr;
    
    -- Mix oscillators with different weights for mridangam character
    mixed_osc <= std_logic_vector(
        resize(signed(osc1_out), 17) +          -- Fundamental (full weight)
        resize(signed(osc2_out(15 downto 1)), 17) +  -- 2nd harmonic (half weight) 
        resize(signed(osc3_out(15 downto 2)), 17) +  -- 3rd harmonic (quarter weight)
        resize(signed(noise_out(15 downto 3)), 17)   -- Noise (eighth weight)
    )(15 downto 0);
    
    -- Apply envelope and output
    process(clk, reset)
        variable temp_mult : signed(31 downto 0);
    begin
        if reset = '1' then
            audio_out <= (others => '0');
        elsif rising_edge(clk) and sample_en = '1' then
            if voice_active = '1' then
                temp_mult := signed(mixed_osc) * signed(envelope);
                audio_out <= std_logic_vector(temp_mult(31 downto 16));
            else
                audio_out <= (others => '0');
            end if;
        end if;
    end process;
    
    active <= voice_active;

end Behavioral;
