package chip8

import rl "vendor:raylib"

rl_keymap :: [Key]rl.KeyboardKey {
	.ONE   = rl.KeyboardKey.ONE,
	.TWO   = rl.KeyboardKey.TWO,
	.THREE = rl.KeyboardKey.THREE,
	.C     = rl.KeyboardKey.FOUR,
	.FOUR  = rl.KeyboardKey.Q,
	.FIVE  = rl.KeyboardKey.W,
	.SIX   = rl.KeyboardKey.E,
	.D     = rl.KeyboardKey.R,
	.SEVEN = rl.KeyboardKey.A,
	.EIGHT = rl.KeyboardKey.S,
	.NINE  = rl.KeyboardKey.D,
	.E     = rl.KeyboardKey.F,
	.A     = rl.KeyboardKey.Z,
	.ZERO  = rl.KeyboardKey.X,
	.B     = rl.KeyboardKey.C,
	.F     = rl.KeyboardKey.V,
}


rl_is_key_pressed :: proc(_: ^Chip8, key: u8) -> bool {
	keymap := rl_keymap
	return rl.IsKeyDown(keymap[transmute(Key)key])
}

rl_is_key_up :: proc(_: ^Chip8, key: u8) -> bool {
	keymap := rl_keymap
	return rl.IsKeyUp(keymap[transmute(Key)key])

}

rl_get_key_pressed :: proc(_: ^Chip8) -> Maybe(Key) {
	keymap := rl_keymap
	pressed_key := rl.GetKeyPressed()
	if pressed_key == .KEY_NULL {
		return nil
	}
	for _, key in rl_keymap {
		if pressed_key == keymap[key] {
			return key
		}
	}
	return nil
}
