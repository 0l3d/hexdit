import hexdit_core.sl
import disassembler.sl
import tui.sl

use("sys")

var file_path = sys.get_arg(2)
errors.panic($file_path)

var bytes = hexdit_open_file($file_path)
# var hex = hexdit_convert_number_to_hexadecimal(hexdit_convert_number_signed_to_unsigned(byte.get($bytes, 0)))
# var disassembly = hexdit_disassemble($bytes, 0, 5, "x86")
hexdit_init_tui($bytes, byte.size($bytes), $file_path)
# hexdit_print_hexadecimal_output($bytes, 8)




















