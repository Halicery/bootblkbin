# Boot block &eacute;tudes 

## What is this? 

512 byte PC boot block assembly examples for bare metal programming joy, exploring Intel/AMD CPU features and internal operation. 

- basic CPU operation tests (descriptors, D-bit, B-bit, limit)
- 32-bit mode
- 286/386 protected mode switch
- IDT interrupts
- APIC interrupts
- multicore wake-up
- 16-bit Real Mode exceptions and 8086 emulation
- 64-bit mode switch
- mixing 16/32/64-bit code
- some frame buffer graphics with VESA call setup

Ongoing process.. with low threshold to make it public as it is. 

What is not here: TSS, hardware task switch, caching, privilege levels, call gates, paging (well, 64-bit mode needs paging). 

## It works on my hardware 

Absolutely no guarantee that these examples work everywhere. The BIOS leaves the CPU and hardware in a certain, but quite standard state. Mostly. The 16-bit Real Mode. Code is written minimal so that it works on Hyper-V first, the fastest way to boot, then test Virtual Box, then a few real hardware. If there is an issue, try fixing it. If it works it works. 

## NASM assembler

Code written for and assembled with NASM assembler. 

	>nasm -v
	NASM version 2.14.02 compiled on Dec 26 2018

Plain binary output ORG = 7C00. 

F. ex. `nasm bootblkbin_int64.asm -fbin -obin.vfd -lbootblkbin.l`

NASM will create a bootable virtual floppy file, `bin.vfd`, ready to boot in VM-s or the same file with PXE boot on real hardware. 

### bin.vfd 

360K (smallest possible) .vfd file that Hyper-V accepts. Virtual Box, PXE is happy with 512 byte file size. Boot block parameters, ROM signature not even needed for any VMs, we have the whole 512 bytes available for code. PXE boot is the same. Note that PXE loads the whole boot file at 7C00, not only one "sector". There are no sectors in PXE. 

## Running on VM-s: floppy boot

I use Hyper-V and Virtual Box 6.1 mostly on my AMD Ryzen Win10 host PC (good to test AMD features). Hyper-V is super fast to boot from virtual floppy. The guest OS is simple with all extra stuff disabled and with some 32MB RAM. No HDD. Attach bin.vfd as floppy and boot. 

How exactly the hardware is virtualized may also vary (eg. on startup A20 is inhibited on Virtual Box 6.1, but not on Hyper-V; segment limits are already extended on Hyper-V but not on VBox etc.). 

## Running on real hardware: PXE boot

Most of the examples are tested on some of my old rigs and notebooks I have: a Core i7 Haswell box, a Core i3 NUC SoC, an older Core 2 Duo notebook etc.
 
If BIOS can do network boot the PC is ready to go. Boot with PXE. I use the excellent `tftpd64.452`, where the same bin.vfd is the boot file for DHCP. A little pain to set up this program. Needs only DHCP and TFTP server to work correctly.
 
I abandoned writing physical floppies and boot another PC long ago..

-----------

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

----------------

### [bootblkbin_run16above.asm](ASM/bootblkbin_run16above.asm)

[<img width="50%" src="SCREENSHOT/run16above.png" />](https://github.com/Halicery/bootblkbin/blob/main/SCREENSHOT/run16above.png)

I was wondering how to execute D=0 16-bit code way above 1MB high in memory. CPU always uses full EIP for code fetch so this should work. CS segment limit should be extended first. Because of 8086-emulation, every jump, call, ret should use 32-bit operand size to work (otherwise EIP HI zeroed). Interestingly, CPU even honors the 66h prefix for short jump and works correctly in high memory. 









