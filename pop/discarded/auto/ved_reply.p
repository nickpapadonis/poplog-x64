/* --- Copyright University of Sussex 1993.  All rights reserved. ---------
 > File:           C.unix/lib/ved/ved_reply.p
 > Purpose:		   Begin reply to Unix message in VED
 > Author:         Aaron Sloman, Nov  1 1986 (see revisions)
 > Documentation:  HELP * VED_REPLY, * VED_MAIL
 > Related Files:  LIB * VED_MCM * VED_MDIR  * VED_SEND, *VED_MAIL
 */
compile_mode :pop11 +strict;

/*
This can be used with a Unix format mail file in the VED buffer. It assumes
that mail messages start with 'From 'at the beginning of a line.

If the cursor is in a mail message then
	<ENTER> reply
starts a header for a message to the sender, with same subject. The new
message is a marked range.
	<ENTER> sendmr
can then be used to send the mail.

	<ENTER> Reply

is similar, but attempts to produce a 'Cc: ' line with names of the others
who received the original message.

Either command can be given an optional extra argument which is either a
file name, in which case the reply will go into a file of that name, or
a line number, in which case the reply will go after that line, or
one of
	@t	- above Top of current current message
	@z  - end of file
	.	- above current line

NOTES:

Deals with various formats of UNIX mail headers but probably not completely.

Reply tries to clean up addresses of people on the current machine in the
Cc: list.
*/

section;

;;;; EDIT LIB POPHOST FOR DIFFERENT SITES IF NECESSARY
uses pophost;
lconstant
	hostname= pophost("systemname"),
	Ccstring='Cc: ';

global vars popsitename;
unless isstring(popsitename) then
	'@' sys_>< pophost("sitemailname") ;;; see lib pophost
		-> popsitename
endunless;

/* UTILITY PROCEDURES */

define lconstant charsbetween(start,fin,string) with_props 501;
	;;; put characters in string between start and fin on stack;
	lvars start,fin,string;
	min(fin,datalength(string)) -> fin;
	fast_for start from start to fin do
		subscrs(start,string)
	endfor
enddefine;

define lconstant prunesitename(string) -> string with_props 505;
	;;; get rid of occurrences of popsitename in string
	lvars string, len = datalength(popsitename), start = 1, found;
	;;; could be a lot more efficient
	if issubstring(popsitename,string) then
		cons_with consstring {%
			 while issubstring(popsitename, start, string) ->> found do
				 charsbetween(start, found fi_-1, string);
				 found fi_+ len -> start;
			 endwhile,
			 charsbetween(start,datalength(string) ,string)
			 %} -> string
	endif
enddefine;

define lconstant extract_mailnames(string) ->new  with_props 510;
	lvars string, start = 1, next, fin, new;
	if strmember(`<`, string) and strmember(`>`, string) then
	  cons_with consstring{%
		 while (locchar(`<`, start, string) ->> next)
		 and (locchar(`>`, next, string) ->> fin)
		 do
			 charsbetween(next fi_+ 1, fin fi_-1, string);
			 fin -> start;
			 `,`		;;; trailing commas removed elsewhere
		 endwhile,
		 %}
	else string
	endif -> new;
	if new = nullstring then string -> new endif;
	prunesitename(new) -> new;
enddefine;

define lconstant Veddo(vedcommand) with_props 600;
	;;; vedcommand is a substitute command. Do it without messages
	lvars line, edit=vedediting;
	dlocal vedcommand;
	vedtrimline(); copy(vedthisline()) -> line;
	false -> vedediting;
	space sys_>< vedcommand -> vedcommand;
	veddocommand();
	edit -> vedediting;
	unless line = vedthisline() then vedrefreshrange(vedline,vedline,undef)
	endunless
enddefine;

define lconstant vedgetrest(string) -> string with_props 601;
	;;; used to get continuation of "To:" or "CC:" line, etc.
	;;; if next line starts with space or tab
	lvars string, line;
	extract_mailnames(string) -> string;
	repeat
		vednextline();
		vedthisline() -> line;
	quitif(vvedlinesize == 0 or strmember(`:`,line)
			or not(strmember(line(1),'\s\t')));
		string  sys_>< extract_mailnames(line) -> string
	endrepeat;
enddefine;

