----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.03.2024 10:16:14
-- Design Name: 
-- Module Name: DAQ_TOP - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all; -- need this for using the OBUFDS output buffer

entity DAQ_TOP is
    Port
    (
        CLK_50_i      :    in std_logic; 
        
        DAC_MOSI_o    :   out std_logic;
        DAC_SCLK_o    :   out std_logic;
        DAC_SS_N_o    :   out std_logic;
        
        WIZ_ADDR_o    :   out std_logic_vector(9 downto 1);
        WIZ_RD_N_o    :   out std_logic;
        WIZ_WR_N_o    :   out std_logic;
        WIZ_DATA_io   : inout std_logic_vector(15 downto 0);
        WIZ_CS_N_o    :   out std_logic;
        WIZ_INT_N_i   :    in std_logic;
        WIZ_RST_N_o   :   out std_logic;
        
        DRS_RST_N_o   :   out std_logic;
        DRS_ADDR_o    :   out std_logic_vector(3 downto 0);
        DRS_SRCLK_o   :   out std_logic;
        DRS_SRIN_o    :   out std_logic;
        DRS_SROUT_i   :    in std_logic;
        DRS_RSRLOAD_o :   out std_logic;
        DRS_DENABLE_o :   out std_logic;
        DRS_DWRITE_o  :   out std_logic;
        --DRS_REFCLK_o  :   out std_logic; -- single ended clock out
        DRS_REFCLK_o_p  :   out std_logic; -- LVDS clock out pos
        DRS_REFCLK_o_m  :   out std_logic; -- LVDS clock out neg
        DRS_PLL_LCK_i :    in std_logic;
        
        TRIG_IN_i     :    in std_logic;
        CH0_TRIG_i    :    in std_logic;
        CH2_TRIG_i    :    in std_logic;
        CH4_TRIG_i    :    in std_logic;
        CH6_TRIG_i    :    in std_logic;
        
        ADC_DATA_i    :    in std_logic_vector(11 downto 0);
        ADC_CLK_o     :   out std_logic;
        
        TCAL_OSC_EN_o :   out std_logic;
        TIMING_o      :   out std_logic;
        
        SPARE_o       :   out std_logic_vector(19 downto 0);
        
        FPGA_RXD_i    :    in std_logic;
        FPGA_TXD_o    :   out std_logic;
        
        LED0_o        :   out std_logic;
        LED1_o        :   out std_logic;
        SW0_i         :    in std_logic        
    );
end DAQ_TOP;

architecture Behavioral of DAQ_TOP is

--*******************************************--
-- Component Declaration Old style

