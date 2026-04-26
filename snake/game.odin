package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Constants
WINDOW_SIZE :: 800
NUM_ROWS :: 16
CELL_SIZE :: WINDOW_SIZE / NUM_ROWS

DIRECTION_DELTA :: [Direction]rl.Vector2 {
	.RIGHT = {CELL_SIZE, 0},
	.LEFT  = {-CELL_SIZE, 0},
	.DOWN  = {0, CELL_SIZE},
	.UP    = {0, -CELL_SIZE},
}

Direction :: enum {
	RIGHT,
	LEFT,
	DOWN,
	UP,
}

GameState :: enum {
	INITIALIZING,
	RUNNING,
	PAUSED,
	GAME_OVER,
}

GameData :: struct {
	state:      GameState,
	snake:      Snake,
	food_pos:   rl.Vector2,
	head_index: int,
	score:      i32,
	high_score: i32,
	speed:      f32,
	chomp:      rl.Sound,
	timer:      f32,
}

Snake :: struct {
	segments:         [dynamic]rl.Vector2,
	direction:        Direction,
	direction_locked: bool,
}

main :: proc() {
	// Setup Window and audio
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Snake")
	rl.InitAudioDevice()
	defer rl.CloseWindow()
	defer rl.CloseAudioDevice()

	// Load chomp sound
	chomp_sound := rl.LoadSound("snake/assets/chomp.wav")
	defer rl.UnloadSound(chomp_sound)

	game := GameData {
		speed      = 0.3,
		snake      = make_snake(3),
		head_index = 0,
		score      = 0,
		chomp      = chomp_sound,
		state      = .INITIALIZING,
		timer      = 0.0,
	}

	// Spawn food
	game.food_pos = spawn_food(&game.snake)


	for !rl.WindowShouldClose() {
		// Increment the timer
		game.timer += rl.GetFrameTime()

		// DRAW
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		// Draw score
		draw_score_text(rl.TextFormat("High Score: %d", game.high_score), rl.GREEN, 10)
		draw_score_text(rl.TextFormat("Score: %d", game.score), rl.BLACK, 50)

		// Draw snake segments
		for segment in game.snake.segments {
			rl.DrawRectangle(i32(segment.x), i32(segment.y), CELL_SIZE, CELL_SIZE, rl.DARKGRAY)
		}

		// draw food
		rl.DrawRectangle(
			i32(game.food_pos.x),
			i32(game.food_pos.y),
			CELL_SIZE,
			CELL_SIZE,
			rl.GREEN,
		)

		// We should suspend the game if it's not running
		if game.state != .RUNNING {
			suspend_game(&game)

			// Skip the rest of the loop and wait for unpause
			continue
		}

		// Pause the game
		if rl.IsKeyPressed(.SPACE) {
			game.state = .PAUSED
			continue
		}

		update_direction(&game.snake)

		// This is our game tick
		if (game.timer >= game.speed) {
			update_snake(&game)
			game.timer -= game.speed // reset timer
		}
	}
}

suspend_game :: proc(game: ^GameData) {
	switch game.state {
	case .INITIALIZING:
		draw_center_text("Press the space key to start...", rl.RED)
		if rl.IsKeyPressed(.SPACE) {
			game.state = .RUNNING
			game.timer = 0.0 // reset timer
		}
	case .PAUSED:
		draw_center_text("Press the space key to resume...", rl.RED)
		if rl.IsKeyPressed(.SPACE) {
			game.state = .RUNNING
			game.timer = 0.0 // reset timer
		}
	case .GAME_OVER:
		draw_center_text("Game Over", rl.RED)
		draw_center_text("Press SPACE to play again...", rl.RED)
		if rl.IsKeyPressed(.SPACE) {
			game.state = .RUNNING
			game.timer = 0.0 // reset timer
		}
	case .RUNNING:
	// We should never hit this case
	}
}

