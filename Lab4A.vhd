----------------------------------------------------------------------------------
-- Final Lab Project
-- Christopher Slaughter and Johnny Lozano
-- 
-- Ball will be "pitched" from one player to the other, who will use the switch to
-- "hit" the ball back and the pitching player will need to "catch" the ball with
-- other switches, while incurring a penalty of a point if the ball was caught
-- too soon.
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use work.physical_io_package.all;



entity Lab4A is
    Port ( reset       : in std_logic;
           clock       : in std_logic;
           switches    : in std_logic_vector (15 downto 0);
           rightButton : in std_logic;
           leftButton  : in std_logic;
           upButton    : in std_logic;
           downButton  : in std_logic;           
           centerButton: in std_logic;
           segments    : out std_logic_vector(6 downto 0);
           anodes      : out std_logic_vector(3 downto 0);
           leds        : out std_logic_vector (15 downto 0));
end Lab4A;



architecture Lab4A_ARCH of Lab4A is

    ----general-definitions-------------------------------------------------CONSTANTS
    constant ACTIVE        : std_logic := '1';
    constant BALL_CLEAR    : std_logic_vector(15 downto 0):= (others => '0');
    constant NO_COLLISION  : std_logic_vector(15 downto 0):= (others => '0');

    constant BALL_LEFT   : std_logic_vector(15 downto 0):= "1000000000000000";
    constant BALL_RIGHT  : std_logic_vector(15 downto 0):= "0000000000000001";
    constant COUNT_1MS   : integer := (100000000/1000)-1;
    constant COUNT_SHIFT : integer := COUNT_1MS * 200; -- for reference, half a second would be COUNT_1MS * 500
    
    constant LEFT   : std_logic := '0';
    constant RIGHT  : std_logic := not LEFT;

    ----ball-driver-signals----------------------------------------------------SIGNALS
    signal serve      : std_logic;
    signal direction  : std_logic;
    signal shiftEn    : std_logic;
    signal ball       : std_logic_vector(15 downto 0);
    signal dummyBall  : std_logic_vector(15 downto 0);
    signal collision  : std_logic;
    signal turn       : std_logic;
    signal catch      : std_logic;
    signal catchInc   : integer range 0 to 3;
    signal blinkP1    : std_logic;
    signal blinkP2    : std_logic;
    
    
    ----ball-control-state-machine-declarations---------------------------------SIGNALS
    type States_t is (IDLE, SERVE_LEFT_P1, MOVE_RIGHT_P1, SERVE_RIGHT_p2, MOVE_LEFT_P1, INCREMENT_P1, INCREMENT_P2,
    IDLE_P1, IDLE_P2, MOVE_LEFT_P2, MOVE_RIGHT_P2, BALL_CATCH);
    signal currentState: States_t;
    signal nextState: States_t;
    
    signal upSync: std_logic;
    signal downSync: std_logic;    
    signal pitchRate: integer;
    signal pitchSpeed: integer;    
    
    ----pitch-speed-state-machine-declarations---------------------------------SIGNALS
    type Speeds_t is (SLOW, MEDIUM, FAST,MAXIMUM, MINIMUM, BUFFER_SPEED, BUFFER_UPPER, BUFFER_LOWER);
    signal currentSpeedState: Speeds_t;
    signal nextSpeedState: Speeds_t;
    
    
    constant MAX_SPEED: integer := COUNT_1MS * 50;
    constant FAST_SPEED : integer := COUNT_1MS * 100;
    constant NORMAL_SPEED : integer := COUNT_1MS * 250;
    constant SLOW_SPEED : integer := COUNT_1MS * 330; 
    constant MIN_SPEED: integer := COUNT_1MS * 500;    

    ----button-sync-signals------------------------------------------------------SIGNALS    
    signal leftSync: std_logic;
    signal rightSync: std_logic;
    
    signal rawInc01: std_logic;
    signal rawInc02: std_logic;
    signal inc01:       std_logic;
    signal inc02:       std_logic;
    signal inc01En:     std_logic;
    signal inc02En:     std_logic;
    signal count01:     integer range 0 to 99;
    signal count02:     integer range 0 to 99;
    signal count01Bcd:  std_logic_vector(7 downto 0);
    signal count02Bcd:  std_logic_vector(7 downto 0);    
    signal sevenSegs: std_logic_vector(6 downto 0);

