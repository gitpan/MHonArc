# $Id: Makefile,v 1.10 2002/05/03 04:12:38 ehood Exp $

.PHONY: default residx toc pagetocs buttons rcfileexs utildocs

TOP	  = ..

include $(TOP)/etc/variables.mk

TOCFILE	  = mhonarc.html
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

UTIL_PODS = \
	    $(TOP)/mha-dbedit \
	    $(TOP)/mha-dbrecover \
	    $(TOP)/mha-decode \
	    # End of UTIL_PODS

RCLIST	  = _helper/resource.lst
RCVARLIST = _helper/rcvars.lst


default: residx rcfileexs toc pagetocs buttons utildocs

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

utildocs: $(UTIL_PODS)
	-@$(RM) -f pod2htm*~~

$(UTIL_PODS): _force
	-@$(MKDIR) -p utils
	pod2html --header --infile=$@ \
		 --outfile=utils/$(notdir $@).html

clean:
	$(RM) -rf *.gml \
	          pod2htm*~~ \
		  utils

_force:

