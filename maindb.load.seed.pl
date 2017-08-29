#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use Generic qw(pprint read_file);
use MainDB;
use Getopt::Long;
use Storable;

# Load the seed data for mainDB this includes
#
# -data_cancer_type.txt
# -data_gene.txt
# -data_gene_alis.txt
#
# These files need to be located in load disk

my %options = ( -d => 0,
		-it => 'one',
		-db => 'maindb_dev' );


GetOptions( "d=s"      => \$options{ -d },
	    "v=s"      => \$options{ -v },
	    "s=s"      => \$options{ -s },
	    "it=s"     => \$options{ -it }
	    
    ) or die "Incorrect Options $0!\n";

# Establish connection to mainDB
my $mainDB = new MainDB( -db => $options{ -db },
			 -d  => $options{ -d },
			 -it => $options{ -it } );

my @seedDB = qw( cancer_type gene gene_alias );

my %map = ( 'type_of_cancer_id' => 'cancer_id' );

my $dbtable = $mainDB->load_dbtable();

pprint( -level => 0, -val => "Loading SeedDB to $options{ -db }" );

foreach my $table( @seedDB ) {
    
    pprint( -val => $table );
    
    # next unless( $table eq 'gene_alias' );

    import_file( -file => "data_${table}.psv",
		 -table => $table );
}

$mainDB->commit();

#########################################################################################################
# SUBROUTINE
#

sub import_file {

    my(%param) = @_;

    my $data = read_file( -file => $param{ -file },
			  -delim =>  "|" );

    my @header = @{ $data->{ header } };
    foreach( @{ $data->{ data } } ) {

	my($sql_insert, $sql_value) = $mainDB->generate_sql( -table => $param{ -table },
							     -data => $_ );;
    
	$mainDB->import_sql( -insert => $sql_insert,
			     -value => $sql_value );
    }
}


    

##############################################################################################
# SUBROUTINE
