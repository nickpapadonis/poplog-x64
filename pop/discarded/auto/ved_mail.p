/* --- Copyright University of Sussex 1991.  All rights reserved. ---------
 > File:           C.unix/lib/ved/ved_mail.p
 > Purpose:		   Read mail in VED on unix systems
 > Author:         Aaron Sloman, Nov  8 1986 (see revisions)
 > Documentation:  HELP * VED_MAIL *VED_REPLY, *VED_MDIR, *VED_SEND
 > Related Files:  LIB * VED_SEND
 */
compile_mode :pop11 +strict;

/*
This is a simple mail reading facility based on VED.
Quick and easy, and generally faster than unix mail, but you have to mark
range and ENTER sendmr to do replies, etc. Original and reply then left in
same file for future reference, unless moved. Facilities are provided
for manipulating current message, replying, etc.

<ENTER> mail
  If there is new mail waiting in system mail box then:
	1. reads in the user's mail file defined in environment variable
		$MYMAIL, or else ~/mymail
	2. goes to end of file
	3. appends user's system mail file to this (e.g. /usr/spool/mail/<name>)
	4. truncates system mail file to 0, unless its size has increased.
	5. writes current file to disk for safety
	5.a. if 5 causes an error -e.g. disk over quota- then write to a /tmp file
	6. leaves you at the beginning of the new mail

 otherwise asks if you want to read old mail. Reply with `y` or `n`
 in three sections - otherwise defaults to `n`.

See also LIB * VED_MDIR  LIB * VED_REPLY   LIB * VED_MCM  LIB * VED_SEND
*/

include sysdefs.ph;		;;; to locate the default mail directory

section;

;;; @@@@@@@ N.B. This assignment may need to be changed @@@@@@@

global vars sys_mail_dir;
unless isstring(sys_mail_dir) then
#_IF DEF BERKELEY
	'/usr/spool/mail/'
#_ELSE
	'/usr/mail/'
#_ENDIF
	 -> sys_mail_dir
endunless;

lvars last_mail_size=0;
lconstant sizevec=initv(1);

define ved_mail_waiting -> mailfile;
	;;; if there's mail waiting, return pathname for the file, or false
	lvars mailfile = systranslate('MAIL');
	unless mailfile then
		;;; Check system mail file
		sys_mail_dir dir_>< popusername -> mailfile;
	endunless;
	;;; check if it exists, and is non-empty
	if sys_file_stat(mailfile, sizevec) and sizevec(1) > 0 then
			sizevec(1) -> last_mail_size;
	else
		false -> mailfile
	endif
enddefine;

define ved_mail_file -> file;
	lvars file;
	;;; get name of file for user's mail
	systranslate('$MYMAIL') -> file;
	unless file then sysfileok('$HOME/mymail') -> file; endunless;
enddefine;

define vars ved_mail;
	;;; Mail reader for new mail. Append system mail file to user's file.
	dlocal pop_file_versions, vedediting, vednotabs,
		 vedargument,pop_file_mode=8:600;
	lvars mailfile oldversions=pop_file_versions,c;
	;;; wasediting=vedediting;

	ved_mail_file() -> vedargument;
	ved_mail_waiting() -> mailfile;
	if mailfile then
		if vedediting and not(vedusewindows) and vedwindowlength > vedstartwindow
		and vedargument /= vedpathname
		then
			vedsetwindow()
		endif;
		;;; read it into ved - invisibly
		vedputmessage('PLEASE WAIT');
		if vedinvedprocess then false -> vedediting endif;
		;;; get user's mail file
		vedsetonscreen(vedopen(vedargument), nullstring);
		false -> ved_on_status;
		if vvedbuffersize > 0 then
			vedendfile();
			vedlinebelow();
		endif;
		;;;wasediting -> vedediting;
		true -> vedediting;
		;;; put cursor near middle of window
		max(0,vedline - (vedwindowlength >> 1)) -> vedlineoffset;
		vedrefresh();
		;;; read in system mail file
		mailfile -> vedargument;
		false -> vednotabs;	;;; don't lose tabs
		ved_r();

		if sys_file_stat(mailfile, sizevec)
		and sizevec(1) > last_mail_size then
			vedputmessage('NEW MAIL HAS COME - LEAVING SYSTEM MAIL FILE');
			;;; pause to show it
			syssleep(100)
		else
			;;; delete system file
			0 -> pop_file_versions;			;;; no backup files in system dir
			discout(mailfile)(termin);

			oldversions -> pop_file_versions;
		endif;

		;;; in case saving buffer fails
		define dlocal prmishap(string,list);
			;;; save file in /tmp. Ensure user sees message
			lvars string, list, file=systmpfile(false,popusername,'save');
			true -> vedediting;
			vedwriterange(1,vvedbuffersize,file);
			vedlineabove();
			;;; write error message in file
			vedinsertstring(string sys_>< list);
			vedlinebelow();
			'MAIL SAVED IN ' sys_>< file -> string;
			vedinsertstring(string);
			vedchardown(); vedchardown();
			vederror(string)
		enddefine;

		;;; save the buffer immediately.
		ved_w1();
		vedlocate('@?');

	else
		vedputmessage('NO NEW MAIL - read old mail? y/n:');
		charin_timeout(300) -> c;
		if c and strmember(c,'yY') then
			ved_ved();	;;; read old mail
		endif;
	endif;
enddefine;


define vars syntax mail;
	unless isboolean(vedprintingdone) then false -> vedprintingdone endunless;
	vedsetup();     ;;; make sure everything is initialised.
	ved_save_file_globals();
	;;; run ved_mail on startup
	vedinput(procedure();
				ved_mail();
			endprocedure);
	chain(ved_mail_file(), vededit);
enddefine;

endsection;

/* --- Revision History ---------------------------------------------------
--- John Gibson, Jun  5 1991
		Uses vedusewindows, vedinvedprocess
--- Aaron Sloman, Jul  9 1990
	Prevent re-sizing of window if vedusepw*mwindows isnt false.
--- Rob Duncan, Apr  5 1989
	Added "uses sysdefs" and replaced test `sys_os_type(2) == "bsd"' with
	`DEF BERKELEY';
	added -string- and -list- to lvars list in -prmishap-
--- Aaron Sloman, Jan 14 1989
	removed vednullstring
--- Aaron Sloman, Jan 13 1989
	Altered to see if $MAIL is set. If so reads from there.
--- Aaron Sloman, Jan  8 1989
	Made ved_mail_waiting use dir_><
--- Aaron Sloman, Apr  2 1988
	I had made a mistake in ved_mail_waiting. Now fixed. Also added
	call of syssleep when mail file is not being zeroed.

--- Aaron Sloman, Apr  2 1988
	Changed to check sys_os_type(2) instead of sys_os_type(3).(Fault
	reported by Antony Worrall.

	Also introduced global variable sys_mail_dir, making it easier for
	users if system mail stored elsewhere.

	Two procedures made accessible to users: ved_mail_waiting and
	ved_mail_file.

--- Aaron Sloman, Jul 10 1987
	Made sure not on status file before calling ved_r
--- Aaron Sloman, Nov 23 1986
	Altered not to truncate system mail file if it has grown after reading.
	Occasionally this will mean getting messages twice - better than
	losing mail, since user programs cannot operate mail locks.
*/
