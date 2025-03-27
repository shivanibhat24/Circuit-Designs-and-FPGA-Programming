--------------------------------------------------------------------
--
--	SignalTap II Parameterized Megafunction
--
--  Copyright (C) 2018  Intel Corporation. All rights reserved.
--
--  Your use of Altera Corporation's design tools, logic functions  
--  and other software and tools, and its AMPP partner logic  
--  functions, and any output files from any of the foregoing  
--  (including device programming or simulation files), and any  
--  associated documentation or information are expressly subject  
--  to the terms and conditions of the Altera Program License  
--  Subscription Agreement, Altera MegaCore Function License  
--  Agreement, or other applicable license agreement, including,  
--  without limitation, that your use is for the sole purpose of  
--  programming logic devices manufactured by Altera and sold by  
--  Altera or its authorized distributors.  Please refer to the  
--  applicable agreement for further details. 
--  
--  18.1.0 Build 625 09/12/2018 SJ Standard Edition
--
--
--------------------------------------------------------------------
package sld_signaltap_pack is
	constant SLD_IR_BITS					: natural := 10;	-- Constant value.  DO NOT CHANGE.
end package sld_signaltap_pack;

package sld_signaltap_function_pack is
	function get_interface_assignments( SLD_CREATE_MONITOR_INTERFACE : in natural; SLD_SECTION_ID : in string ) return string;
end package sld_signaltap_function_pack;


library ieee;
use ieee.std_logic_1164.all;
use work.sld_signaltap_pack.all;
use work.sld_signaltap_function_pack.all;


