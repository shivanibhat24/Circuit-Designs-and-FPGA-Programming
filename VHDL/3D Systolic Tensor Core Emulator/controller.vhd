-- ==============================================================================
-- 3D Systolic Array Controller
-- ==============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.tensor_core_pkg.all;

entity systolic_array_3d is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        start         : in  std_logic;
        
        -- Input matrices
        matrix_a      : in  pe_data_3d;
        matrix_b      : in  pe_weight_3d;
        matrix_c      : in  pe_data_3d;
        
        -- Output matrix
        result_matrix : out pe_data_3d;
        
        -- Control
        op_type       : in  tensor_op_type;
        precision     : in  precision_type;
        done          : out std_logic
    );
end entity;

architecture structural of systolic_array_3d is
    -- Internal PE interconnect signals
    type pe_interconnect is array (0 to ARRAY_SIZE_X, 0 to ARRAY_SIZE_Y, 0 to ARRAY_SIZE_Z) 
                           of std_logic_vector(FP16_WIDTH-1 downto 0);
    type pe_acc_interconnect is array (0 to ARRAY_SIZE_X, 0 to ARRAY_SIZE_Y, 0 to ARRAY_SIZE_Z) 
                               of std_logic_vector(FP32_WIDTH-1 downto 0);
    
    signal data_flow_x, data_flow_y, data_flow_z : pe_interconnect;
    signal acc_flow : pe_acc_interconnect;
    signal weight_array : pe_weight_3d;
    
    -- Control signals
    signal pe_enable : std_logic;
    signal computation_active : std_logic;
    signal cycle_counter : unsigned(7 downto 0);
    
    component processing_element is
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            enable        : in  std_logic;
            data_in_x     : in  std_logic_vector(FP16_WIDTH-1 downto 0);
            data_in_y     : in  std_logic_vector(FP16_WIDTH-1 downto 0);
            data_in_z     : in  std_logic_vector(FP16_WIDTH-1 downto 0);
            weight_in     : in  std_logic_vector(FP16_WIDTH-1 downto 0);
            acc_in        : in  std_logic_vector(FP32_WIDTH-1 downto 0);
            data_out_x    : out std_logic_vector(FP16_WIDTH-1 downto 0);
            data_out_y    : out std_logic_vector(FP16_WIDTH-1 downto 0);
            data_out_z    : out std_logic_vector(FP16_WIDTH-1 downto 0);
            acc_out       : out std_logic_vector(FP32_WIDTH-1 downto 0);
            op_type       : in  tensor_op_type;
            precision     : in  precision_type
        );
    end component;
    
begin
    -- Generate 3D PE mesh
    gen_pe_array: for i in 0 to ARRAY_SIZE_X-1 generate
        gen_pe_row: for j in 0 to ARRAY_SIZE_Y-1 generate
            gen_pe_col: for k in 0 to ARRAY_SIZE_Z-1 generate
                pe_inst: processing_element
                port map (
                    clk => clk,
                    rst => rst,
                    enable => pe_enable,
                    
                    -- Data flow connections
                    data_in_x => data_flow_x(i, j, k),
                    data_in_y => data_flow_y(i, j, k),
                    data_in_z => data_flow_z(i, j, k),
                    
                    data_out_x => data_flow_x(i+1, j, k),
                    data_out_y => data_flow_y(i, j+1, k),
                    data_out_z => data_flow_z(i, j, k+1),
                    
                    -- Weight and accumulator
                    weight_in => weight_array(i, j, k),
                    acc_in => acc_flow(i, j, k),
                    acc_out => acc_flow(i+1, j+1, k+1),
                    
                    -- Control
                    op_type => op_type,
                    precision => precision
                );
            end generate;
        end generate;
    end generate;
    
    -- Control logic
    process (clk, rst)
    begin
        if rst = '1' then
            cycle_counter <= (others => '0');
            computation_active <= '0';
            pe_enable <= '0';
            done <= '0';
        elsif rising_edge(clk) then
            if start = '1' and computation_active = '0' then
                computation_active <= '1';
                pe_enable <= '1';
                cycle_counter <= (others => '0');
                done <= '0';
                
                -- Load weights
                weight_array <= matrix_b;
                
                -- Initialize data flows
                for i in 0 to ARRAY_SIZE_X-1 loop
                    for j in 0 to ARRAY_SIZE_Y-1 loop
                        for k in 0 to ARRAY_SIZE_Z-1 loop
                            data_flow_x(0, j, k) <= matrix_a(0, j, k)(FP16_WIDTH-1 downto 0);
                            data_flow_y(i, 0, k) <= matrix_a(i, 0, k)(FP16_WIDTH-1 downto 0);
                            data_flow_z(i, j, 0) <= matrix_a(i, j, 0)(FP16_WIDTH-1 downto 0);
                            acc_flow(i, j, k) <= matrix_c(i, j, k);
                        end loop;
                    end loop;
                end loop;
                
            elsif computation_active = '1' then
                cycle_counter <= cycle_counter + 1;
                
                -- Complete computation after sufficient cycles
                if cycle_counter >= ARRAY_SIZE_X + ARRAY_SIZE_Y + ARRAY_SIZE_Z + 5 then
                    computation_active <= '0';
                    pe_enable <= '0';
                    done <= '1';
                    
                    -- Collect results
                    for i in 0 to ARRAY_SIZE_X-1 loop
                        for j in 0 to ARRAY_SIZE_Y-1 loop
                            for k in 0 to ARRAY_SIZE_Z-1 loop
                                result_matrix(i, j, k) <= acc_flow(i+1, j+1, k+1);
                            end loop;
                        end loop;
                    end loop;
                end if;
            end if;
        end if;
    end process;
    
end architecture;