-- The MicroBlaze System
component mb_system is
  port (
    clk_50MHz : in STD_LOGIC;
    reset_rtl_0 : in STD_LOGIC;
    uart_rtl_0_rxd : in STD_LOGIC;
    uart_rtl_0_txd : out STD_LOGIC;
    dac_spi_ss_n_tri_o : out STD_LOGIC_VECTOR ( 0 to 0 );
    dac_spi_mosi_tri_o : out STD_LOGIC_VECTOR ( 0 to 0 );
    dac_spi_sclk_tri_o : out STD_LOGIC_VECTOR ( 0 to 0 );
    wiz_rst_n_tri_o : out STD_LOGIC_VECTOR ( 0 to 0 );
    drs_rst_n_tri_o : out STD_LOGIC_VECTOR ( 0 to 0 );
    led_gpio_tri_o : out STD_LOGIC_VECTOR ( 1 downto 0 );
    daq_rst_n_tri_o : out STD_LOGIC_VECTOR ( 0 to 0 );
    wiz_int : in STD_LOGIC;
    daq_event_int : in STD_LOGIC;
    intr_in : in STD_LOGIC;
    daq_logic_clk : out STD_LOGIC;
    adc_clk_in : out STD_LOGIC;
    drs_ref_clk_gen : out STD_LOGIC;
    wiz_emc_addr : out STD_LOGIC_VECTOR ( 31 downto 0 );
    wiz_emc_adv_ldn : out STD_LOGIC;
    wiz_emc_ben : out STD_LOGIC_VECTOR ( 1 downto 0 );
    wiz_emc_ce : out STD_LOGIC_VECTOR ( 0 to 0 );
    wiz_emc_ce_n : out STD_LOGIC_VECTOR ( 0 to 0 );
    wiz_emc_clken : out STD_LOGIC;
    wiz_emc_cre : out STD_LOGIC;
    wiz_emc_dq_i : in STD_LOGIC_VECTOR ( 15 downto 0 );
    wiz_emc_dq_o : out STD_LOGIC_VECTOR ( 15 downto 0 );
    wiz_emc_dq_t : out STD_LOGIC_VECTOR ( 15 downto 0 );
    wiz_emc_lbon : out STD_LOGIC;
    wiz_emc_oen : out STD_LOGIC_VECTOR ( 0 to 0 );
    wiz_emc_qwen : out STD_LOGIC_VECTOR ( 1 downto 0 );
    wiz_emc_rnw : out STD_LOGIC;
    wiz_emc_rpn : out STD_LOGIC;
    wiz_emc_wait : in STD_LOGIC_VECTOR ( 0 to 0 );
    wiz_emc_wen : out STD_LOGIC;
    daq_logic_emc_addr : out STD_LOGIC_VECTOR ( 31 downto 0 );
    daq_logic_emc_adv_ldn : out STD_LOGIC;
    daq_logic_emc_ben : out STD_LOGIC_VECTOR ( 3 downto 0 );
    daq_logic_emc_ce : out STD_LOGIC_VECTOR ( 0 to 0 );
    daq_logic_emc_ce_n : out STD_LOGIC_VECTOR ( 0 to 0 );
    daq_logic_emc_clken : out STD_LOGIC;
    daq_logic_emc_cre : out STD_LOGIC;
    daq_logic_emc_dq_i : in STD_LOGIC_VECTOR ( 31 downto 0 );
    daq_logic_emc_dq_o : out STD_LOGIC_VECTOR ( 31 downto 0 );
    daq_logic_emc_dq_t : out STD_LOGIC_VECTOR ( 31 downto 0 );
    daq_logic_emc_lbon : out STD_LOGIC;
    daq_logic_emc_oen : out STD_LOGIC_VECTOR ( 0 to 0 );
    daq_logic_emc_qwen : out STD_LOGIC_VECTOR ( 3 downto 0 );
    daq_logic_emc_rnw : out STD_LOGIC;
    daq_logic_emc_rpn : out STD_LOGIC;
    daq_logic_emc_wait : in STD_LOGIC_VECTOR ( 0 to 0 );
    daq_logic_emc_wen : out STD_LOGIC
  );
end component mb_system;

component IOBUF is
  port (
    I : in STD_LOGIC;
    O : out STD_LOGIC;
    T : in STD_LOGIC;
    IO : inout STD_LOGIC
  );
end component IOBUF;

-- The DAQ Logic
component CMVD_DAQ_LOGIC is
	port
	(
		LCLK		: in std_logic;
		nRST		: in std_logic;
		MCU_ADDR	: in std_logic_vector(7 downto 0);
		MCU_nRD		: in std_logic;
		MCU_nWR		: in std_logic;
		--MCU_DATA	: inout std_logic_vector(31 downto 0);
		MCU_DATA_IN	: in std_logic_vector(31 downto 0);
		MCU_DATA_OUT: out std_logic_vector(31 downto 0);
		MCU_EVE_INT	: out std_logic;
		----------------------------------
		-- DRS Related ports
		----------------------------------
      
		DRS_ADDR    : out std_logic_vector(3 downto 0);
		DRS_SRCLK   : out std_logic;
		DRS_SRIN    : out std_logic;
		DRS_SROUT   : in std_logic;

		DRS_RSRLOAD : out std_logic;-- Read Shift Register Load Input : "pulse"
		
		DRS_DENABLE : out std_logic;-- low-to-high transition starts the Domino Wave. 
		DRS_DWRITE  : out std_logic;-- Connects the Domino Wave Circuit to the Sampling Cells to enable sampling if high.
		DRS_PLL_LCK : in std_logic;-- PLL Lock Indicator Output.
		DRS_REF_clk : out std_logic;
		DRS_REF_CLK_GEN : in std_logic; -- 62.5 MHz cock for the generation of drs_ref_clk of 488.28125 kHz
		----------------------------------
		-- ADC 
		----------------------------------
		ADC_DATA 	: in std_logic_vector(11 downto 0);--ADC_DATA_WIDTH
		ADC_CLK_IN  : in std_logic;
		ADC_CLK_OUT : out std_logic;
		----------------------------------
		-- Other/Mislenious
		----------------------------------
		TCAL_CTRL 	: out std_logic;-- Timing calibration control : crystal ON/OFF	

		----------------------------------
		-- Global services
		----------------------------------	
		TRIG_IN	 	: in std_logic;
		TIM	     	: out std_logic; -- Timing signal to ch 8 of DRS		

		----------------------------------
		-- local HW trigger
		----------------------------------
		AIN0_L0		:  in std_logic; -- CH0_TRIG   
		AIN1_H0		:  in std_logic; -- CH2_TRIG   
		AIN2_L1		:  in std_logic; -- CH4_TRIG   
		AIN3_H1		:  in std_logic; -- CH6_TRIG   
		
		
		DRS_RST		: in std_logic;
		TRIGGER_o	: out std_logic; -- taken out for debug (count no of pulses generated etc)  
		FIFO_WR_EN	: out std_logic; -- taken out for debug only 
		LED         : out std_logic_vector(1 downto 0) -- blink LED usign the DAQ Logic if required
		
	);
