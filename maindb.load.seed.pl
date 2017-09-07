#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use Generic;
use MainDB;
use Getopt::Long;
use Storable;

# Load the core content of the mainDB database
#
# Currently this script is harded coded to load the folloing files from the same directory
# 
# -data_cancer_type.txt
# -data_gene.txt
# -data_gene_alis.txt

( $#ARGV > -1 ) || die "

DESCRIPTION:
     Loads the static portion of the mainDB database. Data is loaded from the files at the current directory.
     Please ensure that these are present on the current directory

     -data_cancer_type.txt
     -data_gene.txt
     -data_gene_alias.txt
    
USAGE:
     maindb.load.seed.pl

EXAMPLE:
     maindb.load.seed.pl -d test -c

OPTIONS :
     -db    Database. This is db that we're inserting to
     -d     Debug Mode
     -v     Verbose

     Database Operation
     -c     Commit Insert Statement (Default rollback)
     -im    Insert many (Default one-by-one insert)
   
AUTHOR:
    Alexander Butarbutar (ab\@oncodna.com), OncoDNA
\n\n";


 

my %options = ( -db => 'maindb' );

GetOptions( "d"        => \$options{ -d },
	    "dd"       => \$options{ -dd },
	    "ddd"      => \$options{ -ddd },
	    "t"        => \$options{ -t },
	    "db=s"     => \$options{ -db },
	    "v"        => \$options{ -v },
	    "it=s"     => \$options{ -it },
	    "c"        => \$options{ -c }	    
    ) or die "Incorrect Options $0!\n";

# Establish connection to mainDB
my $mainDB = new MainDB( %options );

# Create generatic class various common function
my $gen = new Generic( %options );

# This is the list of tables that we will load
# the script will specific look for files in the following format
# data_[seedDB].txt

my @seedDB = qw( cancer_type gene gene_alias );

# Mapping table to map external to internal terminology
my %map = ( 'type_of_cancer_id' => 'cancer_id' );

# Load the database table structure, column names, primary key, foreign key etc
my $dbtable = $mainDB->load_dbtable();

$gen->pprint( -level => 0, 
	      -val => "Loading SeedDB to $options{ -db }" );

foreach my $table( @seedDB ) {
    
    $gen->pprint( -val => "Importing $table" );
    
    # $options{ -t } is used to import specific tables
    next if( defined $options{ -table } && $table ne $options{ -table } );
    
    import_file( -file => "data_${table}.psv",
		 -table => $table );
}

# Commit & Disconnect
$mainDB->close();

#########################################################################################################
# SUBROUTINE
#

=head2 import_file

    Function : Imports a file to a specific table on the database
    Usage    : process_file( %parameters )
    Returns  : none
    Args     : -file   File name to be process
               -table  The table name where this file will be imported to
=cut
    
sub import_file {

    my(%param) = @_;

    # Read the content of the file
    my $data = $gen->read_file( -file => $param{ -file },
				-delim =>  "|" );
    
    my @header = @{ $data->{ header } };
    
    my $cnt = 0;
    my $total = `more $param{ -file } | wc -l`; chomp $total;
    $gen->pprogres_reset();

    # For each line within the files, we will generate an sql > then import this sql
    foreach( @{ $data->{ data } } ) {
	print Dumper $_;
	# Generating sql statement
	$mainDB->generate_sql( -table => $param{ -table },
			       -data => $_,
			       %options );
	
	$gen->pprogres( -total => $total );
	
    }
    print "\n";
    
    $gen->pprint( -val => "SQL Inserts..." );

    # Importing the sql statement to the database
    $mainDB->insert_sql( %param );

}


    

