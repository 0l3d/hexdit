# simple tutorial for hexdit
  
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
  
**gonna put an image here**
  
the interface consists of two main panels, the left and the right one.
  
**gonna put an image here**
  
the purpose of the right panel is to make the hex data easier to understand and navigate.
  
**gonna put an image here**
  
the left panel is where all the editing happens.
  
at the bottom, we have a status bar showing your current position, modification status and some basic keyboard shortcuts.
  
**gonna put an image here**
  
`^` = CTRL
  
`^S` = CTRL + S
  
the goal of this tutorial is to bypass the `if` statement and reach the "Hello, World!" output, since running the original binary doesn't print anything.
  
**gonna put an image here**
  
now that we have our compiled binary open, let's search for `cmp`, which is the comparison instruction in x86.
  
^S = CTRL + S
  
press ^S, write the phrase you want to search for and F6 to enter search mode. pressing F6 again moves to the next result, while F7 moves to the previous one.
  
you can also press F3 to jump directly to the code start, as specified by the format.
  
**gonna put an image here**
  
when reverse-engineering a program you don't know, you usually have to figure things out as you go.
  
but in our case, we already know what we're looking for.
  
if we have a stack location initialized to `0` before the `cmp` instruction (which represents our `a` variable), and then that same stack location is compared against `1`, we've found the code we're looking for.
  
**gonna put an image here**
  
now, the `jne` instruction after `cmp` means jump if not equal.
  
but we want the opposite behavior. we want it to jump if equal, so we'll replace `jne` with `je`.
  
this way, it will jump whenever the value is not `1` (which means our `a` variable is currently equal to `0`).
  
if you don't know the hexadecimal difference between `je` and `jne`, you can inspect the binary and compare the hex values used by these instructions in other locations.
  
**gonna put an image here**
  
after changing `JNE` to `JE`, our disassembler immediately recognizes the change and updates the disassembly on the right panel.
  
it now displays `je` instead of `jne`, so we can see that our modification was applied correctly.
  
let's save the changes with `^S` and exit using `^Q`.
  
**gonna put an image here**
  
now let's run our modified binary and see what happens:
  
**gonna put an image here**