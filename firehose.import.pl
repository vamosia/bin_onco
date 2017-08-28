#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Generic qw(pprint read_file);
use Getopt::Long;
use Storable;


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
my %sql;
my $db = $options{ -db };
my %map_column = ( 'BCR_PATIENT_BARCODE' => 'STABLE_ID',
		   'BCR_SAMPLE_BARCODE' => 'STABLE_ID',
		   'CANCER_STUDY' => 'NAME' );


my $dbh = DBI->connect("dbi:Pg:dbname=$db;host=localhost;port=5432",'postgres','ionadmin',{AutoCommit=>0,RaiseError=>1,PrintError=>0});
# 0. Load required tables

pprint( -val => 'Loading DB tables' );
load_dbtables();

pprint( -val => 'Loading DB Priority' );
load_dbpriority();

pprint( -id => 0, -val => 'Start Importing File' );

foreach( sort { $a <=> $b } keys %dbpriority ) {
    
    %sql = ();
    
    my $table = $dbpriority{ $_ };
    
    my $file =  "data_${table}.txt";
    
    next unless ( $table eq $options{ -t } );
    
    
    # Check file (but skip meta, as meta file does not exists (data_patient_meta.txt) it is contained in the original file (data_patient.txt)
    unless( -e $file ) {
	pprint( -level => 2, tag => 'WARNING', -val => "File does not exists : $file" );
	next;
    }

    pprint( -val => "Importing '$file' to '$table'" );
    
    process_file( -t => $table,
		  -f => $file );

}

$dbh->commit();
exit;
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
	    ($sql_insert, $sql_value) = generate_sql_meta( -table => $table,
							   -data => \%line );
	    
	} else {
	    ($sql_insert, $sql_value) = generate_sql( -table => $table,
						      -data => \%line );
	    
	    
	}	

	import_sql( -insert => $sql_insert,
		    -value => $sql_value );
	
    }
    
    import_many() if( $options{ -it } eq 'many' );

    close( IN );
}


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

sub generate_sql_meta {

    my (%param) = @_;
        
    my $table = $param{ -table };

    my $data = $param{ -data };
    
    my @columns;
    my @values;

    # get the fk
    my $fk_sql;
    foreach my $col ( sort keys %{ $dbtable{ $table } } ) {

	my $key_stat = get_key_status( -table => $table,
					 -column => $col );

	# Get the query to extract the forein_key
	if ( $key_stat->{ key } eq 'fk' ) {
	    $fk_sql = get_fk_sql( -data => $data, %{ $key_stat } );
	}
    }
    
    while( my( $key, $val ) = each(%{ $data } ) ) {
	push( @values, "( $fk_sql, '$key', '$val' )" );
    }

    my $sql_value = join( ",\n", @values );
    
    my $sql_insert = sprintf 'INSERT INTO %s.%s VALUES',$db, $table;
    
    return( $sql_insert, $sql_value );

}

sub generate_sql {

    my (%param) = @_;
        
    my $table = $param{ -table };
    my $data = $param{ -data };
    
    my @columns;
    my @values;

    
    foreach my $col ( sort keys %{ $dbtable{ $table } } ) {
	my $val;
	my $key_stat = get_key_status( -table => $table,
				       -column => $col );
	# Skip primary that's auto generated by sequence
	if ( $key_stat->{ key } eq 'pk'  && $key_stat->{ pk_ref } eq 'auto' ) {
	    pprint( -level => 2, -val => "Skipping $table.$col => pk auto" ) if( $options{ -v } );
	    next;
	} if( $key_stat->{ key } eq 'fk' ) {
	    
	    $val = get_fk_sql( -data => $data, %{ $key_stat } );
	    
	    push( @values, $val );
	    
	} else {
	    
	    $val = $data->{ uc( $col ) };
	    
	    push( @values, "'$val'" );
	}
	
	
	push( @columns, $col );
    }

    my $sql_value = "(" . join( ",", @values ) . ")";
    
    my $col = "(" . join( ",", @columns) . ")";
    
    # INSERT STATEMENT
    # INSERT INTO maindb_dev.patient( PATIENT_ID, STABLE_ID ) VALUES ( 'TCGA-XXX' )
    my $sql_insert = sprintf 'INSERT INTO %s.%s %s VALUES',$db, $table, $col;
    
    return( $sql_insert, $sql_value );
    
}

sub get_fk_sql {
    my( %param ) = @_;

    my $fk_ref = uc( $param{ fk_ref } ); # STABLE_ID

    my $fk_ref_val = $param{ -data }->{ $fk_ref };
    my( $fk_table, $fk_col ) = split( /\./, $param{ fk_table } );

    #  SELECT patient_id FROM maindb_dev.patient WHERE STABLE_ID = 'TCGA-OR-A5K0'
    my $ret = sprintf "SELECT %s FROM %s.%s WHERE %s = '%s'", $fk_col, $db, $fk_table, $fk_ref, $fk_ref_val;

    return( "($ret)" );
}

sub get_key_status {

    my (%param) = @_;
    
    my $table = $param{ -table };
    my $column = $param{ -column };
    my %ret;
    
    while( my( $key, $val ) = (each %{ $dbtable{ $table }{ $column } } ) ) {
	$ret{ $key } = $val || 'NA';
    }

    return( \%ret );
}

sub load_dbpriority {

    my $file = `echo \$DATAHUB/firehose/table.priority.csv`; chomp $file;

    open( IN, "<$file" ) or die "$!\n";
    my $header = 0;
    my @header;
    
    while( <IN> ) {
	chomp $_;

	next if( $_ =~ /^,/ );

	if( $header == 0 ) {
	    $_ =~ s/#//g;
	    @header = split( /,/, $_ );
	    $header++;
	    next;
	}
	my @l = split( /,/, $_ );
	my %line;
	@line{ @header } = @l;

	next unless( defined $line{ priority }  );
	$dbpriority{ $line{ priority } } = $line{ table };
    }
}

sub load_dbtables {
    
    my $file = `echo \$DATAHUB/firehose/table.column.csv`; chomp $file;

    open( IN, "<$file" ) or die "$!\n";
    my $header = 0;
    my @header;

    while( <IN> ) {
	chomp $_;

	next if( $_ =~ /^,/ );

	if( $header == 0 ) {
	    $_ =~ s/#//g;
	    @header = split( /,/, $_ );
	    $header++;
	    next;
	}
	my @l = split( /,/, $_ );
	my %line;
	@line{ @header } = @l;
	
	# 0 - db
	# 1 - table
	# 2 - column
	# 3 - key
	# 4 - fk_table
	# 5 - fk_column
	# 6 - nk_column

	my $table = $line{table};
	my $column = $line{column};
	my $key = $line{key};

	
	$dbtable{ $table }{ $column } = \%line;
    }
    
    close( IN );

}

sub open_connection {

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
