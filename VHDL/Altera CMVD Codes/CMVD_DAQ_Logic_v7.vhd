---v3------------Initialization Sequence-------------------
--1. DRS RST on fpga reset
--2. CONFIG REG  				ADDR : 1100		"11111011" DMODE-'1', PLLEN-'1', WSRLOOP-'0'		
--3. WRITE SHIFT REG 		ADDR : 1101    "11111111" All eight channels 
--4. Domino wave DENABLE high and Channel write DWRITE high
---------------On Trigger--------------------------------
--5. Two Modes of Operation
      -- Calibration mode on every Calib trigger 
	  -- a. Read Shift INIT PROCESS  Stops Dwrite, ADDR : 1011 issue 1024 clks in SRCLK but SRIN high only in last clk.
	  -- b. TRIG EN Process  		 ADDR : 0000 to 1000, Channel 0 to 8, 1024 clks * 8 in SRCLK, Writes ADC data to FIFO
	  -- c. Eve Enable process       Starts Dwrite and enables event interrupt

	  -- ROI Readout Mode
	  -- a. ROI initialize by reading Stop register, Stop Dwrite
	  -- b. ROI_TRIG_ EN Process : Reads every Channel from 0 to 8 by issuing RSR load
	  -- c. Eve Enable process   : Starts Dwrite and enables event interrupt
-- Note: Comment ROI during Calibration and Viceversa
-- Note: Select ROI window in PKG file
-- Note: if ROI mode Change DRS_EVENT_SIZE to 300 in ddb.h file else:1024
--
-- 			SR_CLK Count  = 1032 ADC clks.
--			ADC CLK 33 MHz in phase with SRCLK 33 MHz but 38ns delay 
--			REF CLK 0.488281 MHz
--			FIFO CLK is 66MHz with 38ns Phase Shift


--V3.1   
-- V4.1 Changes line 588,630,635,795
-- these no longer hold good, as the code was modified and line numbers have changed in the v5
--

-- v5
-- Taken over by Mandar
-- adding a command for setting the cnt_en used to generate n number of test trigger pulses.
-- test_sig taken to the i/o port, so that it is available in the top module
-- added a constant to define the number of cells to be readout, instead of using hard-coded 
-- values at multiple locations.

-- v6
-- added wait state before staring adc_clk in the adc readout process
-- this is to acheive the correct (38 ns) delay wrt the DRS clock

-- v7
-- ROI readout corrections


library ieee;
use ieee.std_logic_1164.all;
--use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

USE work.CMVD_DAQ_PKG.all;

entity CMVD_DAQ_LOGIC is
	port
	(
		LCLK		: in std_logic;
		nRST		: in std_logic;
		MCU_ADDR	: in std_logic_vector(7 downto 0);
		MCU_nRD		: in std_logic;
		MCU_nWR		: in std_logic;
		MCU_DATA	: inout std_logic_vector(31 downto 0);
		MCU_EVE_INT	: out std_logic;
		----------------------------------
		-- DRS Related ports
		----------------------------------
      
		DRS_ADDR    : out std_logic_vector(3 downto 0);
		DRS_SRCLK   : out std_logic;
		DRS_SRIN    : out std_logic;
		DRS_SROUT   : in std_logic;

		DRS_RSRLOAD : out std_logic;-- Read Shift Register Load Input : "pulse"
		-- WSROUT   : in std_logic;--NC in DDB
		-- WSRIN    : out std_logic;--NC in DDB

		DRS_DENABLE : out std_logic;-- low-to-high transition starts the Domino Wave. 
		DRS_DWRITE  : out std_logic;-- Connects the Domino Wave Circuit to the Sampling Cells to enable sampling if high.
		DRS_PLL_LCK : in std_logic;-- PLL Lock Indicator Output.
		DRS_REF_clk : in std_logic;
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
		--TRIG_OUT 	: out std_logic;	
		TIM	     	: out std_logic; -- Timing signal to ch 8 of DRS		

		----------------------------------
		-- local HW trigger
		----------------------------------
		AIN0_L0		:  in std_logic;
		AIN1_H0		:  in std_logic;
		AIN2_L1		:  in std_logic;
		AIN3_H1		:  in std_logic;
		AIN4_L2		:  in std_logic;
		--AIN5_H2	:  in std_logic;
		AIN6_L3		:  in std_logic;
		--AIN7_H3	:  in std_logic;
		TEMP_MISO   :	out std_logic;
		TEMP_MOSI   :	in std_logic;
		TEMP_SIO    :	inout std_logic;
		TEMP_SIO_DIR: in std_logic;
		DRS_RST		: in std_logic;
		TRIGGER_o	: out std_logic; -- taken out for debug (count no of pulses generated etc)
		FIFO_WR_EN	: out std_logic -- taken out for debug only
		----------------------------------
		-- Spare : SPI_CONJ10) / J10.1(FPGA_PIN132) used for trig_in
		----------------------------------
		--SPARE : out std_logic_vector(2 downto 0) -- SP_CLK, SP_MOSI, SP_MISO
	);
end CMVD_DAQ_LOGIC;

architecture behav of CMVD_DAQ_LOGIC is


component monoshot
	port
	(
		width_in	: in std_logic_vector(11 downto 0);
		trig_in		: in std_logic;
		clk_in		: in std_logic;
		rst_in		: in std_logic;
		output		: out std_logic
	);
end component;




component sync_monoshot
	--generic (width_gen : std_logic_vector(11 downto 0) := X"240"); -- default is 7
	port
	(
		width_in	: in std_logic_vector(15 downto 0);
		trig_in		: in std_logic;
		clk_in		: in std_logic;
		rst_in		: in std_logic;
		output		: out std_logic
	);
end component;

component monoshot_100ns     --For Pretrigger strecthing
	port
	(
		trig_in		: in std_logic;
		clk_in		: in std_logic;
		rst_in		: in std_logic;
		output		: out std_logic
	);
end component;

--fifo  
---------------------------------------------------------------------------
component fifo2
	PORT
	(
		Clk          : in std_logic;
		nReset	 	 : in std_logic;
		WriteEnable  : in std_logic;
		ReadEnable   : in std_logic;
		DataIn       : in std_logic_vector(15 downto 0);
		DataOut      : out std_logic_vector(15 downto 0);
		FifoEmpty    : out std_logic;
		FifoFull     : out std_logic;
		-- P_wptr       : out std_logic_vector(ADDR_width-1 downto 0);
		-- F_wptr       : in std_logic_vector(ADDR_width-1 downto 0);
		-- wptr_cflag : in std_logic;
		FreeSpace	 : out std_logic_vector(ADDR_width downto 0)
	);
end component;



-- RAM
component cell_ram_part
	port
	(
		clock         : IN   std_logic;
		data          : IN   std_logic_vector (15 DOWNTO 0);
		write_address : IN   integer RANGE 0 to DRS_CELL_OFFSET_depth-1;
		read_address  : IN   integer RANGE 0 to DRS_CELL_OFFSET_depth-1;
		we            : IN   std_logic;
		re            : IN   std_logic;                          ---  read enable 
		q             : OUT  std_logic_vector (15 DOWNTO 0)
	);
end component;


signal TRIG_INs			: std_logic;
signal TRIGs			: std_logic;
signal CLR_TRIG_VETOs	: std_logic;
signal TMPs				: std_logic;
signal CLR_TRIG_VETO_DLYDs	: std_logic;
--signal TRIG_COUNTs		: std_logic_vector(31 downto 0);
--signal EVE0				: std_logic_vector(31 downto 0);
--signal EVE1				: std_logic_vector(31 downto 0);
--signal EVE2				: std_logic_vector(31 downto 0);
--signal EVE3				: std_logic_vector(31 downto 0);
--signal EVE4				: std_logic_vector(31 downto 0);
--signal EVE5				: std_logic_vector(31 downto 0);
--signal EVE6				: std_logic_vector(31 downto 0);
--signal EVE7				: std_logic_vector(31 downto 0);
--signal EVE8				: std_logic_vector(31 downto 0);
--signal EVE9				: std_logic_vector(31 downto 0);
signal MCU_DINs			: std_logic_vector(31 downto 0);
signal MCU_DOUTs		: std_logic_vector(31 downto 0);
signal EVE_INT			: std_logic;

--pulser
signal test_sig			: std_logic;
signal cnt_en			: std_logic;
signal eve_freqs		: std_logic_vector(31 downto 0);
signal eve_cnts			: std_logic_vector(31 downto 0);
signal SINGLE_CAL_TRIG	: std_logic;
--signal cnt : integer range 0 to 10000;


-- DRS Readout
signal CLEARs			: std_logic;
signal CONFIG_DRSs		: std_logic;
signal CONFIG_DRS		: std_logic;
signal TRIG_ENs			: std_logic;
signal TRIG_EN			: std_logic;
signal ROI_TRIG_ENs		: std_logic;
signal ROI_TRIG_EN		: std_logic;
signal EVE_ENABLEs		: std_logic;
signal EVE_ENABLE		: std_logic;
signal CLK_ENs			: std_logic;
signal ADC_CLK_ENs		: std_logic;
signal ADC_CLK_EN		: std_logic;
signal READ_SHIFT_ENs	: std_logic;
signal READ_SHIFT_EN	: std_logic;
signal ROI_ENs			: std_logic;
signal ROI_EN			: std_logic;
signal DRS_INIT_ENs		: std_logic;
signal DRS_READ_ENs		: std_logic;

--signal TSAMP 			: integer RANGE 0 to 15000;
--signal READ_INIT_CYCLE: integer RANGE 0 to 15000;
signal START_CNT 		: integer RANGE 0 to 1023;
signal BASE_CNT 		: integer RANGE 0 to 100;
signal THRES_VAR		: integer RANGE 0 to 15000;
signal VALID_PULSE_CNT 	: integer RANGE 0 to 1000;

--signal READ_CNT 		: integer RANGE 0 to 15000;
--signal CH0_READ_CNT 	: integer RANGE 0 to 15000;
--signal CH1_READ_CNT 	: integer RANGE 0 to 15000;
--signal CH2_READ_CNT 	: integer RANGE 0 to 15000;
--signal CH3_READ_CNT 	: integer RANGE 0 to 15000;
--signal CH4_READ_CNT 	: integer RANGE 0 to 15000;
--signal CH5_READ_CNT 	: integer RANGE 0 to 15000;
--signal CH6_READ_CNT 	: integer RANGE 0 to 15000;
--signal CH7_READ_CNT 	: integer RANGE 0 to 15000;
--signal CH8_READ_CNT 	: integer RANGE 0 to 15000;
--signal EVE_READ_CNT 	: integer RANGE 0 to 15000;
--signal STOP_CNT 		: integer RANGE 0 to 15000;
--signal READOUT_TOTAL_CNT 			: integer RANGE 0 to 15000;
signal START_CNTs		: integer RANGE 0 to 1023;
signal BASE_CNTs		: integer RANGE 0 to 100;
signal THRES_VARS		: integer RANGE 0 to 15000;
signal VALID_PULSE_CNTs	: integer RANGE 0 to 1000;

