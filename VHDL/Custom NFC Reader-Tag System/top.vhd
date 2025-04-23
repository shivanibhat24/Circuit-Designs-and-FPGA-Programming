-- NFC Reader-Tag System Top Entity
-- This design implements a simplified NFC reader system with tag communication

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity nfc_system is
    Port (
        clk              : in  STD_LOGIC;                     -- System clock
        rst              : in  STD_LOGIC;                     -- Reset signal
        -- Reader control interface
        start_transaction: in  STD_LOGIC;                     -- Start NFC transaction
        command_in       : in  STD_LOGIC_VECTOR(7 downto 0);  -- Command to send
        data_in          : in  STD_LOGIC_VECTOR(7 downto 0);  -- Data to send
        data_ready       : out STD_LOGIC;                     -- Data ready indicator
        data_out         : out STD_LOGIC_VECTOR(7 downto 0);  -- Received data
        -- RF interface signals
        carrier_out      : out STD_LOGIC;                     -- 13.56 MHz carrier
        modulation_out   : out STD_LOGIC;                     -- Modulation signal
        field_detect_in  : in  STD_LOGIC;                     -- Tag field detection
        load_modulation  : in  STD_LOGIC                      -- Tag load modulation
    );
end nfc_system;

architecture Behavioral of nfc_system is
    -- Internal component declarations
    component carrier_generator is
        Port (
            clk          : in  STD_LOGIC;
            rst          : in  STD_LOGIC;
            enable       : in  STD_LOGIC;
            carrier_out  : out STD_LOGIC
        );
    end component;
    
    component modulator is
        Port (
            clk          : in  STD_LOGIC;
            rst          : in  STD_LOGIC;
            enable       : in  STD_LOGIC;
            data_in      : in  STD_LOGIC_VECTOR(7 downto 0);
            modulation   : out STD_LOGIC
        );
    end component;
    
    component demodulator is
        Port (
            clk          : in  STD_LOGIC;
            rst          : in  STD_LOGIC;
            load_mod_in  : in  STD_LOGIC;
            data_out     : out STD_LOGIC_VECTOR(7 downto 0);
            data_valid   : out STD_LOGIC
        );
    end component;
    
    component protocol_controller is
        Port (
            clk              : in  STD_LOGIC;
            rst              : in  STD_LOGIC;
            start_trans      : in  STD_LOGIC;
            command          : in  STD_LOGIC_VECTOR(7 downto 0);
            data_to_send     : in  STD_LOGIC_VECTOR(7 downto 0);
            field_detect     : in  STD_LOGIC;
            data_received    : in  STD_LOGIC_VECTOR(7 downto 0);
            data_valid_in    : in  STD_LOGIC;
            carrier_enable   : out STD_LOGIC;
            mod_enable       : out STD_LOGIC;
            tx_data          : out STD_LOGIC_VECTOR(7 downto 0);
            data_ready_out   : out STD_LOGIC;
            data_out         : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;
    
    -- Internal signals
    signal carrier_enable    : STD_LOGIC;
    signal mod_enable        : STD_LOGIC;
    signal tx_data           : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_data           : STD_LOGIC_VECTOR(7 downto 0);
    signal data_valid        : STD_LOGIC;
    
begin
    -- Component instantiations
    carrier_gen: carrier_generator
    port map (
        clk         => clk,
        rst         => rst,
        enable      => carrier_enable,
        carrier_out => carrier_out
    );
    
    mod: modulator
    port map (
        clk         => clk,
        rst         => rst,
        enable      => mod_enable,
        data_in     => tx_data,
        modulation  => modulation_out
    );
    
    demod: demodulator
    port map (
        clk         => clk,
        rst         => rst,
        load_mod_in => load_modulation,
        data_out    => rx_data,
        data_valid  => data_valid
    );
    
    controller: protocol_controller
    port map (
        clk            => clk,
        rst            => rst,
        start_trans    => start_transaction,
        command        => command_in,
        data_to_send   => data_in,
        field_detect   => field_detect_in,
        data_received  => rx_data,
        data_valid_in  => data_valid,
        carrier_enable => carrier_enable,
        mod_enable     => mod_enable,
        tx_data        => tx_data,
        data_ready_out => data_ready,
        data_out       => data_out
    );
end Behavioral;

-- Carrier Generator Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity carrier_generator is
    Port (
        clk          : in  STD_LOGIC;
        rst          : in  STD_LOGIC;
        enable       : in  STD_LOGIC;
        carrier_out  : out STD_LOGIC
    );
end carrier_generator;

architecture Behavioral of carrier_generator is
    -- Constants for 13.56 MHz carrier generation (assuming 108.48 MHz system clock)
    constant DIVIDER_VALUE : integer := 4;  -- 108.48 MHz / 4 = 27.12 MHz
    constant HALF_DIVIDER  : integer := DIVIDER_VALUE / 2;
    
    signal counter       : unsigned(3 downto 0) := (others => '0');
    signal carrier_state : STD_LOGIC := '0';
begin
    -- Generate 13.56 MHz carrier from system clock
    process(clk, rst)
    begin
        if rst = '1' then
            counter <= (others => '0');
            carrier_state <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                if counter = DIVIDER_VALUE - 1 then
                    counter <= (others => '0');
                    carrier_state <= '1';  -- Start of carrier cycle
                else
                    counter <= counter + 1;
                    if counter = HALF_DIVIDER - 1 then
                        carrier_state <= '0';  -- Mid-cycle transition
                    end if;
                end if;
            else
                carrier_state <= '0';
                counter <= (others => '0');
            end if;
        end if;
    end process;
    
    carrier_out <= carrier_state when enable = '1' else '0';
end Behavioral;
