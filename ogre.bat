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

use strict;
use warnings;
use XML::LibXML;
use XML::Simple qw(:strict);

package HtmlParser;
use POSIX qw(strftime);
use base qw(HTML::Parser);
use File::Basename;
use File::Find;
use DateTime::Format::Strptime;
use DateTime::Format::RFC3339;
use Data::Dumper; 

my %allIncludeFiles;
my $p;
my $brand = "";
my $html = "";
my %variableMap;
my %globalVariables;
my @customTags;
my @customText;
my @xmlDocStack;
my $notificationType;

my $DEBUG_INCLUDE_FILES = 0;
my $DEBUG_VARIABLE_MAP  = 0;

my $GLOBAL_PACKAGE_NUMBER = "PackageNumber";
my $GLOBAL_PAYMENT_NUMBER = "PaymentNumber";

# -----------------------------------------------------------------------------
sub validateBrandIdentifier($) {
   my $brand = shift;
   if ($brand ne "GC") {
      die "Could not find brand.\n";
   }
}

# -----------------------------------------------------------------------------
sub actualFilenameForBrand($) {
   my $originalBaseFilename = shift;
   my $filename = $originalBaseFilename . "-${brand}.inc";
   my $actualFilename = $allIncludeFiles{lc($filename)};
   print "Tried $filename\n" if ($DEBUG_INCLUDE_FILES);
   if ( ! defined($actualFilename)) {
      $filename = $originalBaseFilename . ".inc";
      print "Tried $filename\n" if ($DEBUG_INCLUDE_FILES);
      $actualFilename = $allIncludeFiles{$filename};
   }
   
   print "Looking for <$originalBaseFilename>\n" if ($DEBUG_INCLUDE_FILES);
   if (defined($actualFilename)) {
      print "Found <", $actualFilename, ">\n" if ($DEBUG_INCLUDE_FILES);
   } else {
      print "No find for <$originalBaseFilename>\n";
      foreach my $f (sort(keys(%allIncludeFiles))) {
         print "\t>", $f, "< \n";
      }
   }

   return $actualFilename;
}

# -----------------------------------------------------------------------------
sub slurpFile($) {
   my $file = shift;
   my $s = "";
   open(IN, $file) || die "Couldn't open $file\n$!\n";
   while (<IN>) {
      $s .= $_;
   }
   return $s;
}

# -----------------------------------------------------------------------------
sub validate_xml_against_xsd($$) {
    my ($xml, $xsd) = @_;

    my $schema = XML::LibXML::Schema->new(location => $xsd);
    my $parser = XML::LibXML->new;

    my $doc = $parser->parse_file($xml);
    eval { $schema->validate( $doc ) };

    if ( my $ex = $@ ) {
        return $ex;
    }
    return;
}
# -----------------------------------------------------------------------------
sub includeFile($) {
   my $actualFilename = shift;
   print "includeFile ", $actualFilename, "\n" if ($DEBUG_INCLUDE_FILES);
   
   my $p = new HtmlParser;
   $p->parse_file($actualFilename) || die $!;
}

# -----------------------------------------------------------------------------
sub importIncludeFile($) {
   my $baseFilename = shift;
   print "importIncludeFile ", $baseFilename, "\n" if ($DEBUG_INCLUDE_FILES);
   
   my $actualFilename = "";
   $actualFilename = actualFilenameForBrand($baseFilename);

   includeFile($actualFilename);
}

# -----------------------------------------------------------------------------
sub loadModule($) {
   my $notificationType = shift;
   my $moduleName = getModule($brand, $notificationType);
   
   if ($moduleName eq "") {
      die "Got request for <$notificationType> but I couldn't determine which module to use.\n";
   }
   
   my $moduleFilename = "transactional\\coded\\modules\\${moduleName}.inc";

   print "  Module is $moduleName ($moduleFilename)\n";
   die "Couldn't find $moduleFilename" if ( ! -e $moduleFilename);
   includeFile($moduleFilename);
}

# -----------------------------------------------------------------------------
sub replaceBracketedTags($) {
   my $s = shift;

   my %vars = (
      "[PRODUCT_IMAGE]"    => "PRODUCT_IMAGE",
      "[PRODUCT_NAME]"     => "PRODUCT_NAME",
      "[SOURCE_CODE]"      => "SOURCE_CODE",
      "[TRACKING_URL]"     => "TRACKING_URL",
   );
   
   if (@xmlDocStack == 0) {      
      ## Some variables are only valid in the base document, so add them here
      $vars{"[ORDER_NUM]"}    = "ORDER_NUM";
   }
   
   foreach my $key (keys(%vars)) {
      my $val = $vars{$key};
      ## Bracketed fields can be looked up conditionally because we'll barf if they aren't found anyway
      $val = getValueForField($val, 0);
      $key = quotemeta($key);
      $s =~ s/$key/$val/g;
   }
   
   die "\n\nFound bracket in $s after all brackets should have been replaced\n\n" if ($s =~ /[\[\]]/);
   return $s;
}

