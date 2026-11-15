import hexdit_core.sl
import disassembler.sl
import file_formats.sl
use("console", "enums", "list")

var TUI_CONSOLE_WIDTH = console.get_width() - 1
var TUI_CONSOLE_HEIGHT = console.get_height() - 2
var BOTTOM_BAR_POS = console.get_height() - 1

var BYTES_PER_ROW = 8
var HEX_X = 2
var ASCII_X = $HEX_X + ($BYTES_PER_ROW * 3) + 1
var EACH_PANEL_SIZE = $ASCII_X + $BYTES_PER_ROW + 1
var SEPARATOR = "|"
var DIS_X = $EACH_PANEL_SIZE + 2
var DIS_WIDTH = $TUI_CONSOLE_WIDTH - $DIS_X
var TUI_VISIBLE_ROWS = $BOTTOM_BAR_POS / 2

var HL_OPCODE_COLOR = $COLOR_MAGENTA
var HL_OPERAND_COLOR = $COLOR_YELLOW

enums.create_enum("LEFT_PANEL", "RIGHT_PANEL")

var focused_panel = $LEFT_PANEL;

var tui_pos = 0
var tui_nibble = 0
var tui_scroll = 0
var tui_status = "ready"
var tui_modified = false
var tui_back = List.new()
var tui_find_query = ""
var tui_find_low = ""
var tui_find_buf = ""
var tui_find_input = false
var tui_goto_mode = false

var ins_starts = List.new()
var ins_lens = List.new()
var ins_oplens = List.new()
var ins_texts = List.new()
var ins_targets = List.new()
var ins_next = 0

var tui_sel_idx = 0
var tui_sel_start = 0 - 1
var tui_sel_end = 0 - 1
var tui_sel_oplen = 0

var CURSOR_X = 0
var CURSOR_Y = 0 


def tui_calculate_line_pos then 
	if $focused_panel equ $LEFT_PANEL; then 
		$CURSOR_X = 0 
	else
		$CURSOR_X = $EACH_PANEL_SIZE
	end
end

def hexdit_change_focused_panel then
	if $focused_panel equ $LEFT_PANEL; then
		$focused_panel = $RIGHT_PANEL;
	else
		$focused_panel = $LEFT_PANEL;
	end
end

def tui_left_focused then
	if $focused_panel equ $LEFT_PANEL; then
		return true
	end
	return false
end

def tui_panel_name then
	if tui_left_focused() then
		return "HEX"
	end
	return "ASM"
end

def hexdit_print_line -> str then 
	console.cursor_position($CURSOR_X, $CURSOR_Y)
	io.print($str)
end

def hexdit_init_panel_sep then 
	var i = -1 while ({ $i = $i + 1 return $i < $TUI_CONSOLE_HEIGHT }) then 
		console.cursor_position($EACH_PANEL_SIZE, $i)
		io.print($SEPARATOR)
	end
end

def tui_fit -> str, width then
	var s = $str
	if $width < 1 then
		return ""
	end
	if string.len($s) > $width then
		$s = string.slice($s, 0, $width)
	end
	while string.len($s) < $width then
		$s = $s + " "
	end
	return $s
end

def tui_byte_hex -> num then
	if $num equ 0 then
		return "00"
	end
	if $num < 16 then
		return "0" + hexdit_convert_number_to_hexadecimal($num)
	end
	return hexdit_convert_number_to_hexadecimal($num)
end

def tui_offset_hex -> num then
	if $num equ 0 then
		return "0"
	end
	return hexdit_convert_number_to_hexadecimal($num)
end

def tui_ascii -> v then
	if $v < 32 or $v > 126 then
		return "."
	end
	return types.char_to_str(types.int_to_char($v))
end

def tui_hex_digit_value -> ckey then
	var ci = types.char_to_int($ckey)
	if $ci eqg 48 and $ci eql 57 then
		return $ci - 48
	end
	if $ci eqg 65 and $ci eql 70 then
		return $ci - 55
	end
	if $ci eqg 97 and $ci eql 102 then
		return $ci - 87
	end
	return -1
end

