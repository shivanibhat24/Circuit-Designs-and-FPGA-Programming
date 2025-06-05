-- cubesat_daq_pkg.vhd
-- Package file for CubeSat DAQ system
-- Contains constants, types, and utility functions

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package cubesat_daq_pkg is

    -- System constants
    constant SYSTEM_CLK_FREQ    : integer := 50000000;  -- 50MHz system clock
    constant UART_BAUD_RATE     : integer := 115200;    -- UART baud rate
    constant SPI_CLK_FREQ       : integer := 1000000;   -- 1MHz SPI clock
    constant I2C_CLK_FREQ       : integer := 400000;    -- 400kHz I2C clock
    
    -- Data format constants
    constant DATA_WIDTH         : integer := 16;        -- Sensor data width
    constant TIMESTAMP_WIDTH    : integer := 32;        -- Timestamp width
    constant SENSOR_ID_WIDTH    : integer := 8;         -- Sensor ID width
    constant FIFO_DEPTH         : integer := 1024;      -- FIFO depth
    
    -- Sensor IDs
    constant RAD_SENSOR_ID      : std_logic_vector(7 downto 0) := x"01";
    constant MAG_X_SENSOR_ID    : std_logic_vector(7 downto 0) := x"02";
    constant MAG_Y_SENSOR_ID    : std_logic_vector(7 downto 0) := x"03";
    constant MAG_Z_SENSOR_ID    : std_logic_vector(7 downto 0) := x"04";
    constant THERM_SENSOR_ID    : std_logic_vector(7 downto 0) := x"05";
    
    -- Command constants
    constant CMD_START_DAQ      : std_logic_vector(7 downto 0) := x"01";
    constant CMD_STOP_DAQ       : std_logic_vector(7 downto 0) := x"02";
    constant CMD_SET_RATE       : std_logic_vector(7 downto 0) := x"03";
    constant CMD_GET_STATUS     : std_logic_vector(7 downto 0) := x"04";
    constant CMD_RESET_SYSTEM   : std_logic_vector(7 downto 0) := x"05";
    constant CMD_POWER_CONTROL  : std_logic_vector(7 downto 0) := x"06";
    
    -- Status constants
    constant STATUS_IDLE        : std_logic_vector(7 downto 0) := x"00";
    constant STATUS_RUNNING     : std_logic_vector(7 downto 0) := x"01";
    constant STATUS_ERROR       : std_logic_vector(7 downto 0) := x"02";
    constant STATUS_FIFO_FULL   : std_logic_vector(7 downto 0) := x"03";
    
    -- Telemetry packet structure
    type telemetry_packet_t is record
        header      : std_logic_vector(15 downto 0);
        sensor_id   : std_logic_vector(7 downto 0);
        timestamp   : std_logic_vector(31 downto 0);
        data        : std_logic_vector(15 downto 0);
        checksum    : std_logic_vector(7 downto 0);
    end record;
    
    -- Sensor configuration record
    type sensor_config_t is record
        enabled     : std_logic;
        sample_rate : std_logic_vector(15 downto 0);
        threshold   : std_logic_vector(15 downto 0);
        gain        : std_logic_vector(7 downto 0);
    end record;
    
    -- System status record
    type system_status_t is record
        daq_running    : std_logic;
        fifo_full      : std_logic;
        fifo_empty     : std_logic;
        sensor_errors  : std_logic_vector(2 downto 0);
        comm_error     : std_logic;
        power_status   : std_logic_vector(2 downto 0);
        sample_count   : std_logic_vector(31 downto 0);
    end record;
    
    -- Function declarations
    function calculate_checksum(data : std_logic_vector) return std_logic_vector;
    function pack_telemetry(packet : telemetry_packet_t) return std_logic_vector;
    function unpack_telemetry(data : std_logic_vector) return telemetry_packet_t;
    function gray_to_binary(gray : std_logic_vector) return std_logic_vector;
    function binary_to_gray(binary : std_logic_vector) return std_logic_vector;
    
    -- Component declarations
    component spi_master is
        generic (
            DATA_WIDTH : integer := 16;
            CLK_DIV    : integer := 50
        );
        port (
            clk        : in  std_logic;
            rst_n      : in  std_logic;
            start      : in  std_logic;
            tx_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            rx_data    : out std_logic_vector(DATA_WIDTH-1 downto 0);
            data_valid : out std_logic;
            busy       : out std_logic;
            sclk       : out std_logic;
            mosi       : out std_logic;
            miso       : in  std_logic;
            cs_n       : out std_logic
        );
    end component;
    
    component i2c_master is
        generic (
            CLK_FREQ   : integer := 50000000;
            I2C_FREQ   : integer := 400000
        );
        port (
            clk        : in  std_logic;
            rst_n      : in  std_logic;
            start      : in  std_logic;
            rw         : in  std_logic;
            slave_addr : in  std_logic_vector(6 downto 0);
            reg_addr   : in  std_logic_vector(7 downto 0);
            tx_data    : in  std_logic_vector(7 downto 0);
            rx_data    : out std_logic_vector(7 downto 0);
            data_valid : out std_logic;
            busy       : out std_logic;
            ack_error  : out std_logic;
            scl        : inout std_logic;
            sda        : inout std_logic
        );
    end component;
    
    component onewire_master is
        generic (
            CLK_FREQ : integer := 50000000
        );
        port (
            clk        : in  std_logic;
            rst_n      : in  std_logic;
            start      : in  std_logic;
            command    : in  std_logic_vector(7 downto 0);
            tx_data    : in  std_logic_vector(63 downto 0);
            rx_data    : out std_logic_vector(63 downto 0);
            data_valid : out std_logic;
            busy       : out std_logic;
            dq         : inout std_logic
        );
    end component;
    
    component uart_transceiver is
        generic (
            CLK_FREQ   : integer := 50000000;
            BAUD_RATE  : integer := 115200
        );
        port (
            clk        : in  std_logic;
            rst_n      : in  std_logic;
            -- TX interface
            tx_start   : in  std_logic;
            tx_data    : in  std_logic_vector(7 downto 0);
            tx_busy    : out std_logic;
            tx_done    : out std_logic;
            -- RX interface
            rx_data    : out std_logic_vector(7 downto 0);
            rx_valid   : out std_logic;
            rx_error   : out std_logic;
            -- Physical interface
            uart_tx    : out std_logic;
            uart_rx    : in  std_logic
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

end package cubesat_daq_pkg;

package body cubesat_daq_pkg is

    -- Calculate simple XOR checksum
    function calculate_checksum(data : std_logic_vector) return std_logic_vector is
        variable checksum : std_logic_vector(7 downto 0) := (others => '0');
        variable temp     : std_logic_vector(7 downto 0);
    begin
        for i in 0 to (data'length/8)-1 loop
            temp := data((i+1)*8-1 downto i*8);
            checksum := checksum xor temp;
        end loop;
        return checksum;
    end function;
    
    -- Pack telemetry packet into bit vector
    function pack_telemetry(packet : telemetry_packet_t) return std_logic_vector is
        variable result : std_logic_vector(79 downto 0); -- 80 bits total
    begin
        result(79 downto 64) := packet.header;
        result(63 downto 56) := packet.sensor_id;
        result(55 downto 24) := packet.timestamp;
        result(23 downto 8)  := packet.data;
        result(7 downto 0)   := packet.checksum;
        return result;
    end function;
    
    -- Unpack bit vector into telemetry packet
    function unpack_telemetry(data : std_logic_vector) return telemetry_packet_t is
        variable packet : telemetry_packet_t;
    begin
        packet.header    := data(79 downto 64);
        packet.sensor_id := data(63 downto 56);
        packet.timestamp := data(55 downto 24);
        packet.data      := data(23 downto 8);
        packet.checksum  := data(7 downto 0);
        return packet;
    end function;
    
    -- Convert Gray code to Binary
    function gray_to_binary(gray : std_logic_vector) return std_logic_vector is
        variable binary : std_logic_vector(gray'range);
    begin
        binary(gray'high) := gray(gray'high);
        for i in gray'high-1 downto gray'low loop
            binary(i) := binary(i+1) xor gray(i);
        end loop;
        return binary;
    end function;
    
    -- Convert Binary to Gray code
    function binary_to_gray(binary : std_logic_vector) return std_logic_vector is
        variable gray : std_logic_vector(binary'range);
    begin
        gray(binary'high) := binary(binary'high);
        for i in binary'high-1 downto binary'low loop
            gray(i) := binary(i+1) xor binary(i);
        end loop;
        return gray;
    end function;

end package body cubesat_daq_pkg;
