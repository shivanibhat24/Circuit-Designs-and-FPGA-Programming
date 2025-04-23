library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Constants for Reed-Solomon parameters commonly used in NFC
-- RS(255,223) with 8-bit symbols (GF(2^8))
package rs_constants is
    constant SYMBOL_SIZE : integer := 8;
    constant N : integer := 255;  -- Code length
    constant K : integer := 223;  -- Message length
    constant T : integer := (N - K) / 2;  -- Error correction capability (16 symbols)
    
    -- Primitive polynomial for GF(2^8): x^8 + x^4 + x^3 + x^2 + 1
    constant PRIMITIVE_POLY : std_logic_vector(SYMBOL_SIZE downto 0) := "100011101";  -- 0x11D
    
    type gf_array is array (0 to N-1) of std_logic_vector(SYMBOL_SIZE-1 downto 0);
    
    -- Function declarations
    function gf_mult(a, b : std_logic_vector(SYMBOL_SIZE-1 downto 0)) return std_logic_vector;
    function gf_add(a, b : std_logic_vector(SYMBOL_SIZE-1 downto 0)) return std_logic_vector;
    function gf_inv(a : std_logic_vector(SYMBOL_SIZE-1 downto 0)) return std_logic_vector;
end package rs_constants;

package body rs_constants is
    -- Galois Field Addition (XOR operation)
    function gf_add(a, b : std_logic_vector(SYMBOL_SIZE-1 downto 0)) return std_logic_vector is
    begin
        return a xor b;
    end function;
    
    -- Galois Field Multiplication
    function gf_mult(a, b : std_logic_vector(SYMBOL_SIZE-1 downto 0)) return std_logic_vector is
        variable result : std_logic_vector(SYMBOL_SIZE-1 downto 0) := (others => '0');
        variable temp_a : std_logic_vector(SYMBOL_SIZE-1 downto 0) := a;
        variable carry : std_logic;
    begin
        -- If either operand is zero, return zero
        if unsigned(a) = 0 or unsigned(b) = 0 then
            return result;
        end if;
        
        for i in 0 to SYMBOL_SIZE-1 loop
            -- If current bit of b is '1', XOR result with a
            if b(i) = '1' then
                result := result xor temp_a;
            end if;
            
            -- Compute next value of temp_a (multiply by x)
            carry := temp_a(SYMBOL_SIZE-1);
            temp_a := temp_a(SYMBOL_SIZE-2 downto 0) & '0';
            
            -- If carry is '1', XOR with the primitive polynomial
            if carry = '1' then
                temp_a := temp_a xor PRIMITIVE_POLY(SYMBOL_SIZE-1 downto 0);
            end if;
        end loop;
        
        return result;
    end function;
    
    -- Galois Field Inverse (for division)
    function gf_inv(a : std_logic_vector(SYMBOL_SIZE-1 downto 0)) return std_logic_vector is
        variable result : std_logic_vector(SYMBOL_SIZE-1 downto 0);
        variable temp : std_logic_vector(SYMBOL_SIZE-1 downto 0);
    begin
        -- Exception for zero input
        if unsigned(a) = 0 then
            return (others => '0');
        end if;
        
        -- Using Fermat's Little Theorem: a^(p-1) ≡ 1 (mod p), so a^(p-2) ≡ a^(-1) (mod p)
        -- For GF(2^8), a^(2^8-2) = a^254 is the inverse
        
        -- Start with a^1
        result := a;
        
        -- Compute a^2, a^4, a^8, ... , a^128
        for i in 1 to SYMBOL_SIZE-1 loop
            temp := result;
            for j in 1 to 2**(i-1) loop
                temp := gf_mult(temp, temp);
            end loop;
            result := temp;
        end loop;
        
        -- For a^254, we multiply a^253 by a
        result := gf_mult(result, a);
        
        return result;
    end function;
end package body rs_constants;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rs_constants.all;

entity rs_decoder is
    port (
        clk         : in std_logic;
        reset       : in std_logic;
        data_in     : in std_logic_vector(SYMBOL_SIZE-1 downto 0);
        data_valid  : in std_logic;
        data_out    : out std_logic_vector(SYMBOL_SIZE-1 downto 0);
        data_ready  : out std_logic;
        decode_done : out std_logic;
        error_count : out integer range 0 to T;
        uncorrectable : out std_logic
    );
end entity rs_decoder;

architecture rtl of rs_decoder is
    -- Define state machine states
    type state_type is (IDLE, RECEIVE_DATA, CALC_SYNDROMES, FIND_ERROR_LOCATOR, 
                        CHIEN_SEARCH, FORNEY_ALGORITHM, OUTPUT_CORRECTED);
    signal state : state_type;
    
    -- Signal declarations
    signal received_codeword : gf_array;
    signal syndromes : gf_array;
    signal error_locator_poly : gf_array;
    signal error_value_poly : gf_array;
    signal error_locations : gf_array;
    signal error_values : gf_array;
    
    signal symbol_counter : integer range 0 to N;
    signal error_count_internal : integer range 0 to T;
    signal deg_error_locator : integer range 0 to 2*T;
    signal deg_error_value : integer range 0 to 2*T;
    
    -- Key-equation solver method signals (Berlekamp-Massey Algorithm)
    signal discrepancy : std_logic_vector(SYMBOL_SIZE-1 downto 0);
    signal L : integer range 0 to 2*T;
    signal B_poly : gf_array;
    signal iteration : integer range 0 to 2*T;
    