def tui_color_role -> role then
	if $role equ 1 then
		console.background_color($HL_OPCODE_COLOR)
		console.foreground_color($COLOR_BLACK)
	elif $role equ 2 then
		console.background_color($HL_OPERAND_COLOR)
		console.foreground_color($COLOR_BLACK)
	elif $role equ 3 then
		console.background_color($COLOR_WHITE)
		console.foreground_color($COLOR_BLACK)
	end
end

def tui_byte_role -> idx then
	if $idx eqg $tui_sel_start and $idx < $tui_sel_end then
		if $idx < $tui_sel_start + $tui_sel_oplen then
			return 1
		end
		return 2
	end
	return 0
end

def tui_decode_until -> bytes, size, limit then
	while $ins_next < $size and $ins_next eql $limit then
		var text = ff_unit_one($bytes, $ins_next, $size)
		List.push($ins_starts, $ins_next)
		List.push($ins_lens, $dis_len)
		List.push($ins_oplens, $dis_oplen)
		List.push($ins_texts, $text)
		List.push($ins_targets, $dis_target)
		$ins_next = $ins_next + $dis_len
	end
end

def tui_find_ins -> p then
	var lo = 0
	var hi = List.len($ins_starts) - 1
	var ans = 0
	while $lo eql $hi then
		var mid = ($lo + $hi) / 2
		var st = List.get($ins_starts, $mid)
		if $st eql $p then
			$ans = $mid
			$lo = $mid + 1
		else
			$hi = $mid - 1
		end
	end
	return $ans
end

def tui_first_ins_from -> p then
	var total = List.len($ins_starts)
	if $total equ 0 then
		return 0
	end
	var i = tui_find_ins($p)
	if List.get($ins_starts, $i) < $p then
		return $i + 1
	end
	return $i
end

def tui_invalidate -> p then
	if $p < $ins_next then
		var idx = tui_find_ins($p)
		var st = List.get($ins_starts, $idx)
		while List.len($ins_starts) > $idx then
			var last = List.len($ins_starts) - 1
			List.remove($ins_starts, $last)
			List.remove($ins_lens, $last)
			List.remove($ins_oplens, $last)
			List.remove($ins_texts, $last)
			List.remove($ins_targets, $last)
		end
		$ins_next = $st
	end
end

def tui_follow_scroll then
	var row = $tui_pos / $BYTES_PER_ROW
	if $row < $tui_scroll then
		$tui_scroll = $row
	end
	if $row eqg $tui_scroll + $TUI_VISIBLE_ROWS then
		$tui_scroll = $row - $TUI_VISIBLE_ROWS + 1
	end
end

def tui_set_pos -> newpos, size then
	if $size > 0 then
		var np = $newpos
		if $np < 0 then
			$np = 0
		end
		if $np > $size - 1 then
			$np = $size - 1
		end
		$tui_pos = $np
		$tui_nibble = 0
		tui_follow_scroll()
	end
end

def tui_move -> delta, size then
	tui_set_pos($tui_pos + $delta, $size)
end

def tui_snap_to_ins -> bytes, size then
	if $size > 0 then
		tui_decode_until($bytes, $size, $tui_pos)
		var i = tui_find_ins($tui_pos)
		tui_set_pos(List.get($ins_starts, $i), $size)
	end
end

def tui_move_ins -> delta, bytes, size then
	if $size > 0 then
		tui_decode_until($bytes, $size, $tui_pos + 32)
		var cur = tui_find_ins($tui_pos)
		var ni = $cur + $delta
		var total = List.len($ins_starts)
		if $ni < 0 then
			$ni = 0
		end
		if $ni > $total - 1 then
			$ni = $total - 1
		end
		tui_set_pos(List.get($ins_starts, $ni), $size)
	end
end

def tui_place -> newpos, bytes, size then
	tui_set_pos($newpos, $size)
	if tui_left_focused() equ false then
		tui_snap_to_ins($bytes, $size)
	end
end

def tui_goto_code_start -> bytes, size then
	if $ff_code_start eqg 0 and $ff_code_start < $size then
		List.push($tui_back, $tui_pos)
		tui_place($ff_code_start, $bytes, $size)
		$tui_status = "code start 0x" + tui_offset_hex($ff_code_start)
	else
		$tui_status = "no code start in this file"
	end
end

