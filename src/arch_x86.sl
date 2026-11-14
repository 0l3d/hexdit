import hexdit_core.sl
use("list", "types", "string")

var X86_UNKNOWN = "xx"

var X86_R64 = List.new()
List.push($X86_R64, "rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15")
var X86_R32 = List.new()
List.push($X86_R32, "eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi", "r8d", "r9d", "r10d", "r11d", "r12d", "r13d", "r14d", "r15d")
var X86_R16 = List.new()
List.push($X86_R16, "ax", "cx", "dx", "bx", "sp", "bp", "si", "di", "r8w", "r9w", "r10w", "r11w", "r12w", "r13w", "r14w", "r15w")
var X86_R8X = List.new()
List.push($X86_R8X, "al", "cl", "dl", "bl", "spl", "bpl", "sil", "dil", "r8b", "r9b", "r10b", "r11b", "r12b", "r13b", "r14b", "r15b")
var X86_R8L = List.new()
List.push($X86_R8L, "al", "cl", "dl", "bl", "ah", "ch", "dh", "bh")
var X86_CC = List.new()
List.push($X86_CC, "o", "no", "b", "ae", "e", "ne", "be", "a", "s", "ns", "p", "np", "l", "ge", "le", "g")
var X86_ALU = List.new()
List.push($X86_ALU, "add", "or", "adc", "sbb", "and", "sub", "xor", "cmp")
var X86_SHIFT = List.new()
List.push($X86_SHIFT, "rol", "ror", "rcl", "rcr", "shl", "shr", "shl", "sar")
var X86_GRP3 = List.new()
List.push($X86_GRP3, "test", "test", "not", "neg", "mul", "imul", "div", "idiv")
var X86_STR = List.new()
List.push($X86_STR, "movs", "cmps", "", "stos", "lods", "scas")

var x86_p = 0
var x86_start = 0
var x86_overrun = false
var x86_jump = 0 - 1
var x86_len = 1
var x86_oplen = 1
var x86_oplen_set = false
var x86_pfx66 = false
var x86_rep = 0
var x86_has_rex = false
var x86_rex_w = 0
var x86_rex_r = 0
var x86_rex_x = 0
var x86_rex_b = 0
var x86_mod_reg = 0
var x86_rm_text = ""


def x86_u8 -> bytes, size then
	if $x86_p eqg $size then
		$x86_overrun = true
		$x86_p = $x86_p + 1
		return 0
	end
	var v = hexdit_get($bytes, $x86_p)
	$x86_p = $x86_p + 1
	return $v
end

def x86_mark then
	if $x86_oplen_set equ false then
		$x86_oplen = $x86_p - $x86_start
		$x86_oplen_set = true
	end
end

def x86_imm -> bytes, size, n then
	x86_mark()
	var v = 0
	var mul = 1
	var i = 0
	while $i < $n then
		$v = $v + x86_u8($bytes, $size) * $mul
		$mul = $mul * 256
		$i = $i + 1
	end
	return $v
end

def x86_signed -> v, n then
	var limit = 128
	if $n equ 2 then
		$limit = 32768
	end
	if $n equ 4 then
		$limit = 2147483648
	end
	if $v eqg $limit then
		return $v - ($limit * 2)
	end
	return $v
end

def x86_hex -> n then
	if $n equ 0 then
		return "0"
	end
	return hexdit_convert_number_to_hexadecimal($n)
end

def x86_num -> v then
	if $v < 0 then
		return "-0x" + x86_hex(0 - $v)
	end
	return "0x" + x86_hex($v)
end

def x86_imm64_text -> lo, hi then
	if $hi equ 0 then
		return x86_num($lo)
	end
	var low = x86_hex($lo)
	while string.len($low) < 8 then
		$low = "0" + $low
	end
	return "0x" + x86_hex($hi) + $low
end

