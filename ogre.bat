@rem = '--*-Perl-*--
::
:: Shrek: Layers. Onions have layers. Ogres have layers. Onions have layers. You get it? 
::        (plus this program is big and ugly)
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
my $xmlDoc;

my $DEBUG_INCLUDE_FILES             = 0;
my $DEBUG_VARIABLE_MAP              = 0;
my $DEBUG_HTML_START_AND_END_CUSTOM = 0;

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
      if ($originalBaseFilename =~ /\.inc/i) {
         print "\n\nORIGINAL NAME CONTAINS .inc, BUT IT SHOULD NOT.  THIS IS PROBABLY THE PROBLEM.\n\n";
      }
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

   print "  Module ($moduleFilename)\n";
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
      "[RETURN_LABEL_URL]" => "RETURN_LABEL_URL",
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
sub processXmlFile($$$) {
   my ($xmlFile, $xsdFile, $file1) = @_;
   print "-" x 60, "\n"; ## Processing:\n\t$xmlFile\n\t$xsdFile\n\t$file1 is present\n";
   if ( my $error = validate_xml_against_xsd($xmlFile, $xsdFile) ) {
       die "Validation failed: $error\n";
   }
   die "Could not find base template $file1\n" if ( ! -e $file1);
   
   $html = "";

   print "Validated:\n\t$xmlFile\n\t$xsdFile\n\t$file1 is present\n";

   my $xmlParser = XML::LibXML->new();
   $xmlDoc = $xmlParser->parse_file($xmlFile);
   $notificationType = $xmlDoc->getDocumentElement()->getName();
   loadVariableMap();

   my $query = "$notificationType/OrderSource/Brand/\@brandID";
   $brand = $xmlDoc->findnodes($query);
   validateBrandIdentifier($brand);

   print "Sending notification type: <$notificationType> for brand <$brand>\n";


   $p->parse_file($file1) || die $!;

   my ($volume, $directories, $outputFile) = File::Spec->splitpath($xmlFile);
   $outputFile =~ s/\.xml/\.html/ig;
   $outputFile = "output\\$outputFile";

   open(OUT, ">$outputFile") || die "Couldn't open $outputFile\n$!\n";
   print "Writing output: \n\t$outputFile\n";
   ## print OUT "" . localtime();
   print OUT $html;
   close(OUT);

   ## foreach my $f (sort(keys(%allIncludeFiles))) {
   ##    print $f, "\n";
   ## }
}

# -----------------------------------------------------------------------------
$p = new HtmlParser;

find(\&findAllIncludeFiles, ".");

my $customDepth = 0;

my $xmlFile = "";
my $xsdFile = "";
my $file1   = "";

my @testFiles = (
   "sample_data_2014-05-23\\E1-Return-Auth-MSC.xml",
   ## "sample_data_2014-05-23\\F1-Return-Receive-MSC.xml",
   ## "MSC-OrderConfirm-Sample-kitItems+Warranty.xml",
   ## "sample_data_2014-05-06\\MSC-ShipConfirm-kitItems_Sample_1.xml",
   ## "sample_data_2014-05-06\\MSC-ShipConfirm-kitItems_Sample_2.xml",
   ## "sample_data_2014-05-07\\MSC-OrderCancel-Sample_1.xml",
   ## "sample_data_2014-05-16\\MSC_BackOrder_sample1.xml",
   ## "sample_data_2014-05-16\\MSC_BackOrder_sample2.xml",
   ## "sample_data_2014-05-22\\B7-ShipConfirm-MSC.xml",
);

my $outdir  = ".\\";
if (@ARGV == 4) {
   $xmlFile = $ARGV[0];
   $xsdFile = $ARGV[1];
   $file1   = $ARGV[2];
   $outdir  = $ARGV[3];
} elsif (@ARGV > 0) {
   die "This program expects 0 or 4 arguments.\n1. XML file\n2. XSD file\n3. Base template HTML/include\n4. Output directory\n";
} else {
   foreach (@testFiles) {
      processXmlFile($_, "sample_data_2014-05-22\\MSC-CDMOrderNotification.xsd", "transactional\\coded\\base-template.html");
   }
}
$outdir .= "\\" unless ($outdir =~ /\\$/);


