##---------------------------------------------------------------------------##
##  File:
##	@(#) readmail.pl 2.14 01/11/13 23:08:32
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Library defining routines to parse MIME e-mail messages.  The
##	library is designed so it may be reused for other e-mail
##	filtering programs.  The default behavior is for mail->html
##	filtering, however, the defaults can be overridden to allow
##	mail->whatever filtering.
##
##	Public Functions:
##	----------------
##	$data 		= MAILdecode_1522_str($str);
##	($data, @files) = MAILread_body($fields_hash_ref, $body_ref);
##	$hash_ref 	= MAILread_file_header($handle);
##	$hash_ref 	= MAILread_header($mesg_str_ref);
##
##	($disp, $file)  = MAILhead_get_disposition($fields_hash_ref);
##	$boolean 	= MAILis_excluded($content_type);
##	$parm_hash_ref  = MAILparse_parameter_str($header_field);
##	$parm_hash_ref  = MAILparse_parameter_str($header_field, 1);
##
##---------------------------------------------------------------------------##
##    Copyright (C) 1996-2001	Earl Hood, mhonarc@mhonarc.org
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
##    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
##    02111-1307, USA
##---------------------------------------------------------------------------##

package readmail;

##---------------------------------------------------------------------------##
##	Scalar Variables
##

##  Variable storing the mulitple fields separator value for the
##  the read header routines.
##  DEPRECATED: NO LONGER USED BY ANY ROUTINES IN THIS LIBRARY.

$FieldSep	= "\034";

##  Flag if message headers are decoded in the parse header routines:
##  MAILread_header, MAILread_file_header.  This only affects the
##  values of the field hash created.  The original header is still
##  passed as the return value.
##
##  The only 1522 data that will be decoded is data encoded with charsets
##  set to "-decode-" in the %MIMECharSetConverters hash.

$DecodeHeader	= 0;

##---------------------------------------------------------------------------##
##	Variables for holding information related to the functions used
##	for processing MIME data.  Variables are defined in the scope
##	of main.

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMEDecoders is the associative array for storing functions for
##  decoding mime data.
##
##	Keys => content-transfer-encoding (should be in lowercase)
##	Values => function name.
##
##  Function names should be qualified with package identifiers.
##  Functions are called as follows:
##
##	$decoded_data = &function($data);
##
##  The value "as-is" may be used to allow the data to be passed without
##  decoding to the registered filter, but the decoded flag will be
##  set to true.

%MIMEDecoders			= ()
    unless defined(%MIMEDecoders);
%MIMEDecodersSrc		= ()
    unless defined(%MIMEDecodersSrc);

##	Default settings:
$MIMEDecoders{"7bit"}		  = "as-is"
    unless defined($MIMEDecoders{"7bit"});
$MIMEDecoders{"8bit"}		  = "as-is"
    unless defined($MIMEDecoders{"8bit"});
$MIMEDecoders{"binary"}		  = "as-is"
    unless defined($MIMEDecoders{"binary"});
$MIMEDecoders{"base64"}		  = "base64::b64decode"
    unless defined($MIMEDecoders{"base64"});
$MIMEDecoders{"quoted-printable"} = "quoted_printable::qprdecode"
    unless defined($MIMEDecoders{"quoted-printable"});
$MIMEDecoders{"x-uuencode"}	  = "base64::uudecode"
    unless defined($MIMEDecoders{"x-uuencode"});
$MIMEDecoders{"x-uue"}     	  = "base64::uudecode"
    unless defined($MIMEDecoders{"x-uue"});
$MIMEDecoders{"uuencode"}  	  = "base64::uudecode"
    unless defined($MIMEDecoders{"uuencode"});

$MIMEDecodersSrc{"base64"}	  	= "base64.pl"
    unless defined($MIMEDecodersSrc{"base64"});
$MIMEDecodersSrc{"quoted-printable"}	= "qprint.pl"
    unless defined($MIMEDecodersSrc{"quoted-printable"});
$MIMEDecodersSrc{"x-uuencode"}	 	= "base64.pl"
    unless defined($MIMEDecodersSrc{"x-uuencode"});
$MIMEDecodersSrc{"x-uue"}     	 	= "base64.pl"
    unless defined($MIMEDecodersSrc{"x-uue"});