entity sld_signaltap is
	generic 
	(
		lpm_type					: string := "sld_signaltap";

		SLD_NODE_INFO				: natural := 0;		-- The NODE ID to uniquely identify this node on the hub.
		
		SLD_SECTION_ID					: string := "hdl_signaltap_0";	-- This name was chosen so it wouldn't clash with any auto_signaltap_xxx agent(s) from .stp file(s)


		-- Auto generated version definition begin
		SLD_IP_VERSION					: natural := 6;
		SLD_IP_MINOR_VERSION				: natural := 0;
		SLD_COMMON_IP_VERSION				: natural := 0;
		-- Auto generated version definition end

		
		-- ELA Input Width Parameters
		SLD_DATA_BITS				: natural := 1;		-- The ELA data input width in bits
		SLD_TRIGGER_BITS			: natural := 1;		-- The ELA trigger input width in bits
				
		-- Consistency Check Parameters
		SLD_NODE_CRC_BITS			: natural := 32;
		SLD_NODE_CRC_HIWORD			: natural := 41394;	-- High byte of the CRC word
		SLD_NODE_CRC_LOWORD			: natural := 50132;	-- Low byte of the CRC word
		SLD_INCREMENTAL_ROUTING		: natural := 0;		-- Indicate whether incremental CRC register is used

		-- Acquisition Buffer Parameters
		SLD_SAMPLE_DEPTH			: natural := 16;	-- Memory buffer size
		SLD_SEGMENT_SIZE			: natural := 0;	-- Size of each segment
		SLD_RAM_BLOCK_TYPE			: string := "AUTO";	-- Memory buffer type on the device
		SLD_STATE_BITS				: natural := 11;		-- bits needed for state encoding
		
		SLD_BUFFER_FULL_STOP		: natural := 1;		-- if set to 1, once last segment full auto stops acquisition
		
		--obsoleted
		SLD_MEM_ADDRESS_BITS		: natural := 7;		-- Memory buffer address width log2(SLD_SAMPLE_DEPTH)
		SLD_DATA_BIT_CNTR_BITS		: natural := 4;		-- = ceil(log2(SLD_DATA_BITS)) + 1
		
		-- Trigger Control Parameters
		SLD_TRIGGER_LEVEL			: natural := 10;		-- Number of trigger levels that will be used to stop the data acquisition
		SLD_TRIGGER_IN_ENABLED		: natural := 0;		-- Indicate whether to generate the trigger_in logic.  Generate if it is 1; not, otherwise.
		SLD_HPS_TRIGGER_IN_ENABLED	: natural := 0;		-- Indicate whether to generate the trigger_in logic from HPS.  Generate if it is 1; not, otherwise.
		SLD_HPS_TRIGGER_OUT_ENABLED	: natural := 0;		-- Indicate whether to generate the trigger_out logic driving HPS.  Generate if it is 1; not, otherwise.
		SLD_HPS_EVENT_ENABLED		: natural := 0;		-- Indicate whether to generate the event logic driving HPS.  Generate if it is 1; not, otherwise.
		SLD_HPS_EVENT_ID			: natural := 0;		-- Specifies the event line index, if event logic is created driving HPS.
		SLD_ADVANCED_TRIGGER_ENTITY	: string := "basic";	-- Comma delimited entity name for each advanced trigger level, or "basic" if level is using standard mode
		SLD_TRIGGER_LEVEL_PIPELINE	: natural := 1;		-- Length of trigger level pipeline.
		SLD_TRIGGER_PIPELINE	: natural := 0;		-- Length of pipeline of segment/final triggers from ELA to Buffer Manager 
		SLD_RAM_PIPELINE : natural := 0;					-- Length of pipeline into RAM ports
		SLD_COUNTER_PIPELINE : natural := 0;		-- Option to add pipeline register for counter equality. Zero for no pipelining
		SLD_ENABLE_ADVANCED_TRIGGER	: natural := 0;		-- Indicate whether to deploy multi-level basic trigger level or advanced trigger level
		SLD_ADVANCED_TRIGGER_1		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_2		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_3		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_4		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_5		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_6		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_7		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_8		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_9		: string := "NONE";	-- advanced trigger expression
		SLD_ADVANCED_TRIGGER_10		: string := "NONE";	-- advanced trigger expression
		SLD_INVERSION_MASK_LENGTH	: integer := 1;		-- length of inversion mask
		SLD_INVERSION_MASK			: std_logic_vector := "0"; --inversion mask
		SLD_POWER_UP_TRIGGER		: natural := 0;		-- power-up trigger mode
		SLD_STATE_FLOW_MGR_ENTITY	: string := "state_flow_mgr_entity.vhd";	--name of generated entity controlling state flow
		SLD_STATE_FLOW_USE_GENERATED	: natural := 0;
		SLD_CURRENT_RESOURCE_WIDTH	: natural := 0;
		SLD_ATTRIBUTE_MEM_MODE		: string := "OFF";
		
		--Storage Qualifier Parameters
		SLD_STORAGE_QUALIFIER_BITS	: natural := 1;
		SLD_STORAGE_QUALIFIER_GAP_RECORD : natural := 0;
		SLD_STORAGE_QUALIFIER_MODE	: string := "OFF";
		SLD_STORAGE_QUALIFIER_ENABLE_ADVANCED_CONDITION	: natural := 0;		-- Indicate whether to deploy multi-level basic condition level or advanced condition level
		SLD_STORAGE_QUALIFIER_INVERSION_MASK_LENGTH	: natural := 0;
		SLD_STORAGE_QUALIFIER_ADVANCED_CONDITION_ENTITY	: string := "basic";
		SLD_STORAGE_QUALIFIER_PIPELINE : natural := 0;
		
		SLD_CREATE_MONITOR_INTERFACE 	: natural := 0;		-- This default value should be used when sld_signaltap is instantiated in HDL; otherwise, a different value is set by synthesizer accordingly.
		SLD_USE_JTAG_SIGNAL_ADAPTER 	: natural := 1		-- This default value should be used when sld_signaltap is instantiated in HDL; otherwise, a different value is set by synthesizer accordingly.
				
	);

	port 
	(
		acq_clk						: in std_logic;		-- The acquisition clock
		acq_data_in					: in std_logic_vector (SLD_DATA_BITS-1 downto 0) := (others => '0');	-- The data input source to be acquired.
		acq_trigger_in				: in std_logic_vector (SLD_TRIGGER_BITS-1 downto 0) := (others => '0');	-- The trigger input source to be analyzed.
		acq_storage_qualifier_in	: in std_logic_vector (SLD_STORAGE_QUALIFIER_BITS-1 downto 0) := (others => '0'); --the storage qualifier condition module input source signals
		trigger_in					: in std_logic := '0';		-- The trigger-in source
		crc							: in std_logic_vector (SLD_NODE_CRC_BITS-1 downto 0) := (others => '0');	-- The incremental CRC data input
		storage_enable				: in std_logic := '0';		-- Storage Qualifier control when in PORT mode
		raw_tck						: in std_logic := '0';		-- Real TCK from the JTAG HUB.
		tdi							: in std_logic := '0';		-- TDI from the JTAG HUB.  It gets the data from JTAG TDI.
		usr1						: in std_logic := '0';		-- USR1 from the JTAG HUB.  Indicate whether it is in USER1 or USER0
		jtag_state_cdr				: in std_logic := '0';		-- CDR from the JTAG HUB.  Indicate whether it is in Capture_DR state.
		jtag_state_sdr				: in std_logic := '0';		-- SDR from the JTAG HUB.  Indicate whether it is in Shift_DR state.
		jtag_state_e1dr				: in std_logic := '0';		-- EDR from the JTAG HUB.  Indicate whether it is in Exit1_DR state.
		jtag_state_udr				: in std_logic := '0';		-- UDR from the JTAG HUB.  Indicate whether it is in Update_DR state.
		jtag_state_uir				: in std_logic := '0';		-- UIR from the JTAG HUB.  Indicate whether it is in Update_IR state.
		clr							: in std_logic := '0';		-- CLR from the JTAG HUB.  Indicate whether hub request global reset.
		ena							: in std_logic := '0';		-- ENA from the JTAG HUB.  Indicate whether this node should establish JTAG chain.
		ir_in						: in std_logic_vector (SLD_IR_BITS-1 downto 0) := (others => '0');	-- IR_OUT from the JTAG HUB.  It hold the current instruction for the node.
		
		-- (Begin extra ports) QSYS requires that both ends of a conduit match up so these ports have been added
		-- to make our conduit match the standard one
		jtag_state_tlr 				: in std_logic := '0';
		jtag_state_rti 				: in std_logic := '0';
		jtag_state_sdrs				: in std_logic := '0';
		jtag_state_pdr 				: in std_logic := '0';
		jtag_state_e2dr				: in std_logic := '0';
		jtag_state_sirs				: in std_logic := '0';
		jtag_state_cir 				: in std_logic := '0';
		jtag_state_sir				: in std_logic := '0';
		jtag_state_e1ir				: in std_logic := '0';
		jtag_state_pir 				: in std_logic := '0';
		jtag_state_e2ir				: in std_logic := '0';
		tms							: in std_logic := '0';
		clrn						: in std_logic := '0';
		irq							: out std_logic;
		vir_tdi						: in std_logic := '0';
		-- (End extra ports)
		
		vcc							: out std_logic;
		gnd							: out std_logic;
		
		ir_out						: out std_logic_vector (SLD_IR_BITS-1 downto 0);	-- IR_IN to the JTAG HUB.  It supplies the updated value for IR_IN.
		tdo							: out std_logic;	-- TDO to the JTAG HUB.  It supplies the data to JTAG TDO.

		acq_data_out				: out std_logic_vector (SLD_DATA_BITS-1 downto 0);	-- SHIFT to the JTAG HUB.  Indicate whether it is in shift state.
		acq_trigger_out				: out std_logic_vector (SLD_TRIGGER_BITS-1 downto 0);	-- SHIFT to the JTAG HUB.  Indicate whether it is in shift state.
		trigger_out					: out std_logic 	-- Indicating when a match occurred.	-- SHIFT from the JTAG HUB.  Indicate whether it is in shift state.
	);

