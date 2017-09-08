#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;



my $file = `echo \$DATAHUB/mainDB.seedDB/data_gene.tsv`; chomp $file;

open( IN, "<$file" ) or die "$!\n";

my $header = 0;

open( OUT, ">data_cnv.tsv" );

while( <IN> ) {
    
    chomp $_;
    if( $header == 0) {
	$header++;
	next;
    }

    my @line = split( /\t/, $_ );
    printf OUT "%s\t%s\n", $line[0], "Deep Deletion";
    printf OUT "%s\t%s\n", $line[0], "High Amplification";
    
	
}

close( IN );
close( OUT );
