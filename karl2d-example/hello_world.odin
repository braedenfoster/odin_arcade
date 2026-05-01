package hello_world

import k2 "karl2d"

init :: proc() {
	k2.init(1280, 720, "Greetings from Karl2D!")
}

step :: proc() -> bool {

	if !k2.update() {
		return false
	}

	k2.clear(k2.LIGHT_BLUE)
	k2.draw_text("Let's make a an odin game", {50, 50}, 100, k2.DARK_BLUE)
	k2.present()

	k2.present()

	return true
}
