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
my @customTags;
my @customText;
my @xmlDocStack;

my $DEBUG_INCLUDE_FILES = 0;

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
      $actualFilename = $allIncludeFiles{lc($filename)};
   }
   
   print "Looking for $originalBaseFilename\n" if ($DEBUG_INCLUDE_FILES);
   if (defined($actualFilename)) {
      print "Found <", $actualFilename, ">\n" if ($DEBUG_INCLUDE_FILES);
   } else {
      print "Did not find $originalBaseFilename\n";
      foreach my $f (sort(keys(%allIncludeFiles))) {
         print "\t>", $f, "\n";
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
sub includeFile($) {
   my $actualFilename = shift;
   print "includeFile ", $actualFilename, "\n" if ($DEBUG_INCLUDE_FILES);
   
   my $p = new HtmlParser;
   $p->parse_file($actualFilename) || die $!;
}

# -----------------------------------------------------------------------------
sub importIncludeFile($) {
   my $baseFilename = shift;
   print "importIncludeFile ", $baseFilename, "\n";
   
   my $actualFilename = "";
   $actualFilename = actualFilenameForBrand($baseFilename);

   includeFile($actualFilename);
}

# -----------------------------------------------------------------------------
sub loadModule($) {
   my $notificationType = shift;
   my $moduleName = "";
   if ($notificationType =~ /ns0\:OrderConfirmationNotification/i) {
      $moduleName = "mod-order-confirmation";
   } 
   
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
   );
   
   if (@xmlDocStack == 0) {      
      ## Some variables are only valid in the base document, so add them here
      $vars{"[ORDER_NUM]"}    = "ORDER_NUM";
   }
   
   foreach my $key (keys(%vars)) {
      my $val = $vars{$key};
      print "Getting value ($val)\n";
      $val = getValueForField($val);
      $key = quotemeta($key);
      $s =~ s/$key/$val/g;
      die "REPLACE $key with $val\n" if ($key eq "[PRODUCT_IMAGE]");
   }
   
   die "\n\nFound bracket in $s after all brackets should have been replaced\n\n" if ($s =~ /[\[\]]/);
   return $s;
}

# -----------------------------------------------------------------------------
sub loadVariableMap() {
   open(IN, "variable_map.txt") || die "Couldn't open variable_map.txt\n$!\n";
   while (<IN>) {
      unless (/^\#/) {
         my ($var, $xpath) = split(/\s*=\s*/, $_, 2);
         $variableMap{$var} = $xpath;
      }
   }
   close(IN);
}

# -----------------------------------------------------------------------------
$p = new HtmlParser;

find(\&findAllIncludeFiles, ".");

my $customDepth = 0;
my $xmlFile = "MSC-OrderConfirm-Sample-kitItems+Warranty.xml";
my $xmlParser = XML::LibXML->new();
my $xmlDoc = $xmlParser->parse_file($xmlFile);
my $notificationType = $xmlDoc->getDocumentElement()->getName();
loadVariableMap();

my $query = "$notificationType/OrderSource/Brand/\@brandID";
$brand = $xmlDoc->findnodes($query);
validateBrandIdentifier($brand);

print "Notification type: <$notificationType>\n";


my $file1 = "transactional\\coded\\base-template.html";
$p->parse_file($file1) || die $!;

open(OUT, ">out.html") || die "Couldn't open out.html\n$!\n";
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
sub getBrandNotificationVariables($$) {
   my ($brand, $notificationType) = @_;
   my $sourceCode = "";
   my $subject    = "";
   if ($brand eq "GC") {
      if ($notificationType eq "ns0:OrderConfirmationNotification") {
         $sourceCode = "OrdConfSrc";
         $subject    = "GC Order Confirmation";
      } else {
         die "Unrecognized notification type ($notificationType) for brand ($brand) in getSourceCode()\n";
      }
   } else {
      die "Unrecognized brand ($brand) in getSourceCode()\n";
   }
   return ($subject, $sourceCode);
}

# -----------------------------------------------------------------------------
sub getValueForField($) {
   my ($variable) = @_;
   my $s;
   
   if ($variable =~ /current_year/i) {
      $s = strftime("%Y", localtime());
   } elsif ($variable =~ /source_code/i) {
      $s = getSourceCode($brand, $notificationType);
   } else {
      my %variable_map;
      $s = "PCR_$variable";

      if (defined($variableMap{uc($variable)})) {
         $s = $xmlDoc->findvalue($variableMap{uc($variable)});
      } else {
         warn "FAILED TO FIND VARIABLE '$variable'\n";
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
      my $date = $formatter->parse_datetime($value);
   
      $s = $date->strftime("%m/%d/%Y");
   } elsif ($format =~ /currency/i) {
      $s = sprintf("%0.2f", $value);
   } elsif ($format =~ /number/i) {
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
   addToHtml($text);
}

sub comment {
   my ($self, $comment) = @_;
   ## discarding comments
}

sub start {
   my ($self, $tag, $attributes, $attrseq, $origtext) = @_;
   my $saveOrigText = 1;
   if ($tag =~ /custom/i) {
      if ($attributes->{"type"} =~ /file/i) {
         die "Could not find 'name' attribute for 'file' in 'custom' tag\n>>>$origtext\n" if ($attributes->{"name"} eq "");
         if (defined($attributes->{"repeatable"}) && $attributes->{"repeatable"} eq "yes") {
            print "\t\t$attributes->{'name'} is REPEATABLE\n";
            if ($attributes->{'name'} eq "product-detail") {
               my @orderedItems = $xmlDoc->findnodes('//OrderedItem');

               print "NOW WE SEE HOW THE INCLUDED ITEMS GO...\n\n";
               for (my $itemCount = 0; $itemCount < @orderedItems; $itemCount++) {
                  ## Creating a new document only for this OrderedItem
                  my $treeForItem = XML::LibXML->load_xml(string => $orderedItems[$itemCount]);
                  my $documentForItem = $treeForItem->getDocumentElement;

                  pushXmlDoc($documentForItem);
                  
                  print "\n\n$itemCount\n", $orderedItems[$itemCount], "\n";
                  importIncludeFile($attributes->{"name"});
                  
                  popXmlDoc();
               }
               
            } elsif ($attributes->{'name'} eq "product-kit") {
               ## If we found a kit, then we must be in a product so our XMLDOC should be a product
               my @kitItems = $xmlDoc->findnodes('//Component');
               print "NOW WE SEE HOW THE INCLUDED KITS GO...\n\n";
               
               
               for (my $kitCount = 0; $kitCount < @kitItems; $kitCount++) {
                  ## Creating a new document only for this Kit
                  my $treeForKit = XML::LibXML->load_xml(string => $kitItems[$kitCount]);
                  my $documentForKit = $treeForKit->getDocumentElement;

                  pushXmlDoc($documentForKit);
               
                  importIncludeFile($attributes->{"name"});

                  popXmlDoc();
               }
               
            } elsif ($attributes->{'name'} eq "order-shipped-payment") {
               my @paymentDetails = $xmlDoc->findnodes('//PaymentDetails');
               for (my $itemCount = 0; $itemCount < @paymentDetails; $itemCount++) {
                  importIncludeFile($attributes->{"name"});
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
         $origtext =~ s/\<custom/\<image/i;
         
         $origtext = replaceBracketedTags($origtext);
      } elsif ($attributes->{"type"} =~ /anchor/i) {
         print "\n\nBEGINNING CUSTOM ANCHOR\n\n";
         incrementCustomDepth();
         $customTags[$customDepth] = $attributes;
         $saveOrigText = 0;
         #print "($self, $tag, $attributes, $attrseq, $origtext)\n";
      } elsif ($attributes->{"type"} =~ /field/i) {
         print "\n\nBEGINNING CUSTOM FIELD $attributes->{'name'}\n\n";
         if ($origtext =~ /\/\>$/) {
            print "IN SHORT CIRCUIT\n";
            $saveOrigText = 0;
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
      print "END $origtext\n";
      print "CUSTOMTEXT\n>>$customText[$customDepth]\n<<\n";
      $a = $customTags[$customDepth];
      
      if (ref($a) ne "HASH") {
         die "Got to end() at depth $customDepth using $customText[$customDepth]\n and \$a is not a HASH\n";
      }

      if ($a->{"type"} =~ /field/ && defined($a->{"optional"}) && $a->{"optional"} =~ /yes/i) {
         if (defined($a->{"minvalue"})) {
            my $value = getValueForField($a->{'name'});
            print "\n\tvalue for $a->{'name'} is $value and min=$a->{'minvalue'}\n";
            if (($value + 0) >= ($a->{'minvalue'} + 0)) {
               print "\tAPPENDING" . formatValueForHtml($value, $a->{'format'}) . "\n";
               $html .= formatValueForHtml($value, $a->{'format'});
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
            
            print "\nNAME=($a->{'name'})\nVALUE=($value) (" . ($value ne "") . ")\n" if ($a->{'name'} =~ /kit/i);
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

         print "\$newAnchor=\n\n$newAnchor\n\n";
         print "\$customText was=\n\n$customText[$customDepth]\n\n";
         
         ##exit(1) if ($customText[$customDepth] =~ /order details/i);
         $html .= $newAnchor;
      }
      
      decrementCustomDepth();
   } else {
      #$html .= $origtext;
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
