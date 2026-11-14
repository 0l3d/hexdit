import disassembler.sl
use("list", "types", "string")

var ff_name = "raw"
var ff_arch = "x86"
var ff_size = 0
var ff_c = 0
var ff_code_start = 0 - 1

var ff_f_starts = List.new()
var ff_f_ends = List.new()
var ff_f_texts = List.new()
var ff_a_starts = List.new()
var ff_a_ends = List.new()
var ff_a_kinds = List.new()
var ff_a_labels = List.new()
var ff_m_pos = List.new()
var ff_m_texts = List.new()

var FF_PE_DIRS = List.new()
List.push($FF_PE_DIRS, "export", "import", "resource", "exception", "security", "basereloc", "debug", "architecture", "globalptr", "tls", "load_config", "bound_import", "iat", "delay_import", "clr", "reserved")

def ff_reset then
	$ff_f_starts = List.new()
	$ff_f_ends = List.new()
	$ff_f_texts = List.new()
	$ff_a_starts = List.new()
	$ff_a_ends = List.new()
	$ff_a_kinds = List.new()
	$ff_a_labels = List.new()
	$ff_m_pos = List.new()
	$ff_m_texts = List.new()
	$ff_code_start = 0 - 1
end

def ff_u -> bytes, pos, n then
	var v = 0
	var mul = 1
	var i = 0
	while $i < $n then
		var at = $pos + $i
		if $at eqg 0 and $at < $ff_size then
			$v = $v + (hexdit_get($bytes, $at) * $mul)
		end
		$mul = $mul * 256
		$i = $i + 1
	end
	return $v
end

def ff_ub -> bytes, pos, n then
	var v = 0
	var i = 0
	while $i < $n then
		var at = $pos + $i
		var b = 0
		if $at eqg 0 and $at < $ff_size then
			$b = hexdit_get($bytes, $at)
		end
		$v = ($v * 256) + $b
		$i = $i + 1
	end
	return $v
end

def ff_hex -> n then
	if $n equ 0 then
		return "0"
	end
	if $n < 0 then
		return "?"
	end
	return hexdit_convert_number_to_hexadecimal($n)
end

def ff_dec -> n then
	return types.int_to_str($n)
end

def ff_str -> bytes, pos, n then
	var s = ""
	var i = 0
	while $i < $n then
		var v = ff_u($bytes, $pos + $i, 1)
		if $v < 32 or $v > 126 then
			$v = 63
		end
		$s = $s + types.char_to_str(types.int_to_char($v))
		$i = $i + 1
	end
	return $s
end

def ff_cstr -> bytes, pos, maxn then
	var s = ""
	var i = 0
	while $i < $maxn and $pos + $i < $ff_size then
		var v = ff_u($bytes, $pos + $i, 1)
		if $v equ 0 then
			break
		end
		if $v < 32 or $v > 126 then
			$v = 63
		end
		$s = $s + types.char_to_str(types.int_to_char($v))
		$i = $i + 1
	end
	return $s
end

def ff_find -> starts, p then
	var lo = 0
	var hi = List.len($starts) - 1
	var ans = 0 - 1
	while $lo eql $hi then
		var mid = ($lo + $hi) / 2
		if List.get($starts, $mid) eql $p then
			$ans = $mid
			$lo = $mid + 1
		else
			$hi = $mid - 1
		end
	end
	return $ans
end

