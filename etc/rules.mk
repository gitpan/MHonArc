# $Id: rules.mk,v 1.2 2002/04/04 04:38:56 ehood Exp $
##-----------------------------------------------------------------------##
##  Common rules
##-----------------------------------------------------------------------##

ifeq ($(_rules_mk),)
_rules_mk:=1

.PHONY: perlsyntax make_subdirs

## Check syntax of perl source.
perl_syntax: $(PERL_FILES)

## Individual rules for each source file
$(PERL_FILES): _perl_force
	$(V)PERL5LIB="$(PERL_SEARCH_LIBS)" $(PERL) -cw $@

## Rules to invoke make on specified sub-directories.
make_subdirs: $(SUBDIRS)

$(SUBDIRS): _perl_force
	@$(MAKE) -w -C $@


## Bogus target to force execution of a rule
_perl_force:

## Default pattern rules
%.pm:
	PERL5LIB="$(PERL_SEARCH_LIBS)" $(PERL) -cw $@

%.pl:
	PERL5LIB="$(PERL_SEARCH_LIBS)" $(PERL) -cw $@


endif
# NOTHING GOES BELOW THIS LINE
