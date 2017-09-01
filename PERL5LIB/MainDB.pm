package MainDB;

use strict;
use warnings;
use Data::Dumper;
use Generic;
use Term::ANSIColor;
use DBI; 
# use Exporter qw(import);
 
# our @EXPORT_OK = qw(load_dbtable load_dbpriority import_sql import_many );
my $dbh;
my %options;
my %sql;
my %dbtable;
my %dbpriority;
my $db;
my $schema = "";
my $debug;
my $gen;

sub new {
    my ($class, %param) = @_;
    
    %options = %param;

    $gen = new Generic( %param );
    
    $db = $param{ -db };
    
    $schema = $param{ -schema } . "." if( defined $param{ -schema } );
    
    $debug = $param{ -d } || 0;
    
    $dbh = DBI->connect("dbi:Pg:dbname=$param{ -db };host=localhost;port=5432",'postgres','ionadmin',{AutoCommit=>0,RaiseError=>1,PrintError=>0});
    
    load_dbtable();
    
    load_dbpriority();
    
    my $self = {};
    
    bless $self, $class;
    
    return $self;
}

sub load_dbpriority {
    
    my( $class, %param ) = @_;

    $gen->pprint( -val => 'Loading DB Priority',
		  -v => 1);
    
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

sub get_dbpriority {
    
    return( \%dbpriority );
}

sub load_dbtable {

    my( $class, %param) = @_;

    $gen->pprint( -val => 'Loading DB tables',
		  -v => 1 );
    
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

sub import_sql {

    my ($class, %param) = @_;
    
    my $sql_insert = $param{ -insert };
    my $sql_value = $param{ -value };
    
    my $stmt = $param{ -stmt } || $sql_insert . $sql_value;
    
    $gen->pprint( -tag => 'IMPORT_SQL', 
		  -val => "\n$sql_insert\n$sql_value\n",
		  -level => 2,
		  -d => 1 );
    
    my $rv;
    
    if( defined $options{ -im } ) {
	
	unless( exists $sql{ insert } ) {
	    $sql{ insert } = $sql_insert;
	}
	
	# Insert many at once
	push( @{ $sql{ value } }, $sql_value );
	
    } else {
	# Insert one by one
	$rv = $dbh->do($stmt) or die $DBI::errstr;	
    }
}

sub import_many {

    my ($class, %param) = @_;
    
    my $sql_insert = $sql{ 'insert' };
    my @sql_value = @{ $sql{ 'value' } };
    
    my $val = join( ",", @sql_value );
    my $stmt = "$sql_insert $val";

    # $gen->pprint( -val => "$stmt" ) if( $options{ -d } == 2 );
    
    #my $rv = $dbh->do($stmt) or die $DBI::errstr;
    my $rv = $dbh->do($stmt) or die $dbh->rollback();
    
}

sub get_key_status {

    my ($class, %param) = @_;
    
    my $table = $param{ -table };
    my $column = $param{ -column };
    my %ret;
    
    while( my( $key, $val ) = (each %{ $dbtable{ $table }{ $column } } ) ) {
	$ret{ $key } = $val || 'NA';
    }

    return( \%ret );
}

sub generate_sql_meta {

    my ($class, %param) = @_;
        
    my $table = $param{ -table };

    my $data = $param{ -data };
    
    my @columns;
    my @values;

    # get the fk
    my $fk_sql;
    foreach my $col ( sort keys %{ $dbtable{ $table } } ) {

	my $key_stat = get_key_status( $class,
				       -table => $table,
				       -column => $col );
	
	# Get the query to extract the forein_key
	if ( $key_stat->{ key } eq 'fk' ) {
	    $fk_sql = get_fk_sql( $class,
				  -data => $data, 
				  %{ $key_stat } );
	}
	
	
    }
    
    while( my( $key, $val ) = each(%{ $data } ) ) {
	push( @values, "( $fk_sql, '$key', '$val' )" );
    }
    my $sql_insert = sprintf 'INSERT INTO %s%s VALUES',$schema, $table;    

    my $sql_value = join( ",\n", @values );
    
    $gen->pprint( -tag => 'GENERATE_SQL_META', 
		  -val => "$sql_insert\n$sql_value\n",
		  -d => 1 );

    return( $sql_insert, $sql_value );

}

sub generate_sql {
    
    my ($class, %param) = @_;
    
    my $table = $param{ -table };
    my $data = $param{ -data };
    my $meta = ($param{ -table } =~ /meta/) ? 1 : 0;
    my $meta_fk;
    my @columns;
    my @values;
    
    foreach my $col ( sort keys %{ $dbtable{ $table } } ) {

	my $val;

	$gen->pprint( -tag => 'GENERATE_SQL   ', 
		      -level => 1, 
		      -val => "Working on : $col" ,
		      -d => 1 );
	
	my $key_stat = get_key_status( $class,
				       -table => $table,
				       -column => $col );
	
	# Skip primary that's auto generated by sequence
	if ( $key_stat->{ key } eq 'pk' && $key_stat->{ pk_auto } eq 'auto' ) {

	    $gen->pprint( -level => 1, 
			  -val => "Skipping $table.$col => pk_auto",
			  -d => 1 );

	    
	    next;
	    
	# Get the query to extract the forein_key 
	} elsif( $key_stat->{ key } eq 'fk' ) {

	    
	    $val = get_fk_sql( $class,
			       -data => $data, 
			       %{ $key_stat } );
	    
	    
	    $gen->pprint( -tag => 'GENERATE_SQL FK', 
			  -level => 2, 
			  -val => "$val\n",
			  -d => 1 );

	    # keep track of the FK for meta_table. 
	    # There should only be 1 fk for meta_ table
	    $meta_fk = $val; 
	    
	}  elsif( $meta == 0 ) {
	    
	    # some of the columns need to be map, so extract the data key from a function
	    $val = get_val( -table => $table,
			    -data => $data,
			    -id => $col );
	    
	    $gen->pprint( -tag => "GENERATE_SQL  ++", 
			  -level => 2,
			  -val => " TABLE: $table | COL: $col = VAL: $val\n",
			  -d => 1 );
	    
	}
	
	if( $meta == 0 ) {
	    push( @values, $val );
	    push( @columns, $col );
	}
    }

    my ($sql_insert, $sql_value );
    
    # For meta table go through each data and value
    if( $meta == 1 ) {
	
	while( my( $key, $val ) = each(%{ $data } ) ) {
	    push( @values, "( $meta_fk, '$key', '$val' )" );
	}
	
	$sql_insert = sprintf 'INSERT INTO %s%s VALUES',$schema, $table;    
	
	$sql_value = join( ",\n", @values );
	
	$gen->pprint( -tag => 'GENERATE_SQL_META', 
		      -val => "$sql_insert\n$sql_value\n",
		      -d => 1 );
	
    } else {

	my $col = "(" . join( ",", @columns) . ")";
	
	# INSERT INTO maindb_dev.patient( PATIENT_ID, STABLE_PATIENT_ID ) VALUES ( 'TCGA-XXX' )
	$sql_insert = sprintf 'INSERT INTO %s%s %s VALUES',$schema, $table, $col;
	
	$sql_value = "(" . join( ",", @values ) . ")";
	
	$gen->pprint( -tag => 'GENERATE_SQL ==', 
		      -level => 1,
		      -val => "$sql_insert \n $sql_value\n",
		      -d => 1 );
    }
    
    return( $sql_insert, $sql_value );
}

    
sub get_fk_sql {
    my( $class, %param ) = @_;

    # This is the data usd to look up the key
    my $fk_ref = uc( $param{ fk_ref } ); # STABLE_PATIENT_ID or PATIENT_ID|STUDY_ID

    my $ret;

    # If there is a | in the reference key, need to dereference it

    if( $fk_ref =~ /\|/ ) {

	my @line = split( /\|/, $fk_ref );
	
	my @sql;
	
	foreach (@line) {

	    my $sql = get_ref_sql( $class,
				   -id => $_,
				   -data => $param{ -data } );

	    push( @sql, "$_ = ($sql)" );
	    
	}
	
	my $query = join( " AND ", @sql );
	
	$ret = sprintf "SELECT patient_study_id FROM %spatient_study WHERE %s", $schema, $query;
	
    } else {

	my( $fk_table, $fk_col ) = split( /\./, $param{ fk_table } );
	
	#my $fk_ref_val = $param{ -data }->{ $fk_ref };
	
	my $fk_ref_val = get_val( -data => $param{ -data },
				  -id => $fk_ref,
				  -table => $fk_table );
	
	#  SELECT patient_id FROM maindb_dev.patient WHERE STABLE_PATIENT_ID = 'TCGA-OR-A5K0'
	$ret = sprintf "SELECT %s FROM %s%s WHERE %s = %s", $fk_col, $schema, $fk_table, $fk_ref, $fk_ref_val;

    }

    $ret = "($ret)";
    
    return( $ret );
}

sub get_val {
    
    my( %param ) = @_;
    
    my $key = $param{ -id };
    
    my $val = $param{ -data }->{ uc($key) };
    
    # Replace ' with '', but dont do it if we encounter a ( or )
    # ( or ) means there the value probably has an SQL syntax such as
    #   > SELECT cancer_id FROM cancer_type WHERE cancer_id = 'acc'
    # so here we don't want to create ''acc''
    
    $val =~ s/\'/\'\'/g  unless( $val =~ /[()]/ );
    
    $val = "'$val'";
    
    
    return( $val );
}

# Get the SQL for de-referencing a fk
sub get_ref_sql {
    
    my( $class, %param ) = @_;
    
    my $ret;

    my %query = ( 'PATIENT_ID' => "SELECT patient_id FROM ${schema}patient WHERE stable_patient_id = '$param{ -data }{ STABLE_PATIENT_ID }'",
		  'SAMPLE_ID' => "SELECT sample_id FROM ${schema}sample WHERE stable_sample_id = '$param{ -data }{ STABLE_SAMPLE_ID }'",
		  'STUDY_ID' => "SELECT study_id FROM ${schema}study WHERE study_name = '$param{ -data }{ STUDY_NAME }'" );
    
    $gen->pprint( -tag => 'GET_REF_SQL',
		  -val => $query{ $param{-id} },
		  -d => 1 );
    
    return( $query{ $param{-id} } );
    
}

sub close {

    if( defined $options{ -c } && $options{ -c } ) {
	$gen->pprint( -val => "DB Commit" );
	$dbh->commit();
    } else {
	$gen->pprint( -val => "DB Rollback" );
	$dbh->rollback();
    }
    $dbh->disconnect();
}

# Chekc if the pk already exists
# 0 = no
# 1 = yes
sub pk_exists {
    
    my( $class,
	%param ) = @_;
    
    my $table = $param{ -table };
    my $data = $param{ -data };
    my $ret = 0;
    
    foreach my $col ( sort keys %{ $dbtable{ $table } } ) {
	
	my $key_stat = get_key_status( $class,
				       -table => $table,
				       -column => $col );
	
	# check for uniqness will be ased on the pk_uniq
	if ( $key_stat->{ key } eq 'pk' &&
	     $key_stat->{ pk_uniq } ne 'NA' &&
	     $key_stat->{ pk_auto } eq 'auto' ) {
	    
	    my $pk_uniq = uc( $key_stat->{ pk_uniq } );
	    
	    # Construct query	    
	    my $query = sprintf( "SELECT %s FROM %s WHERE %s", 
				 $key_stat->{ column },
				 $key_stat->{ table } );
				 
	    my @line = split( /\|/, $pk_uniq );
	    
	    my @search;
	    foreach (@line) {
		push( @search, "$_ = $data->{ $_ }" );
		
	    }
	    print Dumper $data;exit;
	    print Dumper \@search;
		
	    my $id = uc( $key_stat->{ column } );
	    
	    
	    my $stmt = get_ref_sql( $class,
				    -id => $id,
				    -data => $param{ -data } );
		    
	    my $sth = $dbh->prepare( $stmt );
	    
	    my $rv = $sth->execute() or die $DBI::errstr;
	    
		    # 0E0 means does not return anything
	    $ret = $rv eq '0E0' ? 0 : 1;
	    
	    $gen->pprint( -tag => 'PK_EXISTS',
			  -level => 1,
				  -val => "$table : $param{ -data }->{ $pk_uniq } : $ret -> SKIPPING",
			  -v => 1 ) if( $ret );
	}
    }
    
    
    return( $ret );
}
1;

__END__

# Check for uniqness of a key
# we don't want to for example, insert the same STABLE_SAMPLE_ID, twice in the sample table
sub check_uniq {
    my( $class, %param ) = @_;
    my %key_stat;
    my $pk_uniq = uc( $param{ -key_stat }->{ pk_uniq } );
    my $id = uc( $param{ -key_stat }->{ column } );
    my $data = $param{ -data };

    my $ret = 1;

    # check for uniqness will be ased on the pk_uniq
    if( $pk_uniq ne 'NA' ) {
	
	my $stmt = get_ref_sql( $class,
				-id => $id,
				-data => $data );
	
	my $sth = $dbh->prepare( $stmt );
	
	my $rv = $sth->execute() or die $DBI::errstr;
	print Dumper $rv;

	
	# 0E0 means does not return anything
	$ret = $rv eq '0E0' ? 0 : 1;
    }
    
    return( $ret );
}

sub check_existance {

}
1;
