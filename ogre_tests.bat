@rem = '--*-Perl-*--
::
:: Shrek: Layers. Onions have layers. Ogres have layers. Onions have layers. You get it? 
::

@echo off
cls
setlocal 

y:\perl64 -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9 
:: > %0.log

goto endofperl
@rem ';
# -----------------------------------------------------------------------------

sub runTestFromDirectory($) {
   my $dir = shift;
   print "TEST $dir\n";
   
   opendir(my $dh, $dir) || die "can't opendir $dir: $!";
   my @testDirContents = grep { ! /^\./ } readdir($dh);
   closedir $dh;
   
   my $xml;
   my $xsd;
   my $html;
   
   for (my $i = 0; $i < @testDirContents; $i++) {
      if ($testDirContents[$i] =~ /\.xml/i) {
         $xml = $testDirContents[$i];
      } elsif ($testDirContents[$i] =~ /\.xsd/i) {
         $xsd = $testDirContents[$i];
      } else {
         $html = $testDirContents[$i];
      }
   }
   
   my $cmd = qq(ogre "${dir}\\${xml}" "${dir}\\${xsd}" "${dir}\\${html}" "${dir}");
   print $cmd, "\n";
   my $res = system($cmd);
   if ($? >> 8) {
      print $res, "\n";
      print $cmd, "\n";
      print "\n\n\tError running tests in $dir\n\nPress any key...";
      `pause`;
      die "\n\n\tError running tests in $dir\n\n";
   }
}

# -----------------------------------------------------------------------------
use strict;
use warnings;
use File::Basename;
use File::Find;

my $testDir = "tests";
opendir(my $dh, $testDir) || die "can't opendir $testDir: $!";
my @all_dirs = grep { ! /^\./ } readdir($dh);
closedir $dh;

for (my $i = 0; $i < @all_dirs; $i++) {
   $all_dirs[$i] = "${testDir}\\$all_dirs[$i]";
   if (-d $all_dirs[$i]) {
      runTestFromDirectory($all_dirs[$i]);
   }
}


__END__
:endofperl

endlocal
:pause
