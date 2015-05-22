# -----------------------------------------------------------------------------

use strict;
use warnings;
use XML::LibXML;
use XML::Simple qw(:strict);
use POSIX;
use DBI;


my $dbh;
my $dbhUpdate;
my $sth;
my $rs;
my $filename = "${0}_email.html";

my $DSN 				= "Driver={SQL Server Native Client 10.0};Server=gcdb2;Database=gcProd;Trusted_Connection=yes;";

$dbh = DBI->connect("dbi:ODBC:$DSN") || die "Couldn't connect to database: " . DBI->errstr;
$dbh->{LongReadLen} = 1024 * 1024;

my $sql =<<EOT;
   select 'TransactionalEmailTest' sourceTable, count(*) [UnprocessedRecords]
     from gcprod.dbo.TransactionalEmailTest with (nolock)
    where DateProcessedForEmail is null
      and contents like '%<?xml%'
      and EmailProcessResult is null
      and contents like '%CDMOrderNotification%'
   union
   select 'TransactionalEmail'     sourceTable, count(*) 
     from gcprod.dbo.TransactionalEmail with (nolock)
    where DateProcessedForEmail is null
      and EmailProcessResult is null
EOT

$sth = $dbh->prepare($sql) || die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute() || die "Couldn't execute statement: " . $sth->errstr;

my $html =<<HTML;
<html>
 <head>
 	<title>Unsent Email</title>
 	<style type="text/css">
 		p { clear: left; width: 50%; }
 	</style>
 </head>
 <body>
<div>
<table align="left" border=1 cellspacing=0 cellpadding=0 style="border-color:#d9d9d9;">
<tr align="left" valign="middle">
	<th>Source Table</th>
	<th>Record Count</th>
</tr>
HTML

my $totalUnprocessed = 0;
my $needToSendEmail = 0;
print "\n\n";
while ($rs = $sth->fetchrow_hashref) {
	my $sourceTable            = $rs->{'sourceTable'};
	my $unprocessedCount      	= $rs->{'UnprocessedRecords'};
	$totalUnprocessed 			+= $unprocessedCount;
	
	if ($sourceTable eq "TransactionalEmail" && $unprocessedCount > 5) {
		$needToSendEmail = 1;
	} elsif ($sourceTable eq "TransactionalEmailTest" && $unprocessedCount > 25) {
		$needToSendEmail = 1;
	}

	$unprocessedCount = commify($unprocessedCount);	
	print "$sourceTable has $unprocessedCount unprocessed records.\n";
	
	$html .= "<tr>"
			.  "<td>$sourceTable</td><td align=right>$unprocessedCount</td>"
	  		.  "</tr>"
}

$html .= "<tr>"
		.  "<th align=right>Total:</th><th align=right>" . commify($totalUnprocessed) . "</th>"
		.  "</tr>"
		. "</table>"
		. "</div>";
		
if ($needToSendEmail) {
	SendEmailNotification($html) ;
} else {
	print "Conditions do not warrant sending email.\n";
}

##unlink($filename);
print "\n\n";


# Adds commas to numbers for printing purposes --------------------------------
sub commify {
    local($_) = shift;
    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}

# -----------------------------------------------------------------------------
sub SendEmailNotification {
   my $html = shift;
   
   open(EMAIL, ">$filename") || die "Couldn't open file $filename\n$!\n";
   
   my $subject = strftime("Ogre Unprocessed Records %Y-%m-%d at %H:%M:%S", localtime());

   print EMAIL "$html\n";

   print EMAIL "<p>These counts show how many Guitar Center transactional email records have not been sent.  I think they should have been sent, so check out the transactional email processing to make sure it's picking up and sending email.</p><hr size=1  width=\"100%\"/>\n";
   print EMAIL "<p><font size=1>This script is: $0</font></p>\n";
   print EMAIL "<p><font size=1>$sql</font></p>\n";

   close(EMAIL);

   my @d= split(' ', localtime(time));
   my $dayOfWeekName = $d[0];

   my @recipients = "";
   if (1 == 0) {
      push @recipients, "prohner\@mscnet.com(Preston Rohner)";
   } else {
      push @recipients, "prohner\@mscnet.com(Preston Rohner)";
   }
   
   my $recipients = "";
   for (my $i = 0; $i < @recipients; $i++) {
      $recipients .= qq( -to:"$recipients[$i]");
   }
   
   my $cmd = "y:\\util\\postie -host:mail.mscnet.com $recipients -from:\"preston\@mscnet.com(Preston Rohner)\" -s:\"$subject\" -file:\"$filename\" -html -high";
   ShellOutAndRun($cmd);

}


# -----------------------------------------------------------------------------
sub ShellOutAndRun() {
   my $cmd = shift;

   print "$cmd\n";
   system($cmd);
   if ($? >> 8) {
      die "Error executing ($cmd)\nERR MSG:($!)\n";
   }
}
