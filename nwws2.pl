#!/usr/bin/perl -w

use strict;
use Net::Jabber;
use Config::IniFiles;
use XML::Simple;
use Data::Dumper;

$Data::Dumper::Sortkeys = 1;

die "Usage: $0 /path/to/config/file\n" if $#ARGV < 0;
my $config_file = $ARGV[0];

my $cfg = Config::IniFiles->new( -file => $config_file ) or die "Could not parse config, exiting.\n";

my $server    = $cfg->val('Main', 'server', 'undef');
my $port      = $cfg->val('Main', 'port', 'undef');
my $username  = $cfg->val('Main', 'username', 'undef') . '@' . $cfg->val('Main', 'server', 'undef');
my $password  = $cfg->val('Main', 'password', 'undef');
my $resource  = $cfg->val('Main', 'resource', 'undef');
my $debugfile = $cfg->val('Main', 'debugfile', '');

if ($server eq 'undef' || $port eq 'undef' || $username =~ /undef/ || $password eq 'undef' || $resource eq 'undef') {
	die "Could not parse all required variables, exiting.\n";
}

#Set up signal handlers
$SIG{HUP} = \&Stop;
$SIG{KILL} = \&Stop;
$SIG{TERM} = \&Stop;
$SIG{INT} = \&Stop;

our $Connection;

#Start connect loop
while(1) {

	#Create new Jabber client
	$Connection = new Net::Jabber::Client();

	#Turn on debug messages?
	if ($debugfile ne '') {
		$Connection->{DEBUG}->Init(
			level => 3,
			file  => $debugfile
		);
	}

	#Set up callback functions
	$Connection->SetCallBacks(
		message  => \&InMessage,
		presence => \&InPresence,
		iq       => \&InIQ
	);

	#Connect to server
	my $status = $Connection->Connect(
		hostname => $server,
		port     => $port,
		_tls     => 1
	);
	if (!(defined($status))) {
		printToLog("ERROR:  Jabber server is down or connection was not allowed.");
		printToLog("($!)");
		exit(0);
	}

	#Send auth info
	my @result = $Connection->AuthSend(
		username => $username,
		password => $password,
		resource => $resource
	);
	if ($result[0] ne "ok") {
		printToLog("ERROR: Authorization failed: $result[0] - $result[1]");
		exit(0);
	}

	printToLog("Logged in to $server:$port...");

	printToLog("Getting Roster to tell server to send presence info...");
	$Connection->RosterGet();

	printToLog("Sending presence to tell world that we are logged in...");
	$Connection->PresenceSend();

	#Join the 'nwws' conference room
	$Connection->MUCJoin(
		room   => 'nwws',
		server => 'conference.' . $cfg->val('Main', 'server'),
		nick   => $cfg->val('Main', 'resource')
	);

	#Enter event loop
	while(defined($Connection->Process())) { }

	#If we got here, the connection was severed
	printToLog("ERROR: The connection was killed, restarting.");
	
	#Sleep for 1 second
	sleep(1);
}

#Done
exit(0);

################################################################################
sub Stop {
	printToLog("Exiting...");
	$Connection->Disconnect();
	exit(0);
}

