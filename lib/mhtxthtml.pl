##---------------------------------------------------------------------------##
##  File:
##	@(#) mhtxthtml.pl 2.7 99/03/30 21:02:47
##  Author:
##      Earl Hood       earlhood@usa.net
##  Description:
##	Library defines routine to filter text/html body parts
##	for MHonArc.
##	Filter routine can be registered with the following:
##		<MIMEFILTERS>
##		text/html:m2h_text_html'filter:mhtxthtml.pl
##		</MIMEFILTERS>
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1995-1998	Earl Hood, earlhood@usa.net
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program; if not, write to the Free Software
##    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
##---------------------------------------------------------------------------##


package m2h_text_html;

# Beginning of URL match expression
my $Url	= '(\w+://|\w+:)';
# Script related attributes
my $SAttr = q/(?:onload|onunload|onclick|ondblclick|/.
	    q/onmouse(?:down|up|over|move|out)|/.
	    q/onkey(?:press|down|up))/;

##---------------------------------------------------------------------------
##	The filter must modify HTML content parts for merging into the
##	final filtered HTML messages.  Modification is needed so the
##	resulting filtered message is valid HTML.
##
##	Arguments:
##
##	noscript	Remove any markup associated with scripting.
##			This includes elements and attributes related
##			to scripting.
##
sub filter {
    local($header, *fields, *data, $isdecode, $args) = @_;
    local(@files) = ();	# !!!Used by resolve_cid!!!
    my $base 	 = '';
    my $title	 = '';
    my $noscript = $args =~ /\bnoscript\b/i;
    my $tmp;

    ## Get/remove title
    if ($data =~ s|<title\s*>([^<]*)</title\s*>||io) {
        $title = "<ADDRESS>Title: <STRONG>$1</STRONG></ADDRESS>\n";
    }
    ## Get/remove BASE url
    BASEURL: {
	if ($data =~ s|(<base\s[^>]*>)||i) {
	    $tmp = $1;
	    if ($tmp =~ m|href\s*=\s*['"]([^'"]+)['"]|i) {
		$base = $1;
	    } elsif ($tmp =~ m|href\s*=\s*([^\s>]+)|i) {
		$base = $1;
	    }
	    last BASEURL  if ($base =~ /\S/);
	} 
	if ((defined($tmp = $fields{'content-base'}) ||
	     defined($tmp = $fields{'content-location'})) && ($tmp =~ m%/%)) {
	    ($base = $tmp) =~ s/['"\s]//g;
	}
    }
    $base =~ s|(.*/).*|$1|;

    ## Strip out certain elements/tags to support proper inclusion
    $data =~ s|<!doctype\s[^>]*>||io;
    $data =~ s|</?html[^>]*>||gio;
    $data =~ s|<head\s*>[\s\S]*</head\s*>||io;

    ## Strip out scripting markup if requested
    if ($noscript) {
	$data =~ s|<script[^>]*>.*?</script\s*>||gios;
	$data =~ s|\b$SAttr\b\s*=\s*"[^"]*"||gio;
	$data =~ s|\b$SAttr\b\s*=\s*'[^']*'||gio;
	$data =~ s|\b$SAttr\b\s*=\s*[^\s>]+||gio;
	$data =~ s|</?applet[^>]*>||gio;
	$data =~ s|</?param[^>]*>||gio;
    }

    ## Check for body attributes
    if ($data =~ s|<body\b([^>]*)>||i) {
	require 'mhutil.pl';
	my $a = $1;
	my %attr = mhonarc::parse_vardef_str($a, 1);
	if (%attr) {
	    ## Use a table with a single cell to encapsulate data to
	    ## set visual properties.  We use a mixture of old attributes
	    ## and CSS to set properties since browsers may not support
	    ## all of the CSS settings via the STYLE attribute.
	    my $tpre = '<TABLE><TR><TD ';
	    my $tsuf = "";
	    $tpre .= qq|BACKGROUND="$attr{'background'}" |
		     if $attr{'background'};
	    $tpre .= qq|BGCOLOR="$attr{'bgcolor'}" |
		     if $attr{'bgcolor'};
	    $tpre .= qq|STYLE="|;
	    $tpre .= qq|background-color: $attr{'bgcolor'}; |
		     if $attr{'bgcolor'};
	    if ($attr{'background'}) {
		if ($attr{'background'} =~ s/^cid://i) {
		    $attr{'background'} = &resolve_cid($attr{'background'});
		} else {
		    $attr{'background'} = &addbase($base, $attr{'background'});
		}
		$tpre .= qq|background-image: url($attr{'background'}) |;
	    }
	    $tpre .= qq|color: $attr{'text'}; |
		     if $attr{'text'};
	    $tpre .= qq|A:link { color: $attr{'link'} } |
		     if $attr{'link'};
	    $tpre .= qq|A:active { color: $attr{'alink'} } |
		     if $attr{'alink'};
	    $tpre .= qq|A:visited { color: $attr{'vlink'} } |
		     if $attr{'vlink'};
	    $tpre .= '">';
	    if ($attr{'text'}) {
		$tpre .= qq|<FONT COLOR="$attr{'text'}">|;
		$tsuf .= '</FONT>';
	    }
	    $tsuf .= '</TD></TR></TABLE>';
	    $data = $tpre . $data . $tsuf;
	}
    }
    $data =~ s|</?body[^>]*>||ig;

    ## Modify relative urls to absolute using BASE
    if ($base =~ /\S/) {
        $data =~ s/((?:href|src|background)\s*=\s*['"])([^'"]+)(['"])/
		   join("", $1, &addbase($base,$2), $3)/geix;
    }

    ## Check for CID URLs (multipart/related HTML)
    $data =~ s/((?:href|src|background)\s*=\s*['"])cid:([^'"]+)(['"])/
	       join("", $1, &resolve_cid($2), $3)/geix;
    $data =~ s/((?:href|src|background)\s*=\s*)cid:([^\s>]+)/
	       join("", $1, '"', &resolve_cid($2), '"')/geix;

    ($title.$data, @files);
}

