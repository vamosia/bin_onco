package MainDB;

use strict;
use warnings;
use Data::Dumper;
use Generic;
use Term::ANSIColor;
use DBI; 
# use Exporter qw(import);
 
# our @EXPORT_OK = qw(load_dbtable load_dbpriority execute_sql import_many );
my $dbh;
my %options;
my %sql;
my %dbtable;
my %dbpriority;
my $db;
my $schema = "";
my $debug;
my $gen;

=head2 new

    Function : Creating new class
    Usage    : my $class = new MainDB( %options );
    Returns  : self class
    Args     : -db       Database. The database used for the connection

               -schema   Schema. used in the database

               -im       Insert Many. 
                         SQL statement will be inserted many at once (default = one )

               -c        Commit command for the database (default = 0)
                         
               -d        Debug Mode

               -v        Verbose Mode

               
=cut

sub new {
    my ($class, %param) = @_;
    
    %options = %param;

    $gen = new Generic( %param );
    
    $db = $param{ -db };
    
    $schema = $param{ -schema } . "." if( defined $param{ -schema } );
    
    $debug = $param{ -d };
    
    $dbh = DBI->connect("dbi:Pg:dbname=$param{ -db };host=localhost;port=5432",'postgres','ionadmin',{AutoCommit=>0,RaiseError=>1,PrintError=>0});
    
    load_dbtable();
    
    load_dbpriority();
    
    my $self = {};
    
    bless $self, $class;
    
    return $self;
}

=head2 load_db_priority

    Function : Load the priority to which the database table should be loaded
               Fiel is loaded from : $DATAHUB/firehose/table.priority.csv
    Usage    : load_dbpriority()
    Returns  : none
    Args     : none


               
=cut

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

=head2 get_dbpriority

    Function : Get the hash data structure of the database priority
    Usage    : get_priority()
    Returns  : \%dbpriority - hash data structore of the database prioirty
    Args     : none

               
=cut

sub get_dbpriority {
    
    return( \%dbpriority );
}

=head2 load_dbtable

    Function : Load the structure of mainDB into an hash structure
               File loaded from $DATAHUB/firehose/table.column.csv
    Usage    : load_dbtable()
    Returns  : none
    Args     : none

               
=cut

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




=head2 load_db_priority

    Function : 
    Usage    : 
    Returns  : 
    Args     : 
               
=cut


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

=head2 get_key_status

    Function : 
    Usage    : 
    Returns  : 
    Args     : 

               
=cut


sub get_key_status {

    my ($class, %param) = @_;
    
    my $table = $param{ -table };
    my $column = $param{ -column };
    my %ret;

    return( \%ret ) unless exists $dbtable{ $table }{ $column };
    
    foreach my $key ( keys %{ $dbtable{ $table }{ $column } } ) {
	
	$ret{ $key } = $dbtable{ $table }{ $column }{ $key } || 'NA';
    }

    return( \%ret );
}

=head2 generate_sql

    Function : Generates an SQL INSERT statement to a specific database (as defined in the object)

    Usage    : generate_sql( -table => 'variant',
                             -data  => \%data );

    Returns  : 3 parts of the SQL INSERT which includes
               $sql_insert, $sql_value, $constraint

    Args     : -table     The table to which this SQL INSERT statement will be generated
               -data      A Hash variable containing all the data

               
=cut