define lconstant vedtryfind(string,lo,hi) -> found with_props 602;
;;; Assume current message is between lines lo and hi.
;;; Try to locate line starting with string between lo and hi
	lvars string, lo, hi, found;
	vedjumpto(lo,1);
	repeat
		if vvedlinesize == 0 then false -> found; return() endif;
		vedthisline() -> found;
		returnif(isstartstring(string, found));
		vedchardown();
		if vedline > hi then false -> found; return() endif;
	endrepeat
enddefine;

define lconstant vedgetsender(lo,hi) -> line with_props 603;
	;;; Get name of sender from 'From: ...... <name>'
	lvars lo, hi, line, m, n, temp;
	;;; 'lo' is line of top of message, 'From 'line.
	vedtryfind('From: ', lo, hi) -> line;

	if line then
		;;; Berkeley Unix. Various formats - e.g. from Janet, uucp, etc.
		;;; now cope with different formats of From: lines
		;;; From: ..... <name>
		if locchar(`<`,1,line) then
			extract_mailnames(line) -> line;
		elseif (locchar (`(`,1,line) ->> m) then
			;;; Out of date? Redundant?
			;;; deal with other mail format : From: name ( .... )
			substring(7, m fi_- 8, line) -> line
		else
			;;; assume what's after 'From: ' is name
			substring(7, vvedlinesize - 6, line) -> line
		endif;
	else
		;;; Sometimes there is no 'From: ' line. So get 'From ' line.
		subscrv(lo, vedbuffer) -> line;
		if isstartstring('From ',line) then
			skipchar(`\s`,5,line) -> lo;
			locchar(`\s`,lo,line) -> hi;
			prunesitename(substring(lo, hi - lo, line))
		else false
		endif -> line
	endif
enddefine;

define lconstant vedgetsubject(lo,hi) -> subject with_props 604;
	;;; Get subject from line 'Subject: ...   '
	lvars lo,hi,subject;
	vedtryfind('Subject: ', lo, hi) -> subject;
	if subject then
		;;; Add "Re:" to indicate that it is a reply to a message on
		;;; same subject, unless it's there already
		if issubstring('Re:', subject) then
			copy(subject) -> subject		;;; to be safe
		else
			'Subject: Re: ' sys_>< allbutfirst(9, subject) -> subject
		endif;
	else 'Subject: ' -> subject
	endif
enddefine;

define lconstant vedgetCc(lo,hi,) -> Cc with_props 605;
	;;; get Cc: line
	lvars lo, hi, Cc, line;
	vedtryfind(Ccstring, lo, hi) -> Cc;
;;; DECLARING VARIABLE Ccstring
;;; DECLARING VARIABLE vedtryfind
	if Cc then
		;;; add the following line if it starts with space or tab
		vedgetrest(Cc) -> Cc;
		unless isstartstring(Ccstring, Cc) then
			Ccstring sys_>< Cc -> Cc
		endunless
	endif
enddefine;

define lconstant vedgetTo(lo,hi,) -> string with_props 606;
;;; get 'To: ' line, in case there are other recipients
	lvars lo, hi, string, line;
	vedtryfind('To: ', lo, hi) -> string;
	if string then allbutfirst(3, string)-> string;
		;;; Check if no other recipients
		if vedissubitem(popusername, 1, string)
		and datalength(string) - datalength(popusername) < 2
		then nullstring -> string
		endif;
		vedgetrest(string) -> string;
		if string = nullstring then false -> string endif
	endif
enddefine;

define lconstant vedtry(proc,lo,hi);
	lvars proc,lo,hi;
	vedpositionpush();
	proc(lo,hi);
	vedpositionpop()
enddefine;

