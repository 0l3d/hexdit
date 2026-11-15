# Simple tutorial for Hexdit
  
```c
#include <stdio.h>

int main() {
        const char* msg = "Hello, World!";
        int a = 0;
        if (a == 1) {
                printf("%s\n", msg);
        }
        return 0;
}
```
  
this is the c code we will be experimenting with.
  
first, let's compile this code using any compiler and then launch hexdit by passing the compiled binary as an argument.
  
<img width="1715" height="1032" alt="hexdit" src="https://github.com/user-attachments/assets/ef77dcb3-b6f0-4d9d-b1a5-510f63514c6e" />
  
the interface consists of two main panels, the left and the right one.
  
the purpose of the right panel is to make the hex data easier to understand and navigate.
  
the left panel is where all the editing happens.
  
at the bottom, we have a status bar showing your current position, modification status and some basic keyboard shortcuts.
  
<img width="1238" height="73" alt="bottompanel" src="https://github.com/user-attachments/assets/ac73015a-77ff-44ee-ad2c-1a897cc485b3" />
  
`^` = CTRL + 
  
`^S` = CTRL + S
  
the goal of this tutorial is to bypass the `if` statement and reach the "Hello, World!" output, since running the original binary doesn't print anything.
  
<img width="730" height="69" alt="output" src="https://github.com/user-attachments/assets/278f0208-84ec-45d6-bfd7-b23597a26072" />
  
now that we have our compiled binary open, let's search for `cmp`, which is the comparison instruction in x86.
  
press ^S, write the phrase you want to search for and F6 to enter search mode. pressing F6 again moves to the next result, while F7 moves to the previous one.
  
you can also press F3 to jump directly to the code start, as specified by the format.
  
<img width="648" height="65" alt="finding" src="https://github.com/user-attachments/assets/6c18d551-7704-430f-8fcd-ebd7c8290e3c" />
  
when reverse-engineering a program you don't know, you usually have to figure things out as you go.
  
but in our case, we already know what we're looking for.
  
if we have a stack location initialized to `0` before the `cmp` instruction (which represents our `a` variable), and then that same stack location is compared against `1`, we've found the code we're looking for.
  
<img width="1180" height="185" alt="codewewant" src="https://github.com/user-attachments/assets/679f0598-541d-4055-8dcb-59780767c437" />
  
now, the `jne` instruction after `cmp` means jump if not equal.
  
but we want the opposite behavior. we want it to jump if equal, so we'll replace `jne` with `je`.
  
this way, the jump is taken when the value is equal to 1. since our a variable is 0, the jump is not taken, so execution continues into the printf block.
  
if you don't know the hexadecimal difference between `je` and `jne`, you can inspect the binary and compare the hex values used by these instructions in other locations.

<img width="1167" height="61" alt="change" src="https://github.com/user-attachments/assets/ab74a746-2b07-4a76-9c2c-7edea61c2974" />
  
after changing `JNE` to `JE`, our disassembler immediately recognizes the change and updates the disassembly on the right panel.
  
<img width="1202" height="65" alt="ok" src="https://github.com/user-attachments/assets/0bd52a67-05cb-45b2-b8c7-3ff379ad94df" />
  
it now displays `je` instead of `jne`, so we can see that our modification was applied correctly.
  
let's save the changes with `^S` and exit using `^Q`.
  
now let's run our modified binary and see what happens:
  
<img width="732" height="128" alt="testing" src="https://github.com/user-attachments/assets/5675d45a-8a9c-4cdf-93d9-334fcdb9c658" />

# extras
  
you can go to any position in the code with ^G just like ^F

if you want to go to your main code you need to do some calculations by hand
  
binaries have something called a virtual address (vaddr) and its calculated from the format header
  
you can calculate it yourself and enter the final result as hex but hexdit can do the calculation for you, just type a v before the hex. you dont need the 0x tag like `v1140`
  
you still need a little calculation to find main with a virtual address. remember rip is the address of the next instruction (where the current one ends) so for something like `lea rdi, [rip+0xD5]` the target is
  
```
target_vaddr = instruction_vaddr + instruction_length + disp
```
  
everything you need for this is in the bottom bar. va is the instruction_vaddr and len is the instruction_length. disp comes from the instruction itself. then type v + the result in ^G
  
use a separate calculator for the math, hexdit is not a calculator
  
if you want to enter a plain file offset instead use these formulas
  
```
ELF: file_offset = vaddr - segment_vaddr + segment_offset
PE:  file_offset = vaddr - ImageBase - section_va + section_raw
```
  
for elf take the segment values from the phdr[n] LOAD line in the format header. for pe take ImageBase and the sec[n] line of the section your target is in
  
all the examples here are on an elf. on pe the idea is the same but you type the full address including ImageBase, like `v140001150`
  
you can go to the code start (not main, the start of the whole binary code) with F3 and go back with F5
  
here are the keybinds:
  
```
CTRL + q => quit
CTRL + s => save
TAB      => switch between left (hex) and right (asm) panel
F3       => goto code_start (specified by the format)
F4       => goto the target if your cursor is on a jump or call
F5       => go back after you used a goto
CTRL + f => search text on the right panel
F6 / F7  => next / previous search result
CTRL + g => goto something (plain hex goes to the offset you typed, vHEX does the vaddr calculation for you)
```