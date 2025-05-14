---v3------------Initialization Sequence-------------------
--1. DRS RST on fpga reset
--2. CONFIG REG  			ADDR : 1100		"11111011" DMODE-'1', PLLEN-'1', WSRLOOP-'0'		
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
	  -- b. ROI_TRIG_EN Process : Reads every Channel from 0 to 8 by issuing RSR load
	  -- c. Eve Enable process   : Starts Dwrite and enables event interruptcf
-- Note: Comment ROI during Calibration and Vice versa
-- Note: Select ROI window in PKG file
-- Note: if ROI mode Change DRS_EVENT_SIZE to 300 in ddb.h file else:1024
-- 			SR_CLK Count  = 1032 ADC clks.
--			ADC CLK 33 MHz in phase with SRCLK 33 MHz but 38ns delay 
--			REF CLK 0.488281 MHz
--			FIFO CLK is 66MHz with 38ns Phase Shift
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;
use work.CMVD_DAQ_PKG.all;

entity CMVD_DAQ_LOGIC is
	port
	(
		LCLK		: in std_logic;
		nRST		: in std_logic;
		MCU_ADDR	: in std_logic_vector(7 downto 0);
		MCU_nRD		: in std_logic;
		MCU_nWR		: in std_logic;
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
		DRS_DENABLE : out std_logic; -- low-to-high transition starts the Domino Wave. 
		DRS_DWRITE  : out std_logic; -- Connects the Domino Wave Circuit to the Sampling Cells to enable sampling if high.
		DRS_PLL_LCK : in std_logic;  -- PLL Lock Indicator Output.
		DRS_REF_CLK_GEN : in std_logic; -- 62.5 MHz clock for the generation of drs_ref_clk of 488.28125 kHz
		DRS_REF_clk : out std_logic; -- For Spartan7 FPGA, PLL minimum output frequency is 6.25 MHz
		                              -- Hence need to generate the DRS Ref Clock frequncy in the RTL
		----------------------------------
		-- ADC 
		----------------------------------
		ADC_DATA 	: in std_logic_vector(11 downto 0);--ADC_DATA_WIDTH
		ADC_CLK_IN  : in std_logic;
		ADC_CLK_OUT : out std_logic;
		----------------------------------
		-- Other
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
		LED         : out std_logic_vector(1 downto 0) 		
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
		re            : IN   std_logic;
		q             : OUT  std_logic_vector (15 DOWNTO 0)
	);
end component;

signal TRIG_INs			: std_logic;
signal TRIGs			: std_logic;  
signal CLR_TRIG_VETOs	: std_logic;
signal TMPs				: std_logic; 
signal CLR_TRIG_VETO_DLYDs	: std_logic; 
signal MCU_DINs			: std_logic_vector(31 downto 0);
signal MCU_DOUTs		: std_logic_vector(31 downto 0);
signal EVE_INT			: std_logic;

--pulser
signal test_sig			: std_logic;
signal cnt_en			: std_logic;
signal eve_freqs		: std_logic_vector(31 downto 0);
signal eve_cnts			: std_logic_vector(31 downto 0);
signal SINGLE_CAL_TRIG	: std_logic;

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
signal START_CNT 		: integer RANGE 0 to 1023;
signal BASE_CNT 		: integer RANGE 0 to 100;
signal THRES_VAR		: integer RANGE 0 to 15000;
signal VALID_PULSE_CNT 	: integer RANGE 0 to 1000;
signal START_CNTs		: integer RANGE 0 to 1023;
signal BASE_CNTs		: integer RANGE 0 to 100;
signal THRES_VARS		: integer RANGE 0 to 15000;
signal VALID_PULSE_CNTs	: integer RANGE 0 to 1000;
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

-- Zero Suppression
signal base_line    	: signed(15 downto 0);
signal threshold    	: signed(15 downto 0);
signal peak_sense_cnt   : std_logic_vector(31 downto 0);

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
signal s_DRS_REF_CLK    : std_logic;

signal SET_CNT_ENs		: std_logic := '0';

signal DRS_CELL : integer := 1024; 
signal DRS_ROI  : integer := 300;
signal ADC_DLAY : integer := 9;

signal slv_DRS_CELL : std_logic_vector(10 downto 0); -- 
signal slv_DRS_ROI  : std_logic_vector(10 downto 0);
signal slv_ADC_DLAY : std_logic_vector(4 downto 0);

signal s_TEST_REG1	: std_logic_vector(31 downto 0);
signal s_TEST_REG2	: std_logic_vector(31 downto 0);

begin

	TRIGGER_o <= TRIGGER; -- send the test_sig outside this entity
	FIFO_WR_EN <= FIFO_WEs;
    TIM <= TRIG_IN; 
    TCAL_CTRL <= TCAL_CTRLS;
-----------------------------------------------------------------------------
-- DRS_REF_CLK genertion
-- since the Spartan-7 FPGA cannot generate frequency lower than 6.25MHz, 
-- we need to generate the drs ref clokc in RTL by frequency divider
------------------------------------------------------------------------------

p_drs_ref_clk_gen: process(DRS_REF_CLK_GEN)
    variable count1 : integer range 0 to 200;
