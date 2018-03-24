
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

-- Package is used to pass the encrypted message (32 byte string) to the cracker workers
-- https://stackoverflow.com/a/16873147

library ieee;
use ieee.numeric_std.all;

package Common is
	type string32 is array (0 to 31) of unsigned (7 DOWNTO 0);	-- encoded as unsigned instead of std_logic_vector to reflect ASCII # (and easier use!)
	
	type hashKey is array(0 to 2) of unsigned(7 downto 0);
	
end Common;