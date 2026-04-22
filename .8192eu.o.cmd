savedcmd_/home/fullmetal/InstalarDriver/rtl8192eu-linux/8192eu.o := x86_64-linux-gnu-ld -m elf_x86_64 -z noexecstack --no-warn-rwx-segments --strip-debug  -r -o /home/fullmetal/InstalarDriver/rtl8192eu-linux/8192eu.o @/home/fullmetal/InstalarDriver/rtl8192eu-linux/8192eu.mod  ; ./tools/objtool/objtool --hacks=jump_label --hacks=noinstr --hacks=skylake --ibt --orc --retpoline --rethunk --sls --static-call --uaccess --prefix=16  --link  --module /home/fullmetal/InstalarDriver/rtl8192eu-linux/8192eu.o

/home/fullmetal/InstalarDriver/rtl8192eu-linux/8192eu.o: $(wildcard ./tools/objtool/objtool)
