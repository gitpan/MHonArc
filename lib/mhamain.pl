##---------------------------------------------------------------------------##
##  File:
##	$Id: mhamain.pl,v 2.44 2002/07/18 21:54:52 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Main library for MHonArc.
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1995-2001	Earl Hood, mhonarc@mhonarc.org
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

package mhonarc;

require 5;

$VERSION = "2.5.9";
$VINFO =<<EndOfInfo;
  MHonArc v$VERSION (Perl $] $^O)
  Copyright (C) 1995-2002  Earl Hood, mhonarc\@mhonarc.org
  MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
  under the terms of the GNU General Public License, which may be found in
  the MHonArc distribution.
EndOfInfo

$CODE		= 0;
$ERROR  	= "";
@OrgARGV	= ();
$ArchiveOpen	= 0;

$_msgid_cnt	= 0;

my %_sig_org	= ();
my @_term_sigs	= qw(
    ABRT ALRM BUS FPE HUP ILL INT IOT PIPE POLL PROF QUIT SEGV
    TERM TRAP USR1 USR2 VTALRM XCPU XFSZ
);


###############################################################################
##	Public routines
###############################################################################

##---------------------------------------------------------------------------
##	initialize() does some initialization stuff.  Should be called
##	right after mhamain.pl is called.
##
sub initialize {
    ##	Turn off buffered I/O to terminal
    my($curfh) = select(STDOUT);  $| = 1;  select($curfh);

    ##	Check what system we are executing under
    require 'osinit.pl';  &OSinit();

    ##	Require essential libraries
    require 'mhlock.pl';
    require 'mhopt.pl';

    ##	Init some variables
    $ISLOCK     = 0;	# Database lock flag

    $StartTime	= 0;	# CPU start time of processing
    $EndTime	= 0;	# CPU end time of processing
}

##---------------------------------------------------------------------------
##	open_archive opens the archive
##
sub open_archive {
    eval { $StartTime = (times)[0]; };

    ## Set @ARGV if options passed in
    if (@_) { @OrgARGV = @ARGV; @ARGV = @_; }

    ## Get options
    my($optstatus);
    eval {
	set_handler();
	$optstatus = get_resources();
    };

    ## Check for error
    if ($@ || $optstatus <= 0) {
	if ($@) {
	    if ($@ =~ /signal caught/) {
		$CODE = 0;
	    } else {
		$CODE = int($!) ? int($!) : 255;
	    }
	    $ERROR = $@;
	    warn "\n", $ERROR;

	} else {
	    if ($optstatus < 0) {
		$CODE = $! = 255;
		$ERROR = "ERROR: Problem loading resources\n";
	    } else {
		$CODE = 0;
	    }
	}
	close_archive();
	return 0;
    }
    $ArchiveOpen = 1;
    1;
}

##---------------------------------------------------------------------------
##	close_archive closes the archive.
##
sub close_archive {
    my $reset_sigs = shift;

    ## Remove lock
    &$UnlockFunc()  if defined(&$UnlockFunc);

    ## Reset signal handlers
    reset_handler()  if $reset_sigs;

    ## Stop timing
    eval { $EndTime = (times)[0]; };
    my $cputime = $EndTime - $StartTime;

    ## Output time (if specified)
    if ($TIME) {
	printf(STDERR "\nTime: %.2f CPU seconds\n", $cputime);
    }

    ## Restore @ARGV
    if (@OrgARGV) { @ARGV = @OrgARGV; }

    $ArchiveOpen = 0;

    ## Return time
    $cputime;
}

##---------------------------------------------------------------------------
##	Routine to process input.  If no errors, routine returns the
##	CPU time taken.  If an error, returns undef.
##
sub process_input {

    ## Do processing
    if ($ArchiveOpen) {
	# archive already open, so doit
	eval { doit(); };

    } else {
	# open archive first (implictely pass @_ to open_archive)
	if (&open_archive) {
	    eval { doit(); };
	} else {
	    return undef;
	}
    }

    # check for error
    if ($@) {
	if ($@ =~ /signal caught/) {
	    $CODE = 0  unless $CODE;
	} else {
	    $CODE = (int($!) ? int($!) : 255)  unless $CODE;
	}
	$ERROR = $@;
	close_archive();
	warn "\n", $ERROR;
	return undef;
    }

    ## Cleanup
    close_archive();
}

###############################################################################
##	Private routines
###############################################################################

##---------------------------------------------------------------------------
##	Routine that does the work
##
sub doit {

    ## Check for non-archive modification modes.

    ## Just converting a single message to HTML
    if ($SINGLE) {
	single();
	return 1;
    }

    ## Text message listing of archive to standard output.
    if ($SCAN) {
	scan();
	return 1;
    }

    ## Annotating messages
    if ($ANNOTATE) {
	print STDOUT "Annotating messages in $OUTDIR ...\n"  unless $QUIET;

	if (!defined($NoteText)) {
	    print STDOUT "Please enter note text (terminated with EOF char):\n"
		unless $QUIET;
	    $NoteText = join("", <$MhaStdin>);
	}
	return annotate(@ARGV, $NoteText);
    }

    ## Removing messages
    if ($RMM) {
	print STDOUT "Removing messages from $OUTDIR ...\n"
	    unless $QUIET;
	return rmm(@ARGV);
    }

    ## HTML message listing to standard output.
    if ($IDXONLY) {
	IDXPAGE: {
	    compute_page_total();
	    if ($IdxPageNum && $MULTIIDX) {
		if ($IdxPageNum =~ /first/i) {
		    $IdxPageNum = 1;
		    last IDXPAGE;
		} 
		if ($IdxPageNum =~ /last/i) {
		    $IdxPageNum = $NumOfPages;
		    last IDXPAGE;
		}
		$IdxPageNum = int($IdxPageNum);
		last IDXPAGE  if $IdxPageNum;
	    }
	    $MULTIIDX   = 0;
	    $IdxPageNum = 1;
	    $NumOfPages = 1;
	}
	if ($THREAD) {
	    compute_threads();
	    write_thread_index($IdxPageNum);
	} else {
	    write_main_index($IdxPageNum);
	}
	return 1;
    }

    ## Get here, we are processing mail folders
    my($index, $fields, $fh, $i);

    $i = $NumOfMsgs;
    ##-------------------##
    ## Read mail folders ##
    ##-------------------##
    ## Just editing pages
    if ($EDITIDX) {
	print STDOUT "Editing $OUTDIR layout ...\n"  unless $QUIET;

    ## Adding a single message
    } elsif ($ADDSINGLE) {
	print STDOUT "Adding message to $OUTDIR\n"  unless $QUIET;
	$handle = $ADD;

	## Read mail head
	($index, $fields) = read_mail_header($handle);

	if ($index) {
	    $AddIndex{$index} = 1;
	    $IndexNum{$index} = &getNewMsgNum();

	    ## Read rest of message
	    $Message{$index} = &read_mail_body(
					$handle,
					$index,
				        $fields,
					$NoMsgPgs);
	}

    ## Adding/converting mail{boxes,folders}
    } else {
	print STDOUT ($ADD ? "Adding" : "Converting"), " messages to $OUTDIR"
	    unless $QUIET;
	my($mbox, $mesgfile, @files);

	MAILFOLDER: foreach $mbox (@ARGV) {

	    ## MH mail folder (a directory)
	    if (-d $mbox) {
		if (!opendir(MAILDIR, $mbox)) {
		    warn "\nWarning: Unable to open $mbox\n";
		    next;
		}
		$MBOX = 0;  $MH = 1;
		print STDOUT "\nReading $mbox "  unless $QUIET;
		@files = sort { $a <=> $b } grep(/$MHPATTERN/o,
						 readdir(MAILDIR));
		closedir(MAILDIR);

		local($_);
		MHFILE: foreach (@files) {
		    $mesgfile = "${mbox}${DIRSEP}${_}";
		    eval {
			$fh = file_open($mesgfile);
		    };
		    if ($@) {
			warn $@,
			     qq/...Skipping "$mesgfile"\n/;
			next MHFILE;
		    }
		    print STDOUT "."  unless $QUIET;
		    ($index, $fields) = read_mail_header($fh);

		    #  Process message if valid
		    if ($index) {
			if ($ADD && !$SLOW) { $AddIndex{$index} = 1; }
			$IndexNum{$index} = &getNewMsgNum();
			$Message{$index} = &read_mail_body(
						$fh,
						$index,
					        $fields,
						$NoMsgPgs);
			#  Check if conserving memory
			if ($SLOW && $DoArchive) {
			    output_mail($index, 1, 1);
			    if (defined($IndexNum{$index})) {
				$Update{$IndexNum{$index}} = 1;
			    }
			}
			if ($SLOW || !$DoArchive) {
			    delete $MsgHead{$index};
			    delete $Message{$index};
			}
		    }
		    close($fh);
		}

	    ## UUCP mail box file
	    } else {
		if ($mbox eq "-") {
		    $fh = $MhaStdin;
		} else {
		    eval {
			$fh = file_open($mbox);
		    };
		    if ($@) {
			warn $@,
			     qq/...Skipping "$mbox"\n/;
			next MAILFOLDER;
		    }
		}

		$MBOX = 1;  $MH = 0;
		print STDOUT "\nReading $mbox "  unless $QUIET;
		# while (<$fh>) { last if /$FROM/o; }
		MBOX: while (!eof($fh)) {
		    print STDOUT "."  unless $QUIET;
		    ($index, $fields) = read_mail_header($fh);

		    if ($index) {
			if ($ADD && !$SLOW) { $AddIndex{$index} = 1; }
			$IndexNum{$index} = &getNewMsgNum();
			$Message{$index} = read_mail_body(
						$fh,
						$index,
						$fields,
						$NoMsgPgs);
			if ($SLOW && $DoArchive) {
			    output_mail($index, 1, 1);
			    if (defined($IndexNum{$index})) {
				$Update{$IndexNum{$index}} = 1;
			    }
			}
			if ($SLOW || !$DoArchive) {
			    delete $MsgHead{$index};
			    delete $Message{$index};
			}

		    } else {
			read_mail_body($fh, $index, $fields, 1);
		    }
		}
		close($fh);

	    } # END: else UUCP mailbox
	} # END: foreach $mbox
    } # END: Else converting mailboxes
    print "\n"  unless $QUIET;

    ## All done if not creating an archive
    if (!$DoArchive) {
	return 1;
    }

    ## Check if there are any new messages
    if (!$EDITIDX && ($i == $NumOfMsgs)) {
	print STDOUT "No new messages\n"  unless $QUIET;
	return 1;
    }
    $NewMsgCnt = $NumOfMsgs - $i;

    ## Write pages
    &write_pages();
    1;
}