def tui_follow_jump -> bytes, size then
	if $size > 0 then
		tui_decode_until($bytes, $size, $tui_pos + 32)
		var idx = tui_find_ins($tui_pos)
		var target = List.get($ins_targets, $idx)
		if $target eqg 0 and $target < $size then
			List.push($tui_back, $tui_pos)
			tui_place($target, $bytes, $size)
			$tui_status = "jumped to 0x" + tui_offset_hex($target)
		else
			$tui_status = "no jump target here"
		end
	end
end

def tui_jump_back -> bytes, size then
	var n = List.len($tui_back)
	if $n > 0 then
		var p = List.get($tui_back, $n - 1)
		List.remove($tui_back, $n - 1)
		tui_place($p, $bytes, $size)
		$tui_status = "back to 0x" + tui_offset_hex($p)
	else
		$tui_status = "nothing to go back to"
	end
end

def tui_lower -> v then
	if $v eqg 65 and $v eql 90 then
		return $v + 32
	end
	return $v
end

def tui_lower_str -> s then
	var res = ""
	var i = 0
	var n = string.len($s)
	while $i < $n then
		var v = tui_lower(types.char_to_int(string.char_at($s, $i)))
		$res = $res + types.char_to_str(types.int_to_char($v))
		$i = $i + 1
	end
	return $res
end

def tui_text_has -> text, query then
	var tl = string.len($text)
	var ql = string.len($query)
	if $ql equ 0 or $ql > $tl then
		return false
	end
	var first = types.char_to_int(string.char_at($query, 0))
	var i = 0
	while $i + $ql eql $tl then
		if tui_lower(types.char_to_int(string.char_at($text, $i))) equ $first then
			var j = 1
			var same = true
			while $j < $ql and $same then
				if tui_lower(types.char_to_int(string.char_at($text, $i + $j))) neq types.char_to_int(string.char_at($query, $j)) then
					$same = false
				end
				$j = $j + 1
			end
			if $same then
				return true
			end
		end
		$i = $i + 1
	end
	return false
end

def tui_search_fwd -> bytes, size, start then
	var i = $start
	while true then
		var total = List.len($ins_starts)
		while $i < $total then
			if tui_text_has(List.get($ins_texts, $i), $tui_find_low) then
				return $i
			end
			$i = $i + 1
		end
		if $ins_next eqg $size then
			return 0 - 1
		end
		tui_decode_until($bytes, $size, $ins_next + 4096)
	end
	return 0 - 1
end

def tui_search_back -> start then
	var i = $start
	while $i eqg 0 then
		if tui_text_has(List.get($ins_texts, $i), $tui_find_low) then
			return $i
		end
		$i = $i - 1
	end
	return 0 - 1
end

def tui_find_go -> bytes, size, step then
	if string.len($tui_find_query) equ 0 then
		$tui_status = "no search text, press Ctrl+F"
		return 0
	end
	if tui_left_focused() then
		hexdit_change_focused_panel()
	end
	if $size > 0 then
		tui_decode_until($bytes, $size, $tui_pos + 32)
		var cur = tui_find_ins($tui_pos)
		var hit = 0 - 1
		if $step > 0 then
			$hit = tui_search_fwd($bytes, $size, $cur + 1)
		else
			$hit = tui_search_back($cur - 1)
		end
		if $hit eqg 0 then
			var at = List.get($ins_starts, $hit)
			tui_set_pos($at, $size)
			$tui_status = "found [" + $tui_find_query + "] at 0x" + tui_offset_hex($at)
		else
			$tui_status = "[" + $tui_find_query + "] not found"
		end
	end
	return 0
end

def tui_goto_resolve -> q then
	var n = string.len($q)
	var i = 0
	var by_va = false
	if types.char_to_int(string.char_at($q, 0)) equ 118 then
		$by_va = true
		$i = 1
	end
	if $n - $i > 2 then
		if types.char_to_int(string.char_at($q, $i)) equ 48 and types.char_to_int(string.char_at($q, $i + 1)) equ 120 then
			$i = $i + 2
		end
	end
	if $i eqg $n then
		return 0 - 1
	end
	var v = 0
	while $i < $n then
		var d = tui_hex_digit_value(string.char_at($q, $i))
		if $d < 0 then
			return 0 - 1
		end
		$v = $v * 16 + $d
		$i = $i + 1
	end
	if $by_va then
		return ff_va_to_off($v)
	end
	return $v
