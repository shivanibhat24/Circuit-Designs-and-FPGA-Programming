-- ==============================================================================
-- Matrix Inversion Engine using Gauss-Jordan Elimination
-- ==============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.mimo_decoder_pkg.all;

entity matrix_inverter is
    generic (
        MATRIX_SIZE : integer := 16
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        start           : in  std_logic;
        
        -- Input matrix (row-major order)
        matrix_in       : in  complex_vector(0 to MATRIX_SIZE*MATRIX_SIZE-1);
        matrix_valid    : in  std_logic;
        
        -- Output inverted matrix
        matrix_out      : out complex_vector(0 to MATRIX_SIZE*MATRIX_SIZE-1);
        matrix_out_valid: out std_logic;
        
        -- Status
        busy            : out std_logic;
        error           : out std_logic  -- Singular matrix detected
    );
end entity;

architecture behavioral of matrix_inverter is
    type state_type is (IDLE, LOAD_MATRIX, FORWARD_ELIM, BACK_SUBST, OUTPUT, ERROR_STATE);
    signal state : state_type;
    
    -- Internal matrix storage (augmented with identity matrix)
    type augmented_matrix_type is array (0 to MATRIX_SIZE-1, 0 to 2*MATRIX_SIZE-1) of complex_fixed;
    signal aug_matrix : augmented_matrix_type;
    
    signal row_idx, col_idx : integer range 0 to MATRIX_SIZE-1;
    signal pivot_element : complex_fixed;
    signal operation_done : std_logic;
    
begin
    process(clk)
        variable pivot_found : boolean;
        variable temp_element : complex_fixed;
        variable pivot_magnitude : sfixed(DATA_WIDTH-1 downto -FRAC_WIDTH);
        variable current_magnitude : sfixed(DATA_WIDTH-1 downto -FRAC_WIDTH);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                busy <= '0';
                error <= '0';
                matrix_out_valid <= '0';
                row_idx <= 0;
                col_idx <= 0;
                
            else
                case state is
                    when IDLE =>
                        if start = '1' and matrix_valid = '1' then
                            state <= LOAD_MATRIX;
                            busy <= '1';
                            row_idx <= 0;
                            col_idx <= 0;
                        end if;
                        
                    when LOAD_MATRIX =>
                        -- Load input matrix and create augmented matrix with identity
                        for i in 0 to MATRIX_SIZE-1 loop
                            for j in 0 to MATRIX_SIZE-1 loop
                                aug_matrix(i, j) <= matrix_in(i*MATRIX_SIZE + j);
                            end loop;
                            for j in MATRIX_SIZE to 2*MATRIX_SIZE-1 loop
                                if j-MATRIX_SIZE = i then
                                    aug_matrix(i, j) <= complex_one;
                                else
                                    aug_matrix(i, j) <= complex_zero;
                                end if;
                            end loop;
                        end loop;
                        state <= FORWARD_ELIM;
                        row_idx <= 0;
                        
                    when FORWARD_ELIM =>
                        if row_idx < MATRIX_SIZE then
                            -- Find pivot element
                            pivot_found := false;
                            pivot_magnitude := aug_matrix(row_idx, row_idx).re * aug_matrix(row_idx, row_idx).re + 
                                             aug_matrix(row_idx, row_idx).im * aug_matrix(row_idx, row_idx).im;
                            
                            -- Check if pivot is too small (near-singular)
                            if pivot_magnitude < to_sfixed(0.001, DATA_WIDTH-1, -FRAC_WIDTH) then
                                -- Try to find better pivot in same column
                                for k in row_idx+1 to MATRIX_SIZE-1 loop
                                    current_magnitude := aug_matrix(k, row_idx).re * aug_matrix(k, row_idx).re + 
                                                       aug_matrix(k, row_idx).im * aug_matrix(k, row_idx).im;
                                    if current_magnitude > pivot_magnitude then
                                        -- Swap rows
                                        for j in 0 to 2*MATRIX_SIZE-1 loop
                                            temp_element := aug_matrix(row_idx, j);
                                            aug_matrix(row_idx, j) <= aug_matrix(k, j);
                                            aug_matrix(k, j) <= temp_element;
                                        end loop;
                                        pivot_magnitude := current_magnitude;
                                        pivot_found := true;
                                    end if;
                                end loop;
                            else
                                pivot_found := true;
                            end if;
                            
                            if not pivot_found or pivot_magnitude < to_sfixed(0.0001, DATA_WIDTH-1, -FRAC_WIDTH) then
                                state <= ERROR_STATE;
                            else
                                -- Normalize pivot row
                                pivot_element <= aug_matrix(row_idx, row_idx);
                                for j in 0 to 2*MATRIX_SIZE-1 loop
                                    aug_matrix(row_idx, j) <= complex_mult(aug_matrix(row_idx, j), 
                                                             complex_fixed'(re => pivot_element.re / pivot_magnitude, 
                                                                           im => -pivot_element.im / pivot_magnitude));
                                end loop;
                                
                                -- Eliminate column entries below pivot
                                for i in row_idx+1 to MATRIX_SIZE-1 loop
                                    temp_element := aug_matrix(i, row_idx);
                                    for j in 0 to 2*MATRIX_SIZE-1 loop
                                        aug_matrix(i, j) <= complex_sub(aug_matrix(i, j), 
                                                          complex_mult(temp_element, aug_matrix(row_idx, j)));
                                    end loop;
                                end loop;
                                
                                row_idx <= row_idx + 1;
                            end if;
                        else
                            state <= BACK_SUBST;
                            row_idx <= MATRIX_SIZE - 1;
                        end if;
                        
                    when BACK_SUBST =>
                        if row_idx >= 0 then
                            -- Eliminate entries above pivot
                            for i in 0 to row_idx-1 loop
                                temp_element := aug_matrix(i, row_idx);
                                for j in 0 to 2*MATRIX_SIZE-1 loop
                                    aug_matrix(i, j) <= complex_sub(aug_matrix(i, j), 
                                                      complex_mult(temp_element, aug_matrix(row_idx, j)));
                                end loop;
                            end loop;
                            
                            if row_idx > 0 then
                                row_idx <= row_idx - 1;
                            else
                                state <= OUTPUT;
                            end if;
                        end if;
                        
                    when OUTPUT =>
                        -- Extract inverted matrix from augmented matrix
                        for i in 0 to MATRIX_SIZE-1 loop
                            for j in 0 to MATRIX_SIZE-1 loop
                                matrix_out(i*MATRIX_SIZE + j) <= aug_matrix(i, j + MATRIX_SIZE);
                            end loop;
                        end loop;
                        matrix_out_valid <= '1';
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
