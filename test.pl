use DBI;
my $DSN = "dbi:ODBC:Driver={SQL Server Native Client 10.0};Server=gcdb2;Database=gcProd;Trusted_Connection=yes;";

my $dbh = DBI->connect($DSN)
                or die "Couldn't connect to database: " . DBI->errstr;
$dbh->{LongReadLen} = 512 * 1024;
                
my $sql = <<EOT;
select 'TransactionalEmailTest' sourceTable, [ServerSource] as x, Contents --, * 
  from gcprod.dbo.TransactionalEmailTest 
 where DateProcessedForEmail is null
union
select 'TransactionalEmail'     sourceTable, [ServerSource] as x, Contents --, * 
  from gcprod.dbo.TransactionalEmail     
 where DateProcessedForEmail is null
EOT

                
my $sth = $dbh->prepare($sql)
                or die "Couldn't prepare statement: " . $dbh->errstr;

$sth->execute()             # Execute the query
            or die "Couldn't execute statement: " . $sth->errstr;

          # Read the matching records and print them out          
          print "Near loop\n";
          while (@data = $sth->fetchrow_array()) {
            my $firstname = $data[0];
            my $id = $data[1];
            my $contents = $data[2];
            print "\t$id: $firstname $lastname\n";
            print "$contents\n";
          }

          if ($sth->rows == 0) {
            print "No names matched `$lastname'.\n\n";
          }

          
        $dbh->disconnect;
