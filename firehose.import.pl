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
     -im    Insert many (Default one-by-one insert)
   
AUTHOR:
    Alexander Butarbutar (ab\@oncodna.com), OncoDNA
\n\n";


my %dbtable;
my %dbpriority;

# Get User Options
my %options = ( -db => 'maindb_dev' );
GetOptions( 'd'        => \$options{ -d },
	    'c'        => \$options{ -c },  
	    'v'        => \$options{ -v },
	    't=s'      => \$options{ -t },
	    'im'       => \$options{ -im },         # insert many
	    'db=s'     => \$options{ -db },
	    'dbs=s'    => \$options{ -schema }
    ) or die "Incorrect Options $0!\n";


my %seed_table = ( 'cancer_type' => '',
		   'gene' => '',
		   'gene_alias' => '' );

my $gen = new Generic( %options );

my $mainDB = new MainDB( %options );

my %sql;

$gen->pprint( -level => 0,
	      -val => "FIREHOSE IMPORT" );

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
    
    # These are part of seedDB so skip importing
    # as it will be imported by a different script maindb.load.seed.pl
    if( exists $seed_table{ $table } ) {
	#$gen->pprint( -tag => 'IGNORE', 
	#	      -val => "$table is part of seedDB",
	#	      -v => 1 );
	next;
    }
    
    my $file =  "data_${table}.txt";
    
    # $options{ -t } is used to import specific tables
    next if( defined $options{ -t } && $table ne $options{ -t } );
    
    # if file does not exists
    unless( -e $file ) {
	$gen->pprint( -tag => 'WARNING',
		      -level => 2, 
		      -val => "File does not exists : $file" );
	next;
    }
    
    $gen->pprint( -level => 0, 
		  -val => "Importing file from '$file' to table '$table'" );
    
    process_file( -t => $table,
		  -f => $file );
}

# Commit & Disconnect
$mainDB->close();


############################################################
# SUBROUTINE
############################################################

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

    my $file = $param{ -f };
    my $table = $param{ -t };
    

    my $total = `more $file | wc -l`; chomp $total;
    
    open( IN, "<$file" ) or die "$!\n";

    my $header = 0;
    my @header;
    my %many_sql;
    my @many_values;

    # Get contrain
    
    # Read the file and process each line
    while( <IN> ) {
	
	chomp $_;
	
	# Store the header into its own array
	if( $header == 0 ) {
	    @header = split( /\t/, $_ );

	    $header = 1;

	    $gen->pprogres( -total => $total,
			    -v => 1 );
	    next;
	}
	
	# Create a hash table with the @header as the key and each (split) column as the @value
	my @l = split( /\t/, $_ );
	my %data;
	@data{ @header } = @l;
	
	 
#	# If value doesn't exists set it to null
#	foreach (keys %data ) {
#	    $data{ $_ } = 'NULL' if( $data{ $_ } eq '');
#	}
	
	# Create SQL
	my $sql = $mainDB->generate_sql( -table => $table,
					 -data => \%data );

	next unless( defined $sql );
	# Counter
	$gen->pprogres( -total => $total,
			-v => 1 );
	
	# Insert SQL statement to the database, if we're inserting many
	# Just store the SQL which, we'll combine later on
	if( $options{ -im } ) {
	    
	    %many_sql = %{ $sql };
	    
	    foreach( @{ $sql->{ -values } } ) {
		push( @many_values, $_ );
	    }
	    
	} else {
	    
	    $mainDB->insert_sql( -table => $table,
				 %{$sql} );
	}
	
    }
    
    print "\n" if( $options{ -v } );

    # If we're inserting many, combine the SQL and insert it to the DB
    if( $options{ -im } && $#many_values > -1) {

	$many_sql{ -values } = \@many_values;

	$gen->pprint( -val => "Executing SQL Inserts" );
	
	$mainDB->insert_sql( -table => $table,
			     %many_sql );
    }
    
    
    
    # Allows importing of SQL statement many at once, instead of one by one
    # this is currently deprecated
    # $mainDB->import_many() if( defined $options{ -im } );

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
