# ALEXIS GIOBBI
# AEG70

# NOTES ON PROJECT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Everything should work EXCEPT the blobs cannot be killed with the sword
# or with the bombs. Part of the code for killing with the sword is
# written in obj_update_bomb and it's commented out because whacky things happen.
# Thank you!

# this .include has to be up here so we can use the constants in the variables below.
.include "game_constants.asm"

# ------------------------------------------------------------------------------------------------
.data

# Player coordinates, in tiles. These initializers are the starting position.
player_x: .word 6
player_y: .word 5

# Direction player is facing.
player_dir: .word DIR_S

# How many hits the player can take until a game over.
player_health: .word 3

# How many keys the player has.
player_keys: .word 0

# 0 = player can move a tile, nonzero = they can't
player_move_timer: .word 0

# 0 = normal, nonzero = player is invincible and flashing.
player_iframes: .word 0

# 0 = no sword out, nonzero = sword is out
player_sword_timer: .word 0

# 0 = can place bomb, nonzero = can't place bomb
player_bomb_timer: .word 0

# boolean: did the player pick up the treasure?
player_got_treasure: .word 0

# Camera coordinates, in tiles. This is the top-left tile being displayed onscreen.
# This is derived from the player coordinates, so these initial values don't mean anything.
camera_x: .word 0
camera_y: .word 0

# Object arrays. These are parallel arrays.
object_type:  .byte OBJ_EMPTY:NUM_OBJECTS
object_x:     .byte 0:NUM_OBJECTS
object_y:     .byte 0:NUM_OBJECTS
object_timer: .byte 0:NUM_OBJECTS # general-purpose timer

# A 2D array of tile types. Filled in by load_map.
playfield: .byte 0:MAP_TILE_NUM

# A pair of arrays, indexed by direction, to turn a direction into x/y deltas.
# e.g. direction_delta_x[DIR_E] is 1, because moving east increments X by 1.
#                         N  E  S  W
direction_delta_x: .byte  0  1  0 -1
direction_delta_y: .byte -1  0  1  0

.text

# ------------------------------------------------------------------------------------------------

# these .includes are here to make these big arrays come *after* the interesting
# variables in memory. it makes things easier to debug.
.include "display_2211_0822.asm"
.include "textures.asm"
.include "map.asm"
.include "obj.asm"

# ------------------------------------------------------------------------------------------------

.globl main
main:
	# load the map into the 'playfield' array
	jal load_map

	# wait for the game to start
	jal wait_for_start

	# main game loop
	_loop:
		jal check_input
		jal update_all
		jal draw_all
		jal display_update_and_clear
		jal wait_for_next_frame
	jal check_game_over
	beq v0, 0, _loop

	# when the game is over, show a message
	jal show_game_over_message
syscall_exit

# ------------------------------------------------------------------------------------------------

wait_for_start:
enter
	_loop:
		jal draw_all
		jal display_update_and_clear
		jal wait_for_next_frame
	jal input_get_keys_pressed
	beq v0, 0, _loop
leave

# ------------------------------------------------------------------------------------------------

# returns a boolean (1/0) of whether the game is over. 1 means it is.
check_game_over:
enter

	lw t0, player_health
	lw t1, player_got_treasure
	# player_health == 0, OR
	beq t0, 0, _game_over
	# player_got_treasure != 0
	beq t1, 0, _else
		_game_over:
		# return a 1
		li v0, 1
		j _endif
	_else:
		# return 0
		li v0, 0
_endif: 

leave

# ------------------------------------------------------------------------------------------------

show_game_over_message:
enter

	lw t0, player_got_treasure

	# if player_got_treasure is 0
	bne t0, 0, _else
		# show a “game over” message;
			li a0, 5
			li a1, 28
			lstr a2, "game over"
			li a3, COLOR_RED
			jal display_draw_colored_text
		j _endif
	_else:
		# congratulate them
			li a0, 7
			li a1, 28
			lstr a2, "congrats!"
			li a3, COLOR_WHITE
			jal display_draw_colored_text
_endif:

jal display_update_and_clear

leave 

