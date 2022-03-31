# VHDL-Baseball-Game
Baseball style game built using XLINIX VIVADO for the Basys 3 Artix-7 FPGA Trainer Board. Features include pithcing, swinging, catching, speed modifying, and a scoring system.

How to set up files (in VIVADO 2020.2):
- basys3-master.xdc should be added as a constraint
- Lab4A.vhd and Lab4A_basys3 should be added as design sources
- Lab4A_basys3 is a wrapper which allows Lab4A.vhd to operate with basys3-master variables


Button Controls:
- The center button is a reset button
- The left and right buttons are the pitch buttons
- The up and down buttons are the speed toggle for different pitching speeds

How to play:
- Game begins with led on far right, indicating player 1 (left) is batting, and player 2 (right) is pitching
- Player 2 uses buttons to change pitch speed or pitch ( with right button ) which sends led traveling to the left
- Player 1 can lift any switch in order to swing at the ball. If it misses, player two scores a point. If the swing hits the ball, the led will travel the other direction.
- In the event of a successful hit, player can lift a switch to catch, or if the ball successfully makes it all the way to the right, player 1 scores a point.
- After either player scores a point, the led lights up on the other side of the board indicating that the turns have swapped (p1 pitches, and p2 swings)
- The game goes on indefinitely
