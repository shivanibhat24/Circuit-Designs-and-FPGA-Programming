-- ==============================================================================
-- MIMO Decoder Core - Main Engine
-- ==============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.mimo_decoder_pkg.all;

entity mimo_decoder_core is
    generic (
        NUM_RX_ANTENNAS : integer := 64;
        NUM_TX_ANTENNAS : integer := 16;
        PIPELINE_STAGES : integer := 8
    );
    port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        
        -- Configuration
        decoder_mode        : in  std_logic; -- 0: ZF, 1: MMSE
        noise_variance      : in  sfixed(DATA_WIDTH-1 downto -FRAC_WIDTH);
        
        -- Channel matrix H (NUM_RX x NUM_TX)
        channel_matrix      : in  complex_vector(0 to NUM_RX_ANTENNAS*NUM_TX_ANTENNAS-1);
        channel_valid       : in  std_logic;
        
        -- Received signal vector
        received_signal     : in  complex_vector(0 to NUM_RX_ANTENNAS-1);
        signal_valid        : in  std_logic;
        
        -- Decoded output
        decoded_symbols     : out complex_vector(0 to NUM_TX_ANTENNAS-1);
        decoded_valid       : out std_logic;
        
        -- Status and control
        start_decode        : in  std_logic;
        busy                : out std_logic;
        error               : out std_logic
    );
end entity;

architecture behavioral of mimo_decoder_core is
    -- State machine
    type decoder_state_type is (IDLE, COMPUTE_GRAM, INVERT_GRAM, MULTIPLY_HH, MULTIPLY_Y, OUTPUT, ERROR_STATE);
    signal state : decoder_state_type;
    
    -- Internal signals
    signal gram_matrix : complex_vector(0 to NUM_TX_ANTENNAS*NUM_TX_ANTENNAS-1);
    signal gram_matrix_valid : std_logic;
    signal inverted_gram : complex_vector(0 to NUM_TX_ANTENNAS*NUM_TX_ANTENNAS-1);
    signal inverted_gram_valid : std_logic;
    signal temp_vector : complex_vector(0 to NUM_TX_ANTENNAS-1);
    
    -- Matrix inverter instance
    signal inv_start : std_logic;
    signal inv_busy : std_logic;
    signal inv_error : std_logic;
    
    component matrix_inverter is
        generic (MATRIX_SIZE : integer);
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            start           : in  std_logic;
            matrix_in       : in  complex_vector(0 to MATRIX_SIZE*MATRIX_SIZE-1);
            matrix_valid    : in  std_logic;
            matrix_out      : out complex_vector(0 to MATRIX_SIZE*MATRIX_SIZE-1);
            matrix_out_valid: out std_logic;
            busy            : out std_logic;
            error           : out std_logic
        );
    end component;
    
begin
    -- Matrix inverter instantiation
    matrix_inv_inst: matrix_inverter
        generic map (MATRIX_SIZE => NUM_TX_ANTENNAS)
        port map (
            clk => clk,
            rst => rst,
            start => inv_start,
            matrix_in => gram_matrix,
            matrix_valid => gram_matrix_valid,
            matrix_out => inverted_gram,
            matrix_out_valid => inverted_gram_valid,
            busy => inv_busy,
            error => inv_error
        );
    
    -- Main decoder process
    process(clk)
        variable h_hermitian : complex_vector(0 to NUM_TX_ANTENNAS*NUM_RX_ANTENNAS-1);
        variable temp_sum : complex_fixed;
        variable identity_element : complex_fixed;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                busy <= '0';
                error <= '0';
                decoded_valid <= '0';
                inv_start <= '0';
                gram_matrix_valid <= '0';
                
            else
                case state is
                    when IDLE =>
                        if start_decode = '1' and channel_valid = '1' and signal_valid = '1' then
                            state <= COMPUTE_GRAM;
                            busy <= '1';
                        end if;
                        
                    when COMPUTE_GRAM =>
                        -- Compute H^H (Hermitian transpose)
                        for i in 0 to NUM_TX_ANTENNAS-1 loop
                            for j in 0 to NUM_RX_ANTENNAS-1 loop
                                h_hermitian(i*NUM_RX_ANTENNAS + j) := 
                                    complex_conj(channel_matrix(j*NUM_TX_ANTENNAS + i));
                            end loop;
                        end loop;
                        
                        -- Compute Gram matrix: G = H^H * H
                        for i in 0 to NUM_TX_ANTENNAS-1 loop
                            for j in 0 to NUM_TX_ANTENNAS-1 loop
                                temp_sum := complex_zero;
                                for k in 0 to NUM_RX_ANTENNAS-1 loop
                                    temp_sum := complex_add(temp_sum, 
                                              complex_mult(h_hermitian(i*NUM_RX_ANTENNAS + k),
                                                         channel_matrix(k*NUM_TX_ANTENNAS + j)));
                                end loop;
                                
                                -- Add noise term for MMSE
                                if decoder_mode = '1' and i = j then
                                    identity_element.re := noise_variance;
                                    identity_element.im := (others => '0');
                                    temp_sum := complex_add(temp_sum, identity_element);
                                end if;
                                
                                gram_matrix(i*NUM_TX_ANTENNAS + j) <= temp_sum;
                            end loop;
                        end loop;
                        
                        gram_matrix_valid <= '1';
                        state <= INVERT_GRAM;
                        
                    when INVERT_GRAM =>
                        inv_start <= '1';
                        if inv_busy = '1' then
                            inv_start <= '0';
                            state <= MULTIPLY_HH;
                        elsif inv_error = '1' then
                            state <= ERROR_STATE;
                        end if;
                        
                    when MULTIPLY_HH =>
                        if inverted_gram_valid = '1' then
                            -- Compute temp_vector = G^(-1) * H^H
                            for i in 0 to NUM_TX_ANTENNAS-1 loop
                                temp_sum := complex_zero;
                                for k in 0 to NUM_RX_ANTENNAS-1 loop
                                    for j in 0 to NUM_TX_ANTENNAS-1 loop
                                        temp_sum := complex_add(temp_sum,
                                                  complex_mult(inverted_gram(i*NUM_TX_ANTENNAS + j),
                                                             h_hermitian(j*NUM_RX_ANTENNAS + k)));
                                    end loop;
                                end loop;
                                temp_vector(i) <= temp_sum;
                            end loop;
                            state <= MULTIPLY_Y;
                        end if;
                        
                    when MULTIPLY_Y =>
                        -- Final multiplication: decoded = temp_vector * received_signal
                        for i in 0 to NUM_TX_ANTENNAS-1 loop
                            temp_sum := complex_zero;
                            for j in 0 to NUM_RX_ANTENNAS-1 loop
                                temp_sum := complex_add(temp_sum,
                                          complex_mult(temp_vector(i), received_signal(j)));
                            end loop;
                            decoded_symbols(i) <= temp_sum;
                        end loop;
                        state <= OUTPUT;
                        
                    when OUTPUT =>
                        decoded_valid <= '1';
                        busy <= '0';
                        state <= IDLE;
                        
                    when ERROR_STATE =>
                        error <= '1';
                        busy <= '0';
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;
    
end architecture;
