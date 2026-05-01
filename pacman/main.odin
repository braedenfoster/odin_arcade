package main

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(800, 600, "Pacman")
	defer rl.CloseWindow()

}
