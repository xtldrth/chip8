package chip8

import "core:fmt"
import "core:io"
import "core:math/bits"
import "core:math/rand"
import "core:mem"
import "core:os"

Key :: enum u8 {
	ZERO,
	ONE,
	TWO,
	THREE,
	FOUR,
	FIVE,
	SIX,
	SEVEN,
	EIGHT,
	NINE,
	A,
	B,
	C,
	D,
	E,
	F,
}

is_key_pressed :: proc(_: ^Chip8, key: u8) -> bool
is_key_up :: proc(_: ^Chip8, key: u8) -> bool
get_key_pressed :: proc(_: ^Chip8) -> Maybe(Key)


get_12bit :: proc(opcode: u16) -> u16 {
	return 0x0FFF & opcode
}

get_4bit_byte :: proc(opcode: u16) -> (u8, u8) {
	return cast(u8)((0x0F00 & opcode) >> 8), cast(u8)(0x00FF & opcode)
}

get_4bit_4bit_4bit :: proc(opcode: u16) -> (u8, u8, u8) {
	return cast(u8)((0x0F00 & opcode) >> 8),
		cast(u8)((0x00F0 & opcode) >> 4),
		cast(u8)(0x000F & opcode)
}

Chip8 :: struct {
	mem:             [4096]u8,
	vram:            [32][64]u8,
	stack:           [16]u16,
	regs:            [16]u8,
	index_reg:       u16,
	pc:              u16,
	delay_timer:     u8,
	sound_timer:     u8,
	sp:              u8,
	is_pc_changed:   bool,
	is_key_pressed:  is_key_pressed,
	is_key_up:       is_key_up,
	get_key_pressed: get_key_pressed,
}

init_emu :: proc(
	emu: ^Chip8,
	is_key_pressed: is_key_pressed,
	is_key_up: is_key_up,
	get_key_pressed: get_key_pressed,
) {
	emu.mem = 0
	emu.vram = 0
	emu.stack = 0
	emu.regs = 0
	emu.pc = 0x200
	emu.is_pc_changed = false
	emu.is_key_pressed = is_key_pressed
	emu.is_key_up = is_key_up
	emu.get_key_pressed = get_key_pressed
	emu_load_sprites(emu)
}

emu_load_program :: proc(emu: ^Chip8, program_opcodes: io.Reader) -> int {
	if n, err := io.read(program_opcodes, emu.mem[0x200:]); err != nil {
		fmt.panicf("ERROR: %e", err)
	} else {
		return n
	}
}

emu_load_sprites :: proc(emu: ^Chip8) {
	sprites := [?]u8 {
		0xF0,
		0x90,
		0x90,
		0x90,
		0xF0, // 0
		0x20,
		0x60,
		0x20,
		0x20,
		0x70, // 1
		0xF0,
		0x10,
		0xF0,
		0x80,
		0xF0, // 2
		0xF0,
		0x10,
		0xF0,
		0x10,
		0xF0, // 3
		0x90,
		0x90,
		0xF0,
		0x10,
		0x10, // 4
		0xF0,
		0x80,
		0xF0,
		0x10,
		0xF0, // 5
		0xF0,
		0x80,
		0xF0,
		0x90,
		0xF0, // 6  TODO: check ended here
		0xF0,
		0x10,
		0x20,
		0x40,
		0x40, // 7
		0xF0,
		0x90,
		0xF0,
		0x90,
		0xF0, // 8
		0xF0,
		0x90,
		0xF0,
		0x10,
		0xF0, // 9
		0xF0,
		0x90,
		0xF0,
		0x90,
		0x90, // A
		0xE0,
		0x90,
		0xE0,
		0x90,
		0xE0, // B
		0xF0,
		0x80,
		0x80,
		0x80,
		0xF0, // C
		0xE0,
		0x90,
		0x90,
		0x90,
		0xE0, // D
		0xF0,
		0x80,
		0xF0,
		0x80,
		0xF0, // E
		0xF0,
		0x80,
		0xF0,
		0x80,
		0x80, // F
	}
	mem.copy(rawptr(&emu.mem[0]), rawptr(&sprites[0]), len(sprites))
}

