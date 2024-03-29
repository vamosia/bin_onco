#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;
my %options;
GetOptions( "d"      => \$options{ -d },
	    "dd"     => \$options{ -dd },
	    "ddd"    => \$options{ -ddd },
	    "db=s"   => \$options{ -db },
	    "v"      => \$options{ -v },
	    "s=s"    => \$options{ -s },
	    "t=s"    => \$options{ -t },
	    "f=s"    => \$options{ -f },
	    "i=s"    => \$options{ -i },
	    "o=s"    => \$options{ -o }
    ) or die "Incorrect Options $0!\n";


my $gen = new Generic( %options );

unless( defined $options{ -i } ) {
    $gen->pprint( -tag => "ERROR",
		  -val => "$0 : -i (in file) Required" );
}

unless( defined $options{ -o } ) {
    $gen->pprint( -tag => "ERROR",
		  -val => "$0 : -o (out file) Required" );
}


$gen->pivot_file( -f => $options{-i},
		  -o => $options{-o} )



__END__
##########################################################################################

sub process_patient_samplea {

    open( IN, "<$options{-f} " ) or die "$!\n";
    
    my %data;
    my (@disease_code, @study_name, @cancer_id, @key, @patient_list);
    my ($study_name, $merge_code );
    my %added;
	
    while( <IN> ) {

	chomp $_;
	
	my @line = split( /\t/ );

	my @header = split( /\./, $line[0] );
	# remove first index, this is stored in header
	#admin.batch_number     304.62.0        313.56.0;
	shift @line; 

	# Map the header as needed
	foreach( 0 ..$#header ) {
	    $header[$_] = map_key( -id => $header[$_] );
	}
	
	if( $header[0] eq 'admin' ) {

	    # Need to store disease code line, since we have not encountered the key yet
	    if( $header[1] eq 'disease_code' ) {
		
		@disease_code = @line;

		# GENERATE STUDY_NAME ARRAY;

		# From the list of disease code determine the uniq hash
		my %uniq = map{ $_ => "" } @disease_code;
		
		my @uniq = sort keys %uniq; # convert back to array
		
		$merge_code = join( ",", @uniq ); # get comma seperated code

		# Map disease code to study name ---> There should only be 1 study_name
		$study_name = $mainDB->get_data( -id => 'disease_to_study_name',
						 -val => $merge_code );

		unless( defined $study_name ) {
		    $gen->pprint( -tag => 'error',
				  -val => "Unknown study for '$merge_code', please update \$DATAHUB/mainDB.seeDB/disease_code_to_cancer_id.tsv" )
		}
		
		foreach( @disease_code ) {
		    # add 'tcga' to the disaese code to make the study_name
		    push( @study_name, $study_name );
		}
		
	    }
	    
	    # Start processing the file once we encounter UUID
	    if( $header[1] eq 'file_uuid' ) {
		@key = @line; # store the column key used in the data hash
		
		# CHECK OF 'NA' UUID > MAKE IT UNIQ
		for my $idx ( 0 ..$#key ) {
		    
		    my $code = $key[ $idx ];
		    
		    if( $code eq 'NA' ) {

			$code = "${code}_${idx}";
			
			$gen->pprint( -tag => "WARNING",
				      -val => "UUID: NA found. Setting to $code",
				      -v => 1 );
			    
			    $key[ $idx ] = $code;
		    }	
		}

		# initialize UUID
		$data{ $_ } = undef foreach( @key );

		# ADD TO HASH : the study_name tag to the patient hash
		store_to_data( -col0 => 'patient',
			       -col1 => 'study_name',
			       -key => \@key,
			       -data => \%data, 
			       -line => \@study_name );


		my $cancer_id = $mainDB->get_data( -id => 'cancer_id',
						   -val => $merge_code );
		
		# If we're inserting study for the first time, don't have to checek for cancer_id
		unless( defined $cancer_id ) {
			
		    $gen->pprint( -tag => 'error',
				  -val => "cancer_study ($_) / cancer_id (?) not defined " .
				  "Please add cancer_study to \$DATAHUB/mainDB.seedDB/disease_code_to_cancer_id.tsv" );
		}
		    
		$data_s{ $study_name }{ source } = $options{ -s };

		$data_s{ $study_name }{ description } = $mainDB->get_data( -id => 'description',
								    -val => $merge_code );
		$data_s{ $study_name }{ cancer_id } = $cancer_id;

		$data_s{ $study_name }{ study_name } = $study_name;
	    }	    
	}
	

	# based on the merged data from firehouse, we're only going to store specific column
	# this will be chosen based on the length of the header

	# $#header == 1 means that this column is blank... this is what we want;
	
	if( ($header[0] eq 'patient' && $#header == 1) ) {
	    
	    # Capitalize 
	    if( $header[1] eq 'stable_patient_id' ) {
		$_ = uc for @line;
	    }

	    # Store this to an array as we want to add it a differen group later on
	    @patient_list = @line if( $header[1] eq 'stable_patient_id' );
	    
	    # ADD TO HASH : stable_patient_id
	    store_to_data( -col0 => 'patient',
			   -col1 => $header[1],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );

	} elsif($header[1] eq 'primary_pathology' && $#header == 2) {

	    # ADD TO HASH : primary_pathology
	    store_to_data( -col0 => 'patient',
			   -col1 => $header[2],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );

	} elsif($header[1] eq 'primary_pathology' && $#header == 3) {
	    
	    # ADD TO HASH : primary_pathology
	    store_to_data( -col0 => 'patient',
			   -col1 => $header[3],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );


	} elsif($header[1] eq 'primary_pathology' && $#header == 4) {
	    
	    # ADD TO HASH : primary_pathology
	    store_to_data( -col0 => 'patient',
			   -col1 => $header[4],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );
	    

	} elsif($header[1] eq 'new_tumor_events' && $#header == 2) {
	    
	    # ADD TO HASH : primary_pathology
	    store_to_data( -col0 => 'patient',
			   -col1 => $header[2],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );

	} elsif($header[1] eq 'new_tumor_events' && $#header == 3) {
	    
	    # ADD TO HASH : primary_pathology
	    store_to_data( -col0 => 'patient',
			   -col1 => $header[3],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );

	} elsif( $header[1] =~ /^sample/ && $#header == 3 ) {

	    # Capitalize 
	    if( $header[3] eq 'stable_sample_id' ) {
		$_ = uc for @line;
	    }


	    # col0 has to be header[2] as sometiems its sample-2, sample-3
	    store_to_data( -col0 => $header[2],
			   -col1 => $header[3],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );

	    # cancer_id is not part of the normal data input, so need to manually added this for each sample (sample-2, sample-3)
	    # but only add it once
	    
	    unless( exists $added{ $header[2] }{ 'cancer_id' } ) {

		# Disease code != cancer_id as sometimes its different (i.e pcpg cancer study = mnet cancer type)
		# so we need to map it
		
		my @cancer_id = @disease_code;

		store_to_data( -col0 => $header[2],
			       -col1 => 'cancer_id',
			       -key => \@key,
			       -data => \%data, 
			       -line => \@cancer_id );
		
		
		# Add the stable_patient_id to the sample hash
		store_to_data( -col0 => $header[2],
			       -col1 => 'stable_patient_id',
			       -key => \@key,
			       -data => \%data, 
			       -line => \@patient_list );
		
		$added{ $header[2] }{ cancer_id } = 1;
	    }

	}
	
    }    
    
    close( IN );
    
    # study_name is only added to patient hash, need to add this to everything else
    foreach my $uuid ( keys %data ) {
	
	foreach my $cat (keys %{ $data{ $uuid } } ) {
	
	    next if( $cat eq 'patient' );
	    
	    $data{ $uuid }{ $cat }{ study_name } = $data{ $uuid }{ patient }{ study_name };
	}
    }
    print Dumper \%data;exit;
    return( \%data );
}

sub store_to_data {

    my (%param) = @_;
    
    my $max = scalar @{ $param{ -key } } - 1;
    
    for my $idx( 0 .. $max ) {
	my $uuid = $param{ -key }[ $idx ];
	my $col0 = $param{ -col0 };
	my $col1 = $param{ -col1 };
	my $val = $param{ -line }[ $idx ];

	
	# modify TCGA-OR-A5KP-01A to TCGA-OR-A5KP-01
	if( $col1 =~ /stable_sample_id/ && $val ne 'NA') {
	    
	    my @sid = split( /\-/, $val );

	    splice( @sid, 4 );

	    $val = join ("-",, @sid);
	}
	
	
	$param{ -data }{ $uuid }{ $col0 }{ $col1 } = $val;
	
	if( $col0 =~ /^sample/ ) {

	    $header_meta{ sample }{ $col1 } = undef;
	    
	} else {
	    $header_meta{ $col0 }{ $col1 } = undef;
	}
	
    }
}
