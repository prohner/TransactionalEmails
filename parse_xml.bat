@rem = '--*-Perl-*--
@echo off
cls
setlocal 

y:\perl64 -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9 
:: > %0.log

goto endofperl
@rem ';
# -----------------------------------------------------------------------------

use XML::LibXML;
use XML::Simple qw(:strict);
use strict;
use warnings;

# -----------------------------------------------------------------------------
sub ProcessOrderConfirmationNotification() {
    print "ProcessOrderConfirmationNotification\n";
}

# -----------------------------------------------------------------------------

my $file = "MSC-OrderConfirm-Sample-kitItems.xml";

my $orderNotification = XMLin($file, ForceArray => 1, KeyAttr => {});
print "Simple\n";
foreach my $b (@{$orderNotification->{OrderSource}}) {
    print $b->{ChannelID}->[0], "\n";
}



print "LibXML\n";

my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($file);

my $isbn = "whatev";
my $query  = "/";

my $notificationType = $doc->getDocumentElement()->getName();
print "Notification type: <$notificationType>\n";

if ($notificationType eq "ns0:OrderConfirmationNotification") {
    ProcessOrderConfirmationNotification();
} else {
    die "\n\n\tUnknown notification type: <$notificationType>\n";
}

##print $doc->getDocumentElement, "\n";
##print $_->data . "\n" foreach ($doc->findnodes($query));

## my %dist;
## proc_node( $doc->getDocumentElement, \%dist, "" );
## foreach my $item ( sort keys %dist ) {
##     print "$item: ", $dist{ $item }, "\n";
## }

## my $rootel = $doc->getDocumentElement();
## print "\nROOTEL name:" , $rootel->getName(), "\n";

print "\n\n\tALL DONE\n";

# -----------------------------------------------------------------------------
# process an XML tree node: if it's an element, update the
# distribution list and process all its children
#
sub proc_node {
    my( $node, $dist, $name ) = @_;
    return unless( $node->nodeType eq &XML_ELEMENT_NODE );
    $dist->{ $name . "/" . $node->nodeName } ++;
    foreach my $child ( $node->getChildnodes ) {
        &proc_node( $child, $dist, $name . "/" . $node->nodeName );
    }
}

# -----------------------------------------------------------------------------
__END__
:endofperl

endlocal
:pause