emu_tick :: proc(emu: ^Chip8) {
	emu.is_pc_changed = false
	opcode := cast(u16)emu.mem[emu.pc] << 8 | cast(u16)emu.mem[emu.pc + 1]
	_12bits := get_12bit(opcode)
	vx, byte := get_4bit_byte(opcode)
	_, vy, n := get_4bit_4bit_4bit(opcode)
	fmt.printfln("opcode = %X", opcode)
	fmt.printfln("opcode starts with = %X", opcode & 0xF000)
	switch (opcode & 0xF000) >> 12 {
	case 0:
		if vx == 0 && vy == 0xE && n == 0 {
			emu_cls(emu)
		} else if vx == 0 && vy == n && n == 0xE {
			emu_ret(emu)
		}
	case 1:
		emu_jp(emu, _12bits)
	case 2:
		emu_call(emu, _12bits)
	case 3:
		emu_se(emu, vx, byte)
	case 4:
		emu_sne(emu, vx, byte)
	case 5:
		emu_se_reg(emu, vx, vy)
	case 6:
		emu_ld(emu, vx, byte)
	case 7:
		emu_add(emu, vx, byte)
	case 8:
		switch n {
		case 0:
			emu_ld_regs(emu, vx, vy)
		case 1:
			emu_or(emu, vx, vy)
		case 2:
			emu_and(emu, vx, vy)
		case 3:
			emu_xor(emu, vx, vy)
		case 4:
			emu_add_regs(emu, vx, vy)
		case 5:
			emu_sub(emu, vx, vy)
		case 6:
			emu_shr(emu, vx)
		case 7:
			emu_subn(emu, vx, vy)
		case 0xE:
			emu_shl(emu, vx)
		}
	case 9:
		emu_sne_regs(emu, vx, vy)
	case 0xA:
		emu_ld_idx(emu, _12bits)
	case 0xB:
		emu_jp_v0(emu, _12bits)
	case 0xC:
		emu_rnd(emu, vx, byte)
	case 0xD:
		emu_drw(emu, vx, vy, n)
	case 0xE:
		switch byte {
		case 0x9E:
			emu_skp_reg(emu, vx)
		case 0xA1:
			emu_sknp_reg(emu, vx)
		}
	case 0xF:
		switch byte {
		case 0x07:
			emu_ld_vx_dt(emu, vx)
		case 0x0A:
			emu_ld_k(emu, vx)
		case 0x15:
			emu_ld_dt_vx(emu, vx)
		case 0x18:
			emu_ld_st(emu, vx)
		case 0x1E:
			emu_add_i(emu, vx)
		case 0x29:
			emu_ld_f(emu, vx)
		case 0x33:
			emu_ld_b(emu, vx)
		case 0x55:
			emu_ld_i_vx(emu, vx)
		case 0x64:
			emu_ld_vx_i(emu, vx)
		}
	}
	if !emu.is_pc_changed {
		emu.pc += 2
	}
}


emu_cls :: proc(emu: ^Chip8) {
	fmt.println("cls")
	emu.vram *= 0
}

emu_ret :: proc(emu: ^Chip8) {
	fmt.println("ret")
	emu.is_pc_changed = true
	emu.pc = emu.stack[emu.sp]
	emu.sp -= 1
}

emu_jp :: proc(emu: ^Chip8, addr: u16) {
	fmt.println("jp")
	emu.is_pc_changed = true
	emu.pc = addr
}

emu_call :: proc(emu: ^Chip8, addr: u16) {
	fmt.println("call")
	emu.is_pc_changed = true
	emu.sp += 1
	emu.stack[emu.sp] = emu.pc
	emu.pc = addr
}

emu_se :: proc(emu: ^Chip8, vx, val: u8) {
	if emu.regs[vx] == val {
		// emu.is_pc_changed = true
		emu.pc += 2
	}
}

emu_sne :: proc(emu: ^Chip8, vx, val: u8) {
	if emu.regs[vx] != val {
		// emu.is_pc_changed = true
		emu.pc += 2
	}
}

emu_se_reg :: proc(emu: ^Chip8, vx, vy: u8) {
	if emu.regs[vx] == emu.regs[vy] {
		// emu.is_pc_changed = true
		emu.pc += 2
	}
}

emu_ld :: proc(emu: ^Chip8, vx, val: u8) {
	fmt.println("here")
	emu.regs[vx] = val
}


emu_add :: proc(emu: ^Chip8, vx, val: u8) {
	emu.regs[vx] += val
}

emu_ld_regs :: proc(emu: ^Chip8, vx, vy: u8) {
	emu.regs[vx] = emu.regs[vy]
}

emu_or :: proc(emu: ^Chip8, vx, vy: u8) {
	emu.regs[vx] |= emu.regs[vy]
}

emu_and :: proc(emu: ^Chip8, vx, vy: u8) {
	emu.regs[vx] &= emu.regs[vy]
}

emu_xor :: proc(emu: ^Chip8, vx, vy: u8) {
	emu.regs[vx] ~= emu.regs[vy]
}

emu_add_regs :: proc(emu: ^Chip8, vx, vy: u8) {
	overflow: bool
	emu.regs[vx], overflow = bits.overflowing_add(emu.regs[vx], emu.regs[vy])
	emu.regs[0xF] = 1 if overflow else 0
}

emu_sub :: proc(emu: ^Chip8, vx, vy: u8) {
	xval, yval := emu.regs[vx], emu.regs[vy]
	emu.regs[vx] -= emu.regs[vy]
	emu.regs[0xF] = 1 if xval > yval else 0
}

emu_shr :: proc(emu: ^Chip8, vx: u8) {
	emu.regs[0xF] = emu.regs[vx] & 1
	emu.regs[vx] >>= 1
}