end

def tui_goto_run -> bytes, size, text then
	var q = tui_lower_str($text)
	if string.len($q) equ 0 then
		$tui_status = "goto cancelled"
		return 0
	end
	$tui_status = "bad or unmapped address"
	var off = tui_goto_resolve($q)
	if $off eqg 0 and $off < $size then
		List.push($tui_back, $tui_pos)
		tui_place($off, $bytes, $size)
		$tui_status = "goto 0x" + tui_offset_hex($off)
	end
	return 0
end

def tui_goto_open then
	$tui_goto_mode = true
	$tui_find_buf = ""
	$tui_find_input = true
end

def tui_find_open then
	$tui_goto_mode = false
	if tui_left_focused() then
		hexdit_change_focused_panel()
	end
	$tui_find_buf = ""
	$tui_find_input = true
end

def tui_find_commit -> bytes, size then
	$tui_find_input = false
	if $tui_goto_mode then
		$tui_goto_mode = false
		return tui_goto_run($bytes, $size, $tui_find_buf)
	end
	if string.len($tui_find_buf) equ 0 then
		$tui_status = "search cancelled"
		return 0
	end
	$tui_find_query = $tui_find_buf
	$tui_find_low = tui_lower_str($tui_find_buf)
	tui_find_go($bytes, $size, 1)
	return 0
end

def tui_find_backspace then
	var n = string.len($tui_find_buf)
	if $n > 0 then
		$tui_find_buf = string.slice($tui_find_buf, 0, $n - 1)
	end
end

def tui_find_key -> ckey, mod, bytes, size then
	if types.is_char($ckey) then
		var code = types.char_to_int($ckey)
		if $code equ 13 or $code equ 10 then
			tui_find_commit($bytes, $size)
		elif $code equ 27 then
			$tui_find_input = false
			$tui_status = "search cancelled"
		elif $code equ 8 or $code equ 127 then
			tui_find_backspace()
		elif $code eqg 32 and $code < 127 and $mod neq $MOD_CTRL then
			$tui_find_buf = $tui_find_buf + types.char_to_str($ckey)
		end
	else
		if $ckey equ $KEY_F6 then
			tui_find_commit($bytes, $size)
		elif $ckey equ $KEY_F7 then
			$tui_find_input = false
			$tui_status = "search cancelled"
		elif $ckey equ $KEY_LEFT then
			tui_find_backspace()
		end
	end
end

def tui_apply_digit -> bytes, digit then
	tui_invalidate($tui_pos)
	var cur = hexdit_get($bytes, $tui_pos)
	var newval = 0
	if $tui_nibble equ 0 then
		$newval = $digit * 16 + ($cur % 16)
		$tui_nibble = 1
	else
		$newval = ($cur / 16) * 16 + $digit
		$tui_nibble = 0
	end
	$tui_modified = true
	$tui_status = "edited 0x" + tui_offset_hex($tui_pos)
	return hexdit_edit_byte($bytes, $tui_pos, $newval)
end

def hexdit_save_file -> file_path, bytes then
	return file.write($file_path, $bytes)
end

def hexdit_init_bottom_panel then
	console.background_color($COLOR_WHITE)
	console.foreground_color($COLOR_BLACK)
	console.cursor_position(0, $BOTTOM_BAR_POS)

	var message = " " + tui_panel_name() + " 0x" + tui_offset_hex($tui_pos) + " [" + $ff_name + "]"
	var cur_va = ff_off_to_va($tui_pos)
	if $cur_va eqg 0 then
		$message = $message + " va 0x" + tui_offset_hex($cur_va)
	end
	if $tui_sel_start eqg 0 then
		$message = $message + " | unit 0x" + tui_offset_hex($tui_sel_start) + " len " + types.int_to_str($tui_sel_end - $tui_sel_start)
	end
	$message = $message + " | " + $tui_status
	if $tui_modified then
		$message = $message + " (modified)"
	end
	$message = $message + " | F3 code F4 jump F5 back F6 next F7 prev ^F find ^G goto ^S save ^Q quit"
	if $tui_find_input then
		var plabel = " search: "
		if $tui_goto_mode then
			$plabel = " goto (hex, vHEX): "
		end
		$message = $plabel + $tui_find_buf + "_ | F6 ok, F7 cancel, Left delete"
	end
	io.print(tui_fit($message, $TUI_CONSOLE_WIDTH))
	console.reset_color()
