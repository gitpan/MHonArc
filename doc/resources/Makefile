# $Date: 2002/03/30 08:56:43 $ 

# Where doc scripts are located
SCRIPT_DIR  = ../_helper
# Root of mhonarc source
MHA_SRC_DIR = ../..

RCLIST	   = $(SCRIPT_DIR)/resource.lst
VARLIST    = $(SCRIPT_DIR)/rcvars.lst
MKTMPLPL   = $(SCRIPT_DIR)/mkrestmpl.pl
ADDVARPL   = $(SCRIPT_DIR)/addvartbls.pl
ADDCTYPEPL = $(SCRIPT_DIR)/addctypetbl.pl
MHAEXTPL   = $(MHA_SRC_DIR)/lib/mhmimetypes.pl

.PHONY: _FORCE

# Pattern rule for HTML files in this directory.
%.html: _FORCE
	perl $(ADDVARPL) $(RCLIST) $(VARLIST) $@

# Default rule checks if any new resources exist and to create template
# documentation page for any new resources.
default:
	perl $(MKTMPLPL) $(RCLIST)

# Add resource variable tables.
addvars:
	perl $(ADDVARPL) $(RCLIST) $(VARLIST) *.html

# Update content-type list for m2hexternal filter.
filters:
	perl $(ADDCTYPEPL) $(MHAEXTPL) mimefilters.html

# Bogus target to force a target to be updated.
_FORCE:
