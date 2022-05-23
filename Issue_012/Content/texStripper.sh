#!/bin/bash

#-------------------------------------------------------------
# A small script to strip the Lyx generated Tex files of the
# stuff we don;t need for a chapter file. This script uses sed
# to remove all lines up to and including \begin{document} and
# also the final \end{document} line.
#
# This leaves just the \chapter{...} lines and this is all we
# need when writing chapters.
#
# In case anything goes horribly wrong, you can generate the
# chapter again from Lyx, or, use the backup taken by sed
# with has the .sed.bkp extension.
#
#
# Norman Dunbar
# 22nd February 2021
#-------------------------------------------------------------
# ./texStripper.sh chapter.tex
#-------------------------------------------------------------

# Got any parameters? Got too many parameters?
if [ $# != 1 ]; then
	echo "USAGE: ./textStripper.sh input.tex"
	exit 1
fi

# We have one parameter. Is it a file we can process?
# It may already have been done.
grep -i -n  "^\\\\begin{document}$" "${1}"

if [ $? != 0 ]; then
	echo "${1} may have been processed already."
	echo "No \\begin{document} found."
	exit 1
fi

# Now we can process the file.
sed -i.sed.bkp -f sed.commands "${1}"

