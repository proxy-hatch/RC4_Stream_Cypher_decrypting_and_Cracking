
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

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY WORK;
USE WORK.ALL;

-----------------------------------------------------
--
--  This block will contain a decoder to decode a 4-bit number
--  to a 7-bit vector suitable to drive a HEX dispaly
--
--  It is a purely combinational block (think Pattern 1) and
--  is similar to a block you designed in Lab 1.
--
--------------------------------------------------------

ENTITY digit7seg IS
	PORT(
          digit : IN  UNSIGNED(3 DOWNTO 0);  -- number 0 to 0xF
          seg7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)  -- one per segment
	);
END;


ARCHITECTURE behavioral OF digit7seg IS
BEGIN
	-- 7seg is active low (inverted) 

	comb_process: process(digit)
	
	begin
		
	case digit is
		when "0000" => --0
			seg7 <= "1000000";
		when "0001" => --1
			seg7 <= "1111001";
		when "0010" => --2
			seg7 <= "0100100";
		when "0011" => --3
			seg7 <= "0110000";
		when "0100" => --4
			seg7 <= "0011001";
		when "0101" => --5
			seg7 <= "0010010";
		when "0110" => --6
			seg7 <= "0000010";
		when "0111" => --7
			seg7 <= "1111000";
		when "1000" => --8
			seg7 <= "0000000";
		when "1001" => --9
			seg7 <= "0010000";
		when "1010" => --A
			seg7 <= "0001000";
		when "1011" => --b
			seg7 <= "0000011";
		when "1100" => --C
			seg7 <= "0100111";
		when "1101" => --d
			seg7 <= "0100001";
		when "1110" => --E
			seg7 <= "0000110";
		when "1111" => --F
			seg7 <= "0001110";
		when others => 
			seg7 <= "1111111";
	end case;
		
	end process comb_process;
END;
