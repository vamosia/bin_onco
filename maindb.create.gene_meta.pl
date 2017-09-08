#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;



my $file = `echo \$DATAHUB/mainDB.seedDB.BAK/data_gene_meta.psv`; chomp $file;

open( IN, "<$file" ) or die "$!\n";

my $header = 0;

open( OUT, ">data_gene_meta.tsv" );

while( <IN> ) {

    chomp $_;
    
    if( $header == 0) {
	$header++;
	next;
    }

    my @line = split( /\|/, $_ );

    my $entrez = $line[0];

    printf OUT "%s\t%s\t%s\n", $entrez, 'Type', $line[2];
    printf OUT "%s\t%s\t%s\n", $entrez, 'Cytoband', $line[3] || 'null';
    printf OUT "%s\t%s\t%s\n", $entrez, 'Length', $line[4] || 'null';

}

close( IN );
close( OUT );
