-- =============================================================================
-- RSA CORE MODULE
-- =============================================================================
-- File: rsa_core.vhd
-- Main RSA computation core with operation selection

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rsa_pkg.all;

entity rsa_core is
    generic (
        KEY_WIDTH : integer := RSA_KEY_WIDTH
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        operation   : in  rsa_op_type;
        message     : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        public_exp  : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        private_exp : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        modulus     : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        result      : out std_logic_vector(KEY_WIDTH-1 downto 0);
        done        : out std_logic;
        busy        : out std_logic;
        error       : out std_logic
    );
end rsa_core;

architecture behavioral of rsa_core is
    signal selected_exp : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal modexp_start : std_logic;
    signal modexp_done : std_logic;
    signal modexp_busy : std_logic;
    signal modexp_error : std_logic;
    signal modexp_result : std_logic_vector(KEY_WIDTH-1 downto 0);
    
    signal state : rsa_state_type;
    
begin
    -- Select appropriate exponent based on operation
    process(operation, public_exp, private_exp)
    begin
        case operation is
            when RSA_ENCRYPT | RSA_VERIFY =>
                selected_exp <= public_exp;
            when RSA_DECRYPT | RSA_SIGN =>
                selected_exp <= private_exp;
            when others =>
                selected_exp <= public_exp;
        end case;
    end process;
    
    -- Modular exponentiation unit
    modexp_unit: modexp_core
        generic map (
            KEY_WIDTH => KEY_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            start => modexp_start,
            base => message,
            exponent => selected_exp,
            modulus => modulus,
            result => modexp_result,
            done => modexp_done,
            busy => modexp_busy,
            error => modexp_error
        );
    
    -- RSA operation control FSM
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= RSA_IDLE;
                modexp_start <= '0';
                result <= (others => '0');
                done <= '0';
                busy <= '0';
                error <= '0';
            else
                case state is
                    when RSA_IDLE =>
                        done <= '0';
                        busy <= '0';
                        error <= '0';
                        modexp_start <= '0';
                        if start = '1' then
                            state <= RSA_LOAD_PARAMS;
                        end if;
                    
                    when RSA_LOAD_PARAMS =>
                        -- Parameter validation could be added here
                        if unsigned(message) >= unsigned(modulus) then
                            state <= RSA_ERROR;
                        else
                            busy <= '1';
                            state <= RSA_COMPUTE;
                        end if;
                    
                    when RSA_COMPUTE =>
                        modexp_start <= '1';
                        state <= RSA_WAIT_RESULT;
                    
                    when RSA_WAIT_RESULT =>
                        modexp_start <= '0';
                        if modexp_done = '1' then
                            if modexp_error = '1' then
                                state <= RSA_ERROR;
                            else
                                result <= modexp_result;
                                state <= RSA_COMPLETE;
                            end if;
                        end if;
                    
                    when RSA_COMPLETE =>
                        done <= '1';
                        busy <= '0';
                        state <= RSA_IDLE;
                    
                    when RSA_ERROR =>
                        error <= '1';
                        busy <= '0';
                        state <= RSA_IDLE;
                    
                    when others =>
                        state <= RSA_ERROR;
                end case;
            end if;
        end if;
    end process;
    
end behavioral;
