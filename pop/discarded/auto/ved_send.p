/* --- Copyright University of Sussex 1998.	 All rights reserved. ---------
 > File:		   C.unix/lib/ved/ved_send.p
 > Purpose:		   send file or range as mail, allows .mailrc Cc and Bcc specs
 > Author:		   Mark Rubinstein and A.Sloman 1985 (see revisions)
 > Documentation:  HELP * SEND, Berkeley Unix 'man mail'
 > Related Files:  LIB *VED_SENDMR, VMS LIB *VED_SEND, UNIX LIB *OLDSEND,
 */
compile_mode :pop11 +strict;

include sysdefs.ph;		;;; to work out a default name for the mail program

section;

/* variable to control whether whole process done in the background */
vars ved_send_wait;
unless isboolean(ved_send_wait) then
	true -> ved_send_wait;
endunless;

/* variable to control whether environment variable $record is removed */
vars ved_send_record;
unless isboolean(ved_send_record) then
	false -> ved_send_record;	;;; default is not to copy
endunless;

/* variable to control whether From line is inserted in file */
vars vedinsert_From;
unless isboolean(vedinsert_From) then
	true -> vedinsert_From;
endunless;

/*  vedindet_From controls whether lines in message starting with 'From '
		are indented with ">" in file.
	Suppressed if whole file sent, and if ved_sendmr is called with arguments.
*/
vars vedindent_From;
unless isboolean(vedindent_From) then
	true -> vedindent_From;
endunless;

/* variable to control whether aliases are parsed before mail program */
vars ved_send_aliases;
unless isboolean(ved_send_aliases) then
	true -> ved_send_aliases;
endunless;

vars ved_send_plain_text;
unless isboolean(ved_send_plain_text) then
	false -> ved_send_plain_text;
endunless;

/* the user's .mailrc file */
vars vedmailrc;

lvars mailrc = false;	;;; set when program is run

/* The user must have the option to use a different mailrc for VED-based
   mail and non-VED-based mail. Also it must NOT be computed at top level
   in the file. Must be done at run time. Can then be put in saved images,
   etc.
*/

lconstant default_mailrc = '$HOME/.mailrc';

lvars lastlookatmailrc = 0;

lconstant procedure aliases =
	newanyproperty([], 32, 1, 32, syshash, nonop =, false, false, false);

/* acceptable prefixes to find at file top */
lconstant
	to_prefixes = ['TO' 'To' 'to'],
	re_prefixes =
		['RE' 'Re' 're' 'Subject' 'subject' 'Subj' 'SUBJ' 'subj' 'SUBJECT'],
	cc_prefixes = ['CC' 'Cc' 'cc'],
	bcc_prefixes = ['BCC' 'BCc' 'Bcc' 'bcc'];


/* Mailer to use */

vars ved_send_mailer;
unless isstring(ved_send_mailer) then
#_IF DEF SYSTEM_V
	 '/usr/bin/mailx'
#_ELSE
	 '/usr/ucb/Mail'
#_ENDIF
	-> ved_send_mailer
endunless;

/* parse a string using spaces, tabs and commas as separators */
define lconstant parse_string(str);
	lvars c, i, str, lim = datalength(str);
	[%  fast_for i to lim do
			unless strmember(fast_subscrs(i, str) ->> c, ',\s\t') then
				/* found beginning of an entry */
				cons_with consstring {%
					repeat
						c;
						quitif(i == lim);
						fast_subscrs(i fi_+ 1 ->> i, str) -> c;
						quitif(strmember(c, ',\s\t'));
					endrepeat
				%};
			endunless;
		endfast_for
	%];
enddefine;


/* try to read the mailrc file - just look for aliases (going to a depth of
 * 25 before mishapping.
 */