end

def hexdit_render_row -> bytes, size, row, y then
	var base = $row * $BYTES_PER_ROW

	console.reset_color()
	console.cursor_position($HEX_X, $y)
	var col = 0
	while $col < $BYTES_PER_ROW then
		var idx = $base + $col
		if $idx < $size then
			var role = tui_byte_role($idx)
			var spacerole = 0
			if $role > 0 and $idx + 1 < $tui_sel_end and $col < $BYTES_PER_ROW - 1 then
				$spacerole = $role
			end
			if $idx equ $tui_pos and tui_left_focused() then
				$role = 3
			end
			tui_color_role($role)
			io.print(tui_byte_hex(hexdit_get($bytes, $idx)))
			console.reset_color()
			tui_color_role($spacerole)
			io.print(" ")
			console.reset_color()
		else
			io.print("   ")
		end
		$col = $col + 1
	end

	console.cursor_position($ASCII_X, $y)
	var acol = 0
	while $acol < $BYTES_PER_ROW then
		var aidx = $base + $acol
		if $aidx < $size then
			var arole = tui_byte_role($aidx)
			if $aidx equ $tui_pos and tui_left_focused() then
				$arole = 3
			end
			tui_color_role($arole)
			io.print(tui_ascii(hexdit_get($bytes, $aidx)))
			console.reset_color()
		else
			io.print(" ")
		end
		$acol = $acol + 1
	end

	console.cursor_position($DIS_X, $y)
	var used = 0
	var first = true
	var total = List.len($ins_starts)
	var ii = tui_first_ins_from($base)
	while $ii < $total and $used < $DIS_WIDTH then
		var st = List.get($ins_starts, $ii)
		if $st eqg $base + $BYTES_PER_ROW then
			break
		end
		if $first equ false then
			var sep = "; "
			var room = $DIS_WIDTH - $used
			if $room < 1 then
				$sep = ""
			elif string.len($sep) > $room then
				$sep = string.slice($sep, 0, $room)
			end
			io.print($sep)
			$used = $used + string.len($sep)
		end
		$first = false
		var txt = List.get($ins_texts, $ii)
		var room2 = $DIS_WIDTH - $used
		if $room2 > 0 then
			if string.len($txt) > $room2 then
				$txt = string.slice($txt, 0, $room2)
			end
			if $ii equ $tui_sel_idx then
				console.background_color($COLOR_WHITE)
				console.foreground_color($COLOR_BLACK)
			end
			io.print($txt)
			console.reset_color()
			$used = $used + string.len($txt)
		end
		$ii = $ii + 1
	end
	io.print(tui_fit("", $DIS_WIDTH - $used))
end

def hexdit_render -> bytes, size then
	console.begin_update()
	if $size > 0 then
		tui_decode_until($bytes, $size, (($tui_scroll + $TUI_VISIBLE_ROWS) * $BYTES_PER_ROW) + 16)
		tui_decode_until($bytes, $size, $tui_pos + 16)
		$tui_sel_idx = tui_find_ins($tui_pos)
		$tui_sel_start = List.get($ins_starts, $tui_sel_idx)
		$tui_sel_end = $tui_sel_start + List.get($ins_lens, $tui_sel_idx)
		$tui_sel_oplen = List.get($ins_oplens, $tui_sel_idx)
	end
	var k = 0
	while $k < $TUI_VISIBLE_ROWS then
		hexdit_render_row($bytes, $size, $tui_scroll + $k, 1 + $k * 2)
		$k = $k + 1
	end
	hexdit_init_bottom_panel()
	io.flush()
	console.end_update()
end

