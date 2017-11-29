#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;


my %options = ( -l => 30000 );

GetOptions( "f=s"      => \$options{ -f },
	    "l=i"      => \$options{ -l }
    ) or die "Incorrect Options $0!\n";

my $total = `more $options{-f} | wc -l`; chomp $total;

print "Total Lines\t: $total\n";
print "Files per Line\t: $options{-l}\n";

my $cnt = 1;
my $part1 = 1;
my $part2 = $options{-l};
my $out = "tcga_mutations_extended.txt.$cnt.maf";
system( "rm $out" ) if( -e $out );

while( $part2 <= $total ) {
    $out = "tcga_mutations_extended.txt.$cnt.maf";
    print "$out = $part1 - $part2\n";

    # header
    if( $cnt > 1 ) {
	system( qq( head -n 1 $options{-f} > $out) );
    } elsif( $cnt == 1 ) {
	system( qq( rm $out) );
    }
    
    system( qq(sed -n "$part1,${part2}p" $options{-f} >> $out) );
    
    $part1 = $part2 + 1;
    $part2 += $options{-l};
    $cnt++;
}
$out = "tcga_mutations_extended.txt.$cnt.maf";
$part2 = $total;
print "$out = $part1 - $part2\n";
system( qq( head -n 1 $options{-f} > $out) ) if( $cnt > 1 );
system( qq(sed -n "$part1,${part2}p" $options{-f} >> $out) );