define lconstant tryreadmailrc;
	lvars dev, i, count, line, n, name;
	dlvars expand_depth = 0;

	/* convert tabs to spaces - doesn't copy string */
	define lconstant tabs_to_spaces(str) -> str;
		lvars str, i;
		fast_for i to length(str) do
			if fast_subscrs(i, str) == `\t` then
				`\s` -> fast_subscrs(i, str);
			endif;
		endfast_for;
	enddefine;

	define lconstant count_ok(bool);
		lvars bool;
		unless bool then
			vederror('Premature end of ALIAS in MAILRC line: ' sys_>< line);
		endunless;
	enddefine;

	/* expands aliases and checks for recursion depth limit being exceeded */
	define lconstant checkentry(name, alias);
		lvars name, each, alias, newalias = nullstring, needcomma ;
		dlocal expand_depth;
		define lconstant procedure recheck(entry);
			lvars entry, alias;
			aliases(entry) -> alias;
			if islist(alias) then
				checkentry(entry, alias);
				aliases(entry);
			else
				alias or entry;
			endif;
		enddefine;


		expand_depth fi_+ 1 -> expand_depth;
		if expand_depth fi_> 25 then
			mishap(name, alias, mailrc, 3, 'Recursive Mail Alias')
		endif;
		if islist(alias) then
			false -> needcomma;		;;; controls whether commas inserted
			fast_for each in maplist(alias, recheck) do
				newalias, if needcomma then sys_>< space endif,
					sys_>< each	 -> newalias;
				true -> needcomma;
			endfor;
			newalias -> aliases(name);
		endif;
	enddefine;

	unless mailrc then
		;;; Set up mailrc. This should be done once only
		if isstring(vedmailrc) then vedmailrc
		elseif systranslate('MAILRC') ->> mailrc then
		else 	default_mailrc
		endif.sysfileok -> mailrc
	endunless;

	/* find if we can access the mailrc file and if we need to */
	returnunless(readable(mailrc) and sysmodtime(mailrc) > lastlookatmailrc);
	/* read in mailrc file and process lines starting with 'alias' */
	clearproperty(aliases);
	sysopen(mailrc, 0, "line") -> dev;
	0 -> line;
	until (sysread(dev, sysstring, sysstringlen) ->> count) == 0 do
		line fi_+ 1 -> line;
		tabs_to_spaces(sysstring) ->;
		nextunless((skipchar(`\s`, 1, sysstring) ->> i) and i <= count);
		/* something on this line */
		if issubstring_lim('alias', i, i, false, sysstring) then
			/* it's an alias */
			count_ok((skipchar(`\s`, i fi_+ 6, sysstring) ->> i) and i <= count);
			count_ok((locchar(`\s`, i, sysstring) ->> n) and n <= count);
			substring(i, n fi_- i, sysstring) -> name;
			count_ok((skipchar(`\s`, n, sysstring) ->> i) and i <= count);
			if sysstring(i) == `"` and sysstring(count fi_- 1) == `"` then
				/* if alias enclosed in " marks, remove them */
				i fi_+ 1 -> i;
				count fi_- 1 -> count;
			endif;
			parse_string(substring(i, count fi_- i,sysstring)) -> aliases(name);
		endif;
	enduntil;
	sysclose(dev);
	sysmodtime(mailrc) + 1 -> lastlookatmailrc;
	appproperty(aliases, checkentry);
enddefine;


/* Expand aliases in -line-.  Return 'transformed' line, i.e. expanded. Pipes
 * are left for the mailer to cope with.
 */
define lconstant check_aliases(line) -> line;
	lvars line, alias, name;
	/* see if we are using aliases */
	returnunless(ved_send_aliases);
	/* see if we can/need to update the alias property */
	tryreadmailrc();
	/* perform alias substitution */
	if line = nullstring or line = vedspacestring then
		vederror('Names missing on line ' sys_>< vedline);
	endif;
	cons_with consstring {%
		fast_for name in parse_string(line) do
			if aliases(name) ->> alias then
				check_aliases(alias)
			else
				name
			endif.explode, `,`;
		endfast_for;
		/* get rid of last comma */
		erase();
	%} -> line;
enddefine;


/* simple logging of outgoing mail */
define lconstant writelog(tolist, subject, cclist, bcclist);
	lvars tolist subject cclist bcclist outfile dout;
	/* place to store short records of outgoing mail */
	if systranslate('MAILREC') ->> outfile then
		;;;vedputmessage('Logging in ' sys_>< outfile);
		discappend(outfile) -> outfile;
		outfile(`\n`);
		appdata(% outfile %) -> dout;
		dout(sysdaytime());
		dout('\nTo: '); dout(tolist);
		unless cclist = nullstring then
			dout('\nCc: '); dout(cclist);
		endunless;
		unless bcclist = nullstring then
			dout('\nBcc: '); dout(bcclist);
		endunless;
		unless subject = nullstring then
			dout('\nRe: '); dout(subject);
		endunless;
		outfile(termin);
	endif;
enddefine;


/* pipe the marked range through the ucb mail program, inserting escapes to
 * specify subject, cc list and bcc list.  Note that the function assumes
 * that the mailer is using the default escape (tilde).  Function must not
 * be called with a null tolist!  vvedmarklo *must* be <= vvedmarkhi!!
 */