################################################################################
sub InMessage {
	my $sid = shift;
	my $message = shift;
	my $type = $message->GetType();
	my $fromJID = $message->GetFrom("jid");
	my $from = $fromJID->GetUserID();
	my $resource = $fromJID->GetResource();
	my $subject = $message->GetSubject();
	my $body = $message->GetBody();
	return if $body =~ /^\*\*WARNING\*\*/;
	return if $body =~ /issues  valid/;
	return if $body =~ /issues TST valid/;
	my $xml = $message->GetXML();
	#printToLog("Message ($type)");
	#printToLog("  From: $from ($resource)");
	#printToLog("  Subject: $subject");
	#printToLog("  Body: $body");
	#printToLog("===");
	#printToLog($xml);
	#printToLog("===");
	my $ref = XMLin($xml);
	return if !defined($ref->{'body'});
	#print $ref->{'body'} . "\n";
	# Create archive dir if it does not exist
	my $newref;
	if (ref($ref->{'x'}) eq 'ARRAY') {
		$newref = $ref->{'x'}->[0];
	} elsif (ref($ref->{'x'}) eq 'HASH') {
		$newref = $ref->{'x'};
	}
	#print Dumper($ref);
	printToLog('message stanza rcvd from nwws-oi saying... ' . $ref->{'html'}->{'body'}->{'content'} . ', timestamp ' . $newref->{'issue'});
	if (! -d $cfg->val('Main', 'archivedir')) {
		mkdir($cfg->val('Main', 'archivedir')) or die "Could not create archive directory: $!\n";
	}
	if (! -d $cfg->val('Main', 'archivedir') . '/' . lc($newref->{'cccc'})) {
		mkdir(lc($cfg->val('Main', 'archivedir')) . '/' . lc($newref->{'cccc'})) or die "Could not create WFO directory: $!\n";
	}
	#Create product file
	#my $prodDate = $newref->{'issue'};
	#$prodDate =~ s/[\-T\:]//g;
	#$prodDate =~ s/Z$//;
	#my $file = $newref->{'awipsid'} . '-' . $newref->{'id'} . '-' . $prodDate . '.txt';
	#open(OUTFILE, ">" . $cfg->val('Main', 'archivedir') . '/' . $newref->{'cccc'} . '/' . $file) or die $!;
	#my @lines = split(/\n/, $newref->{'content'});
	#for(my $i=0; $i<@lines; $i+=2) {
	#	print OUTFILE $lines[$i] . "\n";
	#}
	#close(OUTFILE);
	#print Dumper($newref);
	my @tmpArray = split(/\./, $newref->{'id'});
	my @rightnow_gmt = gmtime(time());
	my $newId = substr($rightnow_gmt[5]+1900, 0, 2) . (length($rightnow_gmt[2]) == 2 ? '0' . $rightnow_gmt[2] : $rightnow_gmt[2]) . (length($rightnow_gmt[1]) == 2 ? '0' . $rightnow_gmt[1] : $rightnow_gmt[1]) . '_' . substr(time(), 0, 3) . substr($tmpArray[1], 0, 5);
	my $file = lc($newref->{'cccc'}) . '_' . lc($newref->{'ttaaii'}) . '-' . lc($newref->{'awipsid'}) . '.' . $newId . '.txt';
	open(OUTFILE, '>' . $cfg->val('Main', 'archivedir') . '/' . lc($newref->{'cccc'}) . '/' . $file) or die $!;
	my @lines = split("/\n/", $newref->{'content'});
	for(my $i=0; $i<@lines; $i+=2) {
		print OUTFILE $lines[$i] . "\n";
	}
	close(OUTFILE);
	# Perform Product Arrival Notification (PAN) action, if it exists and is executable
	if (defined($cfg->val('Main', 'panrun'))) {
		if ( -x $cfg->val('Main', 'panrun')) {
			chomp(my $cwd = `pwd`);
			my @output = `$cfg->val('Main', 'panrun') . ' ' . $cwd . '/' . $cfg->val('Main', 'archivedir') . '/' . $newref->{'cccc'} . '/' . $file . ' 2>&1 &`;
			if (scalar(@output) == 0) {
				printToLog("Error running PAN executable: " . join(" ", @output));
			}
		}
	}
}

################################################################################
sub InIQ {
	my $sid = shift;
	my $iq = shift;
	my $from = $iq->GetFrom();
	my $type = $iq->GetType();
	my $query = $iq->GetQuery();
	my $xmlns = $query->GetXMLNS();
	#printToLog("===");
	#printToLog("IQ");
	#printToLog("  From $from");
	#printToLog("  Type: $type");
	#printToLog("  XMLNS: $xmlns");
	#printToLog("===");
	#printToLog($iq->GetXML());
	#printToLog("===");
}

################################################################################
sub InPresence {
	my $sid = shift;
	my $presence = shift;
	my $from = $presence->GetFrom();
	my $type = $presence->GetType();
	my $status = $presence->GetStatus();
	#printToLog("===");
	#printToLog("Presence");
	#printToLog("  From $from");
	#printToLog("  Type: $type");
	#printToLog("  Status: $status");
	#printToLog("===");
	#printToLog($presence->GetXML());
	#printToLog("===");
}