sub generate_sql {
    
    my ($class, %param) = @_;
    
    my $table = $param{ -table };
    my $data = $param{ -data };
    my $meta = ($param{ -table } =~ /meta/) ? 1 : 0;
    my $meta_fk;

    my @columns;
    my @value;
    my @values;
    my $constraint;
    my $reset_seq;

    foreach my $col ( sort keys %{ $dbtable{ $table } } ) {

	my $val;
	
	# get the key status, this will determine if the column is a pk, fk, etc
	my $key_stat = get_key_status( $class,
				       -table => $table,
				       -column => $col );

	# Contruct SQL constraint if required
	if( $key_stat->{ constraint } ne 'NA' ) {
	    $constraint = "ON CONFLICT ON CONSTRAINT $key_stat->{ constraint } DO NOTHING";
	} 
	
	# Generate sql statement for reseting the sequences as needed
	if($key_stat->{ pk_auto } eq 'auto' ) {
	    
	    $gen->pprint( -tag => "ERROR",
			  -val => "Reset sequence should not be defined" ) if( defined $reset_seq );
	    
	    $reset_seq = "SELECT SETVAL('${col}_seq', COALESCE( MAX($col), 1), false) FROM $table";
	}	
	
	
	# If the colums is a primary key that's auto generated, don't need to handle this
	next if ( $key_stat->{ key } eq 'pk' && $key_stat->{ pk_auto } eq 'auto' );
	
	# Get the query to extract the forein_key 
	if( $key_stat->{ key } eq 'fk' ) {
	    
	    $val = get_fk_val( $class,
			       -data => $data, 
			       %{ $key_stat } );
	    
	    $meta_fk = $val if( $meta == 1 );
	
	} else {
	    
	    # some of the column need to be map, so extract the data key from a function
	    $val = get_val( $class,
			    -table => $table,
			    -data => $data,
			    -id => $col );
	}
	 
	# If entrez_id does not exists on the database
	# 0 means that entrez_gene_id is not valid
	if( $table eq 'variant' && $col eq 'entrez_gene_id' && $val eq '0' ) {
	    
	    $gen->pprint( -tag => 'WARNING',
			  -val => "Entrez not valid | $data->{ Stable_Sample_Id } | HUGO : $data->{ Hugo_Symbol }",
			  -level => 2);
	    
	    return();
	}

 	# For non meta table, store value to @value.
	# This will be combined to @values later on;
	if( $meta == 0 ) {
	    
	    $gen->pprint( -tag => "2.GENERATE_SQL  ", 
			  -level => 1,
			  -val => "$key_stat->{ key } | TABLE: $table | COL: $col = VAL: $val",
			  -d => 1 );
	    push( @value, $val )
	}

	push( @columns, $col );
    }

    if ( $meta == 0 ) {
	
	    push( @values, \@value  ) 
		
    } elsif( $meta == 1 ) {

	# For meta table go through each data and value	
	while( my( $key, $val ) = each(%{ $data } ) ) {
	    
	    # Skip inserting these value, there's nothing here
	    next if ($val eq ''  || $val eq  ',' ||
		     $val eq '.' || $val =~ /^,+$/);

	    $val = get_val( $class,
			    -table => $table,
			    -data => $data,
			    -id => $key );
	    
	    # replace ' to ''
	    $val =~ s/\'/\'\'/g;

	    # Contruct PRIMAR_KEY, attr_id, attr_val
	    my @value;
	    
	    foreach( @columns ) {
		if( $_ eq 'attr_id' ) {
		    push( @value, $key );
	
		} elsif( $_ eq 'attr_value' ) {
		    push( @value, $val );
		
		} else {
		    push( @value, $meta_fk )
		}	    
	    }
		
	    
	    push( @values, \@value );
	}
    }
        
    # $col = "(" . join( ",", @columns) . ")";

    # 	# For the variant table, need to check if the entrez_gene_id is valid
    # 	# if not we're simply going to 'ignore the entry'
    # 	if( $table eq 'variant' ) {
    # 	    $sql_insert = sprintf 'INSERT INTO %s%s %s',$schema, $table, $col;

    # 	    $sql_value = sprintf "SELECT val.*\n FROM ( VALUES %s ) val %s \n JOIN gene USING (entrez_gene_id)",
    # 	    "(" . join( ",", @values) . ")",
    # 	    $col;
	    
    # 	} else {
    # 	    # INSERT INTO maindb_dev.patient( PATIENT_ID, STABLE_PATIENT_ID ) VALUES ( 'TCGA-XXX' )
    # 	    $sql_insert = sprintf 'INSERT INTO %s%s %s',$schema, $table, $col;
	    
    # 	    $sql_value = "(" . join( ",", @value ) . ")";
    # 	}

    return({ -columns =>  \@columns, 
	     -values => \@values, 
	     -constraint => $constraint,
	     -reset_seq => $reset_seq,
	     -table => $table });
    
}

=head2 execute_sql

    Function : 
    Usage    : 
    Returns  : 
    Args     : 
               
=cut

