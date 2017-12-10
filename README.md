toggle-pie
==========
This is an iOS tool which toggles the MH_PIE bit in an application.
This disables/re-enables the Address Space Layout Randomization of an application.
This is useful when disassembling an app, because it will cause runtime memory
locations to align with the locations that are seen in IDA/Hopper disassemblers.

Building
========
1. Ensure you have the theos build system set up. Instructions can be found at http://iphonedevwiki.net/index.php/Theos/Setup.
2. Change the 'theos' symlink to point to your $THEOS directory.
3. Run 'deploy'.

Usage
=====
Copy the compiled executable using scp to the device then run it:
```bash
devzkndeMacBook-Pro:toggle-pie-master devzkn$ deploy
==> Cleaning…
> Making all for tool toggle-pie…
==> Compiling toggle-pie.mm (armv7)…
==> Linking tool toggle-pie (armv7)…
```
The <PATH_TO_APPLICATION_BINARY> is most likely located in a sub-directory of /var/mobile/Containers/Bundle/Application/ on the device, if it's running iOS 8 or later.

To toggle the PIE bit again, re-run:
```bash
root /# toggle-pie <PATH_TO_APPLICATION_BINARY>
iPhone:~ root# toggle-pie /var/mobile/Containers/Bundle/Application/2B559443-6CEE-4731-AA3B-7E587BE67219/BINARY/
[STEP 1] Backing up the binary file...
[STEP 1] Binary file successfully backed up to /var/mobile/Containers/Bundle/Application/2B559443-6CEE-4731-AA3B-7E587BE67219//

[STEP 2] Flip the 32-bit PIE...
Original Mach-O header: cefaedfe0c00000009000000020000004b0000004c1d000085802100
Original Mach-O header flags: 85802100
Flipping the PIE...
New Mach-O header flags: 85800100
[STEP 2] Successfully flipped the 32-bit PIE.

[STEP 3] Flip the 64-bit PIE...
Original Mach-O header: cffaedfe0c00000100000000020000004b000000982000008580210000000000
Original Mach-O header flags: 85802100
Flipping the PIE...
New Mach-O header flags: 85800100
[STEP 3] Successfully flipped the 64-bit PIE.
iPhone:~ root# otool -hv /var/mobile/Containers/Bundle/Application/2B559443-6CEE-4731-AA3B-7E587BE67219//

```

License
=======

Note: I removed Peter Fillmore's license in the migration to iOS 8, FAT
      binaries, and 64-bit support. This is because I essentially re-architected
      the codebase. I've licensed it myself as MIT.
# KNtoggle-pie
