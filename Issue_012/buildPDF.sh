#!/bin/bash

#-------------------------------------------------------------
# A script to build a PDF version of the eMagazine.
#
# Norman Dunbar
# 30 June 2022.
#-------------------------------------------------------------

cd Content
./export_for_magazine.sh
cd ..

pdflatex Assembly_Language*.tex
pdflatex Assembly_Language*.tex
pdflatex Assembly_Language*.tex


