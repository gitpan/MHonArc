# 98/02/18 18:56:11

TOCFILE = faq.html
HTMLFILES = \
	    about.html \
	    general.html \
	    envs.html \
	    usage.html \
	    archives.html \
	    indexpgs.html \
	    msgpgs.html \
	    threads.html \
	    mime.html \
	    # End of files

default: addbuttons pagetocs toc

addbuttons:
	perl .src/addbuttons.pl $(HTMLFILES)

pagetocs:
	perl .src/addtoc-i.pl $(HTMLFILES)

toc:
	perl .src/addtoc.pl $(TOCFILE) $(HTMLFILES)

clean:
	/bin/rm -f *.tmp *.gml