begin
    -- Main process
    process(clk, reset)
        variable temp_discrepancy : std_logic_vector(SYMBOL_SIZE-1 downto 0);
        variable temp : std_logic_vector(SYMBOL_SIZE-1 downto 0);
        variable temp_poly : gf_array;
        variable error_found : boolean;
        variable error_pos : integer;
        variable sum : std_logic_vector(SYMBOL_SIZE-1 downto 0);
        variable has_error : boolean;
    begin
        if reset = '1' then
            state <= IDLE;
            symbol_counter <= 0;
            error_count_internal <= 0;
            deg_error_locator <= 0;
            deg_error_value <= 0;
            data_ready <= '0';
            decode_done <= '0';
            uncorrectable <= '0';
            
            -- Initialize arrays
            for i in 0 to N-1 loop
                received_codeword(i) <= (others => '0');
                syndromes(i) <= (others => '0');
                error_locator_poly(i) <= (others => '0');
                error_value_poly(i) <= (others => '0');
                error_locations(i) <= (others => '0');
                error_values(i) <= (others => '0');
                B_poly(i) <= (others => '0');
            end loop;
            
            -- Initialize error locator polynomial to 1
            error_locator_poly(0) <= (0 => '1', others => '0');
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    symbol_counter <= 0;
                    error_count_internal <= 0;
                    data_ready <= '0';
                    decode_done <= '0';
                    uncorrectable <= '0';
                    
                    if data_valid = '1' then
                        state <= RECEIVE_DATA;
                    end if;
                
                when RECEIVE_DATA =>
                    if data_valid = '1' then
                        -- Store incoming symbol in received_codeword buffer
                        received_codeword(symbol_counter) <= data_in;
                        
                        if symbol_counter = N-1 then
                            -- All symbols received, start decoding
                            symbol_counter <= 0;
                            state <= CALC_SYNDROMES;
                        else
                            symbol_counter <= symbol_counter + 1;
                        end if;
                    end if;
                
                when CALC_SYNDROMES =>
                    -- Calculate syndromes
                    if symbol_counter < 2*T then
                        -- Initialize syndrome for this iteration
                        sum := (others => '0');
                        
                        -- S_j = sum_{i=0}^{n-1} r_i * (alpha^j)^i
                        for i in 0 to N-1 loop
                            -- Calculate (alpha^j)^i
                            -- For simplicity, we're using a direct approach
                            -- In a real implementation, this would use a precomputed table
                            temp := (0 => '1', others => '0');  -- Start with 1
                            for k in 1 to i*symbol_counter loop
                                -- Multiply by alpha (primitive element)
                                if temp(SYMBOL_SIZE-1) = '1' then
                                    temp := (temp(SYMBOL_SIZE-2 downto 0) & '0') xor PRIMITIVE_POLY(SYMBOL_SIZE-1 downto 0);
                                else
                                    temp := temp(SYMBOL_SIZE-2 downto 0) & '0';
                                end if;
                            end loop;
                            
                            -- Multiply by r_i and add to sum
                            temp := gf_mult(received_codeword(i), temp);
                            sum := gf_add(sum, temp);
                        end loop;
                        
                        syndromes(symbol_counter) <= sum;
                        symbol_counter <= symbol_counter + 1;
                    else
                        -- Check if all syndromes are zero (no errors)
                        has_error := false;
                        for i in 0 to 2*T-1 loop
                            if unsigned(syndromes(i)) /= 0 then
                                has_error := true;
                                exit;
                            end if;
                        end loop;
                        
                        if not has_error then
                            -- No errors, output the original message
                            state <= OUTPUT_CORRECTED;
                            symbol_counter <= 0;
                        else
                            -- Errors detected, find error locator polynomial
                            state <= FIND_ERROR_LOCATOR;
                            -- Initialize BMA algorithm
                            L <= 0;
                            error_locator_poly(0) <= (0 => '1', others => '0');  -- Lambda(x) = 1
                            for i in 1 to 2*T loop
                                error_locator_poly(i) <= (others => '0');
                            end loop;
                            
                            B_poly(0) <= (0 => '1', others => '0');  -- B(x) = 1
                            for i in 1 to 2*T loop
                                B_poly(i) <= (others => '0');
                            end loop;
                            
                            iteration <= 0;
                        end if;
                    end if;
                
                when FIND_ERROR_LOCATOR =>
                    -- Berlekamp-Massey Algorithm to find the error locator polynomial
                    if iteration < 2*T then
                        -- Calculate discrepancy
                        discrepancy <= (others => '0');
                        for j in 0 to L loop
                            temp := gf_mult(error_locator_poly(j), syndromes(iteration-j));
                            discrepancy <= gf_add(discrepancy, temp);
                        end loop;
                        
                        if unsigned(discrepancy) /= 0 then
                            -- Update error locator polynomial
                            temp_poly := error_locator_poly;  -- Save current polynomial
                            
                            -- Lambda(x) = Lambda(x) - d * B(x) * x^(iteration)
                            for j in 0 to 2*T loop
                                if j >= iteration then
                                    temp := gf_mult(discrepancy, B_poly(j-iteration));
                                    error_locator_poly(j) <= gf_add(error_locator_poly(j), temp);
                                end if;
                            end loop;
                            
                            if 2*L <= iteration-1 then
                                L <= iteration + 1 - L;
                                
                                -- B(x) = Lambda(x) / d
                                for j in 0 to 2*T loop
                                    B_poly(j) <= gf_mult(temp_poly(j), gf_inv(discrepancy));
                                end loop;
                            else
                                -- B(x) = x * B(x)
                                for j in 2*T downto 1 loop
                                    B_poly(j) <= B_poly(j-1);
                                end loop;
                                B_poly(0) <= (others => '0');
                            end if;
                        else
                            -- B(x) = x * B(x)
                            for j in 2*T downto 1 loop
                                B_poly(j) <= B_poly(j-1);
                            end loop;
                            B_poly(0) <= (others => '0');
                        end if;
                        
                        iteration <= iteration + 1;
                    else
                        -- Set degree of error locator polynomial
                        deg_error_locator <= L;
                        
                        -- Check if errors exceed correction capability
                        if L > T then
                            -- Too many errors
                            uncorrectable <= '1';
                            state <= IDLE;
                        else
                            -- Proceed to find error locations
                            state <= CHIEN_SEARCH;
                            symbol_counter <= 0;
                            error_count_internal <= 0;
                        end if;
                    end if;
                
                when CHIEN_SEARCH =>
                    -- Chien Search to find the roots of the error locator polynomial
                    -- These roots correspond to the error locations
                    
                    -- Evaluate error locator polynomial at alpha^(-i)
                    sum := (others => '0');
                    for j in 0 to deg_error_locator loop
                        -- Calculate error_locator_poly(j) * (alpha^(-i))^j
                        -- For simplicity, we're using a direct approach
                        -- In a real implementation, this would use a precomputed table
                        temp := error_locator_poly(j);
                        for k in 1 to j*(N-1-symbol_counter) loop
                            -- Multiply by alpha (primitive element)
                            if temp(SYMBOL_SIZE-1) = '1' then
                                temp := (temp(SYMBOL_SIZE-2 downto 0) & '0') xor PRIMITIVE_POLY(SYMBOL_SIZE-1 downto 0);
                            else
                                temp := temp(SYMBOL_SIZE-2 downto 0) & '0';
                            end if;
                        end loop;
                        
                        sum := gf_add(sum, temp);
                    end loop;
                    
                    -- If sum is zero, we found an error location
                    if unsigned(sum) = 0 then
                        error_locations(error_count_internal) <= std_logic_vector(to_unsigned(symbol_counter, SYMBOL_SIZE));
                        error_count_internal <= error_count_internal + 1;
                    end if;
                    
                    if symbol_counter = N-1 then
                        -- Completed Chien search
                        if error_count_internal /= deg_error_locator then
                            -- Number of errors doesn't match degree of error locator polynomial
                            -- This indicates an uncorrectable error pattern
                            uncorrectable <= '1';
                            state <= IDLE;
                        else
                            -- Proceed to calculate error values
                            state <= FORNEY_ALGORITHM;
                            symbol_counter <= 0;
                        end if;
                    else
                        symbol_counter <= symbol_counter + 1;
                    end if;
                
                when FORNEY_ALGORITHM =>
                    -- Calculate error values using Forney algorithm
                    if symbol_counter < error_count_internal then
                        -- For each error location, calculate the error value
                        error_pos := to_integer(unsigned(error_locations(symbol_counter)));
                        
                        -- Calculate error evaluator polynomial (omega) at alpha^(-error_pos)
                        sum := (others => '0');
                        for j in 0 to deg_error_value loop
                            -- Calculate error_value_poly(j) * (alpha^(-error_pos))^j
                            temp := error_value_poly(j);
                            for k in 1 to j*(N-1-error_pos) loop
                                -- Multiply by alpha (primitive element)
                                if temp(SYMBOL_SIZE-1) = '1' then
                                    temp := (temp(SYMBOL_SIZE-2 downto 0) & '0') xor PRIMITIVE_POLY(SYMBOL_SIZE-1 downto 0);
                                else
                                    temp := temp(SYMBOL_SIZE-2 downto 0) & '0';
                                end if;
                            end loop;
                            
                            sum := gf_add(sum, temp);
                        end loop;
                        
                        -- Calculate derivative of error locator polynomial at alpha^(-error_pos)
                        temp := (others => '0');
                        for j in 1 to deg_error_locator step 2 loop
                            -- Only odd terms contribute to the derivative in GF(2^m)
                            -- Calculate error_locator_poly(j) * (alpha^(-error_pos))^(j-1)
                            temp_discrepancy := error_locator_poly(j);
                            for k in 1 to (j-1)*(N-1-error_pos) loop
                                -- Multiply by alpha (primitive element)
                                if temp_discrepancy(SYMBOL_SIZE-1) = '1' then
                                    temp_discrepancy := (temp_discrepancy(SYMBOL_SIZE-2 downto 0) & '0') xor PRIMITIVE_POLY(SYMBOL_SIZE-1 downto 0);
                                else
                                    temp_discrepancy := temp_discrepancy(SYMBOL_SIZE-2 downto 0) & '0';
                                end if;
                            end loop;
                            
                            temp := gf_add(temp, temp_discrepancy);
                        end loop;
                        
                        -- Error value = omega(alpha^(-error_pos)) / derivative(alpha^(-error_pos))
                        error_values(symbol_counter) <= gf_mult(sum, gf_inv(temp));
                        
                        symbol_counter <= symbol_counter + 1;
                    else
                        -- All error values calculated, proceed to correction
                        state <= OUTPUT_CORRECTED;
                        symbol_counter <= 0;
                        error_count <= error_count_internal;
                    end if;
                
                when OUTPUT_CORRECTED =>
                    -- Output the corrected codeword
                    if symbol_counter < N then
                        -- Check if current position has an error
                        error_found := false;
                        for i in 0 to error_count_internal-1 loop
                            if to_integer(unsigned(error_locations(i))) = symbol_counter then
                                -- Apply error correction
                                data_out <= gf_add(received_codeword(symbol_counter), error_values(i));
                                error_found := true;
                                exit;
                            end if;
                        end loop;
                        
                        if not error_found then
                            -- No error at this position
                            data_out <= received_codeword(symbol_counter);
                        end if;
                        
                        data_ready <= '1';
                        symbol_counter <= symbol_counter + 1;
                    else
                        -- All symbols output
                        data_ready <= '0';
                        decode_done <= '1';
                        state <= IDLE;
                    end if;
                
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end architecture rtl;