$MIMEDecodersSrc{"uuencode"}  	 	= "base64.pl"
    unless defined($MIMEDecodersSrc{"uuencode"});

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMECharSetConverters is the associative array for storing functions
##  for converting data in a particular charset to a destination format
##  within the MAILdecode_1522_str() routine. Destination format is defined
##  by the function.
##
##	Keys => charset (should be in lowercase)
##	Values => function name.
##
##  Charset values take on a form like "iso-8859-1" or "us-ascii".
##              NOTE: Values need to be in lower-case.
##
##  The key "default" can be assigned to define the default function
##  to call if no explicit charset function is defined.
##
##  The key "plain" can be set to a function for decoded regular text not
##  encoded in 1522 format.
##
##  Function names are name of defined perl function and should be
##  qualified with package identifiers. Functions are called as follows:
##
##	$converted_data = &function($data, $charset);
##
##  A function called "-pass-:function" implies that the data should be
##  passed to the converter "function" but not decoded.
##
##  A function called "-decode-" implies that the data should be
##  decoded, but no converter is to be invoked.
##
##  A function called "-ignore-" implies that the data should
##  not be decoded and converted.  Ie.  For the specified charset,
##  the encoding will stay unprocessed and passed back in the return
##  string.

%MIMECharSetConverters			= ()
    unless defined(%MIMECharSetConverters);
%MIMECharSetConvertersSrc		= ()
    unless defined(%MIMECharSetConvertersSrc);

##	Default settings:
$MIMECharSetConverters{"default"}	= "-ignore-"
    unless defined($MIMECharSetConverters{"default"});

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMEFilters is the associative array for storing functions that
##  process various content-types in the MAILread_body routine.
##
##	Keys => Content-type (should be in lowercase)
##	Values => function name.
##
##  Function names should be qualified with package identifiers.
##  Functions are called as follows:
##
##	$converted_data = &function($header, *parsed_header_assoc_array,
##				    *message_data, $decoded_flag,
##				    $optional_filter_arguments);
##
##  Functions can be registered for base types.  Example:
##
##	$MIMEFilters{"image/*"} = "mypackage'function";
##
##  IMPORTANT: If a function specified is not defined when MAILread_body
##  tries to invoke it, MAILread_body will silently ignore.  Make sure
##  that all functions are defined before invoking MAILread_body.

%MIMEFilters	= ()
    unless defined(%MIMEFilters);
%MIMEFiltersSrc	= ()
    unless defined(%MIMEFiltersSrc);

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMEFiltersArgs is the associative array for storing any optional
##  arguments to functions specified in MIMEFilters (the
##  $optional_filter_arguments from above).
##
##	Keys => Either one of the following: content-type, function name.
##	Values => Argument string (format determined by filter function).
##
##  Arguments listed for a content-type will be used over arguments
##  listed for a function if both are applicable.

%MIMEFiltersArgs	= ()
    unless defined(%MIMEFiltersArgs);

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMEExcs is the associative array listing which data types
##  should be auto-excluded during parsing:
##
##	Keys => content-type, or base-type
##	Values => <should evaluate to a true expression>
##
##  For purposes of efficiency, content-types, or base-types, should
##  be specified in lowercase.  All key lookups are done in lowercase.

%MIMEExcs			= ()
    unless defined(%MIMEExcs);

##---------------------------------------------------------------------------
##	Variables holding functions for generating processed output
##	for MAILread_body().  The default functions generate HTML.
##	However, the variables can be set to functions that generate
##	a different type of output.
##
##	$FormatHeaderFunc has no default, and must be defined by
##	the calling program.
##
##  Function that returns a message when failing to process a part of a
##  a multipart message.  The content-type of the message is passed
##  as an argument.

$CantProcessPartFunc		= \&cantProcessPart
    unless(defined($CantProcessPartFunc));

##  Function that returns a message when a part is excluded via %MIMEExcs.

$ExcludedPartFunc	= \&excludedPart
    unless(defined($ExcludedPartFunc));

##  Function that returns a message when a part is unrecognized in a
##  multipart/alternative message.  I.e. No part could be processed.
##  No arguments are passed to function.

$UnrecognizedAltPartFunc	= \&unrecognizedAltPart
    unless(defined($UnrecognizedAltPartFunc));

