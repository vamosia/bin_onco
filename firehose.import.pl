#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;
use POSIX;


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
     -io     Insert One by One (Default Insert Many
   
AUTHOR:
    Alexander Butarbutar (ab\@oncodna.com), OncoDNA
\n\n";


my %dbtable;
my %dbpriority;

$| = 1; #Flush buffer off

# Get User Options
my %options = ( -db => 'maindb_dev' );
GetOptions( 'd'        => \$options{ -d },
	    'dd'       => \$options{ -dd },
	    'ddd'      => \$options{ -ddd },
	    'c'        => \$options{ -c },  
	    'v'        => \$options{ -v },
	    't=s'      => \$options{ -table },
 	    'io'       => \$options{ -io },         # insert many
	    'db=s'     => \$options{ -db },
	    'dbs=s'    => \$options{ -schema }
	    
    ) or die "Incorrect Options $0!\n";



my %load_table = ( 'seed' => { 'cancer_type' => '',
			       'gene' => '',
			       'gene_meta' => '',
			       'gene_alias' => '' },
		   'variants' => { 'variant' => '',
				  'variant_meta' => '' },
		   'cnvs' => { 'cnv' => '',
			      'cnv_sample' => '',
			      'cnv_meta' => '' },
		   
		   'data' => { 'study' => '',
			       'cancer_study' => '',
			       'patient' => '',
			       'patient_meta' => '',
			       'sample' => '',
			       'sample_meta' => '' } );
			       
my $gen = new Generic( %options );

$gen->pprint( -level => 0,
	      -val => "FIREHOSE IMPORT" );

$gen->pprint( -tag => 'error',
	      -val => '-t required' ) unless( defined $options{ -table } );


my $mainDB = new MainDB( %options );

my %sql;



# Load the database structure
$mainDB->load_dbtable();

# Load the priority of tables we should import
$mainDB->load_dbpriority();

$gen->pprint( -val => 'Start Importing File',
	      -v => 1 );

# Get the list of tables to import, we are going to iterate through this
# looking for file with the following symtax 'data_$table_.txt'

my $dbpriority = $mainDB->get_dbpriority();

# Load data based on its priority
foreach( sort { $a <=> $b } keys %{ $dbpriority } ) {

    %sql = ();
    
    my $table = $dbpriority->{ $_ };

    my $file =  "data_${table}.txt";
    
    if( exists $load_table{ $options{-table} } ) {
	
	next unless( exists $load_table{ $options{-table} }{ $table } );

	$file =  "data_${table}.psv" if( $options{-table} eq 'seed' );
	
    } else {
	
	next if( $options{-table } ne $table );

    }
    
    # if file does not exists
    unless( -e $file ) {
	$gen->pprint( -tag => 'error',
		      -level => 2, 
		      -val => "File does not exists : $file" );
	next;
    }
    
    $gen->pprint( -level => 0, 
		  -val => "Importing file from '$file' to table '$table'" );
    
    process_file( -table => $table,
		  -file => $file );

}

# Commit & Disconnect
$mainDB->close();

=head2 process_file

    Function : Process and import the FILENAME into the database on TABLENAME
    Usage    : process_file( -f => FILE_NAME,
                             -t => TABLE_NAME )                           
    Returns  : none
    Args     : -f  File name to be process
               -t  The table name where this file will be imported to
=cut

sub process_file {
    
    my( %param ) = @_;

    my $file = $param{ -file };
    
    my $total = `more $file | wc -l`; chomp $total;


    
    $gen->pprogres_reset();
    
    open( IN, "<$file" ) or die "$!\n";

    my $header = 0;
    my @header;
    my %many_sql;
    my @many_values;

    # Read the file and process each line
    while( <IN> ) {
	
	chomp $_;


	# Store the header into its own array
	if( $header == 0 ) {

	    @header = split( /[\t\|]/, $_ );

	    $header = 1;
	    
	    $total-- if( $total > 1 );
	    
	    next;
	}


	# Counter
	$gen->pprogres( -total => $total,
			-v => 1 );

	
	# Create a hash table with the @header as the key and each (split) column as the @value
	my %data;

	@data{ @header } = split( /[\t\|]/, $_ );
	
	# Create SQL
	$mainDB->generate_sql( -data => \%data,
			       %param );
		
    }
    
    print "\n" if( $options{ -v } );
    
    $gen->pprint( -val => "SQL Inserts..." );
    
    $mainDB->insert_sql( %param );
    
    $mainDB->reset_sql();
    
    close( IN );
}


=head2 test_connection

    Function : Basic check to test connection to a database
    Usage    : test_connection()
    Returns  : none
    Args     : none


=cut
sub test_connection {
    
    my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=localhost;port=5432",'postgres','ionadmin',{AutoCommit=>1,RaiseError=>1,PrintError=>0});
    
    my $stmt = qq(SELECT * FROM maindb.cancer_type );
    
    my $sth = $dbh->prepare( $stmt );
    
    my $rv = $sth->execute() or die $DBI::errstr;

    print $DBI::errstr if($rv < 0);
    
    while(my @row = $sth->fetchrow_array()) {
	print Dumper \@row;
    }
    
    print "Operation done successfully\n";
    
    $dbh->disconnect();
}


__END__
