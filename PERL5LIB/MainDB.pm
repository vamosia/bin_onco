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

=head2 execute_sql

    Function : 
    Usage    : 
    Returns  : 
    Args     : 
               
=cut

sub execute_sql {

    my ($class, %param) = @_;
    
    my $sql_insert = $param{ -insert };
    my $sql_value = $param{ -value };
    my $constraint = $param{ -constraint } || "";
    
    if( $sql_insert eq 0 ) {
	$gen->pprint(-val => "Skipping SQL INSERT",
		     -v => 1 );
	return();
    }
    
    my $stmt = $param{ -stmt } || "$sql_insert $sql_value $constraint";
    
    $gen->pprint( -tag => 'EXECUTE_SQL', 
		  -val => "\n$sql_insert\n$sql_value\n$constraint\n",
		  -level => 1,
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
    
    while( my( $key, $val ) = (each %{ $dbtable{ $table }{ $column } } ) ) {
	$ret{ $key } = $val || 'NA';
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
    my @values;
    my $constraint = "";
    
    foreach my $col ( sort keys %{ $dbtable{ $table } } ) {

	my $val;
	# get the key status, this will determine if the column is a pk, fk, etc
	my $key_stat = get_key_status( $class,
				       -table => $table,
				       -column => $col );

	# Contruct SQL constraint if required
	if( $key_stat->{ constraint } ne 'NA' ) {
	    
	    $constraint = "ON CONFLICT ON CONSTRAINT $key_stat->{ constraint } DO NOTHING";

	    if( $key_stat->{ pk_auto } eq 'auto' ) {
		$constraint .= ";\nSELECT SETVAL('${col}_seq', COALESCE( MAX($col), 1)) FROM $table";
		
	    } 
	}	
	
	# If the colums is a primary key that's auto generated, don't need to handle this
	# the DB will handle it automatically. so skip it
	if ( $key_stat->{ key } eq 'pk' && $key_stat->{ pk_auto } eq 'auto' ) {

	    # Skip primary that's auto generated by sequence

	    $gen->pprint( -level => 1, 
			  -val => "Skipping $table.$col => pk_auto",
			  -d => 1 );
	    
	    next;
	    
	# Get the query to extract the forein_key 
	} elsif( $key_stat->{ key } eq 'fk' ) {
	    
	    $val = get_fk_sql( $class,
			       -data => $data, 
			       %{ $key_stat } );
	    
	    
	    $gen->pprint( -tag => '2.GENERATE_SQL - FK', 
			  -level => 1, 
			  -val => "$col > $val",
			  -d => 2 );
	    
	    # keep track of the FK for meta_table. 
	    # There should only be 1 fk for meta_ table
	    $meta_fk = $val; 
	    
	}  elsif( $meta == 0 ) {
	    
	    # some of the columns need to be map, so extract the data key from a function
	    $val = get_val( $class,
			    -table => $table,
			    -data => $data,
			    -id => $col );
	 

	    # If entrez_id does not exists on the database
	    if( $table eq 'variant' && $col eq 'entrez_gene_id' ) {

		# 0 means that entrez_gene_id is not valid
		if( $val eq '0' ) {

		    $gen->pprint( -val => "Entrez_Gene_Id does not exists",
				  -v => 1 );

		    $gen->pprint( -val => "STABLE_SAMPLE_ID: $data->{ STABLE_SAMPLE_BARCODE }",
				   -level => 2);
		    
		    $gen->pprint( -val => "HUGO: $data->{ HUGO_SYMBOL }",
				   -level => 2);
		    
		    return(0,0,0);
		}
	    }
	    
   
	    $gen->pprint( -tag => "1.GENERATE_SQL  ", 
			  -level => 1,
			  -val => "TABLE: $table | COL: $col = VAL: $val",
			  -d => 1 );
	}

	# For meta table, store all the columns & values into array
	# will create the SQL INSERT statement seperately
	if( $meta == 0 ) {
	    push( @values, $val );
	    push( @columns, $col );
	}
    }
    
    my ($sql_insert, $sql_value );



    my %skip = ('STABLE_SAMPLE_ID' => '',
		'HUGO_SYMBOL' => '',
		'ENTREZ_GENE_ID' => '',
		'VAR_KEY' => '',
		'CHR' => '',
		'START_POSITION' => '',
		'END_POSITION' => '',
		'REF_ALLELE' => '',
		'VAR_ALLELE' => '',
		'REF_GENOME_BUILD' => '',
		'STRAND' => '',
		'Center' => ''
		'dbSNP_Val_Status' => ''
		'Verification_Status' => ''
		'Validation_Status' => ''
		'Sequencing_Phase',
		'Sequence_Source',
		'Validation_Method',
		'Score',
		'BAM_file',
		'Sequencer',


	);

    
    # For meta table go through each data and value
    if( $meta == 1 ) {


	while( my( $key, $val ) = each(%{ $data } ) ) {

	    # Skip inserting these values, there's nothing here
	    next if ($val eq '' || 
		     $val eq  ',' ||
		     $val eq '.' ||
		     $val =~ /^,+$/);

	    # Skip these values for variant_meta
	    next if( $table eq 'variant_meta' && exists $skip{ $key } );
	    
	    # replace ' to ''
	    $val =~ s/\'/\'\'/g;
	    	    
	    # Don't add double quotes to
	    $val = "'$val'" unless( $val =~ /^\d+$/ );
	    
	    push( @values, "( $meta_fk, '$key', $val )" );
	}

	$sql_insert = sprintf 'INSERT INTO %s%s VALUES',$schema, $table;
	
	$sql_value = join( ",\n", @values );
	
	
    } else {

	my $col = "(" . join( ",", @columns) . ")";

#	# For the variant table, need to check if the entrez_gene_id is valid
#	# if not we're simply going to 'ignore the entry'
#	if( $table eq 'variant' ) {
#	    $sql_insert = sprintf 'INSERT INTO %s%s %s',$schema, $table, $col;
#
#	    $sql_value = sprintf "SELECT val.*\n FROM ( VALUES %s ) val %s \n JOIN gene USING (entrez_gene_id)",
#	    "(" . join( ",", @values) . ")",
#	    $col;
#	    
#	} else {

	# INSERT INTO maindb_dev.patient( PATIENT_ID, STABLE_PATIENT_ID ) VALUES ( 'TCGA-XXX' )
	$sql_insert = sprintf 'INSERT INTO %s%s %s VALUES',$schema, $table, $col;
	
	$sql_value = "(" . join( ",", @values ) . ")";
    }
    
    return( $sql_insert, $sql_value, $constraint );
}


=head2 get_fk_sql

    Function : Gets the SQL query statement for a foreign key
    Usage    : 
    Returns  : 
    Args     : $ret - containst he SQL Query statement               

=cut

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
    
    my $key = $param{ -id };
    my $data = $param{ -data };
    my $val = $data->{ uc($key) };

    # Set to null if not defined
    $val = 'null' unless( defined $val );
    
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
    } elsif( $key eq 'entrez_gene_id' ) {

	# hugo_symbol might be mapped to gene or gene_alias
	$val = get_entrez( $class,
			   -entrez => $data->{ ENTREZ_GENE_ID },
			   -hugo => $data->{ HUGO_SYMBOL } );
    }
    

    # Replace ' with '', but dont do it if we encounter a ( or )
    # ( or ) means there the value probably has an SQL syntax such as
    #   > SELECT cancer_id FROM cancer_type WHERE cancer_id = 'acc'
    # so here we don't want to create ''acc''
    $val =~ s/\'/\'\'/g  unless( $val =~ /[()]/ );
    
    # If everything is a digit don't add quotes , other add single quotes i.e 'acc'
    $val = ($val =~ /^\d*$/ ) ? $val : "'$val'";
    
    
    return( $val );
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
	$stmt = "SELECT * FROM gene_alias WHERE gene_alias = ?";

	$sth = $dbh->prepare( $stmt );
	
	$rv = $sth->execute( $param{ -hugo } ) or die $DBI::errstr;
    
	if( $rv eq '1' ) {
	    my @row = $sth->fetchrow_array();
	    $ret = $row[0];
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
=head2 pk_exists

    Function : Check to see if this primary key eixsts in the database

    Usage    : $mainDB->pk_exists( %param )
               
    Returns  : 1  if primary key exists
               0  if primary key does not exists

    Args     : -table   : The table name that we want to check for primary key uniqness
               -column  : The column used for the checking
               
=cut


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

	    my @line = split( /\|/, $pk_uniq );
	    
	    my @search;
		
	    push( @search, "$_ = '$data->{ $_ }'" ) foreach (@line);
	    
	    my $value = join " AND ", @search;
	    

	    # Construct query	    
	    my $query = sprintf( "SELECT %s FROM %s WHERE %s", 
				 $col,
				 $key_stat->{ table },
				 $value);

	    my $id = uc( $key_stat->{ column } );
	    
	    #my $stmt = get_ref_sql( $class,
	    #			    -id => $id,
	    #			    -data => $param{ -data } );
	    
	    my $sth = $dbh->prepare( $query );
	    
	    my $rv = $sth->execute() or die $DBI::errstr;
	    
	    # 0E0 means does not return anything
	    $ret = $rv eq '0E0' ? 0 : 1;

	    $gen->pprint( -tag => 'PK_EXISTS',
			  -level => 1,
			  -val => "IGNORING LINE : TABLE = $table | $value",
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

sub generate_sql_meta {

    my ($class, %param) = @_;
        
    my $table = $param{ -table };

    my $data = $param{ -data };
    
    my @columns;
    my @values;
    my $constraint = "";
    
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

    return( $sql_insert, $sql_value, $constraint );

}


sub check_existance {

}
1;