end component;

-- 
-- signals 
--

    signal s_MB_INTR1       : std_logic;
    signal s_ADC_CLK_IN     : std_logic;
    signal s_CLK_50M        : std_logic;
    
    signal s_DAC_SPI_MOSI   : std_logic;
    signal s_DAC_SPI_SCLK   : std_logic;
    signal s_DAC_SPI_SS_N   : std_logic;
    
    signal s_DAQ_LOGIC_CLK  : std_logic;
    signal s_RST_MB         : std_logic;
    signal s_UART_RXD       : std_logic;
    signal s_UART_TXD       : std_logic;
    signal s_WIZ_ADDR_32    : std_logic_vector(31 downto 0); -- 32 bit for the AXI_EMC
    signal s_WIZ_ADDR       : std_logic_vector( 9 downto 0);
    signal s_WIZ_INT        : std_logic;
    signal s_WIZ_CS_N       : std_logic;
    signal s_WIZ_RD_N       : std_logic;
    signal s_WIZ_WR_N       : std_logic;
    signal s_WIZ_RST_N      : std_logic;
    
    signal s_WIZ_EMC_DQ_I   : std_logic_vector(15 downto 0);
    signal s_WIZ_EMC_DQ_O   : std_logic_vector(15 downto 0);
    signal s_WIZ_DQ_T		: std_logic_vector(15 downto 0);
    
    signal s_DAQ_RST_N          : std_logic;
    signal s_DAQ_MCU_ADDR_32    : std_logic_vector(31 downto 0); -- 32 bit for the AXI_EMC
    signal s_DAQ_MCU_ADDR       : std_logic_vector( 7 downto 0);
    signal s_DAQ_MCU_DIN        : std_logic_vector(31 downto 0);
    signal s_DAQ_MCU_DOUT       : std_logic_vector(31 downto 0);
    signal s_DAQ_MCU_RD_N       : std_logic;
    signal s_DAQ_MCU_WR_N       : std_logic;
    signal s_DAQ_MCU_EVENT_INT  : std_logic;
        
    signal s_DRS_ADDR       : std_logic_vector(3 downto 0);
    signal s_DRS_SRCLK      : std_logic;
    signal s_DRS_SRIN       : std_logic;
    signal s_DRS_SROUT      : std_logic;
    signal s_DRS_RSRLOAD    : std_logic;
    signal s_DRS_DENABLE    : std_logic;
    signal s_DRS_DWRITE     : std_logic;
    signal s_DRS_PLL_LCK    : std_logic;
    signal s_DRS_REF_clk    : std_logic;
    signal s_DRS_REF_CLK_GEN: std_logic;
    
    signal s_ADC_DATA       : std_logic_vector(11 downto 0);
    signal s_ADC_CLK_OUT    : std_logic;
    
    signal s_TCAL_OSC_EN    : std_logic;
    
    signal s_TRIG_IN        : std_logic;
    signal s_TIMING         : std_logic;
    
    signal s_CH0_TRIG       : std_logic;
    signal s_CH2_TRIG       : std_logic;
    signal s_CH4_TRIG       : std_logic;
    signal s_CH6_TRIG       : std_logic;
    
    signal s_DRS_RST        : std_logic;
    signal s_TRIGGER_o      : std_logic;
    signal s_FIFO_WR_EN     : std_logic;
    signal s_LED_GPIO       : std_logic_vector(1 downto 0);
	signal s_LED            : std_logic_vector(1 downto 0) := "10";
	signal s_LED_DAQ_LOGIC  : std_logic_vector(1 downto 0);
    
    signal led1_timer      : integer := 0; -- triggers led
    signal led1_on         : std_logic := '0'; -- triggers led


