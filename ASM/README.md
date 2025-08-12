Every file has the nasm command at the first line. 

### Some coding conventions

#### Save code bytes 

512 bytes are not much especially for 32-bit code. All offsets takes 4 bytes, etc. Sometimes really sqeezing and opt for code size sacrifying nice code.

### Include files

Files of `inc.xxxxxxxxx.asm` 

After a while, certain code fragments just repeat: instead of copy/paste using NASM %include. Eg. the 16-bit prologue that prints out CPUID and the .asm file name. We write stuff on the char screen so 16/32/64-bit hex and string routines are always included. For other quick tests: 32- or 64-bit mode switch. A small one for APIC programming. Just comfortable.  

### 16/32-bit assembly

I tend to write 16-bit code with capital letters and 32-bit with small so it's easier to see where we're at:

	rep stosd       <-- 32-bit D=1 code
	                
	REP STOSW       <-- 16-bit D=0 code

### ALIGN n

In bootblock we do not align anything to save code bytes. Also good for testing that Intel has no alignment requirements at all for any system structures. Even the stack works with odd address. 