# -----------------------------------------------------------------------------
sub loadVariableMap() {
   open(IN, "variable_map.txt") || die "Couldn't open variable_map.txt\n$!\n";
   
   my $notificationType = "";
   my $var = "";
   my $xpath = "";
   while (<IN>) {
      unless (/^\#/) {
         if (/^\[.*\]/) {
            $notificationType = $_;
            $notificationType =~ s/[\[\]\s]//g;
            $notificationType .= "/";
         } else {
            ($var, $xpath) = split(/\s*=\s*/, $_, 2);
            chomp($xpath) if (defined($xpath));
            $variableMap{$notificationType . $var} = $xpath;
         }
      }
   }
   close(IN);
}

# -----------------------------------------------------------------------------
$p = new HtmlParser;

find(\&findAllIncludeFiles, ".");

my $customDepth = 0;

my $xmlFile = "";
my $xsdFile = "";
my $file1   = "";

if (0 == 1) {
   $xmlFile = "MSC-OrderConfirm-Sample-kitItems+Warranty.xml";
   $xsdFile = "MSC-CDMOrderNotification.xsd";
   $file1   = "transactional\\coded\\base-template.html";
} else {
   $xmlFile = "sample_data_2014-05-06\\MSC-ShipConfirm-kitItems_Sample_1.xml";
   $xsdFile = "sample_data_2014-05-06\\MSC-CDMOrderNotification.xsd";
   $file1   = "transactional\\coded\\base-template.html";
}

my $outdir  = ".\\";
if (@ARGV == 4) {
   $xmlFile = $ARGV[0];
   $xsdFile = $ARGV[1];
   $file1   = $ARGV[2];
   $outdir  = $ARGV[3];
} elsif (@ARGV > 0) {
   die "This program expects 0 or 4 arguments.\n1. XML file\n2. XSD file\n3. Base template HTML/include\n4. Output directory\n";
}
$outdir .= "\\" unless ($outdir =~ /\\$/);

if ( my $error = validate_xml_against_xsd($xmlFile, $xsdFile) ) {
    die "Validation failed: $error\n";
}
die "Could not find base template $file1\n" if ( ! -e $file1);

print "Validated:\n\t$xmlFile\n\t$xsdFile\n\t$file1 is present\n";

my $xmlParser = XML::LibXML->new();
my $xmlDoc = $xmlParser->parse_file($xmlFile);
$notificationType = $xmlDoc->getDocumentElement()->getName();
loadVariableMap();

my $query = "$notificationType/OrderSource/Brand/\@brandID";
$brand = $xmlDoc->findnodes($query);
validateBrandIdentifier($brand);

print "Sending notification type: <$notificationType> for brand <$brand>\n";


$p->parse_file($file1) || die $!;

my $outputFile = "${outdir}out.html"; 
open(OUT, ">$outputFile") || die "Couldn't open $outputFile\n$!\n";
print "Writing output: \n\t$outputFile\n";
print OUT "" . localtime();
print OUT $html;
close(OUT);

## foreach my $f (sort(keys(%allIncludeFiles))) {
##    print $f, "\n";
## }


# -----------------------------------------------------------------------------
sub incrementCustomDepth() {
   $customDepth++;
   $customTags[$customDepth] = "";
   $customText[$customDepth] = "";
}

# -----------------------------------------------------------------------------
sub decrementCustomDepth() {
   $customTags[$customDepth] = "";
   $customText[$customDepth] = "";
   $customDepth--;
}

# -----------------------------------------------------------------------------
sub getSubject($$) {
   my ($brand, $notificationType) = @_;
   my @vars = getBrandNotificationVariables($brand, $notificationType);
   return $vars[0];
}

# -----------------------------------------------------------------------------
sub getSourceCode($$) {
   my ($brand, $notificationType) = @_;
   my @vars = getBrandNotificationVariables($brand, $notificationType);
   return $vars[1];
}

# -----------------------------------------------------------------------------
sub getModule($$) {
   my ($brand, $notificationType) = @_;
   my @vars = getBrandNotificationVariables($brand, $notificationType);
   return $vars[2];
}