begin

    ----assigns-ball-signal-to-led-output----------------------------------------SIGNALS    
    leds <= ball;
    segments <= sevenSegs;


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
    
    --=============================================================PROCESS
    -- Synchronizer for up and down buttons
    --====================================================================
    UPDOWN_SYNC: process(reset, clock)
        variable unsafeOutputUp: std_logic;
        variable unsafeOutputDown: std_logic;
    begin
        if (reset=ACTIVE) then
            upSync <= not ACTIVE;
            unsafeOutputUp := not ACTIVE;
            
            downSync <= not ACTIVE;
            unsafeOutputdown := not ACTIVE;
        elsif (rising_edge(clock)) then
            upSync <= unsafeOutputUp;
            unsafeOutputUp := upButton;
            
            downSync<= unsafeOutputDown;
            unsafeOutputDown := downButton;
        end if;
    end process;  
        
    --=============================================================PROCESS
    -- Synchronizer for left and right buttons
    --====================================================================
    LR_SYNC_CHAIN: process(reset, clock)
        variable unsafeOutputLeft: std_logic;
        variable unsafeOutputRight: std_logic;
    begin
        if (reset=ACTIVE) then
            leftSync <= not ACTIVE;
            unsafeOutputLeft := not ACTIVE;
            
            rightSync <= not ACTIVE;
            unsafeOutputRight := not ACTIVE;
        elsif (rising_edge(clock)) then
            leftSync <= unsafeOutputLeft;
            unsafeOutputLeft := leftButton;
            
            rightSync<= unsafeOutputRight;
            unsafeOutputRight := rightButton;
        end if;
    end process;
    
    --=============================================================PROCESS
    -- Pitch Speed State register
    --    Syncs Pitch Speed register to clock
    --====================================================================
    PITCH_SPEED_REG: process(reset, clock)
    begin
        if (reset=ACTIVE) then
            currentSpeedState <= MEDIUM;
        elsif (rising_edge(clock)) then
            currentSpeedState <= nextSpeedState;
        end if;
    end process;   
    
    --=============================================================PROCESS
    -- Speed State transitions
    --====================================================================
    PITCH_SPEED_TRANS: process(upSync, downSync, currentSpeedState, pitchRate)
    begin
        case currentSpeedState is
            ---------------------------------------------------------MEDIUM
            when MEDIUM =>
                pitchRate <= NORMAL_SPEED;
                
                if (upSync = ACTIVE)then
                        nextSpeedState <= FAST;
                    
                elsif (downSync = ACTIVE) then
                        nextSpeedState <= SLOW;
                    
                else
                    nextSpeedState <= MEDIUM;
                end if;  
                
            ---------------------------------------------------------FAST
            when FAST =>
                pitchRate <= FAST_SPEED;
                               
                if (downSync = ACTIVE)then
                        nextSpeedState <= BUFFER_SPEED; --MEDIUM;
                elsif (upSync = ACTIVE) then
                        nextSpeedState <= MAXIMUM;
                    
                else
                    nextSpeedState <= FAST;
                end if;
                
            ---------------------------------------------------------SLOW
            when SLOW =>
                pitchRate <= SLOW_SPEED;
                                
                if (upSync = ACTIVE)then
                        nextSpeedState <= BUFFER_SPEED; --MEDIUM;
                elsif (downSync = ACTIVE) then
                        nextSpeedState <= MINIMUM;
                    
                else
                    nextSpeedState <= SLOW;
                end if;
                                       
             ---------------------------------------------------------MAXIMUM
             when MAXIMUM =>
                 pitchRate <= MAX_SPEED;
                                
                 if (downSync = ACTIVE)then
                         nextSpeedState <= BUFFER_UPPER; --FAST;                   
                 else
                     nextSpeedState <= MAXIMUM;
                 end if;                   
              ---------------------------------------------------------MINIMUM
              when MINIMUM =>
                  pitchRate <= MIN_SPEED;
                              
                  if (upSync = ACTIVE)then
                          nextSpeedState <= BUFFER_LOWER; --SLOW;                   
                  else
                      nextSpeedState <= MINIMUM;
                  end if;
                               
            ---------------------------------------------------------BUFFER
            --      BUFFER SPEED state is solution to problem with pressing 
            --      the buttons and it skipping over states.
            --      It'll stay in buffer a speed state until button is released
            when BUFFER_SPEED =>
                if (downSync = ACTIVE) then
                    nextSpeedState <= BUFFER_SPEED;
                elsif (upSync = ACTIVE) then
                    nextSpeedState <= BUFFER_SPEED;
                else
                nextSpeedState <= MEDIUM;
                end if;
                               
            ---------------------------------------------------------BUFFER-UPPER
            when BUFFER_UPPER =>
                if (downSync = ACTIVE) then
                    nextSpeedState <= BUFFER_UPPER;
                elsif (upSync = ACTIVE) then
                    nextSpeedState <= BUFFER_UPPER;
                else
                nextSpeedState <= FAST;
                end if;
                                
            ---------------------------------------------------------BUFFER-LOWER
            when BUFFER_LOWER =>
                if (downSync = ACTIVE) then
                    nextSpeedState <= BUFFER_LOWER;
                elsif (upSync = ACTIVE) then
                    nextSpeedState <= BUFFER_LOWER;
                else
                nextSpeedState <= SLOW;
                end if;
                                               
         end case;
    end process;        

    --=============================================================PROCESS
    -- Ball Control State register
    --    Syncs states to the clock
    --====================================================================
    BALL_CONTROL_REG: process(reset, clock)
    begin
        if (reset=ACTIVE) then
            currentState <= IDLE;
        elsif (rising_edge(clock)) then
            currentState <= nextState;
        end if;
    end process;
    
    
    
    --=============================================================PROCESS
    -- State transitions
    --====================================================================
    BALL_CONTROL_TRANS: process(collision, rightSync, leftSync, currentState, ball)
        variable catchCount: integer range 0 to 3 := 0;
    begin
        case CurrentState is
            ---------------------------------------------------------IDLE
            when IDLE =>
                serve <= not ACTIVE;
                direction <= LEFT;
                catch <= not ACTIVE;
                rawInc01 <= not ACTIVE;
                rawInc02 <= not ACTIVE;
                if (turn = ACTIVE)then
                    nextState <= IDLE_P1;
                elsif (turn = not ACTIVE) then
                    nextState <= IDLE_P2;
                else
                    nextState <= IDLE;
                end if; 
                
            ---------------------------------------------------------IDLE_P1
            when IDLE_P1 => 
                 blinkP1 <= not ACTIVE;                
                 if (leftSync = ACTIVE) then
                    nextState <= SERVE_LEFT_P1;
                 else 
                    nextState <= IDLE_P1;
                 end if;    
                 
            ---------------------------------------------------------IDLE_P2
            when IDLE_P2 => 
                 blinkP2 <= not ACTIVE;         
                 if (rightSync = ACTIVE) then
                    nextState <= SERVE_RIGHT_P2;
                 else 
                    nextState <= IDLE_P2;
                 end if;                         
            ---------------------------------------------------------SERVE_LEFT_P1
            when SERVE_LEFT_P1 =>
                serve <= ACTIVE;
                direction <= RIGHT;
                nextState <= MOVE_RIGHT_P1;
                
            ---------------------------------------------------------MOVE_RIGHT_P1
            when MOVE_RIGHT_P1 =>
                direction <= RIGHT;
                if (collision = ACTIVE) then
                    serve <= not ACTIVE;
                    direction <= LEFT;
                    dummyBall <= ball;
                    nextState <= MOVE_LEFT_P1;
                else
                    serve <= not ACTIVE;
                    direction <= RIGHT;
                    if (ball = BALL_RIGHT and direction = RIGHT) then
                        nextState <= BALL_CATCH;
                        rawInc01 <= ACTIVE;
                    else 
                        nextState <= MOVE_RIGHT_P1;
                    end if;
                 end if;
                 
                 
            ---------------------------------------------------------INCREMENT_P1
            when INCREMENT_P1 => 
                rawInc01 <= ACTIVE;
                nextState <= IDLE;  
                serve <= not ACTIVE;
                direction <= LEFT;              
                 
                
            ---------------------------------------------------------MOVE_LEFT_P1
            when MOVE_LEFT_P1 =>
                direction <= LEFT;
                serve <= ACTIVE;
                if (collision = ACTIVE and ball /= dummyBall) then
                    serve <= not ACTIVE;
                    direction <= RIGHT;
                    nextState <= BALL_CATCH;
                    rawInc01 <= ACTIVE;
                else
                    serve <= not ACTIVE;
                    direction <= LEFT;
                    if (ball = BALL_CLEAR and direction = LEFT) then
                        nextState <= INCREMENT_P2;
                    else 
                        nextState <= MOVE_LEFT_P1;
                    end if;
                 end if;
                 
            ---------------------------------------------------------INCREMENT_P2
            when INCREMENT_P2 => 
                rawInc02 <= ACTIVE;
                nextState <= IDLE;
                serve <= not ACTIVE;
                direction <= RIGHT;                   
                         
            ---------------------------------------------------------SERVE_RIGHT_P2
            when SERVE_RIGHT_P2 =>
                serve <= ACTIVE;
                direction <= LEFT;
                nextState <= MOVE_LEFT_P2; 
                
            ---------------------------------------------------------MOVE_LEFT_P2
            when MOVE_LEFT_P2 =>
            
                if (collision = ACTIVE) then
                    serve <= not ACTIVE;
                    direction <= RIGHT;
                    nextState <= MOVE_RIGHT_P2;
                    dummyBall <= ball;
                else
                    serve <= not ACTIVE;
                    direction <= LEFT;
                    if (ball = BALL_CLEAR and direction = LEFT) then
                        nextState <= BALL_CATCH;
                        rawInc02 <= ACTIVE;
                    else 
                        nextState <= MOVE_LEFT_P2;
                    end if;
                end if;
                        
            ---------------------------------------------------------MOVE_LEFT
            when MOVE_RIGHT_P2 =>
                direction <= RIGHT;
                serve <= ACTIVE;
                if (collision = ACTIVE and ball /= dummyBall) then
                    serve <= not ACTIVE;
                    direction <= LEFT;
                    nextState <= BALL_CATCH;
                    rawInc02 <= ACTIVE;
                else
                    serve <= not ACTIVE;
                    direction <= RIGHT;
                    if (ball = BALL_CLEAR and direction = RIGHT) then
                        nextState <= INCREMENT_P1;
                    else 
                        nextState <= MOVE_RIGHT_P2;
                    end if;
                 end if; 
                 
            ---------------------------------------------------------BALL_CATCH
            when BALL_CATCH =>   
                catch <= ACTIVE;
                catchCount := catchCount + 1;
                --if (catchCount = 3) then
                    if (turn = '1') then
                        turn <= '0';
                        nextState <= IDLE;
                    
                    elsif (turn = '0') then
                        turn <= '1';
                        nextState <= IDLE;
                    end if;  
                    catchCount := 0;
                --end if;                                
                nextState <= IDLE;
        end case;
    end process;
                
            

    --=====================================================================PROCESS
    --  Sets shift rate for ball movement
    --============================================================================
    SHIFT_RATE: process(reset, clock)
        variable countSR: integer range 0 to COUNT_SHIFT;
    begin
        --manage-count-value--------------------------------------------
        if (reset = ACTIVE) then
            countSR := 0;
        elsif (rising_edge(clock)) then
            if (countSR = pitchRate) then
                countSR := 0;
            else
                countSR := countSR + 1;
            end if;
        end if;
        
        --update-enable-signal-------------------------------------------
        shiftEn <= not ACTIVE;  --default value unless countSR reaches terminal
        if (countSR=pitchRate) then
            shiftEn <= ACTIVE;
        end if;
    end process SHIFT_RATE;
    
    
    
    --=====================================================================PROCESS
    --  Handles the ball movement 
    --============================================================================
    BALL_DRIVER: process (reset, clock)
    begin
        if (reset = ACTIVE) then
            ball <= BALL_CLEAR;
        elsif (rising_edge(clock)) then
            
            --handle-ball-serve---------------------------------------------------
            if (serve = ACTIVE) then
                if (direction = LEFT) then
                    ball <= BALL_RIGHT;
                else
                    ball <= BALL_LEFT;
                end if;
                     
            --handle-ball-movement----------------------------------------
            elsif (shiftEn = ACTIVE) then
                if (direction = LEFT) then
                    ball <= ball(14 downto 0) & '0';
                else
                    ball <= '0' & ball(15 downto 1);
                end if;
            end if;
            
            --handle-ball-catch-------------------------------------------
            if (catch = ACTIVE) then
                ball <= BALL_CLEAR;
            end if; 
            
            --handle-ball-pitch--------------------------------------------  
            if (nextState = IDLE_P1 and turn = '1')then
                ball <= "1000000000000000";
            elsif (nextState = IDLE_P2 and turn = '0') then
                ball <=  "0000000000000001"; 
            end if;    
        end if;
    end process BALL_DRIVER;
    
 
    
    --=====================================================================PROCESS
    --  Detects ball to switch collision
    --============================================================================
    COLLISION_DETECT: process(switches, ball)
    begin
        if ( (switches and ball) = NO_COLLISION) then
            collision <= not ACTIVE;
        else
            collision <= ACTIVE;
        end if;
    end process COLLISION_DETECT;


end Lab4A_ARCH;
