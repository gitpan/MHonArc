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

RCLIST = _helper/resource.lst
RCVARLIST = _helper/rcvars.lst

.PHONY: default residx toc pagetocs buttons rcfileexs

default: residx rcfileexs toc pagetocs buttons

residx:
	perl _helper/addrcindex.pl $(RCLIST) resources.html app-rcidx.html

toc:
	perl _helper/addtoc.pl $(TOCFILE) $(HTMLFILES)

pagetocs:
	perl _helper/addtoc-i.pl $(HTMLFILES)

buttons:
	perl _helper/addbuttons.pl $(HTMLFILES)

rcfileexs:
	-@mkdir rcfileexs
	perl _helper/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/date.mrc > \
	    rcfileexs/date.mrc.html
	perl _helper/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/def-mime.mrc > \
	    rcfileexs/def-mime.mrc.html
	perl _helper/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/frames.mrc > \
	    rcfileexs/frames.mrc.html
	perl _helper/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/icons.mrc > \
	    rcfileexs/icons.mrc.html
	perl _helper/ppeg.pl $(RCLIST) $(RCVARLIST) ../examples/subject.mrc > \
	    rcfileexs/subject.mrc.html

clean:
	/bin/rm *.gml
