# Hexdit
  
Simple hex editor written in SL.
  
  <img width="1683" height="1035" alt="image" src="https://github.com/user-attachments/assets/580aa057-d50a-4d63-9c2f-a82a2602aaf8" />
## Usage
  
Download the **latest** version of [SL](https://github.com/0l3d/sl).
  
```bash
git clone https://github.com/0l3d/hexdit
cd hexdit/
./run.sh file  # for POSIX
./run.cmd file # for Windows
# or
sl src/hexdit.sl file
```
  
## Why is this project good?
  
Hexdit is fast as hell and also has a simple disassembler for x86.
  
You can also add your own formats by modifying the source code.
  
You can add everything you want to Hexdit without needing to compile it.
  
Do you need support for another architecture, like ARM64? Just add it to `arch_arm64.sl` just like `arch_x86.sl`.
  
You can also open a PR to contribute new features to this project.
  
## Tutorial
  
For a simple reverse engineering tutorial, check out: [Simple Hexdit Usage](TUTORIAL.md).
  
## License
  
This project is licensed under the *BSD 3-Clause License*.
  
## Author
  
Created by **0l3d**.
