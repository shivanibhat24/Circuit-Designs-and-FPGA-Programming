-- cubesat_daq_top.vhd
-- Top level module for CubeSat DAQ system
-- Integrates all sensor interfaces and communication

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cubesat_daq_top is
    port (
        -- System clock and reset
        sys_clk_50mhz  : in  std_logic;
        sys_rst_n      : in  std_logic;
        
        -- Radiation sensor interface (SPI)
        rad_sclk       : out std_logic;
        rad_mosi       : out std_logic;
        rad_miso       : in  std_logic;
        rad_cs_n       : out std_logic;
        
        -- Magnetometer interface (I2C)
        mag_scl        : inout std_logic;
        mag_sda        : inout std_logic;
        mag_int        : in  std_logic;
        
        -- Thermal sensor interface (1-Wire)
        therm_dq       : inout std_logic;
        
        -- UART interface for telemetry
        uart_tx        : out std_logic;
        uart_rx        : in  std_logic;
        
        -- SPI interface for external communication
        spi_sclk       : in  std_logic;
        spi_mosi       : in  std_logic;
        spi_miso       : out std_logic;
        spi_cs_n       : in  std_logic;
        
        -- Status LEDs
        led_status     : out std_logic_vector(3 downto 0);
        
        -- Power management
        sensor_pwr_en  : out std_logic_vector(2 downto 0)
    );
end cubesat_daq_top;

architecture rtl of cubesat_daq_top is

    -- Component declarations
    component cubesat_daq_core is
        generic (
            DATA_WIDTH     : integer := 16;
            FIFO_DEPTH     : integer := 1024;
            NUM_SENSORS    : integer := 3;
            SAMPLE_DIV     : integer := 1000
        );
        port (
            clk            : in  std_logic;
            rst_n          : in  std_logic;
            rad_data       : in  std_logic_vector(15 downto 0);
            rad_valid      : in  std_logic;
            mag_data_x     : in  std_logic_vector(15 downto 0);
            mag_data_y     : in  std_logic_vector(15 downto 0);
            mag_data_z     : in  std_logic_vector(15 downto 0);
            mag_valid      : in  std_logic;
            therm_data     : in  std_logic_vector(15 downto 0);
            therm_valid    : in  std_logic;
            enable         : in  std_logic;
            sample_rate    : in  std_logic_vector(15 downto 0);
            data_out       : out std_logic_vector(15 downto 0);
            data_valid     : out std_logic;
            data_ready     : in  std_logic;
            sensor_id      : out std_logic_vector(7 downto 0);
            timestamp      : out std_logic_vector(31 downto 0);
            fifo_full      : out std_logic;
            fifo_empty     : out std_logic;
            error_flag     : out std_logic
        );
    end component;
    
    component sensor_interfaces is
        port (
            clk            : in  std_logic;
            rst_n          : in  std_logic;
            -- Radiation sensor SPI
            rad_sclk       : out std_logic;
            rad_mosi       : out std_logic;
            rad_miso       : in  std_logic;
            rad_cs_n       : out std_logic;
            rad_data       : out std_logic_vector(15 downto 0);
            rad_valid      : out std_logic;
            -- Magnetometer I2C
            mag_scl        : inout std_logic;
            mag_sda        : inout std_logic;
            mag_int        : in  std_logic;
            mag_data_x     : out std_logic_vector(15 downto 0);
            mag_data_y     : out std_logic_vector(15 downto 0);
            mag_data_z     : out std_logic_vector(15 downto 0);
            mag_valid      : out std_logic;
            -- Thermal sensor 1-Wire
            therm_dq       : inout std_logic;
            therm_data     : out std_logic_vector(15 downto 0);
            therm_valid    : out std_logic;
            -- Control
            sensor_enable  : in  std_logic_vector(2 downto 0)
        );
    end component;
    
    component comm_controller is
        port (
            clk            : in  std_logic;
            rst_n          : in  std_logic;
            -- UART interface
            uart_tx        : out std_logic;
            uart_rx        : in  std_logic;
            -- SPI slave interface
            spi_sclk       : in  std_logic;
            spi_mosi       : in  std_logic;
            spi_miso       : out std_logic;
            spi_cs_n       : in  std_logic;
            -- Data interface
            data_in        : in  std_logic_vector(15 downto 0);
            data_valid_in  : in  std_logic;
            data_ready     : out std_logic;
            sensor_id_in   : in  std_logic_vector(7 downto 0);
            timestamp_in   : in  std_logic_vector(31 downto 0);
            -- Control interface
            daq_enable     : out std_logic;
            sample_rate    : out std_logic_vector(15 downto 0);
            sensor_pwr_en  : out std_logic_vector(2 downto 0);
            -- Status
            tx_busy        : out std_logic;
            comm_error     : out std_logic
        );
    end component;

    -- Internal signals
    signal clk_int         : std_logic;
    signal rst_int_n       : std_logic;
    
    -- DAQ core signals
    signal rad_data_int    : std_logic_vector(15 downto 0);
    signal rad_valid_int   : std_logic;
    signal mag_data_x_int  : std_logic_vector(15 downto 0);
    signal mag_data_y_int  : std_logic_vector(15 downto 0);
    signal mag_data_z_int  : std_logic_vector(15 downto 0);
    signal mag_valid_int   : std_logic;
    signal therm_data_int  : std_logic_vector(15 downto 0);
    signal therm_valid_int : std_logic;
    
    signal daq_enable      : std_logic;
    signal sample_rate_int : std_logic_vector(15 downto 0);
    signal data_out_int    : std_logic_vector(15 downto 0);
    signal data_valid_int  : std_logic;
    signal data_ready_int  : std_logic;
    signal sensor_id_int   : std_logic_vector(7 downto 0);
    signal timestamp_int   : std_logic_vector(31 downto 0);
    
    -- Status signals
    signal fifo_full_int   : std_logic;
    signal fifo_empty_int  : std_logic;
    signal error_flag_int  : std_logic;
    signal tx_busy_int     : std_logic;
    signal comm_error_int  : std_logic;
    
    -- Power management
    signal sensor_pwr_int  : std_logic_vector(2 downto 0);