# ------------------------------------------------------------------------------------------------
player_unlock_door:
enter s0, s1

    # if(player_keys == 0) return;
    lw t0, player_keys
    beq t0, 0, _return

    # s0, s1 = position_in_front_of_player();
	jal position_in_front_of_player
	move s0, v0
	move s1, v1
	
    # if(s0 < 0) 
	blt s0, 0, _return
	# (s0 >= MAP_TILE_W)
	bge s0, MAP_TILE_W, _return
	# (s1 < 0) 
	blt s1, 0, _return
	# (s1 >= MAP_TILE_H) 
	bge s1, MAP_TILE_H, _return

   # v0 = get_tile(s0, s1);
   move a0, s0
   move a1, s1
   jal get_tile
   
   # if(v0 != TILE_DOOR) return;
   bne v0, TILE_DOOR, _return

   # set_tile(s0, s1, TILE_GRASS);
   move a0, s0
   move a1, s1
   li a2, TILE_GRASS
   jal set_tile
   
   # player_keys--;
   lw t1, player_keys
   sub t1, t1, 1
   sw t1, player_keys
	
_return:
   
leave s0, s1
# ------------------------------------------------------------------------------------------------

# Get input from the user and move the player object accordingly.
check_input:
enter s0

	# s0 = input_get_keys_pressed();
	jal input_get_keys_pressed
	move s0, v0 
	
	# if(s0 & KEY_Z)
	and t0, s0, KEY_Z
	beq t0, 0, _endif_z
		# if player_sword_timer == 0
		lw t1, player_sword_timer
		bne t1, 0, _ends_swordtimer
			# player_sword_timer = PLAYER_SWORD_FRAMES
			li t2, PLAYER_SWORD_FRAMES
			sw t2, player_sword_timer
	 _ends_swordtimer:
_endif_z:

	# if player_sword_timer is not 0, return from check_input.
	lw t2, player_sword_timer
	bne t2, 0, _return

	# if(s0 & KEY_C) 
	and t0, s0, KEY_C
	beq t0, 0, _endif_c
        # player_unlock_door();
        jal player_unlock_door
_endif_c:

	# if(s0 & KEY_X)
	and t0, s0, KEY_X
	beq t0, 0, _endif_x
		# call player_place_bomb
		jal player_place_bomb
_endif_x:

	#  s0 = input_get_keys_held();
	jal input_get_keys_held
	move s0, v0 

	# if(s0 & KEY_U) 
	and t0, s0, KEY_U
	beq t0, 0, _endif_u
		# try_move_player(DIR_N); 
		li a0, DIR_N
		jal try_move_player
_endif_u:

	# if(s0 & KEY_R)
	and t0, s0, KEY_R
	beq t0, 0, _endif_r
		# try_move_player(DIR_E);
		li a0, DIR_E
		jal try_move_player
_endif_r:

	# if(s0 & KEY_D)
	and t0, s0, KEY_D
	beq t0, 0, _endif_d
		# try_move_player(DIR_S);
		li a0, DIR_S
		jal try_move_player
_endif_d:

	# if(s0 & KEY_L)
	and t0, s0, KEY_L
	beq t0, 0, _endif_l
		# try_move_player(DIR_W)
		li a0, DIR_W
		jal try_move_player
_endif_l:

_return:

leave s0
# ------------------------------------------------------------------------------------------------
player_place_bomb:
enter s0, s1

	# Return if player_bomb_timer is not 0.
	lw t0, player_bomb_timer
	bne t0, 0, _return

	# Use position_in_front_of_player, and return if it’s invalid 
	jal position_in_front_of_player
	move s0, v0
	move s1, v1
	
	# if(s0 < 0) 
	blt s0, 0, _return
	# (s0 >= MAP_TILE_W)
	bge s0, MAP_TILE_W, _return
	# (s1 < 0) 
	blt s1, 0, _return
	# (s1 >= MAP_TILE_H) 
	bge s1, MAP_TILE_H, _return
		
	# Call obj_new_bomb with the position returned by position_in_front_of_player as arguments
	move a0, s0
	move a1, s1
	jal obj_new_bomb
	
	# If obj_new_bomb didn’t return -1
	beq v0, -1, _else
		# Set player_bomb_timer to PLAYER_BOMB_FRAMES
		li t1, PLAYER_BOMB_FRAMES
		sw t1, player_move_timer
	_else:

_return: 
leave s0, s1