--signal READ_CNTs		: integer RANGE 0 to 15000;
--signal READ_INIT_CYCLEs	: integer RANGE 0 to 15000;

signal ADC_SAMPLE_SIZE		: integer RANGE 0 to 2000;

--signal READ_status	: std_logic;
signal CONFIG_REGs		: std_logic_vector(7 downto 0);
signal WRSHIFT_REGs		: std_logic_vector(7 downto 0);
signal CONFIG_REGss		: std_logic_vector(7 downto 0);
signal WRSHIFT_REGss	: std_logic_vector(7 downto 0);
signal CONFIG_REG		: std_logic_vector(7 downto 0);
signal WRSHIFT_REG		: std_logic_vector(7 downto 0);
signal WRCONFIG_REG		: std_logic_vector(7 downto 0);
signal STOP_REGs		: std_logic_vector(9 downto 0);
signal ADC_DATAS		: std_logic_vector(11 downto 0);
signal DRS_CH_ADDR		: std_logic_vector(3 downto 0);
signal DRS_CH_ADDRs		: std_logic_vector(3 downto 0);
signal TCAL_CTRLS		: std_logic;
signal TRIGGER			: std_logic;
signal CAL_ENABLEs		: std_logic;
signal CAL_ENABLE		: std_logic;
signal CAL_SINGLE_EN	: std_logic := '0';
signal PULSE_ENABLEs	: std_logic;
signal PULSE_ENABLE		: std_logic;
signal EVENT_VALID		: std_logic;



----- FIFO 
signal FIFO_WEs			: std_logic;
signal FIFO_REs			: std_logic;
signal FIFO_DATAINs		: std_logic_vector(31 downto 0);
signal FIFO_DATAIN_16s	: std_logic_vector(15 downto 0);
signal FIFO_DATAOUTs	: std_logic_vector(15 downto 0);
signal FIFOEMPTYs		: std_logic;
signal FIFOFULLs		: std_logic;
signal FREESPACEs 		: std_logic_vector(ADDR_width downto 0);
signal FIFO_Rden_sync	: std_logic;
signal FIFO_Wren_sync	: std_logic;
signal FIFO_PWPTRs		: std_logic_vector(ADDR_width-1 downto 0);
signal FIFO_FWPTRs		: std_logic_vector(ADDR_width-1 downto 0);
signal FIFO_wptr_cflag	: std_logic;

-- RAM
signal 	ram_data_in		: std_logic_vector(15 downto 0);
signal 	ram_data_ins	: std_logic_vector(15 downto 0);
signal 	ram_WEs			: std_logic := '1';
signal 	ram_REs			: std_logic := '1';
signal  w_addr 			: integer RANGE 0 to DRS_CELL_OFFSET_depth-1;
signal  r_addr 		   	: integer RANGE 0 to DRS_CELL_OFFSET_depth-1;
signal  ram_data_out	: std_logic_vector(15 downto 0);
signal  start_cell_addr	: integer RANGE 0 to DRS_CELL_OFFSET_depth;
signal  last_cell_addr 	: integer RANGE 0 to DRS_CELL_OFFSET_depth;
signal  first_cell_addr	: integer RANGE 0 to DRS_CELL_OFFSET_depth;


--signal 	test_data	: std_logic_vector(31 downto 0);

-- Zero Suppression

signal base_line    	: signed(15 downto 0);
signal threshold    	: signed(15 downto 0);
signal peak_sense_cnt   : std_logic_vector(31 downto 0);
--signal base_line1    	: signed(31 downto 0);
--signal base_line2    	: signed(31 downto 0);
--signal base_line3    	: signed(31 downto 0);
--signal base_line4    	: signed(31 downto 0);
--signal base_line5    	: signed(31 downto 0);
--signal base_line6    	: signed(31 downto 0);
--signal base_line7    	: signed(31 downto 0);
--signal base_line8    	: signed(31 downto 0);


-- state of DRS readout state machine
type type_drs_readout_state is (init, conf_setup, conf_strobe, wsr_addr, wsr_setup, wsr_strobe,
				wcr_addr, wcr_setup, wcr_strobe, wait_vdd, roi_ch_read_init, roi_ch_read,
				roi_read_init, cal_read_init, wait_dummy1, wait_dummy2, wait_dummy3, ch_read_init,
				wait_after_read_init, ch_read, wait_after_ch_read, eve_gen, wait_after_ch_read_init);
signal drs_readout_state  	: type_drs_readout_state;

type type_adc_readout_state is (init, adc_roi_read, adc_cal_read, wait_state, wait_state2, wait_state3, wait_state4);
signal adc_readout_state	: type_adc_readout_state;


signal DRS_SRCLK_s		: std_logic;
signal DRS_SRINs		: std_logic;
signal ADC_CLK_s		: std_logic;
signal ADC_CLK			: std_logic;
signal CH_ADDRs			: std_logic_vector(3 downto 0);
signal drs_sr_reg		: std_logic_vector(7 downto 0);
subtype type_sr_count is integer range 0 to 1024;
signal drs_sr_count    	: type_sr_count;

signal SET_CNT_ENs		: std_logic := '0';


signal DRS_CELL : integer := 1024; -- Prajj: Originally was 1024
signal DRS_ROI  : integer := 300;
signal ADC_DLAY : integer := 9;

signal slv_DRS_CELL : std_logic_vector(10 downto 0); -- 
signal slv_DRS_ROI  : std_logic_vector(10 downto 0);
signal slv_ADC_DLAY : std_logic_vector(4 downto 0);


--constant DRS_CELL : integer := 10; -- Prajj: Originally was 1024
--constant DRS_ROI  : integer := 300;
--constant ADC_DLAY : integer := 9;

begin

	TRIGGER_o <= TRIGGER; -- send the test_sig outside this entity
	FIFO_WR_EN <= FIFO_WEs;
 

TIM <= TRIG_IN; -- MNS: Uncommented. Let the trigger in flow to the drs channel 8 unconditionally.
--DRS_SRCLK <= READ_CLK;
--ADC_CLK_OUT <= ADC_CLK_IN;
-----------------------------------------------
-- Temperature sensor SIO signal resolution
-----------------------------------------------
TEMP_SIO  <= TEMP_MOSI when TEMP_SIO_DIR = '0' else 'Z';
TEMP_MISO <= TEMP_SIO;




TCAL_CTRL <= TCAL_CTRLS;




----------------------
process(LCLK,nRST,CAL_ENABLE)
	variable count2 : std_logic_vector(31 downto 0);
	variable count1 : std_logic_vector(31 downto 0);
