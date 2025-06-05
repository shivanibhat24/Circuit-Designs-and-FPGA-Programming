-- cubesat_daq_core.vhd
-- Core data acquisition module for CubeSat sensor suite
-- Handles synchronized sampling and data buffering

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cubesat_daq_core is
    generic (
        DATA_WIDTH     : integer := 16;
        FIFO_DEPTH     : integer := 1024;
        NUM_SENSORS    : integer := 3;
        SAMPLE_DIV     : integer := 1000  -- Clock divider for 1kHz sampling
    );
    port (
        -- System signals
        clk            : in  std_logic;
        rst_n          : in  std_logic;
        
        -- Sensor interfaces
        rad_data       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        rad_valid      : in  std_logic;
        mag_data_x     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mag_data_y     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mag_data_z     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mag_valid      : in  std_logic;
        therm_data     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        therm_valid    : in  std_logic;
        
        -- Control interface
        enable         : in  std_logic;
        sample_rate    : in  std_logic_vector(15 downto 0);
        
        -- Data output interface
        data_out       : out std_logic_vector(DATA_WIDTH-1 downto 0);
        data_valid     : out std_logic;
        data_ready     : in  std_logic;
        sensor_id      : out std_logic_vector(7 downto 0);
        timestamp      : out std_logic_vector(31 downto 0);
        
        -- Status signals
        fifo_full      : out std_logic;
        fifo_empty     : out std_logic;
        error_flag     : out std_logic
    );
end cubesat_daq_core;

architecture rtl of cubesat_daq_core is
    
    -- Internal signals
    signal sample_clk      : std_logic;
    signal sample_counter  : unsigned(15 downto 0);
    signal timestamp_cnt   : unsigned(31 downto 0);
    
    -- FIFO signals
    signal fifo_din        : std_logic_vector(DATA_WIDTH + 8 + 32 - 1 downto 0); -- data + sensor_id + timestamp
    signal fifo_dout       : std_logic_vector(DATA_WIDTH + 8 + 32 - 1 downto 0);
    signal fifo_wr_en      : std_logic;
    signal fifo_rd_en      : std_logic;
    signal fifo_full_int   : std_logic;
    signal fifo_empty_int  : std_logic;
    
    -- Sampling state machine
    type sample_state_t is (IDLE, SAMPLE_RAD, SAMPLE_MAG_X, SAMPLE_MAG_Y, SAMPLE_MAG_Z, SAMPLE_THERM);
    signal sample_state    : sample_state_t;
    signal next_state      : sample_state_t;
    
    -- Data formatting
    signal current_data    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal current_id      : std_logic_vector(7 downto 0);
    signal data_valid_int  : std_logic;
    
    -- Sensor IDs
    constant RAD_SENSOR_ID    : std_logic_vector(7 downto 0) := x"01";
    constant MAG_X_SENSOR_ID  : std_logic_vector(7 downto 0) := x"02";
    constant MAG_Y_SENSOR_ID  : std_logic_vector(7 downto 0) := x"03";
    constant MAG_Z_SENSOR_ID  : std_logic_vector(7 downto 0) := x"04";
    constant THERM_SENSOR_ID  : std_logic_vector(7 downto 0) := x"05";