sub insert_sql {

    my ($class, %param) = @_;
    
    my $val = $param{ -values };
    my $col = $param{ -columns };
    my $skip = $param{ -skip } || 0;
    my $table = $param{ -table };
    my $const = $param{ -constraint } || "";

    if( $skip ) {
	$gen->pprint(-val => "Skipping SQL INSERT",
		     -v => 1 );
	return();
    }

    my $stmt_seq = $param{ -reset_seq } || "";
    
    # Reset sequence to ensure consistency
    if( exists $param{ -reset_seq } && defined $param{ -reset_seq } ) {
	
	my $rv = $dbh->do( $stmt_seq ) or die $DBI::errstr;
    }

    # Create a comma seperated list of ? for db handler
    my @var;
    
    push( @var, "?") foreach( @{ $param{ -columns } } );

    my $var = join( ",", @var );

    # Create a comma seperate list for columns
    my $cols = join( ",", @{ $col } );
    
    # Generate the sql statement
    my $stmt = "INSERT INTO $table ($cols) VALUES($var) $const";
    
    $gen->pprint( -tag => 'EXECUTE',
		  -val => "\n\n$stmt_seq;\n$stmt\n",
		  -d => 1 );

    # Prepare the sql statement
    my $sth = $dbh->prepare( $stmt );
    
    foreach ( @{ $val} ) {
	print( "('" . join( "' , '", @{$_} ) . "')\n" ) if( $options{ -d } );
	my $rv = $sth->execute( @{$_} ) or die $DBI::errstr;
    }
    
    print "\n" if( $options{-d} );
    
    # Reset sequence to ensure consistency
    if( exists $param{ -reset_seq } && defined $param{ -reset_seq} ) {
	
	# Subsequent sequence reset should be false
	$stmt_seq =~ s/false/true/;
	
	my $rv = $dbh->do( $stmt_seq ) or die $DBI::errstr;
    }
  
}


=head2 get_fk_val

    Function : Gets the SQL query statement for a foreign key
    Usage    : 
    Returns  : 
    Args     : $ret - containst he SQL Query statement               

=cut

sub get_fk_val {
    my( $class, %param ) = @_;

    # This is the data usd to look up the key
    my $fk_ref = uc( $param{ fk_ref } ); # STABLE_PATIENT_ID or PATIENT_ID|STUDY_ID
    
    my $stmt;
    my $val;
    
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
	
	$stmt = sprintf "SELECT patient_study_id FROM %spatient_study WHERE %s", $schema, $query;
	
    } else {
	
	my( $fk_table, $fk_col ) = split( /\./, $param{ fk_table } );
	
	
	$val = get_val( $class,
			-data => $param{ -data },
			-id => $fk_ref,
			-table => $fk_table );
	
	#  SELECT patient_id FROM maindb_dev.patient WHERE STABLE_PATIENT_ID = 'TCGA-OR-A5K0'
	$stmt = sprintf "SELECT %s FROM %s%s WHERE %s = ?", $fk_col, $schema, $fk_table, $fk_ref;
	print Dumper $stmt;
    }
    
    my $sth = $dbh->prepare( $stmt );
    print Dumper $val;
    my $rv = $sth->execute( $val) or die $DBI::errstr;
    
    my @row = $sth->fetchrow_array();
    print Dumper \@row;
    exit;
    return( $row[0] );
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
	
	my $fk_ref_val = get_val( $class,
				  -data => $param{ -data },
				  -id => $fk_ref,
				  -table => $fk_table );
	

	#  SELECT patient_id FROM maindb_dev.patient WHERE STABLE_PATIENT_ID = 'TCGA-OR-A5K0'
	$ret = sprintf "SELECT %s FROM %s%s WHERE %s = %s", $fk_col, $schema, $fk_table, $fk_ref, $fk_ref_val;

    }

    $ret = "($ret)";
    
    return( $ret );
}


=head2 get_val

    Function : Extract a specific value from a hash table with processing.
               Processing includes

                - Harmonizing Hugo_symbol, which is checked through gene_alias

                - Generating VarKey composit value for the variant table

    Usage    : get_val( -id   => 'entrez_gene_id',
                        -data => \%data )

    Returns  : The value from -id as defined from the -data, which has been harmonized

    Args     : -id     The value to extract
               -data   A hash table with all the values

               
=cut
    