define lconstant veddoreply(all_?) with_props ved_reply;
;;; ENTER reply starts reply to sender. ENTER Reply starts reply to all
;;; all_? is a boolean. If true, reply to all recipients incl Cc: list
	lvars sender, subject, Cc, To, lo, hi, all_?, Where,
		oldvedediting = vedediting, oldc=vedchanged;
	dlocal vvedmarkprops, vedediting, vedbreak=false, vedautowrite=false,
		;;; localise search state variables.
		ved_search_state;

	unless subscrs(1, popsitename) == `@` then
		'@' sys_>< popsitename -> popsitename
	endunless;
	if vedargument = nullstring then
		false -> Where
	else
		;;; find out where to insert reply
		unless (strnumber(vedargument) ->> Where) then
			vedargument -> Where
		endunless;
	endif;
	vedmarkpush();
	false -> vvedmarkprops;
	ved_mcm();
	vvedmarklo -> lo; vvedmarkhi -> hi;
	vedmarkpop();
	vedtry(vedgetsender,lo,hi) -> sender;
	vedtry(vedgetsubject,lo,hi) -> subject;
	if all_? then
		vedtry(vedgetCc,lo,hi) -> Cc;
		vedtry(vedgetTo,lo,hi) -> To;
		;;; append To: list to Cc: list
		if Cc or To then
			unless Cc then Ccstring -> Cc endunless;
			if To then Cc sys_>< space  sys_>< To -> Cc endif;
		endif;
	else false -> Cc
	endif;
	;;; Find where to start reply
	if Where = '@t' then lo
	elseif Where = '@z' then vvedbuffersize fi_+ 1
	elseif Where = '.' then vedline
	else Where
	endif -> Where;
	if isinteger(Where) then
		vedjumpto(Where,1); vedlineabove();
	elseif isstring(Where) then
		if Where = '@x' then
			vedswapfiles(); vedendfile();
		elseif Where(1) == `@` then
			vedlocate(allbutfirst(1, Where)); vedlineabove();
		else	;;; argument must have been file name
			ved_ved();	vedendfile();
		endif;
		vedlinebelow();
	else hi -> vedline;
		vedsetlinesize();
		unless vvedlinesize == 0 then vedlinebelow() endunless
	endif;
	unless vedline==1 then vedlinebelow() endunless;
	unless vedline >= vvedbuffersize then vedlinebelow(); vedcharup();
	endunless;
	;;; insert 'From ' line to conform to mail format.
	vedcheck();
	vedinsertstring('From '); vedinsertstring (sysgetusername(popusername));
	vedlinebelow();
	vedinsertstring('To: ');
	vedinsertstring(sender);
	Veddo('gsl/,@z//');		;;; remove trailing comma
	vedmarklo(); vedmarkhi();

	vedlinebelow(); vedinsertstring(subject);
	if Cc then
		;;; insert copy list
		vedlinebelow(); vedinsertstring(Cc); vedcharinsert(`,`);
		false -> vedediting;
		;;; now clean up junk and replace spaces with commas
		Veddo('gsl/ /,/');
		;;; get rid of redundant occurrences of hostname
		Veddo('gsl"@@'  sys_>< hostname sys_>< '.uucp,","');
		Veddo('gsl",'  sys_>< hostname sys_><'!","');
		Veddo('gsl"@@' sys_>< hostname sys_><',","');
		;;; Get rid of sender (already in To: line)
		Veddo('gsl",'  sys_>< sender  sys_><',","');
		;;; Get rid of oneself
		Veddo('gsl",' sys_>< popusername sys_>< ',","');
		while issubstring(',,', vedthisline()) do
			Veddo('gsl/,,/,/');
		endwhile;
		Veddo('gsl/,@z//');		;;; remove trailing comma
		Veddo('gsl/:,/: /');
		oldvedediting -> vedediting;
		;;; if nothing left, delete Cc: line
		if issubstring(vedthisline(), Ccstring) then vedlinedelete()
		else
			vedtextright(); vedcheck(); vedrefreshrange(vedline,vedline,undef);
		endif;
		vedcharup(); vedtextright()
	endif;
	if oldc then oldc + 1 else 1 endif -> vedchanged;
enddefine;

define vars ved_reply =
	veddoreply(%false%)
enddefine;

define vars ved_Reply =
	veddoreply(%true%)
enddefine;

endsection;


/* --- Revision History ---------------------------------------------------
--- Jonathan Meyer, Sep 29 1993
		Changed vvedsr*ch vars to ved_search_state.
--- John Williams, Jun  3 1992
		Fixed BR jamesg@cogs.susx.ac.uk.1 by renaming lvar -where-
		to -Where-
--- Aaron Sloman, May 29 1989
	Localised VED search state variables in veddoreply
--- Aaron Sloman, May 21 1989
	It occasionally merged To: line with Cc: line. Now fixed. Further
	Tidying and replaced :pdr_valof with new define syntax
--- Aaron Sloman, April 6 1989
	Changed to cope with more complex From:, To:, Cc: lines, and
		remove occurrences of popsitename more effectively
--- Aaron Sloman, Mar  5 1989
	Simplified vedgetsubject. Made it insert "Re:" after subject, if
	it isn't already there. Used pdr_valof

 */
