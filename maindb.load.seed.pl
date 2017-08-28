#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use Generic qw(pprint read_file);
use Getopt::Long;
use Storable;

my %options = ( -d => 0 );


GetOptions( "d=s"      => \$options{ -d },
	    "v=s"      => \$options{ -v },
	    "s=s"      => \$options{ -s }
    ) or die "Incorrect Options $0!\n";


# Import data_cancer_study.psv
# Import data_gene.psv
# Import data_gene_alias.psv


my @seedDB = qw( cancer_type gene gene_alias );
my %map = ( 'type_of_cancer_id' => 'cancer_id' );
my %dbtable;	    

foreach my $table( @seedDB ) {
    next unless( $table eq 'cancer_type' );
    import_file( -file => "data_${table}.psv",
		 -table => $table );
    
}

sub import_file {

    my(%param) = @_;

    my $data = read_file( -file => $param{ -file },
			  -delim =>  "|" );

    my @header = @{ $data->{ header } };
    
}

sub load_interal_table {

}
    
    
    

##############################################################################################
# SUBROUTINE
