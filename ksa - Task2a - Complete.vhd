
-- Author 1: Sheung Yau (Gary) Chung
-- Author 1 Student #: 301236546
-- Author 2: Yu Xuan (Shawn) Wang
-- Author 2 Student #: 301227972
-- Group Number: 40
-- Lab Section: LA04
-- Lab: ASB 10808
-- Task Completed: 2a, 2b, 3, LCD, Challenge
-- Date: March 23, 2018 
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs

entity ksa is
  port(CLOCK_50 : in  std_logic;  -- Clock pin
       KEY : in  std_logic_vector(3 downto 0);  -- push button switches
       SW : in  std_logic_vector(17 downto 0);  -- slider switches
		 LEDG : out std_logic_vector(7 downto 0);  -- green lights
		 LEDR : out std_logic_vector(17 downto 0));  -- red lights
end ksa;

-- Architecture part of the description

architecture rtl of ksa is

   -- Declare the component for the ram.  This should match the entity description 
	-- in the entity created by the megawizard. If you followed the instructions in the 
	-- handout exactly, it should match.  If not, look at s_memory.vhd and make the
	-- changes to the component below
	
   COMPONENT s_memory IS
	   PORT (
		   address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		   clock		: IN STD_LOGIC  := '1';
		   data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		   wren		: IN STD_LOGIC ;
		   q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0));
   END component;

	-- Enumerated type for the state variable.  You will likely be adding extra
	-- state names here as you complete your design
	-- appended # n: nth loop implementation of the RC4 algorithm
	type state_type is (state_init1, state_fill1, state_readi2, state_readj2, state_writei2, state_writej2, state_done,
							state_empty0, state_empty1, state_empty2
	);
								
    -- These are signals that are used to connect to the memory													 
	signal address : STD_LOGIC_VECTOR (7 DOWNTO 0);	 
	signal data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal wren : STD_LOGIC;
	signal q : STD_LOGIC_VECTOR (7 DOWNTO 0);	

	-- my code
	signal clk: std_logic;
	signal curr_state: state_type := state_type'left;
	type hashKeys is array(2 downto 0) of std_logic_vector(7 downto 0);
	signal secret_key : hashKeys;
	
	begin
		-- Include the S memory structurally
		u0: s_memory port map (address, clk, data, wren, q);
		
		clk <= CLOCK_50;
		
		secret_key(0) <= "00000011";
		secret_key(1) <= "01011111";
		secret_key(2) <= "00111100";
		--secret_key(2) <= "000000" & sw(17 downto 16);
		--secret_key(1) <= sw(15 downto 8);
		--secret_key(0) <= sw(7 downto 0);
		
		process(clk)
			variable i, j, tmp, tmp_si, tmp_sj: unsigned(7 downto 0);	-- i, i and s[i], s[j]
			variable k_index: integer;
		begin	
			if rising_edge(clk) then
				case curr_state is
					-- Task 1) First Loop in algorithm
					when state_init1 =>
						i := (others => '0');
						wren <= '1';
						address <= std_logic_vector(i);
						data <= std_logic_vector(i);
						curr_state <= state_fill1;
					 
					when state_fill1 =>
						address <= std_logic_vector(i);
						data <= std_logic_vector(i);
						wren <= '1';
						
						if i < 255 then
							i := i + 1;
							curr_state <= state_fill1;
						else 
							wren <= '1';
							address <= std_logic_vector(i);
							data <= std_logic_vector(i);
							curr_state <= state_empty0;
						end if;
						
					when state_empty0=>
							-- clear i for re-use
							i := (others => '0');
							j := (others => '0');
						curr_state <= state_readi2;
						
					-- Task 2a) Second Loop in algorithm
					when state_readi2 =>
						-- add the two terms and wait for s[i]
						k_index := to_integer(i mod 3);
						tmp := j + unsigned(secret_key(k_index));
						-- read s[i]
						wren <= '0';    
						address <= std_logic_vector(i);
						
						curr_state <= state_empty1;

					when state_empty1 =>
						curr_state <= state_readj2;
						
					when state_readj2 =>
						-- catch s[i]
						tmp_si := unsigned(q);
						j := (tmp + tmp_si);
						-- read s[j] for swapping
						wren <= '0';
						address <= std_logic_vector(j);
						
						curr_state <= state_empty2;
						
					when state_empty2 =>
						curr_state <= state_writei2;

					when state_writei2 =>
						-- catch s[j]
						tmp_sj := unsigned(q);
						-- write s[i] for swapping
						wren <= '1';
						address <= std_logic_vector(i);
						data <= std_logic_vector(tmp_sj);
						curr_state <= state_writej2;
							
					when state_writej2 =>
						-- write s[j] for swapping
						wren <= '1';
						address <= std_logic_vector(j);
						data <= std_logic_vector(tmp_si);
						
						if i < 255 then
							i := i + 1;
							curr_state <= state_readi2;
						else 
							wren <= '0';
							curr_state <= state_done;
						end if;
						
					when state_done =>
						curr_state <= state_done;
						LEDR(17) <= '1';
				end case;	 
			end if;
		end process;


end RTL;