sub get_val {
    
    my($class,
       %param ) = @_;

    my $data = $param{ -data };
    my $key = get_valid_key( $class,
			     -key => $param{ -id },
			     -data => $data );

    my $val = $data->{ $key };
    
    # Contruct VarKey if needed
    if( $key =~ /^VarKey$/i && $param{ -table } eq 'variant' ) {
	
	if( exists $data->{ VarKey } ) {
	
	    $val = $data->{ VarKey };

	} else {
	    my @VarKey = qw(CHR START_POSITION END_POSITION REF_ALLELE VAR_ALLELE);
	    
	    my @line;

	    foreach( @VarKey ) {
		$gen->pprint( -tag => 'ERROR',
			      -val => "$_ for VarKey does not exists" ) unless( $data->{ $_ } );
		
		push( @line, $data->{ $_ } )
	    }
	    $val = join( "_", @line );
	}
	
    } elsif( $key =~ /entrez_gene_id/i ) {

	my $key_hugo = get_valid_key( $class,
				      -key => 'hugo_symbol',
				      -data => $data );
	
	# hugo_symbol might be mapped to gene or gene_alias
	$val = get_entrez( $class,
			   -entrez => $data->{ $key },
			   -hugo => $data->{ $key_hugo } );
	
    } 
	    
    # Set to null if not defined
    $val = 'NULL' unless( defined $val );
    
    
    # Replace ' with '', but dont do it if we encounter a ( or )
    # ( or ) means there the value probably has an SQL syntax such as
    #   > SELECT cancer_id FROM cancer_type WHERE cancer_id = 'acc'
    # so here we don't want to create ''acc''
    $val =~ s/\'/\'\'/g  unless( $val =~ /[()]/ );
    
    # If everything is a digit don't add quotes , other add single quotes i.e 'acc'
    #$val = ($val =~ /^\d*$/ ) ? $val : "'$val'";

    return( $val );
}

=head2

    Function : Determine if a key for a hash is valid based on different capitalization
               For example the key might be
                    - Entrez_Gene_Id   
                    - ENTREZ_GENE_ID
                    - entrez_gene_id

    USAGE : get_valid_key( -key => 'entrez_gene_id',
                           -data => \%data )
    
    RETURN : The key that matches the hash variable with the correct capitalization
    
    ARGS : -key     The text key that we will search the hash variable
           -data    The hash vaiable that we will interogate
=cut

sub get_valid_key {

    my( $class,
	%param ) = @_;

    my $key = $param{ -key };
    
    # Capitalize the first letter
    my $key_ucfirst = join "_", map {ucfirst} split "_", lc($key);

    my $data = $param{ -data };
    
    if ( exists $data->{ $key } ) {
	# Do nothing, this is just to optimize the if search
	
    } elsif ( exists $data->{ lc($key) } ) {
	$key = lc($key);

    } elsif ( exists $data->{ uc($key) } ) {
	$key = uc( $key );

    } elsif( exists $data->{ $key_ucfirst } ) {
	
	$key = $key_ucfirst;
    } elsif( $key =~ /varkey/i ) {
	$key = 'VarKey' if (exists $data->{ VarKey });
    }
    return( $key );
}


=head2
    Function : Determine if entrez_gene_id is valid, if not get it from hugo
    
               Specifically this function check to see if entrez_gene_id is valid, if so return this entrez
               If not, use the Hugo_Symbol to determine if there is an entrez_gene_id 
               within the gene_alias table

    Usage    : get_entrez( -entrez => 1234,
                           -hugo   => myGene )

    Returns  : entrez_gene_id

    Args     : -entrez     : the entrez_gene_id to which we want to check
               -hugo       : if the entrez_gene_id is not valid, use hugo to check gene_alias

=cut

sub get_entrez {

    my ($class,
	%param) = @_;
    

    my $stmt = "SELECT * FROM gene WHERE entrez_gene_id = ?";

    my $sth = $dbh->prepare( $stmt );
 
    my $rv = $sth->execute( $param{ -entrez } ) or die $DBI::errstr;

    # 0E0 means does not return anything
    my $ret = $rv eq '0E0' ? 0 : $param{ -entrez };

    if( $ret == 0 ) {
	# $stmt = "SELECT * FROM gene_alias WHERE gene_alias = ?";
	
	$stmt = qq(
SELECT 
    ga.ENTREZ_GENE_ID, g.HUGO_GENE_SYMBOL
FROM
    gene_alias ga,
    gene g
WHERE ga.gene_alias = ?
AND g.ENTREZ_GENE_ID = ga.ENTREZ_GENE_ID);

	$sth = $dbh->prepare( $stmt );
	
	$rv = $sth->execute( $param{ -hugo } ) or die $DBI::errstr;
    
	if( $rv eq '1' ) {
	    my @row = $sth->fetchrow_array();
	    $ret = $row[0];
	    
	    $gen->pprint( -tag => 'ENTREZ_MAP',
			  -level => 1,
			  -val => "$param{ -hugo } ($param{ -entrez }) > $row[1] ($row[0])",
			  -v => 1 );
	    
	}

	
    }
    return( $ret );
}


=head2 load_db_priority

    Function : 
    Usage    : 
    Returns  : 
    Args     : 
               
=cut

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

=head2 Close

    Function : Close the database connection or roll back 
    Usage    : close( -c )
    Returns  : onne
    Args     : -c     Commit the changes to the database otherwill will roll them back (Default rollback)
               
=cut

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
1;

__END__