begin
    if(DRS_REF_CLK_GEN'event and DRS_REF_CLK_GEN = '1') then
        if(count1 = 128/2) then 
           s_DRS_REF_CLK <= not s_DRS_REF_CLK;
            count1 := 0;
        end if;
        
        count1 := count1 + 1;
       end if;
end process;

DRS_REF_CLK <= s_DRS_REF_CLK;
    
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
		EVE_INT 			<= '0';
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
					
					drs_sample_count 	:= (others => '0'); 
					drs_rd_tmp_count 	:= (others => '0'); 
					adc_sample_count 	:= (others => '0'); 
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
					drs_readout_state  <= ch_read_init; 
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
                    CH_ADDRs			<= CH_ADDRs + "0001";   --uncomment this  line to update values 
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
					--drs_readout_state <= eve_gen; --wait_after_ch_read; --roi_ch_read_init
					drs_readout_state <= roi_ch_read_init;
					drs_sample_count 	:= (others => '0');
					adc_sample_count 	:= (others => '0');
					drs_rd_tmp_count 	:= (others => '0');
					DRS_SRCLK_s 		<= '0';
					ADC_CLK_s 			<= '0';
					ADC_CLK_ENs 		<= '0';
					CH_ADDRs			<= CH_ADDRs + "0001";  ---- abd: uncommented this line to take data from all channels
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
						adc_readout_state   <= wait_state4;
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
				 				 
				if(adc_sample_count > (ADC_DLAY-1) and adc_sample_count < (ADC_SAMPLE_SIZE)) then  --CAL =  1031  ROI =  307 -- Prajj: Originlly was 6 --Prajj: removed -1, added +1, +2
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
				end if;
				
				if(ADC_CLK = '1') then
					adc_sample_count   := adc_sample_count + 1;
				end if; 
				 
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

process(LCLK,nRST,START_CNTs,DRS_RST)
begin
	if(nRST = '0' or DRS_RST = '0')
	then
		START_CNT 		 <= 0;      
		BASE_CNT			 <= 0;
		THRES_VAR		 <= 0;	
		VALID_PULSE_CNT <= 0;

	elsif(LCLK'event and LCLK = '1') then
		START_CNT 		 <= START_CNTs;       -- 1 for full readout  --20 for ROI latency of 600ns
		BASE_CNT 		 <= BASE_CNTs; 
		THRES_VAR       <= THRES_VARS;
		VALID_PULSE_CNT <= VALID_PULSE_CNTs;

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
		--TRIGGER 		<= TRIG_IN; -- MNS: temporarily changed to exit triger in from test_sig to test input pulses
		--TIM 			<= '0'; -- MNS: Commented
		ROI_ENs			<= '0';
		ROI_TRIG_ENs	<= '0';
		READ_SHIFT_ENs	<= DRS_INIT_ENs;
		TRIG_ENs 		<= DRS_READ_ENs;
		ADC_SAMPLE_SIZE <= DRS_CELL + ADC_DLAY;
	end if;
	
end process;

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
			FreeSpace	=> FreeSpaces  
	);

--------------------------------------------------------------------------

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

--------------------------------------------------------------------------
-- USER REGISTERS SECTION
--------------------------------------------------------------------------
	MCU_DINs <= MCU_DATA_IN;
	MCU_DATA_OUT <= MCU_DOUTs;

------------------------------------------------------------------------------
-- Read and write to registers
------------------------------------------------------------------------------
	process(LCLK, nRST)
	begin
		if(nRST = '0')
		then			
		-- put default values of registers here
		CONFIG_DRSs <= '0';
		DRS_CH_ADDRs <= "0000";
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
					when A_READ_FIFO  	 	=> MCU_DOUTs(15 downto 0) <= FIFO_DATAOUTs;           ---read FIFO
					when A_FREE_SPACE  		=> MCU_DOUTs(ADDR_width downto 0) <= FreeSpaces;
					when A_FIFO_TEST		=> MCU_DOUTs(ADDR_width-1 downto 0) <= FIFO_PWPTRs;   -- Can be used to track the wptr of H/W FIFO
					when A_STOP_REG  	 	=> MCU_DOUTs(9 downto 0) <= STOP_REGs;           ---read Stop Reg
					when A_READ_RAM_DATA 	=> MCU_DOUTs(15 downto 0) <= ram_data_out; --abd: uncommenting this to check ram data 
					when A_BASE_LINE		=> MCU_DOUTs <= X"0000" & std_logic_vector(unsigned(base_line));
					when A_CALC_THRESHOLD	=> MCU_DOUTs <= X"0000" & std_logic_vector(unsigned(threshold));
					when A_PEAK_CNT			=> MCU_DOUTs <= peak_sense_cnt;
					when A_EVE_VALID 		=> MCU_DOUTs <= X"0000000" & "000" & EVENT_VALID;
					when A_TEST_REG1		=> MCU_DOUTs <= s_TEST_REG1;
					when A_TEST_REG2		=> MCU_DOUTs <= s_TEST_REG2;
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
					when A_LED  			=> LED      				<= MCU_DINs( 1 downto 0);
					when A_TEST_REG1		=> s_TEST_REG1				<= MCU_DINs;
					when A_TEST_REG2		=> s_TEST_REG2				<= MCU_DINs;

					when others	=> NULL;
				end case;
			else
				CLR_TRIG_VETOs	<= '0';
			end if;
		end if;
	end process;
	
	-- convert slv to int
	DRS_CELL <= to_integer(unsigned(slv_DRS_CELL));
	DRS_ROI  <= to_integer(unsigned(slv_DRS_ROI));
	ADC_DLAY <= to_integer(unsigned(slv_ADC_DLAY));
	
end behav;