emu_subn :: proc(emu: ^Chip8, vx, vy: u8) {
	xval, yval := emu.regs[vx], emu.regs[vy]
	emu.regs[vx] = emu.regs[vy] - emu.regs[vx]
	emu.regs[0xF] = 1 if yval > xval else 0
}

emu_shl :: proc(emu: ^Chip8, vx: u8) {
	emu.regs[0xF] = (emu.regs[vx] >> 7) & 1
	emu.regs[vx] <<= 1
}

emu_sne_regs :: proc(emu: ^Chip8, vx, vy: u8) {
	emu_sne(emu, vx, emu.regs[vy])
}

emu_ld_idx :: proc(emu: ^Chip8, addr: u16) {
	emu.index_reg = addr
}

emu_jp_v0 :: proc(emu: ^Chip8, addr: u16) {
	emu.is_pc_changed = true
	emu.pc = addr + cast(u16)(emu.regs[0])
}

emu_rnd :: proc(emu: ^Chip8, vx, val: u8) {
	emu.regs[vx] = val + cast(u8)rand.uint32()
}

// emu_drw :: proc(emu: ^Chip8, vx, vy, n: u8) {
// 	x, y := emu.regs[vx], emu.regs[vy] // TODO: maybe this is not necessary
// 	emu.regs[0xF] = 0
// 	bytes := emu.mem[emu.index_reg:emu.index_reg + cast(u16)n]
// 	for row in y ..< y + n {
// 		row := row
// 		if row > 32 {
// 			row = row % 32
// 		}
// 		if emu.regs[0xF] != 1 && emu.vram[row][x] & bytes[row] > 0 {
// 			emu.regs[0xF] = 1
// 		}
// 		emu.vram[row][x] ~= bytes[row]
// 	}
// }

split_byte :: proc(byte: u8) -> [8]u8 {
	res := [8]u8{}
	for idx, byte := 0, byte; byte > 0; byte >>= 1 {
		res[7 - idx] = byte & 1
		idx += 1
	}
	return res
}
emu_drw :: proc(emu: ^Chip8, vx, vy, n: u8) {
	x, y := emu.regs[vx] % 64, emu.regs[vy]
	emu.regs[0xF] = 0
	bytes := emu.mem[emu.index_reg:emu.index_reg + cast(u16)n]
	idx := 0
	for row in y ..< y + n {
		row := row % 32
		bits := split_byte(bytes[idx])
		for bit, bit_index in bits {
			if emu.regs[0xF] != 1 && emu.vram[row][(x + bit) % 64] & bytes[idx] == 1 {
				emu.regs[0xF] = 1
			}
			emu.vram[row][(x + cast(u8)bit_index) % 64] ~= bit
		}
		idx += 1
	}
}

emu_skp_reg :: proc(emu: ^Chip8, vx: u8) {
	if emu->is_key_pressed(emu.regs[vx]) {
		// emu.is_pc_changed = true
		emu.pc += 2
	}
}

emu_sknp_reg :: proc(emu: ^Chip8, vx: u8) {
	if emu->is_key_up(emu.regs[vx]) {
		// emu.is_pc_changed = true
		emu.pc += 2
	}
}

emu_ld_vx_dt :: proc(emu: ^Chip8, vx: u8) {
	emu.regs[vx] = emu.delay_timer
}

emu_ld_k :: proc(emu: ^Chip8, vx: u8) {
	key, ok := emu->get_key_pressed().?
	if !ok {
		emu.pc -= 2
		return
	}
	emu.regs[vx] = transmute(u8)key
}

emu_ld_dt_vx :: proc(emu: ^Chip8, vx: u8) {
	emu.delay_timer = emu.regs[vx]
}


emu_ld_st :: proc(emu: ^Chip8, vx: u8) {
	emu.sound_timer = emu.regs[vx]
}

emu_add_i :: proc(emu: ^Chip8, vx: u8) {
	emu.index_reg += cast(u16)emu.regs[vx]
}

emu_ld_f :: proc(emu: ^Chip8, vx: u8) {
	emu.index_reg = cast(u16)emu.regs[vx] * 5
}

emu_ld_b :: proc(emu: ^Chip8, vx: u8) {
	val := emu.regs[vx]
	emu.mem[emu.index_reg + 2] = val % 10
	val /= 10
	emu.mem[emu.index_reg + 1] = val % 10
	val /= 10
	emu.mem[emu.index_reg] = val
}

emu_ld_i_vx :: proc(emu: ^Chip8, vx: u8) {
	mem.copy(rawptr(&emu.mem[emu.index_reg]), rawptr(&emu.regs[0]), cast(int)vx)
}

emu_ld_vx_i :: proc(emu: ^Chip8, vx: u8) {
	mem.copy(rawptr(&emu.regs[0]), rawptr(&emu.mem[emu.index_reg]), cast(int)vx)
}