# -----------------------------------------------------------------------------
sub getBrandNotificationVariables($$) {
   my ($brand, $notificationType) = @_;
   my $sourceCode = "";
   my $subject    = "";
   my $moduleName = "";
   if ($brand eq "GC") {
      if ($notificationType eq "ns0:OrderConfirmationNotification") {
         $sourceCode = "OrdConfSrc";
         $subject    = "Guitar Center Order Confirmation";
         $moduleName = "mod-order-confirmation";
      } elsif ($notificationType eq "ns0:ShipConfirmationNotification") {
         $sourceCode = "OrdShipSrc";
         $subject    = "Guitar Center Order Shipping Confirmation";
         $moduleName = "mod-order-shipped";
      } else {
         die "Unrecognized notification type ($notificationType) for brand ($brand) in getSourceCode()\n";
      }
   } else {
      die "Unrecognized brand ($brand) in getSourceCode()\n";
   }
   return ($subject, $sourceCode, $moduleName);
}

# -----------------------------------------------------------------------------
sub getValueForField($;$) {
   my ($variable, $mustFindVariable) = @_;
   my $s;
   
   $mustFindVariable = 1 unless(defined($mustFindVariable));
   
   if ($variable =~ /current_year/i) {
      $s = strftime("%Y", localtime());
   } elsif ($variable =~ /source_code/i) {
      $s = getSourceCode($brand, $notificationType);
   } else {
      $s = "PCR_$variable";
      
      my $localNotificationType = substr($notificationType, 4) . "/";
      $localNotificationType =~ s/\s//g;
      my $varToFind = $localNotificationType . uc($variable);

      if (defined($variableMap{$varToFind})) {
         ## First try to find the NotificationType's variable
         $s = $xmlDoc->findvalue($variableMap{$varToFind});
         #print "SEEK 1 $varToFind \n\txpath=$variableMap{$varToFind}\n\ts=$s\n";

         if (1 == 1) {
            my @nodes = $xmlDoc->findnodes($variableMap{$varToFind});
            #print "SEEK 1 $varToFind \n\txpath=$variableMap{$varToFind}\n\t$s\n\tnode count=" . (@nodes + 0) . "\n";
            if (@nodes > 0) {
               my $node = $nodes[0];
               $s = $node->textContent();
            }
         }
      } elsif (defined($variableMap{uc($variable)})) {
         ## Second try to find the general variable
         #print "SEEK 2 $variable\n";
         $s = $xmlDoc->findvalue($variableMap{uc($variable)});
      } elsif ($globalVariables{$variable}) {
         ## Second try to find the general variable
         #print "SEEK 3 $variable\n";
         $s = $xmlDoc->findvalue($globalVariables{$variable});
      } else {
         if ($mustFindVariable) {
            print "SEEK 4 $varToFind\n";
            if ($DEBUG_VARIABLE_MAP) {
               print "DYING DUMPING VARIABLE MAP\n";
               foreach my $key (sort(keys(%variableMap))) {
                  print "$key = <$variableMap{$key}>\n";
               }
            }
            die "\n\nFAILED TO FIND VARIABLE '$varToFind'\n";
         }
      }
      
   }

   return $s;
}

# -----------------------------------------------------------------------------
sub formatValueForHtml($$) {
   my ($value, $format) = @_;
   my $s;
   
   $format = "" if (!defined($format));
   
   if ($format =~ /date/i) {
      my $formatter = DateTime::Format::RFC3339->new();
      if ($value ne "") {
         print "Formatting date ($value)\n";
         my $date = $formatter->parse_datetime($value);
         $s = $date->strftime("%m/%d/%Y");
      } else {
         warn "FAILED TO CONVERT VALUE ($value) TO DATE\n";
         $s = "";
      }
   } elsif ($format =~ /currency/i) {
      $value = 0 if ($value eq "");
      $s = sprintf("%0.2f", $value);
   } elsif ($format =~ /number/i) {
      $value = 0 if ($value eq "");
      $s = sprintf("%0.0f", $value);
   } else {
      my %variable_map;
      $s = $value;
   }

   return $s;
}

# -----------------------------------------------------------------------------
sub pushXmlDoc($) {
   my ($newxmlDoc) = @_;
   push(@xmlDocStack, $xmlDoc);
   $xmlDoc = $newxmlDoc;
}

# -----------------------------------------------------------------------------
sub popXmlDoc() {
   $xmlDoc = pop(@xmlDocStack);
}