def ff_field_add -> start, len, text then
	var e = $start + $len
	if $e > $ff_size then
		$e = $ff_size
	end
	if $start < 0 or $start eqg $e then
		return 0
	end
	var n = List.len($ff_f_starts)
	if $n equ 0 then
		List.push($ff_f_starts, $start)
		List.push($ff_f_ends, $e)
		List.push($ff_f_texts, $text)
		return 1
	end
	if $start eqg List.get($ff_f_ends, $n - 1) then
		List.push($ff_f_starts, $start)
		List.push($ff_f_ends, $e)
		List.push($ff_f_texts, $text)
		return 1
	end
	var i = 0
	while $i < $n then
		if $start < List.get($ff_f_ends, $i) and List.get($ff_f_starts, $i) < $e then
			return 0
		end
		$i = $i + 1
	end
	var ns = List.new()
	var ne = List.new()
	var nt = List.new()
	var placed = false
	var k = 0
	while $k < $n then
		if $placed equ false and $start < List.get($ff_f_starts, $k) then
			List.push($ns, $start)
			List.push($ne, $e)
			List.push($nt, $text)
			$placed = true
		end
		List.push($ns, List.get($ff_f_starts, $k))
		List.push($ne, List.get($ff_f_ends, $k))
		List.push($nt, List.get($ff_f_texts, $k))
		$k = $k + 1
	end
	if $placed equ false then
		List.push($ns, $start)
		List.push($ne, $e)
		List.push($nt, $text)
	end
	$ff_f_starts = $ns
	$ff_f_ends = $ne
	$ff_f_texts = $nt
	return 1
end

def ff_area_add -> start, end_pos, kind, label then
	var e = $end_pos
	if $e > $ff_size then
		$e = $ff_size
	end
	if $start < 0 or $start eqg $e then
		return 0
	end
	var n = List.len($ff_a_starts)
	if $n equ 0 then
		List.push($ff_a_starts, $start)
		List.push($ff_a_ends, $e)
		List.push($ff_a_kinds, $kind)
		List.push($ff_a_labels, $label)
		return 1
	end	
	if $start eqg List.get($ff_a_ends, $n - 1) then
		List.push($ff_a_starts, $start)
		List.push($ff_a_ends, $e)
		List.push($ff_a_kinds, $kind)
		List.push($ff_a_labels, $label)
		return 1
	end
	var i = 0
	while $i < $n then
		if $start < List.get($ff_a_ends, $i) and List.get($ff_a_starts, $i) < $e then
			return 0
		end
		$i = $i + 1
	end
	var ns = List.new()
	var ne = List.new()
	var nk = List.new()
	var nl = List.new()
	var placed = false
	var k = 0
	while $k < $n then
		if $placed equ false and $start < List.get($ff_a_starts, $k) then
			List.push($ns, $start)
			List.push($ne, $e)
			List.push($nk, $kind)
			List.push($nl, $label)
			$placed = true
		end
		List.push($ns, List.get($ff_a_starts, $k))
		List.push($ne, List.get($ff_a_ends, $k))
		List.push($nk, List.get($ff_a_kinds, $k))
		List.push($nl, List.get($ff_a_labels, $k))
		$k = $k + 1
	end
	if $placed equ false then
		List.push($ns, $start)
		List.push($ne, $e)
		List.push($nk, $kind)
		List.push($nl, $label)
	end
	$ff_a_starts = $ns
	$ff_a_ends = $ne
	$ff_a_kinds = $nk
	$ff_a_labels = $nl
	return 1
end

def ff_mark_add -> pos, text then
	if $pos < 0 or $pos eqg $ff_size then
		return 0
	end
	var n = List.len($ff_m_pos)
	if $n equ 0 then
		List.push($ff_m_pos, $pos)
		List.push($ff_m_texts, $text)
		return 1
	end
	if $pos eqg List.get($ff_m_pos, $n - 1) then
		List.push($ff_m_pos, $pos)
		List.push($ff_m_texts, $text)
		return 1
	end
	var ns = List.new()
	var nt = List.new()
	var placed = false
	var k = 0
	while $k < $n then
		if $placed equ false and $pos < List.get($ff_m_pos, $k) then
			List.push($ns, $pos)
			List.push($nt, $text)
			$placed = true
		end
		List.push($ns, List.get($ff_m_pos, $k))
		List.push($nt, List.get($ff_m_texts, $k))
		$k = $k + 1
	end
	if $placed equ false then
		List.push($ns, $pos)
		List.push($nt, $text)
	end
	$ff_m_pos = $ns
	$ff_m_texts = $nt
	return 1
end

def ff_seq_text -> name, len, text then
	ff_field_add($ff_c, $len, $name + "=" + $text)
	$ff_c = $ff_c + $len
end

def ff_seq -> bytes, name, len then
	ff_seq_text($name, $len, "0x" + ff_hex(ff_u($bytes, $ff_c, $len)))