# ------------------------------------------------------------------------------------------------
try_move_player: 
enter s0, s1

	# if(player_dir != a0) 
	lw t3, player_dir
	beq t3, a0, _ends1
    	# player_dir = a0;
    	sw a0, player_dir
    	
    	# player_move_timer = PLAYER_MOVE_DELAY;
		li t2, PLAYER_MOVE_DELAY
		sw t2, player_move_timer
	_ends1:

    # if(player_move_timer == 0) {
    lw t1, player_move_timer
    bne t1, 0, _ends2
    
		# player_move_timer = PLAYER_MOVE_DELAY; 
		li t2, PLAYER_MOVE_DELAY
		sw t2, player_move_timer
   		
		# s0 = player_x + direction_delta_x[a0];
    	lw s0, player_x
    	lb t0, direction_delta_x(a0)
    	add s0, s0, t0
    
    	# s1 = player_y + direction_delta_y[a0];
    	lw s1, player_y
    	lb t0, direction_delta_y(a0)
    	add s1, s1, t0
    	
    	# if s0 >= 0 
		blt s0, 0, _ends3
		# s0 < MAP_TILE_W
		bge s0, MAP_TILE_W, _ends3
		# s1 >= 0 
		blt s1, 0, _ends3
		# s1 < MAP_TILE_H)
		bge s1, MAP_TILE_H, _ends3
		
			# if(is_solid_tile(s0, s1) == 0)
			move a0, s0
			move a1, s1
			jal is_solid_tile
			bne v0, 0 _ends4
    			# player_x = s0;
    			sw s0, player_x
    			# player_y = s1;
    			sw s1, player_y
    		_ends4: 
    	_ends3:
    _ends2:
    
leave s0, s1

# ------------------------------------------------------------------------------------------------

# calculate the position in front of the player based on their coordinates and direction.
# returns v0 = x, v1 = y.
# the returned position can be *outside the map,* so be careful!
position_in_front_of_player:
enter
	lw  t1, player_dir

	lw  v0, player_x
	lb  t0, direction_delta_x(t1)
	add v0, v0, t0

	lw  v1, player_y
	lb  t0, direction_delta_y(t1)
	add v1, v1, t0
leave

# ------------------------------------------------------------------------------------------------

# update all the parts of the game and do collision between objects.
update_all:
enter
	jal update_camera
	jal update_timers
	jal obj_update_all
	jal collide_sword
leave

# ------------------------------------------------------------------------------------------------

# positions camera based on player position, but doesn't
# let it move off the edges of the playfield.
update_camera:
enter
	
	# player_x + CAMERA_OFFSET_X
	lw t0, player_x
	li t1, CAMERA_OFFSET_X
	add t0, t0, t1
	
	# max(t0,0)
	maxi t0, t0, 0
	
	# min(t0, CAMERA_MAX_X)
	mini t0, t0, CAMERA_MAX_X
	
	# camera_x = t0
	sw t0, camera_x

	# player_y + CAMERA_OFFSET_Y
	lw t2, player_y
	li t3, CAMERA_OFFSET_Y
	add t2, t2, t3
	
	# max(t2, 0)
	maxi t2, t2, 0
	
	# min(t2, CAMERA_MAX_Y)
	mini t2, t2, CAMERA_MAX_Y
	
	# camera_y = t2
	sw t2, camera_y
	
leave

# ------------------------------------------------------------------------------------------------

update_timers:
enter
	# decrement player_move_timer
	lw   t0, player_move_timer
	sub  t0, t0, 1
	maxi t0, t0, 0
	sw t0, player_move_timer
	
	# decrement player_sword_timer 
	lw t1, player_sword_timer
	sub t1, t1, 1
	maxi t1, t1, 0
	sw t1, player_sword_timer
	
	# decrement player_bomb_timer 
	lw t2, player_bomb_timer
	sub t2, t2, 1
	maxi t2, t2, 0
	sw t2, player_bomb_timer
	
	# decrement player_iframes
	lw t3, player_iframes
	sub t3, t3, 1
	maxi t3, t3, 0
	sw t3, player_iframes
leave

# ------------------------------------------------------------------------------------------------

collide_sword:
enter s0, s1

	# Return if player_sword_timer is 0.
	lw t0, player_sword_timer
	beq t0, 0,  _return
	
	# Use position_in_front_of_player to get the tile coordinates of the sword
	jal position_in_front_of_player
	move s0, v0
	move s1, v1
	
	# Return if those coordinates are outside the map boundaries.
	 # if(s0 < 0) 
	blt s0, 0, _return
	# (s0 >= MAP_TILE_W)
	bge s0, MAP_TILE_W, _return
	# (s1 < 0) 
	blt s1, 0, _return
	# (s1 >= MAP_TILE_H) 
	bge s1, MAP_TILE_H, _return
	
	# Use get_tile to get the tile at those coordinates
	move a0, s0
	move a1, s1
	jal get_tile
	
	# If it returns TILE_BUSH…
	bne v0, TILE_BUSH, _endsif
		# Use set_tile to replace the tile with TILE_GRASS.
		li a2, TILE_GRASS
   		jal set_tile
	_endsif:
	
	# use obj_find_at_position at the sword’s position 
	#jal position_in_front_of_player
	#move a0, v0
	#move a1, v1
	#jal obj_find_at_position
	
	# if didn't return -1
	#beq v0, -1, _obj_there
	# && that object’s object_type is OBJ_BLOB
	#bne v0, OBJ_BLOB, _obj_there
		#move a0, s0
		#jal obj_free
#_obj_there:
_return:

leave s0, s1

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this, obj_update_all does!
obj_update_bomb:
enter s0, s1
	# If the bomb’s field is not 0, return.
	lb t0, object_timer(a0)
	bne t0, 0, _return
	# Otherwise:
		# Get its position (x, y) from object_x and object_y and save that into some s regs.
		lb s0, object_x(a0)
		lb s1, object_y(a0)
		
	# Call obj_free on it (pass the same index that was passed into obj_update_bomb).
	jal obj_free
	
	# call explode five times 
	# explode(x, y)
	move a0, s0
	move a1, s1
	jal explode
	# explode(x + 1, y)
	add s0, s0, 1
	move a0, s0
	move a1, a1
	jal explode
	sub s0, s0, 1
	# explode(x - 1, y)
	sub s0, s0, 1
	move a0, s0
	move a1, s1
	jal explode
	add s0, s0, 1
	# explode(x, y + 1)
	add s1, s1, 1
	move a0, s0
	move a1, s1
	jal explode
	sub s1, s1, 1
	# explode(x, y - 1)
	sub s1, s1, 1
	move a0, s0
	move a1, s1
	jal explode
	add s1, s1, 1

_return:

leave s0, s1
# ------------------------------------------------------------------------------------------------
explode:
enter s0, s1

	move s0, a0
    move s1, a1

	# Return if those coordinates are outside the map boundaries
    # if(s0 < 0) 
	blt s0, 0, _return
	# (s0 >= MAP_TILE_W)
	bge s0, MAP_TILE_W, _return
	# (s1 < 0) 
	blt s1, 0, _return
	# (s1 >= MAP_TILE_H) 
	bge s1, MAP_TILE_H, _return
	
	# check if the explosion coordinates are equal to the player coordinates
	lw t0, player_x
	lw t1, player_y
	bne s0, t0, _endsif
	bne s1, t1, _endsif
		# if they are, call hurt_player
		jal hurt_player
_endsif:
	# Pass those coordinates to obj_new_explosion to create a new explosion object
	move a0, s0
	move a1, s1
	jal obj_new_explosion
	
	# Then, use get_tile to see what tile is at the explosion coordinates.
	move a0, s0
	move a1, s1
	jal get_tile
	
	# If the tile is TILE_BUSH or TILE_ROCK, replace it with TILE_GRASS
	bne v0, TILE_BUSH, _ends1
		# replace the tile with TILE_GRASS.
		li a2, TILE_GRASS
   		jal set_tile
_ends1:
   	bne v0, TILE_ROCK, _ends2
   		li a2, TILE_GRASS
   		jal set_tile
_ends2:

_return:

leave s0, s1
# ------------------------------------------------------------------------------------------------
hurt_player:
enter
	# Return if player_iframes is not 0.
	lw t1, player_iframes
	bne t1, 0, _return
	
	# Otherwise, decrement player_health
	lw t0, player_health
    sub t0, t0, 1
    sw t0, player_health
    
	# and set player_iframes to PLAYER_HURT_IFRAMES.
	li t2, PLAYER_HURT_IFRAMES
	sw t2, player_iframes
    
_return:

leave
# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this, obj_update_all does!
obj_update_explosion:
enter

	# if its obj_timer is 0.
	lb t0, object_timer(a0)
	bne t0, 0, _endsif
		# obj_update_explosion should obj_free
		jal obj_free
