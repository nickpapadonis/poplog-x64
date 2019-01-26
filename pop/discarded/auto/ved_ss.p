/* --- Copyright University of Sussex 1993. All rights reserved. ----------
 > File:            C.all/lib/ved/ved_ss.p
 > Purpose:         <ENTER> ss command
 > Author:          Jonathan Meyer, Sept 9 1992
 > Documentation:   REF *VEDSEARCH
 > Related Files:	SRC *VDREGEXP.P
 */
section;
compile_mode :pop11 +strict;

define global vars ved_ss =
	ved_search_or_substitute(%'-case', undef%)
enddefine;

endsection;
