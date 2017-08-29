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
my %options = ( -d => 0,
		-db => 'maindb_dev',
		-it => 'one' );

GetOptions( 'd=i'    => \$options{ -d },
	    'v'      => \$options{ -v },
	    'db=s'   => \$options{ -db },
	    't=s'    => \$options{ -t },
	    'it=s'   => \$options{ -it }         # INSERT TYPE
    ) or die "Incorrect Options $0!\n";


my $mainDB = new MainDB( -db => $options{ -db },
			 -d  => $options{ -d },
			 -it => $options{ -it } );

my %sql;
my %map_column = ( 'BCR_PATIENT_BARCODE' => 'STABLE_ID',
		   'BCR_SAMPLE_BARCODE' => 'STABLE_ID',
		   'CANCER_STUDY' => 'NAME' );

#my $dbh = DBI->connect("dbi:Pg:dbname=$db;host=localhost;port=5432",'postgres','ionadmin',{AutoCommit=>0,RaiseError=>1,PrintError=>0});
# 0. Load required tables

pprint( -val => 'Loading DB tables' );
$mainDB->load_dbtable();

pprint( -val => 'Loading DB Priority' );
$mainDB->load_dbpriority();

pprint( -id => 0, -val => 'Start Importing File' );

my $dbpriority = $mainDB->get_dbpriority();

foreach( sort { $a <=> $b } keys %{ $dbpriority } ) {
    
    %sql = ();
    
    my $table = $dbpriority->{ $_ };
    
    my $file =  "data_${table}.txt";
    
    next if( exists $options{ -t } && $table ne $options{ -t } );
    
    # Check file (but skip meta, as meta file does not exists (data_patient_meta.txt) it is contained in the original file (data_patient.txt)
    unless( -e $file ) {
	pprint( -level => 2, tag => 'WARNING', -val => "File does not exists : $file" );
	next;
    }

    pprint( -val => "Importing '$file' to '$table'" );
    
    process_file( -t => $table,
		  -f => $file );

}

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
    my $meta = ($param{ -f } =~ /meta/) ? 1 : 0;
    
    open( IN, "<$file" ) or die "$!\n";
    my $header = 0;
    my @header;
    
    while( <IN> ) {
	chomp $_;
	
	if( $header == 0 ) {
	    @header = split( /\t/, $_ );

	    
	    for( 0 .. $#header ) {
		my $column = $header[$_];

		if( exists $map_column{ $column } ) {

		    # Exception for sample table
		    # this is because BCR_SAMPLE_BARCODE && BCR_PATIENT_BARCODE maps to the same value
		    next if( $table eq 'sample' && $column =~ /BCR.*BARCODE/ );
		    
		    $header[$_ ] = $map_column{ $column }
		}
	    }
	    
	    $header = 1;
	    
	    next
	}
	
	my @l = split( /\t/, $_ );
	my %line;
	@line{ @header } = @l;
	
	# Create SQL
	my ($sql_insert, $sql_value );
	if( $meta ) {
	    ($sql_insert, $sql_value) = $mainDB->generate_sql_meta( -table => $table,
								    -data => \%line );
	    
	} else {
	    ($sql_insert, $sql_value) = $mainDB->generate_sql( -table => $table,
							       -data => \%line );
	    
	    
	}	

	$mainDB->import_sql( -insert => $sql_insert,
			     -value => $sql_value );
	
    }
    
    $mainDB->import_many() if( $options{ -it } eq 'many' );

    close( IN );
}


sub test_connection {
    my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=localhost;port=5432",'postgres','ionadmin',{AutoCommit=>1,RaiseError=>1,PrintError=>0});
    my $stmt = qq(SELECT * FROM maindb.cancer_type );
    my $sth = $dbh->prepare( $stmt );
    my $rv = $sth->execute() or die $DBI::errstr;
    if($rv < 0) {
	print $DBI::errstr;
    }
    #while(my @row = $sth->fetchrow_array()) {
    #print Dumper \@row;
    #    }
    print "Operation done successfully\n";
    $dbh->disconnect();
    
}


__END__

sub import_sql {
    
    my (%param) = @_;
    
    my $sql_insert = $param{ -insert };
    my $sql_value = $param{ -value };
    
    my $stmt = $param{ -stmt } || $sql_insert . $sql_value;

    pprint( -level => 2, -tag => 'sql', -val => $stmt ) if( $options{ -d } );

    my $rv;
    
    if( $options{ -it } eq 'one' ) {
	# Insert one by one
	$rv = $dbh->do($stmt) or die $DBI::errstr;	
	
    } elsif( $options{ -it } eq 'many' ) {

	unless( exists $sql{ insert } ) {
	    $sql{ insert } = $sql_insert;
	}
	
	# Insert many at once
	push( @{ $sql{ value } }, $sql_value );
	
    } else {
	pprint( -tag => 'error', -val => 'Insert Type not Valid' );
    }
}

sub import_many {
    
    my $sql_insert = $sql{ 'insert' };
    my @sql_value = @{ $sql{ 'value' } };
    
    my $val = join( ",", @sql_value );
    my $stmt = "$sql_insert $val";

    # pprint( -val => "$stmt" ) if( $options{ -d } == 2 );
    
    #my $rv = $dbh->do($stmt) or die $DBI::errstr;
    my $rv = $dbh->do($stmt) or die $dbh->rollback();
    
}

