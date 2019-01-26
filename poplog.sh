#!/bin/sh
# originally http://www.cs.bham.ac.uk/research/poplog/setup/bin/poplog.sh
# Script which sets up poplog environment variables, and then runs
# The command given as argument (e.g. pop11, xved, clisp, etc.)
# Aaron Sloman
# 17 Sep 2000
#
# 9 Jun 2018
# Provisionally updated for 64 bit poplog
# See also the poplogmail script

# Please edit the "setenv" line to suit your installation

## This could be a "poplog" shell script, as described in the man file
## It can be invoked with commands such as
##    poplog pop11
##    poplog ved
##    poplog xved <file>
##    poplog prolog
##    poplog clisp
##    poplog pml
##    poplog pop11 +eliza

# setup local directory tree for poplog root
# may be a symbolic link to something else

#poplogroot=/mnt/a6/kompi/poplog/pp3
poplogroot=`pwd`

usepop=$poplogroot

# set the poplocal variables
poplocal=$poplogroot
local=$poplocal/local

# Run the initialisation files to set up additional environment
# variables, extend $PATH, etc.
source $usepop/pop/com/poplog.sh

# (Optional)
# Set $EDITOR and $VISUAL, unless set by users. Users can undo this.


# If sourced with no arguments do nothing, but leave environment
# variables set. Otherwise run the command given.

#if ($?DISPLAY) xrdb -merge $poplocal/local/setup/Poplib/Xdefaults.poplog

if [ -d ~/Poplib ] ; then
    poplib=~/Poplib :
else
    poplib=$poplocal/local/setup/Poplib :
fi
export poplocal poplib poplogroot local usepop

# If no arguments given, just do nothing, otherwise run the program
if [ "x$*" != "x" ] ; then
#        echo PATH=$PATH
        exec "$@"
fi
