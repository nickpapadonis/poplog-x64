/* --- Copyright University of Sussex 1993. All rights reserved. ----------
 > File:            C.all/lib/ved/ved_ww.p
 > Purpose:         <ENTER> ww command
 > Author:          Jonathan Meyer, Sept 9 1992
 > Documentation:   REF *VEDSEARCH
 > Related Files:	SRC *VDREGEXP.P
 */
section;
compile_mode :pop11 +strict;

define global vars ved_ww =
	ved_search_or_substitute(%'-case -embed', undef%)
enddefine;

endsection;
