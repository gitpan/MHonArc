
.PHONY: default _force

PERL_FILES	= \
		  base64.pl \
		  ewhutil.pl \
		  iso2022jp.pl \
		  iso8859.pl \
		  mhamain.pl \
		  mhdb.pl \
		  mhdysub.pl \
		  mhexternal.pl \
		  mhfile.pl \
		  mhidxrc.pl \
		  mhindex.pl \
		  mhinit.pl \
		  mhlock.pl \
		  mhmimetypes.pl \
		  mhmsgextbody.pl \
		  mhmsgfile.pl \
		  mhnote.pl \
		  mhnull.pl \
		  mhopt.pl \
		  mhrcfile.pl \
		  mhrcvars.pl \
		  mhrmm.pl \
		  mhscan.pl \
		  mhsingle.pl \
		  mhthread.pl \
		  mhtime.pl \
		  mhtxtenrich.pl \
		  mhtxthtml.pl \
		  mhtxtplain.pl \
		  mhtxtsetext.pl \
		  mhtxttsv.pl \
		  mhusage.pl \
		  mhutil.pl \
		  osinit.pl \
		  qprint.pl \
		  readmail.pl \
		  rfc822.pl \
		  ## End of PERL_FILES

default: $(PERL_FILES)

$(PERL_FILES): _force
	perl -c $@


_force:

