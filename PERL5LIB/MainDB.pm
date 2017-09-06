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
my %seen_entrez_map;
my @many_sql;
my %many_sql;
my %gene_entrez;
my %gene_hugo;
my %gene_alias;
=head2 new

    Function : Creating new class
    Usage    : my $class = new MainDB( %options );
    Returns  : self class
    Args     : -db       Database. The database used for the connection

               -schema   Schema. used in the database

               -io         Insert SQL statement one by one (default = many at once

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

    load_gene();
    load_gene_alias();
    
    my $self = {};
    
    bless $self, $class;
    
    return $self;
}

sub load_gene {

    $gen->pprint( -val => 'Loading Gene' );

    
    my $file = `echo \$DATAHUB/genome/hg19/entrez.hugo.csv`; chomp $file;
    
    open( IN, "<$file" ) or die "$! $file\n";

    my $header = 0;

    while( <IN> ) {
	chomp $_;

	if( $header == 0 ) {
	    $header++;
	    next;
	}
	
	my @line = split( /\,/, $_ );

	# 0 enterz
	# 1 hugo
	
	$gene_entrez{ $line[0] } = $line[1];
	$gene_hugo{ $line[1] } = $line[0];
    }
}


sub load_gene_alias {

    $gen->pprint( -val => 'Loading Gene Alias' );

	
    
    my $file = `echo \$DATAHUB/genome/hg19/entrez.gene_alias.csv`; chomp $file;
    
    open( IN, "<$file" ) or die "$! $file\n";
    
    my $header = 0;
    
    while( <IN> ) {
	chomp $_;
	
	if( $header == 0 ) {
	    $header++;
	    next;
	}
	
	my @line = split( /\,/, $_ );

	# 0 enterz
	# 1 hugo
	
	$gene_alias{ $line[1] } = $line[0];
    }
    
    close( IN );
    
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

    $gen->pprint( -val => 'Loading DB Priority' );
    
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

    $gen->pprint( -val => 'Loading DB tables' );
    
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

sub check_fix_data {
    my( $class,
	%param) = @_;

    my $ret = 1;
    
    my $table = $param{ -table };

    my $data = $param{ -data };
    
    my $entrez_key = get_valid_key( $class,
				    -key => 'entrez_gene_id',
				    -data => $data );

    my $hugo_key = get_valid_key( $class,
				  -key => 'hugo_gene_symbol',
				  -data => $data );

    # Does entrez_gene_id key exists.
    if( defined $entrez_key ) {

	my $entrez = get_val( $class,
			      -table => $table,
			      -data => $data,
			      -id => 'entrez_gene_id' );
			

	my $hugo = get_val( $class,
			    -table => $table,
			    -data => $data,
			     -id => 'hugo_gene_symbol' );

	if( $entrez =~ /^\d+$/ ) {

	    # If found entrez is different from the data, store the new one
	    if(  $entrez ne $data->{ $entrez_key } ) {
		
		$data->{ $entrez_key } = $entrez;
	    
	    }
	    
	    
	} else {

	    $ret = 0;
	    $gen->pprint( -tag => 'WARNING',
			  -val => "Entrez not valid | HUGO : $hugo ($data->{ Entrez_Gene_Id } ). Skipping processing of this line",
			  -level => 2,
			  -dd => 1 );
	    
	    
	}
    }

    return( $ret );
}

sub generate_sql {
    
    my ($class, %param) = @_;
    
    my $table = $param{ -table };
    my $data = $param{ -data };
    my $meta = ($param{ -table } =~ /meta/) ? 1 : 0;
    my (@columns, @value, @values);
    my $constraint;
    my $reset_seq;
    

    # Precheck
    return() if( check_fix_data( $class, %param ) == 0 );    

    if( $meta == 0 ) {
	
	foreach my $col ( sort keys %{ $dbtable{ $table } } ) {
	    
	    my $val;
	    
	    # get the key status, this will determine if the column is a pk, fk, etc
	    my $key_stat = get_key_status( $class,
					   -table => $table,
					   -column => $col );

	    # Contruct Constraint if required
	    if( $key_stat->{ constraint } ne 'NA' ) {
		$constraint = "ON CONFLICT ON CONSTRAINT $key_stat->{ constraint } DO NOTHING";
	    } 

	    # Generate sql statement for reseting the sequences as needed
	    if($key_stat->{ pk_auto } eq 'auto' ) {
		
		$gen->pprint( -tag => "ERROR",
			      -val => "Reset sequence should not be defined" ) if( defined $reset_seq );
		
		$reset_seq = "SELECT SETVAL('${col}_seq', COALESCE( MAX($col), 1), false) FROM $table";
	    }	
	    
	    # PK - If the colums is a primary key that's auto generated, don't need to handle this
	    if ( $key_stat->{ key } eq 'pk' && $key_stat->{ pk_auto } eq 'auto' ) {
		
		next;
		
	    } elsif( $key_stat->{ key } eq 'fk' && ! ($col =~ /entrez_gene_id/ ) ) {

		# FK - Get the query to extract the foreign_key
		# Entrez_Gene_ID is handled by get_val not get_fk_val

		$val = get_fk_val( $class,
				   -data => $data, 
				   %{ $key_stat } );

		unless( defined $val ) {
		    $gen->pprint( -tag => 'WARNING',
				  -val => "FK Not Defined for '$key_stat->{ table }' using '$key_stat->{ fk_ref }'",
				  -dd => 1 );
		    return( undef );
		}
		
		
	    } else { 

		# For non meta table, store value to @value. This will be combined to @values later on;
		$val = get_val( $class,
				-table => $table,
				-data => $data,
				-id => $col );
		
		
	    }

	    push( @value, $val );   	    	     	    
	    push( @columns, $col ); # This needs to be here are we don't want the value that's skipped by next
	    
	    $gen->pprint( -tag => "1.GENERATE_SQL  ", 
			  -level => 1,
			  -val => "$key_stat->{ key } | TABLE: $table | COL: $col = VAL: $val",
			  -ddd => 1 );

	    
	    
	}# End for loop
	push( @values, \@value  );

    } else {
	
	# For meta table, we first need to extract the main fk
	my $meta_fk;

	foreach my $col ( sort keys %{ $dbtable{ $table } } ) {
	    
	    # get the key status, this will determine if the column is a pk, fk, etc
	    my $key_stat = get_key_status( $class,
					   -table => $table,
					   -column => $col );

	    # This needs to be here to capture those that are skiped by the next command
	    push( @columns, $col );
	       
	    # Contruct Constraint if required
	    if( $key_stat->{ constraint } ne 'NA' ) {
		$constraint = "ON CONFLICT ON CONSTRAINT $key_stat->{ constraint } DO NOTHING";
	    } 

	    if( $col =~ /^entrez_gene_id$/ ) {
		$meta_fk = get_val( $class,
				    -table => $table,
				    -data => $data,
				    -id => $col );
		
		
	    } elsif( $key_stat->{ key } eq 'fk' ) {
		
		$meta_fk = get_fk_val( $class,
				       -data => $data, 
				       %{ $key_stat } );
		
	    } else {
		next;
	    }
	     
	    # Error if no meta_fk is found
	    $gen->pprint( -tag => 'error',
			  -val => 'Meta FK not defined' ) if( ! defined $meta_fk );
	    
	    
	    $gen->pprint( -tag => "2.MAIN_FK  ", 
			  -level => 1,
			  -val => "$key_stat->{ key } | TABLE: $table | COL: $col = VAL: $meta_fk",
			  -dd => 1 );
	    
	    
	    
	} # End for loop

	# now go thorugh each data
	while( my( $key, $val ) = each(%{ $data } ) ) {

	    # Skip inserting these value, there's nothing here
	    next if ($val eq ''  || $val eq  ',' || $val eq '.' || $val =~ /^,+$/);

	    
	    $val = get_val( $class,
			    -table => $table,
			    -data => $data,
			    -id => $key );

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
	     $gen->pprint( -tag => "2.GENERATE_SQL  ", 
	      		  -level => 1,
	      		  -val => "META | TABLE: $table | COL: $key = VAL: '$val'",
			   -ddd => 1 );
	    
	 
	    push( @values, \@value );
	}
    }
    
    # INSERT SQL
    my %sql = ( '-columns' =>  \@columns, 
		'-values' => \@values, 
		'-constraint' => $constraint,
		'-reset_seq' => $reset_seq,
		'-table' => $table );


    if( $param{ -io } ) {

	insert_sql( $class, %sql );


    } else {
	
	%many_sql = %sql;
	push( @many_sql, @values );
	
    }
}

=head2 execute_sql

    Function : 
    Usage    : 
    Returns  : 
    Args     : 
               
=cut

sub insert_sql {

    my ($class, 
	%param) = @_;

    if( defined $param{ -io } ) {
	return();
    
    } if( $param{ -skip } || 0 ) {
	$gen->pprint(-val => "Skipping SQL INSERT",
		     -v => 1 );
	return();

    }
    
    # If we're using the insert many method,
    my $cnt = scalar @many_sql;
    if( $cnt > 0 ) {
	
	$many_sql{ -values } = \@many_sql;
	%param = %many_sql;
	
    }
    
    my $table = $param{ -table };    
    my $col = $param{ -columns };
    my $val = $param{ -values };
    my $const = $param{ -constraint } || "";
    my $stmt_seq = $param{ -reset_seq } || "";
    

    # Reset sequence to ensure consistency, do this only once
    if( exists $param{ -reset_seq } && defined $param{ -reset_seq } && ! defined $options{ -io } ) {

#	$gen->pprint( -val => 'Reseting Sequence (Pre)',
#		      -v => 1 );
	
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
		  -dd => 1 );

    # Prepare the sql statement
    my $sth = $dbh->prepare( $stmt );

    foreach my $q ( @{ $val} ) {
	print( "('" . join( "' , '", @{$q} ) . "')\n" ) if( $options{ -dd } );
	my $rv = $sth->execute( @{$q} ) or die $DBI::errstr;
    }

    
    
    # Reset sequence to ensure consistency, in case of rollback
    if( exists $param{ -reset_seq } && defined $param{ -reset_seq} ) {
	
	#$gen->pprint( -val => 'Reseting Sequence (Post)',
       	#      -v => 1 );
	
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
    my( $class, 
	%param ) = @_;
    
    # This is the data usd to look up the key
    my $fk_ref = uc( $param{ fk_ref } ); # STABLE_PATIENT_ID or PATIENT_ID|STUDY_ID
    my( $fk_table, $fk_col ) = split( /\./, $param{ fk_table } );

    my ($stmt, $sth, $rv, @row, $val );
    
    # If there is a | in the reference key, need to dereference it

    if( $fk_ref =~ /\|/ ) {

	my @line = split( /\|/, $fk_ref );
	
	my @query;
	my @val;
	foreach (@line) {

	    my $val = get_val( $class,
			       -data => $param{ -data },
			       -id => $_,
			       -table => $fk_table );
	    
	    push( @query, "$_ = ?" );
	    push( @val, $val );
	}
	
	my $query = join( " AND ", @query );
	
	$stmt = sprintf "SELECT %s FROM %s WHERE %s", $fk_col, $fk_table, $query;

	$sth = $dbh->prepare( $stmt );
	
	$rv = $sth->execute( @val ) or die $DBI::errstr;
	
	@row = $sth->fetchrow_array();
	
	
    } else {

	$val = get_val( $class,
			-data => $param{ -data },
			-id => $fk_ref,
	 		-table => $fk_table );

	#  SELECT patient_id FROM maindb_dev.patient WHERE STABLE_PATIENT_ID = 'TCGA-OR-A5K0'
	$stmt = sprintf "SELECT %s FROM %s%s WHERE %s = ?", $fk_col, $schema, $fk_table, $fk_ref;

	$sth = $dbh->prepare( $stmt );
	
	$rv = $sth->execute( $val ) or die $DBI::errstr;
	
	@row = $sth->fetchrow_array();
    }
    
    return( $row[0] );
}


=head2 get_val

    Function : Extract a specific value from a hash table with processing.
               Processing includes

                - Harmonizing hugo_gene_symbol, which is checked through gene_alias

                - Generating VarKey composit value for the variant table

    Usage    : get_val( -id   => 'entrez_gene_id',
                        -data => \%data )

    Returns  : 'NA' if the value is undefined

    Args     : -id     The value to extract
               -data   A hash table with all the values

               
=cut
    
sub get_val {
    
    my($class,
       %param ) = @_;

    my $data = $param{ -data };
    my $key = $param{ -id };
    my $val;
    
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
	
       } elsif( $key =~ /^entrez_gene_id$/i ) {
	   
	my $key_hugo = get_valid_key( $class,
				      -key => 'hugo_gene_symbol',
				      -data => $data );

	my $key_entrez = get_valid_key( $class,
					-key => 'entrez_gene_id',
					-data => $data );
	
	# hugo_gene_symbol might be mapped to gene or gene_alias
	$val = get_entrez( $class,
			   -entrez => $data->{ $key_entrez },
			   -hugo => $data->{ $key_hugo } );


    } else {
	
	$key = get_valid_key( $class,
			      -key => $param{ -id },
			      -data => $data );
	
	$val = $data->{ $key };
    }
    
    # TODO : Set to null or NA ??? if not defined
    $val = 'NA' unless( defined $val );
    
    # Replace ' with '', but dont do it if we encounter a ( or )
    # ( or ) means there the value probably has an SQL syntax such as
    #   > SELECT cancer_id FROM cancer_type WHERE cancer_id = 'acc'
    # so here we don't want to create ''acc''
    $val =~ s/\'/\'\'/g  unless( $val =~ /[()]/ );
        
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
    
    RETURN : $ret  - the matching key
             undef - if key not found
    
    ARGS : -key     The text key that we will search the hash variable
           -data    The hash vaiable that we will interogate
=cut

sub get_valid_key {

    my( $class,
	%param ) = @_;

    my $ret;
    my $key = $param{ -key };
    
    # Capitalize the first letter
    my $key_ucfirst = join "_", map {ucfirst} split "_", lc($key);

    my $data = $param{ -data };
    
    if ( exists $data->{ $key } ) {
	# if current key already match to existing hash
	$ret = $key;
	
    } elsif ( exists $data->{ lc($key) } ) {
	# check if lower case key would match
	$ret = lc($key);

    } elsif ( exists $data->{ uc($key) } ) {
	# check if upper case key would match
	$ret = uc( $key );

    } elsif( exists $data->{ $key_ucfirst } ) {
	# check if capitalizing the first key would match
	$ret = $key_ucfirst;
	
    } elsif( $key =~ /varkey/i ) {
	# VarKey is special as the V and R is capitalize
	$ret = 'VarKey' if (exists $data->{ VarKey });
    }
    
    return( $ret );
}


=head2
    Function : Determine if entrez_gene_id is valid, if not get it from hugo
    
               Specifically this function check to see if entrez_gene_id is valid, if so return this entrez
               If not, use the Hugo_Gene_Symbol to determine if there is an entrez_gene_id 
               within the gene_alias table

    Usage    : get_entrez( -entrez => 1234,
                           -hugo   => myGene )

    Returns  : entrez_gene_id

    Args     : -entrez     : the entrez_gene_id to which we want to check
               -hugo       : if the entrez_gene_id is not valid, use hugo to check gene_alias


=cut

sub get_entrez {
    my( $class,
	%param ) = @_;

    my $q_entrez = $param{ -entrez } || 0;
    my $q_hugo = $param{ -hugo };
    my $hugo = "NA";
    my $entrez = "NA";
    
    
    if( exists $gene_entrez{ $q_entrez } ) {	
	$entrez = $q_entrez;
	$hugo = $q_hugo;

    } elsif( exists $gene_hugo{ $q_hugo } ) {

	# Check gene based on hugo
	$entrez = $gene_hugo{ $q_hugo };
	$hugo = $q_hugo;
	
    } elsif( exists $gene_alias{ $q_hugo } ) {

	# Check gene_alias based on hugo
	$entrez = $gene_alias{ $q_hugo };
	$hugo = $gene_entrez{ $entrez };
    }
    
    if( $entrez ne 'NA' &&
	($q_entrez ne $entrez) && 
	! exists $seen_entrez_map{ $q_hugo } ) {
	
	$seen_entrez_map{ $q_hugo } = "";
	
	$gen->pprint( -tag => "ENTREZ_MAP",
		      -val => "$q_hugo ($q_entrez) > $hugo ($entrez)",
		      -d => 1 );
    }
    
    return( $entrez );
}

=head2 load_db_priority

    Function : 
    Usage    : 
    Returns  : 
    Args     : 
               
=cut

sub format_stable_id {
    my( $class,
	%param ) = @_;
    
    my $ret;
    if( $param{ -id } eq 'sample' ) {
	
	my @sid = split( /\-/, $param{ -val } );
	splice( @sid, 3 );
	$ret = join( "-", @sid );
	$ret =~ s/(.*)\w$/$1/;
    }
    return( $ret );
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
