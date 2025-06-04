-- Gas Chromatography Top Level Module
-- Complete FPGA implementation with external interfaces

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gc_package.all;

entity gc_chip_top is
    port (
        -- Clock and reset
        clk_100mhz          : in  std_logic;
        rst_n               : in  std_logic;
        
        -- External control interface (SPI/I2C slave)
        spi_cs_n            : in  std_logic;
        spi_sclk            : in  std_logic;
        spi_mosi            : in  std_logic;
        spi_miso            : out std_logic;
        
        -- ADC interface
        adc_cs_n            : out std_logic;
        adc_sclk            : out std_logic;
        adc_mosi            : out std_logic;
        adc_miso            : in  std_logic;
        adc_conv_start      : out std_logic;
        adc_busy            : in  std_logic;
        
        -- Sensor array interface
        sensor_select       : out std_logic_vector(2 downto 0);
        sensor_enable       : out std_logic;
        sensor_power        : out std_logic;
        sensor_heater       : out std_logic_vector(NUM_SENSORS-1 downto 0);
        
        -- Status LEDs
        led_ready           : out std_logic;
        led_sampling        : out std_logic;
        led_pattern_found   : out std_logic;
        led_error           : out std_logic;
        
        -- External memory interface (optional)
        mem_addr            : out std_logic_vector(15 downto 0);
        mem_data            : inout std_logic_vector(31 downto 0);
        mem_we_n            : out std_logic;
        mem_oe_n            : out std_logic;
        mem_ce_n            : out std_logic;
        
        -- UART interface for debugging
        uart_tx             : out std_logic;
        uart_rx             : in  std_logic;
        
        -- Interrupt output
        irq_out             : out std_logic;
        
        -- GPIO for expansion
        gpio                : inout std_logic_vector(7 downto 0)
    );
end entity gc_chip_top;

architecture rtl of gc_chip_top is
    
    -- Component declarations
    component gc_core is
        port (
            clk                 : in  std_logic;
            rst_n               : in  std_logic;
            gc_control          : in  gc_control_t;
            gc_status           : out gc_status_t;
            sample_rate_div     : in  std_logic_vector(15 downto 0);
            sensitivity_level   : in  std_logic_vector(3 downto 0);
            num_samples         : in  std_logic_vector(15 downto 0);
            adc_interface       : out adc_interface_t;
            adc_miso            : in  std_logic;
            sensor_select       : out std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
            sensor_enable       : out std_logic;
            pattern_detected    : out std_logic;
            pattern_id          : out std_logic_vector(log2_ceil(NUM_TEMPLATES)-1 downto 0);
            confidence_level    : out std_logic_vector(7 downto 0);
            mem_addr            : out std_logic_vector(15 downto 0);
            mem_data_out        : out std_logic_vector(31 downto 0);
            mem_data_in         : in  std_logic_vector(31 downto 0);
            mem_we              : out std_logic;
            mem_re              : out std_logic;
            current_sensor      : out std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
            sample_count        : out std_logic_vector(15 downto 0);
            debug_pattern       : out pattern_array_t
        );
    end component;
    
    -- Internal signals
    signal clk_system           : std_logic;
    signal reset_sync           : std_logic;
    signal pll_locked           : std_logic;
    
    -- Control and status
    signal gc_ctrl              : gc_control_t;
    signal gc_stat              : gc_status_t;
    signal config_regs          : std_logic_vector(127 downto 0);
    
    -- Core interface signals
    signal core_adc_if          : adc_interface_t;
    signal core_sensor_sel      : std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
    signal core_sensor_en       : std_logic;
    signal core_pattern_det     : std_logic;
    signal core_pattern_id      : std_logic_vector(log2_ceil(NUM_TEMPLATES)-1 downto 0);
    signal core_confidence      : std_logic_vector(7 downto 0);
    signal core_mem_addr        : std_logic_vector(15 downto 0);
    signal core_mem_data_out    : std_logic_vector(31 downto 0);
    signal core_mem_data_in     : std_logic_vector(31 downto 0);
    signal core_mem_we          : std_logic;
    signal core_mem_re          : std_logic;
    signal core_current_sensor  : std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
    signal core_sample_count    : std_logic_vector(15 downto 0);
    signal core_debug_pattern   : pattern_array_t;
    
    -- SPI interface signals
    signal spi_cmd_reg          : std_logic_vector(7 downto 0);
    signal spi_addr_reg         : std_logic_vector(15 downto 0);
    signal spi_data_reg         : std_logic_vector(31 downto 0);
    signal spi_byte_counter     : unsigned(2 downto 0);
    signal spi_shift_reg        : std_logic_vector(7 downto 0);
    signal spi_active           : std_logic;
    signal spi_new_byte         : std_logic;
    
    -- Memory interface
    signal mem_data_out_int     : std_logic_vector(31 downto 0);
    signal mem_data_in_int      : std_logic_vector(31 downto 0);
    signal mem_tri_enable       : std_logic;
    
    -- UART interface
    signal uart_tx_data         : std_logic_vector(7 downto 0);
    signal uart_tx_valid        : std_logic;
    signal uart_tx_ready        : std_logic;
    signal uart_rx_data         : std_logic_vector(7 downto 0);
    signal uart_rx_valid        : std_logic;
    
    -- Interrupt management
    signal irq_mask             : std_logic_vector(7 downto 0);
    signal irq_status           : std_logic_vector(7 downto 0);
    signal irq_pending          : std_logic;
    
    -- Sensor heater control
    signal heater_pwm_counter   : unsigned(7 downto 0);
    signal heater_duty_cycle    : std_logic_vector(7 downto 0);
    signal heater_enable        : std_logic;
    
    -- Timing and control
    signal startup_counter      : unsigned(15 downto 0);
    signal system_ready         : std_logic;
    
