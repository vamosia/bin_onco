#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Generic qw(pprint read_file);
use Getopt::Long;
use Storable;
use MainDB;


my %dbtable;
my %dbpriority;
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
my $debug = $options{ -d };

my $gen = new Generic( %options );

my $mainDB = new MainDB( %options );

my %sql;

#my $dbh = DBI->connect("dbi:Pg:dbname=$db;host=localhost;port=5432",'postgres','ionadmin',{AutoCommit=>0,RaiseError=>1,PrintError=>0});
# 0. Load required tables

$gen->pprint( -level => 0,
	      -val => "FIREHOSE IMPORT" );

# Load the database structure
$mainDB->load_dbtable();

# Load the priority of tables we should import
$mainDB->load_dbpriority();

$gen->pprint( -val => 'Start Importing File' );

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
	$gen->pprint( -tag => 'IGNORE', 
		      -val => "$table is part of seedDB" );
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

# 1. Load data_cancer_study.txt

# 3. Load data_patient_clinical.txt

# 4. Load data_sample.txt;

# 5. Load_data_sample_clinical.txt

# 2. Load Mutation
# Directory = stddata__2016_01_28/ACC/20160128/*ACC.Mutation_Packager_Oncotated_Calls.Level_3*
    
# 3. Load GISTIC2
# Directory = analyses__2016_01_28//ACC/20160128/


############################################################
# SUBROUTINE


sub process_file {
    
    my( %param ) = @_;

    my $file = $param{ -f };
    my $table = $param{ -t };

    
    open( IN, "<$file" ) or die "$!\n";
    my $header = 0;
    my @header;
    my $cnt = 0;
    
    while( <IN> ) {

	chomp $_;
	
	if( $header == 0 ) {
	    @header = split( /\t/, $_ );

	    $header = 1;
	    
	    next
	}
	
	my @l = split( /\t/, $_ );
	my %data;
	@data{ @header } = @l;
	
	# Create SQL
	my ($sql_insert, $sql_value) = $mainDB->generate_sql( -table => $table,
							      -data => \%data );
		
#	$gen->pprint( -tag => 'SQL',
#		      -level => 1, 
#		      -val => "$sql_insert \n $sql_value\n" );

	$mainDB->import_sql( -insert => $sql_insert,
			     -value => $sql_value );

	# Counter
	$cnt++;
	print "$cnt\r" if( $options{ -v } )
    }
    
    print "\n" if( $options{ -v } );
   
    $mainDB->import_many() if( defined $options{ -im } );

    close( IN );
}


sub test_connection {
    my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=localhost;port=5432",'postgres','ionadmin',{AutoCommit=>1,RaiseError=>1,PrintError=>0});
    my $stmt = qq(SELECT * FROM maindb.cancer_type );
    my $sth = $dbh->prepare( $stmt );
    my $rv = $sth->execute() or die $DBI::errstr;

    print $DBI::errstr if($rv < 0);
    #while(my @row = $sth->fetchrow_array()) {
    #print Dumper \@row;
    #    }
    print "Operation done successfully\n";
    $dbh->disconnect();
    
}


__END__
