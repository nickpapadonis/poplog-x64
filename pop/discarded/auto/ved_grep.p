/* --- Copyright University of Sussex 1997. All rights reserved. ----------
 > File:            C.unix/lib/ved/ved_grep.p
 > Purpose:         Run grep and read output into a VED file
 > Author:          Aaron Sloman, Oct 14 1990 (see revisions)
 > Documentation:	HELP * VED_GREP
 > Related Files:
 */
compile_mode :pop11 +strict;

/*
  <ENTER> grep [<flags>] <search-string> file1, file2 ...
  <ENTER> grep [<flags>] <search-string> <file-pattern>
  <ENTER> grep [<flags>] <file-pattern>
  <ENTER> grep [<flags>]
*/

section;

uses-by_name vedgenshell;


/*USER-MODIFIABLE DEFAULTS*/

vars grep_search_command, grep_leave_colons;

vars show_output_on_status;	;;; used by vedgenshell


/* UTILITIES */

define lconstant analyse_args(args) -> args;
	;;; if there are any flags (indicated by -) put the characters
	;;; of the leading substring on the stack. Return a string
	;;; with remaining args

	lvars args, flags = false, n = 1, nextspace = false;

	while subscrs(n, args) == `-` do
		true -> flags;	;;; indicate flag found

		locchar(`\s`,n,args) -> nextspace;
	quitunless(nextspace);
		skipchar(`\s`, nextspace, args) -> n;
	quitunless(n)
	endwhile;

	if nextspace then
		fast_for n from 1 to nextspace do
			subscrs(n,args)
		endfast_for;
		`\s`;
		allbutfirst(nextspace,args) -> args;
	elseif flags then
		;;; no following space, so it is all flags
		explode(args), `\s`;
		nullstring-> args;
	else
		;;; no flags found, args unchanged
	endif
enddefine;

define lconstant next_string() -> string;
	;;; get space/tab delimited string to right of cursor,
	;;; excluding trailing . or ,.
	;;; Uses the mechanism employed by vedexpandchar, in SRC * vdprocess.p
	lvars string;
	pdpart(vedexpandchars(`f`))('\s\t\n();,[]{}|><~&*?`\'"', '.,') -> string;
enddefine;

define vars ved_grep;
	lvars oldfile = vedcurrentfile, flags;

	dlocal show_output_on_status = false, vedargument;

	;;; Save vedsearch state
	dlocal ved_search_state;

	unless isstring(grep_search_command) then
		;;; ggrep (Gnu Grep) is the fastest search program at Sussex
		if sys_file_exists('/usr/local/bin/ggrep') then
			'ggrep'
		else
			'grep'
		endif -> grep_search_command
	endunless;

	unless isboolean(grep_leave_colons) then
		false -> grep_leave_colons
	endunless;


	;;; now create second argument for vedgenshell

	consstring(#|
		explode(grep_search_command), `\s`,
		if vedargument = nullstring then
			explode(vedthisline())
		else
			analyse_args(vedargument) -> vedargument;

			unless strmember(`\s`, vedargument) then
				explode(next_string()), `\s`, explode(vedargument)
			else
				explode(vedargument)
			endunless

		endif
		|#) -> vedargument;

	valof("vedgenshell") (systranslate('SHELL') or '/bin/sh', vedargument);

	;;; Now prepare file so that filenames are delimited by spaces

	unless oldfile == vedcurrentfile or grep_leave_colons then
		;;; get rid of first colon in each line
		dlocal vedstatic = true;
		lblock lvars line, loc;
			for line from 1 to vvedbuffersize do
				if locchar(`:`, 1, subscrv(line,vedbuffer)) ->> loc then
					vedjumpto(line, loc);
					veddotdelete();
				endif
			endfor
		endlblock;

		vedjumpto(1,1)

	endunless;
enddefine;

endsection;


/* --- Revision History ---------------------------------------------------
--- John Williams, Jan  7 1997
		Now uses $SHELL if set (/bin/sh otherwise), as per BR joew.12.
--- John Gibson, Aug  2 1995
		Made initialisation of grep_search_command be done at runtime
--- Jonathan Meyer, Sep 29 1993
		Changed vvedsr*ch vars to ved_search_state
--- John Williams, Aug  4 1992
		Made -ved_grep- global (cf BR isl-fr.4461)
--- Aaron Sloman, Oct 21 1990
	Restricted test for 'ggrep' to sussex
--- Aaron Sloman, Oct 16 1990
	Completely replaced and generalised previous version. Provided
	HELP file
 */
