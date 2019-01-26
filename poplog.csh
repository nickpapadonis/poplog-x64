#!/bin/tcsh
# originally http://www.cs.bham.ac.uk/research/poplog/setup/bin/poplog
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
setenv poplogroot `pwd`
setenv usepop $poplogroot

# set the poplocal variables
setenv poplocal $poplogroot
setenv local $poplocal/local

# Run the initialisation files to set up additional environment
# variables, extend $PATH, etc. for csh/tcsh
source $usepop/pop/com/poplog

# (Optional)
# Set $EDITOR and $VISUAL, unless set by users. Users can undo this.

## UNCOMMENT THESE IF YOU WISH
## Make ved the default visual editor
## if (! $?EDITOR) setenv EDITOR ved
## if (! $?VISUAL) setenv VISUAL ved

## Check if user has a location for init.p, vedinit.p etc. and if not
## use a default location (MUST EXIST)

echo setting "poplib"

if ( $?poplib ) then

    if ( -d $poplib ) then

        # Then $poplib already set and is a directory: use it

        echo "use existing poplib set to $poplib"

        goto poplibset

    endif

endif

# $poplib not set

if (-d $HOME/Poplib) then

    ## echo set poplib to $HOME/Poplib

    setenv poplib $HOME/Poplib

else if ( -d $HOME/poplib ) then

    ## echo set poplib to $HOME/poplib

    setenv poplib $HOME/poplib

else if ( -f $HOME/vedinit.p ||  -f $HOME/init.p ) then

    ## echo set poplib to $HOME

    setenv poplib $HOME

else
    ## A place where local versions of init.p, vedinit.p init.lsp etc.
    ## can be located (Changed: A.Sloman 17 Jan 2005 )

    echo set poplib to the default: $usepop/Poplib

    setenv poplib $usepop/Poplib

endif

poplibset:

echo "poplib set to" $poplib

poplibset:

echo "poplib set to" $poplib


## New default
set usesetarch = false
#echo usesetarch  $usesetarch

# If sourced (with no arguments) do nothing, but leave environment
# variables set.
# If run with arguments, run the command given. Use exec to save a proces.

if ( "$*" != "") then

        exec $*

endif

poplibset:
echo "poplib set to" $poplib
