package chip8

import "core:flags"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

PIXEL_SIZE :: 20

main :: proc() {
	Options :: struct {
		file: os.Handle `args:"pos=0,required,file=r", usage:"Input binary file"`,
	}
	opt: Options
	style: flags.Parsing_Style = .Unix

	flags.parse_or_exit(&opt, os.args, style)

	rl.InitWindow(64 * PIXEL_SIZE, 32 * PIXEL_SIZE, "chip8")
	rl.SetTargetFPS(60)
	emu := Chip8{}
	init_emu(&emu, rl_is_key_pressed, rl_is_key_up, rl_get_key_pressed)
	l := emu_load_program(&emu, os.stream_from_handle(opt.file))
	paused := true
	step := false
	fmt.printfln("%X", emu.mem[0x200:0x200 + l])
	for !rl.WindowShouldClose() {
		// fmt.printfln("%v", emu.vram)
		step = false
		if rl.IsKeyPressed(.SPACE) {
			paused = !paused
		}
		if rl.IsKeyPressed(.N) {
			step = true
		}
		if step {
			paused = true
		}
		if !paused || step {
			fmt.printfln("pc = 0x%X", emu.pc)
			fmt.printfln("sp = 0x%v", emu.sp)
			fmt.printfln("idx = 0x%X", emu.index_reg)
			fmt.printfln("regs = %v", emu.regs)
			fmt.printfln("stack = %v", emu.stack)
			emu_tick(&emu)
			fmt.printfln("************************\n")
		}
		rl.BeginDrawing()
		{
			rl.DrawFPS(0, 0)
			rl.ClearBackground(rl.BLACK)
			rl_render_display(emu.vram, PIXEL_SIZE)
		}
		rl.EndDrawing()
	}
}
