#!/usr/bin/perl -w
use Data::Dumper;
use Text::Unidecode;

my $stable = "TCGA-24-1553-01A";

my @stable = split( /\-/, $stable );
splice( @stable, 4 );
$stable[3] =~ s/(\d+)\w/\1/g;
print Dumper $stable[3];
print uc( join("-", @stable ) );
print"\n";



__END__
my $a = `echo 1`;
print Dumper $a;
__END__
exit;
open( IN,"<:encoding(LATIN1)", $ARGV[0] ) or die( "$!\n" );
my %uniq;
while( <IN> ){
    chomp $_;
    #$_ =~ s/[^A-Za-z0-9\s\t\-\_]//g;
    if( $_ =~/(\W)/ ) {
	#$uniq{ $1 } = undef;
    }

    print unidecode($_);
}

foreach( sort keys %uniq ) {
    #print unidecode($_);
}
print "\n";

close( IN );
