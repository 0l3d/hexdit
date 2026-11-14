use("file", "types", "bytes", "io", "errors", "string")

def hexdit_dbg -> msg then 
	io.print($msg)
	io.flush()
end

def hexdit_open_file -> file_path then 
	var bytes = file.read($file_path)
	errors.panic($bytes)
	return $bytes
end

def hexdit_get -> bytes, pos then 
	return hexdit_convert_number_signed_to_unsigned(byte.get($bytes, $pos))
end

def hexdit_convert_number_to_hexadecimal -> number then 
	var nums = ""
	var num = $number
	while $num > 0 then
		var rem = $num % 16
		if $rem > 9 then 
			$nums = types.char_to_str(
			types.int_to_char($rem + 55)
					) + $nums
		else 
        		$nums = types.int_to_str($rem) + $nums
		end
		$num = $num / 16
	end
	return $nums
end

def hexdit_convert_hexadecimal_to_number -> hex_string then 
	var first = string.char_at($hex_string, 0)
	var second = string.char_at($hex_string, 1)
	var number = 0
	
	if types.is_digit($first) then 
		$number = types.str_to_int($first) + $number
	else
		$number = (types.char_to_int($first) - 55) * 16 + $number
	end

	if types.is_digit($second) then 
		$number = types.str_to_int(types.char_to_str($second)) + $number
	else
		$number = (types.char_to_int($second) - 55) * 16 + $number
	end

	return $number
end

def hexdit_convert_number_signed_to_unsigned -> char then
	var signed_num = types.char_to_int($char)
	var mask = 255
	return $signed_num & $mask
end

def hexdit_print_hexadecimal_output -> bytes, size then 
	var i = -1 while ({ $i = $i + 1 return $i < $size }) then
		var byte = byte.get($bytes, $i)
		var num = hexdit_convert_number_signed_to_unsigned($byte)
		if $num eql 15 then io.print("0") end
		if $num equ 0 then io.print("0") end
		hexdit_convert_number_to_hexadecimal($num)
		|> io.print("|")
	end
end

def hexdit_edit_byte -> bytes, pos, num then
	return byte.set($bytes, $pos, types.int_to_char($num))
end