end

def ff_in_field -> pos then
	var i = ff_find($ff_f_starts, $pos)
	if $i eqg 0 then
		if $pos < List.get($ff_f_ends, $i) then
			return true
		end
	end
	return false
end

def ff_first_code_start then
	var i = 0
	var n = List.len($ff_a_kinds)
	while $i < $n then
		if List.get($ff_a_kinds, $i) equ "code" then
			return List.get($ff_a_starts, $i)
		end
		$i = $i + 1
	end
	return 0 - 1
end

def ff_elf_type -> v then
	if $v equ 1 then
		return "REL"
	end
	if $v equ 2 then
		return "EXEC"
	end
	if $v equ 3 then
		return "DYN"
	end
	if $v equ 4 then
		return "CORE"
	end
	return "0x" + ff_hex($v)
end

def ff_elf_machine -> v then
	if $v equ 3 then
		return "x86"
	end
	if $v equ 62 then
		return "x86-64"
	end
	if $v equ 40 then
		return "ARM"
	end
	if $v equ 183 then
		return "AArch64"
	end
	if $v equ 243 then
		return "RISC-V"
	end
	return "0x" + ff_hex($v)
end

def ff_elf_ptype -> v then
	if $v equ 0 then
		return "NULL"
	end
	if $v equ 1 then
		return "LOAD"
	end
	if $v equ 2 then
		return "DYNAMIC"
	end
	if $v equ 3 then
		return "INTERP"
	end
	if $v equ 4 then
		return "NOTE"
	end
	if $v equ 6 then
		return "PHDR"
	end
	if $v equ 7 then
		return "TLS"
	end
	if $v equ 1685382480 then
		return "EH_FRAME"
	end
	if $v equ 1685382481 then
		return "GNU_STACK"
	end
	if $v equ 1685382482 then
		return "GNU_RELRO"
	end
	return "0x" + ff_hex($v)
end

def ff_pe_machine -> v then
	if $v equ 34404 then
		return "AMD64"
	end
	if $v equ 332 then
		return "i386"
	end
	if $v equ 43620 then
		return "ARM64"
	end
	return "0x" + ff_hex($v)
end

def ff_png_color -> v then
	if $v equ 0 then
		return "grayscale"
	end
	if $v equ 2 then
		return "RGB"
	end
	if $v equ 3 then
		return "indexed"
	end
	if $v equ 4 then
		return "gray+alpha"
	end
	if $v equ 6 then
		return "RGBA"
	end
	return ff_dec($v)
end

def ff_jpg_is_sof -> m then
	if $m eqg 192 and $m eql 207 and $m neq 196 and $m neq 200 and $m neq 204 then
		return true
	end
	return false
end

def ff_jpg_name -> m then
	if ff_jpg_is_sof($m) then
		return "SOF" + ff_dec($m - 192)
	end
	if $m eqg 224 and $m eql 239 then
		return "APP" + ff_dec($m - 224)
	end
	if $m equ 219 then
		return "DQT"
	end
	if $m equ 196 then
		return "DHT"
	end
	if $m equ 218 then
		return "SOS"
	end
	if $m equ 221 then
		return "DRI"
	end
	if $m equ 254 then
		return "COM"
	end
	return "marker 0x" + ff_hex($m)
end

def ff_detect_elf64 -> bytes, size then
	if $size < 64 then
		return false
	end
	if ff_u($bytes, 0, 4) equ 1179403647 and ff_u($bytes, 4, 1) equ 2 then
		return true
	end
	return false
end

def ff_detect_pe64 -> bytes, size then
	if $size < 64 then
		return false
	end
	if ff_u($bytes, 0, 2) neq 23117 then
		return false
	end
	var pe = ff_u($bytes, 60, 4)
	if $pe < 64 or $pe + 26 > $size then
		return false
	end
	if ff_u($bytes, $pe, 4) neq 17744 then
		return false
	end
	if ff_u($bytes, $pe + 24, 2) neq 523 then
		return false
	end
	return true
end

