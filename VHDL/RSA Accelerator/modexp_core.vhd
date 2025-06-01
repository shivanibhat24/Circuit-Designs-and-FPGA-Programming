-- =============================================================================
-- MODULAR EXPONENTIATION CORE
-- =============================================================================
-- File: modexp_core.vhd
-- Core module for modular exponentiation using binary method

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rsa_pkg.all;

entity modexp_core is
    generic (
        KEY_WIDTH  : integer := RSA_KEY_WIDTH;
        DATA_WIDTH : integer := PE_DATA_WIDTH;
        ARRAY_SIZE : integer := SYSTOLIC_SIZE
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        start     : in  std_logic;
        base      : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        exponent  : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        modulus   : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        result    : out std_logic_vector(KEY_WIDTH-1 downto 0);
        done      : out std_logic;
        busy      : out std_logic;
        error     : out std_logic
    );
end modexp_core;

architecture behavioral of modexp_core is
    type modexp_state_type is (
        IDLE,
        INIT,
        SQUARE_BASE,
        WAIT_SQUARE,
        CHECK_BIT,
        MULTIPLY,
        WAIT_MULTIPLY,
        SHIFT_EXP,
        FINAL_REDUCE,
        COMPLETE,
        ERROR_STATE
    );
    
    signal state : modexp_state_type;
    signal next_state : modexp_state_type;
    
    -- Internal registers
    signal accumulator : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal base_reg : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal exp_reg : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal mod_reg : std_logic_vector(KEY_WIDTH-1 downto 0);
    
    -- Systolic array interface
    signal array_start : std_logic;
    signal array_result : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal array_valid : std_logic;
    signal array_busy : std_logic;
    
    -- Control signals
    signal exp_bit : std_logic;
    signal exp_zero : std_logic;
    signal bit_counter : integer range 0 to KEY_WIDTH;
    
begin
    -- Systolic array instance
    mult_array: systolic_array
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            ARRAY_SIZE => ARRAY_SIZE
        )
        port map (
            clk => clk,
            rst => rst,
            start => array_start,
            x_data => base_reg(DATA_WIDTH-1 downto 0),
            y_data => accumulator,
            m_data => mod_reg,
            result => array_result,
            valid => array_valid,
            busy => array_busy
        );
    
    exp_bit <= exp_reg(0);
    exp_zero <= '1' when unsigned(exp_reg) = 0 else '0';
    
    -- Main state machine
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                accumulator <= (others => '0');
                base_reg <= (others => '0');
                exp_reg <= (others => '0');
                mod_reg <= (others => '0');
                array_start <= '0';
                bit_counter <= 0;
                result <= (others => '0');
                done <= '0';
                busy <= '0';
                error <= '0';
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        busy <= '0';
                        error <= '0';
                        array_start <= '0';
                        if start = '1' then
                            -- Input validation
                            if unsigned(modulus) <= 1 then
                                state <= ERROR_STATE;
                            else
                                base_reg <= base;
                                exp_reg <= exponent;
                                mod_reg <= modulus;
                                bit_counter <= KEY_WIDTH;
                                state <= INIT;
                                busy <= '1';
                            end if;
                        end if;
                    
                    when INIT =>
                        accumulator <= (0 => '1', others => '0'); -- Set to 1
                        state <= CHECK_BIT;
                    
                    when CHECK_BIT =>
                        if exp_zero = '1' then
                            state <= COMPLETE;
                        elsif exp_bit = '1' then
                            array_start <= '1';
                            state <= MULTIPLY;
                        else
                            state <= SQUARE_BASE;
                        end if;
                    
                    when MULTIPLY =>
                        array_start <= '0';
                        state <= WAIT_MULTIPLY;
                    
                    when WAIT_MULTIPLY =>
                        if array_valid = '1' then
                            accumulator <= array_result;
                            state <= SQUARE_BASE;
                        end if;
                    
                    when SQUARE_BASE =>
                        if bit_counter > 1 then
                            array_start <= '1';
                            state <= WAIT_SQUARE;
                        else
                            state <= COMPLETE;
                        end if;
                    
                    when WAIT_SQUARE =>
                        array_start <= '0';
                        if array_valid = '1' then
                            base_reg <= array_result;
                            state <= SHIFT_EXP;
                        end if;
                    
                    when SHIFT_EXP =>
                        exp_reg <= '0' & exp_reg(KEY_WIDTH-1 downto 1);
                        bit_counter <= bit_counter - 1;
                        state <= CHECK_BIT;
                    
                    when COMPLETE =>
                        result <= accumulator;
                        done <= '1';
                        busy <= '0';
                        state <= IDLE;
                    
                    when ERROR_STATE =>
                        error <= '1';
                        busy <= '0';
                        state <= IDLE;
                        
                    when others =>
                        state <= ERROR_STATE;
                end case;
            end if;
        end if;
    end process;
    
end behavioral;
