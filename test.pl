

my $orig = "r 1";

my $hold = \$orig;

print "orig 1 ", $orig, "\n";

$orig =  "whatever";

print "orig 2 ", $orig, "\n";

$orig = $$hold;
print "orig 3 ", $orig, "\n";