##  Function that returns a string to go before any data generated generating
##  from processing an embedded message (message/rfc822 or message/news).
##  No arguments are passed to function.

$BeginEmbeddedMesgFunc		= \&beginEmbeddedMesg
    unless(defined($BeginEmbeddedMesgFunc));

##  Function that returns a string to go after any data generated generating
##  from processing an embedded message (message/rfc822 or message/news).
##  No arguments are passed to function.

$EndEmbeddedMesgFunc		= \&endEmbeddedMesg
    unless(defined($EndEmbeddedMesgFunc));

##  Function to return a string that is a result of the functions
##  processing of a message header.  The function is called for
##  embedded messages (message/rfc822 and message/news).  The
##  arguments to function are:
##
##   1.	Pointer to associative array representing message header
##	contents with the keys as field labels (in all lower-case)
##	and the values as field values of the labels.
##
##   2. Pointer to associative array mapping lower-case keys of
##	argument 1 to original case.
##
##  Prototype: $return_data = &function(*fields, *lower2orig_fields);

$FormatHeaderFunc		= undef
    unless(defined($FormatHeaderFunc));

###############################################################################
##	Public Routines							     ##
###############################################################################
##---------------------------------------------------------------------------##
##	MAILdecode_1522_str() decodes a string encoded in a format
##	specified by RFC 1522.  The decoded string is the return value.
##	If no MIMECharSetConverters is registered for a charset, then
##	the decoded data is returned "as-is".
##
##	Usage:
##
##	    $ret_data = &MAILdecode_1522_str($str, $justdecode);
##
##	If $justdecode is non-zero, $str will be decoded for only
##	the charsets specified as "-decode-".
##
sub MAILdecode_1522_str {
    my($str) = shift;
    my($justdecode) = shift;
    my($charset,
       $lcharset,
       $encoding,
       $dec,
       $charcnv,
       $defcharcnv,
       $plaincnv,
       $strtxt,
       $str_before);
    my($ret) = ('');

    $defcharcnv = '-bogus-';

    # Get default converter
    $defcharcnv = &load_charset('default');

    # Get plain converter
    $plaincnv = &load_charset('plain');
    $plaincnv = $defcharcnv  unless $plaincnv;

    # Decode string
    while ($str =~ /=\?([^?]+)\?(.)\?([^?]*)\?=/) {

	# Grab components
	($charset, $encoding) = ($1, $2);
	$strtxt = $3; $str_before = $`; $str = $';

	# Check encoding method and grab proper decoder
	if ($encoding =~ /b/i) {
	    $dec = &load_decoder('base64');
	} else {
	    $dec = &load_decoder('quoted-printable');
	}

	# Convert before (unencoded) text
	if ($justdecode) {				# ignore if just decode
	    $ret .= $str_before;
	} elsif (defined(&$plaincnv)) {			# decode and convert
	    $ret .= &$plaincnv($str_before,'');
	} elsif (($plaincnv =~ /-pass-:(.*)/) &&	# pass
		 (defined(&${1}))) {
	    $ret .= &${1}($str_before,'');
	} else {					# ignore
	    $ret .= $str_before;
	}

	# Convert encoded text
	($lcharset = $charset) =~ tr/A-Z/a-z/;
	$charcnv = &load_charset($lcharset);
	$charcnv = $defcharcnv  unless $charcnv;

	# Decode only
	if ($charcnv eq "-decode-") {
	    $strtxt =~ s/_/ /g;
	    $ret .= &$dec($strtxt);

	# Ignore if just decoding
	} elsif ($justdecode) {
	    $ret .= "=?$charset?$encoding?$strtxt?=";

	# Decode and convert
	} elsif (defined(&$charcnv)) {
	    $strtxt =~ s/_/ /g;
	    $ret .= &$charcnv(&$dec($strtxt),$lcharset);

	# Do not decode, but convert
	} elsif (($charcnv =~ /-pass-:(.*)/) &&
		 (defined(&${1}))) {
	    $ret .= &${1}($strtxt,$lcharset);

	# Fallback is to ignore
	} else {
	    $ret .= "=?$charset?$encoding?$strtxt?=";
	}
    }

    # Convert left-over unencoded text
    if ($justdecode) {				# ignore if just decode
	$ret .= $str;
    } elsif (defined(&$plaincnv)) {		# decode and convert
	$ret .= &$plaincnv($str,'');
    } elsif (($plaincnv =~ /-pass-:(.*)/) &&	# pass
	     (defined(&${1}))) {
	$ret .= &${1}($str,'');
    } else {					# ignore
	$ret .= $str;
    }

    $ret;
}

##---------------------------------------------------------------------------##
##	MAILread_body() parses a MIME message body.
##	Usage:
##	  ($data, @files) =
##	      MAILread_body($fields_hash_ref, $body_date_ref);
##
##	Parameters:
##	  $fields_hash_ref
##		      A reference to hash of message/part header
##		      fields.  Keys are field names in lowercase
##		      and values are array references containing the
##		      field values.  For example, to obtain the
##		      content-type, if defined, one would do:
##
##			$fields_hash_ref->{'content-type'}[0]
##
##		      Values for a fields are stored in arrays since
##		      duplication of fields are possible.  For example,
##		      the Received: header field is typically repeated
##		      multiple times.  For fields that only occur once,
##		      then array for the field will only contain one
##		      item.
##
##	  $body_data_ref
##		      Reference to body data.  It is okay for the
##		      filter to modify the text in-place.
##
##	Return:
##	  The first item in the return list is the text that should
##	  printed to the message page.	Any other items in the return
##	  list are derived filenames created.
##
##	See Also:
##	  MAILread_header(), MAILread_file_header()
##
sub MAILread_body {
    my($fields,		# Parsed header hash
       $body,		# Reference to raw body text
       $inaltArg) = @_; # Flag if in multipart/alternative

    my($type, $subtype, $boundary, $content, $ctype, $pos,
       $encoding, $decodefunc, $args, $part);
    my(@parts) = ();
    my(@files) = ();
    my(@array) = ();
    my $ret = "";

    ## Get type/subtype
    if (defined($fields->{'content-type'})) {
	$content = $fields->{'content-type'}->[0];
    }
    $content = 'text/plain'  unless $content;
    ($ctype) = $content =~ m%^\s*([\w-\./]+)%;	# Extract content-type
    $ctype =~ tr/A-Z/a-z/;			# Convert to lowercase
    if ($ctype =~ m%/%) {			# Extract base and sub types
	($type,$subtype) = split(/\//, $ctype, 2);
    } elsif ($ctype =~ /text/i) {
	$ctype = 'text/plain';
	$type = 'text';  $subtype = 'plain';
    } else {
	$type = $subtype = '';
    }

    ## Check if type is excluded
    if ($MIMEExcs{$ctype} || $MIMEExcs{$type}) {
	return (&$ExcludedPartFunc($ctype));
    }

    ## Load content-type filter
    if ( (!defined($filter = &load_filter($ctype)) || !defined(&$filter)) &&
	 (!defined($filter = &load_filter("$type/*")) || !defined(&$filter)) &&
	 (!$inaltArg &&
	  (!defined($filter = &load_filter('*/*')) || !defined(&$filter)) &&
	     $ctype !~ m^\bmessage/(?:rfc822|news)\b^i &&
	     $type  !~ /\bmultipart\b/) ) {
	warn qq|Warning: Unrecognized content-type, "$ctype", |,
	     qq|assuming "application/octet-stream"\n|;
	$filter = &load_filter('application/octet-stream');
    }

    ## Check for filter arguments
    $args = get_filter_args($ctype, "$type/*", $filter);

    ## Check encoding
    if (defined($fields->{'content-transfer-encoding'})) {
	$encoding = lc $fields->{'content-transfer-encoding'}[0];
	$encoding =~ s/\s//g;
	$decodefunc = &load_decoder($encoding);
    } else {
	$encoding = undef;
	$decodefunc = undef;
    }

    ## A filter is defined for given content-type
    if ($filter && defined(&$filter)) {
	## decode data
	if (defined($decodefunc)) {
	    if (defined(&$decodefunc)) {
		$decoded = &$decodefunc($$body);
		@array = &$filter($fields, \$decoded, 1, $args);
	    } else {
		@array = &$filter($fields, $body,
				  $decodefunc =~ /as-is/i, $args);
	    }
	} else {
	    @array = &$filter($fields, $body, 0, $args);
	}

	## Setup return variables
	$ret = shift @array;				# Return string
	push(@files, @array);				# Derived files

    ## No filter defined for given content-type
    } else {
	## If multipart, recursively process each part
	if ($type =~ /\bmultipart\b/i) {
	    local(%Cid) = ( )  unless scalar(caller) eq 'readmail';
	    my($isalt) = $subtype =~ /\balternative\b/i;

	    ## Get boundary
	    $boundary = "";
	    if ($content =~ m/boundary\s*=\s*"([^"]*)"/i) {
		$boundary = $1;
	    } else {
		($boundary) = $content =~ m/boundary\s*=\s*(\S+)/i;
		$boundary =~ s/;$//;  # chop ';' if grabbed
	    }

	    ## If boundary defined, split body into parts
	    if ($boundary =~ /\S/) {
		my $found = 0;
		my $start_pos = 0;
		substr($$body, 0, 0) = "\n";
		substr($boundary, 0, 0) = "\n--";
		my $blen = length($boundary);
		my $bchkstr;

		while (($pos = index($$body, $boundary, $start_pos)) > -1) {
		    # have to check for case when boundary is a substring
		    #	of another boundary, yuck!
		    $bchkstr = substr($$body, $pos+$blen, 2);
		    unless ($bchkstr =~ /\A\r?\n/ || $bchkstr =~ /\A--/) {
			# incomplete match, continue search
			$start_pos = $pos+$blen;
			next;
		    }
		    $found = 1;
		    if ($isalt) {
			# if alternative, do things in reverse
			unshift(@parts, substr($$body, 0, $pos));
			$parts[0] =~ s/^\r//;
		    } else {
			push(@parts, substr($$body, 0, $pos));
			$parts[$#parts] =~ s/^\r//;
		    }
		    # prune out part data just grabbed
		    substr($$body, 0, $pos+$blen) = "";

		    # check if hit end
		    last  if $$body =~ /\A--/;

		    # remove EOL at the beginning
		    $$body =~ s/\A\r?\n//;
		    $start_pos = 0;
		}
		if ($found) {
		    # discard front-matter
		    if ($isalt) { pop(@parts); } else { shift(@parts); }
		} else {
		    # no boundary separators in message!
		    warn qq/Warning: No boundaries found in message body\n/;
		    if ($$body =~ m/\A\n[\w\-]+:\s/) {
			# remove \n added above if part looks like it has
			# headers.  we keep if it does not to avoid body
			# data being parsed as a header below.
			substr($$body, 0, 1) = "";
		    }
		    push(@parts, $$body);
		}

	    ## Else treat body as one part
	    } else {
		@parts = ($$body);
	    }

	    ## Process parts
	    my(@entity) = ();
	    my($cid, $href);
	    @parts = \(@parts);
	    while (defined($part = shift(@parts))) {
		$href = { };
		$partfields = $href->{'fields'} = (MAILread_header($part))[0];
		$href->{'body'} = $part;
		$href->{'filtered'} = 0;
		push(@entity, $href);

		## only add to %Cid if not excluded
		if (!defined($partfields->{'content-type'}) ||
			!&MAILis_excluded($partfields->{'content-type'}[0])) {
		    $cid = $partfields->{'content-id'}[0] ||
			   $partfields->{'message-id'}[0];
		    if (defined($cid)) {
			$cid =~ s/[\s<>]//g;
			$Cid{"cid:$cid"} = $href  if $cid =~ /\S/;
		    }
		    if (defined($partfields->{'content-location'}) &&
			    ($cid = $partfields->{'content-location'}[0])) {
			$cid =~ s/^\s+//;
			$cid =~ s/\s+$//;
			if ($cid =~ /\S/ && !$Cid{$cid}) {
			    $Cid{$cid} = $href;
			}
		    }
		}
	    }

	    my($entity);
	    ENTITY: foreach $entity (@entity) {
		next  if $entity->{'filtered'};

		## If content-type not defined for part, then determine
		## content-type based upon multipart subtype.
		$partfields = $entity->{'fields'};
		if (!defined($partfields->{'content-type'})) {
		    $partfields->{'content-type'} =
		      [ ($subtype =~ /digest/) ?
			    'message/rfc822' : 'text/plain' ];
		}

		## Process part
		@array = MAILread_body(
			    $partfields,
			    $entity->{'body'},
			    $isalt);

		## Only use last filterable part in alternate
		if ($subtype =~ /alternative/) {
		    $ret = shift @array;
		    if ($ret) {
			push(@files, @array);
			$entity->{'filtered'} = 1;
			last ENTITY;
		    }
		} else {
		    if (!$array[0]) {
			$array[0] = &$CantProcessPartFunc(
					$partfields->{'content-type'}[0]);
		    }
		    $ret .= shift @array;
		}
		push(@files, @array);
		$entity->{'filtered'} = 1;
	    }

	    ## Check if multipart/alternative, and no success
	    if (!$ret && ($subtype =~ /alternative/)) {
		warn qq|Warning: No recognized part in multipart/alternative; |,
		     qq|will try to decode last part\n|;
		$entity = $entity[0];
		@array = &MAILread_body(
			    $entity->{'fields'},
			    $entity->{'body'});
		$ret = shift @array;
		if ($ret) {
		    push(@files, @array);
		} else {
		    $ret = &$UnrecognizedAltPartFunc();
		}
	    }

	## Else if message/rfc822 or message/news
	} elsif ($ctype =~ m^\bmessage/(?:rfc822|news)\b^i) {
	    $partfields = (MAILread_header($body))[0];

	    $ret = &$BeginEmbeddedMesgFunc();
	    if ($FormatHeaderFunc && defined(&$FormatHeaderFunc)) {
		$ret .= &$FormatHeaderFunc($partfields);
	    } else {
		warn "Warning: readmail: No message header formatting ",
		     "function defined\n";
	    }
	    @array = MAILread_body($partfields, $body);
	    $ret .= shift @array ||
			&$CantProcessPartFunc(
			    $partfields->{'content-type'}[0] || 'text/plain');
	    $ret .= &$EndEmbeddedMesgFunc();

	    push(@files, @array);

	## Else cannot handle type
	} else {
	    $ret = '';
	}
    }

    ($ret, @files);
}

##---------------------------------------------------------------------------##
##	MAILread_header reads (and strips) a mail message header from the
##	variable $mesg.  $mesg is a reference to the mail message in
##	a string.
##
##	$fields is a reference to a hash to put field values indexed by
##	field labels that have been converted to all lowercase.
##	Field values are array references to the values
##	for each field.
##
##	($fields_hash_ref, $header_txt) = MAILread_header($mesg_data);
##
sub MAILread_header {
    my($mesg) = shift;

    my $fields = { };
    my $label = '';
    my $header = '';
    my($value, $tmp, $pos);

    ## Read a line at a time.
    for ($pos=0; $pos >= 0; ) {
	$pos = index($$mesg, "\n");
	if ($pos >= 0) {
	    $tmp = substr($$mesg, 0, $pos+1);
	    substr($$mesg, 0, $pos+1) = "";
	    last  if $tmp =~ /^\r?$/;	# Done if blank line

	    $header .= $tmp;
	    chop $tmp;			# Chop newline
	    $tmp =~ s/\r$//;		# Delete <CR> characters
	} else {
	    $tmp = $$mesg;
	    $header .= $tmp;
	}

	## Decode text if requested
	$tmp = &MAILdecode_1522_str($tmp,1)  if $DecodeHeader;

	## Check for continuation of a field
	if ($tmp =~ s/^\s//) {
	    $fields->{$label}[-1] .= $tmp  if $label;
	    next;
	}

	## Separate head from field text
	if ($tmp =~ /^([^:\s]+):\s*([\s\S]*)$/) {
	    ($label, $value) = (lc($1), $2);
	    if ($fields->{$label}) {
		push(@{$fields->{$label}}, $value);
	    } else {
		$fields->{$label} = [ $value ];
	    }
	}
    }
    ($fields, $header);
}

##---------------------------------------------------------------------------##
##	MAILread_file_header reads (and strips) a mail message header
##	from the filehandle $handle.  The routine behaves in the
##	same manner as MAILread_header;
##
##	($fields_hash, $header_text) = MAILread_file_header($filehandle);
##	
sub MAILread_file_header {
    my($handle) = @_;
    my $label  = '';
    my $header = '';
    my $fields = { };
    local $/   = "\n";

    my($value, $tmp);
    while (($tmp = <$handle>) !~ /^[\r]?$/) {
	## Save raw text
	$header .= $tmp;

	## Delete eol characters
	$tmp =~ s/[\r\n]//g;

	## Decode text if requested
	$tmp = &MAILdecode_1522_str($tmp,1)  if $DecodeHeader;

	## Check for continuation of a field
	if ($tmp =~ s/^\s//) {
	    $fields->{$label}[-1] .= $tmp  if $label;
	    next;
	}

	## Separate head from field text
	if ($tmp =~ /^([^:\s]+):\s*([\s\S]*)$/) {
	    ($label, $value) = (lc($1), $2);
	    if (defined($fields->{$label})) {
		push(@{$fields->{$label}}, $value);
	    } else {
		$fields->{$label} = [ $value ];
	    }
	}
    }
    ($fields, $header);
}

##---------------------------------------------------------------------------##
##	MAILis_excluded() checks if specified content-type has been
##	specified to be excluded.
##
sub MAILis_excluded {
    my $content = $_[0] || 'text/plain';
    my($ctype) = $content =~ m|^\s*([\w-\./]+)|;
    $ctype =~ tr/A-Z/a-z/;
    if ($MIMEExcs{$ctype}) {
	return 1;
    }
    if ($ctype =~ m|([^/]+)/|) {
	return $MIMEExcs{$1};
    }
    0;
}

##---------------------------------------------------------------------------##
##	MAILhead_get_disposition gets the content disposition and
##	filename from $hfields, $hfields is a hash produced by the
##	MAILread_header and MAILread_file_header routines.
##
sub MAILhead_get_disposition {
    my($hfields) = shift;
    my($disp, $filename) = ('', '');
    local($_);

    if (defined($hfields->{'content-disposition'}) &&
	    ($_ = $hfields->{'content-disposition'}->[0])) {
	($disp)	= /^\s*([^\s;]+)/;
	if (/filename="([^"]+)"/i) {
	    $filename = $1;
	} elsif (/filename=(\S+)/i) {
	    ($filename = $1) =~ s/;\s*$//g;
	}
    }
    if (!$filename && defined($_ = $hfields->{'content-type'}[0])) {
	if (/name="([^"]+)"/i) {
	    $filename = $1;
	} elsif (/name=(\S+)/i) {
	    ($filename = $1) =~ s/;\s*$//g;
	}
    }
    $filename =~ s%.*[/\\:]%%;	# Remove any path component
    $filename =~ s/^\s+//;	# Remove leading whitespace
    $filename =~ s/\s+$//;	# Remove trailing whitespace
    ($disp, $filename);
}

##---------------------------------------------------------------------------##
##	MAILparse_parameter_str(): parses a parameter/value string.
##	Support for RFC 2184 extensions exists.  The $hasmain flag tells
##	the method if there is an intial main value for the sting.  For
##      example:
##
##          text/plain; charset=us-ascii
##      ----^^^^^^^^^^
##
##      The "text/plain" part is not a parameter/value pair, but having
##      an initial value is common among some header fields that can have
##      parameter/value pairs (egs: Content-Type, Content-Disposition).
##
##	Return Value:
##	    Reference to a hash.  Each key is the attribute name.
##	    The special key, 'x-main', is the main value if the
##	    $hasmain flag is set.
##
##	    Each hash value is a hash reference with three keys:
##	    'charset', 'lang', 'value'.  'charset' and 'lang' may be
##	    undef if character set or language information is not
##	    specified.
##
##	Example Usage:
##
##	    $content_type_field = 'text/plain; charset=us-ascii';
##	    $parms = MAILparse_parameter_str($content_type_field, 1);
##	    $ctype = $parms->{'x-main'};
##	    $mesg_body_charset = $parms->{'charset'}{'value'};
##
sub MAILparse_parameter_str {
    my $str     = shift;        # Input string
    my $hasmain = shift;        # Flag if there is a main value to extract

    require 'rfc822.pl';

    my $parm	= { };
    my(@toks)   = (rfc822::uncomment($str));
    my($tok, $name, $value, $charset, $lang, $part);

    $parm->{'x-main'} = shift @toks  if $hasmain;

    ## Loop thru token list
    while ($tok = shift @toks) {
        next if $tok eq ";";
        ($name, $value) = split(/=/, $tok, 2);
        ## Check if charset/lang specified
        if ($name =~ s/\*$//) {
            if ($value =~ s/^([^']*)'([^']*)'//) {
                ($charset, $lang) = ($1, $2);
            } else {
                ($charset, $lang) = (undef, undef);
            }
        }
        ## Check if parameter is only part
        if ($name =~ s/\*(\d+)$//) {
            $part = $1 - 1;     # we start at 0 internally
        } else {
            $part = 0;
        }
        ## Set values for parameter
        $name = lc $name;
        $parm->{$name} = {
            'charset'	=> $charset,
            'lang'   	=> $lang,
        };
        ## Check if value is next token
        if ($value eq "") {
            ## If value next token, than it must be quoted
            $value = shift @toks;
            $value =~ s/^"//;  $value =~ s/"$//;  $value =~ s/\\//g;
        }
        $parm->{$name}{'vlist'}[$part] = $value;
    }

    ## Now we loop thru each parameter and define the final values from
    ## the parts
    foreach $name (keys %$parm) {
	next  if $name eq 'x-main';
        $parm->{$name}{'value'} = join("", @{$parm->{$name}{'vlist'}});
    }

    $parm;
}

###############################################################################
##	Private Routines
###############################################################################

##---------------------------------------------------------------------------##
##	Default function for unable to process a part of a multipart
##	message.
##
sub cantProcessPart {
    my($ctype) = $_[0];
    warn "Warning: Could not process part with given Content-Type: ",
	 "$ctype\n";
    "<br><tt>&lt;&lt;&lt; $ctype: Unrecognized &gt;&gt;&gt;</tt><br>\n";
}
##---------------------------------------------------------------------------##
##	Default function returning message for content-types excluded.
##
sub excludedPart {
    my($ctype) = $_[0];
    "<br><tt>&lt;&lt;&lt; $ctype: EXCLUDED &gt;&gt;&gt;</tt><br>\n";
}
##---------------------------------------------------------------------------##
##	Default function for unrecognizeable part in multipart/alternative.
##
sub unrecognizedAltPart {
    warn "Warning: No recognizable part in multipart/alternative\n";
    "<br><tt>&lt;&lt;&lt; multipart/alternative: ".
    "No recognizable part &gt;&gt;&gt;</tt><br>\n";
}
##---------------------------------------------------------------------------##
##	Default function for beggining of embedded message
##	(ie message/rfc822 or message/news).
##
sub beginEmbeddedMesg {
qq|<blockquote><small>---&nbsp;<i>Begin&nbsp;Message</i>&nbsp;---</small>\n|;
}
##---------------------------------------------------------------------------##
##	Default function for end of embedded message
##	(ie message/rfc822 or message/news).
##
sub endEmbeddedMesg {
qq|<small>---&nbsp;<i>End Message</i>&nbsp;---</small></blockquote>\n|;
}

##---------------------------------------------------------------------------##

sub load_charset {
    require $MIMECharSetConvertersSrc{$_[0]}
	if defined($MIMECharSetConvertersSrc{$_[0]}) &&
	   $MIMECharSetConvertersSrc{$_[0]};
    $MIMECharSetConverters{$_[0]};
}
sub load_decoder {
    my $enc = lc shift; $enc =~ s/\s//;
    require $MIMEDecodersSrc{$enc}
	if defined($MIMEDecodersSrc{$enc}) &&
	   $MIMEDecodersSrc{$enc};
    $MIMEDecoders{$enc};
}
sub load_filter {
    require $MIMEFiltersSrc{$_[0]}
	if defined($MIMEFiltersSrc{$_[0]}) &&
	   $MIMEFiltersSrc{$_[0]};
    $MIMEFilters{$_[0]};
}
sub get_filter_args {
    my $args	= '';
    my $s;
    foreach $s (@_) {
	next  unless defined $s;
	$args = $MIMEFiltersArgs{$s};
	last  if defined($args) && ($args ne '');
    }
    $args;
}

##---------------------------------------------------------------------------##

sub dump_header {
    my $fh	= shift;
    my $fields	= shift;
    my($key, $a, $value);
    foreach $key (sort keys %$fields) {
	$a = $fields->{$key};
	if (ref($a)) {
	    foreach $value (@$a) {
		print $fh "$key: $value\n";
	    }
	} else {
	    print $fh "$key: $a\n";
	}
    }
}

##---------------------------------------------------------------------------##
1; # for require