define lconstant runmailer(tolist, subject, cclist, bcclist);
	lvars tolist, subject, cclist, bcclist, child, mailer_arglist,
			procedure (consume)
		;
	dlocal vedediting, vedbufferlist, popexit;

	define lconstant procedure do_mail(mailer, args);
		lvars mailer, args, child, dout, din, line, len, nulldev;
		dlocal poprawdevin, popdevout;
		syspipe(false) -> din -> dout;
		0 -> vedscreencharmode;	;;; in case there are error messages
		rawoutflush();
		sysopen('/dev/null',2,false) -> nulldev;

		if sys_fork(true) ->> child then
			/* this is still parent */
			sysclose(din);
			/* stuff the marked range to the mail program */
			if vvedmarklo <= vvedmarkhi then
				;;; non-empty body
				vedfile_line_consumer(dout, ved_send_plain_text) -> consume;
				repeat
					vedbuffer(vvedmarklo) -> line;
					if datalength(line) fi_> 0
					and fast_subscrdstring(1,line) == `~` then
						;;; turn leading "~" into "~~"
						'~' <> line -> line;
					endif;
					consume(line);
				quitif(vvedmarklo == vvedmarkhi);
					vvedmarklo + 1 -> vvedmarklo;
				endrepeat;
			endif;
			/* and now stuff the additional parameters as escapes */
			unless (length(subject) ->> len) == 0 then
				syswrite(dout, '~s' sys_>< subject sys_>< '\n', len fi_+ 3);
			endunless;
			unless (length(cclist) ->> len) == 0 then
				syswrite(dout, '~c' sys_>< cclist sys_>< '\n', len fi_+ 3);
			endunless;
			unless (length(bcclist) ->> len) == 0 then
				syswrite(dout, '~b' sys_>< bcclist sys_>< '\n', len fi_+ 3);
			endunless;
			sysclose(dout);
			/* wait for the child */
			sys_wait(child) -> (,);
			sysclose(nulldev);
		else
			/* child - the mailer */
			sysclose(dout);
			din -> popdevin;
			;;; prevent attempts to read from or write to terminal
			nulldev ->> poprawdevin -> popdevout;
			;;; Should never return from this:
			sysexecute(mailer, args, false);
		endif;
	enddefine;

	if vedindent_From then
		;;; Insert ">" at beginning of lines starting 'From '
		;;; May be suppressed in vedsend
		veddo('gsr/@aFrom />From /');
	endif;

	/* construct the argument to the mailer which gives recipient list */
	[^(sys_fname_nam(ved_send_mailer)) ^^(parse_string(tolist))] -> mailer_arglist;

	/* is user willing to wait? */
	if ved_send_wait then
		vedputmessage('Sending mail in foreground...');
		/* open a pipe to send mail to mailer from the top level process */
		do_mail(ved_send_mailer, mailer_arglist);
		writelog(tolist, subject, cclist, bcclist);
	else
		/* busy user can't wait, so detach a process */
		vedputmessage('Sending mail in background...');
		/* these values are restored by dlocal */
		identfn -> popexit;
		[] -> vedbufferlist;
		false -> vedediting;
		if sys_vfork(true) ->> child then
			/* top level parent - a quick wait then we're off */
			sys_wait(child) -> (,)
		else
			/* vforked 1st child (to prevent zombie) */
			if sys_fork(false) then
				/* needed a real fork because processes will be running along
				 * side one another.  This is still the 1st child.
				*/
				fast_sysexit();
			endif;
			/* we're in the fully detached process */
			lblock
				compile_mode :vm -prmprt;
				;;; this is required to make things work ....
				false -> vedinvedprocess;
			endlblock;
			do_mail(ved_send_mailer, mailer_arglist);
			writelog(tolist, subject, cclist, bcclist);
			/* exit from the detached parent process */
			fast_sysexit()
		endif
	endif
enddefine;


