-- sensor_interfaces.vhd
-- Sensor interface controllers for radiation, magnetometer, and thermal sensors
-- Handles SPI, I2C, and 1-Wire protocols

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sensor_interfaces is
    port (
        -- System signals
        clk            : in  std_logic;
        rst_n          : in  std_logic;
        
        -- Radiation sensor SPI interface
        rad_sclk       : out std_logic;
        rad_mosi       : out std_logic;
        rad_miso       : in  std_logic;
        rad_cs_n       : out std_logic;
        rad_data       : out std_logic_vector(15 downto 0);
        rad_valid      : out std_logic;
        
        -- Magnetometer I2C interface
        mag_scl        : inout std_logic;
        mag_sda        : inout std_logic;
        mag_int        : in  std_logic;
        mag_data_x     : out std_logic_vector(15 downto 0);
        mag_data_y     : out std_logic_vector(15 downto 0);
        mag_data_z     : out std_logic_vector(15 downto 0);
        mag_valid      : out std_logic;
        
        -- Thermal sensor 1-Wire interface
        therm_dq       : inout std_logic;
        therm_data     : out std_logic_vector(15 downto 0);
        therm_valid    : out std_logic;
        
        -- Control signals
        sensor_enable  : in  std_logic_vector(2 downto 0) -- [2]=therm, [1]=mag, [0]=rad
    );
end sensor_interfaces;

