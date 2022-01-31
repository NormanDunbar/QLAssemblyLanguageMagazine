#!/bin/bash

#===================================================================
# Execute this in the Content directory to export all lyx files to
# pdflatex and then to run the tex_stripper on them ready to be used
# to build tha magazine.
#
# Norman Dunbar
# 28 January 2022.
#===================================================================

lyx -batch --export pdflatex --force-overwrite all *.lyx
for x in *.tex
do
    echo ${x}
    ./texStripper.sh ${x}
done