begin

    -- Clock and reset management
    clk_int <= sys_clk_50mhz;
    rst_int_n <= sys_rst_n;
    
    -- Instantiate DAQ core
    daq_core_inst : cubesat_daq_core
        generic map (
            DATA_WIDTH  => 16,
            FIFO_DEPTH  => 1024,
            NUM_SENSORS => 3,
            SAMPLE_DIV  => 1000
        )
        port map (
            clk          => clk_int,
            rst_n        => rst_int_n,
            rad_data     => rad_data_int,
            rad_valid    => rad_valid_int,
            mag_data_x   => mag_data_x_int,
            mag_data_y   => mag_data_y_int,
            mag_data_z   => mag_data_z_int,
            mag_valid    => mag_valid_int,
            therm_data   => therm_data_int,
            therm_valid  => therm_valid_int,
            enable       => daq_enable,
            sample_rate  => sample_rate_int,
            data_out     => data_out_int,
            data_valid   => data_valid_int,
            data_ready   => data_ready_int,
            sensor_id    => sensor_id_int,
            timestamp    => timestamp_int,
            fifo_full    => fifo_full_int,
            fifo_empty   => fifo_empty_int,
            error_flag   => error_flag_int
        );
    
    -- Instantiate sensor interfaces
    sensor_intf_inst : sensor_interfaces
        port map (
            clk           => clk_int,
            rst_n         => rst_int_n,
            rad_sclk      => rad_sclk,
            rad_mosi      => rad_mosi,
            rad_miso      => rad_miso,
            rad_cs_n      => rad_cs_n,
            rad_data      => rad_data_int,
            rad_valid     => rad_valid_int,
            mag_scl       => mag_scl,
            mag_sda       => mag_sda,
            mag_int       => mag_int,
            mag_data_x    => mag_data_x_int,
            mag_data_y    => mag_data_y_int,
            mag_data_z    => mag_data_z_int,
            mag_valid     => mag_valid_int,
            therm_dq      => therm_dq,
            therm_data    => therm_data_int,
            therm_valid   => therm_valid_int,
            sensor_enable => sensor_pwr_int
        );
    
    -- Instantiate communication controller
    comm_ctrl_inst : comm_controller
        port map (
            clk           => clk_int,
            rst_n         => rst_int_n,
            uart_tx       => uart_tx,
            uart_rx       => uart_rx,
            spi_sclk      => spi_sclk,
            spi_mosi      => spi_mosi,
            spi_miso      => spi_miso,
            spi_cs_n      => spi_cs_n,
            data_in       => data_out_int,
            data_valid_in => data_valid_int,
            data_ready    => data_ready_int,
            sensor_id_in  => sensor_id_int,
            timestamp_in  => timestamp_int,
            daq_enable    => daq_enable,
            sample_rate   => sample_rate_int,
            sensor_pwr_en => sensor_pwr_int,
            tx_busy       => tx_busy_int,
            comm_error    => comm_error_int
        );
    
    -- Power management output
    sensor_pwr_en <= sensor_pwr_int;
    
    -- Status LED assignments
    led_status(0) <= daq_enable;           -- System active
    led_status(1) <= not fifo_empty_int;   -- Data available
    led_status(2) <= error_flag_int or comm_error_int; -- Error condition
    led_status(3) <= tx_busy_int;          -- Communication active

end rtl;
