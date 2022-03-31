----------------------------------------------------------------------------------
-- Lab4A_basys3
-- Johnny Lozano
-- 
-- Wrapper for component Ball Trapper to provide interface with the Basys 3 
-- development board.
-- 
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;


entity Lab4A_basys3 is
    port ( clk : in std_logic;
           sw   : in  std_logic_vector  (15 downto 0);
           btnR  : in std_logic;
           btnL   : in std_logic;
           btnD : in std_logic;
           btnU  : in std_logic;           
           btnC: in std_logic;
           an: out std_logic_vector(3 downto 0);
           seg: out std_logic_vector(6 downto 0);
           led  : out std_logic_vector  (15 downto 0));

end Lab4A_basys3;

architecture Lab4A_basys3_ARCH of Lab4A_basys3 is
    component Lab4A
    port(  reset : in std_logic;
           clock : in std_logic;
           switches   : in   std_logic_vector (15 downto 0);
           leds       : out  std_logic_vector (15 downto 0);
           anodes: out std_logic_vector(3 downto 0);
           segments: out std_logic_vector(6 downto 0);
           leftButton  : in  std_logic;
           rightButton     : in  std_logic;
           upButton  : in  std_logic;
           downButton     : in  std_logic;           
           centerButton : in std_logic
    );
    end component;
begin
    MY_DESIGN: Lab4A port map(
        reset => btnC,
        clock => clk,
        switches   => sw,
        leds       => led,
        anodes => an,
        segments => seg,
        centerButton => btnC,
        upButton => btnU,
        downButton => btnD,
        leftButton  => btnL,
        rightButton     => btnR
    );

end Lab4A_basys3_ARCH;