# 97/03/03 15:58:47

default:
	chmod a+x *.pl

restbl:
	perl mkrestbl.pl resource.lst > restbl.html

ctypetbl:
	perl dumpctypes.pl 1>ctypes.tmp 2>&1
	perl mkctypetbl.pl ctypes.tmp > ctypetbl.gml

vim:
	perl addvimtags.pl resource.lst ../../examples/mhonarc.vim

clean:
	/bin/rm -f *.tmp *.gml
