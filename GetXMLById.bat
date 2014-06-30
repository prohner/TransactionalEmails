@rem = '--*-Perl-*--

@echo off
cls
setlocal 

y:\perl64 -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9 
:: > %0.log

goto endofperl
@rem ';
# -----------------------------------------------------------------------------

use strict;
use warnings;
use DBI;

use XML::LibXML;

use POSIX qw(strftime);
use base qw(HTML::Parser);

use Data::Dumper;
use JSON;

my $dbh;
my $sth;
my $DSN = "Driver={SQL Server Native Client 10.0};Server=gcdb2;Database=gcProd;Trusted_Connection=yes;";

my $sql = <<EOT;
   select 'TransactionalEmailTest' sourceTable, * 
     from gcprod.dbo.TransactionalEmailTest 
    where TransactionalEmailId = $ARGV[0]
   union
   select 'TransactionalEmail'     sourceTable, * 
     from gcprod.dbo.TransactionalEmail     
    where TransactionalEmailId = $ARGV[0]
EOT

print $sql, "\n";
my $outfile = "output\\DB_$ARGV[0].xml";
$dbh = DBI->connect("dbi:ODBC:$DSN") || die "Couldn't connect to database: " . DBI->errstr;

$dbh->{LongReadLen} = 512 * 1024;
$sth = $dbh->prepare($sql) || die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute() || die "Couldn't execute statement: " . $sth->errstr;

if (my $rs = $sth->fetchrow_hashref) {
   my $xmlParser = XML::LibXML->new();
   my $xmlDoc = $xmlParser->load_xml(string => $rs->{"Contents"});

   print "Writing $outfile\n";
   open(OUT, ">$outfile") || die "Couldn't open $outfile\n$!\n";
   print OUT $xmlDoc->toString(1);
   close(OUT);
} else {
   print "Seems like we couldn't find $ARGV[0]\n";
}

exit(0);

# -----------------------------------------------------------------------------
sub ShellOutAndRun() {
   my $cmd = shift;

   print "$cmd\n";
   system($cmd);
   if ($? >> 8) {
      die "Error executing ($cmd)\nERR MSG:($!)\n";
   }
}

# -----------------------------------------------------------------------------
__END__
:endofperl

endlocal
:pause