begin
 
    s_MB_INTR1          <= not SW0_i; -- Use the pushbutton on board to test interrupts -- <= s_LED(0);
    s_CLK_50M           <= CLK_50_i;
    s_RST_MB            <= '1'; -- disconnecting switch from reset, will use it for testing interrupts -- <= SW0_i;
     
    s_UART_RXD          <= FPGA_RXD_i;
    FPGA_TXD_o          <= s_UART_TXD;
    
    DAC_MOSI_o          <= s_DAC_SPI_MOSI;
    DAC_SCLK_o          <= s_DAC_SPI_SCLK;
    DAC_SS_N_o          <= s_DAC_SPI_SS_N;
    
    s_WIZ_ADDR			<= s_WIZ_ADDR_32(10 downto 1); -- right shift the (already left shifted - in software) address
    WIZ_ADDR_o          <= s_WIZ_ADDR(9 downto 1); 
    WIZ_CS_N_o          <= s_WIZ_CS_N;
    WIZ_RD_N_o          <= s_WIZ_RD_N;
    WIZ_WR_N_o          <= s_WIZ_WR_N;  
    s_WIZ_INT           <= not WIZ_INT_N_i;
    WIZ_RST_N_o         <= s_WIZ_RST_N;  
                 
    DRS_ADDR_o          <= s_DRS_ADDR;   
    DRS_SRCLK_o         <= s_DRS_SRCLK;  
    DRS_SRIN_o          <= s_DRS_SRIN;   
    s_DRS_SROUT         <= DRS_SROUT_i; 
    DRS_RSRLOAD_o       <= s_DRS_RSRLOAD;
    DRS_RST_N_o         <= s_DRS_RST;
    DRS_DENABLE_o       <= s_DRS_DENABLE;
    DRS_DWRITE_o        <= s_DRS_DWRITE; 
    s_DRS_PLL_LCK       <= DRS_PLL_LCK_i;
    --DRS_REFCLK_o        <= s_DRS_REF_clk;
                 
    s_ADC_DATA          <= ADC_DATA_i;
    ADC_CLK_o           <= s_ADC_CLK_OUT;
                 
    TCAL_OSC_EN_o       <= s_TCAL_OSC_EN;
    TIMING_o            <= s_TIMING;
                 
    s_TRIG_IN           <= TRIG_IN_i;
    s_CH0_TRIG          <= CH0_TRIG_i;
    s_CH2_TRIG          <= CH2_TRIG_i;
    s_CH4_TRIG          <= CH4_TRIG_i;
    s_CH6_TRIG          <= CH6_TRIG_i;
    
	s_DAQ_MCU_ADDR <= s_DAQ_MCU_ADDR_32(7 downto 0); -- right shift the (already left shifted - in software) address
    
    --s_TRIGGER_o  
    --s_FIFO_WR_EN
    
    OBUFDS_inst : OBUFDS
    port map
    (
        O => DRS_REFCLK_o_p,   -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB => DRS_REFCLK_o_m, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => s_DRS_REF_clk    -- 1-bit input: Buffer input
    );
    
    gen: for i in 0 to 15 generate
		daq_logic_emc_dq_iobuf: IOBUF
		port map
		(
			I => s_WIZ_EMC_DQ_O(i),
			IO => WIZ_DATA_io(i),
			O => s_WIZ_EMC_DQ_I(i),
			T => s_WIZ_DQ_T(i)
		);
	end generate;


-- Resolve MCU BiDirectional data signals

		-- If we are using the inout as an output, assign it an output value, 
		-- otherwise assign it high-impedence
--	<bidir_variable> <= <data> when <output_enable> = '1' else (others => 'Z');
--	WIZ_DATA_io <= s_WIZ_EMC_DQ_O when s_WIZ_WR_N = '0' else (others => 'Z');

		-- Read in the current value of the bidir port, which comes either 
		-- from the input or from the previous assignment
