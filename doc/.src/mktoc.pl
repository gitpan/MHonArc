#!/usr/local/bin/perl -i
#
# 97/01/30 16:13:33

foreach $file (@ARGV) {
    open(FILE, $file) or die "Unable to open $file\n";

    print "<ul>\n";
    while (<FILE>) {
	chomp;
	next  unless m|<h1|i;
	($id) = m|name="(.*?)"|i;
	s|</?h\d.*?>||gi; s|</?a.*?>||gi;
	print qq{<li><a name="$id" href="$file">$_</a>\n<ul>\n};
	last;
    }
    while (<FILE>) {
	chomp;
	next  unless m|<h2|i;
	($id) = m|name="(.*?)"|i;
	s|</?h\d.*?>||gi; s|</?a.*?>||gi;
	print qq{<li><a name="$id" href="$file#$id">$_</a></li>\n};
    }
    print "</ul>\n</ul>\n";
}

exit 0;