_endsif:
	
	
leave

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this,  does!
obj_update_key:
enter s0

	move s0, a0
   # if(obj_collides_with_player(s0)) 
   jal obj_collides_with_player
   beq v0, 0, _endif
    	# obj_free(s0);
    	jal obj_free
    	# player_keys++;
    	lw t0, player_keys
    	add t0, t0, 1
    	sw t0, player_keys
_endif:

leave s0

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this,  does!
obj_update_blob:
enter s0
	
	move s0, a0
	jal obj_collides_with_player
	# if it collides
	beq v0, 0, _endif
		jal hurt_player
_endif:

	lb t0, object_timer(a0)
	# when timer is 0
	bne t0, 0, _timer
		# pick random direction
		li a0, 0
		li a1, 4
		li v0, 42
		syscall
		
		# obj_try_move(index, direction)
		move a1, v0
		move a0, s0
		jal obj_try_move
		
		# set its timer to BLOB_MOVE_TIME 
		li t1, BLOB_MOVE_TIME
		sb t1, object_timer(s0)
_timer:

leave s0

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this,  does!
obj_update_treasure:
enter s0

	move s0, a0
	jal obj_collides_with_player
	beq v0, 0, _endif
    	li t0, 1
		sw t0, player_got_treasure
_endif:
	
leave s0

# ------------------------------------------------------------------------------------------------

draw_all:
enter
	jal draw_playfield
	jal obj_draw_all
	jal draw_player
	jal draw_sword
	jal draw_hud
leave

# ------------------------------------------------------------------------------------------------

draw_playfield:
enter s0, s1
    
    # for row = 0; 
	li s0, 0
	_loop_outer:
	
	# for col = 0;
	li s1, 0
	
	# ---------------- inner loop        
	
	_loop_inner:
	
	# v0 = get_tile(camera_x + col, camera_y + row);
	
	# load camera_x val and then add it col to it
	lw a0, camera_x
	add a0, a0, s1
	
	# load camera_y val and then add it row to it
	lw a1, camera_y
	add a1, a1, s0
	
	# v0 = get_tile(a0,a1)
	jal get_tile
	
    # a2 = tile_textures[v0 * 4];
    mul v0, v0, 4
    lw a2, tile_textures(v0)
    
    # if(a2 != 0) 
    beq a2, 0, _else
    	# a0 = col * 5 + PLAYFIELD_TL_X;
    	mul a0, s1, 5
    	add a0, a0, PLAYFIELD_TL_X
    	
    	# a1 = row * 5 + PLAYFIELD_TL_Y;
    	mul a1, s0, 5
    	add a1, a1, PLAYFIELD_TL_Y
    	
    	# display_blit_5x5 is a function from display_2211_0822.asm.
        jal display_blit_5x5
        
    _else:
            
	# col < SCREEN_TILE _W; col++
	add s1, s1, 1
	blt s1, SCREEN_TILE_W, _loop_inner
	
	# -------------- inner loop 
	
	# row < SCREEN_TILE _H; row++ 
	add s0, s0, 1
	blt s0, SCREEN_TILE_H, _loop_outer
    
leave s0, s1

# ------------------------------------------------------------------------------------------------

draw_player:
enter
	lw t1, player_iframes
	lw t2, frame_counter
	
	and t0, t1, 8
	# if player_iframes is not 0
	beq t1, 0, _else
	# and (frame_counter & 8) == 0, return
	bne t0, 0, _else
	
	j _endif
	
_else:
	lw a0, player_x
	lw a1, player_y

	# texture = player_textures[player_dir * 4]
	lw  t0, player_dir
	mul t0, t0, 4
	lw  a2, player_textures(t0)

	jal blit_5x5_tile_trans
	
_endif:

leave

# ------------------------------------------------------------------------------------------------