def ff_detect_png -> bytes, size then
	if $size < 8 then
		return false
	end
	if ff_u($bytes, 0, 1) neq 137 or ff_u($bytes, 1, 1) neq 80 or ff_u($bytes, 2, 1) neq 78 or ff_u($bytes, 3, 1) neq 71 then
		return false
	end
	if ff_u($bytes, 4, 1) neq 13 or ff_u($bytes, 5, 1) neq 10 or ff_u($bytes, 6, 1) neq 26 or ff_u($bytes, 7, 1) neq 10 then
		return false
	end
	return true
end

def ff_detect_jpg -> bytes, size then
	if $size < 4 then
		return false
	end
	if ff_u($bytes, 0, 1) equ 255 and ff_u($bytes, 1, 1) equ 216 and ff_u($bytes, 2, 1) equ 255 then
		return true
	end
	return false
end

def ff_detect -> bytes, size then
	if ff_detect_elf64($bytes, $size) then
		return "elf64"
	end
	if ff_detect_pe64($bytes, $size) then
		return "pe64"
	end
	if ff_detect_png($bytes, $size) then
		return "png"
	end
	if ff_detect_jpg($bytes, $size) then
		return "jpg"
	end
	return "raw"
end

def ff_parse_elf64 -> bytes, size then
	ff_field_add(0, 4, "ELF magic")
	ff_field_add(4, 1, "class=64-bit")
	var endian = ff_u($bytes, 5, 1)
	var ename = "little endian"
	if $endian equ 2 then
		$ename = "big endian"
	end
	ff_field_add(5, 1, "data=" + $ename)
	ff_field_add(6, 1, "version=" + ff_dec(ff_u($bytes, 6, 1)))
	ff_field_add(7, 1, "osabi=0x" + ff_hex(ff_u($bytes, 7, 1)))
	ff_field_add(8, 1, "abiversion=" + ff_dec(ff_u($bytes, 8, 1)))
	ff_field_add(9, 7, "padding")
	ff_mark_add(0, "start_of_format_elf64")
	if $endian neq 1 then
		return 0
	end
	var machine = ff_u($bytes, 18, 2)
	var entry = ff_u($bytes, 24, 8)
	var phoff = ff_u($bytes, 32, 8)
	var shoff = ff_u($bytes, 40, 8)
	var phent = ff_u($bytes, 54, 2)
	var phnum = ff_u($bytes, 56, 2)
	var shent = ff_u($bytes, 58, 2)
	var shnum = ff_u($bytes, 60, 2)
	var shstr = ff_u($bytes, 62, 2)
	if $machine equ 62 then
		$ff_arch = "x86"
	end
	$ff_c = 16
	ff_seq_text("e_type", 2, ff_elf_type(ff_u($bytes, 16, 2)))
	ff_seq_text("e_machine", 2, ff_elf_machine($machine))
	ff_seq($bytes, "e_version", 4)
	ff_seq($bytes, "e_entry", 8)
	ff_seq($bytes, "e_phoff", 8)
	ff_seq($bytes, "e_shoff", 8)
	ff_seq($bytes, "e_flags", 4)
	ff_seq($bytes, "e_ehsize", 2)
	ff_seq($bytes, "e_phentsize", 2)
	ff_seq($bytes, "e_phnum", 2)
	ff_seq($bytes, "e_shentsize", 2)
	ff_seq($bytes, "e_shnum", 2)
	ff_seq($bytes, "e_shstrndx", 2)

	var hend = 64
	if $phoff equ 64 and $phnum > 0 then
		$hend = 64 + ($phnum * $phent)
	end
	ff_mark_add($hend, "end_of_format_elf64")

	var code_off = 0 - 1
	var i = 0
	while $i < $phnum and $i < 128 then
		var p = $phoff + ($i * $phent)
		if $phent < 56 or $p + 56 > $size then
			break
		end
		var ptype = ff_u($bytes, $p, 4)
		var pflags = ff_u($bytes, $p + 4, 4)
		var poff = ff_u($bytes, $p + 8, 8)
		var pvaddr = ff_u($bytes, $p + 16, 8)
		var pfilesz = ff_u($bytes, $p + 32, 8)
		ff_field_add($p, $phent, "phdr[" + ff_dec($i) + "] " + ff_elf_ptype($ptype) + " off=0x" + ff_hex($poff) + " vaddr=0x" + ff_hex($pvaddr) + " size=0x" + ff_hex($pfilesz))
		if $ptype equ 1 and $entry eqg $pvaddr and $entry < $pvaddr + $pfilesz then
			$code_off = $poff + ($entry - $pvaddr)
		end
		if $shnum equ 0 and $ptype equ 1 and ($pflags % 2) equ 1 and string.len($ff_arch) > 0 then
			ff_area_add($poff, $poff + $pfilesz, "code", "segment")
		end
		$i = $i + 1
	end

	if $shnum > 0 and $shent eqg 64 and $shoff + 64 eql $size then
		var strtab = 0
		if $shstr < $shnum then
			$strtab = ff_u($bytes, $shoff + ($shstr * $shent) + 24, 8)
		end
		var j = 0
		while $j < $shnum and $j < 256 then
			var s = $shoff + ($j * $shent)
			if $s + 64 > $size then
				break
			end
			var label = ff_cstr($bytes, $strtab + ff_u($bytes, $s, 4), 32)
			if string.len($label) equ 0 then
				$label = "null"
			end
			var stype = ff_u($bytes, $s + 4, 4)
			var sflags = ff_u($bytes, $s + 8, 8)
			var soff = ff_u($bytes, $s + 24, 8)
			var ssize = ff_u($bytes, $s + 32, 8)
			ff_field_add($s, $shent, "shdr[" + ff_dec($j) + "] " + $label + " off=0x" + ff_hex($soff) + " size=0x" + ff_hex($ssize))
			if $stype neq 0 and $stype neq 8 and $ssize > 0 then
				var kind = "data"
				if (($sflags / 4) % 2) equ 1 and $stype equ 1 and string.len($ff_arch) > 0 then
					$kind = "code"
				end
				ff_area_add($soff, $soff + $ssize, $kind, $label)
			end
			$j = $j + 1
		end
	end

	if $code_off < 0 then
		$code_off = ff_first_code_start()
		$entry = $code_off
	end
	if $code_off eqg 0 and $code_off < $size then
		$ff_code_start = $code_off
		ff_mark_add($code_off, "code_start: 0x" + ff_hex($entry))
	end
	return 0
