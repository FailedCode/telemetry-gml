
if (keyboard_check_pressed(vk_escape)) {
	game_end();
}

if (keyboard_check_pressed(vk_enter)) {
	throw("Test Exception");
}