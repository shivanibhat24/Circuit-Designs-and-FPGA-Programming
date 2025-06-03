-- Testbench for Underwater Recorder SoC
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_underwater_recorder is
end tb_underwater_recorder;

architecture Behavioral of tb_underwater_recorder is

    component underwater_recorder_soc is
        Port (
            clk_50mhz    : in  STD_LOGIC;
            reset_n      : in  STD_LOGIC;
            adc_data     : in  STD_LOGIC_VECTOR(15 downto 0);
            adc_clk      : out STD_LOGIC;
            adc_cs_n     : out STD_LOGIC;
            sd_clk       : out STD_LOGIC;
            sd_cmd       : inout STD_LOGIC;
            sd_dat       : inout STD_LOGIC_VECTOR(3 downto 0);
            sd_cd        : in  STD_LOGIC;
            record_en    : in  STD_LOGIC;
            playback_en  : in  STD_LOGIC;
            status_led   : out STD_LOGIC_VECTOR(7 downto 0);
            audio_out    : out STD_LOGIC_VECTOR(15 downto 0);
            audio_valid  : out STD_LOGIC
        );
    end component;

    -- Testbench signals
    signal clk_50mhz : STD_LOGIC := '0';
    signal reset_n : STD_LOGIC := '0';
    signal adc_data : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal adc_clk : STD_LOGIC;
    signal adc_cs_n : STD_LOGIC;
    signal sd_clk : STD_LOGIC;
    signal sd_cmd : STD_LOGIC;
    signal sd_dat : STD_LOGIC_VECTOR(3 downto 0);
    signal sd_cd : STD_LOGIC := '1';
    signal record_en : STD_LOGIC := '0';
    signal playback_en : STD_LOGIC := '0';
    signal status_led : STD_LOGIC_VECTOR(7 downto 0);
    signal audio_out : STD_LOGIC_VECTOR(15 downto 0);
    signal audio_valid : STD_LOGIC;
    
    constant clk_period : time := 20 ns; -- 50MHz

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: underwater_recorder_soc
        Port map (
            clk_50mhz => clk_50mhz,
            reset_n => reset_n,
            adc_data => adc_data,
            adc_clk => adc_clk,
            adc_cs_n => adc_cs_n,
            sd_clk => sd_clk,
            sd_cmd => sd_cmd,
            sd_dat => sd_dat,
            sd_cd => sd_cd,
            record_en => record_en,
            playback_en => playback_en,
            status_led => status_led,
            audio_out => audio_out,
            audio_valid => audio_valid
        );

    -- Clock process
    clk_process : process
    begin
        clk_50mhz <= '0';
        wait for clk_period/2;
        clk_50mhz <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- Reset
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;
        
        -- Simulate ADC data (sine wave)
        for i in 0 to 1000 loop
            adc_data <= std_logic_vector(to_signed(integer(16383.0 * sin(real(i) * 0.1)), 16));
            wait for clk_period * 10;
        end loop;
        
        -- Start recording
        record_en <= '1';
        wait for 1 ms;
        
        -- Stop recording
        record_en <= '0';
        wait for 100 us;
        
        -- Start playback
        playback_en <= '1';
        wait for 1 ms;
        
        -- Stop playback
        playback_en <= '0';
        wait for 100 us;
        
        wait;
    end process;

end Behavioral;