-- Testbench for the Reed-Solomon Decoder
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rs_constants.all;

entity rs_decoder_tb is
end entity rs_decoder_tb;

architecture sim of rs_decoder_tb is
    -- Component declaration
    component rs_decoder is
        port (
            clk         : in std_logic;
            reset       : in std_logic;
            data_in     : in std_logic_vector(SYMBOL_SIZE-1 downto 0);
            data_valid  : in std_logic;
            data_out    : out std_logic_vector(SYMBOL_SIZE-1 downto 0);
            data_ready  : out std_logic;
            decode_done : out std_logic;
            error_count : out integer range 0 to T;
            uncorrectable : out std_logic
        );
    end component;
    
    -- Test signals
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal data_in : std_logic_vector(SYMBOL_SIZE-1 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal data_out : std_logic_vector(SYMBOL_SIZE-1 downto 0);
    signal data_ready : std_logic;
    signal decode_done : std_logic;
    signal error_count : integer range 0 to T;
    signal uncorrectable : std_logic;
    
    -- Clock period definition
    constant CLK_PERIOD : time := 10 ns;
    
    -- Test data
    type test_data_array is array (0 to N-1) of std_logic_vector(SYMBOL_SIZE-1 downto 0);
    signal test_codeword : test_data_array;
    
begin
    -- Instantiate the Unit Under Test (UUT)
    uut: rs_decoder
        port map (
            clk => clk,
            reset => reset,
            data_in => data_in,
            data_valid => data_valid,
            data_out => data_out,
            data_ready => data_ready,
            decode_done => decode_done,
            error_count => error_count,
            uncorrectable => uncorrectable
        );
    
    -- Clock process
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Initialize test codeword (this would normally be encoded data)
        for i in 0 to N-1 loop
            test_codeword(i) <= std_logic_vector(to_unsigned(i mod 256, SYMBOL_SIZE));
        end loop;
        
        -- Apply reset
        reset <= '1';
        wait for CLK_PERIOD*5;
        reset <= '0';
        wait for CLK_PERIOD*2;
        
        -- Send test codeword with some errors
        for i in 0 to N-1 loop
            data_valid <= '1';
            
            -- Introduce errors at specific positions
            if i = 50 or i = 100 or i = 150 then
                -- Introduce error (flip bits)
                data_in <= not test_codeword(i);
            else
                data_in <= test_codeword(i);
            end if;
            
            wait for CLK_PERIOD;
        end loop;
        
        data_valid <= '0';
        
        -- Wait for decoder to finish
        wait until decode_done = '1';
        wait for CLK_PERIOD*5;
        
        -- End simulation
        wait;
    end process;
    
    -- Monitor process
    monitor_proc: process
    begin
        wait until data_ready = '1';
        while data_ready = '1' loop
            wait for CLK_PERIOD;
        end loop;
        
        if decode_done = '1' then
            report "Decoding complete. Error count: " & integer'image(error_count);
            if uncorrectable = '1' then
                report "Uncorrectable errors detected." severity warning;
            end if;
        end if;
        
        wait;
    end process;
end architecture sim;
