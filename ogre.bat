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
use DBI;

package HtmlParser;
use POSIX qw(strftime);
use base qw(HTML::Parser);
use File::Basename;
use File::Find;
use DateTime::Format::Strptime;
use DateTime::Format::RFC3339;
use Data::Dumper;
use JSON;
use MIME::QuotedPrint;

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
my $outputDir  = ".\\output\\";
my $transactionalEmailId;
my $thisScriptIsRunningInTestMode	= ($0 =~ /test/i);
my $templateDirectory = "transactional";
my $recipientEmailAddress;
my $dbhOpenTag;
my $sthOpenTag;

my $DEBUG_INCLUDE_FILES             = 0;
my $DEBUG_VARIABLE_MAP              = 0;
my $DEBUG_HTML_START_AND_END_CUSTOM = 0;
my $DEBUG_VARIABLE_VALUES           = 0;

my $GLOBAL_PACKAGE_NUMBER        = "PackageNumber";
my $GLOBAL_PAYMENT_NUMBER        = "PaymentNumber";

if ($thisScriptIsRunningInTestMode) {
	print "\n\nTHIS IS RUNNING IN TEST MODE\n\n" ;
	$templateDirectory = "transactionalTest";
}

# -----------------------------------------------------------------------------
sub validateBrandIdentifier($) {
   my $brand = shift;
   if ($brand ne "GC") {
      die "Could not find brand '$brand' (validateBrandIdentifier), notification type = $notificationType.\n";
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

    my $doc = $parser->load_xml(string => $xml);
    eval { $schema->validate( $doc ) };

    if ( my $ex = $@ ) {
        return $ex;
    }
    return;
}
# -----------------------------------------------------------------------------
sub includeFile($) {
   my $actualFilename = shift;
   print "includeFile " , $actualFilename , "\n" if ($DEBUG_INCLUDE_FILES);
   
   my $p = new HtmlParser;
   $p->parse_file($actualFilename) || die "Error parsing $actualFilename\n$!\n";
}

# -----------------------------------------------------------------------------
sub importIncludeFile($) {
   my $baseFilename = shift;
   print "importIncludeFile ", $baseFilename, "\n" if ($DEBUG_INCLUDE_FILES);
   
   if ($baseFilename =~ /preheader/i) {
      $baseFilename = getPreheaderName($brand, $notificationType);
      print "changed name to  ", $baseFilename, "\n" if ($DEBUG_INCLUDE_FILES);
   }
   
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
   
   my $moduleFilename = "${templateDirectory}\\coded\\modules\\${moduleName}.inc";

   print "  Module ($moduleFilename)\n";
   die "Couldn't find $moduleFilename" if ( ! -e $moduleFilename);
   includeFile($moduleFilename);
}

# -----------------------------------------------------------------------------
sub loadPreheader($) {
   my $notificationType = shift;
   my $preheaderName = $notificationType;
   print "\$preheaderName = $preheaderName\n";
   
   ## if ($preheaderName eq "") {
   ##    die "Got request for <$notificationType> but I couldn't determine which preheader to use.\n";
   ## }
   ## 
   ## my $preheaderFilename = "${templateDirectory}\\coded\\modules\\${preheaderName}.inc";
   ## 
   ## print "    Preheader ($preheaderName)\n";
   ## die "Couldn't find $preheaderFilename" if ( ! -e $preheaderFilename);
   ## includeFile($preheaderFilename);
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
      "[DOWNLOAD_LINK]"    => "DOWNLOAD_LINK",
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
## 2015-02-28 pcr Added new function
sub overrideNotificationType($) {
   my $xmlString = shift;
   
   ## They send only BackOrderNotification.  However, Deb needs to have separate notification
   ## types for an FTC30 and FTC60 notification emailing.  So, when they send a TransactionType
   ## of FTC30 or FTC60 we are changing the whole notification type in the XML.  Ideally, OMS
   ## or Tibco should've had a different notification type or Deb should've gotten it all into
   ## the same template.
	if ($xmlString =~ /\<TransactionType\>FTC30\<\/TransactionType\>/ig) {
		print "\tNotification OVERRIDDING to: BackOrderFTC30Notification\n";
		$xmlString =~ s/ns0\:BackOrderNotification/ns0\:BackOrderFTC30Notification/ig
	} elsif ($xmlString =~ /\<TransactionType\>FTC60\<\/TransactionType\>/ig) {
		print "\tNotification OVERRIDDING to: BackOrderFTC60Notification\n";
		$xmlString =~ s/ns0\:BackOrderNotification/ns0\:BackOrderFTC60Notification/ig
	}
	return $xmlString;
}

# -----------------------------------------------------------------------------
sub processXml($$$$) {
   my ($outputFile, $xmlString, $xsdFile, $file1) = @_;

	$recipientEmailAddress = "";

   print "-" x 60, "\n"; ## Processing:\n\t$xmlFile\n\t$xsdFile\n\t$file1 is present\n";
   if ( my $error = validate_xml_against_xsd($xmlString, $xsdFile) ) {
       die "Validation of XML failed: $error\nRecord starts with:\n\n" . substr($xmlString, 0, 90) . "\n\n";
   }
   die "Could not find base template $file1\n" if ( ! -e $file1);
   
   $html = "";

   print "Validated:\n\t$outputFile\n\t$xsdFile\n\t$file1 is present\n";
   $xmlString = overrideNotificationType($xmlString);    			## 2015-02-28 pcr Possibly change notification type

   my $xmlParser = XML::LibXML->new();
   $xmlDoc = $xmlParser->load_xml(string => $xmlString);
   $notificationType = $xmlDoc->getDocumentElement()->getName();	
   loadVariableMap();

   ## my $query = "$notificationType/OrderSource/Brand/\@brandID";
   my $query = "$notificationType/OrderSource/Brand/BrandName";
   my $brandName = $xmlDoc->findnodes($query);
   if ($brandName =~ /^Guitar.*Center$/i) {
      $brand = "GC";
   } else {
	   $query = "$notificationType/OrderSource/Brand/\@brandID";
	   $brandName = $xmlDoc->findnodes($query);
	   if ($brandName =~ /^GC$/i) {
	   	$brand = "GC";
	   } else {
      	$brand = "Couldn't find brand with query $query";
      }
   }
   validateBrandIdentifier($brand);

   my $recipientEmailAddressQuery 	= "$notificationType/OrderHeader/Customer/DefaultAddress/EMailAddress/Email";
   $recipientEmailAddress 				= $xmlDoc->findnodes($recipientEmailAddressQuery);

   print "\tSending notification type: <$notificationType> for brand <$brand> \n\tto <$recipientEmailAddress>\n";
   print "\tThere is no email address. Presumably this is a Contact Center order.\n" if ($recipientEmailAddress eq "");

   $p->parse_file($file1) || die $!;

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
sub processXmlFile($$$) {
   my ($xmlFile, $xsdFile, $file1) = @_;
   
   my ($volume, $directories, $outputFile) = File::Spec->splitpath($xmlFile);
   $outputFile =~ s/\.xml/\.html/ig;
   $outputFile = "output\\$outputFile";
   
   processXml($outputFile, slurpFile($xmlFile), $xsdFile, $file1);
}

# -----------------------------------------------------------------------------
sub processAdlucentTracking() {
   ## Search Confluence for "adlucent" for details
   ## This is looking in the current document, assuming it is OrderConfirmationNotification
   ## so that it can just look for the details it needs. This is intended for only the one
   ## notification type (unlike everything else in this program that is intended to be more
   ## generic).
   
   my $orderId    = getValueForField("ORDER_NUM");
   my $customerId = getValueForField("CUSTOMER_ID");
   
   my $s = <<EOT;
   https://tracking.deepsearch.adlucent.com/adlucent/PixelOrderTracking
   ?retailer=music123
   &orderKey=$orderId
   &orderchannel=CallCenter
   &ordersite=$brand
   &customerId=$customerId
   &customerType=CallCenter
EOT
   $s =~ s/[ \n]//g;
   
   my @products = $xmlDoc->findnodes("//OrderedItem");

   for (my $productCounter = 0; $productCounter < @products; $productCounter++) {
      my $node    = $products[$productCounter];
      my $sku     = $node->findnodes('./EnterpriseSkuID');
      my $qty     = $node->findnodes('./OrderLineTransaction/Quantity');
      my $price   = $node->findnodes('./ExtPrice');

      $s .= "&sku=$sku&qty=$qty;price=$price";
   }

   $s = "<img src=\"$s\" height=1 width=1 border=0 />";
   
   addToHtml($s);
}

# -----------------------------------------------------------------------------
sub getEmailOpenTagFor($$$) {
	my ($brand, $notificationType, $fromAddr) = @_;
	my $openTag = "";
	
	$sthOpenTag->bind_param(1, $brand, DBI::SQL_VARCHAR); 
	$sthOpenTag->bind_param(2, $notificationType, DBI::SQL_VARCHAR); 
	$sthOpenTag->bind_param(3, $fromAddr, DBI::SQL_VARCHAR); 
	$sthOpenTag->execute() or die $dbhOpenTag -> errstr;
	my $rs = $sthOpenTag->fetchrow_hashref;
	die "Error getting getEmailOpenTagFor($brand, $notificationType, $fromAddr)\n" unless ($rs);
	my $emailListId 		= $rs->{'ListId'};
	my $emailRecipientId	= $rs->{'RecipientId'};
	
	$openTag = "<img src=\"http://r.em.guitarcenter.com/r4.asp?r=${emailListId}_${emailRecipientId}&i=GC14080601_01001\" width=\"1\" height=\"1\">";
	return ($emailListId, $emailRecipientId, $openTag);
}

# -----------------------------------------------------------------------------
sub emailFileForTestPurposes($$) {
   my $fileIn = shift;
   my $subject = shift;
   
   $subject = strftime("[Transactional Email Test] $subject [%Y-%m-%d@%H:%M:%S (id=$transactionalEmailId)]", localtime());
   
   my $fileOut = strftime("${outputDir}pmta_%Y%m%d%H%M%S_0000001_0001.txt", localtime());
   ##die "\n\n$fileOut\n";
   
   open(IN, $fileIn) || die "emailFileForTestPurposes: Couldn't open input $fileIn\n$!\n";
   open(OUT, ">$fileOut") || die "emailFileForTestPurposes: Couldn't open output $fileOut\n$!\n";

   my $fromAddr      = "guitarcenter\@em.guitarcenter.com";
   my $fromName      = "Guitar Center";
   my $replyAddr     = $fromAddr;
   my $bounceAddr    = "bounces\@em.guitarcenter.com";
   my $vmta          = "GC";
   my ($emailListId, $emailRecipientId, $emailOpenTag) = getEmailOpenTagFor($brand, $notificationType, "test_email\@guitarcenter.com");
   
   $replyAddr =~ s/\@/\-reply\@/;

   print OUT "XMRG FROM:<$bounceAddr>\n";
   
   my @testRecipients;
   push @testRecipients, 'preston@mscnet.com';

   if ( ! $thisScriptIsRunningInTestMode) {   
      ## push @testRecipients, 'aaron.chambers@guitarcenter.com';
      push @testRecipients, 'cvartak@guitarcenter.com';
      ## push @testRecipients, 'dstewart@guitarcenter.com';
      ## push @testRecipients, 'dtelford@guitarcenter.com';
      ## push @testRecipients, 'geoff.robles@guitarcenter.com';
      push @testRecipients, 'gerber.rivera@guitarcenter.com';
      push @testRecipients, 'sophia@guitarcenter.com';
      ## push @testRecipients, 'Simona.Todoroska@guitarcenter.com';
      push @testRecipients, 'gctestermcs@yahoo.com';

		if ($recipientEmailAddress =~ /musiciansfriend.com/i || $recipientEmailAddress =~ /guitarcenter.com/i) {
			@testRecipients = ();
			push @testRecipients, 'preston@mscnet.com';
			push @testRecipients, $recipientEmailAddress;

			print "RECIPIENT EMAIL ADDRESS IS GC OR MF...sending email to $recipientEmailAddress\n";
		}
   }

   foreach (@testRecipients) {
      print OUT "XDFN CUSTOMERID=\"${emailListId}_${emailRecipientId}\" *parts=1 *jobid=\"${emailListId}\" *vmta=\"$vmta\" SUBJECT=\"$subject\"\n";
      print OUT "RCPT TO:<$_>\n";
   }
   
   print OUT <<EOT;
XPRT 1 LAST
From: "$fromName" <$fromAddr>
To: <[*to]>
Date: [*date]
Subject: [SUBJECT]
Reply-To: $replyAddr
X-CLIFF-EMAIL: [*to]
X-CLIFF-LIST: [*jobid]
X-CLIFF-RID: [CUSTOMERID]
Mime-Version: 1.0
Content-Type: multipart/alternative; 
   boundary="----=_Part_37_8099147.1185488738520" 

------=_Part_37_8099147.1185488738520
Content-Type: text/html; charset="iso-8859-1" 
Content-Transfer-Encoding: Quoted-Printable

EOT

   ## while(my $s = <IN>) {
   ##    chomp $s;
   ##    print OUT $s, "\n";
   ## }
   my $sFileContents = "";
   while (<IN>) {
     $sFileContents .= $_;
   }
   
   if ($sFileContents =~ /\<\/body\>/i) {
   	$sFileContents =~ s/\<\/body\>/$emailOpenTag/i;
   } else {
   	$sFileContents .= $emailOpenTag;
   }
   
   print OUT encode_qp($sFileContents);
   
   print OUT <<EOT;

------=_Part_37_8099147.1185488738520--

.

EOT
   close(OUT);
   close(IN);
   
   sleep(1);
   ShellOutAndRun("copy $fileOut \\\\pmta\\pmta\\pickup_in");
}

# -----------------------------------------------------------------------------
sub emailFile($$) {
   my $fileIn = shift;
   my $subject = shift;
   
   my $fileOut = strftime("${outputDir}pmta_%Y%m%d%H%M%S_0000001_0001.txt", localtime());
   ##die "\n\n$fileOut\n";
   
   open(IN, $fileIn) || die "emailFile: Couldn't open input $fileIn\n$!\n";
   open(OUT, ">$fileOut") || die "emailFile: Couldn't open output $fileOut\n$!\n";

   my $fromAddr      = getFromAddress($brand, $notificationType);
   my $fromName      = getFromName($brand, $notificationType);
   my $replyAddr     = $fromAddr;
   my $bounceAddr    = getBounceAddress($brand, $notificationType);
   my $vmta          = $brand;
   my ($emailListId, $emailRecipientId, $emailOpenTag) = getEmailOpenTagFor($brand, $notificationType, $recipientEmailAddress);
   
   $replyAddr =~ s/\@/\-reply\@/;

   print OUT "XMRG FROM:<$bounceAddr>\n";
   
   my @testRecipients;
   push @testRecipients, 'preston@mscnet.com';
   ## print "\n\nThis email was supposed to be sent to $recipientEmailAddress\n\n";

   foreach (@testRecipients) {
      print OUT "XDFN CUSTOMERID=\"${emailListId}_${emailRecipientId}\" *parts=1 *jobid=\"${emailListId}\" *vmta=\"$vmta\" SUBJECT=\"$subject\"\n";
      print OUT "RCPT TO:<$_>\n";
   }
	print OUT "XDFN CUSTOMERID=\"${emailListId}_${emailRecipientId}\" *parts=1 *jobid=\"${emailListId}\" *vmta=\"$vmta\" SUBJECT=\"$subject\"\n";
	print OUT "RCPT TO:<$recipientEmailAddress>\n";
   
   print OUT <<EOT;
XPRT 1 LAST
From: "$fromName" <$fromAddr>
To: <[*to]>
Date: [*date]
Subject: [SUBJECT]
Reply-To: $replyAddr
X-CLIFF-EMAIL: [*to]
X-CLIFF-LIST: [*jobid]
X-CLIFF-RID: [CUSTOMERID]
Mime-Version: 1.0
Content-Type: multipart/alternative; 
   boundary="----=_Part_37_8099147.1185488738520" 

------=_Part_37_8099147.1185488738520
Content-Type: text/html; charset="iso-8859-1" 
Content-Transfer-Encoding: Quoted-Printable

EOT

   ## while(my $s = <IN>) {
   ##    chomp $s;
   ##    print OUT $s, "\n";
   ## }
   my $sFileContents = "";
   while (<IN>) {
     $sFileContents .= $_;
   }
   
   if ($sFileContents =~ /\<\/body\>/i) {
   	$sFileContents =~ s/\<\/body\>/$emailOpenTag/i;
   } else {
   	$sFileContents .= $emailOpenTag;
   }
   
   print OUT encode_qp($sFileContents);
   
   print OUT <<EOT;

------=_Part_37_8099147.1185488738520--

.

EOT
   close(OUT);
   close(IN);
   
   print "\n\nFileOut=($fileOut)\n";
   sleep(1);
   ShellOutAndRun("copy $fileOut \\\\pmta\\pmta\\pickup_in") if ($recipientEmailAddress ne "");
   
}

# -----------------------------------------------------------------------------
sub getSubject($$) {
   my ($brand, $notificationType) = @_;
   my @vars = getBrandNotificationVariables($brand, $notificationType);
   return $vars[0];
}

# -----------------------------------------------------------------------------
$p = new HtmlParser;

find(\&findAllIncludeFiles, "./${templateDirectory}/");

my $customDepth = 0;

my $xmlFile = "";
my $file1   = "";

my @testFiles = (
   "MSC-OrderConfirm-Sample-kitItems+Warranty.xml",
   "sample_data_2014-06-10\\MSC-OrderConfirm-Sample-kitItems+Warranty+Adlucent.xml",
   "sample_data_2014-06-10\\G2-CC_Decline-MSC.xml",
   "sample_data_2014-06-10\\G3-OrderVerification-MSC.xml",
   "sample_data_2014-06-06\\B8-ElectronicLicence-MSC.xml",
   "sample_data_2014-06-06\\ElectronicLicence.xml",
   "sample_data_2014-05-23\\E1-Return-Auth-MSC.xml",
   "sample_data_2014-05-23\\F1-Return-Receive-MSC.xml",
   "sample_data_2014-05-06\\MSC-ShipConfirm-kitItems_Sample_1.xml",
   "sample_data_2014-05-06\\MSC-ShipConfirm-kitItems_Sample_2.xml",
   "sample_data_2014-05-07\\MSC-OrderCancel-Sample_1.xml",
   "sample_data_2014-05-16\\MSC_BackOrder_sample1.xml",
   "sample_data_2014-05-16\\MSC_BackOrder_sample2.xml",
   "sample_data_2014-05-22\\B7-ShipConfirm-MSC.xml",
   "sample_data_2015-02-28\\MSC_FTC30.xml",
   "sample_data_2015-02-28\\MSC_FTC60.xml",
);

my $xsdFile = "sample_data_2015-03-12\\CDMOrderNotification.xsd";
my $modFile = "${templateDirectory}\\coded\\base-template.html";

my $sql = <<EOT;
   select 'TransactionalEmailTest' sourceTable, * 
     from gcprod.dbo.TransactionalEmailTest with (nolock)
    where DateProcessedForEmail is null
      and contents like '%<?xml%'
      and EmailProcessResult is null
   union
   select 'TransactionalEmail'     sourceTable, * 
     from gcprod.dbo.TransactionalEmail with (nolock)
    where DateProcessedForEmail is null
      and EmailProcessResult is null
EOT

my $dbh;
my $dbhUpdate;
my $sth;
my $rs;

my $DSN 				= "Driver={SQL Server Native Client 10.0};Server=gcdb2;Database=gcProd;Trusted_Connection=yes;";
my $DSN_GCEMRDB 	= "Driver={SQL Server Native Client 10.0};Server=gcemrdb;Database=EmailAdmin;Trusted_Connection=yes;";

$dbhOpenTag = DBI->connect("dbi:ODBC:$DSN_GCEMRDB") || die "Couldn't connect to database: " . DBI->errstr;
$sthOpenTag = $dbhOpenTag->prepare("exec GetRecipientInfoForTransactionalEmailing ?, ?, ?") || die "Couldn't prepare statement: " . $dbhOpenTag->errstr;

$dbh = DBI->connect("dbi:ODBC:$DSN") || die "Couldn't connect to database: " . DBI->errstr;
$dbh->{LongReadLen} = 512 * 1024;

$dbhUpdate = DBI->connect("dbi:ODBC:$DSN") || die "Couldn't connect to database: " . DBI->errstr;

$sth = $dbh->prepare($sql) || die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute() || die "Couldn't execute statement: " . $sth->errstr;


while ($rs = $sth->fetchrow_hashref) {
   my $sourceTable            = $rs->{'sourceTable'};
   $transactionalEmailId      = $rs->{'TransactionalEmailId'};
   my $xml                    = $rs->{"Contents"};
   my $outputFile             = "${outputDir}db_$transactionalEmailId.html";
   print "Process $outputFile\n";

   $sql = "update $sourceTable set EmailProcessResult = 'A', EmailProcessDate = getdate() where TransactionalEmailId = ?";
   my $updateStatementHandle = $dbhUpdate->prepare($sql) || die "Couldn't prepare statement: " . $dbhUpdate->errstr;
   $updateStatementHandle->execute(($transactionalEmailId)) || die "\nCouldn't update $sourceTable for id = $transactionalEmailId\n";

   processXml($outputFile, $xml, $xsdFile, $modFile);
   
   if ($sourceTable =~ /TransactionalEmailTest/i) {
      emailFileForTestPurposes($outputFile, getSubject($brand, $notificationType));
   } else {
      emailFile($outputFile, getSubject($brand, $notificationType));
   }
   
   $sql = "update $sourceTable set DateProcessedForEmail = getdate(), EmailProcessResult = 'S', EmailProcessDate = getdate() where TransactionalEmailId = ?";
   $updateStatementHandle = $dbhUpdate->prepare($sql) || die "Couldn't prepare statement: " . $dbhUpdate->errstr;
   $updateStatementHandle->execute(($transactionalEmailId)) || die "\nCouldn't update $sourceTable for id = $transactionalEmailId\n";
}

if ($sth->rows == 0) {
   print "No database records found.\n\n";
}

$dbh->disconnect;

if (@ARGV == 4) {
   $xmlFile = $ARGV[0];
   $xsdFile = $ARGV[1];
   $file1   = $ARGV[2];
   $outputDir  = $ARGV[3];
} elsif (@ARGV > 0) {
   die "This program expects 0 or 4 arguments.\n1. XML file\n2. XSD file\n3. Base template HTML/include\n4. Output directory\n";
} else {
	if ($thisScriptIsRunningInTestMode) {
		foreach (@testFiles) {
			my $sendTestXMLFilesViaSMTP = 1;
			my $outputFile = $_;
			processXmlFile($_, $xsdFile, $modFile);
			
			if ($sendTestXMLFilesViaSMTP) {
				$outputFile =~ s/\.xml/\.html/ig;
				$outputFile = "output\\$outputFile";

				$brand = "GC";
				$notificationType = "Preston's Notification";
				my $subject = "Preston's Test";
				$transactionalEmailId = 1234;
				emailFileForTestPurposes($outputFile, $subject);
				last;
			}
		}
	}
}
$outputDir .= "\\" unless ($outputDir =~ /\\$/);


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
sub getPreheaderName($$) {
   my ($brand, $notificationType) = @_;
   my @vars = getBrandNotificationVariables($brand, $notificationType);
   return $vars[3];
}

# -----------------------------------------------------------------------------
sub getListId($$) {
   my ($brand, $notificationType) = @_;
   my @vars = getBrandNotificationVariables($brand, $notificationType);
   return $vars[4];
}

# -----------------------------------------------------------------------------
sub getFromAddress($$) {
   my ($brand, $notificationType) = @_;
   my @vars = getBrandNotificationVariables($brand, $notificationType);
   return $vars[5];
}

# -----------------------------------------------------------------------------
sub getFromName($$) {
   my ($brand, $notificationType) = @_;
   my @vars = getBrandNotificationVariables($brand, $notificationType);
   return $vars[6];
}

# -----------------------------------------------------------------------------
sub getBounceAddress($$) {
   my ($brand, $notificationType) = @_;
   my $addr = getFromAddress($brand, $notificationType);
   $addr =~ s/(.*)\@(.*)/bounces\@$2/g;
   return $addr;
}

# -----------------------------------------------------------------------------
sub getBrandNotificationVariables($$) {
   my ($brand, $notificationType) = @_;
   my $sourceCode    = "";
   my $subject       = "";
   my $moduleName    = "";
   my $preheaderName = "";
   my $listId			= -1;
   my $fromAddress   = "";
   my $fromName      = "";
   
   my %vars = (
      "GC" => {"ns0:OrderConfirmationNotification" => ["4TEM4H1G",
                                                       "Your guitarcenter.com order is placed",
                                                       "mod-order-confirmation",
                                                       "order-confirmation-preheader",
                                                       2022919],
               "ns0:ShipConfirmationNotification"  => ["4TEM4H1H",
                                                       "Your guitarcenter.com order has shipped",
                                                       "mod-order-shipped",
                                                       "order-shipped-preheader",
                                                       2022920],
               "ns0:OrderCancelNotification"       => ["4TEM4H1F",
                                                       "Your guitarcenter.com item cancellation",
                                                       "mod-order-cancellation",
                                                       "order-cancellation-preheader",
                                                       2022921],
               "ns0:BackOrderFTC30Notification"    => ["4TEM4H1A",									## 2015-02-28 pcr New notification type
                                                       "Your guitarcenter.com order status",
                                                       "mod-order-backorder-ftc30",
                                                       "order-backorder-preheader",
                                                       2022922],
               "ns0:BackOrderFTC60Notification"    => ["4TEM4H1B",									## 2015-02-28 pcr New notification type
                                                       "Your guitarcenter.com order status",
                                                       "mod-order-backorder-ftc60",
                                                       "order-backorder-preheader",
                                                       2022922],
               "ns0:BackOrderNotification"         => ["4TEM4H1C",
                                                       "Your guitarcenter.com order status",
                                                       "mod-order-backorder",
                                                       "order-backorder-preheader",
                                                       2022922],
               "ns0:ReturnAuthNotification"        => ["4TEM4H1J",
                                                       "guitarcenter.com merchandise return instructions",
                                                       "mod-order-return-auth",
                                                       "order-return-auth-preheader",
                                                       2022923],
               "ns1:ReturnAuthNotification"        => ["4TEM4H1J",
                                                       "guitarcenter.com merchandise return instructions",
                                                       "mod-order-return-auth",
                                                       "order-return-auth-preheader",
                                                       2022923],
               "ns0:ReturnReceivedNotification"    => ["4TEM4H1K",
                                                       "Your guitarcenter.com merchandise return",
                                                       "mod-order-return-received",
                                                       "order-return-received-preheader",
                                                       2022924],
               "ns0:ElectronicLicenseNotification" => ["4TEM4H1E",
                                                       "Your guitarcenter.com software purchase",
                                                       "mod-order-eld",
                                                       "order-eld-preheader",
                                                       2022925],
               "ns0:OrderVerification_CreditCardDeclineNotification" => ["4TEM4H1D",
                                                       "Your guitarcenter.com order has an issue",
                                                       "mod-order-cc-declined-fraud",
                                                       "order-cc-declined-fraud-preheader",
                                                       2022926],
                                                       
               ##  Source codes provided by Deb 6/9/2014
               ##  4TEM4H1A Customer Contact  OMS Backorder FTC 30
               ##  4TEM4H1B Customer Contact  OMS Backorder FTC 60
               ##  4TEM4H1I Customer Contact  OMS Order Verification (they merged with CC decline)
               ##x 4TEM4H1C Customer Contact  OMS Backorder
               ##x 4TEM4H1D Customer Contact  OMS CC Declined
               ##x 4TEM4H1E Customer Contact  OMS Software ELD
               ##x 4TEM4H1F Customer Contact  OMS Order Cancellation
               ##x 4TEM4H1G Customer Contact  OMS Order Confirmation
               ##x 4TEM4H1H Customer Contact  OMS Order Shipped
               ##x 4TEM4H1J Customer Contact  OMS Return Authorization
               ##x 4TEM4H1K Customer Contact  OMS Return Received

				  "emailInfo" => ['guitarcenter@em.guitarcenter.com', 'Guitar Center']

              }
   );

   my @variables = $vars{$brand}{$notificationType};
   $sourceCode    = $variables[0][0];
   $subject       = $variables[0][1];
   $moduleName    = $variables[0][2];
   $preheaderName = $variables[0][3];
   $listId			= $variables[0][4];
   $fromAddress   = $vars{$brand}{"emailInfo"}[0];
   $fromName      = $vars{$brand}{"emailInfo"}[1];

   die "\nCould not find source code    for brand ($brand) and notification type ($notificationType)\n" if ($sourceCode eq "");
   die "\nCould not find subject line   for brand ($brand) and notification type ($notificationType)\n" if ($subject eq "");
   die "\nCould not find module name    for brand ($brand) and notification type ($notificationType)\n" if ($moduleName eq "");
   die "\nCould not find preheader name for brand ($brand) and notification type ($notificationType)\n" if ($preheaderName eq "");
   die "\nCould not find list id        for brand ($brand) and notification type ($notificationType)\n" if ($listId <= 0);
   die "\nCould not find from address   for brand ($brand)\n" if ($fromAddress eq "");
   die "\nCould not find from name   for brand ($brand)\n" if ($fromName eq "");

   return ($subject, $sourceCode, $moduleName, $preheaderName, $listId, $fromAddress, $fromName);
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
      my $default_variable_value = "PCR_$variable";
      $s = $default_variable_value;
      
      my $localNotificationType = substr($notificationType, 4) . "/";
      $localNotificationType =~ s/\s//g;
      my $varToFind = $localNotificationType . uc($variable);

      if (defined($variableMap{$varToFind})) {
         ## First try to find the NotificationType's variable
         $s = $xmlDoc->findvalue($variableMap{$varToFind});
         print "SEEK 1 $varToFind \n\txpath=$variableMap{$varToFind} (depth=$customDepth)\n\ts=$s\n" if ($DEBUG_VARIABLE_VALUES);

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
         print "SEEK 2 $variable => ($variableMap{uc($variable)})\n" if ($DEBUG_VARIABLE_VALUES);
         $s = $xmlDoc->findvalue($variableMap{uc($variable)});
         
         if ( ! defined($s) || $s eq "" || $s eq $default_variable_value) {
            ## Check global variables if we didn't find anything
            if (defined($globalVariables{$variableMap{uc($variable)}})) {
               print "\t $variable => ($globalVariables{$variable}), found in globals\n" if ($DEBUG_VARIABLE_VALUES);
               $s = $globalVariables{$variableMap{uc($variable)}};
            }
         }         
      } elsif ($globalVariables{$variable}) {
         ## Second try to find the general variable
         print "SEEK 3 $variable\n" if ($DEBUG_VARIABLE_VALUES);
         $s = $xmlDoc->findvalue($globalVariables{$variable});
      } else {
      	unless ($varToFind =~ /SERIAL_NUM/i) {	## 2015-02-28 pcr Allowed serial # to be blank because Deb's using it in odd places in templates
				if ($mustFindVariable) {
					print "SEEK 4 $varToFind\n" if ($DEBUG_VARIABLE_VALUES);
					if ($DEBUG_VARIABLE_MAP) {
						print "DYING DUMPING VARIABLE MAP\n";
						foreach my $key (sort(keys(%variableMap))) {
							print "$key = <$variableMap{$key}>\n";
						}
					}
					die "\n\nFAILED TO FIND VARIABLE '$varToFind'\n";
				}
			} else {
				$s = "";	## 2015-02-28 pcr This is the default for serial #
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
               } elsif ($notificationType eq "ns0:BackOrderFTC30Notification") {	## 2015-02-28 pcr Added new type
                  $xpathToOrderItems = "//BackOrderedItem";
               } elsif ($notificationType eq "ns0:BackOrderFTC60Notification") {	## 2015-02-28 pcr Added new type
                  $xpathToOrderItems = "//BackOrderedItem";
               } elsif ($notificationType eq "ns0:ReturnAuthNotification") {
                  $xpathToOrderItems = "//ReturnAuthorizedItem";
               } elsif ($notificationType eq "ns0:ReturnReceivedNotification") {
                  $xpathToOrderItems = "//ReturnReceivedItem";
               } elsif ($notificationType eq "ns0:ElectronicLicenseNotification") {
                  $xpathToOrderItems = "//ELDItem";
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

            } elsif ($attributes->{'name'} eq "order-return-label-url") {
               my @returnLabels = $xmlDoc->findnodes('//ReturnLabelURL');
               $globalVariables{$GLOBAL_PACKAGE_NUMBER} = 0;
               for (my $count = 0; $count < @returnLabels; $count++) {
                  $globalVariables{$GLOBAL_PACKAGE_NUMBER}++;
                  processSubordinateTree($returnLabels[$count], $attributes->{"name"});
               }

            } elsif ($attributes->{'name'} eq "order-confirmation-payment") {
               my @paymentDetails = $xmlDoc->findnodes('//PaymentDetails');
               for (my $count = 0; $count < @paymentDetails; $count++) {
                  processSubordinateTree($paymentDetails[$count], $attributes->{"name"});
               }

            } else {
               die "Found a REPEATABLE '$attributes->{'name'}', but I don't recognize that name.\n";
            }
            
         } else {
            importIncludeFile($attributes->{"name"}); ## unless ($attributes->{"name"} =~ /preheader/i);
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
         my @validAttributes = ("/", "name", "type", "format", "optional", "minvalue", "mustequal");
         foreach my $attr (sort(keys($attributes))) {
            my @matches = grep(/$attr/i, @validAttributes);
            if (@matches != 1) {
               die "\n\n$tag tag came in with invalid '$attr' attribute\n"
                 . "Valid attributes are: " . join(", ", @validAttributes). "\n"
                 . "Input attributes: " . to_json($attributes) . "\n"
                 . "\n";
            }
         }
         
         if ($origtext =~ /\/\>$/) {
            my $value = getValueForField($attributes->{'name'});
            ##print "\n\nVAL=($value) for $origtext ($attributes->{'name'})\n\n" if ($attributes->{'name'} =~ /pkg_num/i);
            addToHtml(formatValueForHtml($value, $attributes->{'format'}));
         } else {
            incrementCustomDepth();
            $customTags[$customDepth] = $attributes;
            #print "($self, $tag, $attributes, $attrseq, $origtext)\n";
         }
      } elsif ($attributes->{"type"} =~ /adlucent/i) {
         processAdlucentTracking();
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
         
         } elsif (defined($a->{"mustequal"})) {
            my $value = getValueForField($a->{'name'});
            print "\n\tvalue for $a->{'name'} is $value and min=$a->{'mustequal'}\n" if ($DEBUG_HTML_START_AND_END_CUSTOM);
            if ($value eq $a->{'mustequal'}) {
               ;  ## No-operation
            } else {
               print "\tDID NOT MEET mustequal " . formatValueForHtml($value, $a->{'format'}) . "\n";
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
         ##print "PRE NewAnchor=\n$customText[$customDepth]\n";

         $newAnchor = replaceBracketedTags($newAnchor);
         $newAnchor .= ">$customText[$customDepth]</a>";
         
         ##print "POSTNewAnchor=\n$newAnchor\n";
         
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