def x86_reg -> n, size then
	if $size equ 64 then
		return List.get($X86_R64, $n)
	end
	if $size equ 32 then
		return List.get($X86_R32, $n)
	end
	if $size equ 16 then
		return List.get($X86_R16, $n)
	end
	if $x86_has_rex then
		return List.get($X86_R8X, $n)
	end
	return List.get($X86_R8L, $n)
end

def x86_osize then
	if $x86_rex_w equ 1 then
		return 64
	end
	if $x86_pfx66 then
		return 16
	end
	return 32
end

def x86_ptr -> size then
	if $size equ 8 then
		return "byte "
	end
	if $size equ 16 then
		return "word "
	end
	if $size equ 32 then
		return "dword "
	end
	return "qword "
end

def x86_peek_reg -> bytes, size then
	if $x86_p eqg $size then
		return 0
	end
	return (hexdit_get($bytes, $x86_p) / 8) % 8
end

def x86_target -> rel then
	$x86_jump = $x86_p + $rel
	return x86_num($x86_p + $rel)
end

def x86_modrm -> bytes, size, rmsize, showptr then
	x86_mark()
	var m = x86_u8($bytes, $size)
	var md = $m / 64
	var regf = ($m / 8) % 8
	var rmf = $m % 8
	$x86_mod_reg = $regf + ($x86_rex_r * 8)

	if $md equ 3 then
		$x86_rm_text = x86_reg($rmf + ($x86_rex_b * 8), $rmsize)
		return 0
	end

	var base = ""
	var index = ""
	var scale = 1
	var disp_size = 0
	var rip = false

	if $rmf equ 4 then
		var sib = x86_u8($bytes, $size)
		var ss = $sib / 64
		var idx = (($sib / 8) % 8) + ($x86_rex_x * 8)
		var bs = $sib % 8
		var k = 0
		while $k < $ss then
			$scale = $scale * 2
			$k = $k + 1
		end
		if $idx neq 4 then
			$index = x86_reg($idx, 64)
		end
		if $bs equ 5 and $md equ 0 then
			$disp_size = 4
		else
			$base = x86_reg($bs + ($x86_rex_b * 8), 64)
		end
	elif $rmf equ 5 and $md equ 0 then
		$rip = true
		$disp_size = 4
	else
		$base = x86_reg($rmf + ($x86_rex_b * 8), 64)
	end

	if $md equ 1 then
		$disp_size = 1
	end
	if $md equ 2 then
		$disp_size = 4
	end

	var inner = $base
	if $rip then
		$inner = "rip"
	end
	if string.len($index) > 0 then
		if string.len($inner) > 0 then
			$inner = $inner + "+"
		end
		$inner = $inner + $index
		if $scale > 1 then
			$inner = $inner + "*" + types.int_to_str($scale)
		end
	end

	if $disp_size > 0 then
		var disp = x86_signed(x86_imm($bytes, $size, $disp_size), $disp_size)
		if string.len($inner) > 0 then
			if $disp < 0 then
				$inner = $inner + "-0x" + x86_hex(0 - $disp)
			else
				$inner = $inner + "+0x" + x86_hex($disp)
			end
		else
			$inner = x86_num($disp)
		end
	end

	var pfx = ""
	if $showptr equ 1 then
		$pfx = x86_ptr($rmsize)
	end
	$x86_rm_text = $pfx + "[" + $inner + "]"
	return 0
end

def x86_rm_reg -> bytes, size, name, sz, dir then
	x86_modrm($bytes, $size, $sz, 0)
	var r = x86_reg($x86_mod_reg, $sz)
	if $dir equ 0 then
		return $name + " " + $x86_rm_text + ", " + $r
	end
	return $name + " " + $r + ", " + $x86_rm_text
end

def x86_imm_tail -> bytes, size, name, immn, sx then
	var rmt = $x86_rm_text
	var v = x86_imm($bytes, $size, $immn)
	if $sx equ 1 then
		$v = x86_signed($v, $immn)
	end
	return $name + " " + $rmt + ", " + x86_num($v)
