Poplog
======
This is currently a partially functional Poplog environment
for Debian and other Linux x64 varients based on source and
documentation from:
[University of Sussex UK] (http://www.cs.bham.ac.uk/research/projects/poplog/freepoplog.html)

Building Poplog Environment
===========================
This script downloads all the prerequisites required on Debian 9 x64.
sudo ./debian-prep

The following command builds 'pop11'.  I tested 'pop11' and it has the new date.  This binary is per Waldek's comments, with only -core functionality and possibly remaining 64 int fixes to apply.

./build

Setup the environment for poplog:
source ./popenv

Invoke
"pop11" it will be in the path.

pop11 is located in ./pop/pop

Setup the environment for a build of poplog and modifications:
source ./popenv-build