begin

    -- Sample clock generation
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            sample_counter <= (others => '0');
            sample_clk <= '0';
        elsif rising_edge(clk) then
            if sample_counter >= unsigned(sample_rate) then
                sample_counter <= (others => '0');
                sample_clk <= '1';
            else
                sample_counter <= sample_counter + 1;
                sample_clk <= '0';
            end if;
        end if;
    end process;
    
    -- Timestamp counter
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            timestamp_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                timestamp_cnt <= timestamp_cnt + 1;
            end if;
        end if;
    end process;
    
    -- Sampling state machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            sample_state <= IDLE;
        elsif rising_edge(clk) then
            if enable = '1' then
                sample_state <= next_state;
            else
                sample_state <= IDLE;
            end if;
        end if;
    end process;
    
    -- State machine logic
    process(sample_state, sample_clk, rad_valid, mag_valid, therm_valid)
    begin
        next_state <= sample_state;
        
        case sample_state is
            when IDLE =>
                if sample_clk = '1' then
                    next_state <= SAMPLE_RAD;
                end if;
                
            when SAMPLE_RAD =>
                if rad_valid = '1' then
                    next_state <= SAMPLE_MAG_X;
                end if;
                
            when SAMPLE_MAG_X =>
                if mag_valid = '1' then
                    next_state <= SAMPLE_MAG_Y;
                end if;
                
            when SAMPLE_MAG_Y =>
                next_state <= SAMPLE_MAG_Z;
                
            when SAMPLE_MAG_Z =>
                next_state <= SAMPLE_THERM;
                
            when SAMPLE_THERM =>
                if therm_valid = '1' then
                    next_state <= IDLE;
                end if;
        end case;
    end process;
    
    -- Data multiplexing
    process(sample_state, rad_data, mag_data_x, mag_data_y, mag_data_z, therm_data)
    begin
        case sample_state is
            when SAMPLE_RAD =>
                current_data <= rad_data;
                current_id <= RAD_SENSOR_ID;
                data_valid_int <= rad_valid;
                
            when SAMPLE_MAG_X =>
                current_data <= mag_data_x;
                current_id <= MAG_X_SENSOR_ID;
                data_valid_int <= mag_valid;
                
            when SAMPLE_MAG_Y =>
                current_data <= mag_data_y;
                current_id <= MAG_Y_SENSOR_ID;
                data_valid_int <= mag_valid;
                
            when SAMPLE_MAG_Z =>
                current_data <= mag_data_z;
                current_id <= MAG_Z_SENSOR_ID;
                data_valid_int <= mag_valid;
                
            when SAMPLE_THERM =>
                current_data <= therm_data;
                current_id <= THERM_SENSOR_ID;
                data_valid_int <= therm_valid;
                
            when others =>
                current_data <= (others => '0');
                current_id <= (others => '0');
                data_valid_int <= '0';
        end case;
    end process;
    
    -- FIFO input formatting
    fifo_din <= current_data & current_id & std_logic_vector(timestamp_cnt);
    fifo_wr_en <= data_valid_int and not fifo_full_int;
    
    -- FIFO instance (simplified - would use IP core in practice)
    process(clk, rst_n)
        type fifo_array_t is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH + 8 + 32 - 1 downto 0);
        variable fifo_mem : fifo_array_t;
        variable wr_ptr : integer range 0 to FIFO_DEPTH-1 := 0;
        variable rd_ptr : integer range 0 to FIFO_DEPTH-1 := 0;
        variable count : integer range 0 to FIFO_DEPTH := 0;
    begin
        if rst_n = '0' then
            wr_ptr := 0;
            rd_ptr := 0;
            count := 0;
            fifo_full_int <= '0';
            fifo_empty_int <= '1';
        elsif rising_edge(clk) then
            -- Write operation
            if fifo_wr_en = '1' and count < FIFO_DEPTH then
                fifo_mem(wr_ptr) := fifo_din;
                wr_ptr := (wr_ptr + 1) mod FIFO_DEPTH;
                count := count + 1;
            end if;
            
            -- Read operation
            if fifo_rd_en = '1' and count > 0 then
                fifo_dout <= fifo_mem(rd_ptr);
                rd_ptr := (rd_ptr + 1) mod FIFO_DEPTH;
                count := count - 1;
            end if;
            
            -- Status flags
            fifo_full_int <= '1' when count = FIFO_DEPTH else '0';
            fifo_empty_int <= '1' when count = 0 else '0';
        end if;
    end process;
    
    -- Output interface
    fifo_rd_en <= data_ready and not fifo_empty_int;
    data_out <= fifo_dout(DATA_WIDTH + 8 + 32 - 1 downto 8 + 32);
    sensor_id <= fifo_dout(8 + 32 - 1 downto 32);
    timestamp <= fifo_dout(31 downto 0);
    data_valid <= not fifo_empty_int;
    
    -- Status outputs
    fifo_full <= fifo_full_int;
    fifo_empty <= fifo_empty_int;
    error_flag <= fifo_full_int; -- Error when FIFO overflows
    
end rtl;