# -----------------------------------------------------------------------------
sub text {
   my ($self, $text) = @_;
   if ($text =~ /\<custom .*subject_line/i) {
      ## In <title> you can't have HTML tags so the <custom> tag has not been 
      ## parsed/processed so it comes in here and needs to be substituted
      addToHtml(getSubject($brand, $notificationType));
   } else {
      addToHtml($text);
   }
}

sub comment {
   my ($self, $comment) = @_;
   ## discarding comments
}

sub start {
   my ($self, $tag, $attributes, $attrseq, $origtext) = @_;
   my $saveOrigText = 1;
   if ($tag =~ /custom/i) {
      $saveOrigText = 0;
      if ($attributes->{"type"} =~ /file/i) {
         die "Could not find 'name' attribute for 'file' in 'custom' tag\n>>>$origtext\n" if ($attributes->{"name"} eq "");
         if (defined($attributes->{"repeatable"}) && $attributes->{"repeatable"} eq "yes") {
            ## print "\t\t$attributes->{'name'} is REPEATABLE\n";
            if ($attributes->{'name'} eq "product-detail") {
               my $xpathToOrderItems = "//OrderedItem";
               if ($notificationType eq "ShipConfirmationNotification") {
                  $xpathToOrderItems = "//ContainerItem";
               }
            
               my @orderedItems = $xmlDoc->findnodes($xpathToOrderItems);

               for (my $itemCount = 0; $itemCount < @orderedItems; $itemCount++) {
                  ## Creating a new document only for this OrderedItem
                  my $treeForItem = XML::LibXML->load_xml(string => $orderedItems[$itemCount]);
                  my $documentForItem = $treeForItem->getDocumentElement;

                  pushXmlDoc($documentForItem);
                  
                  ## print "\n\n$itemCount\n", $orderedItems[$itemCount], "\n";
                  importIncludeFile($attributes->{"name"});
                  
                  popXmlDoc();
               }
               
            } elsif ($attributes->{'name'} eq "product-kit") {
               ## If we found a kit, then we must be in a product so our XMLDOC should be a product
               my @kitItems = $xmlDoc->findnodes('//Component');               
               
               for (my $kitCount = 0; $kitCount < @kitItems; $kitCount++) {
                  ## Creating a new document only for this Kit
                  my $treeForKit = XML::LibXML->load_xml(string => $kitItems[$kitCount]);
                  my $documentForKit = $treeForKit->getDocumentElement;

                  pushXmlDoc($documentForKit);
               
                  importIncludeFile($attributes->{"name"});

                  popXmlDoc();
               }
               
            } elsif ($attributes->{'name'} eq "order-shipped-payment") {
               warn "\n\n\tREPEAT order-shipped-payment HAS NOT BEEN TESTED\n\n";
               my @paymentDetails = $xmlDoc->findnodes('//ShippingGroup/ShippingGroupTotal');
               $globalVariables{$GLOBAL_PAYMENT_NUMBER} = 0;
               for (my $paymentDetails = 0; $paymentDetails < @paymentDetails; $paymentDetails++) {
                  $globalVariables{$GLOBAL_PAYMENT_NUMBER}++;
                  my $treeForPayment = XML::LibXML->load_xml(string => $paymentDetails[$paymentDetails]);
                  my $documentForPayment = $treeForPayment->getDocumentElement;

                  pushXmlDoc($documentForPayment);
               
                  importIncludeFile($attributes->{"name"});

                  popXmlDoc();
               }
               $globalVariables{$GLOBAL_PAYMENT_NUMBER} = 0;
            } elsif ($attributes->{'name'} eq "order-shipped-product-pkg") {
               warn "\n\n\tREPEAT order-shipped-product-pkg HAS NOT BEEN TESTED\n\n";
               print "Went into order-shipped-product-pkg\n";
               my @shippedPackages = $xmlDoc->findnodes('//ShippingGroup/ShipContainerDetails');
               $globalVariables{$GLOBAL_PACKAGE_NUMBER} = 0;
               for (my $packageCount = 0; $packageCount < @shippedPackages; $packageCount++) {
                  $globalVariables{$GLOBAL_PACKAGE_NUMBER}++;
                  my $treeForPackage = XML::LibXML->load_xml(string => $shippedPackages[$packageCount]);
                  my $documentForPackage = $treeForPackage->getDocumentElement;

                  pushXmlDoc($documentForPackage);
               
                  importIncludeFile($attributes->{"name"});

                  popXmlDoc();
               }
               $globalVariables{$GLOBAL_PACKAGE_NUMBER} = 0;
            } else {
               die "Found a REPEATABLE '$attributes->{'name'}', but I don't recognize that name.\n";
            }
            
         } else {
            importIncludeFile($attributes->{"name"});
         }         
         
      } elsif ($attributes->{"type"} =~ /module/i) {
         loadModule($notificationType);
      } elsif ($attributes->{"type"} =~ /image/i) {
         $origtext =~ s/\<custom/\<img/i;
         $origtext = replaceBracketedTags($origtext);
         $saveOrigText = 1;
      } elsif ($attributes->{"type"} =~ /anchor/i) {
         incrementCustomDepth();
         $customTags[$customDepth] = $attributes;
         #print "($self, $tag, $attributes, $attrseq, $origtext)\n";
      } elsif ($attributes->{"type"} =~ /field/i) {
         if ($origtext =~ /\/\>$/) {
            my $value = getValueForField($attributes->{'name'});
            addToHtml(formatValueForHtml($value, $attributes->{'format'}));
         } else {
            incrementCustomDepth();
            $customTags[$customDepth] = $attributes;
            #print "($self, $tag, $attributes, $attrseq, $origtext)\n";
         }
      } else {
         die "Did not recognize 'custom' type\n>>>$origtext\n";
      }
   #} else {
   #   print "Called start $tag\n";
   }
   
   if ($saveOrigText) {
      addToHtml($origtext);
   }
   #print "\nORIG:$origtext", "\n";
}