end

def ff_parse_pe64 -> bytes, size then
	var pe = ff_u($bytes, 60, 4)
	ff_field_add(0, 2, "MZ")
	ff_field_add(2, 58, "dos header")
	ff_field_add(60, 4, "e_lfanew=0x" + ff_hex($pe))
	ff_mark_add(0, "start_of_format_pe64")
	if $pe > 64 then
		ff_area_add(64, $pe, "data", "dos stub")
	end
	ff_field_add($pe, 4, "PE signature")
	var co = $pe + 4
	var machine = ff_u($bytes, $co, 2)
	var nsec = ff_u($bytes, $co + 2, 2)
	var optsz = ff_u($bytes, $co + 16, 2)
	if $machine equ 34404 then
		$ff_arch = "x86"
	end
	$ff_c = $co
	ff_seq_text("Machine", 2, ff_pe_machine($machine))
	ff_seq($bytes, "NumberOfSections", 2)
	ff_seq($bytes, "TimeDateStamp", 4)
	ff_seq($bytes, "PointerToSymbolTable", 4)
	ff_seq($bytes, "NumberOfSymbols", 4)
	ff_seq($bytes, "SizeOfOptionalHeader", 2)
	ff_seq($bytes, "Characteristics", 2)

	var oh = $co + 20
	var entry_rva = ff_u($bytes, $oh + 16, 4)
	var image_base = ff_u($bytes, $oh + 24, 8)
	var hend = ff_u($bytes, $oh + 60, 4)
	var nrva = ff_u($bytes, $oh + 108, 4)
	$ff_c = $oh
	ff_seq_text("Magic", 2, "PE32+")
	ff_seq($bytes, "MajorLinkerVersion", 1)
	ff_seq($bytes, "MinorLinkerVersion", 1)
	ff_seq($bytes, "SizeOfCode", 4)
	ff_seq($bytes, "SizeOfInitializedData", 4)
	ff_seq($bytes, "SizeOfUninitializedData", 4)
	ff_seq($bytes, "AddressOfEntryPoint", 4)
	ff_seq($bytes, "BaseOfCode", 4)
	ff_seq($bytes, "ImageBase", 8)
	ff_seq($bytes, "SectionAlignment", 4)
	ff_seq($bytes, "FileAlignment", 4)
	ff_seq($bytes, "MajorOSVersion", 2)
	ff_seq($bytes, "MinorOSVersion", 2)
	ff_seq($bytes, "MajorImageVersion", 2)
	ff_seq($bytes, "MinorImageVersion", 2)
	ff_seq($bytes, "MajorSubsystemVersion", 2)
	ff_seq($bytes, "MinorSubsystemVersion", 2)
	ff_seq($bytes, "Win32VersionValue", 4)
	ff_seq($bytes, "SizeOfImage", 4)
	ff_seq($bytes, "SizeOfHeaders", 4)
	ff_seq($bytes, "CheckSum", 4)
	ff_seq($bytes, "Subsystem", 2)
	ff_seq($bytes, "DllCharacteristics", 2)
	ff_seq($bytes, "SizeOfStackReserve", 8)
	ff_seq($bytes, "SizeOfStackCommit", 8)
	ff_seq($bytes, "SizeOfHeapReserve", 8)
	ff_seq($bytes, "SizeOfHeapCommit", 8)
	ff_seq($bytes, "LoaderFlags", 4)
	ff_seq($bytes, "NumberOfRvaAndSizes", 4)

	var d = 0
	while $d < $nrva and $d < 16 then
		var dp = $oh + 112 + ($d * 8)
		ff_field_add($dp, 8, "dir[" + List.get($FF_PE_DIRS, $d) + "] rva=0x" + ff_hex(ff_u($bytes, $dp, 4)) + " size=0x" + ff_hex(ff_u($bytes, $dp + 4, 4)))
		$d = $d + 1
	end

	ff_mark_add($hend, "end_of_format_pe64")

	var code_off = 0 - 1
	var st = $oh + $optsz
	var i = 0
	while $i < $nsec and $i < 96 then
		var s = $st + ($i * 40)
		if $s + 40 > $size then
			break
		end
		var label = ff_cstr($bytes, $s, 8)
		var va = ff_u($bytes, $s + 12, 4)
		var rawsz = ff_u($bytes, $s + 16, 4)
		var rawptr = ff_u($bytes, $s + 20, 4)
		var chars = ff_u($bytes, $s + 36, 4)
		ff_field_add($s, 40, "sec[" + ff_dec($i) + "] " + $label + " va=0x" + ff_hex($va) + " raw=0x" + ff_hex($rawptr) + " size=0x" + ff_hex($rawsz))
		if $rawsz > 0 then
			var kind = "data"
			var is_code = false
			if (($chars / 32) % 2) equ 1 then
				$is_code = true
			end
			if (($chars / 536870912) % 2) equ 1 then
				$is_code = true
			end
			if $is_code and string.len($ff_arch) > 0 then
				$kind = "code"
			end
			ff_area_add($rawptr, $rawptr + $rawsz, $kind, $label)
		end
		if $entry_rva eqg $va and $entry_rva < $va + $rawsz then
			$code_off = $rawptr + ($entry_rva - $va)
		end
		$i = $i + 1
	end

	var shown = $image_base + $entry_rva
	if $code_off < 0 then
		$code_off = ff_first_code_start()
	end
	if $code_off eqg 0 and $code_off < $size then
		$ff_code_start = $code_off
		ff_mark_add($code_off, "code_start: 0x" + ff_hex($shown))
	end
	return 0
