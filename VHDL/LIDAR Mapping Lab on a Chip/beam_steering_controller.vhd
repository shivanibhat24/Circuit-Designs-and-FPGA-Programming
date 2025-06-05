-- Beam Steering Controller
-- Controls MEMS mirrors or galvanometer for 2D beam scanning

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lidar_pkg.all;

entity beam_steering_controller is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        start_scan      : in  std_logic;
        angle_step      : in  std_logic_vector(7 downto 0);
        scan_rate       : in  std_logic_vector(15 downto 0);
        beam_angle_x    : out std_logic_vector(7 downto 0);
        beam_angle_y    : out std_logic_vector(7 downto 0);
        scan_complete   : out std_logic;
        beam_valid      : out std_logic
    );
end beam_steering_controller;

architecture rtl of beam_steering_controller is
    type state_t is (IDLE, SCAN_X, SCAN_Y, SETTLE, COMPLETE);
    signal state : state_t := IDLE;
    
    signal x_angle : unsigned(7 downto 0) := (others => '0');
    signal y_angle : unsigned(7 downto 0) := (others => '0');
    signal rate_counter : unsigned(15 downto 0) := (others => '0');
    signal settle_counter : unsigned(7 downto 0) := (others => '0');
    signal step_size : unsigned(7 downto 0);
    signal rate_limit : unsigned(15 downto 0);
    
    constant SETTLE_TIME : unsigned(7 downto 0) := to_unsigned(50, 8); -- 500ns settle
    constant MAX_ANGLE : unsigned(7 downto 0) := to_unsigned(255, 8);
    
begin
    step_size <= unsigned(angle_step);
    rate_limit <= unsigned(scan_rate);
    
    beam_angle_x <= std_logic_vector(x_angle);
    beam_angle_y <= std_logic_vector(y_angle);
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                x_angle <= (others => '0');
                y_angle <= (others => '0');
                rate_counter <= (others => '0');
                settle_counter <= (others => '0');
                scan_complete <= '0';
                beam_valid <= '0';
            else
                case state is
                    when IDLE =>
                        scan_complete <= '0';
                        beam_valid <= '0';
                        if start_scan = '1' then
                            state <= SCAN_X;
                            x_angle <= (others => '0');
                            y_angle <= (others => '0');
                            rate_counter <= (others => '0');
                        end if;
                    
                    when SCAN_X =>
                        if rate_counter >= rate_limit then
                            rate_counter <= (others => '0');
                            state <= SETTLE;
                            settle_counter <= (others => '0');
                        else
                            rate_counter <= rate_counter + 1;
                        end if;
                    
                    when SETTLE =>
                        if settle_counter >= SETTLE_TIME then
                            beam_valid <= '1';
                            settle_counter <= (others => '0');
                            
                            -- Move to next X position
                            if x_angle + step_size <= MAX_ANGLE then
                                x_angle <= x_angle + step_size;
                                state <= SCAN_X;
                            else
                                -- Move to next Y line
                                x_angle <= (others => '0');
                                if y_angle + step_size <= MAX_ANGLE then
                                    y_angle <= y_angle + step_size;
                                    state <= SCAN_X;
                                else
                                    state <= COMPLETE;
                                end if;
                            end if;
                        else
                            settle_counter <= settle_counter + 1;
                            beam_valid <= '0';
                        end if;
                    
                    when COMPLETE =>
                        scan_complete <= '1';
                        beam_valid <= '0';
                        if start_scan = '0' then
                            state <= IDLE;
                        end if;
                    
                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
    
end rtl;