def hexdit_init_tui -> bytes, size, file_path then 
	ff_load($bytes, $size)
	console.raw_mode(true)
	console.enter_alt_screen()
	console.autowrap(false)
	console.cursor_visibility(false)
	console.clear()
	hexdit_init_panel_sep()
	hexdit_render($bytes, $size)

	while true then 
		var event = console.get_event()
		if $event equ $KEY_EVENT then
			if console.key_event.is_pressed() then
				var ckey = console.key_event.get_key()
				var mod = console.key_event.get_mod()

				if $tui_find_input then
					tui_find_key($ckey, $mod, $bytes, $size)
				elif types.is_char($ckey) then
					if $ckey equ 'q' and $mod equ $MOD_CTRL then
						console.reset_scroll_area()
						console.reset_color()
						console.cursor_visibility(true)
						console.autowrap(true)
						console.leave_alt_screen()
						console.raw_mode(false)
						break
					elif $ckey equ 's' and $mod equ $MOD_CTRL then
						hexdit_save_file($file_path, $bytes)
						$tui_modified = false
						$tui_status = "saved " + $file_path
					elif $ckey equ 'f' and $mod equ $MOD_CTRL then
						tui_find_open()
					elif $ckey equ 'g' and $mod equ $MOD_CTRL then
						tui_goto_open()
					elif $size > 0 then
						var digit = tui_hex_digit_value($ckey)
						if $digit eqg 0 then
							$bytes = tui_apply_digit($bytes, $digit)
							if ff_after_edit($bytes, $size, $tui_pos) then
								tui_invalidate(0)
							end
							if $tui_nibble equ 0 then
								tui_move(1, $size)
							end
						end
					end
				else
					if $ckey equ $KEY_TAB then
						hexdit_change_focused_panel()
					elif $ckey equ $KEY_F3 then
						tui_goto_code_start($bytes, $size)
					elif $ckey equ $KEY_F4 then
						tui_follow_jump($bytes, $size)
					elif $ckey equ $KEY_F5 then
						tui_jump_back($bytes, $size)
					elif $ckey equ $KEY_F6 then
						if string.len($tui_find_query) equ 0 then
							tui_find_open()
						else
							tui_find_go($bytes, $size, 1)
						end
					elif $ckey equ $KEY_F7 then
						tui_find_go($bytes, $size, 0 - 1)
					elif tui_left_focused() then
						if $ckey equ $KEY_LEFT then
							tui_move(0 - 1, $size)
						elif $ckey equ $KEY_RIGHT then
							tui_move(1, $size)
						elif $ckey equ $KEY_UP then
							tui_move(0 - $BYTES_PER_ROW, $size)
						elif $ckey equ $KEY_DOWN then
							tui_move($BYTES_PER_ROW, $size)
						elif $ckey equ $KEY_PAGE_UP then
							tui_move(0 - ($TUI_VISIBLE_ROWS * $BYTES_PER_ROW), $size)
						elif $ckey equ $KEY_PAGE_DOWN then
							tui_move($TUI_VISIBLE_ROWS * $BYTES_PER_ROW, $size)
						elif $ckey equ $KEY_HOME then
							tui_set_pos($tui_pos - ($tui_pos % $BYTES_PER_ROW), $size)
						elif $ckey equ $KEY_END then
							tui_set_pos($tui_pos - ($tui_pos % $BYTES_PER_ROW) + $BYTES_PER_ROW - 1, $size)
						end
					else
						if $ckey equ $KEY_UP or $ckey equ $KEY_LEFT then
							tui_move_ins(0 - 1, $bytes, $size)
						elif $ckey equ $KEY_DOWN or $ckey equ $KEY_RIGHT then
							tui_move_ins(1, $bytes, $size)
						elif $ckey equ $KEY_PAGE_UP then
							tui_move(0 - ($TUI_VISIBLE_ROWS * $BYTES_PER_ROW), $size)
							tui_snap_to_ins($bytes, $size)
						elif $ckey equ $KEY_PAGE_DOWN then
							tui_move($TUI_VISIBLE_ROWS * $BYTES_PER_ROW, $size)
							tui_snap_to_ins($bytes, $size)
						elif $ckey equ $KEY_HOME then
							tui_set_pos(0, $size)
						elif $ckey equ $KEY_END then
							tui_set_pos($size - 1, $size)
							tui_snap_to_ins($bytes, $size)
						end
					end
				end
				hexdit_render($bytes, $size)
			end
		end
	end
end
