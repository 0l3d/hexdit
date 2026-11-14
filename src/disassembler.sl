import arch_x86.sl

# Heart Shaped-Box
 ##   ##
####+####
#########
 #######
  #####
   ###
    #
# Heart Shaped-Box

var dis_len = 1
var dis_oplen = 1
var dis_target = 0 - 1

def hexdit_disassemble -> bytes, start, size, arch then 
	var limit = $size
	var real = byte.size($bytes)
	if $limit > $real then
		$limit = $real
	end
	if $arch equ "x86" then 
		return disassemble_x86($bytes, $start, $limit)
	end
	return ""
end

def hexdit_disassemble_one -> bytes, pos, size, arch then
	if $arch equ "x86" then
		var text = disassemble_x86_one($bytes, $pos, $size)
		$dis_len = $x86_len
		$dis_oplen = $x86_oplen
		$dis_target = $x86_jump
		return $text
	end
	$dis_len = 1
	$dis_oplen = 1
	$dis_target = 0 - 1
	return ""
end