sub end {
   my ($self, $tag, $origtext) = @_;
   if ($origtext eq "</custom>") {
      ## print "CUSTOMTEXT\n>>$customText[$customDepth]\n<<\n";
      $a = $customTags[$customDepth];
      
      if (ref($a) ne "HASH") {
         die "Got to end() at depth $customDepth using $customText[$customDepth]\n and \$a is not a HASH\n";
      }

      if ($a->{"type"} =~ /field/ && defined($a->{"optional"}) && $a->{"optional"} =~ /yes/i) {
         if (defined($a->{"minvalue"})) {
            my $value = getValueForField($a->{'name'});
            ## print "\n\tvalue for $a->{'name'} is $value and min=$a->{'minvalue'}\n";
            if (($value + 0) >= ($a->{'minvalue'} + 0)) {
               ## print "\tAPPENDING " . formatValueForHtml($value, $a->{'format'}) . "\n\tPLUS $customText[$customDepth]\n";
               #$html .= formatValueForHtml($value, $a->{'format'});
               $html .= $customText[$customDepth];
            } else {
               print "\tDID NOT MEET minvalue " . formatValueForHtml($value, $a->{'format'}) . "\n";
            }
            
            #decrementCustomDepth();
         } else {
            
            my $value = getValueForField($a->{'name'});
            
            ## For a simple optional field, do not display if value is empty/MIA
            if ($value ne "") {
               $html .= $customText[$customDepth];
            }
            
            ## print "\nNAME=($a->{'name'})\nVALUE=($value) (" . ($value ne "") . ")\n" if ($a->{'name'} =~ /kit/i);
         }
         
         
      } elsif ($a->{"type"} =~ /anchor/i) {
         my $newAnchor = "<a ";
         foreach my $k (sort(keys($a))) {
            if ( ! ($k =~ /type/i)) {
               $newAnchor .= "$k=\"$a->{$k}\" ";
            }
         }
         $newAnchor = replaceBracketedTags($newAnchor);
         $newAnchor .= ">$customText[$customDepth]</a>";

         ## print "\$newAnchor=\n\n$newAnchor\n\n";
         ## print "\$customText was=\n\n$customText[$customDepth]\n\n";
         
         ##exit(1) if ($customText[$customDepth] =~ /order details/i);
         $html .= $newAnchor;
      }
      
      decrementCustomDepth();
   } else {
      addToHtml($origtext);
   }
}

# -----------------------------------------------------------------------------
sub addToHtml() {
   my $s = shift;
   if ($customDepth) {
      $customText[$customDepth] .= $s;
   } else {
      $html .= $s;
   }
}

# -----------------------------------------------------------------------------
sub findAllIncludeFiles() {
   if ($_ =~ /\.inc$/i) {
      $allIncludeFiles{lc($_)} = $File::Find::name;
      $allIncludeFiles{lc($_)} =~ s|/|\\|g;  ## system func returns / for path separator so I'm replacing
   }
}

# -----------------------------------------------------------------------------
__END__
:endofperl

endlocal
:pause
