TOCFILE = mhonarc.html
HTMLFILES = intro.html \
	    relnotes.html \
	    install.html \
	    quickstart.html \
	    commontasks.html \
	    layout.html \
	    resources.html \
	    rcvars.html \
	    contacts.html \
	    app-rcidx.html \
	    app-rcfileexs.html \
	    app-diagnos.html \
	    app-utilsprg.html \
	    app-api.html \
	    app-mimeconf.html \
	    app-bugs.html \
	    # End of HTMLFILES

RCLIST = .src/resource.lst
RCVARLIST = .src/rcvars.lst

.PHONY: default residx toc pagetocs buttons rcfileexs

default: residx rcfileexs toc pagetocs buttons

residx:
	perl .src/addrcindex.pl $(RCLIST) resources.html app-rcidx.html

toc:
	perl .src/addtoc.pl $(TOCFILE) $(HTMLFILES)

pagetocs:
	perl .src/addtoc-i.pl $(HTMLFILES)

buttons:
	perl .src/addbuttons.pl $(HTMLFILES)

rcfileexs:
	perl .src/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/date.mrc > \
	    rcfileexs/date.mrc.html
	perl .src/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/def-mime.mrc > \
	    rcfileexs/def-mime.mrc.html
	perl .src/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/frames.mrc > \
	    rcfileexs/frames.mrc.html
	perl .src/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/icons.mrc > \
	    rcfileexs/icons.mrc.html
	perl .src/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/subject.mrc > \
	    rcfileexs/subject.mrc.html

clean:
	/bin/rm *.gml