begin
	if(nRST = '0')
	then
		count2 := (others => '0');
		count1 := (others => '0');
		test_sig <='0';
		cnt_en <= '1';
		
	elsif(LCLK'event and LCLK = '1')
	then
	
		if(SET_CNT_ENs = '1') then
			cnt_en <= '1';
		end if;
		
		if(SET_CNT_ENs = '0') then
			cnt_en <= '0';
		end if;
		
		if(CAL_ENABLE = '1' and cnt_en = '1')then
			if(count2 < eve_freqs + 2)
			then
				count2 := count2 + '1';
			end if;
	
			-- generate signal  pulse			
			if(count2 = 1)
			then
				test_sig <= '1';
			end if;
			
			if(count2 = 15)
			then
				test_sig <= '0';
			end if;

			
			if(count2 = eve_freqs)
			then
				count1 := count1 + '1';
				count2 := (others => '0');
				test_sig <= '0';
			end if;
		
			if(count1 >= eve_cnts)
			then
				count1 := (others => '0');
				test_sig <= '0';
				cnt_en <= '0';
			end if;
		else
			test_sig <='0';
		end if;
	end if;
end process;



--------------------------------------------------------------------------
DRS_SRCLK 	<= DRS_SRCLK_s;
ADC_CLK_OUT	<= ADC_CLK;
DRS_SRIN <= DRS_SRINs;



process(LCLK,nRST,TRIGGER,CONFIG_DRS,DRS_RST)
	variable count1 : std_logic_vector(31 downto 0) := X"00000000";
	variable drs_sample_count : std_logic_vector(31 downto 0) := X"00000000";
	variable drs_rd_tmp_count : std_logic_vector(31 downto 0) := X"00000000";
	variable adc_sample_count : std_logic_vector(31 downto 0) := X"00000000";
	variable count6 : std_logic_vector(31 downto 0) := X"00000000";
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		count1 				:= (others => '0');
		drs_sample_count 	:= (others => '0');
		drs_rd_tmp_count 	:= (others => '0');
		adc_sample_count 	:= (others => '0');
		drs_sr_count		<= 0;
		count6 				:= (others => '0');
		DRS_RSRLOAD			<= '0';
		DRS_DENABLE 		<= '0';
		DRS_DWRITE			<= '0';
		DRS_SRINs 			<= '0';
		DRS_ADDR   	 		<= "0000";
		ADC_CLK_ENs			<= '0';
		EVE_INT 				<= '0';
		DRS_SRCLK_s			<= '0';
		drs_readout_state <= init;
		ADC_CLK_s 			<= '0';
		CONFIG_REG  <= "11111111";
		WRSHIFT_REG <= "11111111";
		WRCONFIG_REG <= "11111111";
	elsif rising_edge(LCLK) then		
		
		case (drs_readout_state) is

			when init =>
				if(TRIGGER = '1' and CONFIG_DRS = '0')then
					--DRS_DENABLE <= '0';
					DRS_SRCLK_s	<= '0';
					ADC_CLK_ENs	<= '0';
					DRS_SRINs	<= '0';
					DRS_RSRLOAD	<= '0';
					ADC_CLK_s   <= '0';
					if(CAL_ENABLE = '1')then
						DRS_DWRITE  <= '0';
						DRS_ADDR		<= "1011";
						drs_readout_state   <= wait_vdd; --wait_vdd; --cal_Read_init;
					end if;
					
					if(PULSE_ENABLE = '1')then
						DRS_ADDR		<= "0000";
						drs_readout_state   <= roi_read_init; --wait_vdd; --roi_Read_init;
					end if;
					
					drs_sample_count 	:= (others => '0'); --
					drs_rd_tmp_count 	:= (others => '0'); --
					adc_sample_count 	:= (others => '0'); --
				elsif(TRIGGER = '0' and CONFIG_DRS = '0')then
					drs_readout_state   <= init;
					--DRS_DWRITE  <= '1';
					--DRS_DENABLE <= '1';
					DRS_ADDR	<= "0000";
					CH_ADDRs <= "0000";
					DRS_SRCLK_s <= '0';
					DRS_SRINs	<= '0';
					DRS_RSRLOAD	<= '0';
					ADC_CLK_s   <= '0';
					drs_sample_count 	:= (others => '0');
					drs_rd_tmp_count 	:= (others => '0');
					adc_sample_count 	:= (others => '0');
					drs_sr_count		<= 0; 
					ADC_CLK_ENs 		<= '0';				
				elsif(TRIGGER = '0' and CONFIG_DRS = '1')then
					DRS_ADDR	<= "1100";
					CONFIG_REG  <= "11111111";
					WRSHIFT_REG <= "11111111";
					WRCONFIG_REG <= "11111111";
					drs_readout_state   <= conf_setup;
				end if;
				
				
       -- set-up of configuration register        
			when conf_setup =>
				DRS_SRCLK_s          <= '1';
				drs_sr_count         <= 0;
				drs_sr_reg           <= CONFIG_REG;
				drs_readout_state    <= conf_strobe;
				DRS_SRINs           	 <= CONFIG_REG(7);
        
			when conf_strobe =>  
				drs_sr_count         <= drs_sr_count + 1;
				DRS_SRCLK_s          <= not DRS_SRCLK_s;

				if (DRS_SRCLK_s = '1') then
					drs_sr_reg(7 downto 1) <= drs_sr_reg(6 downto 0);
				else
					DRS_SRINs        <= drs_sr_reg(7);
				end if;
          
				if (drs_sr_count = 14) then
					drs_readout_state <= wsr_addr; --wait_dummy1;
				end if;
			 
			when wait_dummy1 =>
				drs_rd_tmp_count := drs_rd_tmp_count + 1;
				
				if(drs_rd_tmp_count = 2)then     
					drs_rd_tmp_count 	:= (others => '0');
					drs_readout_state  <= wsr_addr;
				else
					drs_readout_state  <= wait_dummy1;
				end if;		
			
          
        -- change address without changing clock  
			when wsr_addr =>
				DRS_ADDR           <= "1101";  -- address write shift register
				drs_readout_state    <= wsr_setup;

        -- set-up of write shift register
			when wsr_setup =>
				DRS_SRCLK_s          <= '1';
				drs_sr_count       	 <= 0;
				drs_sr_reg           <= WRSHIFT_REG;
				drs_readout_state    <= wsr_strobe;
				DRS_SRINs            <= WRSHIFT_REG(7);
        
			when wsr_strobe =>  
				drs_sr_count         <= drs_sr_count + 1;
				DRS_SRCLK_s          <= not DRS_SRCLK_s;

				if (DRS_SRCLK_s = '1') then
					drs_sr_reg(7 downto 1) <= drs_sr_reg(6 downto 0);
				else
					DRS_SRINs        <= drs_sr_reg(7);
				end if;
          
				if (drs_sr_count = 14) then
					drs_readout_state <= wcr_addr;--wait_dummy2;
				end if;
			 
			when wait_dummy2 =>
				drs_rd_tmp_count := drs_rd_tmp_count + 1;
				
				if(drs_rd_tmp_count = 2)then     
					drs_rd_tmp_count 	:= (others => '0');
					drs_readout_state  <= wcr_addr;
				else
					drs_readout_state  <= wait_dummy2;
				end if;		
				

	        -- change address without changing clock  
			when wcr_addr =>
				DRS_ADDR           <= "1110";  -- address write config register
				drs_readout_state    <= wcr_setup;

        -- set-up of write config register
			when wcr_setup =>
				DRS_SRCLK_s          <= '1';
				drs_sr_count       	 <= 0;
				drs_sr_reg           <= WRCONFIG_REG;
				drs_readout_state    <= wcr_strobe;
				DRS_SRINs            <= WRCONFIG_REG(7);
        
			when wcr_strobe =>  
				drs_sr_count         <= drs_sr_count + 1;
				DRS_SRCLK_s          <= not DRS_SRCLK_s;

			if (DRS_SRCLK_s = '1') then
				drs_sr_reg(7 downto 1) <= drs_sr_reg(6 downto 0);
			else
				DRS_SRINs        <= drs_sr_reg(7);
			end if;
          
			if (drs_sr_count = 14) then
				drs_readout_state <= init; --wait_dummy3;  
				DRS_SRCLK_s   <= '0';
				DRS_DENABLE 	<= '1';
				DRS_DWRITE  	<= '1';
			end if;	
				
			when wait_dummy3 =>
				drs_rd_tmp_count := drs_rd_tmp_count + 1;
				
				if(drs_rd_tmp_count = 2)then     
					drs_rd_tmp_count 	:= (others => '0');
					drs_readout_state  <= init;
				else
					drs_readout_state  <= wait_dummy3;
				end if;				
				
				
			when wait_vdd =>
				drs_rd_tmp_count := drs_rd_tmp_count + 1;
				
				if(drs_rd_tmp_count = 100)then     --1.5us wait
					drs_rd_tmp_count 	:= (others => '0');
					drs_readout_state  <= cal_Read_init;
				else
					drs_readout_state  <= wait_vdd;
				end if;
				
				
			when cal_Read_init =>
				if(DRS_SRCLK_s = '1') then
					drs_sample_count   := drs_sample_count + 1;
				end if; 

				DRS_SRCLK_s <= not DRS_SRCLK_s;

				if(drs_sample_count = 1024 and DRS_SRCLK_s = '1') then --1024
					DRS_SRINs    <= '1';
				end if;
				
				if(drs_sample_count = 1024 and DRS_SRCLK_s = '0') then
					--DRS_SRINs         	 <= '0';
					drs_readout_state  <= ch_read_init; --wait_after_read_init; --ch_read_init;
					DRS_SRCLK_s        <= '0';
					CH_ADDRs    	   <= DRS_CH_ADDR; --"0000";
					drs_sample_count 	:= (others => '0');
					adc_sample_count 	:= (others => '0');
					drs_rd_tmp_count 	:= (others => '0');
				end if;
				 
				 
			when wait_after_read_init =>
				drs_rd_tmp_count := drs_rd_tmp_count + 1;
				DRS_SRINs         	 <= '0';
				if(drs_rd_tmp_count = 2)then     --30ns wait
					--DRS_SRINs	<= '0';
					drs_rd_tmp_count 	:= (others => '0');
					drs_readout_state  <= ch_read_init;
				else
					drs_readout_state  <= wait_after_read_init;
				end if;
				
				
				 
			when ch_read_init =>
				if(CH_ADDRs = "1001")then
					drs_readout_state <= eve_gen;
				else
					DRS_SRINs	<= '0';
					DRS_SRCLK_s <= '0';
					ADC_CLK_s	<= '0';
					ADC_CLK_ENs <= '0';
					DRS_ADDR	<= CH_ADDRs;
					drs_readout_state  <= wait_after_ch_read_init;
					--ADC_CLK_ENs <= '1';
				end if;
				
			-- MNS: add a wait state to get 15 ns more (total 30ns) between ADRESS set to DRS Clock
			-- refer page 12 of DRS datasheet
			when wait_after_ch_read_init =>
				drs_readout_state  <= ch_read;
				ADC_CLK_ENs <= '1';
  
  
			when ch_read =>
				if(DRS_SRCLK_s = '1') then
					drs_sample_count   := drs_sample_count + 1;
				end if; 

				if(ADC_CLK_s = '1') then
					adc_sample_count   := adc_sample_count + 1;
				end if; 
			 
				DRS_SRCLK_s <= not DRS_SRCLK_s;
				ADC_CLK_s <= not ADC_CLK_s;
			 
			
				if(drs_sample_count > (DRS_CELL - 1)) then -- 1024
					DRS_SRCLK_s   <= '0';
				end if;
			
			
				if(adc_sample_count = (DRS_CELL + ADC_DLAY - 1) and ADC_CLK_s = '0') then --1030
					drs_readout_state <= eve_gen; -- ch_read_init--wait_after_ch_read;
					drs_sample_count 	:= (others => '0');
					adc_sample_count 	:= (others => '0');
					drs_rd_tmp_count 	:= (others => '0');
					DRS_SRCLK_s 		<= '0';
					ADC_CLK_s 			<= '0';
					ADC_CLK_ENs 		<= '0';
					--CH_ADDRs				<= CH_ADDRs + "0001";
					DRS_SRINs	<= '0';
				end if;

			when wait_after_ch_read =>
				drs_rd_tmp_count := drs_rd_tmp_count + 1;
				if(drs_rd_tmp_count = 2)then     --30ns wait
					--DRS_SRINs	<= '0';
					drs_rd_tmp_count 	:= (others => '0');
					drs_readout_state  <= eve_gen;
				else
					drs_readout_state  <= wait_after_ch_read;
				end if;
							 
			 
			when roi_read_init =>
				ADC_CLK_s <= not ADC_CLK_s;  
				if(ADC_CLK_s = '1') then
					adc_sample_count   := adc_sample_count + 1;
				end if; 
				
--				if(adc_sample_count < START_CNT)then  
--					DRS_SRCLK_s  <= not DRS_SRCLK_s;
--				end if; 
				
--				if(DRS_SRCLK_s = '1') then
--					drs_sample_count   := drs_sample_count + 1;
--				end if; 

				if(adc_sample_count = START_CNT)then  --ROI Latency must be programmable
					DRS_DWRITE  <= '0';
					drs_readout_state <= roi_ch_read_init;
				end if; 

--				if(adc_sample_count = START_CNT+1)then   
--					DRS_RSRLOAD  <= '1';
--				end if; 
--
--				if(adc_sample_count = START_CNT+2)then  
--					DRS_RSRLOAD <= '0';
--					DRS_ADDR	<= CH_ADDRs;
--				end if;
--				
--				if(adc_sample_count > (START_CNT+2))then  
--					DRS_SRCLK_s  <= not DRS_SRCLK_s;
--				end if; 
--				
--				if(DRS_SRCLK_s = '1') then
--					drs_sample_count   := drs_sample_count + 1;
--				end if; 
 
--				if(adc_sample_count > (START_CNT+2) and adc_sample_count < (START_CNT+13)) then
--					if(DRS_SRCLK_s = '1') then
--					  --STOP_REGs(0) <= DRS_SROUT;
--					  STOP_REGs(9 downto 1) <= STOP_REGs(8 downto 0);
--					  STOP_REGs(0) <= DRS_SROUT;
--					end if;
--				end if;
--				
--				if(adc_sample_count = (START_CNT+3)) then
--					ADC_CLK_ENs <= '1';
--				end if;
--				
--				if(drs_sample_count > DRS_ROI) then -- 300
--					DRS_SRCLK_s   <= '0';
--				end if;
--				
--				if(adc_sample_count = (DRS_ROI + ADC_DLAY - 1) and ADC_CLK_s = '0') then --303
--					drs_readout_state <= eve_gen; -- ch_read_init--wait_after_ch_read;
--					drs_sample_count 	:= (others => '0');
--					adc_sample_count 	:= (others => '0');
--					drs_rd_tmp_count 	:= (others => '0');
--					DRS_SRCLK_s 		<= '0';
--					ADC_CLK_s 			<= '0';
--					ADC_CLK_ENs 		<= '0';
--					--CH_ADDRs				<= CH_ADDRs + "0001";
--					DRS_SRINs	<= '0';
--				end if;
				
--
--				if(adc_sample_count = (START_CNT+13))then         --32
--					DRS_SRINs         	 <= '0';
--					drs_readout_state  <= roi_ch_read_init; 
--					DRS_SRCLK_s        <= '0';
--					CH_ADDRs    		 <= DRS_CH_ADDR; --"0000";
--					DRS_RSRLOAD  		 <= '0';
--					ADC_CLK_s 			 <= '0';
--					drs_sample_count 	:= (others => '0');
--					adc_sample_count 	:= (others => '0');
--					drs_rd_tmp_count 	:= (others => '0');
--				end if; 

			when roi_ch_read_init =>
				if(CH_ADDRs = "1001")then
					drs_readout_state <= eve_gen;
				else
					DRS_SRINs	<= '0';
					DRS_SRCLK_s <= '0';
					ADC_CLK_s	<= '0';
					ADC_CLK_ENs <= '0';
					DRS_RSRLOAD <= '0';
					drs_sample_count := (others => '0');
					adc_sample_count := (others => '0');
					DRS_ADDR		<= CH_ADDRs;
					drs_readout_state  <= roi_ch_read;
				end if;


			when roi_ch_read =>
				ADC_CLK_s <= not ADC_CLK_s;
				if(DRS_SRCLK_s = '1') then
					drs_sample_count   := drs_sample_count + 1;
				end if; 

				if(ADC_CLK_s = '1') then
					adc_sample_count   := adc_sample_count + 1;
				end if;
			
				if(adc_sample_count > 2 and adc_sample_count < 13) then
					if(DRS_SRCLK_s = '1') then
					  --STOP_REGs(0) <= DRS_SROUT;
					  STOP_REGs(9 downto 1) <= STOP_REGs(8 downto 0);
					  STOP_REGs(0) <= DRS_SROUT;
					end if;
				end if;	

				if(adc_sample_count > 2 and adc_sample_count < DRS_ROI + 3) then -- Prajj: originally was 303
					DRS_SRCLK_s <= not DRS_SRCLK_s;
				end if;


				if(adc_sample_count = 1) then	
					DRS_RSRLOAD   <= '1';
				end if;	

				if(adc_sample_count = 2) then 
					DRS_RSRLOAD   <= '0';
				end if;
				
				if(adc_sample_count = 3) then 
					ADC_CLK_ENs <= '1';
				end if;

				if(drs_sample_count > DRS_ROI) then -- 300
					DRS_SRCLK_s   <= '0';
				end if;


				if(adc_sample_count = (DRS_ROI + ADC_DLAY - 1) and ADC_CLK_s = '0') then --303 -- DRS_ROI + ADC_DLAY
					drs_readout_state <= eve_gen; --wait_after_ch_read; --roi_ch_read_init
					drs_sample_count 	:= (others => '0');
					adc_sample_count 	:= (others => '0');
					drs_rd_tmp_count 	:= (others => '0');
					DRS_SRCLK_s 		<= '0';
					ADC_CLK_s 			<= '0';
					ADC_CLK_ENs 		<= '0';
					--CH_ADDRs				<= CH_ADDRs + "0001";
					DRS_SRINs	<= '0';
				end if;


			when eve_gen =>
				if(drs_rd_tmp_count(drs_rd_tmp_count'high) = '0') then
					drs_rd_tmp_count   := drs_rd_tmp_count + 1;
				end if;

				if(drs_rd_tmp_count = 2)then
					EVE_INT	<= not SINGLE_CAL_TRIG; -- MNS: defalult '1'; temporarily disabled for calibration yesting
				end if;
					
				if(drs_rd_tmp_count = ADC_DLAY)then -- Prajj: Originally was 7
					EVE_INT	<= '0';
				end if;				

				if(drs_rd_tmp_count = ADC_DLAY + 2)then -- Prajj: Originally was 9
					drs_readout_state    <= init;
					DRS_DWRITE  <= '1';
					--DRS_DENABLE <= '1';
				end if;

			when others =>
				drs_readout_state    <= init;

		end case;
	end if;
end process;




--FIFO_wr_signal: process(LCLK,ADC_CLK_ENs,DRS_RST,nRST)
--	variable count1 		 : std_logic_vector(3 downto 0) := "0000";
--	variable count2 		 : std_logic_vector(15 downto 0) := X"0000";
--	variable accum_var    : signed(31 downto 0);
----	variable base_line    : signed(31 downto 0);
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		r_addr <= 0;
--		FIFO_WEs <= '1';
--		FIFO_DATAIN_16s  <= (others => '0');
--		accum_var  := (others => '0');
--		base_line0 <= (others => '0');
--		base_line1 <= (others => '0');
--		base_line2 <= (others => '0');
--		base_line3 <= (others => '0');
--		base_line4 <= (others => '0');
--		base_line5 <= (others => '0');
--		base_line6 <= (others => '0');
--		base_line7 <= (others => '0');
--		base_line8 <= (others => '0');
--		count1 := (others => '0');
--		count2 := (others => '0');
--	elsif(LCLK'event and LCLK = '1') then
--		
--		if(ADC_CLK_ENs = '1') then
--			if(count1 < 8) then
--				count1 := count1 + '1';
--			end if;
--			
--			if(r_addr = last_cell_addr)then
--				r_addr <= first_cell_addr;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0000") then
--				base_line0 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0001") then
--				base_line1 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0010") then
--				base_line2 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0011") then
--				base_line3 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0100") then
--				base_line4 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0101") then
--				base_line5 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0110") then
--				base_line6 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0111") then
--				base_line7 <= accum_var/64;
--			end if;
--
--			if(count2 = 64 and DRS_CH_ADDRs = "1000") then
--				base_line8 <= accum_var/64;
--			end if;
--
--			
--			if(count1 = 4) then
--				FIFO_WEs <= '0'; -- active low signal
--				count1 := (others => '0');
--			end if;
--			
--			if(count1 = 1) then
--				FIFO_WEs <= '1';
--				if(PULSE_ENABLE = '1')then
--					FIFO_DATAIN_16s <= ADC_DATA - ram_data_out;
--				else
--					FIFO_DATAIN_16s <= "00" & ADC_DATA;
--				end if;
--
--				if(count2 < 65) then
--					accum_var := signed(ADC_DATA) + accum_var;
--					count2 := count2 + '1';
--				end if;
--				r_addr <= r_addr + 1;
--			end if;
--			
--			
--			if(count1 = 2) then
--				FIFO_WEs <= '0'; -- active low signal
--			end if;
--			
--			
--			if(count1 = 3) then
--				FIFO_WEs <= '1';
--				
--				if(PULSE_ENABLE = '1')then
--					FIFO_DATAIN_16s <= ADC_DATA - ram_data_out;
--				else
--					FIFO_DATAIN_16s <= "00" & ADC_DATA;
--				end if;
--				
--				if(count2 < 65) then
--					accum_var := signed(ADC_DATA) + accum_var;
--					count2 := count2 + '1';
--				end if;
--				r_addr <= r_addr + 1;
--				--FIFO_DATAIN_16s <= "00" & ADC_DATA;
--				--FIFO_WEs <= '1';
--			end if;
--			
--		else
--			FIFO_WEs <= '1';
--			count1 := (others => '0');
--			count2 := (others => '0');
--			accum_var  := (others => '0');
--			r_addr <= start_cell_addr;
--		end if;
--	end if;
--end process;

start_cell_addr <= Conv_Integer(STOP_REGs) + Conv_Integer(DRS_CH_ADDR) * DRS_CELL;
last_cell_addr 	<= Conv_Integer(DRS_CH_ADDR + "0001") * DRS_CELL;
first_cell_addr <= Conv_Integer(DRS_CH_ADDR) * DRS_CELL;


ADC_READOUT : process(ADC_CLK_IN,ADC_CLK_ENs,DRS_RST,nRST)
	variable adc_sample_count 		: std_logic_vector(31 downto 0) := X"00000000";
	variable prev_adc_sample_cnt 	: std_logic_vector(31 downto 0) := X"00000000";
	variable accum_var    			: signed(15 downto 0);
	variable count2 				: std_logic_vector(15 downto 0) := X"0000";
	variable pulse_val    			: signed(15 downto 0);

begin
	if(nRST = '0' or DRS_RST = '0')
	then					
		ADC_CLK		<= '0';
		FIFO_WEs <= '1';
		FIFO_DATAIN_16s  <= (others => '0');
		adc_sample_count := (others => '0');
		prev_adc_sample_cnt	:= (others => '0');
		r_addr <= 0;
		accum_var  := (others => '0');
		count2 := (others => '0');
		base_line <= (others => '0');
		threshold <= (others => '0');
		peak_sense_cnt <= (others => '0');
		pulse_val  := (others => '0');
		adc_readout_state <= init;
		EVENT_VALID <= '0';
	elsif rising_edge(ADC_CLK_IN) then		
		case (adc_readout_state) is
			when init =>
				if(ADC_CLK_ENs = '1')then
					if(PULSE_ENABLE = '1')then
						adc_readout_state   <= wait_state4; -- Prajj: adc_roi_read
						r_addr <= start_cell_addr;
						base_line <= (others => '0');
						peak_sense_cnt <= (others => '0');
						threshold <= (others => '0');
						EVENT_VALID <= '0';
						pulse_val  := (others => '0');
					else
						adc_readout_state   <= wait_state2; -- MNS: wait 1 cycle before going to adc_cal_read state
					end if;
				else
					adc_readout_state   <= init;
					FIFO_WEs 	<= '1';
					FIFO_DATAIN_16s  <= (others => '0');
					ADC_CLK		<= '0';
					adc_sample_count 	:= (others => '0');
					prev_adc_sample_cnt	:= (others => '0');
					r_addr <= 0;
					count2 := (others => '0');
					accum_var  := (others => '0');
					pulse_val  := (others => '0');
					--EVENT_VALID <= '0';
					--base_line <= (others => '0');  -- Disable to see baseline value at BE
					--threshold := (others => '0');
					--peak_sense_cnt := (others => '0');
				end if;
				
			-- MNS: wait 1 cycle before going to adc_cal_read state
			when wait_state2 =>
				adc_readout_state <= wait_state3;
			
			when wait_state3 =>
				adc_readout_state <= adc_cal_read;
				
			when wait_state4 =>
				adc_readout_state <= adc_roi_read;
			
			when adc_cal_read =>                      -- Raw read for offset calibration

				ADC_CLK <= not ADC_CLK;
--				if(ADC_CLK = '1') then
--					adc_sample_count   := adc_sample_count + 1;
--				end if; 
				 				 
				if(adc_sample_count > (ADC_DLAY-1) and adc_sample_count < (ADC_SAMPLE_SIZE)) then  --CAL =  1031  ROI =  307 -- Prajj: Originlly was 6 --Prajj: removed -1, added +1, +2
				--if(adc_sample_count > 0 and adc_sample_count < (ADC_SAMPLE_SIZE)) then
					if(ADC_CLK = '0') then
						FIFO_DATAIN_16s <= "0000" & ADC_DATA;
						FIFO_WEs <= '1';
					end if;
						
					if(ADC_CLK = '1') then
						FIFO_WEs <= '0';
					end if;	
				end if;

				if(adc_sample_count = (ADC_SAMPLE_SIZE))then    --CAL =  1031  ROI =  307 -- Prajj: added +2
					FIFO_WEs <= '1';
					FIFO_DATAIN_16s  <= (others => '0');
					adc_sample_count 	:= (others => '0');
					adc_readout_state   <= init;
				end if;
				
				if(ADC_CLK = '1') then
					adc_sample_count   := adc_sample_count + 1;
				end if;
				 
			when adc_roi_read =>                      -- ROI read for zero suppression
				if(r_addr = last_cell_addr)then
					r_addr <= first_cell_addr;
				end if;
				 
				ADC_CLK <= not ADC_CLK;
--				if(ADC_CLK = '1') then
--					adc_sample_count   := adc_sample_count + 1;
--				end if; 
				 
				if(count2 = BASE_CNT) then
					base_line <= accum_var/BASE_CNT;  
					threshold <= THRES_VAR + (accum_var/BASE_CNT);
				end if;
				 
				if(adc_sample_count > (ADC_DLAY - 1) and adc_sample_count < ADC_SAMPLE_SIZE) then  --CAL =  1031  ROI =  307 -- Prajj: Originally was 6
					if(ADC_CLK = '0') then
						FIFO_DATAIN_16s <= ADC_DATA - ram_data_out;
						pulse_val := signed(ADC_DATA - ram_data_out);
						FIFO_WEs <= '1';
						prev_adc_sample_cnt := adc_sample_count;
					end if;
						
					if(ADC_CLK = '1') then
						FIFO_WEs <= '0';
						r_addr <= r_addr + 1;
						
						if(count2 < (BASE_CNT+1)) then   
							accum_var := signed(ADC_DATA) + accum_var;
							count2 := count2 + '1';
						end if;
						
						if((pulse_val > threshold) and (adc_sample_count = prev_adc_sample_cnt + 1))then
							peak_sense_cnt <= peak_sense_cnt + '1';
						end if;
					end if;						
				end if;

				 
				if(adc_sample_count = ADC_SAMPLE_SIZE)then    --CAL =  1031  ROI =  307
					FIFO_WEs <= '1';
					FIFO_DATAIN_16s  <= (others => '0');
					adc_sample_count 	:= (others => '0');
					adc_readout_state   <= init;
					r_addr <= 0;
					count2 := (others => '0');
					accum_var  := (others => '0');
					pulse_val  := (others => '0');
					if(peak_sense_cnt > VALID_PULSE_CNT)then
						EVENT_VALID <= '1';
					else
						EVENT_VALID <= '0';
					end if;
					--peak_sense_cnt := (others => '0');
					--base_line <= (others => '0');
					--threshold := (others => '0');
				end if;
				
				if(ADC_CLK = '1') then
					adc_sample_count   := adc_sample_count + 1;
				end if; 

--			when adc_roi_read =>                      -- ROI read for zero suppression
--				 if(r_addr = last_cell_addr)then
--					 r_addr <= first_cell_addr;
--				 end if;
--				 
--				 ADC_CLK <= not ADC_CLK;
--				 if(ADC_CLK = '1') then
--					adc_sample_count   := adc_sample_count + 1;
--				 end if; 
--				 
--				 if(count2 = BASE_CNT) then
--					base_line <= accum_var/BASE_CNT;
--				 end if;
--				 
--				 if(adc_sample_count > 6 and adc_sample_count < ADC_SAMPLE_SIZE) then  --CAL =  1031  ROI =  307 
--						if(ADC_CLK = '0') then
--							FIFO_DATAIN_16s <= ADC_DATA - ram_data_out;
--							FIFO_WEs <= '1';
--						end if;
--						
--						if(ADC_CLK = '1') then
--							FIFO_WEs <= '0';
--							r_addr <= r_addr + 1;
--							
--							if(count2 < (BASE_CNT+1)) then   
--								accum_var := signed(ADC_DATA) + accum_var;
--								count2 := count2 + '1';
--							end if;	
--							
--						end if;						
--				 end if;
--
--				 
--				 if(adc_sample_count = ADC_SAMPLE_SIZE)then    --CAL =  1031  ROI =  307
--					FIFO_WEs <= '1';
--					FIFO_DATAIN_16s  <= (others => '0');
--					adc_sample_count 	:= (others => '0');
--					adc_readout_state   <= init;
--					r_addr <= 0;
--					count2 := (others => '0');
--					--base_line <= (others => '0');
--					accum_var  := (others => '0');
--				 end if;	
				 
				 
			when wait_state =>
				adc_sample_count := adc_sample_count + 1;
				
				if(adc_sample_count = 2)then     
					adc_sample_count 	:= (others => '0');
					adc_readout_state  <= init;
				else
					adc_readout_state  <= wait_state;
				end if;				
				
			when others => 
				adc_readout_state <= init;
		end case;	
	end if;
end process;


--process(ADC_CLK_IN,nRST,ADC_CLK_ENs,DRS_RST)
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		ADC_CLK_EN <= '0';
--	elsif(ADC_CLK_IN'event and ADC_CLK_IN = '1') then
--		ADC_CLK_EN <= ADC_CLK_ENs;
--	end if;
--end process;


process(LCLK,nRST,EVE_INT,DRS_RST)
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		MCU_EVE_INT <= '0';
	elsif(LCLK'event and LCLK = '1') then
		MCU_EVE_INT <= EVE_INT;
	end if;
end process;

process(LCLK,nRST,TRIG_IN,DRS_RST)
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		TRIG_INs <= '0';
	elsif(LCLK'event and LCLK = '1') then
		TRIG_INs <= TRIG_IN;
	end if;
end process;

process(LCLK,nRST,ROI_TRIG_ENs,DRS_RST)
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		ROI_TRIG_EN <= '0';
	elsif(LCLK'event and LCLK = '1') then
		ROI_TRIG_EN <= ROI_TRIG_ENs;
	end if;
end process;

process(LCLK,nRST,CONFIG_DRSs,DRS_RST)
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		CONFIG_DRS <= '0';
	elsif(LCLK'event and LCLK = '1') then
		CONFIG_DRS <= CONFIG_DRSs;
	end if;
end process;

process(LCLK,nRST,DRS_CH_ADDRs,DRS_RST)
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		DRS_CH_ADDR <= "0000";
	elsif(LCLK'event and LCLK = '1') then
		DRS_CH_ADDR <= DRS_CH_ADDRs;
	end if;
end process;
--
--process(LCLK,nRST,EVE_ENABLEs,DRS_RST)
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		EVE_ENABLE <= '0';
--	elsif(LCLK'event and LCLK = '1') then
--		EVE_ENABLE <= EVE_ENABLEs;
--	end if;
--end process;
--
--process(LCLK,nRST,READ_SHIFT_ENs,DRS_RST)
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		READ_SHIFT_EN <= '0';
--	elsif(LCLK'event and LCLK = '1') then
--		READ_SHIFT_EN <= READ_SHIFT_ENs;
--	end if;
--end process;
--
--process(LCLK,nRST,ROI_ENs,DRS_RST)
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		ROI_EN <= '0';
--	elsif(LCLK'event and LCLK = '1') then
--		ROI_EN <= ROI_ENs;
--	end if;
--end process;

--
--FIFO_wr_signal: process(FIFO_CLK,ADC_CLK_ENs,DRS_RST,nRST)
--	variable count1 : std_logic_vector(3 downto 0) := "0000";
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		FIFO_WEs <= '1';
--		FIFO_DATAIN_16s  <= (others => '0');
--		count1 := (others => '0');
--	elsif(FIFO_CLK'event and FIFO_CLK = '1') then
--		
--		if(ADC_CLK_ENs = '1') then
--			if(count1 < 8) then
--				count1 := count1 + '1';
--			end if;
--
--			if(count1 = 1) then
--				FIFO_WEs <= '0'; -- active low signal
--			end if;
--			
--			if(count1 = 2) then
--				FIFO_DATAIN_16s <= "00" & ADC_DATA;
--				FIFO_WEs <= '1';
--			end if;
--			
--			if(count1 = 3) then
--				FIFO_WEs <= '0'; -- active low signal
--			end if;
--			
--			if(count1 = 4) then
--				FIFO_WEs <= '1';
--				count1 := (others => '0');
--				FIFO_DATAIN_16s <= "00" & ADC_DATA;
--			end if;
--		else
--			FIFO_WEs <= '1';
--			count1 := (others => '0');
--		end if;
--	end if;
--end process;



--FIFO_wr_signal: process(LCLK,ADC_CLK_ENs,DRS_RST,nRST)
--	variable count1 		 : std_logic_vector(3 downto 0) := "0000";
--	variable count2 		 : std_logic_vector(15 downto 0) := X"0000";
--	variable accum_var    : signed(31 downto 0);
----	variable base_line    : signed(31 downto 0);
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		r_addr <= 0;
--		FIFO_WEs <= '1';
--		FIFO_DATAIN_16s  <= (others => '0');
--		accum_var  := (others => '0');
--		base_line0 <= (others => '0');
--		base_line1 <= (others => '0');
--		base_line2 <= (others => '0');
--		base_line3 <= (others => '0');
--		base_line4 <= (others => '0');
--		base_line5 <= (others => '0');
--		base_line6 <= (others => '0');
--		base_line7 <= (others => '0');
--		base_line8 <= (others => '0');
--		count1 := (others => '0');
--		count2 := (others => '0');
--	elsif(LCLK'event and LCLK = '1') then
--		
--		if(ADC_CLK_ENs = '1') then
--			if(count1 < 8) then
--				count1 := count1 + '1';
--			end if;
--			
--			if(r_addr = last_cell_addr)then
--				r_addr <= first_cell_addr;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0000") then
--				base_line0 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0001") then
--				base_line1 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0010") then
--				base_line2 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0011") then
--				base_line3 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0100") then
--				base_line4 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0101") then
--				base_line5 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0110") then
--				base_line6 <= accum_var/64;
--			end if;
--			
--			if(count2 = 64 and DRS_CH_ADDRs = "0111") then
--				base_line7 <= accum_var/64;
--			end if;
--
--			if(count2 = 64 and DRS_CH_ADDRs = "1000") then
--				base_line8 <= accum_var/64;
--			end if;
--
--			
--			if(count1 = 4) then
--				FIFO_WEs <= '0'; -- active low signal
--				count1 := (others => '0');
--			end if;
--			
--			if(count1 = 1) then
--				FIFO_WEs <= '1';
--				if(PULSE_ENABLE = '1')then
--					FIFO_DATAIN_16s <= ADC_DATA - ram_data_out;
--				else
--					FIFO_DATAIN_16s <= "00" & ADC_DATA;
--				end if;
--
--				if(count2 < 65) then
--					accum_var := signed(ADC_DATA) + accum_var;
--					count2 := count2 + '1';
--				end if;
--				r_addr <= r_addr + 1;
--			end if;
--			
--			
--			if(count1 = 2) then
--				FIFO_WEs <= '0'; -- active low signal
--			end if;
--			
--			
--			if(count1 = 3) then
--				FIFO_WEs <= '1';
--				
--				if(PULSE_ENABLE = '1')then
--					FIFO_DATAIN_16s <= ADC_DATA - ram_data_out;
--				else
--					FIFO_DATAIN_16s <= "00" & ADC_DATA;
--				end if;
--				
--				if(count2 < 65) then
--					accum_var := signed(ADC_DATA) + accum_var;
--					count2 := count2 + '1';
--				end if;
--				r_addr <= r_addr + 1;
--				--FIFO_DATAIN_16s <= "00" & ADC_DATA;
--				--FIFO_WEs <= '1';
--			end if;
--			
--		else
--			FIFO_WEs <= '1';
--			count1 := (others => '0');
--			count2 := (others => '0');
--			accum_var  := (others => '0');
--			r_addr <= start_cell_addr;
--		end if;
--	end if;
--end process;
	

--start_cell_addr 	<= Conv_Integer(STOP_REGs) + Conv_Integer(DRS_CH_ADDRs) * 1024;
--last_cell_addr 	<= Conv_Integer(DRS_CH_ADDRs + "0001") * 1024;
--first_cell_addr 	<= Conv_Integer(DRS_CH_ADDRs) * 1024;
--
--
--
--
--
--
process(LCLK,nRST,START_CNTs,DRS_RST)
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		START_CNT 		 <= 0;      
		BASE_CNT			 <= 0;
		THRES_VAR		 <= 0;	
		VALID_PULSE_CNT <= 0;
--		READ_INIT_CYCLE <= 0; 			
--		READ_CNT			 <= 0;			 
--		TSAMP 			 <= 0;    
--		CH0_READ_CNT    <= 0;
--		CH1_READ_CNT 	 <= 0;
--		CH2_READ_CNT 	 <= 0;
--		CH3_READ_CNT 	 <= 0;
--		CH4_READ_CNT 	 <= 0;
--		CH5_READ_CNT 	 <= 0;
--		CH6_READ_CNT 	 <= 0;
--		CH7_READ_CNT 	 <= 0;
--		CH8_READ_CNT 	 <= 0;
--		EVE_READ_CNT	 <= 0;
--		STOP_CNT		    <= 0;
--		CONFIG_REGss	 <= (others => '0');
--		READOUT_TOTAL_CNT <= 0;	
	elsif(LCLK'event and LCLK = '1') then
		START_CNT 		 <= START_CNTs;       -- 1 for full readout  --20 for ROI latency of 600ns
		BASE_CNT 		 <= BASE_CNTs; 
		THRES_VAR       <= THRES_VARS;
		VALID_PULSE_CNT <= VALID_PULSE_CNTs;
--		READ_INIT_CYCLE <= READ_INIT_CYCLEs; -- 1034 for full readout   --20 for ROI
--		READ_CNT			 <= READ_CNTs;			 -- 1026 for full readout  --302 for ROI	
--		TSAMP 			 <= READ_CNT + 18;    -- Sampling time required for each channel
--		CH0_READ_CNT    <= START_CNT + READ_INIT_CYCLE;
--		CH1_READ_CNT 	 <= CH0_READ_CNT + TSAMP;
--		CH2_READ_CNT 	 <= CH1_READ_CNT + TSAMP;
--		CH3_READ_CNT 	 <= CH2_READ_CNT + TSAMP;
--		CH4_READ_CNT 	 <= CH3_READ_CNT + TSAMP;
--		CH5_READ_CNT 	 <= CH4_READ_CNT + TSAMP;
--		CH6_READ_CNT 	 <= CH5_READ_CNT + TSAMP;
--		CH7_READ_CNT 	 <= CH6_READ_CNT + TSAMP;
--		CH8_READ_CNT 	 <= CH7_READ_CNT + TSAMP;
--		EVE_READ_CNT	 <= CH8_READ_CNT + TSAMP;
--		STOP_CNT		    <= EVE_READ_CNT + 10;
--		READOUT_TOTAL_CNT <= STOP_CNT + 2;	
--		CONFIG_REGss    <= CONFIG_REGs;
--		WRSHIFT_REGss   <= WRSHIFT_REGs;
	end if;
end process;


process(LCLK,nRST,PULSE_ENABLEs,CAL_ENABLEs,DRS_RST)
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		PULSE_ENABLE <= '0';
		CAL_ENABLE 	 <= '0';
	elsif(LCLK'event and LCLK = '1') then
		PULSE_ENABLE <= PULSE_ENABLEs;
		CAL_ENABLE 	 <= CAL_ENABLEs;
	end if;
end process;



process(PULSE_ENABLE, CAL_ENABLE, nRST, DRS_RST, SINGLE_CAL_TRIG)
begin
	if(nRST = '0' or DRS_RST = '0')	then 
		TRIGGER			<= '0';
		--TIM  			<= '0'; -- MNS: Commented
		READ_SHIFT_ENs	<= '0';
		TRIG_ENs 		<= '0';
		ROI_ENs			<= '0';
		ROI_TRIG_ENs	<= '0';
		ADC_SAMPLE_SIZE <= DRS_CELL + ADC_DLAY;
	elsif(PULSE_ENABLE = '1') then
		TRIGGER 		<= TRIG_INs;
		--TIM 			<= TRIG_INs; -- MNS: Commented
		ROI_ENs			<= DRS_INIT_ENs;
		ROI_TRIG_ENs	<= DRS_READ_ENs;
		READ_SHIFT_ENs	<= '0';
		TRIG_ENs 		<= '0';
		ADC_SAMPLE_SIZE <= DRS_ROI + ADC_DLAY; -- Prajj: originally was 307
	elsif(CAL_SINGLE_EN = '1') then
		TRIGGER 		<= SINGLE_CAL_TRIG;
		--TIM 			<= '0'; -- MNS: Commented
		ROI_ENs			<= '0';
		ROI_TRIG_ENs	<= '0';
		READ_SHIFT_ENs	<= DRS_INIT_ENs;
		TRIG_ENs 		<= DRS_READ_ENs;
		ADC_SAMPLE_SIZE <= DRS_CELL + ADC_DLAY;
	elsif(CAL_ENABLE = '1') then
		TRIGGER 		<= test_sig;
		--TRIGGER 		<= TRIG_IN; -- MNS: temporarily changed to ext triger in from test_sig to test input pulses
		--TIM 			<= '0'; -- MNS: Commented
		ROI_ENs			<= '0';
		ROI_TRIG_ENs	<= '0';
		READ_SHIFT_ENs	<= DRS_INIT_ENs;
		TRIG_ENs 		<= DRS_READ_ENs;
		ADC_SAMPLE_SIZE <= DRS_CELL + ADC_DLAY;
	end if;
	
end process;





--		if(CONFIG_DRS = '1') -- Checkking config command and starting configuration
--		then
--			if(config_status = '0')
--			then
--				CONFIG_ENABLEs := '1';
--				config_status := '1';
--				count1 := (others => '0');
--			end if;
--		end if;
--	
--	
--		if(CONFIG_ENABLEs = '1')then
--		
--			if(count1 < 43)   --39
--			then
--				count1 := count1 + '1';
--			end if;
--			
--			if(count1 = 2)  -- Setting Configuration register :"11111011"
--			then
--				DRS_ADDR	<= "1100"; 
--			end if;
--			
--			if(count1 = 3) -- bit7
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 4)
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;			
--			
--			if(count1 = 5) -- bit6
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 6) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;
--			
--			if(count1 = 7) -- bit5
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 8)
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;			
--			
--			if(count1 = 9) -- bit4
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 10) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;	
--			
--			if(count1 = 11) -- bit3
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 12) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;
--		
--	
--			if(count1 = 13) -- bit2
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 14) 
--			then
--				DRS_SRIN	<= '0';
--				DRS_SRCLK_s <= '0';
--			end if;	
--			
--			if(count1 = 15) -- bit1
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 16) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;
--		
--		
--			if(count1 = 17) -- bit0
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 18) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;
--						
--			
--			if(count1 = 21)  -- Setting Write shift register :"11111111"
--			then
--				DRS_ADDR	<= "1101";
--			end if;
--			
--			if(count1 = 22) -- bit7
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 23)
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;			
--			
--			if(count1 = 24) -- bit6
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 25) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;
--			
--			if(count1 = 26) -- bit5
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 27)
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;			
--			
--			if(count1 = 28) -- bit4
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 29) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;	
--			
--			if(count1 = 30) -- bit3
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 31) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;
--		
--	
--			if(count1 = 32) -- bit2
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 33) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;	
--			
--			if(count1 = 34) -- bit1
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 35) 
--			then
--				DRS_SRIN	<= '1';
--				DRS_SRCLK_s	<= '0';
--			end if;
--		
--		
--			if(count1 = 36) -- bit0
--			then
--				DRS_SRCLK_s <= '1';
--			end if;																						
--		
--			if(count1 = 37) 
--			then
--				DRS_SRCLK_s	<= '0';
--				DRS_SRIN		<= '1';
--			end if;
--					
--			
--			if(count1 = 40)   -- start domino 
--			then
--				DRS_DENABLE 	<= '1';
--				DRS_DWRITE  	<= '1';
--				DRS_SRCLK_s    <= '0';
--				DRS_SRIN			<= '0';
--			end if;
--			
--			if(count1 = 41)   -- End Configuration  
--			then
--				CONFIG_ENABLEs 	:= '0';
--				count1 := (others => '0');
--			end if;
--		end if;
--
--
--		if(CONFIG_ENABLEs = '0' and CONFIG_DRS = '0')then -- stop Configuration
--			config_status := '0';
--		end if;



--EVENT_Process: process(LCLK,DRS_RST,nRST,TRIGGER)
--	variable count : std_logic_vector(31 downto 0) := X"00000000";
--	variable TRG_status : std_logic := '0';
--	variable TRG_ENs : std_logic := '0';
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		DRS_INIT_ENs 	<= '0';
--		DRS_READ_ENs 	<= '0';
--		EVE_ENABLEs 	<= '0';
--		TRG_ENs 			:= '0';
--		TRG_status 		:= '0';
--		DRS_CH_ADDRs 	<= "0000";
--	elsif(LCLK'event and LCLK = '1') then
--		if(TRIGGER = '1') -- Initiate event processing 
--		then
--			if(TRG_status = '0')
--			then
--				TRG_ENs := '1';
--				TRG_status := '1';
--			end if;
--		end if;
--		
--		if(TRG_ENs = '1')
--		then	
--			if(count < READOUT_TOTAL_CNT)
--			then
--				count := count + '1';
--			end if;
--			
--			if(count = START_CNT)                 -- Read Init 
--			then
--				DRS_INIT_ENs <= '1';
--			end if;
--			
--			if(count = (START_CNT + 9)) 
--			then
--				DRS_INIT_ENs <= '0';
--			end if;			
--			
--	 ----------------------
--						
--			if(count = CH0_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "0000";    -- CH 0 Read
--			end if;	
--		 	
--			
--			if(count = (CH0_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH0_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';
--			end if;
--	
--	---------------------
--			if(count = CH1_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "0001";    -- CH 1 Read
--			end if;	
--		 	
--			
--			if(count = (CH1_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH1_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';
--			end if;
--
--			
--	---------------------
--			if(count = CH2_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "0010";    -- CH 2 Read
--			end if;	
--		 	
--			
--			if(count = (CH2_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH2_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';
--			end if;
--
--
--	---------------------
--			if(count = CH3_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "0011";    -- CH 3 Read
--			end if;	
--		 	
--			
--			if(count = (CH3_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH3_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';
--			end if;
--
--	---------------------
--			if(count = CH4_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "0100";    -- CH 4 Read
--			end if;	
--		 	
--			
--			if(count = (CH4_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH4_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';
--			end if;
--
--	---------------------
--			if(count = CH5_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "0101";    -- CH 5 Read
--			end if;	
--		 	
--			
--			if(count = (CH5_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH5_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';
--			end if;
--
--	---------------------
--			if(count = CH6_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "0110";    -- CH 6 Read
--			end if;	
--		 	
--			
--			if(count = (CH6_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH6_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';	
--			end if;			
--			
--	---------------------1042
--			if(count = CH7_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "0111";    -- CH 7 Read
--			end if;	
--		 	
--			
--			if(count = (CH7_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH7_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';
--			end if;
--			
--	---------------------1042
--			if(count = CH8_READ_CNT) 
--			then
--				DRS_CH_ADDRs <= "1000";    -- CH 8 Read
--			end if;	
--		 	
--			
--			if(count = (CH8_READ_CNT + 1)) 
--			then
--				DRS_READ_ENs <= '1';
--			end if;	
--	
--			if(count = (CH8_READ_CNT + 3)) 
--			then
--				DRS_READ_ENs <= '0';
--			end if;
--			
--   ---------------------1042       -- Start DWRITE and Generate event intterupt
--
--			if(count = EVE_READ_CNT) 
--			then
--				EVE_ENABLEs     <= '1';
--			end if;	
--	
--			if(count = (EVE_READ_CNT + 1)) 
--			then
--				EVE_ENABLEs     <= '0';   
--			end if;
--	-----------------------10
--	
--			if(count = STOP_CNT) 
--			then
--				DRS_CH_ADDRs <= "0000"; -- CH 8 Read
--			   TRG_ENs := '0';
--				count := (others => '0');
--			end if;
--
--		end if;
--		
--		if(TRG_ENs = '0' and TRIGGER = '0')then -- stop raeding
--			TRG_status := '0';
--		end if;
--		
--	end if;
--end process;		
		
-----------------CALIBRATION ----------------------------------
		
--CELL_OFFSET_CALIBRATION_Process: process(LCLK,DRS_RST,nRST,test_sig)
--	variable count : std_logic_vector(31 downto 0) := X"00000000";
--	variable CAL_status : std_logic := '0';
--	variable CAL_ENs : std_logic := '0';
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		EVE_ENABLEs 	<= '0';
--		TRIG_ENs 		<= '0';
--		READ_SHIFT_ENs <= '0';
--		CAL_ENs 			:= '0';
--		CAL_status 		:= '0';
--		DRS_CH_ADDRs 	<= "0000";
--	elsif(LCLK'event and LCLK = '1') then
--		if(test_sig = '1') -- Initiate CALIB processing 
--		then
--			if(CAL_status = '0')
--			then
--				CAL_ENs := '1';
--				CAL_status := '1';
--			end if;
--		end if;
--		
--		if(CAL_ENs = '1')
--		then	
--			if(count < 10452)
--			then
--				count := count + '1';
--			end if;
--			
--			if(count = 1)                 -- Read Init 
--			then
--				READ_SHIFT_ENs <= '1';
--			end if;	
--			
--			if(count = 10) 
--			then
--				READ_SHIFT_ENs <= '0';
--			end if;			
--			
--	 ----------------------
--						
--			if(count = 1035) 
--			then
--				DRS_CH_ADDRs <= "0000";    -- CH 0 Read
--			end if;	
--		 	
--			
--			if(count = 1036) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 1038) 
--			then
--				TRIG_ENs     <= '0';
--			end if;
--	
--	---------------------
--			if(count = 2080) 
--			then
--				DRS_CH_ADDRs <= "0001";    -- CH 1 Read
--			end if;	 
--		 	
--			
--			if(count = 2081) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 2083) 
--			then
--				TRIG_ENs     <= '0';
--			end if;
--
--			
--	---------------------
--			if(count = 3125) 
--			then
--				DRS_CH_ADDRs <= "0010";    -- CH 2 Read
--			end if;	
--		 	
--			
--			if(count = 3126) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 3128) 
--			then
--				TRIG_ENs     <= '0';
--			end if;
--
--
--	---------------------
--			if(count = 4170) 
--			then
--				DRS_CH_ADDRs <= "0011";    -- CH 3 Read
--			end if;	
--		 	
--			
--			if(count = 4171) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 4173) 
--			then
--				TRIG_ENs     <= '0';
--			end if;
--
--	---------------------
--			if(count = 5215) 
--			then
--				DRS_CH_ADDRs <= "0100";    -- CH 4 Read
--			end if;	
--		 	
--			
--			if(count = 5216) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 5218) 
--			then
--				TRIG_ENs     <= '0';
--			end if;
--
--	---------------------
--			if(count = 6260) 
--			then
--				DRS_CH_ADDRs <= "0101";    -- CH 5 Read
--			end if;	
--		 	
--			
--			if(count = 6261) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 6263) 
--			then
--				TRIG_ENs     <= '0';
--			end if;
--
--	---------------------
--			if(count = 7305) 
--			then
--				DRS_CH_ADDRs <= "0110";    -- CH 6 Read
--			end if;	
--		 	
--			
--			if(count = 7306) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 7308) 
--			then
--				TRIG_ENs     <= '0';
--			end if;			
--			
--	---------------------1042
--			if(count = 8350) 
--			then
--				DRS_CH_ADDRs <= "0111";    -- CH 7 Read
--			end if;	
--		 	
--			
--			if(count = 8351) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 8353) 
--			then
--				TRIG_ENs     <= '0';
--			end if;
--			
--	---------------------1042
--			if(count = 9395) 
--			then
--				DRS_CH_ADDRs <= "1000";    -- CH 8 Read
--			end if;	
--		 	
--			
--			if(count = 9396) 
--			then
--				TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 9398) 
--			then
--				TRIG_ENs     <= '0';
--			end if;
--			
--   ---------------------1042       -- Start DWRITE and Generate event intterupt
--
--			if(count = 10440) 
--			then
--				EVE_ENABLEs     <= '1';
--			end if;	
--	
--			if(count = 10442) 
--			then
--				EVE_ENABLEs     <= '0';   
--			end if;
--	-----------------------10
--	
--			if(count = 10450) 
--			then
--				DRS_CH_ADDRs <= "0000"; -- CH 8 Read
--			   CAL_ENs := '0';
--				count := (others => '0');
--			end if;
--
--		end if;
--		
--		if(CAL_ENs = '0' and test_sig = '0')then -- stop raeding
--			CAL_status := '0';
--		end if;
--		
--	end if;
--end process;

-----------------END of CALIBRATION ----------------------------------



--ROI_TRIGGER_Process: process(LCLK,DRS_RST,nRST,TRIGGER)
--	variable count : std_logic_vector(31 downto 0) := X"00000000";
--	variable TRG_status : std_logic := '0';
--	variable TRG_ENs : std_logic := '0';
--begin
--	if(nRST = '0' or DRS_RST = '0')
--	then
--		EVE_ENABLEs 	<= '0';
--		TRIG_ENs 		<= '0';
--		READ_SHIFT_ENs <= '0';
--		TRG_ENs 			:= '0';
--		TRG_status 		:= '0';
--		DRS_CH_ADDRs 	<= "0000";
--	elsif(LCLK'event and LCLK = '1') then
--		if(TRIGGER = '1' and PULSE_ENABLEs = '1') -- Initiate event processing 
--		then
--			if(TRG_status = '0')
--			then
--				TRG_ENs := '1';
--				TRG_status := '1';
--			end if;
--		end if;
--		
--		if(TRG_ENs = '1')
--		then	
--			if(count < 9451)
--			then
--				count := count + '1';
--			end if;
--			
--			if(count = 1)                 -- Read Init 
--			then
--				ROI_ENs <= '1';
--			end if;	
--			
--			if(count = 10) 
--			then
--				ROI_ENs <= '0';
--			end if;			
--			
--	 ----------------------
--						
--			if(count = 20) 
--			then
--				DRS_CH_ADDRs <= "0000";    -- CH 0 Read
--			end if;	
--		 	
--			
--			if(count = 21) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 23) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;
--	
--	---------------------
--			if(count = 1065) 
--			then
--				DRS_CH_ADDRs <= "0001";    -- CH 1 Read
--			end if;	
--		 	
--			
--			if(count = 1066) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 1068) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;
--
--			
--	---------------------
--			if(count = 2110) 
--			then
--				DRS_CH_ADDRs <= "0010";    -- CH 2 Read
--			end if;	
--		 	
--			
--			if(count = 2111) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 2113) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;
--
--
--	---------------------
--			if(count = 3155) 
--			then
--				DRS_CH_ADDRs <= "0011";    -- CH 3 Read
--			end if;	
--		 	
--			
--			if(count = 3156) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 3158) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;
--
--	---------------------
--			if(count = 4200) 
--			then
--				DRS_CH_ADDRs <= "0100";    -- CH 4 Read
--			end if;	
--		 	
--			
--			if(count = 4201) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 4203) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;
--
--	---------------------
--			if(count = 5245) 
--			then
--				DRS_CH_ADDRs <= "0101";    -- CH 5 Read
--			end if;	
--		 	
--			
--			if(count = 5246) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 5248) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;
--
--	---------------------
--			if(count = 6290) 
--			then
--				DRS_CH_ADDRs <= "0110";    -- CH 6 Read
--			end if;	
--		 	
--			
--			if(count = 6291) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 6293) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;			
--			
--	---------------------1042
--			if(count = 7335) 
--			then
--				DRS_CH_ADDRs <= "0111";    -- CH 7 Read
--			end if;	
--		 	
--			
--			if(count = 7336) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 7338) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;
--			
--	---------------------1042
--			if(count = 8380) 
--			then
--				DRS_CH_ADDRs <= "1000";    -- CH 8 Read
--			end if;	
--		 	
--			
--			if(count = 8381) 
--			then
--				ROI_TRIG_ENs     <= '1';
--			end if;	
--	
--			if(count = 8383) 
--			then
--				ROI_TRIG_ENs     <= '0';
--			end if;
--			
--   ---------------------1042       -- Start DWRITE and Generate event intterupt
--
--			if(count = 9425) 
--			then
--				EVE_ENABLEs     <= '1';
--			end if;	
--	
--			if(count = 9426) 
--			then
--				EVE_ENABLEs     <= '0';   
--			end if;
--	-----------------------23
--	
--			if(count = 9449) 
--			then
--				DRS_CH_ADDRs <= "0000"; -- CH 8 Read
--			   TRG_ENs := '0';
--				count := (others => '0');
--			end if;
--
--		end if;
--		
--		if(TRG_ENs = '0' and TRIGGER = '0')then -- stop raeding
--			TRG_status := '0';
--		end if;
--		
--	end if;
--end process;



------------------------------------------------------------
-- fifo instantiation
------------------------------------------------------------
	fifo : fifo2
	port map
	(
			Clk			=> ADC_CLK_IN,
		    nReset		=> nRST,
		    WriteEnable => FIFO_WEs, --FIFO_Wren_sync,
		    ReadEnable  => FIFO_REs, --FIFO_Rden_sync,
		    DataIn      => FIFO_DATAIN_16s,
		    DataOut     => FIFO_DATAOUTs,
		    FifoEmpty   => FifoEmptys,
		    FifoFull    => FifoFulls,
			-- P_wptr      => FIFO_PWPTRs,
			-- F_wptr      => FIFO_FWPTRs,
			-- wptr_cflag	 => FIFO_wptr_cflag,
			FreeSpace	=> FreeSpaces  
	);

--------------------------------------------------------------------------
	
--	REs <= MCU_nRD when (MCU_ADDR = A_READ_FIFO) else '1';
--	WEs <= MCU_nWR when (MCU_ADDR = A_WRITE_FIFO) else '1';

	FIFO_rd_signal: process(ADC_CLK_IN)
	begin
		if(LCLK'event and LCLK = '1') then
			if (MCU_ADDR = A_READ_FIFO) then
				if (MCU_nRD = '0') then
					FIFO_REs <= '0';
				else
					FIFO_REs <= '1';
				end if;
			end if;
		end if;
	end process;
	


------------------------------------------------------------
-- Offset RAM  instantiation
------------------------------------------------------------
	ram1 : cell_ram_part
	port map
	(
		clock			=> ADC_CLK_IN,
		data    		=> ram_data_in,
		write_address => w_addr,
		read_address  => r_addr,
		we 				=> ram_WEs, 
		re  				=> ram_REs, 
		q     			=> ram_data_out
	);




	RAM_wr_signal: process(ADC_CLK_IN)
		variable count1 : std_logic_vector(3 downto 0) := "0000";
		variable ram_wr_flag : std_logic := '0';
	begin
		if(nRST = '0')
		then
			ram_WEs <= '1';
			ram_REs <= '1';
		elsif(ADC_CLK_IN'event and ADC_CLK_IN = '1') then
			if (MCU_ADDR = A_WRITE_RAM_DATA and MCU_nWR = '0' ) then
				ram_wr_flag := '1';
			end if;
			
			if(ram_wr_flag = '1') then
				if(count1 < 6) then
					count1 := count1 + '1';
				end if;
				
				if(count1 = 2) then
					ram_data_in <= ram_data_ins;
				end if;
				
				if(count1 = 3) then
					ram_WEs <= '0'; -- active low signal
				end if;
				
				if(count1 = 4) then
					ram_WEs <= '1';
					ram_wr_flag := '0';
					count1 := (others => '0');
				end if;
		
			end if;
			
		end if;
	end process;


---------------------------------------------------------------------------

--------------------------------------------------------------------------
-- USER REGISTERS SECTION
--------------------------------------------------------------------------

	-- Resolve MCU BiDirectional data signals

		-- If we are using the inout as an output, assign it an output value, 
		-- otherwise assign it high-impedence
--	<bidir_variable> <= <data> when <output_enable> = '1' else (others => 'Z');

		-- Read in the current value of the bidir port, which comes either 
		-- from the input or from the previous assignment
--	<read_buffer> <= <bidir_variable>;

	MCU_DATA <= MCU_DOUTs when MCU_nRD = '0' else (others => 'Z');
	MCU_DINs <= MCU_DATA;


------------------------------------------------------------------------------
-- Read and write to registers
------------------------------------------------------------------------------
	process(LCLK, nRST)
	begin
		if(nRST = '0')
		then			
		-- put default values of registers here
		CONFIG_DRSs <= '0';
		--EVE_ENABLEs <= '0';    --
		--TRIG_ENs 	<= '0';      --
		--READ_SHIFT_ENs <= '0'; --
		DRS_CH_ADDRs <= "0000";--
		eve_freqs <= X"004C4B40";
		eve_cnts  <= X"000003E8";
		WRSHIFT_REGs <= "11111111";
		CONFIG_REGs  <= "11111011";
		TCAL_CTRLS <= '0';
		PULSE_ENABLEs <= '0';
		CAL_ENABLEs <= '0';
		CAL_SINGLE_EN <= '0';
		SINGLE_CAL_TRIG <= '0';
		w_addr <= 0;
--		r_addr <= 0;
--		READ_INIT_CYCLEs <= 20;
		START_CNTs		  <= 10;
		BASE_CNTs		  <= 10;
		THRES_VARS		  <= 1500;
		VALID_PULSE_CNTs <= 15;
		-- Read from registers
		elsif(LCLK'event and LCLK = '1')
		then
			if(MCU_nRD = '0') -- read pulse from CPU
			then
				case MCU_ADDR is

--					when A_EVE0				=> MCU_DOUTs <= std_logic_vector(unsigned(base_line0));
--					when A_EVE1				=> MCU_DOUTs <= std_logic_vector(unsigned(base_line1));
--					when A_EVE2				=> MCU_DOUTs <= std_logic_vector(unsigned(base_line2));
--					when A_EVE3				=> MCU_DOUTs <= std_logic_vector(unsigned(base_line3));
--					when A_EVE4 			=> MCU_DOUTs <= std_logic_vector(unsigned(base_line4));
--					when A_EVE5				=> MCU_DOUTs <= std_logic_vector(unsigned(base_line5));
--					when A_EVE6				=> MCU_DOUTs <= std_logic_vector(unsigned(base_line6));
--					when A_EVE7				=> MCU_DOUTs <= std_logic_vector(unsigned(base_line7));
--					when A_EVE8				=> MCU_DOUTs <= std_logic_vector(unsigned(base_line8));
--					when A_EVE9 			=> MCU_DOUTs <= EVE9;
--					when A_TRIG_COUNT 		=> MCU_DOUTs <= TRIG_COUNTs;
					when A_READ_FIFO  	 	=> MCU_DOUTs(15 downto 0) <= FIFO_DATAOUTs;           ---read FIFO
					when A_FREE_SPACE  		=> MCU_DOUTs(ADDR_width downto 0) <= FreeSpaces;
					when A_FIFO_TEST		=> MCU_DOUTs(ADDR_width-1 downto 0) <= FIFO_PWPTRs;   -- Can be used to track the wptr of H/W FIFO
					when A_STOP_REG  	 	=> MCU_DOUTs(9 downto 0) <= STOP_REGs;           ---read Stop Reg
					--when A_READ_RAM_DATA 	=> MCU_DOUTs(15 downto 0) <= ram_data_out;
					when A_BASE_LINE		=> MCU_DOUTs <= X"0000" & std_logic_vector(unsigned(base_line));
					when A_CALC_THRESHOLD	=> MCU_DOUTs <= X"0000" & std_logic_vector(unsigned(threshold));
					when A_PEAK_CNT			=> MCU_DOUTs <= peak_sense_cnt;
					when A_EVE_VALID 		=> MCU_DOUTs <= X"0000000" & "000" & EVENT_VALID;				
					when others				=> MCU_DOUTs <= X"FFFFFFFF";

				end case;
			end if;
			
			-- Write to registers
			if(MCU_nWR = '0') -- write pulse from MCU
			then
				case MCU_ADDR is
					when A_PULSE_ENABLE		=> PULSE_ENABLEs	       	<= MCU_DINs(0);
					when A_CLR_TRIG_VETO	=> CLR_TRIG_VETOs			<= '1';							
					when A_EVE_FREQ			=> eve_freqs	    		<= MCU_DINs;
					when A_EVE_CNT			=> eve_cnts	        		<= MCU_DINs;
					when A_CONFIG_REG		=> CONFIG_REGs	    		<= MCU_DINs(7 downto 0);
					when A_WRSHIFT_REG		=> WRSHIFT_REGs	    		<= MCU_DINs(7 downto 0);
					when A_WRITE_FIFO		=> FIFO_DATAINs				<= MCU_DINs;   ---write FIFO removed becoz of H/W event collection
					when A_TCAL_OSC_EN		=> TCAL_CTRLS				<= MCU_DINs(0);
					when A_CONFIG_DRS		=> CONFIG_DRSs	       		<= MCU_DINs(0);
					when A_CAL_ENABLE		=> CAL_ENABLEs	       		<= MCU_DINs(0);
					when A_BASE_CNT			=> BASE_CNTs	    		<= Conv_Integer(MCU_DINs);
					when A_START_CNT		=> START_CNTs	    		<= Conv_Integer(MCU_DINs);
					when A_DRS_CH_ADDR		=> DRS_CH_ADDRs	    		<= MCU_DINs(3 downto 0);
					
					when A_THRESHOLD		=> THRES_VARS	    		<= Conv_Integer(MCU_DINs);
					when A_WRITE_RAM_ADDR	=> w_addr	    			<= Conv_Integer(MCU_DINs);
					when A_WRITE_RAM_DATA	=> ram_data_ins	    		<= MCU_DINs(15 downto 0);
					when A_VALID_PULSE_CNT	=> VALID_PULSE_CNTs	    	<= Conv_Integer(MCU_DINs);
					when A_SET_CNT_EN		=> SET_CNT_ENs				<= MCU_DINs(0);
					when A_CAL_SINGLE_EN	=> CAL_SINGLE_EN			<= MCU_DINs(0);
					when A_SINGLE_CAL_TRIG	=> SINGLE_CAL_TRIG			<= MCU_DINs(0);
					when A_DRS_CELL			=> slv_DRS_CELL				<= MCU_DINs(10 downto 0);
					when A_DRS_ROI			=> slv_DRS_ROI				<= MCU_DINs(10 downto 0);
					when A_ADC_DLAY			=> slv_ADC_DLAY				<= MCU_DINs( 4 downto 0);

					when others	=> NULL;
				end case;
			else
				CLR_TRIG_VETOs	<= '0';
				--EVE_ENABLEs <= '0'; --
			end if;
		end if;
	end process;
	
	-- convert slv to int
	DRS_CELL <= to_integer(unsigned(slv_DRS_CELL));
	DRS_ROI  <= to_integer(unsigned(slv_DRS_ROI));
	ADC_DLAY <= to_integer(unsigned(slv_ADC_DLAY));
	
end behav;
