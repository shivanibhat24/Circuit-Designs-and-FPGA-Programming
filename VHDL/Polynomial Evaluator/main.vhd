-- Library declarations
library IEEE; 
use IEEE.STD_LOGIC_1164.all;  
use IEEE.NUMERIC_STD.all; -- Using NUMERIC_STD instead of STD_LOGIC_UNSIGNED and STD_LOGIC_ARITH for better portability

-- Entity declaration for polynomial evaluator
-- This design implements a polynomial function evaluator with configurable bit widths
-- The polynomial being evaluated is of the form: f(x) = a*x^2 + b*x + c
ENTITY PolynomialEvaluator IS
    GENERIC (
        COEFF_WIDTH  : positive := 3;  -- Width of coefficient input (ai)
        X_WIDTH      : positive := 2;  -- Width of x input
        CONTROL_WIDTH: positive := 3;  -- Width of control signal
        DATA_WIDTH   : positive := 16  -- Width of output and intermediate data
    );
    PORT (
        clk     : IN  STD_LOGIC;                                   -- System clock
        rst     : IN  STD_LOGIC;                                   -- Active high reset
        ai      : IN  STD_LOGIC_VECTOR(COEFF_WIDTH-1 downto 0);    -- Coefficient input
        x       : IN  STD_LOGIC_VECTOR(X_WIDTH-1 downto 0);        -- X value input
        fx      : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)      -- Polynomial result output
    ); 
END PolynomialEvaluator;

-- Behavioral architecture
ARCHITECTURE bhv OF PolynomialEvaluator IS
    -- Internal signals
    SIGNAL accum      : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');  -- Accumulator for polynomial calculation
    SIGNAL control    : STD_LOGIC_VECTOR(CONTROL_WIDTH-1 downto 0) := (CONTROL_WIDTH-3 => '1', others => '0');  -- Ring counter for control
    SIGNAL result     : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');  -- Final result register

    -- Constants for clarity
    CONSTANT RESULT_VALID_BIT : integer := 1;  -- Control bit position that indicates valid result
BEGIN
    -- Main sequential process
    PROCESS(clk, rst)
        -- Variables for intermediate calculations
        variable temp_product : unsigned(X_WIDTH + DATA_WIDTH-1 downto 0);
        variable temp_sum     : unsigned(DATA_WIDTH-1 downto 0);
    BEGIN
        -- Synchronous reset
        IF rst = '1' THEN
            -- Reset all registers
            accum   <= (others => '0');
            control <= (CONTROL_WIDTH-3 => '1', others => '0');  -- Initialize ring counter
            result  <= (others => '0');
            
        ELSIF rising_edge(clk) THEN
            -- Rotate control bits (ring counter)
            control <= control(0) & control(CONTROL_WIDTH-1 downto 1);
            
            -- Calculate polynomial term: x * (ai + accum[lower bits])
            -- This implements Horner's method for polynomial evaluation
            temp_sum := unsigned('0' & accum(COEFF_WIDTH-1 downto 0)) + unsigned('0' & ai);
            temp_product := unsigned(x) * temp_sum;
            
            -- Prevent overflow by limiting result size to DATA_WIDTH
            if temp_product > (2**DATA_WIDTH - 1) then
                accum <= (others => '1');  -- Saturate on overflow
            else
                accum <= std_logic_vector(resize(temp_product, DATA_WIDTH));
            end if;
            
            -- When control bit indicates result is valid, add final coefficient
            IF control(RESULT_VALID_BIT) = '1' THEN
                temp_sum := unsigned(accum) + unsigned('0' & ai);
                -- Prevent overflow in final addition
                if temp_sum > (2**DATA_WIDTH - 1) then
                    result <= (others => '1');  -- Saturate on overflow
                else
                    result <= std_logic_vector(temp_sum(DATA_WIDTH-1 downto 0));
                end if;
            END IF;
        END IF;
    END PROCESS;
    
    -- Output assignment
    fx <= result;
    
    -- Assertion to check generic parameter constraints
    assert COEFF_WIDTH <= DATA_WIDTH
        report "Coefficient width must be less than or equal to data width"
        severity ERROR;
        
    assert X_WIDTH + COEFF_WIDTH <= DATA_WIDTH
        report "Sum of X_WIDTH and COEFF_WIDTH should be less than DATA_WIDTH to prevent overflow"
        severity WARNING;
        
END bhv;
