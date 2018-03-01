==============================
QL Assembly Language eMagazine
==============================

This repository is the home of the somewhat irregular QL Assembly Language eMagazine which I produce from time to time, as time allows.

You can find all the source for the magazines here, and if I ever get enough time, I'll add in the actual source code for the listings too. Mind you, that spoils the fun of typing it in, fixing typos and *learning* doesn't it?

Structure
=========

The repository is laid out as follows:

Common
------

The Common directory is where I keep the pretty much unchanging files. In here we have:

*   bibliography.bib - The bibliography file, currently this is not used as the eMagazine doesn't have a bibliography *yet*!
*   HTMLColours.tex - Defines a whole load of W3C standard HTML colour names. May be used to alter the colour theme of the finished eMagazine.
*   macros.tex - Some macros for settings etc.
*   structure.tex - Defines the entire structure of the eMagazine. Best not to play with this file, get it wrong and we are toast!
*   StyleInd.ist - Used to style the index. Which are not used at present.
*   Preface.tex - Some words of mine that go at the front of every issue.
*   Pictures - A directory containing images used for the front cover and the chapter heading pages. Only ``ChapterImage.jpg`` and ``CoverImage.jpg`` are used.

Issue_nnn
---------

There are code files for the individual issues in these directories. The files are:

*   Assembly_Language_nnn.tex - The top level, master document. This pulls in everything required to build an eMagazine.
*   Assembly_Language_nnn.pdf - The generated eMagazine.
*   config.tex - Defines settings for the generated PDF file, plus titles etc.
*   includeContents.tex - Read by the master document, and pulls in the various chapters from the Content directory.
*   Content - A directory where the individual chapter files can be found. It also contains an ``images`` folder, which is no longer used.
*   images - A directory which holds any images that are used in this issue only.

Cheers,
Norm.