draw_sword:
enter s0, s1
	# Return if player_sword_timer is 0.
	lw t0, player_sword_timer
	beq t0, 0, _return

	# Use position_in_front_of_player to get the tile coordinates of the sword.
	jal position_in_front_of_player
	move s0, v0
	move s1, v1

	# Return if those coordinates are outside the map boundaries
    # if(s0 < 0) 
	blt s0, 0, _return
	# (s0 >= MAP_TILE_W)
	bge s0, MAP_TILE_W, _return
	# (s1 < 0) 
	blt s1, 0, _return
	# (s1 >= MAP_TILE_H) 
	bge s1, MAP_TILE_H, _return

	# Draw the sword at those coordinates, using sword_textures[player_dir] as the a2 argument to blit_5x5_tile_trans.
	move a0, s0
	move a1, s1

	# texture = player_textures[player_dir * 4]
	lw  t1, player_dir
	mul t1, t1, 4
	lw  a2, sword_textures(t1)

	jal blit_5x5_tile_trans
	
_return:
leave s0, s1

# ------------------------------------------------------------------------------------------------

draw_hud:
enter s0, s1
	# draw health
	lw s0, player_health
	li s1, 2
	_health_loop:
		move a0, s1
		li   a1, 1
		la   a2, tex_heart
		jal  display_blit_5x5_trans

		add s1, s1, 6
	dec s0
	bgt s0, 0, _health_loop

	li  a0, 20
	li  a1, 1
	li  a2, 'Z'
	jal display_draw_char

	li  a0, 26
	li  a1, 1
	la  a2, tex_sword_N
	jal display_blit_5x5_trans

	li  a0, 32
	li  a1, 1
	li  a2, 'X'
	jal display_draw_char

	li  a0, 38
	li  a1, 1
	la  a2, tex_bomb
	jal display_blit_5x5_trans

	li  a0, 44
	li  a1, 1
	li  a2, 'C'
	jal display_draw_char

	li  a0, 50
	li  a1, 1
	la  a2, tex_key
	jal display_blit_5x5_trans

	li   a0, 56
	li   a1, 1
	lw   a2, player_keys
	mini a2, a2, 9 # limit it to at most 9
	jal  display_draw_int
leave s0, s1

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this, obj_draw_all does!
obj_draw_bomb:
enter

	# draw it similarly to how you did draw_key, but use tex_bomb instead
    lb t0, object_x(a0)
    lb t1, object_y(a0)
    
	# Get the bomb’s object_timer field.
	lb t2, object_timer(a0)
	# If that timer is < 64 and (timer & 4) != 0 (that’s timer bitwise and 4)…
	and t3, t2, 4
	bge t2, 64, _else
	beq t3, 0, _else
	
	# use tex_bomb_flash as the a2.
	la a2, tex_bomb_flash
	move a0, t0
	move a1, t1
	jal blit_5x5_tile_trans
	
	j _endif
_else:
	# use tex_bomb as the a2 like you did before
    la a2, tex_bomb
    move a0, t0
    move a1, t1
	jal blit_5x5_tile_trans
_endif:
	
leave

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this, obj_draw_all does!
obj_draw_explosion:
enter
	# blit_5x5_tile_trans(object_x[a0], object_y[a0], tex_key);
    lb t0, object_x(a0)
    lb t1, object_y(a0)
    la a2, tex_explosion
    move a0, t0
    move a1, t1
	jal blit_5x5_tile_trans
leave

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this, obj_draw_all does!
obj_draw_key:
enter
	# blit_5x5_tile_trans(object_x[a0], object_y[a0], tex_key);
    lb t0, object_x(a0)
    lb t1, object_y(a0)
    la a2, tex_key
    move a0, t0
    move a1, t1
	jal blit_5x5_tile_trans
leave

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this, obj_draw_all does!
obj_draw_blob:
enter s0
	# use tex_blob
    lb t0, object_x(a0)
    lb t1, object_y(a0)
    la a2, tex_blob
    move a0, t0
    move a1, t1
	jal blit_5x5_tile_trans
leave s0

# ------------------------------------------------------------------------------------------------

# a0 = object index
# you don't call this, obj_draw_all does!
obj_draw_treasure:
enter
	# blit_5x5_tile_trans(object_x[a0], object_y[a0], tex_treasure)
    lb t0, object_x(a0)
    lb t1, object_y(a0)
   
	# switch between tex_treasure1 and tex_treasure2 
	lw t2, frame_counter
	and t3, t2, 16
	# if (frame_counter & 16) != 0
	beq t3, 0, _else
		# a2 = tex_treasure1
		la a2, tex_treasure1
	j _endif
	_else:
		# a2 = tex_treasure2
		la a2, tex_treasure2
_endif:

	move a0, t0
    move a1, t1
	jal blit_5x5_tile_trans
leave