end

def x86_acc_imm -> bytes, size, name then
	var sz = x86_osize()
	var n = 4
	if $sz equ 16 then
		$n = 2
	end
	var v = x86_imm($bytes, $size, $n)
	if $sz equ 64 then
		$v = x86_signed($v, 4)
	end
	return $name + " " + x86_reg(0, $sz) + ", " + x86_num($v)
end

def x86_decode_0f -> bytes, size then
	var b2 = x86_u8($bytes, $size)
	var sz = x86_osize()

	if $b2 equ 5 then
		return "syscall"
	end
	if $b2 equ 11 then
		return "ud2"
	end
	if $b2 equ 49 then
		return "rdtsc"
	end
	if $b2 equ 162 then
		return "cpuid"
	end
	if $b2 equ 30 and $x86_rep equ 243 then
		var b3 = x86_u8($bytes, $size)
		if $b3 equ 250 then
			return "endbr64"
		end
		if $b3 equ 251 then
			return "endbr32"
		end
		return ""
	end
	if $b2 equ 31 then
		x86_modrm($bytes, $size, $sz, 1)
		return "nop " + $x86_rm_text
	end
	if $b2 eqg 64 and $b2 eql 79 then
		return x86_rm_reg($bytes, $size, "cmov" + List.get($X86_CC, $b2 - 64), $sz, 1)
	end
	if $b2 eqg 128 and $b2 eql 143 then
		var rel = x86_signed(x86_imm($bytes, $size, 4), 4)
		return "j" + List.get($X86_CC, $b2 - 128) + " " + x86_target($rel)
	end
	if $b2 eqg 144 and $b2 eql 159 then
		x86_modrm($bytes, $size, 8, 1)
		return "set" + List.get($X86_CC, $b2 - 144) + " " + $x86_rm_text
	end
	if $b2 equ 175 then
		return x86_rm_reg($bytes, $size, "imul", $sz, 1)
	end
	if $b2 equ 182 or $b2 equ 183 or $b2 equ 190 or $b2 equ 191 then
		var srcsz = 8
		if $b2 equ 183 or $b2 equ 191 then
			$srcsz = 16
		end
		var nm = "movzx"
		if $b2 eqg 190 then
			$nm = "movsx"
		end
		x86_modrm($bytes, $size, $srcsz, 1)
		return $nm + " " + x86_reg($x86_mod_reg, $sz) + ", " + $x86_rm_text
	end
	if $b2 eqg 200 and $b2 eql 207 then
		var bsz = 32
		if $x86_rex_w equ 1 then
			$bsz = 64
		end
		return "bswap " + x86_reg(($b2 - 200) + ($x86_rex_b * 8), $bsz)
	end
	return ""
end