##---------------------------------------------------------------------------
##	write_pages writes out all archive pages and db
##
sub write_pages {
    my($i, $j, $key, $index, $tmp, $tmp2);
    my(@array2);
    my($mloc, $tloc);

    ## Remove old message if hit maximum size or expiration
    if (($MAXSIZE && ($NumOfMsgs > $MAXSIZE)) ||
	$ExpireTime ||
	$ExpireDateTime) {

	## Set @MListOrder and %Index2MLoc for properly marking messages
	## to be updated when a related messages are removed.  Thread
	## data should be around from db.

	@MListOrder = sort_messages();
	@Index2MLoc{@MListOrder} = (0 .. $#MListOrder);

	# Ignore termination signals
	&ign_signals();

	## Expiration based upon time
	foreach $index (sort_messages(0,0,0,0)) {
	    last  unless
		    ($MAXSIZE && ($NumOfMsgs > $MAXSIZE)) ||
		    (&expired_time(&get_time_from_index($index)));

	    &delmsg($index);

	    # Mark messages that need to be updated
	    if (!$NoMsgPgs) {
		$mloc = $Index2MLoc{$index};  $tloc = $Index2TLoc{$index};
		$Update{$IndexNum{$MListOrder[$mloc-1]}} = 1
		    if $mloc-1 >= 0;
		$Update{$IndexNum{$MListOrder[$mloc+1]}} = 1
		    if $mloc+1 <= $#MListOrder;
		$Update{$IndexNum{$TListOrder[$tloc-1]}} = 1
		    if $tloc-1 >= 0;
		$Update{$IndexNum{$TListOrder[$tloc+1]}} = 1
		    if $tloc+1 <= $#TListOrder;
		for ($i=2; $i <= $TSliceNBefore; ++$i) {
		    $Update{$IndexNum{$TListOrder[$tloc-$i]}} = 1
			if $tloc-$i >= 0;
		}
		for ($i=2; $i <= $TSliceNAfter; ++$i) {
		    $Update{$IndexNum{$TListOrder[$tloc+$i]}} = 1
			if $tloc-$i >= $#TListOrder;
		}
		foreach (@{$FollowOld{$index}}) {
		    $Update{$IndexNum{$_}} = 1;
		}
	    }

	    # Mark where index page updates start
	    if ($MULTIIDX) {
		$tmp = int($Index2MLoc{$index}/$IDXSIZE)+1;
		$IdxMinPg = $tmp
		    if ($tmp < $IdxMinPg || $IdxMinPg < 0);
		$tmp = int($Index2TLoc{$index}/$IDXSIZE)+1;
		$TIdxMinPg = $tmp
		    if ($tmp < $TIdxMinPg || $TIdxMinPg < 0);
	    }
	}
    }

    ## Reset MListOrder
    @MListOrder = sort_messages();
    @Index2MLoc{@MListOrder} = (0 .. $#MListOrder);

    ## Compute follow up messages
    compute_follow_ups(\@MListOrder);

    ## Compute thread information (sets ThreadList, TListOrder, Index2TLoc)
    compute_threads();

    ## Check for which messages to update when adding to archive
    if ($ADD) {
	if ($UPDATE_ALL) {
	    foreach $index (@MListOrder) { $Update{$IndexNum{$index}} = 1; }
	    $IdxMinPg = 0;
	    $TIdxMinPg = 0;

	} else {
	    $i = 0;
	    foreach $index (@MListOrder) {
		## Check for New follow-up links
		if (is_follow_ups_diff($index)) {
		    $Update{$IndexNum{$index}} = 1;
		}
		## Check if new message; must update links in prev/next msgs
		if ($AddIndex{$index}) {

		    # Mark where main index page updates start
		    if ($MULTIIDX) {
			$tmp = int($Index2MLoc{$index}/$IDXSIZE)+1;
			$IdxMinPg = $tmp
			    if ($tmp < $IdxMinPg || $IdxMinPg < 0);
		    }

		    # Mark previous/next messages
		    $Update{$IndexNum{$MListOrder[$i-1]}} = 1
			if $i > 0;
		    $Update{$IndexNum{$MListOrder[$i+1]}} = 1
			if $i < $#MListOrder;
		}
		## Check for New reference links
		foreach (@{$Refs{$index}}) {
		    $tmp = $MsgId{$_};
		    if (defined($IndexNum{$tmp}) && $AddIndex{$tmp}) {
			$Update{$IndexNum{$index}} = 1;
		    }
		}
		$i++;
	    }
	    $i = 0;
	    foreach $index (@TListOrder) {
		## Check if new message; must update links in prev/next msgs
		if ($AddIndex{$index}) {

		    # Mark where thread index page updates start
		    if ($MULTIIDX) {
			$tmp = int($Index2TLoc{$index}/$IDXSIZE)+1;
			$TIdxMinPg = $tmp
			    if ($tmp < $TIdxMinPg || $TIdxMinPg < 0);
		    }

		    # Mark previous/next message in thread
		    $Update{$IndexNum{$TListOrder[$i-1]}} = 1
			if $i > 0;
		    $Update{$IndexNum{$TListOrder[$i+1]}} = 1
			if $i < $#TListOrder;

		    $tloc = $Index2TLoc{$index};
		    for ($j=2; $j <= $TSliceNBefore; ++$j) {
			$Update{$IndexNum{$TListOrder[$tloc-$j]}} = 1
			    if $tloc-$j >= 0;
		    }
		    for ($j=2; $j <= $TSliceNAfter; ++$j) {
			$Update{$IndexNum{$TListOrder[$tloc+$j]}} = 1
			    if $tloc-$j >= $#TListOrder;
		    }
		}
		$i++;
	    }
	}
    }

    ##	Compute total number of pages
    $i = $NumOfPages;
    compute_page_total();

    ## Update all pages for $LASTPG$
    if ($UsingLASTPG && ($i != $NumOfPages)) {
	$IdxMinPg = 0;
	$TIdxMinPg = 0;
    }

    ##------------##
    ## Write Data ##
    ##------------##
    ign_signals();		# Ignore termination signals
    print STDOUT "\n"  unless $QUIET;

    ## Write indexes and mail
    write_mail()		unless $NoMsgPgs;
    write_main_index()  	if $MAIN;
    write_thread_index()	if $THREAD;

    ## Write database
    print STDOUT "Writing database ...\n"  unless $QUIET;
    output_db($DBPathName);

    ## Write any alternate indexes
    $IdxMinPg = 0; $TIdxMinPg = 0;
    my($rc, $rcfile);
    OTHERIDX: foreach $rc (@OtherIdxs) {
	$THREAD = 0;

	## find other index resource file
	IDXFIND: {
	    if (-e $rc) {
		# in current working directory
		$rcfile = $rc;
		last IDXFIND;
	    }
	    if (defined $MainRcDir) {
		# check if located with main resource file
		$rcfile = join($DIRSEP, $MainRcDir, $rc);
		last IDXFIND  if -e $rcfile;
	    }
	    if (defined $ENV{'HOME'}) {
		# check if in home directory
		$rcfile = join($DIRSEP, $ENV{'HOME'}, $rc);
		last IDXFIND  if -e $rcfile;
	    }

	    # check if in archive directory
	    $rcfile = join($DIRSEP, $OUTDIR, $rc);
	    last IDXFIND  if -e $rcfile;

	    # look thru @INC to find file
	    local($_);
	    foreach (@INC) {
		$rcfile = join($DIRSEP, $_, $rc);
		if (-e $rcfile) {
		    last IDXFIND;
		}
	    }
	    warn qq/Warning: Unable to find resource file "$rc"\n/;
	    next OTHERIDX;
	}
	    
	## read resource file and print index
	if (read_fmt_file($rcfile)) {
	    if ($THREAD) {
		@TListOrder = ();
		write_thread_index();
	    } else {
		@MListOrder = ();
		write_main_index();
	    }
	}
    }

    unless ($QUIET) {
	print STDOUT "$NewMsgCnt new messages\n"  if $NewMsgCnt > 0;
	print STDOUT "$NumOfMsgs total messages\n";
    }

} ## End: write_pages()

##---------------------------------------------------------------------------
##	Compute follow-ups
##
sub compute_follow_ups {
    my $idxlst = shift;
    my($index, $tmp, $tmp2);

    %Follow = ();
    foreach $index (@$idxlst) {
	$FolCnt{$index} = 0  unless $FolCnt{$index};
	if (defined($Refs{$index}) && scalar(@{$Refs{$index}})) {
	    $tmp2 = $Refs{$index}->[-1];
	    next  unless defined($MsgId{$tmp2}) &&
			 defined($IndexNum{$MsgId{$tmp2}});
	    $tmp = $MsgId{$tmp2};
	    if ($Follow{$tmp}) { push(@{$Follow{$tmp}}, $index); }
	    else { $Follow{$tmp} = [ $index ]; }
	    ++$FolCnt{$tmp};
	}
    }
}

##---------------------------------------------------------------------------
##	Compute total number of pages
##
sub compute_page_total {
    if ($MULTIIDX && $IDXSIZE) {
	$NumOfPages   = int($NumOfMsgs/$IDXSIZE);
	++$NumOfPages      if ($NumOfMsgs/$IDXSIZE) > $NumOfPages;
	$NumOfPages   = 1  if $NumOfPages == 0;
    } else {
	$NumOfPages = 1;
    }
}

##---------------------------------------------------------------------------
##	write_mail outputs converted mail.  It takes a reference to an
##	array containing indexes of messages to output.
##
sub write_mail {
    my($hack) = (0);
    print STDOUT "Writing mail "  unless $QUIET;

    if ($SLOW && !$ADD) {
	$ADD = 1;
	$hack = 1;
    }

    foreach $index (@MListOrder) {
	print STDOUT "."  unless $QUIET;
	output_mail($index, $AddIndex{$index}, 0);
    }

    if ($hack) {
	$ADD = 0;
    }

    print STDOUT "\n"  unless $QUIET;
}

##---------------------------------------------------------------------------
##	read_mail_header() is responsible for parsing the header of
##	a mail message and loading message information into hash
##	structures.
##
##	($index, $header_fields_ref) = read_mail_header($filehandle);
##
sub read_mail_header {
    my $handle = shift;
    my($index, $date, $tmp);
    my($from, $sub, $msgid, $ctype);
    local($_);

    my @refs = ();
    my @array = ();
    my($fields, $header) = readmail::MAILread_file_header($handle);

    ##---------------------------##
    ## Check for no archive flag ##
    ##---------------------------##
    if ( $CheckNoArchive &&
	 ((defined($fields->{'restrict'}) &&
	  grep { /no-external-archive/i } @{$fields->{'restrict'}}) ||
	  (defined($fields->{'x-no-archive'}) &&
	   grep { /yes/i } @{$fields->{'x-no-archive'}})) ) {
	return undef;
    }

    ##----------------------------------##
    ## Check for user-defined exclusion ##
    ##----------------------------------##
    if ($MsgExcFilter) {
	return undef  if mhonarc::message_exclude($header);
    }

    ##------------##
    ## Get Msg-ID ##
    ##------------##
    $msgid = $fields->{'message-id'}[0] || $fields->{'msg-id'}[0] || 
	     $fields->{'content-id'}[0];
    if (defined($msgid)) {
	if ($msgid =~ /<([^>]*)>/) {
	    $msgid = $1;
	} else {
	    $msgid =~ s/^\s+//;
	    $msgid =~ s/\s+$//;
	}
    } else {
        # create bogus ID if none exists
	eval {
	    # create message-id using md5 digest of header;
	    # can potentially skip over already archived messages w/o id
	    require Digest::MD5;
	    $msgid = join("", Digest::MD5::md5_hex($header),
			      '@NO-ID-FOUND.mhonarc.org');
	};
	if ($@) {
	    # unable to require, so create arbitary message-id
	    $msgid = join("", $$,'.',time,'.',$_msgid_cnt++,
			      '@NO-ID-FOUND.mhonarc.org');
	}
    }

    ## Return if message already exists in archive
    if ($msgid && defined($MsgId{$msgid})) {
	return undef;
    }

    ##----------##
    ## Get date ##
    ##----------##
    $date = "";
    foreach (@DateFields) {
	next  unless defined($fields->{$_});

	## Treat received field specially
	if ($_ eq 'received') {
	    @array = split(/;/, $fields->{$_}[0]);
	    $date = pop @array;
	## Any other field should just be a date
	} else {
	    $date = $fields->{$_}[0];
	}
	$date =~ s/^\s+//;  $date =~ s/\s+$//;

	## See if time_t can be determined.
	if (($date =~ /\w/) && (@array = parse_date($date))) {
	    $index = get_time_from_date(@array[1..$#array]);
	    last;
	}
    }
    if (!$index) {
	warn qq/\nWarning: Could not parse date for message\n/,
	       qq/         Message-Id: <$msgid>\n/;
	# Use current time
	$index = time;
	# Set date string to local date if not defined
	$date  = &time2str("", $index, 1)  unless $date =~ /\S/;
    }

    ## Return if message too old to add (note, $index just contains time).
    if (&expired_time($index)) {
	return undef;
    }

    ##-------------##
    ## Get Subject ##
    ##-------------##
    if (defined($fields->{'subject'}) && ($fields->{'subject'}[0] =~ /\S/)) {
	($sub = $fields->{'subject'}[0]) =~ s/\s+$//;
	$sub = subject_strip($sub)  if $SubStripCode;
    } else {
	$sub = '';
    }

    ##----------##
    ## Get From ##
    ##----------##
    $from = "";
    foreach (@FromFields) {
	next  unless defined $fields->{$_};
	$from = $fields->{$_}[0];
	last;
    }
    $from = 'Unknown'  unless $from;

    ##----------------##
    ## Get References ##
    ##----------------##
    if (defined($fields->{'references'})) {
	$tmp = $fields->{'references'}[0];
	while ($tmp =~ s/<([^<>]+)>//) {
	    push(@refs, $1);
	}
    }
    if (defined($fields->{'in-reply-to'})) {
	my $irtoid;
	foreach (@{$fields->{'in-reply-to'}}) {
	    $tmp = $_;
	    $irtoid = "";
	    while ($tmp =~ s/<([^<>]+)>//) { $irtoid = $1 };
	    push(@refs, $irtoid)  if $irtoid;
	}
    }
    @refs = remove_dups(\@refs);        # Remove duplicate msg-ids

    ##------------------##
    ## Get Content-Type ##
    ##------------------##
    if (defined($fields->{'content-type'})) {
	($ctype = $fields->{'content-type'}[0]) =~ m%^\s*([\w\-\./]+)%;
	$ctype = lc ($1 || 'text/plain');
    } else {
	$ctype = 'text/plain';
    }

    ## Insure uniqueness of index
    $index .= $X . sprintf("%d",$LastMsgNum+1);

    ## Set mhonarc fields.  Note how values are NOT arrays.
    $fields->{'x-mha-index'} = $index;
    $fields->{'x-mha-message-id'} = $msgid;
    $fields->{'x-mha-from'} = $from;
    $fields->{'x-mha-subject'} = $sub;
    $fields->{'x-mha-content-type'} = $ctype;

    ## Invoke callback if defined
    if (defined($CBMessageHeadRead) && defined(&$CBMessageHeadRead)) {
	return undef  unless &$CBMessageHeadRead($fields, $header);
    }

    $From{$index} = $from;
    $Date{$index} = $date;
    $Subject{$index} = $sub;
    $MsgHead{$index} = htmlize_header($fields);
    $ContentType{$index} = $ctype;
    if ($msgid) {
	$MsgId{$msgid} = $index;
	$NewMsgId{$msgid} = $index;	# Track new message-ids
	$Index2MsgId{$index} = $msgid;
    }

    $Refs{$index} = [ @refs ]  if (@refs);

    ($index, $fields);
}

##---------------------------------------------------------------------------
##	read_mail_body() reads in the body of a message.  The returned
##	filtered body is in $ret.
##
##	$html = read_mail_body($fh, $index, $fields_hash_ref,
##			       $skipConversion);
##
sub read_mail_body {
    my($handle, $index, $fields, $skip) = @_;
    my($ret, $data) = ('', '');
    my(@files);
    local($_);

    ## Slurp up message body
    ##	UUCP mailbox
    if ($MBOX) {
	if ($CONLEN && defined($fields->{"content-length"})) {
	    my($len, $cnt) = ($fields->{"content-length"}[0], 0);
	    if ($len) {
		while (<$handle>) {
		    $cnt += length($_);		# Increment byte count
		    $data .= $_  unless $skip;  # Save data
		    last  if $cnt >= $len	# Last if hit length
		}
	    }
	    # Slurp up bogus data if required (should I do this?)
	    while (!/$FROM/o && !eof($handle)) {
		$_ = <$handle>;
	    }

	} else {				# No content-length
	    while (<$handle>) {
		last  if /$FROM/o;
		$data .= $_  unless $skip;
	    }
	}

    ##	MH message file
    } elsif (!$skip) {
	local $/ = undef;
	$data = <$handle>;
    }

    return ''  if $skip;

    ## Invoke callback if defined
    if (defined($CBRawMessageBodyRead) && defined(&$CBRawMessageBodyRead)) {
	&$CBRawMessageBodyRead($fields, \$data);
    }

    ## Define "globals" for use by filters
    ##	NOTE: This stuff can be handled better, and will be done
    ##	      when/if I get around to rewriting mhonarc in (OO) Perl 5.
    $MHAindex  = $index;
    $MHAmsgnum = &fmt_msgnum($IndexNum{$index});
    $MHAmsgid  = $Index2MsgId{$index};

    ## Filter data
    ($ret, @files) = &readmail::MAILread_body($fields, \$data);
    $ret = ''     unless defined $ret;
    @files = ( )  unless @files;

    ## Invoke callback if defined
    if (defined($CBMessageBodyRead) && defined(&$CBMessageBodyRead)) {
	&$CBMessageBodyRead($fields, \$ret, \@files);
    }

    if (!defined($ret) || $ret eq "") {
	$ret = join('',
		    "<dl>\n",
		    "<dt><strong>Warning</strong></dt>\n",
		    "<dd>Unable to process data: \n",
		    "<tt>",
		    htmlize($fields->{'content-type'}[0] || 'text/plain'),
		    "</tt>\n",
		    "</dd>\n",
		    "</dl>\n"
		    );
    }
    if (@files) {
	$Derived{$index} = [ @files ];
    }
    $ret;
}

##---------------------------------------------------------------------------
##	Output/edit a mail message.
##	    $index	=> current index (== $array[$i])
##	    $force	=> flag if mail is written and not editted, regardless
##	    $nocustom	=> ignore sections with user customization
##
##	This function returns ($msgnum, $filename) if everything went
##	okay, but no calls to this routine check the return values.
##
sub output_mail {
    my($index, $force, $nocustom) = @_;
    my($msgi, $tmp, $tmp2, $template, @array2);
    my($msghandle, $msginfh, $drvfh);

    my $msgnum	     = $IndexNum{$index};
    if (!$SINGLE && !defined($msgnum)) {
      # Something bad must have happened to message, so we just
      # quietly return.
      return;
    }

    my $adding	     = ($ADD && !$force && !$SINGLE);
    my $i_p0 	     = fmt_msgnum($msgnum);
    my $filename     = msgnum_filename($msgnum);
    my $filepathname = join($DIRSEP, $OUTDIR, $filename);
    my $tmppathname  = join($DIRSEP, $OUTDIR, "msgtmp.$$");

    if ($adding) {
	return ($i_p0, $filename)  unless $Update{$msgnum};
	#&file_rename($filepathname, $tmppathname);
	eval {
	  $msginfh = file_open($filepathname);
	};
	if ($@) {
	  # Something is screwed up with archive: We try to delete
	  # message from database since message file appears to have
	  # disappeared
	  warn $@,
	       qq/...Will attempt to remove message and continue on\n/;
	  delmsg($index);

	  # Nothing else to do, so return.
	  return;
	}
    }
    if ($SINGLE) {
	$msghandle = \*STDOUT;
    } else {
	$msghandle = file_create($tmppathname, $GzipFiles);
    }

    ## Output HTML header
    if ($adding) {
	while (<$msginfh>) {
	    last  if /<!--X-Body-Begin/;
	}
    }
    if (!$nocustom) {
	#&defineIndex2MsgId();

	$template = ($MSGPGSSMARKUP ne '') ? $MSGPGSSMARKUP : $SSMARKUP;
	if ($template ne '') {
	    $template =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	    print $msghandle $template;
	}

	# Output comments -- more informative, but can be used for
	#		     error recovering.
	print $msghandle 
	    "<!-- ", commentize("MHonArc v$VERSION"), " -->\n",
	    "<!--X-Subject: ",      commentize($Subject{$index}), " -->\n",
	    "<!--X-From-R13: ",	    commentize(mrot13($From{$index})), " -->\n",
	    "<!--X-Date: ", 	    commentize($Date{$index}), " -->\n",
	    "<!--X-Message-Id: ",   commentize($Index2MsgId{$index}), " -->\n",
	    "<!--X-Content-Type: ", commentize($ContentType{$index}), " -->\n";
		  #ContentType

	if (defined($Refs{$index})) {
	    foreach (@{$Refs{$index}}) {
		print $msghandle
		    "<!--X-Reference: ", commentize($_), " -->\n";
			  #Reference-Id
	    }
	}
	if (defined($Derived{$index})) {
	    foreach (@{$Derived{$index}}) {
		print $msghandle "<!--X-Derived: ", commentize($_), " -->\n";
	    }
	}
	print $msghandle "<!--X-Head-End-->\n";

	# Add in user defined markup
	($template = $MSGPGBEG) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	print $msghandle $template;
    }
    print $msghandle "<!--X-Body-Begin-->\n";

    ## Output header
    if ($adding) {
	while (<$msginfh>) {
	    last  if /<!--X-User-Header-End/ || /<!--X-TopPNI--/;
	}
    }
    print $msghandle "<!--X-User-Header-->\n";
    if (!$nocustom) {
	($template = $MSGHEAD) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	print $msghandle $template;
    }
    print $msghandle "<!--X-User-Header-End-->\n";

    ## Output Prev/Next/Index links at top
    if ($adding) {
	while (<$msginfh>) { last  if /<!--X-TopPNI-End/; }
    }
    print $msghandle "<!--X-TopPNI-->\n";
    if (!$nocustom && !$SINGLE) {
	($template = $TOPLINKS) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	print $msghandle $template;
    }
    print $msghandle "\n<!--X-TopPNI-End-->\n";

    ## Output message data
    if ($adding) {
	$tmp2 = "";
	while (<$msginfh>) {
	    # check if subject header delimited
	    if (/<!--X-Subject-Header-Begin/) {
		$tmp2 =~ s%($AddrExp)%&link_refmsgid($1,1)%geo;
		print $msghandle $tmp2;
		$tmp2 = "";

		while (<$msginfh>) { last  if /<!--X-Subject-Header-End/; }
		print $msghandle "<!--X-Subject-Header-Begin-->\n";
		if (!$nocustom) {
		    ($template = $SUBJECTHEADER) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
		    print $msghandle $template;
		}
		print $msghandle "<!--X-Subject-Header-End-->\n";
		next;
	    }
	    # check if head/body separator delimited
	    if (/<!--X-Head-Body-Sep-Begin/) {
		$tmp2 =~ s%($AddrExp)%&link_refmsgid($1,1)%geo;
		print $msghandle $tmp2;
		$tmp2 = "";

		while (<$msginfh>) { last  if /<!--X-Head-Body-Sep-End/; }
		print $msghandle "<!--X-Head-Body-Sep-Begin-->\n";
		if (!$nocustom) {
		    ($template = $HEADBODYSEP) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
		    print $msghandle $template;
		}
		print $msghandle "<!--X-Head-Body-Sep-End-->\n";
		next;
	    }

	    $tmp2 .= $_;
	    last  if /<!--X-MsgBody-End/;
	}
	$tmp2 =~ s%($AddrExp)%&link_refmsgid($1,1)%geo;
	print $msghandle $tmp2;

    } else {
	print $msghandle "<!--X-MsgBody-->\n";
	print $msghandle "<!--X-Subject-Header-Begin-->\n";
	($template = $SUBJECTHEADER) =~
	    s/$VarExp/&replace_li_var($1,$index)/geo;
	print $msghandle $template;
	print $msghandle "<!--X-Subject-Header-End-->\n";

	$MsgHead{$index} =~ s%($AddrExp)%&link_refmsgid($1)%geo;
	$Message{$index} =~ s%($AddrExp)%&link_refmsgid($1)%geo;

	print $msghandle "<!--X-Head-of-Message-->\n";
	print $msghandle $MsgHead{$index};
	print $msghandle "<!--X-Head-of-Message-End-->\n";
	print $msghandle "<!--X-Head-Body-Sep-Begin-->\n";
	($template = $HEADBODYSEP) =~
	    s/$VarExp/&replace_li_var($1,$index)/geo;
	print $msghandle $template;
	print $msghandle "<!--X-Head-Body-Sep-End-->\n";
	print $msghandle "<!--X-Body-of-Message-->\n";
	print $msghandle $Message{$index}, "\n";
	print $msghandle "<!--X-Body-of-Message-End-->\n";
	print $msghandle "<!--X-MsgBody-End-->\n";
    }

    ## Output any followup messages
    if ($adding) {
	while (<$msginfh>) { last  if /<!--X-Follow-Ups-End/; }
    }
    print $msghandle "<!--X-Follow-Ups-->\n";
    ($template = $MSGBODYEND) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
    print $msghandle $template;
    if (!$nocustom && $DoFolRefs && defined($Follow{$index})) {
	if (scalar(@{$Follow{$index}})) {
	    ($template = $FOLUPBEGIN) =~
		s/$VarExp/&replace_li_var($1,$index)/geo;
	    print $msghandle $template;
	    foreach (@{$Follow{$index}}) {
		($template = $FOLUPLITXT) =~
		    s/$VarExp/&replace_li_var($1,$_)/geo;
		print $msghandle $template;
	    }
	    ($template = $FOLUPEND) =~
		s/$VarExp/&replace_li_var($1,$index)/geo;
	    print $msghandle $template;
	}
    }
    print $msghandle "<!--X-Follow-Ups-End-->\n";

    ## Output any references
    if ($adding) {
	while (<$msginfh>) { last  if /<!--X-References-End/; }
    }
    print $msghandle "<!--X-References-->\n";
    if (!$nocustom && $DoFolRefs && defined($Refs{$index})) {
	$tmp2 = 0;	# flag for when first ref printed
	if (scalar(@{$Refs{$index}})) {
	    foreach (@{$Refs{$index}}) {
		next  unless defined($MsgId{$_});
		next  unless defined($IndexNum{$MsgId{$_}});
		if (!$tmp2) {
		    ($template = $REFSBEGIN) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
		    print $msghandle $template;
		    $tmp2 = 1;
		}
		($template = $REFSLITXT) =~
		    s/$VarExp/&replace_li_var($1,$MsgId{$_})/geo;
		print $msghandle $template;
	    }

	    if ($tmp2) {
		($template = $REFSEND) =~
		    s/$VarExp/&replace_li_var($1,$index)/geo;
		print $msghandle $template;
	    }
	}
    }
    print $msghandle "<!--X-References-End-->\n";

    ## Output verbose links to prev/next message in list
    if ($adding) {
	while (<$msginfh>) { last  if /<!--X-BotPNI-End/; }
    }
    print $msghandle "<!--X-BotPNI-->\n";
    if (!$nocustom && !$SINGLE) {
	($template = $BOTLINKS) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	print $msghandle $template;
    }
    print $msghandle "\n<!--X-BotPNI-End-->\n";

    ## Output footer
    if ($adding) {
	while (<$msginfh>) {
	    last  if /<!--X-User-Footer-End/;
	}
    }
    print $msghandle "<!--X-User-Footer-->\n";
    if (!$nocustom) {
	($template = $MSGFOOT) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	print $msghandle $template;
    }
    print $msghandle "<!--X-User-Footer-End-->\n";

    if (!$nocustom) {
	($template = $MSGPGEND) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	print $msghandle $template;
    }

    close($msghandle)  if (!$SINGLE);
    if ($adding) {
	close($msginfh);
	#&file_remove($tmppathname);
    }
    file_rename($tmppathname, $filepathname)  unless $SINGLE;

    ## Create user defined files
    foreach (keys %UDerivedFile) {
	($tmp = $_) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	$tmp2 = join($DIRSEP, $OUTDIR, $tmp);
	if ($drvfh = file_create($tmp2, $GzipFiles)) {
	    ($template = $UDerivedFile{$_}) =~
		s/$VarExp/&replace_li_var($1,$index)/geo;
	    print $drvfh $template;
	    close($drvfh);
	    if (defined($Derived{$index})) {
		push(@{$Derived{$index}}, $tmp);
	    } else {
		$Derived{$index} = [ $tmp ];
	    }
	} else {
	    warn "Warning: Unable to create $tmp2\n";
	}
    }
    if (defined($Derived{$index})) {
	$Derived{$index} = [ remove_dups($Derived{$index}) ];
    }

    ## Set modification times -- Use eval incase OS does not support utime.
    if ($MODTIME && !$SINGLE) {
	eval {
	    $tmp = get_time_from_index($index);
	    if (defined($Derived{$index})) {
	      @array2 = @{$Derived{$index}};
	      grep($_ = $OUTDIR . $DIRSEP . $_, @array2);
	    } else {
	      @array2 = ( );
	    }
	    unshift(@array2, $filepathname);
	    file_utime($tmp, $tmp, @array2);
	};
	if ($@) {
	    warn qq/\nWarning: Your platform does not support setting file/,
		   qq/         modification times\n/;
	    $MODTIME = 0;
	}
    }

    ($i_p0, $filename);
}

#############################################################################
## Miscellaneous routines
#############################################################################

##---------------------------------------------------------------------------
##	delmsg delets a message from the archive.
##
sub delmsg {
    my($key) = @_;
    my($pathname);

    #&defineIndex2MsgId();
    my $msgnum = $IndexNum{$key};  return 0  if ($msgnum eq '');
    my $filename = join($DIRSEP, $OUTDIR, &msgnum_filename($msgnum));
    delete $ContentType{$key};
    delete $Date{$key};
    delete $From{$key};
    delete $IndexNum{$key};
    delete $Refs{$key};
    delete $Subject{$key};
    delete $MsgId{$Index2MsgId{$key}};
    file_remove($filename)  unless $KeepOnRmm;
    foreach $filename (@{$Derived{$key}}) {
	$pathname = (OSis_absolute_path($filename)) ?
			$filename : join($DIRSEP, $OUTDIR, $filename);
	if (-d $pathname) {
	    dir_remove($pathname)  unless $KeepOnRmm;
	} else {
	    file_remove($pathname)  unless $KeepOnRmm;
	}
    }
    delete $Derived{$key};
    $NumOfMsgs--;
    1;
}

##---------------------------------------------------------------------------
##	Routine to convert a msgid to an anchor
##
sub link_refmsgid {
    my($refmsgid, $onlynew) = @_;

    if (defined($MsgId{$refmsgid}) &&
	defined($IndexNum{$MsgId{$refmsgid}}) &&
	(!$onlynew || $NewMsgId{$refmsgid})) {
	my($lreftmpl) = $MSGIDLINK;
	$lreftmpl =~ s/$VarExp/&replace_li_var($1,$MsgId{$refmsgid})/geo;
	$lreftmpl;
    } else {
	$refmsgid;
    }
}

##---------------------------------------------------------------------------
##	Retrieve next available message number.  Should only be used
##	when an archive is locked.
##
sub getNewMsgNum {
    $NumOfMsgs++; $LastMsgNum++;
    $LastMsgNum;
}

##---------------------------------------------------------------------------
##	ign_signals() sets mhonarc to ignore termination signals.  This
##	routine is called right before an archive is written/edited to
##	help prevent archive corruption.
##
sub ign_signals {
    @SIG{@_term_sigs} = ('IGNORE') x scalar(@_term_sigs);
}

##---------------------------------------------------------------------------
##	set_handler() sets up the signal_catch() routine to be called when
##	termination signals are sent to mhonarc.
##
sub set_handler {
    %_sig_org = ( );
    @_sig_org{@_term_sigs} = @SIG{@_term_sigs};
    @SIG{@_term_sigs} = (\&mhonarc::signal_catch) x scalar(@_term_sigs);
}

##---------------------------------------------------------------------------
##	reset_handler() resets the original signal handlers.
##
sub reset_handler {
    @SIG{@_term_sigs} = @_sig_org{@_term_sigs};
}

##---------------------------------------------------------------------------
##	signal_catch(): Function for handling signals that would cause
##	termination.
##
sub signal_catch {
    my $signame = shift;
    close_archive(1);
    &{$_sig_org{$signame}}($signame)  if defined(&{$_sig_org{$signame}});
    reset_handler();
    die qq/Processing stopped, signal caught: SIG$signame\n/;
}

##---------------------------------------------------------------------------
##	Create Index2MsgId if not defined
##
sub defineIndex2MsgId {
    if (!defined(%Index2MsgId)) {
	foreach (keys %MsgId) {
	    $Index2MsgId{$MsgId{$_}} = $_;
	}
    }
}

##---------------------------------------------------------------------------
1;