##---------------------------------------------------------------------------

sub addbase {
    my($b, $u) = @_;
    my($ret);
    $u =~ s/^\s+//;
    if ($u =~ m%^$Url%o || $u =~ m/^#/) {
	## Absolute URL or scroll link; do nothing
        $ret = $u;
    } else {
	## Relative URL
	if ($u =~ /^\./) {
	    ## "./---" or "../---": Need to remove and adjust base
	    ## accordingly.
	    $b =~ s/\/$//;
	    my @a = split(/\//, $b);
	    my $cnt = 0;
	    while ($u =~ s|^(\.{1,2})/||) { ++$cnt  if length($1) == 2; }
	    splice(@a, -$cnt)  if $cnt > 0;
	    $b = join('/', @a, "");

	} elsif ($u =~ m%^/%) {
	    ## "/---": Just use hostname:port of base.
	    $b =~ s%^(${Url}[^/]*)/.*%$1%o;
	}
        $ret = $b . $u;
    }
    $ret;
}

##---------------------------------------------------------------------------

sub resolve_cid {
    my $cid = shift;
    my $href = $readmail::Cid{$cid};
    if (!defined($href)) { return "cid:$cid"; }

    require 'mhmimetypes.pl';
    my $filename;
    my $decodefunc =
	readmail::load_decoder($href->{'fields'}{'content-transfer-encoding'});
    if (defined($decodefunc) && defined(&$decodefunc)) {
	my $data = &$decodefunc($href->{'body'});
	$filename = mhonarc::write_attachment(
			    $href->{'fields'}{'content-type'}, \$data);
    } else {
	$filename = mhonarc::write_attachment(
			    $href->{'fields'}{'content-type'},
			    \$href->{'body'});
    }
    $href->{'filtered'} = 1;
    push(@files, $filename); # @files defined in filter
    $filename;
}

##---------------------------------------------------------------------------

1;
