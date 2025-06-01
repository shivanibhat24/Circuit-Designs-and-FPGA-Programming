-- =============================================================================
-- RSA ACCELERATOR PACKAGE
-- =============================================================================
-- File: rsa_pkg.vhd
-- Package containing constants, types, and component declarations for RSA accelerator

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package rsa_pkg is
    -- Global constants
    constant RSA_KEY_WIDTH    : integer := 256;
    constant PE_DATA_WIDTH    : integer := 32;
    constant SYSTOLIC_SIZE    : integer := 8;
    constant EXP_WIDTH        : integer := 256;
    constant ADDR_WIDTH       : integer := 8;
    
    -- RSA operation types
    type rsa_op_type is (RSA_ENCRYPT, RSA_DECRYPT, RSA_SIGN, RSA_VERIFY);
    
    -- RSA state machine states
    type rsa_state_type is (
        RSA_IDLE,
        RSA_LOAD_PARAMS,
        RSA_COMPUTE,
        RSA_WAIT_RESULT,
        RSA_STORE_RESULT,
        RSA_COMPLETE,
        RSA_ERROR
    );
    
    -- Array types for multi-word operations
    type word_array_type is array (natural range <>) of std_logic_vector(PE_DATA_WIDTH-1 downto 0);
    type carry_array_type is array (natural range <>) of std_logic_vector(PE_DATA_WIDTH downto 0);
    
    -- Component declarations
    component montgomery_pe is
        generic (
            DATA_WIDTH : integer := PE_DATA_WIDTH
        );
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            enable    : in  std_logic;
            x_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            y_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            m_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            c_in      : in  std_logic_vector(DATA_WIDTH downto 0);
            x_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
            y_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
            m_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
            c_out     : out std_logic_vector(DATA_WIDTH downto 0);
            valid_out : out std_logic
        );
    end component;
    
    component systolic_array is
        generic (
            DATA_WIDTH : integer := PE_DATA_WIDTH;
            ARRAY_SIZE : integer := SYSTOLIC_SIZE
        );
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            start     : in  std_logic;
            x_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            y_data    : in  std_logic_vector(DATA_WIDTH*ARRAY_SIZE-1 downto 0);
            m_data    : in  std_logic_vector(DATA_WIDTH*ARRAY_SIZE-1 downto 0);
            result    : out std_logic_vector(DATA_WIDTH*ARRAY_SIZE-1 downto 0);
            valid     : out std_logic;
            busy      : out std_logic
        );
    end component;
    
    component modexp_core is
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
    end component;
    
    component rsa_core is
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
    end component;
    
    -- Utility functions
    function log2_ceil(n : integer) return integer;
    function is_power_of_2(n : integer) return boolean;
    
end package rsa_pkg;

package body rsa_pkg is
    
    function log2_ceil(n : integer) return integer is
        variable temp : integer := n;
        variable result : integer := 0;
    begin
        while temp > 1 loop
            temp := temp / 2;
            result := result + 1;
        end loop;
        if 2**result < n then
            result := result + 1;
        end if;
        return result;
    end function;
    
    function is_power_of_2(n : integer) return boolean is
    begin
        return (n > 0) and ((n and (n-1)) = 0);
    end function;
    
end package body rsa_pkg;