end entity sld_signaltap;

architecture rtl of sld_signaltap is

	attribute altera_attribute : string;
	attribute altera_attribute of rtl: architecture is "-name message_disable 13410"
													 & 	get_interface_assignments( SLD_CREATE_MONITOR_INTERFACE, SLD_SECTION_ID );						 
	
	--
	-- Constant Definitions:
	--
	
	
	constant IP_MAJOR_VERSION			: natural := SLD_IP_VERSION;
	constant IP_MINOR_VERSION			: natural := SLD_IP_MINOR_VERSION;
	constant COMMON_IP_VERSION			: natural := SLD_COMMON_IP_VERSION;
	
	
	component sld_signaltap_impl is
		generic 
		(


		-- Auto generated version definition begin
		SLD_IP_VERSION					: natural := 6;
		SLD_IP_MINOR_VERSION				: natural := 0;
		SLD_COMMON_IP_VERSION				: natural := 0;
		-- Auto generated version definition end

			
			-- ELA Input Width Parameters
			SLD_DATA_BITS				: natural := 8;		-- The ELA data input width in bits
			SLD_TRIGGER_BITS			: natural := 8;		-- The ELA trigger input width in bits
			
			-- Consistency Check Parameters
			SLD_NODE_CRC_BITS			: natural := 32;
			SLD_NODE_CRC_HIWORD			: natural := 41394;	-- High byte of the CRC word
			SLD_NODE_CRC_LOWORD			: natural := 50132;	-- Low byte of the CRC word
			SLD_INCREMENTAL_ROUTING		: natural := 0;		-- Indicate whether incremental CRC register is used

			-- Acquisition Buffer Parameters
			SLD_SAMPLE_DEPTH			: natural := 128;	-- Memory buffer size
			SLD_SEGMENT_SIZE			: natural := 0;	-- Segment Size
			SLD_RAM_BLOCK_TYPE			: string := "AUTO";	-- Memory buffer type on the device
			SLD_STATE_BITS				: natural := 4;		-- bits necessary to store state
			
			SLD_BUFFER_FULL_STOP		: natural := 0;		-- if set to 1, once last segment full auto stops acquisition
			
			
			-- Trigger Control Parameters
			SLD_TRIGGER_LEVEL			: natural := 1;		-- Number of trigger levels that will be used to stop the data acquisition
			SLD_TRIGGER_IN_ENABLED		: natural := 1;		-- Indicate whether to generate the trigger_in logic.  Generate if it is 1; not, otherwise.
			SLD_HPS_TRIGGER_IN_ENABLED	: natural := 0;		-- Indicate whether to generate the trigger_in logic from HPS.  Generate if it is 1; not, otherwise.
			SLD_HPS_TRIGGER_OUT_ENABLED	: natural := 0;		-- Indicate whether to generate the trigger_out logic driving HPS.  Generate if it is 1; not, otherwise.
			SLD_HPS_EVENT_ENABLED		: natural := 0;		-- Indicate whether to generate the event logic driving HPS.  Generate if it is 1; not, otherwise.
			SLD_HPS_EVENT_ID			: natural := 0;		-- Specifies the event line index, if event logic is created driving HPS.
			SLD_ADVANCED_TRIGGER_ENTITY	: string := "basic";	-- Comma delimited entity name for each advanced trigger level, or "basic" if level is using standard mode
			SLD_TRIGGER_LEVEL_PIPELINE	: natural := 1;		-- Length of trigger level pipeline.
			SLD_TRIGGER_PIPELINE	: natural := 0;		-- Length of pipeline of segment/final triggers from ELA to Buffer Manager 
			SLD_RAM_PIPELINE : natural := 0;					-- Length of pipeline into RAM ports
			SLD_COUNTER_PIPELINE : natural := 0;		-- Option to add pipeline register for counter equality. Zero for no pipelining
			SLD_ENABLE_ADVANCED_TRIGGER	: natural := 0;		-- Indicate whether to deploy multi-level basic trigger level or advanced trigger level
			SLD_ADVANCED_TRIGGER_1		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_2		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_3		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_4		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_5		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_6		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_7		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_8		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_9		: string := "NONE";	-- advanced trigger expression
			SLD_ADVANCED_TRIGGER_10		: string := "NONE";	-- advanced trigger expression
			SLD_INVERSION_MASK_LENGTH	: integer := 1;		-- length of inversion mask
			SLD_INVERSION_MASK			: std_logic_vector := "0"; --inversion mask
			SLD_POWER_UP_TRIGGER		: natural := 0;		-- power-up trigger mode
			SLD_STATE_FLOW_MGR_ENTITY	: string := "state_flow_mgr_entity.vhd";	--name of generated entity controlling state flow
			SLD_STATE_FLOW_USE_GENERATED	: natural := 0;
			SLD_CURRENT_RESOURCE_WIDTH	: natural := 0;
			SLD_ATTRIBUTE_MEM_MODE		: string := "OFF";
			
			--Storage Qualifier Parameters
			SLD_STORAGE_QUALIFIER_BITS	: natural := 1;
			SLD_STORAGE_QUALIFIER_GAP_RECORD : natural := 0;
			SLD_STORAGE_QUALIFIER_MODE	: string := "OFF";
			SLD_STORAGE_QUALIFIER_ENABLE_ADVANCED_CONDITION : natural := 0;
			SLD_STORAGE_QUALIFIER_INVERSION_MASK_LENGTH	: natural := 0;
			SLD_STORAGE_QUALIFIER_ADVANCED_CONDITION_ENTITY	: string := "basic";
			SLD_STORAGE_QUALIFIER_PIPELINE : natural := 0;
			SLD_DISABLE_TDO_CRC_GEN : natural := 0
					
		); 

		port 
		(
			acq_clk						: in std_logic;		-- The acquisition clock
			acq_data_in					: in std_logic_vector (SLD_DATA_BITS-1 downto 0) := (others => '0');	-- The data input source to be acquired.
			acq_trigger_in				: in std_logic_vector (SLD_TRIGGER_BITS-1 downto 0) := (others => '0');	-- The trigger input source to be analyzed.
			acq_storage_qualifier_in	: in std_logic_vector (SLD_STORAGE_QUALIFIER_BITS-1 downto 0) := (others => '0'); --storage qualifier input to condition modules
			trigger_in					: in std_logic := '0';		-- The trigger-in source
			crc							: in std_logic_vector (SLD_NODE_CRC_BITS-1 downto 0) := (others => '0');	-- The incremental CRC data input
			storage_enable				: in std_logic := '0';		-- Storage Qualifier control signal for Port mode
			raw_tck						: in std_logic := '0';		-- Real TCK from the JTAG HUB.
			tdi							: in std_logic := '0';		-- TDI from the JTAG HUB.  It gets the data from JTAG TDI.
			usr1						: in std_logic := '0';		-- USR1 from the JTAG HUB.  Indicate whether it is in USER1 or USER0
			jtag_state_cdr				: in std_logic := '0';		-- CDR from the JTAG HUB.  Indicate whether it is in Capture_DR state.
			jtag_state_sdr				: in std_logic := '0';		-- SDR from the JTAG HUB.  Indicate whether it is in Shift_DR state.
			jtag_state_e1dr				: in std_logic := '0';		-- EDR from the JTAG HUB.  Indicate whether it is in Exit1_DR state.
			jtag_state_udr				: in std_logic := '0';		-- UDR from the JTAG HUB.  Indicate whether it is in Update_DR state.
			jtag_state_uir				: in std_logic := '0';		-- UIR from the JTAG HUB.  Indicate whether it is in Update_IR state.
			clr							: in std_logic := '0';		-- CLR from the JTAG HUB.  Indicate whether hub request global reset.
			ena							: in std_logic := '0';		-- ENA from the JTAG HUB.  Indicate whether this node should establish JTAG chain.
			ir_in						: in std_logic_vector (SLD_IR_BITS-1 downto 0) := (others => '0');	-- IR_OUT from the JTAG HUB.  It hold the current instruction for the node.
			
			ir_out						: out std_logic_vector (SLD_IR_BITS-1 downto 0);	-- IR_IN to the JTAG HUB.  It supplies the updated value for IR_IN.
			tdo							: out std_logic;	-- TDO to the JTAG HUB.  It supplies the data to JTAG TDO.

			acq_data_out				: out std_logic_vector (SLD_DATA_BITS-1 downto 0);	-- SHIFT to the JTAG HUB.  Indicate whether it is in shift state.
			acq_trigger_out				: out std_logic_vector (SLD_TRIGGER_BITS-1 downto 0);	-- SHIFT to the JTAG HUB.  Indicate whether it is in shift state.
			trigger_out					: out std_logic 	-- Indicating when a match occurred.	-- SHIFT from the JTAG HUB.  Indicate whether it is in shift state.
		);

	end component sld_signaltap_impl;

	component sld_jtag_endpoint_adapter
		generic
		(
			sld_ir_width				: natural;
			sld_auto_instance_index		: string;
			sld_node_info_internal		: natural
		);
		port
		(
			raw_tck										: in std_logic := '0';
			raw_tms                                     : in std_logic := '0';
			tdi                                         : in std_logic := '0';
			jtag_state_tlr                              : in std_logic := '0';
			jtag_state_rti                              : in std_logic := '0';
			jtag_state_sdrs                             : in std_logic := '0';
			jtag_state_cdr                              : in std_logic := '0';
			jtag_state_sdr                              : in std_logic := '0';
			jtag_state_e1dr                             : in std_logic := '0';
			jtag_state_pdr                              : in std_logic := '0';
			jtag_state_e2dr                             : in std_logic := '0';
			jtag_state_udr                              : in std_logic := '0';
			jtag_state_sirs                             : in std_logic := '0';
			jtag_state_cir                              : in std_logic := '0';
			jtag_state_sir                              : in std_logic := '0';
			jtag_state_e1ir                             : in std_logic := '0';
			jtag_state_pir                              : in std_logic := '0';
			jtag_state_e2ir                             : in std_logic := '0';
			jtag_state_uir                              : in std_logic := '0';
			usr1                                        : in std_logic := '0';
			clr                                         : in std_logic := '0';
			ena                                         : in std_logic := '0';
			ir_in                                       : in std_logic_vector(sld_ir_width - 1 downto 0) := (others=>'0');

			tdo                                         : out std_logic;
			ir_out          	                        : out std_logic_vector(sld_ir_width - 1 downto 0);

			adapted_tck                                 : out std_logic;
			adapted_tms                                 : out std_logic;
			adapted_tdi                                 : out std_logic;
			adapted_jtag_state_tlr                      : out std_logic;
			adapted_jtag_state_rti                      : out std_logic;
			adapted_jtag_state_sdrs                     : out std_logic;
			adapted_jtag_state_cdr                      : out std_logic;
			adapted_jtag_state_sdr                      : out std_logic;
			adapted_jtag_state_e1dr                     : out std_logic;
			adapted_jtag_state_pdr                      : out std_logic;
			adapted_jtag_state_e2dr                     : out std_logic;
			adapted_jtag_state_udr                      : out std_logic;
			adapted_jtag_state_sirs                     : out std_logic;
			adapted_jtag_state_cir                      : out std_logic;
			adapted_jtag_state_sir                      : out std_logic;
			adapted_jtag_state_e1ir                     : out std_logic;
			adapted_jtag_state_pir                      : out std_logic;
			adapted_jtag_state_e2ir                     : out std_logic;
			adapted_jtag_state_uir                      : out std_logic;
			adapted_usr1                                : out std_logic;
			adapted_clr                                 : out std_logic;
			adapted_ena                                 : out std_logic;
			adapted_ir_in                               : out std_logic_vector(sld_ir_width - 1 downto 0);

			adapted_tdo                                 : in std_logic := '0';
			adapted_ir_out                              : in std_logic_vector(sld_ir_width - 1 downto 0) := (others=>'0')
		);
	end component sld_jtag_endpoint_adapter;

	-- Input Fanout Limit Register --
	signal acq_data_in_reg				: std_logic_vector (SLD_DATA_BITS-1 downto 0);
	signal acq_trigger_in_reg			: std_logic_vector (SLD_TRIGGER_BITS-1 downto 0);
	signal trigger_in_reg				: std_logic;
	
	-- adapted sld_hub signals
	signal adapted_tck							: std_logic;		-- Real TCK from the JTAG HUB.  @no_decl
	signal adapted_tdi							: std_logic;		-- TDI from the JTAG HUB.  It gets the data from JTAG TDI.  @no_decl
	signal adapted_usr1							: std_logic;		-- USR1 from the JTAG HUB.  Indicate whether it is in USER1 or USER0  @no_decl
	signal adapted_jtag_state_cdr				: std_logic;		-- CDR from the JTAG HUB.  Indicate whether it is in Capture_DR state.  @no_decl
	signal adapted_jtag_state_sdr				: std_logic;		-- SDR from the JTAG HUB.  Indicate whether it is in Shift_DR state.  @no_decl
	signal adapted_jtag_state_e1dr				: std_logic;		-- EDR from the JTAG HUB.  Indicate whether it is in Exit1_DR state.  @no_decl
	signal adapted_jtag_state_udr				: std_logic;		-- UDR from the JTAG HUB.  Indicate whether it is in Update_DR state.  @no_decl
	signal adapted_jtag_state_uir				: std_logic;		-- UIR from the JTAG HUB.  Indicate whether it is in Update_IR state.  @no_decl
	signal adapted_clr							: std_logic;		-- CLR from the JTAG HUB.  Indicate whether hub request global reset.  @no_decl
	signal adapted_ena							: std_logic;		-- ENA from the JTAG HUB.  Indicate whether this node should establish JTAG chain.  @no_decl
	signal adapted_ir_in						: std_logic_vector (SLD_IR_BITS-1 downto 0);	-- IR_OUT from the JTAG HUB.  It hold the current instruction for the node.  @no_decl
	signal adapted_ir_out						: std_logic_vector (SLD_IR_BITS-1 downto 0);	-- IR_IN to the JTAG HUB.  It supplies the updated value for IR_IN.  @no_decl
	signal adapted_tdo							: std_logic;		-- TDO to the JTAG HUB.  It supplies the data to JTAG TDO.  @no_decl
