#!/usr/bin/perl -w
use strict;
use warnings;
use lib "/home/ionadmin/bin";
use Data::Dumper;
use Bio::Cbioportal;
use Getopt::Long;

my %options;

GetOptions( 'f=s'    => \$options{ -f }
    ) or die "Incorrect Options $0!\n";

my $cbio = new Bio::Cbioportal( -d => 1);

my $entrez = $cbio->load_entrez( -file => '/home/ionadmin/genome/hg19/cbioportal.gene_info' );

my @files = ( 'data_CNA.txt',
	      'data_linear_CNA.txt',
	      'data_methylation_hm450.txt',
	      'data_mutations_extended.txt',
	      'data_RNA_Seq_v2_expression_median.txt',
	      'data_RNA_Seq_v2_mRNA_median_Zscores.txt' );


foreach my $file ( @files ) {

    $cbio->map_column( -id => 'Hugo_Symbol',
		       -val => 'Entrez_Gene_Id',
		       -file => $file,
		       -data => $entrez );
    
    system( "cp $file ${file}.BAK" );
    
    
}

