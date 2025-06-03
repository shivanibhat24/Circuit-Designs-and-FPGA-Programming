-- Underwater Recorder SoC Top Level
-- Integrates ADC sampling, compression, and SD card storage

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity underwater_recorder_soc is
    Port (
        clk_50mhz    : in  STD_LOGIC;
        reset_n      : in  STD_LOGIC;
        
        -- ADC Interface
        adc_data     : in  STD_LOGIC_VECTOR(15 downto 0);
        adc_clk      : out STD_LOGIC;
        adc_cs_n     : out STD_LOGIC;
        
        -- SD Card Interface (SPI)
        sd_clk       : out STD_LOGIC;
        sd_cmd       : inout STD_LOGIC;
        sd_dat       : inout STD_LOGIC_VECTOR(3 downto 0);
        sd_cd        : in  STD_LOGIC;
        
        -- Control Interface
        record_en    : in  STD_LOGIC;
        playback_en  : in  STD_LOGIC;
        
        -- Status LEDs
        status_led   : out STD_LOGIC_VECTOR(7 downto 0);
        
        -- Audio Output (for playback)
        audio_out    : out STD_LOGIC_VECTOR(15 downto 0);
        audio_valid  : out STD_LOGIC
    );
end underwater_recorder_soc;

architecture Behavioral of underwater_recorder_soc is

    -- Clock generation
    component clk_gen is
        Port (
            clk_in       : in  STD_LOGIC;
            reset_n      : in  STD_LOGIC;
            clk_100mhz   : out STD_LOGIC;
            clk_25mhz    : out STD_LOGIC;
            clk_12mhz    : out STD_LOGIC;
            locked       : out STD_LOGIC
        );
    end component;
    
    -- ADC Controller
    component adc_controller is
        Port (
            clk          : in  STD_LOGIC;
            reset_n      : in  STD_LOGIC;
            enable       : in  STD_LOGIC;
            adc_data     : in  STD_LOGIC_VECTOR(15 downto 0);
            adc_clk      : out STD_LOGIC;
            adc_cs_n     : out STD_LOGIC;
            sample_data  : out STD_LOGIC_VECTOR(15 downto 0);
            sample_valid : out STD_LOGIC
        );
    end component;
    
    -- Audio Compressor
    component audio_compressor is
        Port (
            clk           : in  STD_LOGIC;
            reset_n       : in  STD_LOGIC;
            audio_in      : in  STD_LOGIC_VECTOR(15 downto 0);
            audio_valid   : in  STD_LOGIC;
            compressed_out: out STD_LOGIC_VECTOR(7 downto 0);
            comp_valid    : out STD_LOGIC;
            compression_ratio : in STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;
    
    -- SD Card Controller
    component sd_controller is
        Port (
            clk          : in  STD_LOGIC;
            reset_n      : in  STD_LOGIC;
            sd_clk       : out STD_LOGIC;
            sd_cmd       : inout STD_LOGIC;
            sd_dat       : inout STD_LOGIC_VECTOR(3 downto 0);
            
            -- Write Interface
            write_en     : in  STD_LOGIC;
            write_data   : in  STD_LOGIC_VECTOR(31 downto 0);
            write_addr   : in  STD_LOGIC_VECTOR(31 downto 0);
            write_ready  : out STD_LOGIC;
            
            -- Read Interface
            read_en      : in  STD_LOGIC;
            read_addr    : in  STD_LOGIC_VECTOR(31 downto 0);
            read_data    : out STD_LOGIC_VECTOR(31 downto 0);
            read_valid   : out STD_LOGIC;
            
            -- Status
            card_ready   : out STD_LOGIC;
            error        : out STD_LOGIC
        );
    end component;
    
    -- FIFO Buffer
    component fifo_buffer is
        Generic (
            DATA_WIDTH : integer := 16;
            DEPTH      : integer := 1024
        );
        Port (
            clk        : in  STD_LOGIC;
            reset_n    : in  STD_LOGIC;
            wr_en      : in  STD_LOGIC;
            wr_data    : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            rd_en      : in  STD_LOGIC;
            rd_data    : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            full       : out STD_LOGIC;
            empty      : out STD_LOGIC;
            almost_full: out STD_LOGIC
        );
    end component;

    -- Internal signals
    signal clk_100mhz, clk_25mhz, clk_12mhz : STD_LOGIC;
    signal pll_locked : STD_LOGIC;
    signal sys_reset_n : STD_LOGIC;
    
    -- ADC signals
    signal sample_data : STD_LOGIC_VECTOR(15 downto 0);
    signal sample_valid : STD_LOGIC;
    
    -- Compression signals
    signal compressed_data : STD_LOGIC_VECTOR(7 downto 0);
    signal comp_valid : STD_LOGIC;
    
    -- FIFO signals
    signal fifo_wr_en, fifo_rd_en : STD_LOGIC;
    signal fifo_data_in, fifo_data_out : STD_LOGIC_VECTOR(15 downto 0);
    signal fifo_full, fifo_empty, fifo_almost_full : STD_LOGIC;
    
    -- SD Card signals
    signal sd_write_en, sd_read_en : STD_LOGIC;
    signal sd_write_data, sd_read_data : STD_LOGIC_VECTOR(31 downto 0);
    signal sd_write_addr, sd_read_addr : STD_LOGIC_VECTOR(31 downto 0);
    signal sd_write_ready, sd_read_valid : STD_LOGIC;
    signal sd_card_ready, sd_error : STD_LOGIC;
    
    -- Control signals
    signal recording_active : STD_LOGIC;
    signal playback_active : STD_LOGIC;
    signal current_write_addr : unsigned(31 downto 0);
    signal current_read_addr : unsigned(31 downto 0);
    
    -- State machine
    type state_type is (IDLE, RECORDING, PLAYBACK, ERROR_STATE);
    signal current_state : state_type;

begin

    sys_reset_n <= reset_n and pll_locked;
    
    -- Clock Generation
    clk_gen_inst : clk_gen
        port map (
            clk_in     => clk_50mhz,
            reset_n    => reset_n,
            clk_100mhz => clk_100mhz,
            clk_25mhz  => clk_25mhz,
            clk_12mhz  => clk_12mhz,
            locked     => pll_locked
        );
    
    -- ADC Controller
    adc_ctrl_inst : adc_controller
        port map (
            clk         => clk_12mhz,
            reset_n     => sys_reset_n,
            enable      => recording_active,
            adc_data    => adc_data,
            adc_clk     => adc_clk,
            adc_cs_n    => adc_cs_n,
            sample_data => sample_data,
            sample_valid=> sample_valid
        );
    
    -- Audio Compressor
    compressor_inst : audio_compressor
        port map (
            clk            => clk_25mhz,
            reset_n        => sys_reset_n,
            audio_in       => sample_data,
            audio_valid    => sample_valid,
            compressed_out => compressed_data,
            comp_valid     => comp_valid,
            compression_ratio => "010" -- 4:1 compression
        );
    
    -- FIFO Buffer for audio data
    audio_fifo : fifo_buffer
        generic map (
            DATA_WIDTH => 16,
            DEPTH      => 2048
        )
        port map (
            clk        => clk_25mhz,
            reset_n    => sys_reset_n,
            wr_en      => fifo_wr_en,
            wr_data    => fifo_data_in,
            rd_en      => fifo_rd_en,
            rd_data    => fifo_data_out,
            full       => fifo_full,
            empty      => fifo_empty,
            almost_full=> fifo_almost_full
        );
    
    -- SD Card Controller
    sd_ctrl_inst : sd_controller
        port map (
            clk         => clk_25mhz,
            reset_n     => sys_reset_n,
            sd_clk      => sd_clk,
            sd_cmd      => sd_cmd,
            sd_dat      => sd_dat,
            write_en    => sd_write_en,
            write_data  => sd_write_data,
            write_addr  => sd_write_addr,
            write_ready => sd_write_ready,
            read_en     => sd_read_en,
            read_addr   => sd_read_addr,
            read_data   => sd_read_data,
            read_valid  => sd_read_valid,
            card_ready  => sd_card_ready,
            error       => sd_error
        );
    
    -- Main Control Process
    control_proc : process(clk_25mhz, sys_reset_n)
    begin
        if sys_reset_n = '0' then
            current_state <= IDLE;
            recording_active <= '0';
            playback_active <= '0';
            current_write_addr <= (others => '0');
            current_read_addr <= (others => '0');
            
        elsif rising_edge(clk_25mhz) then
            case current_state is
                when IDLE =>
                    recording_active <= '0';
                    playback_active <= '0';
                    
                    if record_en = '1' and sd_card_ready = '1' then
                        current_state <= RECORDING;
                        recording_active <= '1';
                    elsif playback_en = '1' and sd_card_ready = '1' then
                        current_state <= PLAYBACK;
                        playback_active <= '1';
                    end if;
                
                when RECORDING =>
                    if record_en = '0' or sd_error = '1' then
                        current_state <= IDLE;
                        recording_active <= '0';
                    end if;
                    
                    -- Increment write address when data is written
                    if sd_write_en = '1' and sd_write_ready = '1' then
                        current_write_addr <= current_write_addr + 1;
                    end if;
                
                when PLAYBACK =>
                    if playback_en = '0' or sd_error = '1' then
                        current_state <= IDLE;
                        playback_active <= '0';
                    end if;
                    
                    -- Increment read address when data is read
                    if sd_read_en = '1' and sd_read_valid = '1' then
                        current_read_addr <= current_read_addr + 1;
                    end if;
                
                when ERROR_STATE =>
                    if sd_error = '0' then
                        current_state <= IDLE;
                    end if;
            end case;
            
            if sd_error = '1' then
                current_state <= ERROR_STATE;
            end if;
        end if;
    end process;
    
    -- Data flow control
    data_flow_proc : process(clk_25mhz, sys_reset_n)
    begin
        if sys_reset_n = '0' then
            fifo_wr_en <= '0';
            fifo_rd_en <= '0';
            sd_write_en <= '0';
            sd_read_en <= '0';
            
        elsif rising_edge(clk_25mhz) then
            -- Recording data flow
            if recording_active = '1' then
                -- Write compressed audio to FIFO
                fifo_wr_en <= comp_valid and not fifo_full;
                fifo_data_in <= "00000000" & compressed_data;
                
                -- Transfer from FIFO to SD card
                if not fifo_empty and sd_write_ready = '1' then
                    fifo_rd_en <= '1';
                    sd_write_en <= '1';
                    sd_write_data <= fifo_data_out & x"0000";
                    sd_write_addr <= std_logic_vector(current_write_addr);
                else
                    fifo_rd_en <= '0';
                    sd_write_en <= '0';
                end if;
            else
                fifo_wr_en <= '0';
                fifo_rd_en <= '0';
                sd_write_en <= '0';
            end if;
            
            -- Playback data flow
            if playback_active = '1' then
                if current_read_addr < current_write_addr then
                    sd_read_en <= '1';
                    sd_read_addr <= std_logic_vector(current_read_addr);
                else
                    sd_read_en <= '0';
                end if;
            else
                sd_read_en <= '0';
            end if;
        end if;
    end process;
    
    -- Audio output for playback
    audio_output_proc : process(clk_25mhz, sys_reset_n)
    begin
        if sys_reset_n = '0' then
            audio_out <= (others => '0');
            audio_valid <= '0';
        elsif rising_edge(clk_25mhz) then
            if playback_active = '1' and sd_read_valid = '1' then
                audio_out <= sd_read_data(31 downto 16);
                audio_valid <= '1';
            else
                audio_valid <= '0';
            end if;
        end if;
    end process;
    
    -- Status LED control
    status_led(0) <= recording_active;
    status_led(1) <= playback_active;
    status_led(2) <= sd_card_ready;
    status_led(3) <= sd_error;
    status_led(4) <= fifo_full;
    status_led(5) <= fifo_empty;
    status_led(6) <= pll_locked;
    status_led(7) <= '1' when current_state = ERROR_STATE else '0';

end Behavioral;


-- Clock Generator Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_gen is
    Port (
        clk_in       : in  STD_LOGIC;
        reset_n      : in  STD_LOGIC;
        clk_100mhz   : out STD_LOGIC;
        clk_25mhz    : out STD_LOGIC;
        clk_12mhz    : out STD_LOGIC;
        locked       : out STD_LOGIC
    );
end clk_gen;

architecture Behavioral of clk_gen is
    signal clk_fb : STD_LOGIC;
    signal clk_100_int, clk_25_int, clk_12_int : STD_LOGIC;
    signal locked_int : STD_LOGIC;
begin
    -- PLL instantiation (Xilinx specific - adjust for your FPGA)
    -- This is a simplified representation
    process(clk_in)
        variable counter : integer := 0;
    begin
        if rising_edge(clk_in) then
            counter := counter + 1;
            if counter = 1 then
                clk_100_int <= not clk_100_int;
                counter := 0;
            end if;
        end if;
    end process;
    
    clk_100mhz <= clk_100_int;
    clk_25mhz <= clk_25_int;
    clk_12mhz <= clk_12_int;
    locked <= locked_int;
    
    locked_int <= '1' after 100 ns;
end Behavioral;


-- ADC Controller Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity adc_controller is
    Port (
        clk          : in  STD_LOGIC;
        reset_n      : in  STD_LOGIC;
        enable       : in  STD_LOGIC;
        adc_data     : in  STD_LOGIC_VECTOR(15 downto 0);
        adc_clk      : out STD_LOGIC;
        adc_cs_n     : out STD_LOGIC;
        sample_data  : out STD_LOGIC_VECTOR(15 downto 0);
        sample_valid : out STD_LOGIC
    );
end adc_controller;

architecture Behavioral of adc_controller is
    signal clk_div : unsigned(7 downto 0);
    signal adc_clk_int : STD_LOGIC;
    signal sample_counter : unsigned(3 downto 0);
    signal sampling : STD_LOGIC;
begin
    
    -- Generate ADC clock (divide by 256)
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            clk_div <= (others => '0');
            adc_clk_int <= '0';
        elsif rising_edge(clk) then
            clk_div <= clk_div + 1;
            if clk_div = 0 then
                adc_clk_int <= not adc_clk_int;
            end if;
        end if;
    end process;
    
    adc_clk <= adc_clk_int when enable = '1' else '0';
    adc_cs_n <= not enable;
    
    -- Sample data capture
    process(adc_clk_int, reset_n)
    begin
        if reset_n = '0' then
            sample_data <= (others => '0');
            sample_valid <= '0';
            sample_counter <= (others => '0');
            sampling <= '0';
        elsif rising_edge(adc_clk_int) then
            if enable = '1' then
                if sample_counter = 15 then
                    sample_data <= adc_data;
                    sample_valid <= '1';
                    sample_counter <= (others => '0');
                else
                    sample_valid <= '0';
                    sample_counter <= sample_counter + 1;
                end if;
            else
                sample_valid <= '0';
            end if;
        end if;
    end process;

end Behavioral;


-- Audio Compressor Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity audio_compressor is
    Port (
        clk           : in  STD_LOGIC;
        reset_n       : in  STD_LOGIC;
        audio_in      : in  STD_LOGIC_VECTOR(15 downto 0);
        audio_valid   : in  STD_LOGIC;
        compressed_out: out STD_LOGIC_VECTOR(7 downto 0);
        comp_valid    : out STD_LOGIC;
        compression_ratio : in STD_LOGIC_VECTOR(2 downto 0)
    );
end audio_compressor;

architecture Behavioral of audio_compressor is
    signal audio_signed : signed(15 downto 0);
    signal compressed_signed : signed(7 downto 0);
    signal shift_amount : integer range 0 to 7;
begin
    
    audio_signed <= signed(audio_in);
    
    -- Determine shift amount based on compression ratio
    shift_amount <= 1 when compression_ratio = "001" else  -- 2:1
                   2 when compression_ratio = "010" else  -- 4:1
                   3 when compression_ratio = "011" else  -- 8:1
                   1; -- default 2:1
    
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            compressed_out <= (others => '0');
            comp_valid <= '0';
        elsif rising_edge(clk) then
            if audio_valid = '1' then
                -- Simple compression by bit shifting and saturation
                if audio_signed > 0 then
                    compressed_signed <= resize(shift_right(audio_signed, shift_amount), 8);
                else
                    compressed_signed <= resize(shift_right(audio_signed, shift_amount), 8);
                end if;
                
                compressed_out <= std_logic_vector(compressed_signed);
                comp_valid <= '1';
            else
                comp_valid <= '0';
            end if;
        end if;
    end process;

end Behavioral;
