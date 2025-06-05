-- =========================================================================
-- PACKAGE: Common Types and Constants
-- =========================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package self_mod_pkg is
    -- Configuration constants
    constant DATA_WIDTH : integer := 32;
    constant PATH_COUNT : integer := 8;
    constant LFSR_WIDTH : integer := 16;
    constant CONFIG_WIDTH : integer := 64;
    constant DUMMY_OPS : integer := 4;
    
    -- Type definitions
    type path_array_t is array (0 to PATH_COUNT-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    type config_array_t is array (0 to PATH_COUNT-1) of std_logic_vector(7 downto 0);
    type dummy_array_t is array (0 to DUMMY_OPS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Operation types for path selection
    type operation_t is (OP_XOR, OP_AND, OP_OR, OP_ADD, OP_SUB, OP_MUL, OP_ROT, OP_DUMMY);
    type op_array_t is array (0 to PATH_COUNT-1) of operation_t;
    
    -- Function declarations
    function lfsr_next(current : std_logic_vector) return std_logic_vector;
    function select_operation(sel : std_logic_vector(2 downto 0)) return operation_t;
end package;

package body self_mod_pkg is
    -- LFSR feedback function for pseudo-random generation
    function lfsr_next(current : std_logic_vector) return std_logic_vector is
        variable result : std_logic_vector(current'range);
    begin
        result := current(current'high-1 downto 0) & 
                 (current(15) xor current(13) xor current(12) xor current(10));
        return result;
    end function;
    
    -- Operation selection based on random bits
    function select_operation(sel : std_logic_vector(2 downto 0)) return operation_t is
    begin
        case sel is
            when "000" => return OP_XOR;
            when "001" => return OP_AND;
            when "010" => return OP_OR;
            when "011" => return OP_ADD;
            when "100" => return OP_SUB;
            when "101" => return OP_MUL;
            when "110" => return OP_ROT;
            when others => return OP_DUMMY;
        end case;
    end function;
end package body;
