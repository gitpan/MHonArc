#!/usr/local/bin/perl
#
# 97/02/05 17:51:22

select(STDOUT);
print <<EndOfText;
<table border=0 cellpadding=5>
<tbody>
<tr>
<td colspan=3><hr></td>
</tr>
EndOfText

@rcs = ();
while (<>) {
    chop;
    s/:.*//;
    push(@rcs, $_);
}

while (scalar(@rcs)) {
    @c = splice(@rcs, 0, 3);
    @C = (uc $c[0], uc $c[1], uc $c[2]);
    print "<tr>\n";
    print "<td>";
    print qq{<a name="$c[0]" href="resources/$c[0].html">$C[0]</a>}
	if $c[0];
    print "</td>\n";
    print "<td>";
    print qq{<a name="$c[1]" href="resources/$c[1].html">$C[1]</a>}
	if $c[1];
    print "</td>\n";
    print "<td>";
    print qq{<a name="$c[2]" href="resources/$c[2].html">$C[2]</a>}
	if $c[2];
    print "</td>\n";
    print "</tr>\n";
}

print <<EndOfText;
<tr>
<td colspan=3><hr></td>
</tr>
</tbody>
</table>
EndOfText