architecture rtl of sensor_interfaces is

    -- SPI Master for Radiation Sensor
    component spi_master is
        generic (
            DATA_WIDTH : integer := 16;
            CLK_DIV    : integer := 50  -- 1MHz SPI clock from 50MHz
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
    
    -- I2C Master for Magnetometer
    component i2c_master is
        generic (
            CLK_FREQ   : integer := 50000000;  -- 50MHz
            I2C_FREQ   : integer := 400000     -- 400kHz
        );
        port (
            clk        : in  std_logic;
            rst_n      : in  std_logic;
            start      : in  std_logic;
            rw         : in  std_logic; -- '0' for write, '1' for read
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
    
    -- 1-Wire Master for Thermal Sensor
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

    -- Radiation sensor signals
    signal rad_spi_start    : std_logic;
    signal rad_spi_tx_data  : std_logic_vector(15 downto 0);
    signal rad_spi_rx_data  : std_logic_vector(15 downto 0);
    signal rad_spi_valid    : std_logic;
    signal rad_spi_busy     : std_logic;
    signal rad_timer        : unsigned(19 downto 0); -- ~20ms timer
    signal rad_state        : integer range 0 to 3;
    
    -- Magnetometer signals
    signal mag_i2c_start    : std_logic;
    signal mag_i2c_rw       : std_logic;
    signal mag_i2c_addr     : std_logic_vector(6 downto 0);
    signal mag_i2c_reg      : std_logic_vector(7 downto 0);
    signal mag_i2c_tx_data  : std_logic_vector(7 downto 0);
    signal mag_i2c_rx_data  : std_logic_vector(7 downto 0);
    signal mag_i2c_valid    : std_logic;
    signal mag_i2c_busy     : std_logic;
    signal mag_i2c_ack_err  : std_logic;
    signal mag_timer        : unsigned(19 downto 0);
    signal mag_state        : integer range 0 to 7;
    signal mag_x_low        : std_logic_vector(7 downto 0);
    signal mag_x_high       : std_logic_vector(7 downto 0);
    signal mag_y_low        : std_logic_vector(7 downto 0);
    signal mag_y_high       : std_logic_vector(7 downto 0);
    signal mag_z_low        : std_logic_vector(7 downto 0);
    signal mag_z_high       : std_logic_vector(7 downto 0);
    
    -- Thermal sensor signals
    signal therm_ow_start   : std_logic;
    signal therm_ow_cmd     : std_logic_vector(7 downto 0);
    signal therm_ow_tx_data : std_logic_vector(63 downto 0);
    signal therm_ow_rx_data : std_logic_vector(63 downto 0);
    signal therm_ow_valid   : std_logic;
    signal therm_ow_busy    : std_logic;
    signal therm_timer      : unsigned(23 downto 0); -- ~300ms timer for conversion
    signal therm_state      : integer range 0 to 5;
    
    -- Constants
    constant RAD_READ_CMD     : std_logic_vector(15 downto 0) := x"8000"; -- Read command
    constant MAG_I2C_ADDR     : std_logic_vector(6 downto 0) := "0011110"; -- HMC5883L address
    constant THERM_SKIP_ROM   : std_logic_vector(7 downto 0) := x"CC";
    constant THERM_CONVERT_T  : std_logic_vector(7 downto 0) := x"44";
    constant THERM_READ_PAD   : std_logic_vector(7 downto 0) := x"BE";

begin

    -- Radiation Sensor SPI Interface
    rad_spi_inst : spi_master
        generic map (
            DATA_WIDTH => 16,
            CLK_DIV    => 50
        )
        port map (
            clk        => clk,
            rst_n      => rst_n,
            start      => rad_spi_start,
            tx_data    => rad_spi_tx_data,
            rx_data    => rad_spi_rx_data,
            data_valid => rad_spi_valid,
            busy       => rad_spi_busy,
            sclk       => rad_sclk,
            mosi       => rad_mosi,
            miso       => rad_miso,
            cs_n       => rad_cs_n
        );
    
    -- Radiation sensor control
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            rad_timer <= (others => '0');
            rad_state <= 0;
            rad_spi_start <= '0';
            rad_spi_tx_data <= (others => '0');
            rad_data <= (others => '0');
            rad_valid <= '0';
        elsif rising_edge(clk) then
            rad_spi_start <= '0';
            rad_valid <= '0';
            
            if sensor_enable(0) = '1' then
                case rad_state is
                    when 0 => -- Wait state
                        if rad_timer >= 1000000 then -- 20ms at 50MHz
                            rad_timer <= (others => '0');
                            rad_state <= 1;
                        else
                            rad_timer <= rad_timer + 1;
                        end if;
                        
                    when 1 => -- Start SPI transaction
                        if rad_spi_busy = '0' then
                            rad_spi_start <= '1';
                            rad_spi_tx_data <= RAD_READ_CMD;
                            rad_state <= 2;
                        end if;
                        
                    when 2 => -- Wait for SPI completion
                        if rad_spi_valid = '1' then
                            rad_data <= rad_spi_rx_data;
                            rad_valid <= '1';
                            rad_state <= 0;
                        end if;
                        
                    when others =>
                        rad_state <= 0;
                end case;
            else
                rad_state <= 0;
                rad_timer <= (others => '0');
            end if;
        end if;
    end process;
    
    -- Magnetometer I2C Interface
    mag_i2c_inst : i2c_master
        generic map (
            CLK_FREQ => 50000000,
            I2C_FREQ => 400000
        )
        port map (
            clk        => clk,
            rst_n      => rst_n,
            start      => mag_i2c_start,
            rw         => mag_i2c_rw,
            slave_addr => mag_i2c_addr,
            reg_addr   => mag_i2c_reg,
            tx_data    => mag_i2c_tx_data,
            rx_data    => mag_i2c_rx_data,
            data_valid => mag_i2c_valid,
            busy       => mag_i2c_busy,
            ack_error  => mag_i2c_ack_err,
            scl        => mag_scl,
            sda        => mag_sda
        );
    
    -- Magnetometer control
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            mag_timer <= (others => '0');
            mag_state <= 0;
            mag_i2c_start <= '0';
            mag_i2c_rw <= '0';
            mag_i2c_addr <= MAG_I2C_ADDR;
            mag_i2c_reg <= (others => '0');
            mag_i2c_tx_data <= (others => '0');
            mag_data_x <= (others => '0');
            mag_data_y <= (others => '0');
            mag_data_z <= (others => '0');
            mag_valid <= '0';
        elsif rising_edge(clk) then
            mag_i2c_start <= '0';
            mag_valid <= '0';
            
            if sensor_enable(1) = '1' then
                case mag_state is
                    when 0 => -- Wait state
                        if mag_timer >= 2500000 then -- 50ms at 50MHz
                            mag_timer <= (others => '0');
                            mag_state <= 1;
                        else
                            mag_timer <= mag_timer + 1;
                        end if;
                        
                    when 1 => -- Read X-axis MSB
                        if mag_i2c_busy = '0' then
                            mag_i2c_start <= '1';
                            mag_i2c_rw <= '1';
                            mag_i2c_reg <= x"03"; -- X MSB register
                            mag_state <= 2;
                        end if;
                        
                    when 2 => -- Store X MSB, read X LSB
                        if mag_i2c_valid = '1' then
                            mag_x_high <= mag_i2c_rx_data;
                            mag_i2c_start <= '1';
                            mag_i2c_rw <= '1';
                            mag_i2c_reg <= x"04"; -- X LSB register
                            mag_state <= 3;
                        end if;
                        
                    when 3 => -- Store X LSB, read Y MSB
                        if mag_i2c_valid = '1' then
                            mag_x_low <= mag_i2c_rx_data;
                            mag_i2c_start <= '1';
                            mag_i2c_rw <= '1';
                            mag_i2c_reg <= x"07"; -- Y MSB register
                            mag_state <= 4;
                        end if;
                        
                    when 4 => -- Store Y MSB, read Y LSB
                        if mag_i2c_valid = '1' then
                            mag_y_high <= mag_i2c_rx_data;
                            mag_i2c_start <= '1';
                            mag_i2c_rw <= '1';
                            mag_i2c_reg <= x"08"; -- Y LSB register
                            mag_state <= 5;
                        end if;
                        
                    when 5 => -- Store Y LSB, read Z MSB
                        if mag_i2c_valid = '1' then
                            mag_y_low <= mag_i2c_rx_data;
                            mag_i2c_start <= '1';
                            mag_i2c_rw <= '1';
                            mag_i2c_reg <= x"05"; -- Z MSB register
                            mag_state <= 6;
                        end if;
                        
                    when 6 => -- Store Z MSB, read Z LSB
                        if mag_i2c_valid = '1' then
                            mag_z_high <= mag_i2c_rx_data;
                            mag_i2c_start <= '1';
                            mag_i2c_rw <= '1';
                            mag_i2c_reg <= x"06"; -- Z LSB register
                            mag_state <= 7;
                        end if;
                        
                    when 7 => -- Store Z LSB and output data
                        if mag_i2c_valid = '1' then
                            mag_z_low <= mag_i2c_rx_data;
                            mag_data_x <= mag_x_high & mag_x_low;
                            mag_data_y <= mag_y_high & mag_y_low;
                            mag_data_z <= mag_z_high & mag_z_low;
                            mag_valid <= '1';
                            mag_state <= 0;
                        end if;
                        
                    when others =>
                        mag_state <= 0;
                end case;
            else
                mag_state <= 0;
                mag_timer <= (others => '0');
            end if;
        end if;
    end process;
    
    -- Thermal Sensor 1-Wire Interface
    therm_ow_inst : onewire_master
        generic map (
            CLK_FREQ => 50000000
        )
        port map (
            clk        => clk,
            rst_n      => rst_n,
            start      => therm_ow_start,
            command    => therm_ow_cmd,
            tx_data    => therm_ow_tx_data,
            rx_data    => therm_ow_rx_data,
            data_valid => therm_ow_valid,
            busy       => therm_ow_busy,
            dq         => therm_dq
        );
    
    -- Thermal sensor control
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            therm_timer <= (others => '0');
            therm_state <= 0;
            therm_ow_start <= '0';
            therm_ow_cmd <= (others => '0');
            therm_ow_tx_data <= (others => '0');
            therm_data <= (others => '0');
            therm_valid <= '0';
        elsif rising_edge(clk) then
            therm_ow_start <= '0';
            therm_valid <= '0';
            
            if sensor_enable(2) = '1' then
                case therm_state is
                    when 0 => -- Wait state
                        if therm_timer >= 5000000 then -- 100ms at 50MHz
                            therm_timer <= (others => '0');
                            therm_state <= 1;
                        else
                            therm_timer <= therm_timer + 1;
                        end if;
                        
                    when 1 => -- Send Skip ROM command
                        if therm_ow_busy = '0' then
                            therm_ow_start <= '1';
                            therm_ow_cmd <= THERM_SKIP_ROM;
                            therm_ow_tx_data <= (others => '0');
                            therm_state <= 2;
                        end if;
                        
                    when 2 => -- Send Convert T command
                        if therm_ow_valid = '1' then
                            therm_ow_start <= '1';
                            therm_ow_cmd <= THERM_CONVERT_T;
                            therm_ow_tx_data <= (others => '0');
                            therm_state <= 3;
                        end if;
                        
                    when 3 => -- Wait for conversion (750ms)
                        if therm_ow_valid = '1' then
                            therm_timer <= (others => '0');
                            therm_state <= 4;
                        elsif therm_timer >= 37500000 then -- 750ms at 50MHz
                            therm_state <= 4;
                        else
                            therm_timer <= therm_timer + 1;
                        end if;
                        
                    when 4 => -- Send Read Scratchpad command
                        if therm_ow_busy = '0' then
                            therm_ow_start <= '1';
                            therm_ow_cmd <= THERM_READ_PAD;
                            therm_ow_tx_data <= (others => '0');
                            therm_state <= 5;
                        end if;
                        
                    when 5 => -- Read temperature data
                        if therm_ow_valid = '1' then
                            -- Temperature is in first 16 bits of scratchpad
                            therm_data <= therm_ow_rx_data(15 downto 0);
                            therm_valid <= '1';
                            therm_state <= 0;
                        end if;
                        
                    when others =>
                        therm_state <= 0;
                end case;
            else
                therm_state <= 0;
                therm_timer <= (others => '0');
            end if;
        end if;
    end process;

end rtl;
