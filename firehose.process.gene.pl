#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;
my %options = ( -s => 'TCGA (2016_01_28)' );

GetOptions( "d"      => \$options{ -d },
	    "dd"     => \$options{ -dd },
	    "ddd"    => \$options{ -ddd },
	    "db=s"   => \$options{ -db },
	    "v"      => \$options{ -v },
	    "s=s"    => \$options{ -s },
	    "t=s"    => \$options{ -t },
    ) or die "Incorrect Options $0!\n";


open( IN, "<$ARGV[0]" ) or die "$!\n";

open( GENE," >data_gene.tsv" ) or die "$!\n";
open( META, ">data_gene_meta.tsv" ) or die "$!\n";

my $header = 0;
my @header;

while( <IN> ) {

    chomp $_;
    if( $header == 0 ) {
	@header = split( /\t/, $_);
	$header++;
	next;
    }
    my %line;
    @line{ @header } = split( /\t/, $_ );
    
    my $entrez = $line{ ENTREZ_GENE_ID };

    printf GENE "%s\t%s\n", $entrez, $line{ HUGO_GENE_SYMBOL };

    printf META "%s\tType\t%s\n", $entrez, $line{ TYPE };
    printf META "%s\tCytoband\t%s\n", $entrez, $line{ CYTOBAND };
    printf META "%s\tLength\t%s\n", $entrez, $line{ LENGTH };
}
