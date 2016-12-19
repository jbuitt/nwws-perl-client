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
	my @tmpArray = split(/\./, $newref->{'id'});
	my @rightnow_gmt = gmtime(time());
	$rightnow_gmt[1] .= '0' . $rightnow_gmt[1] if length($rightnow_gmt[1]) == 1;
	$rightnow_gmt[2] .= '0' . $rightnow_gmt[2] if length($rightnow_gmt[2]) == 1;
	my $newId = substr($rightnow_gmt[5]+1900, 2, 2) . $rightnow_gmt[2] . $rightnow_gmt[1] . '_' . substr(time(), 0, 3) . substr($tmpArray[1], 0, 5);
	my $file = lc($newref->{'cccc'}) . '_' . lc($newref->{'ttaaii'}) . '-' . lc($newref->{'awipsid'}) . '.' . $newId . '.txt';
	open(OUTFILE, '>' . $cfg->val('Main', 'archivedir') . '/' . lc($newref->{'cccc'}) . '/' . $file) or die $!;
	my @lines = split(/\n\n/, $newref->{'content'});
	for(my $i=0; $i<@lines; $i++) {
		print OUTFILE $lines[$i] . "\n";
	}
	close(OUTFILE);
	# Perform Product Arrival Notification (PAN) action, if it exists and is executable
	if (defined($cfg->val('Main', 'panrun'))) {
		if ( -x $cfg->val('Main', 'panrun')) {
			my $cmd = $cfg->val('Main', 'panrun') . ' ' . $cfg->val('Main', 'archivedir') . '/' . lc($newref->{'cccc'}) . '/' . $file;
			my @output = `$cmd`;
			if (scalar(@output) != 0) {
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