end

def ff_parse_png -> bytes, size then
	ff_field_add(0, 8, "PNG signature")
	ff_mark_add(0, "start_of_format_png")
	var p = 8
	var n = 0
	while $p + 12 eql $size and $n < 400 then
		var clen = ff_ub($bytes, $p, 4)
		var ctype = ff_str($bytes, $p + 4, 4)
		ff_field_add($p, 8, "chunk[" + ff_dec($n) + "] " + $ctype + " len=" + ff_dec($clen))
		var d = $p + 8
		if $ctype equ "IHDR" and $clen eqg 13 then
			ff_field_add($d, 4, "width=" + ff_dec(ff_ub($bytes, $d, 4)))
			ff_field_add($d + 4, 4, "height=" + ff_dec(ff_ub($bytes, $d + 4, 4)))
			ff_field_add($d + 8, 1, "bit_depth=" + ff_dec(ff_u($bytes, $d + 8, 1)))
			ff_field_add($d + 9, 1, "color_type=" + ff_png_color(ff_u($bytes, $d + 9, 1)))
			ff_field_add($d + 10, 1, "compression=" + ff_dec(ff_u($bytes, $d + 10, 1)))
			ff_field_add($d + 11, 1, "filter=" + ff_dec(ff_u($bytes, $d + 11, 1)))
			ff_field_add($d + 12, 1, "interlace=" + ff_dec(ff_u($bytes, $d + 12, 1)))
		elif $clen > 0 then
			ff_area_add($d, $d + $clen, "data", $ctype + " data")
		end
		ff_field_add($d + $clen, 4, "crc")
		$p = $d + $clen + 4
		$n = $n + 1
		if $ctype equ "IEND" then
			break
		end
	end
	return 0
