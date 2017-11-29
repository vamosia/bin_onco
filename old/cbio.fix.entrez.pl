#!/usr/bin/perl -w
use strict;
use warnings;
use lib "/home/ionadmin/bin";
use Data::Dumper;

use Bio::Cbioportal;
use Bio::Generic qw( debug );
use Getopt::Long;

my %options;

GetOptions( 'f=s'    => \$options{ -f }
    ) or die "Incorrect Options $0!\n";

my $study = `pwd`; 
chomp $study;
$study =~ s/.*\/tcga\/(.*?)\/data_mutations_extended.BAK/$1/;

debug( -t => "id",
       -id => "INFO",
       -val => "Study : $study" );


my $cbio = new Bio::Cbioportal( -d => 1);

my %id = ( 'cbio' => ['entrez_gene_id',
		      'mutation_type' ],
	   
	   'local' => ['Entrez_Gene_Id',
		       'Variant_Classification' ] );


my $entrez = $cbio->load_file( -file => 'data_mutations_extended.txt.cbio',
			       -id => 'gene_symbol',
			       -val => 'entrez_gene_id' );

my $chr_hg = $cbio->load_file( -file => '/home/ionadmin/genome/hg19/Homo_sapiens.gene_info',
			    -id => 'GeneID',
			    -val => 'chromosome');




my @files = ( 'data_CNA.txt',
	      'data_linear_CNA.txt',
	      'data_methylation_hm450.txt',
	      'data_RNA_Seq_v2_expression_median.txt',
	      'data_RNA_Seq_v2_mRNA_median_Zscores.txt' );

@files = ( 'data_mutations_extended.txt' );

foreach my $file ( @files ) {
    
    $cbio->map_column( -id => ['Hugo_Symbol>Entrez_Gene_Id', 'Entrez_Gene_Id>Chromosome' ],
		       -data => [$entrez, $chr_hg],
		       -file_in => $file,
		       -file_out => "$file.fix.entrez.chr" );
    
    # $cbio->map_column( -id => 'Hugo_Symbol',
    # 		       -val => 'Entrez_Gene_Id',
    # 		       -file_in => $file,
    # 		       -file_out => "$file.fix.entrez",		       
    # 		       -data => $entrez );
    
    
    # $cbio->map_column( -id => 'Entrez_Gene_Id',
    # 		       -val => 'Chromosome',
    # 		       -file_in => "$file.fix.entrez",
    # 		       -file_out => "$file.fix.entrez.chr",
    # 		       -data => $chr_hg );
    
    
 

}