################################################################################
sub printToLog {
	my $logMsg = shift;
	chomp(my $today = `date +"%Y-%m-%d"`);
	my $logFile = $cfg->val('Main', 'logpath') . '/nwws_' . $today . '.log';
	#print "**DEBUG** \$logFile = $logFile\n";
	open(LOG, '>>' . $logFile) or die $!;
	print LOG $logMsg . "\n";
	close(LOG);
}

__DATA__
$VAR1 = {
          'body' => 'KSGX issues MWW valid 2016-12-16T04:26:00Z',
          'from' => 'nwws@conference.nwws-oi.weather.gov/nwws-oi',
          'html' => {
                    'body' => {
                              'content' => 'KSGX issues MWW valid 2016-12-16T04:26:00Z',
                              'xmlns' => 'http://www.w3.org/1999/xhtml'
                            },
                    'xmlns' => 'http://jabber.org/protocol/xhtml-im'
                  },
          'to' => 'jim.buitt@nwws-oi.weather.gov/wxnotify',
          'type' => 'groupchat',
          'x' => {
                 'awipsid' => 'MWWSGX',
                 'cccc' => 'KSGX',
                 'content' => '

839

WHUS76 KSGX 160426

MWWSGX



URGENT - MARINE WEATHER MESSAGE

NATIONAL WEATHER SERVICE SAN DIEGO CA

826 PM PST THU DEC 15 2016



...VERY STRONG WINDS AND LARGE SEAS FRIDAY AND FRIDAY NIGHT...



.GUSTY SOUTHWEST WINDS FROM 15 TO 20 KT TONIGHT WILL SHIFT TO THE

WEST WITH THE PASSAGE OF A STRONG COLD FRONT FRIDAY MORNING. THE

STRONGEST WINDS AND LARGEST SEAS ARE EXPECTED FRIDAY AFTERNOON

AND FRIDAY NIGHT WITH SUSTAINED WINDS OF 20 TO 30 KT. GUSTS MAY

APPROACH GALE FORCE. THE STRONG WINDS...LARGE COMBINED SEAS...AND

STEEP WAVES WILL CREATE DANGEROUS BOATING CONDITIONS. WINDS AND

SEAS WILL DECREASE SATURDAY.



PZZ750-775-161400-

/O.CON.KSGX.SC.Y.0021.161216T0800Z-161217T1600Z/

COASTAL WATERS FROM SAN MATEO POINT TO THE MEXICAN BORDER AND OUT

TO 30 NM-

WATERS FROM SAN MATEO POINT TO THE MEXICAN BORDER EXTENDING 30 TO

60 NM OUT INCLUDING SAN CLEMENTE ISLAND-

826 PM PST THU DEC 15 2016



...SMALL CRAFT ADVISORY REMAINS IN EFFECT FROM MIDNIGHT TONIGHT

TO 8 AM PST SATURDAY...



* WINDS...SOUTH WINDS 15 TO 20 KT TONIGHT...BECOMING WEST 20 TO 30

  KT FRIDAY MORNING. STRONGEST WINDS WILL OCCUR FRIDAY AFTERNOON

  AND EVENING WITH A FEW GUSTS APPROACHING GALE FORCE.



* WAVES/SEAS...COMBINED SEAS 8 TO 12 FT OVER THE OUTER COASTAL

  WATERS AND 6 TO 10 FT OVER THE INNER COASTAL WATERS ON FRIDAY.



PRECAUTIONARY/PREPAREDNESS ACTIONS...



A SMALL CRAFT ADVISORY MEANS THAT WIND SPEEDS OF 21 TO 33 KNOTS

AND COMBINED SEAS OF 10 FEET OR GREATER ARE EXPECTED TO PRODUCE

HAZARDOUS WAVE CONDITIONS TO SMALL CRAFT. INEXPERIENCED

MARINERS...ESPECIALLY THOSE OPERATING SMALLER VESSELS SHOULD

AVOID NAVIGATING IN THESE CONDITIONS.



&&



$$



MOEDE

',
                 'id' => '3328.10565',
                 'issue' => '2016-12-16T04:26:00Z',
                 'ttaaii' => 'WHUS76',
                 'xmlns' => 'nwws-oi'
               }
        };
Use of uninitialized value in concatenation (.) or string at ./nwws2.pl line 146.
