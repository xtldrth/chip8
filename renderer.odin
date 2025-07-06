package chip8

import "core:fmt"
import rl "vendor:raylib"

rl_render_display :: proc(vram: [32][64]u8, pixel_size: i32) {
	for y in 0 ..< 32 {
		for val, x in vram[y] {
			x, y := i32(x), i32(y)
			if val == 1 {
				rl.DrawRectangle(x * pixel_size, y * pixel_size, pixel_size, pixel_size, rl.GREEN)
			}
		}
	}
}