begin
    
    -- Clock management (simplified - would use PLL in real implementation)
    clk_system <= clk_100mhz;
    pll_locked <= '1';
    
    -- Reset synchronizer
    process(clk_system, rst_n)
    begin
        if rst_n = '0' then
            reset_sync <= '0';
            startup_counter <= (others => '0');
            system_ready <= '0';
        elsif rising_edge(clk_system) then
            if pll_locked = '1' then
                if startup_counter < 65535 then
                    startup_counter <= startup_counter + 1;
                    reset_sync <= '0';
                else
                    reset_sync <= '1';
                    system_ready <= '1';
                end if;
            else
                startup_counter <= (others => '0');
                reset_sync <= '0';
                system_ready <= '0';
            end if;
        end if;
    end process;
    
    -- Gas Chromatography Core instantiation
    u_gc_core: gc_core
        port map (
            clk                 => clk_system,
            rst_n               => reset_sync,
            gc_control          => gc_ctrl,
            gc_status           => gc_stat,
            sample_rate_div     => config_regs(15 downto 0),
            sensitivity_level   => config_regs(19 downto 16),
            num_samples         => config_regs(31 downto 16),
            adc_interface       => core_adc_if,
            adc_miso            => adc_miso,
            sensor_select       => core_sensor_sel,
            sensor_enable       => core_sensor_en,
            pattern_detected    => core_pattern_det,
            pattern_id          => core_pattern_id,
            confidence_level    => core_confidence,
            mem_addr            => core_mem_addr,
            mem_data_out        => core_mem_data_out,
            mem_data_in         => core_mem_data_in,
            mem_we              => core_mem_we,
            mem_re              => core_mem_re,
            current_sensor      => core_current_sensor,
            sample_count        => core_sample_count,
            debug_pattern       => core_debug_pattern
        );
    
    -- SPI slave interface for external control
    process(clk_system, reset_sync)
    begin
        if reset_sync = '0' then
            spi_cmd_reg <= (others => '0');
            spi_addr_reg <= (others => '0');
            spi_data_reg <= (others => '0');
            spi_byte_counter <= (others => '0');
            spi_shift_reg <= (others => '0');
            spi_active <= '0';
            spi_new_byte <= '0';
            config_regs <= x"00001000000003E8000000FF"; -- Default config
        elsif rising_edge(clk_system) then
            spi_new_byte <= '0';
            
            if spi_cs_n = '0' then
                spi_active <= '1';
                
                -- SPI shift register (simplified)
                if spi_sclk'event and spi_sclk = '1' then
                    spi_shift_reg <= spi_shift_reg(6 downto 0) & spi_mosi;
                    
                    if spi_byte_counter = 7 then
                        spi_byte_counter <= (others => '0');
                        spi_new_byte <= '1';
                        
                        -- Process received byte
                        case spi_byte_counter is
                            when "000" => 
                                spi_cmd_reg <= spi_shift_reg;
                            when "001" | "010" => 
                                spi_addr_reg <= spi_addr_reg(7 downto 0) & spi_shift_reg;
                            when others => 
                                spi_data_reg <= spi_data_reg(23 downto 0) & spi_shift_reg;
                        end case;
                    else
                        spi_byte_counter <= spi_byte_counter + 1;
                    end if;
                end if;
            else
                spi_active <= '0';
                spi_byte_counter <= (others => '0');
                
                -- Process completed SPI transaction
                if spi_active = '1' then
                    case spi_cmd_reg is
                        when x"01" => -- Write config register
                            case spi_addr_reg(3 downto 0) is
                                when x"0" => config_regs(31 downto 0) <= spi_data_reg;
                                when x"1" => config_regs(63 downto 32) <= spi_data_reg;
                                when x"2" => config_regs(95 downto 64) <= spi_data_reg;
                                when x"3" => config_regs(127 downto 96) <= spi_data_reg;
                                when others => null;
                            end case;
                            
                        when x"02" => -- Start measurement
                            gc_ctrl.start <= '1';
                            
                        when x"03" => -- Stop measurement
                            gc_ctrl.start <= '0';
                            
                        when x"04" => -- Reset system
                            gc_ctrl.reset <= '1';
                            
                        when others => 
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    -- Control signal generation
    gc_ctrl.enable <= system_ready and config_regs(32);
    gc_ctrl.sample_trigger <= config_regs(33);
    gc_ctrl.process_enable <= config_regs(34);
    
    -- Memory interface management
    mem_addr <= core_mem_addr;
    mem_we_n <= not core_mem_we;
    mem_oe_n <= not core_mem_re;
    mem_ce_n <= not (core_mem_we or core_mem_re);
    
    -- Bidirectional memory data bus
    mem_tri_enable <= core_mem_we;
    mem_data <= core_mem_data_out when mem_tri_enable = '1' else (others => 'Z');
    core_mem_data_in <= mem_data;
    
    -- ADC interface connections
    adc_cs_n <= core_adc_if.cs_n;
    adc_sclk <= core_adc_if.sclk;
    adc_mosi <= core_adc_if.mosi;
    adc_conv_start <= core_adc_if.conv_start;
    
    -- Sensor interface
    sensor_select <= core_sensor_sel;
    sensor_enable <= core_sensor_en;
    sensor_power <= system_ready and gc_ctrl.enable;
    
    -- Sensor heater PWM control
    process(clk_system, reset_sync)
    begin
        if reset_sync = '0' then
            heater_pwm_counter <= (others => '0');
            sensor_heater <= (others => '0');
        elsif rising_edge(clk_system) then
            heater_pwm_counter <= heater_pwm_counter + 1;
            
            heater_duty_cycle <= config_regs(71 downto 64);
            heater_enable <= config_regs(72);
            
            if heater_enable = '1' then
                for i in 0 to NUM_SENSORS-1 loop
                    if heater_pwm_counter < unsigned(heater_duty_cycle) then
                        sensor_heater(i) <= '1';
                    else
                        sensor_heater(i) <= '0';
                    end if;
                end loop;
            else
                sensor_heater <= (others => '0');
            end if;
        end if;
    end process;
    
    -- Interrupt management
    irq_status(0) <= gc_stat.ready;
    irq_status(1) <= gc_stat.data_valid;
    irq_status(2) <= core_pattern_det;
    irq_status(3) <= gc_stat.error;
    irq_status(7 downto 4) <= (others => '0');
    
    irq_mask <= config_regs(87 downto 80);
    irq_pending <= '1' when (irq_status and irq_mask) /= "00000000" else '0';
    irq_out <= irq_pending;
    
    -- Status LED control
    led_ready <= gc_stat.ready;
    led_sampling <= gc_stat.busy;
    led_pattern_found <= core_pattern_det;
    led_error <= gc_stat.error;
    
    -- Simple UART transmitter for debugging (simplified implementation)
    process(clk_system, reset_sync)
        variable uart_counter : unsigned(15 downto 0) := (others => '0');
        variable uart_bit_counter : unsigned(3 downto 0) := (others => '0');
        variable uart_tx_reg : std_logic_vector(9 downto 0) := (others => '1');
        variable uart_state : std_logic := '0';
    begin
        if reset_sync = '0' then
            uart_tx <= '1';
            uart_counter := (others => '0');
            uart_bit_counter := (others => '0');
            uart_tx_reg := (others => '1');
            uart_state := '0';
        elsif rising_edge(clk_system) then
            if uart_state = '0' then
                uart_tx <= '1';
                -- Send status periodically
                if uart_counter = 0 then
                    uart_tx_reg := '1' & x"A5" & '0'; -- Status byte
                    uart_state := '1';
                    uart_bit_counter := (others => '0');
                end if;
                uart_counter := uart_counter + 1;
            else
                -- Transmit bits at 115200 baud (simplified)
                if uart_counter >= 868 then -- 100MHz / 115200
                    uart_counter := (others => '0');
                    uart_tx <= uart_tx_reg(0);
                    uart_tx_reg := '1' & uart_tx_reg(9 downto 1);
                    
                    if uart_bit_counter = 9 then
                        uart_state := '0';
                        uart_counter := (others => '0');
                    else
                        uart_bit_counter := uart_bit_counter + 1;
                    end if;
                else
                    uart_counter := uart_counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- SPI MISO output
    spi_miso <= spi_shift_reg(7) when spi_active = '1' else 'Z';
    
    -- GPIO assignments (for expansion)
    gpio(0) <= core_pattern_det;
    gpio(1) <= gc_stat.busy;
    gpio(2) <= system_ready;
    gpio(3) <= irq_pending;
    gpio(7 downto 4) <= (others => 'Z');
    
end architecture rtl;
