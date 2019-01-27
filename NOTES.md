NOTES
=====

This version may need attention, please read:
------------------------------------------------------------------------

## 64 Bit Fixes

Info from Waldek:
There may be more fixes to find and replace.

"I have now found the cause: this was due to incomplete port.  Namely,
on 64-bit Linux C 'int' is 32-bit.  On AMD-64 32-bit numbers get
extended by zeros to 64-bit, so negative 32-bit ints become
positive when viewed as 64-bit numbers.  Many system functions
return C 'int' and Popolog must cope with this.  In the port
I did this in clumsy way: comparing numbers against largest
posivive 32-bit int isntead of checking sign.  But I missed
some places where 32-bit int can appear.  Below is patch
that fixes this problem in better way: '_extern' calls
are specially marked so that return value is properly
converted to 64-bit number.  I fixed only the place
which caused problem, but all system call shuld be checked
and marked if needed and the kludge I used previously
should be removed.  With proper definition for 32-bit
poplog this should significanly reduce differences between
32-bit and 64-bit version."

## Build process
1. Use 'corepop' and files in src/syscomp to create 'popc',
   'poplink' and 'poplibr'.
2. Use 'popc' to compile files is src/
3. Link new poplog using 'poplink' and 'poplibr' (that also needs
   support code from 'extern/lib')
4. Build running images images

After 3) you may go to 1) if you want to modify how tools used
in build work.

## Saved Images
The saved images are created by various scripts in

+ $usepop/pop/com/

## pop/com scripts

+ mkstartup
  - creates startup.psv
  - needed by most of the others
+ mkplog
  - makes prolog.psv
+ mkclisp
  - makes clisp.psv
+ mkpml
  - makes pml.psv
+ Poplog ML
+ mkxved
  -  makes xved.psv
+ makeimages
  - assumes mkstartup has been run, then
  - runs mkpml, mkplog, mkclisp

## basepop11 and it's directed soft links
basepop11 is linked (as ls -l in a new installation should show) to several
other filenames:

+ clisp
+ doc
+ help
+ im
+ pml
+ pop11
+ prolog
+ ref
+ teach
+ ved
+ xved

That means you can invoke basepop11 with different names. When it is
invoked it checks which name was used, and then runs basepop11 with a saved
image to provide the system required

## Saved images
The saved images are created by various scripts in

+ $usepop/pop/com/

## $usepop/pop/com scripts
+ mkstartup
  - creates startup.psv
  - needed by most of the others
+ mkplog
  - makes prolog.psv
+ mkclisp
  - makes clisp.psv
+ mkpml
  - makes pml.psv
  - Poplog ML
+ mkxved
  - makes xved.psv
+ makeimages
  - assumes mkstartup has been run, then
  - runs mkpml, mkplog, mkclisp

## basepop invocation notes
If you give the command X where == prolog, clisp, pml, or xved
then it runs the appropriate one of

+ basepop11 +startup +plog
+ basepop11 +startup +clisp
+ basepop11 +startup +pml
+ basepop11 +startup +xved

## Stress testing
mkeliza produces an eliza.psv in $popsavelib which can be run as

+ pop11 +eliza

If you have espeak, you can try

+ $popcom/mkeliza-speak

to give a demo of a talking eliza.

The Birmingham installation scripts create that by default and there are
some demo/test commands specific where you can check it. Also mkgblocks,
produces a little blocks-world graphical demo -- useful for testing the X11
installation.