define lconstant vedsend(whole_file);
	lvars, whole_file, message, line, i, prefix, rest, tolist, subject,
		cclist, bcclist, changed = vedchanged;
	dlocal vedargument, vedpositionstack, vedautowrite = false,
		pop_file_versions = 1, popenvlist,
		vedindent_From, vedinsert_From,

		;;; next variable preserves vedsearch context
		ved_search_state
	;

	define lconstant fixline(string);
		;;; make string current line and re-display
		lvars string;
		string -> vedthisline();
		vedrefreshrange(vedline,vedline,undef);
	enddefine;

	 define lconstant has_record(list);
		;;; if necessary unset $record
		lvars item, list;
		fast_for item in list do
		returnif(isstartstring('record=',item))(true)
		endfor;
		false
	enddefine;

	if not(ved_send_record) and has_record(popenvlist) then
		maplist(popenvlist,
			procedure(string); lvars string;
				unless isstartstring('record=',string) then string endunless
			endprocedure) -> popenvlist
	endif;

	/*	Decide whether to put 'From' line at top and change lines in
		message starting with 'From ' to start with '>From' */

	if whole_file or vedargument /= nullstring then
		/* Probably not kept in mail_file format, so don't change file */
		false ->> vedinsert_From -> vedindent_From
	endif;

	/* Prevent display of intermediate changed marked ranges */
	vedmarkpush();
	false -> vvedmarkprops;
	dlocal 0 %, vedmarkpop()%;

	/* position the cursor and so on depending on whole or marked range */
	vedpositionpush();
	if whole_file then
		1 -> vvedmarklo;
		vvedbuffersize -> vvedmarkhi;
		vedtopfile();
		'Sending mail - whole file'
	else
		if vvedmarkhi < vvedmarklo then
			vederror('ILLEGAL MARKED RANGE: vvedmarkhi < vvedmarklo')
		endif;
		vedmarkfind();
		'Sending mail - marked range'
	endif -> message;

	/* Find the first non-empty line in marked range */
	unless ved_try_search('@?', [range]) do
		vederror('No message in marked range')
	endunless;
	vedputmessage(message);

	/* include the From line in the file, if required and appropriate */
	if vedinsert_From then
		/* add Berkeley-like From line unless one already there */
		'From ' sys_>< (sysgetusername(popusername) or popusername) -> line;
		/* look for an old From - delete if found */
		if isstartstring(line, vedthisline()) then
			/* From is on current line */
		elseif vedline /== 1 and
				isstartstring(line, vedbuffer(vedline-1)) then
			/* From is on previous line */
			vedcharup();
		else
			/* no existing From - make space for one */
			vedlineabove();
		endif;
		fixline(line);
		vedcheck();
		vedtextright(); vedcharright(); vedinsertstring(sysdaytime());
		/* don't send the From line as part of the message */
		vedline fi_+ 1 -> vvedmarklo;
		vednextline();
	endif;
	vedputmessage(message);

	/* collect argument names, either from command line or "To: " line */
	nullstring ->> tolist ->> subject ->> cclist -> bcclist;
	unless vedargument = nullstring then
		space sys_>< check_aliases(vedargument) -> tolist;
	endunless;

	/* collect names etc from file and clean up file */
	repeat
		vedthisline() -> line;
		/* is this the last line of the mail header? */
		quitunless((locchar(`:`, 1, line) ->> i) and i <= vvedlinesize);
		/* no - get the mail header part prefix */
		substring(1, i fi_- 1, line) -> prefix;
		/* now get the rest of the line */
		/* bug fix from jamesg */
		if skipchar(`\s`, i fi_+ 1, line) ->> i then
			substring(i, vvedlinesize fi_+ 1 fi_- i, line)
		else
			/* colon must have been spurious */
			space
		endif -> rest;
		/* store the rest according to the prefix */
		if member(prefix, to_prefixes) then
			unless tolist = nullstring then
				if vedargument = nullstring then
					/* conflict from multiple To: lines */
					vederror('Can\'t send - more than one recipient line');
				else
					vederror('Use "send person" OR give "to:" line in file');
				endif;
			endunless;
			/* expand aliases, if necessary */
			check_aliases(rest) -> tolist;
			fixline('To: ' sys_>< tolist);
		elseif member(prefix, re_prefixes) then
			unless subject = nullstring then
				 vederror('Can\'t send - too many subject lines');
			endunless;
			rest -> subject;
			fixline('Subject: ' sys_>< subject);
		elseif member(prefix, cc_prefixes) then
			unless cclist = nullstring then
				vederror('Can\'t send - too many cc lines');
			endunless;
			check_aliases(rest) -> cclist;
			fixline('Cc: ' sys_>< cclist);
		elseif member(prefix, bcc_prefixes) then
			unless bcclist = nullstring then
				vederror('Can\'t send - too many bcc lines');
			endunless;
			check_aliases(rest) -> bcclist;
			fixline('Bcc: ' sys_>< bcclist);
		else
			/* not a known header line */
			quitloop;
		endif;
		vednextline();
	endrepeat;

	/* mark the body of the message - that which is to be sent */
	vedmarkpush();
	vedline -> vvedmarklo;