end

def ff_parse_jpg -> bytes, size then
	ff_field_add(0, 2, "SOI start of image")
	ff_mark_add(0, "start_of_format_jpg")
	var p = 2
	var n = 0
	while $p + 2 eql $size and $n < 400 then
		if ff_u($bytes, $p, 1) neq 255 then
			ff_area_add($p, $size, "data", "unknown data")
			break
		end
		var m = ff_u($bytes, $p + 1, 1)
		$n = $n + 1
		if $m equ 255 then
			$p = $p + 1
		elif $m equ 217 then
			ff_field_add($p, 2, "EOI end of image")
			break
		elif $m equ 1 or $m equ 216 or ($m eqg 208 and $m eql 215) then
			ff_field_add($p, 2, ff_jpg_name($m))
			$p = $p + 2
		elif $p + 4 > $size then
			ff_area_add($p, $size, "data", "truncated")
			break
		else
			var slen = ff_ub($bytes, $p + 2, 2)
			var name = ff_jpg_name($m)
			var seg_end = $p + 2 + $slen
			if ff_jpg_is_sof($m) and $slen eqg 8 then
				ff_field_add($p, 4, $name + " len=" + ff_dec($slen))
				ff_field_add($p + 4, 1, "precision=" + ff_dec(ff_u($bytes, $p + 4, 1)) + "bit")
				ff_field_add($p + 5, 2, "height=" + ff_dec(ff_ub($bytes, $p + 5, 2)))
				ff_field_add($p + 7, 2, "width=" + ff_dec(ff_ub($bytes, $p + 7, 2)))
				ff_field_add($p + 9, 1, "components=" + ff_dec(ff_u($bytes, $p + 9, 1)))
				ff_area_add($p + 10, $seg_end, "data", "component specs")
			else
				ff_field_add($p, 4, $name + " len=" + ff_dec($slen))
				var label = $name + " data"
				if $m eqg 224 and $m eql 239 then
					$label = $name + ": " + ff_cstr($bytes, $p + 4, 8)
				end
				ff_area_add($p + 4, $seg_end, "data", $label)
			end
			$p = $seg_end
			if $m equ 218 then
				var q = $p
				var limit = $p + 200000
				var scanning = true
				while $scanning and $q + 1 < $size and $q < $limit then
					if hexdit_get($bytes, $q) equ 255 then
						var nx = hexdit_get($bytes, $q + 1)
						if $nx neq 0 and ($nx < 208 or $nx > 215) then
							$scanning = false
						end
					end
					if $scanning then
						$q = $q + 1
					end
				end
				if $scanning and $p < $size then
					$q = $size
					if $size - 2 > $p and ff_u($bytes, $size - 2, 1) equ 255 and ff_u($bytes, $size - 1, 1) equ 217 then
						$q = $size - 2
					end
				end
				ff_area_add($p, $q, "data", "scan data")
				$p = $q
			end
		end
	end
	return 0
