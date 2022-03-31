----------------------------------------------------------------------------------
-- PackageTest
-- Johnny Lozano 
-- 
--      Design detects button press and increments counter on seven segment display
--      each time you press the button.
-- 
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.physical_io_package.all;


entity PackageTest is
    Port (
        reset:          in  std_logic;
        clock:          in  std_logic;
        rawInc01:       in  std_logic;  --asynchronous input to initiate count 01
        rawInc02:       in  std_logic;  --asynchronous input to initiate count 02
        sevenSegs:      out std_logic_vector(6 downto 0);
        anodes:         out std_logic_vector(3 downto 0)
    );
end PackageTest;



architecture PackageTest_ARCH of PackageTest is
    constant ACTIVE:  std_logic := '1';

    signal inc01:       std_logic;
    signal inc02:       std_logic;
    signal inc01En:     std_logic;
    signal inc02En:     std_logic;
    signal count01:     integer range 0 to 99;
    signal count02:     integer range 0 to 99;
    signal count01Bcd:  std_logic_vector(7 downto 0);
    signal count02Bcd:  std_logic_vector(7 downto 0);

begin
    SYNC_INC01: SynchronizerChain
        generic map (CHAIN_SIZE => 2)
        port map (
            reset => reset,
            clock => clock,
            asyncIn => rawInc01,
            syncOut => inc01);

    SYNC_INC02: SynchronizerChain
        generic map (CHAIN_SIZE => 2)
        port map (
            reset => reset,
            clock => clock,
            asyncIn => rawInc02,
            syncOut => inc02);

    INC01_ENABLE: LevelDetector port map (
        reset    => reset,
        clock    => clock,
        trigger  => inc01,
        pulseOut => inc01En
    );

    INC02_ENABLE: LevelDetector port map (
        reset    => reset,
        clock    => clock,
        trigger  => inc02,
        pulseOut => inc02En
    );

    COUNTER01: count_to_99(
        reset   => reset,
        clock   => clock,
        countEn => inc01En,
        count   => count01);

    COUNTER02: count_to_99(
        reset   => reset,
        clock   => clock,
        countEn => inc02En,
        count   => count02);

    count01Bcd <= to_bcd_8bit(count01);
    count02Bcd <= to_bcd_8bit(count02);

    MY_SEGMENTS: SevenSegmentDriver port map (
        reset  => reset,
        clock  => clock,
        digit3 => count01Bcd(7 downto 4),
        digit2 => count01Bcd(3 downto 0),
        digit1 => count02Bcd(7 downto 4),
        digit0 => count02Bcd(3 downto 0),
        blank3 => not ACTIVE,
        blank2 => not ACTIVE,
        blank1 => not ACTIVE,
        blank0 => not ACTIVE,
        sevenSegs => sevenSegs,
        anodes    => anodes
    );

end PackageTest_ARCH;