def x86_decode -> bytes, size then
	var b = x86_u8($bytes, $size)

	var going = true
	var count = 0
	while $going then
		if $b equ 102 then
			$x86_pfx66 = true
		elif $b equ 243 or $b equ 242 then
			$x86_rep = $b
		elif $b equ 46 or $b equ 62 or $b equ 38 or $b equ 54 or $b equ 100 or $b equ 101 then
			$count = $count + 0
		else
			$going = false
		end
		$count = $count + 1
		if $count > 14 then
			$going = false
		end
		if $going then
			$b = x86_u8($bytes, $size)
		end
	end

	if $b eqg 64 and $b eql 79 then
		var rx = $b - 64
		$x86_has_rex = true
		$x86_rex_w = ($rx / 8) % 2
		$x86_rex_r = ($rx / 4) % 2
		$x86_rex_x = ($rx / 2) % 2
		$x86_rex_b = $rx % 2
		$b = x86_u8($bytes, $size)
	end

	var osz = x86_osize()

	if $b < 64 and ($b % 8) < 6 then
		var alu = List.get($X86_ALU, $b / 8)
		var f = $b % 8
		if $f equ 0 then
			return x86_rm_reg($bytes, $size, $alu, 8, 0)
		end
		if $f equ 1 then
			return x86_rm_reg($bytes, $size, $alu, $osz, 0)
		end
		if $f equ 2 then
			return x86_rm_reg($bytes, $size, $alu, 8, 1)
		end
		if $f equ 3 then
			return x86_rm_reg($bytes, $size, $alu, $osz, 1)
		end
		if $f equ 4 then
			return $alu + " al, " + x86_num(x86_imm($bytes, $size, 1))
		end
		return x86_acc_imm($bytes, $size, $alu)
	end

	if $b equ 15 then
		return x86_decode_0f($bytes, $size)
	end

	if $b eqg 80 and $b eql 87 then
		return "push " + x86_reg(($b - 80) + ($x86_rex_b * 8), 64)
	end
	if $b eqg 88 and $b eql 95 then
		return "pop " + x86_reg(($b - 88) + ($x86_rex_b * 8), 64)
	end

	if $b equ 99 then
		x86_modrm($bytes, $size, 32, 0)
		return "movsxd " + x86_reg($x86_mod_reg, $osz) + ", " + $x86_rm_text
	end

	if $b equ 104 then
		return "push " + x86_num(x86_signed(x86_imm($bytes, $size, 4), 4))
	end
	if $b equ 106 then
		return "push " + x86_num(x86_signed(x86_imm($bytes, $size, 1), 1))
	end

	if $b equ 105 or $b equ 107 then
		var imn = 4
		if $b equ 107 then
			$imn = 1
		elif $osz equ 16 then
			$imn = 2
		end
		x86_modrm($bytes, $size, $osz, 0)
		var idst = x86_reg($x86_mod_reg, $osz)
		var isrc = $x86_rm_text
		var iv = x86_signed(x86_imm($bytes, $size, $imn), $imn)
		return "imul " + $idst + ", " + $isrc + ", " + x86_num($iv)
	end

	if $b eqg 112 and $b eql 127 then
		var rel8 = x86_signed(x86_imm($bytes, $size, 1), 1)
		return "j" + List.get($X86_CC, $b - 112) + " " + x86_target($rel8)
	end

	if $b equ 128 or $b equ 129 or $b equ 131 then
		var gsz = $osz
		var gn = 1
		var gsx = 1
		if $b equ 128 then
			$gsz = 8
			$gsx = 0
		elif $b equ 129 then
			$gn = 4
			$gsx = 0
			if $osz equ 16 then
				$gn = 2
			end
			if $osz equ 64 then
				$gsx = 1
			end
		end
		x86_modrm($bytes, $size, $gsz, 1)
		var gname = List.get($X86_ALU, $x86_mod_reg % 8)
		return x86_imm_tail($bytes, $size, $gname, $gn, $gsx)
	end

	if $b equ 132 then
		return x86_rm_reg($bytes, $size, "test", 8, 0)
	end
	if $b equ 133 then
		return x86_rm_reg($bytes, $size, "test", $osz, 0)
	end
	if $b equ 134 then
		return x86_rm_reg($bytes, $size, "xchg", 8, 0)
	end
	if $b equ 135 then
		return x86_rm_reg($bytes, $size, "xchg", $osz, 0)
	end
	if $b equ 136 then
		return x86_rm_reg($bytes, $size, "mov", 8, 0)
	end
	if $b equ 137 then
		return x86_rm_reg($bytes, $size, "mov", $osz, 0)
	end
	if $b equ 138 then
		return x86_rm_reg($bytes, $size, "mov", 8, 1)
	end
	if $b equ 139 then
		return x86_rm_reg($bytes, $size, "mov", $osz, 1)
	end
	if $b equ 141 then
		x86_modrm($bytes, $size, 64, 0)
		return "lea " + x86_reg($x86_mod_reg, $osz) + ", " + $x86_rm_text
	end

	if $b equ 144 then
		if $x86_rep equ 243 then
			return "pause"
		end
		return "nop"
	end
	if $b eqg 145 and $b eql 151 then
		return "xchg " + x86_reg(($b - 144) + ($x86_rex_b * 8), $osz) + ", " + x86_reg(0, $osz)
	end
	if $b equ 152 then
		if $osz equ 64 then
			return "cdqe"
		end
		if $osz equ 16 then
			return "cbw"
		end
		return "cwde"
	end
	if $b equ 153 then
		if $osz equ 64 then
			return "cqo"
		end
		if $osz equ 16 then
			return "cwd"
		end
		return "cdq"
	end
	if $b equ 156 then
		return "pushfq"
	end
	if $b equ 157 then
		return "popfq"
	end

	if $b equ 168 then
		return "test al, " + x86_num(x86_imm($bytes, $size, 1))
	end
	if $b equ 169 then
		return x86_acc_imm($bytes, $size, "test")
	end

	if $b eqg 164 and $b eql 175 then
		var sidx = ($b - 164) / 2
		var sname = List.get($X86_STR, $sidx)
		var sletter = "b"
		if ($b % 2) equ 1 then
			$sletter = "d"
			if $osz equ 64 then
				$sletter = "q"
			end
			if $osz equ 16 then
				$sletter = "w"
			end
		end
		var spfx = ""
		if $x86_rep equ 243 then
			$spfx = "rep "
			if $sidx equ 1 or $sidx equ 5 then
				$spfx = "repe "
			end
		end
		if $x86_rep equ 242 then
			$spfx = "repne "
		end
		return $spfx + $sname + $sletter
	end

	if $b eqg 176 and $b eql 183 then
		return "mov " + x86_reg(($b - 176) + ($x86_rex_b * 8), 8) + ", " + x86_num(x86_imm($bytes, $size, 1))
	end
	if $b eqg 184 and $b eql 191 then
		var mreg = x86_reg(($b - 184) + ($x86_rex_b * 8), $osz)
		if $osz equ 64 then
			var lo = x86_imm($bytes, $size, 4)
			var hi = x86_imm($bytes, $size, 4)
			return "mov " + $mreg + ", " + x86_imm64_text($lo, $hi)
		end
		var mn = 4
		if $osz equ 16 then
			$mn = 2
		end
		return "mov " + $mreg + ", " + x86_num(x86_imm($bytes, $size, $mn))
	end

	if $b equ 192 or $b equ 193 or ($b eqg 208 and $b eql 211) then
		var ssz = $osz
		if $b equ 192 or $b equ 208 or $b equ 210 then
			$ssz = 8
		end
		x86_modrm($bytes, $size, $ssz, 1)
		var shn = List.get($X86_SHIFT, $x86_mod_reg % 8)
		if $b equ 192 or $b equ 193 then
			return x86_imm_tail($bytes, $size, $shn, 1, 0)
		end
		if $b equ 208 or $b equ 209 then
			return $shn + " " + $x86_rm_text + ", 1"
		end
		return $shn + " " + $x86_rm_text + ", cl"
	end

	if $b equ 194 then
		return "ret " + x86_num(x86_imm($bytes, $size, 2))
	end
	if $b equ 195 then
		if $x86_rep equ 243 then
			return "rep ret"
		end
		return "ret"
	end
	if $b equ 201 then
		return "leave"
	end
	if $b equ 204 then
		return "int3"
	end
	if $b equ 205 then
		return "int " + x86_num(x86_imm($bytes, $size, 1))
	end

	if $b equ 198 then
		x86_modrm($bytes, $size, 8, 1)
		return x86_imm_tail($bytes, $size, "mov", 1, 0)
	end
	if $b equ 199 then
		var cn = 4
		var csx = 0
		if $osz equ 16 then
			$cn = 2
		end
		if $osz equ 64 then
			$csx = 1
		end
		x86_modrm($bytes, $size, $osz, 1)
		return x86_imm_tail($bytes, $size, "mov", $cn, $csx)
	end

	if $b equ 232 then
		var crel = x86_signed(x86_imm($bytes, $size, 4), 4)
		return "call " + x86_target($crel)
	end
	if $b equ 233 then
		var jrel = x86_signed(x86_imm($bytes, $size, 4), 4)
		return "jmp " + x86_target($jrel)
	end
	if $b equ 235 then
		var jrel8 = x86_signed(x86_imm($bytes, $size, 1), 1)
		return "jmp " + x86_target($jrel8)
	end

	if $b equ 244 then
		return "hlt"
	end
	if $b equ 245 then
		return "cmc"
	end
	if $b equ 248 then
		return "clc"
	end
	if $b equ 249 then
		return "stc"
	end
	if $b equ 250 then
		return "cli"
	end
	if $b equ 251 then
		return "sti"
	end
	if $b equ 252 then
		return "cld"
	end
	if $b equ 253 then
		return "std"
	end

	if $b equ 246 or $b equ 247 then
		var fsz = $osz
		if $b equ 246 then
			$fsz = 8
		end
		x86_modrm($bytes, $size, $fsz, 1)
		var fg = $x86_mod_reg % 8
		var fname = List.get($X86_GRP3, $fg)
		if $fg < 2 then
			var fn = 1
			var fsx = 0
			if $b equ 247 then
				$fn = 4
				if $osz equ 16 then
					$fn = 2
				end
				if $osz equ 64 then
					$fsx = 1
				end
			end
			return x86_imm_tail($bytes, $size, $fname, $fn, $fsx)
		end
		return $fname + " " + $x86_rm_text
	end

	if $b equ 254 or $b equ 255 then
		var hg = x86_peek_reg($bytes, $size)
		var hsz = $osz
		if $b equ 254 then
			$hsz = 8
		end
		if $b equ 255 and ($hg equ 2 or $hg equ 4 or $hg equ 6) then
			$hsz = 64
		end
		var hname = ""
		if $hg equ 0 then
			$hname = "inc"
		elif $hg equ 1 then
			$hname = "dec"
		elif $b equ 255 and $hg equ 2 then
			$hname = "call"
		elif $b equ 255 and $hg equ 4 then
			$hname = "jmp"
		elif $b equ 255 and $hg equ 6 then
			$hname = "push"
		end
		if string.len($hname) equ 0 then
			return ""
		end
		x86_modrm($bytes, $size, $hsz, 1)
		return $hname + " " + $x86_rm_text
	end

	return ""
end

def disassemble_x86_one -> bytes, pos, size then
	$x86_p = $pos
	$x86_start = $pos
	$x86_overrun = false
	$x86_oplen = 0
	$x86_oplen_set = false
	$x86_jump = 0 - 1
	$x86_pfx66 = false
	$x86_rep = 0
	$x86_has_rex = false
	$x86_rex_w = 0
	$x86_rex_r = 0
	$x86_rex_x = 0
	$x86_rex_b = 0
	var text = x86_decode($bytes, $size)
	x86_mark()
	$x86_len = $x86_p - $pos
	if $x86_overrun then
		$x86_len = 1
		$x86_oplen = 1
		$x86_jump = 0 - 1
		return $X86_UNKNOWN
	end
	if string.len($text) equ 0 then
		$x86_len = 1
		$x86_oplen = 1
		$x86_jump = 0 - 1
		return $X86_UNKNOWN
	end
	return $text
end

def disassemble_x86 -> bytes, start, size then
	var disassembled_output = ""
	var i = $start
	while $i < $size then
		var instruction_str = disassemble_x86_one($bytes, $i, $size)
		$disassembled_output = $disassembled_output + $instruction_str + "\n"
		$i = $i + $x86_len
	end
	return $disassembled_output
end