end

def ff_parse -> bytes, size, name then
	if $name equ "elf64" then
		ff_parse_elf64($bytes, $size)
	elif $name equ "pe64" then
		ff_parse_pe64($bytes, $size)
	elif $name equ "png" then
		ff_parse_png($bytes, $size)
	elif $name equ "jpg" then
		ff_parse_jpg($bytes, $size)
	end
end

def ff_load -> bytes, size then
	ff_reset()
	$ff_size = $size
	$ff_arch = ""
	$ff_name = ff_detect($bytes, $size)
	if $ff_name equ "raw" then
		$ff_arch = "x86"
	end
	ff_parse($bytes, $size, $ff_name)
end

def ff_after_edit -> bytes, size, pos then
	var reload = false
	if $pos < 64 then
		$reload = true
	end
	if $reload equ false then
		if ff_in_field($pos) then
			$reload = true
		end
	end
	if $reload then
		ff_load($bytes, $size)
		return true
	end
	return false
end

def ff_marks_at -> pos then
	var s = ""
	var i = ff_find($ff_m_pos, $pos)
	while $i eqg 0 then
		if List.get($ff_m_pos, $i) equ $pos then
			$s = List.get($ff_m_texts, $i) + "; " + $s
			$i = $i - 1
		else
			break
		end
	end
	return $s
end

def ff_next_boundary -> pos, size then
	var nb = $size
	var fi = ff_find($ff_f_starts, $pos) + 1
	if $fi < List.len($ff_f_starts) then
		var fv = List.get($ff_f_starts, $fi)
		if $fv < $nb then
			$nb = $fv
		end
	end
	var ai = ff_find($ff_a_starts, $pos) + 1
	if $ai < List.len($ff_a_starts) then
		var av = List.get($ff_a_starts, $ai)
		if $av < $nb then
			$nb = $av
		end
	end
	var mi = ff_find($ff_m_pos, $pos) + 1
	if $mi < List.len($ff_m_pos) then
		var mv = List.get($ff_m_pos, $mi)
		if $mv < $nb then
			$nb = $mv
		end
	end
	return $nb
end

def ff_row_len -> pos, limit then
	var len = $limit - $pos
	var room = 8 - ($pos % 8)
	if $room < $len then
		$len = $room
	end
	return $len
end

def ff_region_unit -> bytes, pos, size then
	$dis_target = 0 - 1
	var nb = ff_next_boundary($pos, $size)
	var fi = ff_find($ff_f_starts, $pos)
	if $fi eqg 0 then
		var fe = List.get($ff_f_ends, $fi)
		if $pos < $fe then
			if $nb < $fe then
				$fe = $nb
			end
			$dis_len = $fe - $pos
			$dis_oplen = $dis_len
			if $pos > List.get($ff_f_starts, $fi) then
				return "..."
			end
			return List.get($ff_f_texts, $fi)
		end
	end
	var limit = $nb
	var ai = ff_find($ff_a_starts, $pos)
	if $ai eqg 0 then
		var ae = List.get($ff_a_ends, $ai)
		if $pos < $ae then
			if $ae < $limit then
				$limit = $ae
			end
			if List.get($ff_a_kinds, $ai) equ "code" then
				return hexdit_disassemble_one($bytes, $pos, $limit, $ff_arch)
			end
			$dis_len = ff_row_len($pos, $limit)
			$dis_oplen = $dis_len
			if $pos equ List.get($ff_a_starts, $ai) then
				return List.get($ff_a_labels, $ai) + " (" + ff_dec($ae - $pos) + " bytes)"
			end
			return "..."
		end
	end
	$dis_len = ff_row_len($pos, $limit)
	$dis_oplen = $dis_len
	return "data"
end

def ff_unit_one -> bytes, pos, size then
	var prefix = ff_marks_at($pos)
	var text = ""
	if $ff_name equ "raw" then
		$text = hexdit_disassemble_one($bytes, $pos, $size, $ff_arch)
	else
		$text = ff_region_unit($bytes, $pos, $size)
	end
	return $prefix + $text
end