/*
	;;; uncomment these two lines if you want to be prevented from
	;;; sending empty messages!
	if vvedmarklo > vvedmarkhi then
		vederror('Can\'t send - null message body');
	endif;
*/
	/* check that we have someone to send to */
	if tolist = nullstring then
		vederror('Can\'t send - send mail to whom?');
	endif;

	/* call the mail processing function */
	runmailer(tolist, subject, cclist, bcclist);

	vedmarkpop();
	vedpositionpop();
	vedputmessage('Done');
	if vedinsert_From then
		if changed then changed + 1 else 1 endif
	else
		changed
	endif -> vedchanged;
enddefine;

define vars ved_send =
	vedsend(%true%)
enddefine;

define vars ved_sendmr =
	vedsend(%false%)
enddefine;

endsection;


/* --- Revision History ---------------------------------------------------
--- John Gibson, Aug 25 1998
		Added missing call of vedmarkpop at end of vedsend.
--- John Gibson, Apr 21 1994
		Changed to use new sys_vfork etc.
--- John Williams, Jan  4 1994
		ved_sendmr now makes sure the marked range isn't empty.
--- Jonathan Meyer, Sep 29 1993
		Change vvedsr*ch vars to ved_search_state.
		vedtest*search -> ved_try_search.
--- John Gibson, May  8 1993
		Fixes to runmailer
--- James Goodlet, Oct 22 1992
		Tried to make multiple addressee lines error more meaningful,
		especially when conflict is between addressee on command lines and
		one or more to: lines in file.
--- John Gibson, Mar 23 1992
		Changed to use vedfile_line_consumer to write out the marked range.
		Also added -ved_send_plain_text- for controlling 2nd arg to that.
--- Aaron Sloman, Apr  3 1990
		ved_sendmr was not updating -vedchanged-. Fixed so that it increments
		it by 1 if vedinsert_From is true. Otherwise the whole point of
		inserting the From line is lost if it is not recorded.
--- James Goodlet, Feb 16 1990 - Fixed last change so that one line messages
		are not sent as empty ones.
--- Aaron Sloman, Jan  4 1990
	Fixed so that it allows transmission of empty messages. (Should this
	be controlled by a variable?)
--- Aaron Sloman, Aug 13 1989
	Replaced issubstring_lim with isstartstring
--- Aaron Sloman, Aug 13 1989
	Tidied up. Fixed vedindent_From bug. Replaced pdr_valof with define =
	Changed -ucbmail- to -runmailer-. Made vedindent_From and vedinsert_From
	automatically false when sending whole file or sending with names in
	vedargument
--- Aaron Sloman, Aug  9 1989
	Now changes 'From ' at start of line to '>From ' unless vedindent_From
	is false.
--- Aaron Sloman, Apr  5 1989
	CHANGED BOBCAT to SYSTEM_V
--- Rob Duncan, Apr  4 1989
	Changed to use -sys*vfork- unconditionally, as this is always available
	(although it may be the same as -sys*fork-);
	added "uses sysdefs" to provide definition of BOBCAT flag;
	added -str- to lvars list in parse_string
--- Aaron Sloman, Mar 21 1989
	Introduced ved_send_mailer, and made mailer_arglist sensitive
	to it.
--- Aaron Sloman, Mar 21 1989
	Line ending with colon at end of headers caused problems. Bug fix
	by James Goodlet installed.
--- Aaron Sloman, Mar 17 1989
	dlocalised vedsearch state variables in vedsend.
--- Aaron Sloman, Mar 13 1989
	Fixed lines starting with "~"
--- Aaron Sloman, Mar 12 1989
	Simplified last bit using define :pdr_vlaof.
	Added ved_send_record
	Merged James' changes below with some previous changes avoiding
	consword.
--- James Goodlet, Mar 1989 - Major rewrite.  Changed to allow use of
		/usr/ucb/Mail, using idea of Jason Handby to use "~" prefixes.
		Added ved_send_aliases.  Various rationalisations and fewer forks.
--- Aaron Sloman, Jan  2 1989
	Changed -aliases- to use newanyproperty, removing need for consword.
	Made alias expander (checkentry) insert commas instead of spaces
*/