begin


	-- Auto generated version assertion begin
	-- Assertion fails when version of the entity is older than the required
	assert (IP_MAJOR_VERSION <= 6 or ( IP_MAJOR_VERSION = 6 and IP_MINOR_VERSION <= 0 ))
	report "The design file sld_signaltap.vhd was released with Quartus Prime software Version 18.1.0 and is not compatible with the current version of the Quartus Prime software.  Remove the design file from your project and recompile."
	severity FAILURE;

	-- Assertion fails when version of the entity is newer than the required
	assert (IP_MAJOR_VERSION >= 6 or ( IP_MAJOR_VERSION = 6 and IP_MINOR_VERSION >= 0 ))
	report "The design file sld_signaltap.vhd is released with Quartus Prime software Version 18.1.0. It is not compatible with the parent entity. If you generated the parent entity using the Signal Tap megawizard, then you must update the parent entity using the megawizard in the current release."
	severity FAILURE;
	-- Auto generated version definition end


	-- For use with incremental route CRC connections
	vcc <= '1';
	gnd <= '0';
	irq <= '0';
	
	--------------------------------------------------------------
	-- Register all user signals to limit fanout of source      --
	--------------------------------------------------------------
	process(acq_clk)
	begin
		if (acq_clk'EVENT and acq_clk = '1') then
			acq_data_in_reg <= acq_data_in;
			acq_trigger_in_reg <= acq_trigger_in;
		end if;
	end process;

	gen_trigger_in_enable: 
	if (SLD_TRIGGER_IN_ENABLED = 1) generate
		process(acq_clk)
		begin
			if (acq_clk'EVENT and acq_clk = '1') then
				trigger_in_reg <= trigger_in;
			end if;
		end process;
	end generate;

	gen_trigger_in_disable: 
	if (SLD_TRIGGER_IN_ENABLED = 0) generate
		trigger_in_reg <= '0';
	end generate;
	
	sld_signaltap_body : sld_signaltap_impl
		generic map
		(
			SLD_DATA_BITS				=> SLD_DATA_BITS,
			SLD_TRIGGER_BITS			=> SLD_TRIGGER_BITS,
			SLD_NODE_CRC_BITS			=> SLD_NODE_CRC_BITS,
			SLD_NODE_CRC_HIWORD			=> SLD_NODE_CRC_HIWORD,
			SLD_NODE_CRC_LOWORD			=> SLD_NODE_CRC_LOWORD,
			SLD_INCREMENTAL_ROUTING		=> SLD_INCREMENTAL_ROUTING,
			SLD_SAMPLE_DEPTH			=> SLD_SAMPLE_DEPTH,
			SLD_SEGMENT_SIZE			=> SLD_SEGMENT_SIZE,
			SLD_RAM_BLOCK_TYPE			=> SLD_RAM_BLOCK_TYPE,
			SLD_TRIGGER_LEVEL			=> SLD_TRIGGER_LEVEL,
			SLD_TRIGGER_IN_ENABLED		=> SLD_TRIGGER_IN_ENABLED,
			SLD_HPS_TRIGGER_IN_ENABLED	=> SLD_HPS_TRIGGER_IN_ENABLED,
			SLD_HPS_TRIGGER_OUT_ENABLED	=> SLD_HPS_TRIGGER_OUT_ENABLED,
			SLD_HPS_EVENT_ENABLED		=> SLD_HPS_EVENT_ENABLED,
			SLD_HPS_EVENT_ID			=> SLD_HPS_EVENT_ID,
			SLD_ADVANCED_TRIGGER_ENTITY	=> SLD_ADVANCED_TRIGGER_ENTITY,
			SLD_TRIGGER_LEVEL_PIPELINE	=> SLD_TRIGGER_LEVEL_PIPELINE,
			SLD_TRIGGER_PIPELINE	=> SLD_TRIGGER_PIPELINE,
			SLD_RAM_PIPELINE => SLD_RAM_PIPELINE,
			SLD_COUNTER_PIPELINE => SLD_COUNTER_PIPELINE,
			SLD_ENABLE_ADVANCED_TRIGGER	=> SLD_ENABLE_ADVANCED_TRIGGER,
			SLD_ADVANCED_TRIGGER_1		=> SLD_ADVANCED_TRIGGER_1,
			SLD_ADVANCED_TRIGGER_2		=> SLD_ADVANCED_TRIGGER_2,
			SLD_ADVANCED_TRIGGER_3		=> SLD_ADVANCED_TRIGGER_3,
			SLD_ADVANCED_TRIGGER_4		=> SLD_ADVANCED_TRIGGER_4,
			SLD_ADVANCED_TRIGGER_5		=> SLD_ADVANCED_TRIGGER_5,
			SLD_ADVANCED_TRIGGER_6		=> SLD_ADVANCED_TRIGGER_6,
			SLD_ADVANCED_TRIGGER_7		=> SLD_ADVANCED_TRIGGER_7,
			SLD_ADVANCED_TRIGGER_8		=> SLD_ADVANCED_TRIGGER_8,
			SLD_ADVANCED_TRIGGER_9		=> SLD_ADVANCED_TRIGGER_9,
			SLD_ADVANCED_TRIGGER_10		=> SLD_ADVANCED_TRIGGER_10,
			SLD_INVERSION_MASK_LENGTH	=> SLD_INVERSION_MASK_LENGTH,
			SLD_INVERSION_MASK			=> SLD_INVERSION_MASK,
			SLD_POWER_UP_TRIGGER		=> SLD_POWER_UP_TRIGGER,
			SLD_STATE_BITS				=> SLD_STATE_BITS,
			SLD_STATE_FLOW_MGR_ENTITY	=> SLD_STATE_FLOW_MGR_ENTITY,
			SLD_STATE_FLOW_USE_GENERATED	=> SLD_STATE_FLOW_USE_GENERATED,
			SLD_BUFFER_FULL_STOP		=> SLD_BUFFER_FULL_STOP,
			SLD_CURRENT_RESOURCE_WIDTH	=> SLD_CURRENT_RESOURCE_WIDTH,
			SLD_ATTRIBUTE_MEM_MODE		=> SLD_ATTRIBUTE_MEM_MODE,
			SLD_STORAGE_QUALIFIER_BITS	=> SLD_STORAGE_QUALIFIER_BITS,
			SLD_STORAGE_QUALIFIER_GAP_RECORD	=> SLD_STORAGE_QUALIFIER_GAP_RECORD,
			SLD_STORAGE_QUALIFIER_MODE	=> SLD_STORAGE_QUALIFIER_MODE,
			SLD_STORAGE_QUALIFIER_ENABLE_ADVANCED_CONDITION => SLD_STORAGE_QUALIFIER_ENABLE_ADVANCED_CONDITION,
			SLD_STORAGE_QUALIFIER_INVERSION_MASK_LENGTH	=> SLD_STORAGE_QUALIFIER_INVERSION_MASK_LENGTH,
			SLD_STORAGE_QUALIFIER_ADVANCED_CONDITION_ENTITY => SLD_STORAGE_QUALIFIER_ADVANCED_CONDITION_ENTITY,
			SLD_STORAGE_QUALIFIER_PIPELINE	=> SLD_STORAGE_QUALIFIER_PIPELINE
		)
		port map
		(
			acq_clk						=> acq_clk,
			acq_data_in					=> acq_data_in_reg,
			acq_trigger_in				=> acq_trigger_in_reg,
			acq_storage_qualifier_in	=> acq_storage_qualifier_in,
			storage_enable				=> storage_enable,
			trigger_in					=> trigger_in_reg,
			crc							=> crc,
			raw_tck						=> adapted_tck,
			tdi							=> adapted_tdi,
			usr1						=> adapted_usr1,
			jtag_state_cdr				=> adapted_jtag_state_cdr,
			jtag_state_sdr				=> adapted_jtag_state_sdr,
			jtag_state_e1dr				=> adapted_jtag_state_e1dr,
			jtag_state_udr				=> adapted_jtag_state_udr,
			jtag_state_uir				=> adapted_jtag_state_uir,
			clr							=> adapted_clr,
			ena							=> adapted_ena,
			ir_in						=> adapted_ir_in,
			ir_out						=> adapted_ir_out,
			tdo							=> adapted_tdo,
			acq_data_out				=> acq_data_out,
			acq_trigger_out				=> acq_trigger_out,
			trigger_out					=> trigger_out
		);

	gen_jtag_signal_adapter:
	if (SLD_USE_JTAG_SIGNAL_ADAPTER = 1) generate
		jtag_signal_adapter: sld_jtag_endpoint_adapter
			generic map
			(
				sld_ir_width			=> SLD_IR_BITS,
				sld_auto_instance_index	=> "yes",
				sld_node_info_internal	=> SLD_NODE_INFO
			)
			port map
			(
				raw_tck					=> raw_tck,
				tdi						=> tdi,
				usr1					=> usr1,
				ena						=> ena,
				jtag_state_cdr			=> jtag_state_cdr,
				jtag_state_sdr			=> jtag_state_sdr,
				jtag_state_e1dr			=> jtag_state_e1dr,
				jtag_state_udr			=> jtag_state_udr,
				jtag_state_uir			=> jtag_state_uir,
				clr						=> clr,
				ir_in					=> ir_in,
				ir_out					=> ir_out,
				tdo						=> tdo,
				
				adapted_tck						=> adapted_tck,
				adapted_tdi						=> adapted_tdi,
				adapted_usr1					=> adapted_usr1,
				adapted_ena						=> adapted_ena,
				adapted_jtag_state_cdr			=> adapted_jtag_state_cdr,
				adapted_jtag_state_sdr			=> adapted_jtag_state_sdr,
				adapted_jtag_state_e1dr			=> adapted_jtag_state_e1dr,
				adapted_jtag_state_udr			=> adapted_jtag_state_udr,
				adapted_jtag_state_uir			=> adapted_jtag_state_uir,
				adapted_clr						=> adapted_clr,
				adapted_ir_in					=> adapted_ir_in,
				adapted_ir_out					=> adapted_ir_out,
				adapted_tdo						=> adapted_tdo
			);
	end generate;
		
	gen_direct_jtag_signals:
	if (SLD_USE_JTAG_SIGNAL_ADAPTER /= 1) generate
		adapted_tck						<= raw_tck;
		adapted_tdi						<= tdi;
		adapted_usr1					<= usr1;
		adapted_ena						<= ena;
		adapted_jtag_state_cdr			<= jtag_state_cdr;
		adapted_jtag_state_sdr			<= jtag_state_sdr;
		adapted_jtag_state_e1dr			<= jtag_state_e1dr;
		adapted_jtag_state_udr			<= jtag_state_udr;
		adapted_jtag_state_uir			<= jtag_state_uir;
		adapted_clr						<= clr;
		adapted_ir_in					<= ir_in;
		ir_out							<= adapted_ir_out;
		tdo								<= adapted_tdo;
	end generate;
end architecture rtl;

package body sld_signaltap_function_pack is
	
	function get_interface_assignments( SLD_CREATE_MONITOR_INTERFACE: natural; SLD_SECTION_ID : string ) return string is 
		constant	prev_string_terminator : string := "; ";
		constant	monitor_interface_spec : string := "-name INTERFACE_TYPE ""altera:instrumentation:fabric_monitor:1.0"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""acq_clk"" -to ""acq_clk"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""acq_data_in"" -to ""acq_data_in"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""acq_trigger_in"" -to ""acq_trigger_in"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""acq_storage_qualifier_in"" -to ""acq_storage_qualifier_in"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""trigger_in"" -to ""trigger_in"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""storage_enable"" -to ""storage_enable"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""trigger_out"" -to ""trigger_out"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""crc"" -to ""crc"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""vcc"" -to ""vcc"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACE_ROLE ""gnd"" -to ""gnd"" -section_id " & SLD_SECTION_ID & "; "
													 & "-name INTERFACES "
													 & """"
													 & "{                                                                "
													 & "    'version' : '1',                                             "
													 & "    'interfaces' : [                                             "
													 & "        {                                                        "
													 & "            'type' : 'altera:instrumentation:fabric_monitor:1.0',"
													 & "            'ports' : [                                          "
													 & "                {                                                "
													 & "                    'name' : 'acq_clk',                          "
													 & "                    'role' : 'acq_clk'                           "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'acq_data_in',                      "
													 & "                    'role' : 'acq_data_in'                       "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'acq_trigger_in',                   "
													 & "                    'role' : 'acq_trigger_in'                    "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'acq_storage_qualifier_in',         "
													 & "                    'role' : 'acq_storage_qualifier_in'          "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'trigger_in',                       "
													 & "                    'role' : 'trigger_in'                        "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'storage_enable',                   "
													 & "                    'role' : 'storage_enable'                    "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'trigger_out',                      "
													 & "                    'role' : 'trigger_out'                       "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'crc',                              "
													 & "                    'role' : 'crc'                               "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'vcc',                              "
													 & "                    'role' : 'vcc'                               "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'gnd',                              "
													 & "                    'role' : 'gnd'                               "
													 & "                }                                                "
													 & "            ],                                                   "
													 & "            'parameters' : [                                     "
													 & "                {                                                "
													 & "                    'name' : 'SECTION_ID',                       "
													 & "                    'value' : '" & SLD_SECTION_ID & "'           "
													 & "                }                                                "
													 & "            ]                                                    "
													 & "        }                                                        "
													 & "    ]                                                            "
													 & "}                                                                "
													 & """ -to | ";
		constant	stp_hdl_interface_spec : string  := "-name INTERFACES "
													 & """"
													 & "{                                                                "
													 & "    'version' : '1',                                             "
													 & "    'interfaces' : [                                             "
													 & "        {                                                        "
													 & "            'type' : 'altera:instrumentation:signaltap_hdl:1.0',  "
													 & "            'ports' : [                                          "
													 & "                {                                                "
													 & "                    'name' : 'acq_clk',                          "
													 & "                    'role' : 'acq_clk'                           "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'acq_data_in',                      "
													 & "                    'role' : 'acq_data_in'                       "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'acq_trigger_in',                   "
													 & "                    'role' : 'acq_trigger_in'                    "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'acq_storage_qualifier_in',         "
													 & "                    'role' : 'acq_storage_qualifier_in'          "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'trigger_in',                       "
													 & "                    'role' : 'trigger_in'                        "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'storage_enable',                   "
													 & "                    'role' : 'storage_enable'                    "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'trigger_out',                      "
													 & "                    'role' : 'trigger_out'                       "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'crc',                              "
													 & "                    'role' : 'crc'                               "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'vcc',                              "
													 & "                    'role' : 'vcc'                               "
													 & "                },                                               "
													 & "                {                                                "
													 & "                    'name' : 'gnd',                              "
													 & "                    'role' : 'gnd'                               "
													 & "                }                                                "
													 & "            ],                                                   "
													 & "            'parameters' : [                                     "
													 & "                {                                                "
													 & "                    'name' : 'SECTION_ID',                       "
													 & "                    'value' : '" & SLD_SECTION_ID & "'           "
													 & "                }                                                "
													 & "            ]                                                    "
													 & "        }                                                        "
													 & "    ]                                                            "
													 & "}                                                                "
													 & """ -to | ";
	begin
		if ( SLD_CREATE_MONITOR_INTERFACE = 1 ) then
			return prev_string_terminator & monitor_interface_spec;
		else
			return prev_string_terminator & stp_hdl_interface_spec;
		end if;
	end function get_interface_assignments;

end package body sld_signaltap_function_pack;