# -----------------------------------------------------------------------------
sub incrementCustomDepth() {
   $customDepth++;
   $customTags[$customDepth] = "";
   $customText[$customDepth] = "";
}

# -----------------------------------------------------------------------------
sub decrementCustomDepth() {
   my $s = $customText[$customDepth];
   $customTags[$customDepth] = "";
   $customText[$customDepth] = "";
   $customDepth--;
   addToHtml($s);
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
   
   my %vars = (
      "GC" => {"ns0:OrderConfirmationNotification" => ["OrdConfSrc",
                                                       "Guitar Center Order Confirmation",
                                                       "mod-order-confirmation"],
               "ns0:ShipConfirmationNotification"  => ["OrdShipSrc",
                                                       "Guitar Center Order Shipping Confirmation",
                                                       "mod-order-shipped"],
               "ns0:OrderCancelNotification"       => ["OrdCancSrc",
                                                       "Item cancellation",
                                                       "mod-order-cancellation"],
               "ns0:BackOrderNotification"         => ["BackOrdSrc",
                                                       "Item cancellation",
                                                       "mod-order-backorder"],
               "ns0:ReturnAuthNotification"        => ["RetAuthSrc",
                                                       "guitarcenter.com merchandise return instructions",
                                                       "mod-order-return"],
               "ns0:ReturnReceivedNotification"    => ["RetRecdSrc",
                                                       "guitarcenter.com merchandise return received",
                                                       "mod-order-return"],
              }
   );

   my @variables = $vars{$brand}{$notificationType};
   $sourceCode = $variables[0][0];
   $subject    = $variables[0][1];
   $moduleName = $variables[0][2];

   die "\nCould not find source code  for brand ($brand) and notification type ($notificationType)\n" if ($sourceCode eq "");
   die "\nCould not find subject line for brand ($brand) and notification type ($notificationType)\n" if ($subject eq "");
   die "\nCould not find module name  for brand ($brand) and notification type ($notificationType)\n" if ($moduleName eq "");

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
         ## print "Formatting date ($value)\n";
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
sub processSubordinateTree($$) {
   my ($xml_string, $name) = @_;
   
   my $tree = XML::LibXML->load_xml(string => $xml_string);
   my $document = $tree->getDocumentElement;

   pushXmlDoc($document);
   
   importIncludeFile($name);
   
   popXmlDoc();
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
   print "START $origtext\n" if ($DEBUG_HTML_START_AND_END_CUSTOM && $tag =~ /custom/i);
   if ($tag =~ /custom/i) {
      $saveOrigText = 0;
      if ($attributes->{"type"} =~ /file/i) {
         die "\n\nCould not find 'name' attribute for 'file' in 'custom' tag\n>>>$origtext\n" if ($attributes->{"name"} eq "");
         die "\n\nThe optional attribute is not permitted for 'file' type.\n>>>$origtext\n" if (defined($attributes->{"optional"}));
         
         if (defined($attributes->{"repeatable"}) && $attributes->{"repeatable"} eq "yes") {
            ## print "\t\t$attributes->{'name'} is REPEATABLE\n";
            if ($attributes->{'name'} eq "product-detail") {
               my $xpathToOrderItems = "//OrderedItem";
               if ($notificationType eq "ns0:ShipConfirmationNotification") {
                  $xpathToOrderItems = "//ContainerItem";
               } elsif ($notificationType eq "ns0:OrderCancelNotification") {
                  $xpathToOrderItems = "//CancelledItem";
               } elsif ($notificationType eq "ns0:BackOrderNotification") {
                  $xpathToOrderItems = "//BackOrderedItem";
               } elsif ($notificationType eq "ns0:ReturnAuthNotification") {
                  $xpathToOrderItems = "//ReturnAuthorizedItem";
               } elsif ($notificationType eq "ns0:ReturnReceivedNotification") {
                  $xpathToOrderItems = "//ReturnAuthorizedItem";
               } else {
                  if ($notificationType ne "ns0:OrderConfirmationNotification") {
                     die "\nIt seems that $notificationType has not been fully setup.\n\n";
                  }
               }
            
               my @orderedItems = $xmlDoc->findnodes($xpathToOrderItems);

               for (my $itemCount = 0; $itemCount < @orderedItems; $itemCount++) {
                  processSubordinateTree($orderedItems[$itemCount], $attributes->{"name"});
               }
               
            } elsif ($attributes->{'name'} eq "product-kit") {
               ## If we found a kit, then we must be in a product so our XMLDOC should be a product
               my @kitItems = $xmlDoc->findnodes('//Component');               
               
               for (my $kitCount = 0; $kitCount < @kitItems; $kitCount++) {
                  processSubordinateTree($kitItems[$kitCount], $attributes->{"name"});
               }
               
            } elsif ($attributes->{'name'} eq "order-shipped-payment") {
               my @paymentDetails = $xmlDoc->findnodes('//ShippingGroup/ShippingGroupTotal');
               $globalVariables{$GLOBAL_PAYMENT_NUMBER} = 0;
               for (my $paymentDetails = 0; $paymentDetails < @paymentDetails; $paymentDetails++) {
                  $globalVariables{$GLOBAL_PAYMENT_NUMBER}++;
                  processSubordinateTree($paymentDetails[$paymentDetails], $attributes->{"name"});
               }
               $globalVariables{$GLOBAL_PAYMENT_NUMBER} = 0;

            } elsif ($attributes->{'name'} eq "order-shipped-product-pkg") {
               my @shippedPackages = $xmlDoc->findnodes('//ShippingGroup/ShipContainerDetails');
               $globalVariables{$GLOBAL_PACKAGE_NUMBER} = 0;
               for (my $packageCount = 0; $packageCount < @shippedPackages; $packageCount++) {
                  $globalVariables{$GLOBAL_PACKAGE_NUMBER}++;
                  processSubordinateTree($shippedPackages[$packageCount], $attributes->{"name"});
               }
               $globalVariables{$GLOBAL_PACKAGE_NUMBER} = 0;

            } elsif ($attributes->{'name'} eq "order-cancellation-payment") {
               my @cancelledPayments = $xmlDoc->findnodes('//PaymentDetails');
               for (my $paymentCount = 0; $paymentCount < @cancelledPayments; $paymentCount++) {
                  processSubordinateTree($cancelledPayments[$paymentCount], $attributes->{"name"});
               }

            } elsif ($attributes->{'name'} eq "order-return-label") {
               my @returnLabels = $xmlDoc->findnodes('//ReturnAuthorizedItem');
               for (my $count = 0; $count < @returnLabels; $count++) {
                  processSubordinateTree($returnLabels[$count], $attributes->{"name"});
               }

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
   print " END  $tag (type=" . $a->{"type"} . ")\n" if ($DEBUG_HTML_START_AND_END_CUSTOM && $tag =~ /custom/i);
   if ($origtext eq "</custom>") {
      ## print "CUSTOMTEXT\n>>$customText[$customDepth]\n<<\n";
      $a = $customTags[$customDepth];
      
      if (ref($a) ne "HASH") {
         die "Got to end() at depth $customDepth using $customText[$customDepth]\n and \$a is not a HASH\n($self, $tag, $origtext)\n";
      }

      if ($a->{"type"} =~ /field/ && defined($a->{"optional"}) && $a->{"optional"} =~ /yes/i) {
         if (defined($a->{"minvalue"})) {
            my $value = getValueForField($a->{'name'});
            ## print "\n\tvalue for $a->{'name'} is $value and min=$a->{'minvalue'}\n";
            if (($value + 0) >= ($a->{'minvalue'} + 0)) {
               ;  ## No-operation
            } else {
               print "\tDID NOT MEET minvalue " . formatValueForHtml($value, $a->{'format'}) . "\n";
               $customText[$customDepth] = "";
            }
            
         } else {
            my $value = getValueForField($a->{'name'});
            if ($value eq "") {
               $customText[$customDepth] = "";
            }
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
         $customText[$customDepth] = ""; ## Clear out customText because it it about to be replaced with newAnchor         

         addToHtml($newAnchor);
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