spawn_food :: proc(snake: ^Snake) -> rl.Vector2 {
	/* Create a random x and y pos then map this to a grid cell
	   This should be NUM_ROWS * 2 = 32, so random x and y should be in range [0, 32)
	   now we map this to a grid cell, so the x * CELL_SIZE gives the pixel position
	*/
	for {
		x := f32(rand.int_range(0, NUM_ROWS) * CELL_SIZE)
		y := f32(rand.int_range(0, NUM_ROWS) * CELL_SIZE)

		collides := false
		// Check that the food is not spawned on top of the snake
		// We just regenerate if the position is colliding
		for segment in snake.segments {
			if segment.x == x && segment.y == y {
				collides = true
				break
			}
		}
		if !collides {
			return rl.Vector2{x, y}
		}
	}
}

reset_game :: proc(data: ^GameData) {
	// Update high score if necessary
	if data.score > data.high_score {
		data.high_score = data.score
	}

	data.score = 0
	data.speed = 0.3
	data.head_index = 0

	// Clear memory for segments and make new snake
	delete(data.snake.segments)
	data.snake = make_snake(3)

	// reset food position
	data.food_pos = spawn_food(&data.snake)

	// pause the game
	data.state = .GAME_OVER
}

update_snake :: proc(state: ^GameData) {
	// Store old head location
	old_head := state.snake.segments[state.head_index]

	// Direction vectors for each direction
	direction_delta := DIRECTION_DELTA

	// Move head and wrap around the window for x and y
	delta := direction_delta[state.snake.direction]
	new_head := rl.Vector2 {
		math.mod(old_head.x + delta.x + WINDOW_SIZE, WINDOW_SIZE),
		math.mod(old_head.y + delta.y + WINDOW_SIZE, WINDOW_SIZE),
	}

	// Check if we have collided with the snake's body
	for segment in state.snake.segments {
		if new_head.x == segment.x && new_head.y == segment.y {
			reset_game(state)
			return
		}
	}

	if new_head.x == state.food_pos.x && new_head.y == state.food_pos.y {
		// Food eaten: insert new head without consuming the tail (snake grows)
		// Play chomp sound
		rl.PlaySound(state.chomp)
		inject_at(&state.snake.segments, state.head_index, new_head)
		state.food_pos = spawn_food(&state.snake)

		// Increase speed and score
		if state.speed > 0.1 {
			state.speed -= 0.005
		}
		state.score += 1
	} else {
		// No food: cycle head to tail and overwrite it (snake moves)
		if state.head_index == 0 {
			state.head_index = len(state.snake.segments) - 1
		} else {
			state.head_index -= 1
		}
		state.snake.segments[state.head_index] = new_head
	}

	// unlock the direction after a move has been made
	state.snake.direction_locked = false
}

update_direction :: proc(snake: ^Snake) {
	// We shouldn't update the direction if we haven't updated in our game tick yet.
	if snake.direction_locked {
		return
	}

	opposite := [Direction]Direction {
		.RIGHT = .LEFT,
		.LEFT  = .RIGHT,
		.DOWN  = .UP,
		.UP    = .DOWN,
	}

	key_to_dir := [Direction]rl.KeyboardKey {
		.RIGHT = .RIGHT,
		.LEFT  = .LEFT,
		.DOWN  = .DOWN,
		.UP    = .UP,
	}

	for dir in Direction {
		if rl.IsKeyPressed(key_to_dir[dir]) && snake.direction != opposite[dir] {
			snake.direction = dir
			snake.direction_locked = true
			return
		}
	}
}

make_snake :: proc(num_segments: int) -> Snake {
	snake: Snake
	center := rl.Vector2{WINDOW_SIZE / 2, WINDOW_SIZE / 2}

	// Starting with a 3-segment snake at the center
	for seg in 0 ..< num_segments {
		append(&snake.segments, rl.Vector2{center.x - f32(CELL_SIZE * seg), center.y})
	}

	// set initial direction
	snake.direction = .RIGHT

	return snake
}

draw_score_text :: proc(text: cstring, color: rl.Color, yPos: i32) {
	text_width := rl.MeasureText(text, 20)
	rl.DrawText(text, WINDOW_SIZE - text_width - 20, yPos, 20, color)
}

draw_center_text :: proc(text: cstring, color: rl.Color) {
	text_width := rl.MeasureText(text, 40)
	rl.DrawText(text, WINDOW_SIZE / 2 - text_width / 2, WINDOW_SIZE / 2 - 20, 40, color)
}