--	<read_buffer> <= <bidir_variable>;
--	s_WIZ_EMC_DQ_I<= WIZ_DATA_io;


    
    mb0 : mb_system
    port map
    (
    	clk_50MHz => s_CLK_50M, --: in STD_LOGIC;
		reset_rtl_0 => s_RST_MB, --: in STD_LOGIC;
		uart_rtl_0_rxd => s_UART_RXD, --: in STD_LOGIC;
		uart_rtl_0_txd => s_UART_TXD, --: out STD_LOGIC;
		dac_spi_ss_n_tri_o(0) => s_DAC_SPI_SS_N, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		dac_spi_mosi_tri_o(0) => s_DAC_SPI_MOSI, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		dac_spi_sclk_tri_o(0) => s_DAC_SPI_SCLK, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		wiz_rst_n_tri_o(0) => s_WIZ_RST_N, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		drs_rst_n_tri_o(0) => s_DRS_RST, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		led_gpio_tri_o => s_LED_GPIO, --: out STD_LOGIC_VECTOR ( 1 downto 0 );
		daq_rst_n_tri_o(0) => s_DAQ_RST_N, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		wiz_int => s_WIZ_INT, --: in STD_LOGIC;
		daq_event_int => s_DAQ_MCU_EVENT_INT, --: in STD_LOGIC;
		intr_in => s_MB_INTR1, --: in STD_LOGIC;
		daq_logic_clk => s_DAQ_LOGIC_CLK, --: out STD_LOGIC;
		adc_clk_in => s_ADC_CLK_IN, --: out STD_LOGIC;
		drs_ref_clk_gen => s_DRS_REF_CLK_GEN, --: out STD_LOGIC;
		wiz_emc_addr => s_WIZ_ADDR_32, --: out STD_LOGIC_VECTOR ( 31 downto 0 );
		--wiz_emc_adv_ldn => , --: out STD_LOGIC;
		--wiz_emc_ben => , --: out STD_LOGIC_VECTOR ( 1 downto 0 );
		--wiz_emc_ce => , --: out STD_LOGIC_VECTOR ( 0 to 0 );
		wiz_emc_ce_n(0) => s_WIZ_CS_N, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		--wiz_emc_clken => , --: out STD_LOGIC;
		--wiz_emc_cre => , --: out STD_LOGIC;
		wiz_emc_dq_i => s_WIZ_EMC_DQ_I, --: in STD_LOGIC_VECTOR ( 15 downto 0 );
		wiz_emc_dq_o => s_WIZ_EMC_DQ_O, --: out STD_LOGIC_VECTOR ( 15 downto 0 );
		wiz_emc_dq_t => s_WIZ_DQ_T, --: out STD_LOGIC_VECTOR ( 15 downto 0 );
		--wiz_emc_lbon => , --: out STD_LOGIC;
		wiz_emc_oen(0) => s_WIZ_RD_N, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		--wiz_emc_qwen => , --: out STD_LOGIC_VECTOR ( 1 downto 0 );
		--wiz_emc_rnw => , --: out STD_LOGIC;
		--wiz_emc_rpn => , --: out STD_LOGIC;
		wiz_emc_wait(0) => '0', --: in STD_LOGIC_VECTOR ( 0 to 0 );
		wiz_emc_wen => s_WIZ_WR_N, --: out STD_LOGIC;
		daq_logic_emc_addr => s_DAQ_MCU_ADDR_32, --: out STD_LOGIC_VECTOR ( 31 downto 0 );
		--daq_logic_emc_adv_ldn => , --: out STD_LOGIC;
		--daq_logic_emc_ben => , --: out STD_LOGIC_VECTOR ( 3 downto 0 );
		--daq_logic_emc_ce => , --: out STD_LOGIC_VECTOR ( 0 to 0 );
		--daq_logic_emc_ce_n => , --: out STD_LOGIC_VECTOR ( 0 to 0 );
		--daq_logic_emc_clken => , --: out STD_LOGIC;
		--daq_logic_emc_cre => , --: out STD_LOGIC;
		daq_logic_emc_dq_i => s_DAQ_MCU_DOUT, --: in STD_LOGIC_VECTOR ( 31 downto 0 );
		daq_logic_emc_dq_o => s_DAQ_MCU_DIN, --: out STD_LOGIC_VECTOR ( 31 downto 0 );
		--daq_logic_emc_dq_t => , --: out STD_LOGIC_VECTOR ( 31 downto 0 );
		--daq_logic_emc_lbon => , --: out STD_LOGIC;
		daq_logic_emc_oen(0) => s_DAQ_MCU_RD_N, --: out STD_LOGIC_VECTOR ( 0 to 0 );
		--daq_logic_emc_qwen => , --: out STD_LOGIC_VECTOR ( 3 downto 0 );
		--daq_logic_emc_rnw => , --: out STD_LOGIC;
		--daq_logic_emc_rpn => , --: out STD_LOGIC;
		daq_logic_emc_wait(0) => '0', --: in STD_LOGIC_VECTOR ( 0 to 0 );
		daq_logic_emc_wen => s_DAQ_MCU_WR_N  --: out STD_LOGIC
    );
     
   
    daq_logic0 : CMVD_DAQ_LOGIC
	port map
	(
		LCLK          => s_DAQ_LOGIC_CLK, -- in std_logic;
		nRST          => s_DAQ_RST_N, --  in std_logic;
		MCU_ADDR      => s_DAQ_MCU_ADDR, --  in std_logic_vector(7 downto 0);
		MCU_nRD       => s_DAQ_MCU_RD_N, --  in std_logic;
		MCU_nWR       => s_DAQ_MCU_WR_N, --  in std_logic;
		--MCU_DATA      => s_DAQ_MCU_DATA_io, -- inout std_logic_vector(31 downto 0);
		MCU_DATA_IN	  => s_DAQ_MCU_DIN, -- in std_logic_vector(31 downto 0);
		MCU_DATA_OUT  => s_DAQ_MCU_DOUT, -- out std_logic_vector(31 downto 0);
		MCU_EVE_INT   => s_DAQ_MCU_EVENT_INT, --  out std_logic;
		----------------------------------
		-- DRS Related ports
		----------------------------------
      
		DRS_ADDR      => s_DRS_ADDR, --  out std_logic_vector(3 downto 0);
		DRS_SRCLK     => s_DRS_SRCLK, --  out std_logic;
		DRS_SRIN      => s_DRS_SRIN, --  out std_logic;
		DRS_SROUT     => s_DRS_SROUT, --  in std_logic;
		DRS_RSRLOAD   => s_DRS_RSRLOAD, --  out std_logic;-- Read Shift Register Load Input : "pulse"
		DRS_DENABLE   => s_DRS_DENABLE, --  out std_logic;-- low-to-high transition starts the Domino Wave. 
		DRS_DWRITE    => s_DRS_DWRITE, --  out std_logic;-- Connects the Domino Wave Circuit to the Sampling Cells to enable sampling if high.
		DRS_PLL_LCK   => s_DRS_PLL_LCK, --  in std_logic;-- PLL Lock Indicator Output.
		DRS_REF_clk   => s_DRS_REF_clk, --  out std_logic;
		DRS_REF_CLK_GEN => s_DRS_REF_CLK_GEN, -- in std_logic; -- 62.5 MHz cock for the generation of drs_ref_clk of 488.28125 kHz
		----------------------------------
		-- ADC 
		----------------------------------
		ADC_DATA      => s_ADC_DATA, --  in std_logic_vector(11 downto 0);--ADC_DATA_WIDTH
		ADC_CLK_IN    => s_ADC_CLK_IN, --  in std_logic;
		ADC_CLK_OUT   => s_ADC_CLK_OUT, --  out std_logic;
		----------------------------------
		-- Other/Mislenious
		----------------------------------
		TCAL_CTRL     => s_TCAL_OSC_EN, --  out std_logic;-- Timing calibration control : crystal ON/OFF	

		----------------------------------
		-- Global services
		----------------------------------	
		TRIG_IN       => s_TRIG_IN, --  in std_logic;
		TIM	          => s_TIMING, --  out std_logic; -- Timing signal to ch 8 of DRS		

		----------------------------------
		-- local HW trigger
		----------------------------------
		AIN0_L0       => s_CH0_TRIG, --   in std_logic; -- CH0_TRIG  
		AIN1_H0       => s_CH2_TRIG, --   in std_logic; -- CH2_TRIG   
		AIN2_L1       => s_CH4_TRIG, --   in std_logic; -- CH4_TRIG   
		AIN3_H1       => s_CH6_TRIG, --   in std_logic; -- CH6_TRIG   
		
		
		DRS_RST       => s_DRS_RST, --  in std_logic;
		TRIGGER_o     => s_TRIGGER_o, --  out std_logic; -- taken out for debug (count no of pulses generated etc)  
		FIFO_WR_EN    => s_FIFO_WR_EN,  --  out std_logic  -- taken out for debug only    
		LED           => s_LED_DAQ_LOGIC --: out std_logic_vector(1 downto 0)
		
	);
	

    led_blink_process:
    process(CLK_50_i)
        variable count1 : integer range 0 to 64_000_000;
    begin
        if(CLK_50_i'event and CLK_50_i = '1' and SW0_i = '1')
        then
            count1 := count1 + 1;
            if(count1 = 5_000_000)
            then
                count1 := 0;
                s_LED(0) <= not s_LED(0);
                s_LED(1) <= not s_LED(1);
            end if;
        end if;
    end process;
    
    LED0_o <= s_LED(0);
   -- commented out -- LED1_o <= s_LED_GPIO(1) OR S_LED_DAQ_LOGIC(1); -- blink the led trhu the DAQ logic or the SW
     
   

    ----  led blink process if trigger occurs
        process(CLK_50_i)
    begin
        if rising_edge(CLK_50_i) then
            -- Check for trigger pulse
            if TRIG_IN_i = '1' then
                led1_timer <= 5_000_000; -- 100 milliseconds at 50 MHz
                led1_on <= '1';
            elsif led1_timer > 0 then
                led1_timer <= led1_timer - 1;
                if led1_timer = 1 then
                    led1_on <= '0';
                end if;
            end if;
        end if;
    end process;

    LED1_o <= led1_on;
    ----- led blink process if trigger occurs

------------- DEBUGGING OF DAQ Interface -------------------
	SPARE_o( 0) <= TRIG_IN_i;
	SPARE_o( 1) <= s_DAQ_MCU_ADDR_32(1);
	SPARE_o( 2) <= s_DAQ_MCU_ADDR_32(2);
	SPARE_o( 3) <= s_DAQ_MCU_ADDR_32(3);
	SPARE_o( 4) <= s_DAQ_MCU_ADDR_32(4);
	SPARE_o( 5) <= s_DAQ_MCU_ADDR_32(5);
	SPARE_o( 6) <= s_DAQ_MCU_ADDR_32(6);
	SPARE_o( 7) <= s_DAQ_MCU_ADDR_32(7);
	SPARE_o( 8) <= s_DAQ_MCU_ADDR_32(8);
	SPARE_o( 9) <= s_DAQ_MCU_ADDR_32(9);
	SPARE_o(10) <= s_DAQ_MCU_ADDR_32(10);
	SPARE_o(11) <= s_DAQ_MCU_RD_N;
	SPARE_o(12) <= s_DAQ_MCU_WR_N;
	SPARE_o(13) <= s_DAQ_MCU_DIN(0);
	SPARE_o(14) <= s_DAQ_MCU_DIN(1);
	SPARE_o(15) <= s_DAQ_MCU_DIN(2);
	SPARE_o(16) <= s_DAQ_MCU_DIN(3);
	SPARE_o(17) <= s_DAQ_MCU_DOUT(0);
	SPARE_o(18) <= s_DAQ_MCU_DOUT(1);
	SPARE_o(19) <= s_DAQ_MCU_DOUT(2);
	
--	SPARE_o(14) <= ;
--	SPARE_o(15) <= ;
--	SPARE_o(16) <= ;
--	SPARE_o(17) <= ;
--	SPARE_o(18) <= ;
--	SPARE_o(19) <= ;
	
	--SPARE_o(6) <= ;
	--SPARE_o(7) <= ;
	--SPARE_o(8) <= s_LED(0);


	------------------------------------------------
	-- Xilinx's way to convert bidir signal to in and out
	-- s_DAQ_MCU_DATA_io
	-- MCU_DATA_IN => s_DAQ_MCU_DIN
	-- MCU_DATA_OUT  => s_DAQ_MCU_DOUT

end Behavioral;
