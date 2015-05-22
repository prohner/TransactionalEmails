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
      
      ##my $localNotificationType = substr($notificationType, 4) . "/";
      my $localNotificationType = $notificationType . "/";
      $localNotificationType =~ s/\s//g;
      my $varToFind = $localNotificationType . uc($variable);
      print "SEEK 1 PRE - Hunting $varToFind (mustFind=$mustFindVariable)\n" if ($DEBUG_VARIABLE_VALUES);

      if (defined($variableMap{$varToFind})) {
         ## First try to find the NotificationType's variable
         print "SEEK 1 $varToFind \n\txpath=$variableMap{$varToFind} (depth=$customDepth)\n\ts=$s\n" if ($DEBUG_VARIABLE_VALUES);
         $s = $xmlDoc->findvalue($variableMap{$varToFind});
         print "SEEK 1 POST $varToFind \n\txpath=$variableMap{$varToFind} (depth=$customDepth)\n\ts=$s\n" if ($DEBUG_VARIABLE_VALUES);

         if (1 == 1) {
            my @nodes = $xmlDoc->findnodes($variableMap{$varToFind});
            #print "SEEK 1 $varToFind \n\txpath=$variableMap{$varToFind}\n\t$s\n\tnode count=" . (@nodes + 0) . "\n";
            if (@nodes > 0) {
               my $node = $nodes[0];
               $s = $node->textContent();
            }
         }

         if ($s eq "" && $notificationType ne "EmailForPriceNotification" && $namespace ne "cus" && processingCustomerNotification()) {
         	## We're at the top level and we've tried doing an xpath query, 
         	## but found nothing so we'll try adding the namespace.
         	my $documentDepth = scalar @xmlDocStack;

				my $tmpXpath = $variableMap{$varToFind};
				$tmpXpath =~ s|\/\/|\/\/$namespace\:|g;
				print "SEEK 1b $tmpXpath \n\t(documentDepth=$documentDepth)\n\ts=$s\n" if ($DEBUG_VARIABLE_VALUES);

				my $localXmlDoc = $xmlDoc;
				##if ($documentDepth > 0) {
				##	$localXmlDoc = $xmlDocStack[0];
				##}

				my @nodes = $xmlDoc->findnodes($tmpXpath);
				if (@nodes > 0) {
					my $node = $nodes[0];
					$s = $node->textContent();
				}
				print "SEEK 1c $tmpXpath \n\t$s\n" if ($DEBUG_VARIABLE_VALUES);
         } else {
            print "SEEK 1b was skipped even though \$s is empty for \n\tVar:$varToFind\n\tVal:$variableMap{$varToFind}" if ($DEBUG_VARIABLE_VALUES);
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
      } elsif ("${notificationType}/NOTIFICATIONTYPE" =~ /$varToFind/i) {
      	$s = $notificationType;
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
   ##print "Get $variable, got $s ($variableMap{uc($variable)})\n";

   return $s;
}
