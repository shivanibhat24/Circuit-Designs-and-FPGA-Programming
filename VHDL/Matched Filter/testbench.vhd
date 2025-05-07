library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_matched_filter is
-- Testbench has no ports
end tb_matched_filter;

architecture Behavioral of tb_matched_filter is
    -- Component declaration for the Unit Under Test (UUT)
    component matched_filter
        generic (
            COEFF_WIDTH : integer := 16;
            DATA_WIDTH : integer := 16;
            FILTER_TAPS : integer := 16;
            OUTPUT_WIDTH : integer := 36
        );
        port (
            clk : in std_logic;
            rst : in std_logic;
            signal_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
            valid_in : in std_logic;
            signal_out : out std_logic_vector(OUTPUT_WIDTH-1 downto 0);
            valid_out : out std_logic;
            threshold : in std_logic_vector(OUTPUT_WIDTH-1 downto 0);
            detection : out std_logic
        );
    end component;
    
    -- Constants
    constant CLK_PERIOD : time := 10 ns;
    constant DATA_WIDTH : integer := 16;
    constant COEFF_WIDTH : integer := 16;
    constant FILTER_TAPS : integer := 16;
    constant OUTPUT_WIDTH : integer := 36;
    
    -- Signals for UUT
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal signal_in : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal valid_in : std_logic := '0';
    signal signal_out : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal valid_out : std_logic;
    signal threshold : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := std_logic_vector(to_signed(10000000, OUTPUT_WIDTH));
    signal detection : std_logic;
    
    -- Signals for test generation
    signal sim_done : boolean := false;
    
    -- Define a pulse shape (to match our coefficients)
    type pulse_array is array (0 to FILTER_TAPS-1) of integer;
    constant PULSE_SHAPE : pulse_array := (
        100, 300, 500, 700, 900, 1100, 1300, 1500, 
        1500, 1300, 1100, 900, 700, 500, 300, 100
    );
    
    -- Define a noise function
    function add_noise(signal_val : integer; snr_db : real) return integer is
        variable noise_amplitude : real;
        variable noise : real;
        variable seed1, seed2 : positive := 1;
        variable rand : real;
    begin
        -- Calculate noise amplitude based on SNR
        noise_amplitude := real(abs(signal_val)) / (10.0**(snr_db/20.0));
        
        -- Generate random noise
        uniform(seed1, seed2, rand);
        noise := (rand - 0.5) * 2.0 * noise_amplitude;
        
        -- Add noise to signal
        return signal_val + integer(noise);
    end function;
    
begin
    -- Instantiate the Unit Under Test (UUT)
    uut: matched_filter
        generic map (
            COEFF_WIDTH => COEFF_WIDTH,
            DATA_WIDTH => DATA_WIDTH,
            FILTER_TAPS => FILTER_TAPS,
            OUTPUT_WIDTH => OUTPUT_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            signal_in => signal_in,
            valid_in => valid_in,
            signal_out => signal_out,
            valid_out => valid_out,
            threshold => threshold,
            detection => detection
        );
    
    -- Clock process
    clk_process: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- Stimulus process
    stim_proc: process
        variable noisy_value : integer;
        variable snr_db : real := 10.0; -- 10 dB SNR for the test
    begin
        -- Reset sequence
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for CLK_PERIOD;
        
        -- Send zeros initially (no signal)
        for i in 0 to 31 loop
            valid_in <= '1';
            signal_in <= std_logic_vector(to_signed(0, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Send our target pulse with noise
        for i in 0 to FILTER_TAPS-1 loop
            valid_in <= '1';
            noisy_value := add_noise(PULSE_SHAPE(i), snr_db);
            signal_in <= std_logic_vector(to_signed(noisy_value, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Send zeros again (no signal)
        for i in 0 to 31 loop
            valid_in <= '1';
            signal_in <= std_logic_vector(to_signed(0, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Send random noise (no signal)
        for i in 0 to 31 loop
            valid_in <= '1';
            noisy_value := add_noise(0, snr_db);
            signal_in <= std_logic_vector(to_signed(noisy_value, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Send target pulse again with more noise (lower SNR)
        snr_db := 5.0; -- 5 dB SNR
        for i in 0 to FILTER_TAPS-1 loop
            valid_in <= '1';
            noisy_value := add_noise(PULSE_SHAPE(i), snr_db);
            signal_in <= std_logic_vector(to_signed(noisy_value, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Send zeros to finish
        for i in 0 to 31 loop
            valid_in <= '1';
            signal_in <= std_logic_vector(to_signed(0, DATA_WIDTH));
            wait for CLK_PERIOD;
        end loop;
        
        -- Finish simulation
        valid_in <= '0';
        wait for 50*CLK_PERIOD;
        sim_done <= true;
        wait;
    end process;

end Behavioral;
