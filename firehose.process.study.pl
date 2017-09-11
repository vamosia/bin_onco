#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;
my %options = ( -s => 'TCGA (2016_01_28)' );

GetOptions( "d"      => \$options{ -d },
	    "dd"     => \$options{ -dd },
	    "ddd"    => \$options{ -ddd },
	    "db=s"   => \$options{ -db },
	    "v"      => \$options{ -v },
	    "s=s"    => \$options{ -s },
	    "t=s"    => \$options{ -t },
    ) or die "Incorrect Options $0!\n";

 
# 1. Load Patients, Sample, Clinical Info 
# Directory = stddata__2016_01_28/ACC/20160128/*ACC*Merge_Clinical.Level_1/ACC.clin.merged.txt
# create a hash and split based on "."

# Keep Portions
#primary_pathology.histological_type laterality lymph_node_examined_count


# OUTPUT : data_patient.txt           : a list of patient for this study
#          KEY = patient.bcr_patient_barcode
#          admin.disease_code = cancer_id
    
# OUTPUT : data_patient_meta.txt  : clinical information for patient
#          KEY   = patient.bcr_patient_barcode
#          Value = patient.ID.(blank)
    
# OUTPUT : data_sample.txt            : patient to sample association
#          KEY=bcr_sample_barcode
#          VALUE = patient.sample.sample    .ID.(blank)
#          VALUE = patient.sample.sample-2  .ID.(blank)
#          VALUE = patient.sample.sample-etc.ID.(blank)

# p = patient
# pc = patient_meta

my %map_key = ( 'cancer_study' => 'study_name',
		'bcr_patient_barcode' => 'stable_patient_id',
		'bcr_sample_barcode' => 'stable_sample_id' );


my %header = ( 'study'         => [qw(study_name source description)],
	       'cancer_study'  => [qw(study_name cancer_id)],
	       'patient'       => [qw(stable_patient_id study_name)],
	       'sample'        => [qw(STABLE_PATIENT_ID STABLE_SAMPLE_ID CANCER_ID)] );

my %header_meta;

my $gen = new Generic( %options );
my $mainDB = new MainDB( %options );
my $db = $options{ -db };

$gen->pprint( -level => 0, 
	      -tag => $options{ -t },
	      -val => "Loading $options{ -t }" );


$mainDB->load_db_data( -table => 'study' );
$mainDB->load_db_data( -table => 'patient' );
$mainDB->load_db_data( -table => 'sample' );
$mainDB->load_db_data( -table => 'cancer_study' );

my %header_pm;
my %header_sm;

# cs = study_name
my %data_s;



my $data = process_patient_sample();

generate_output( $data );

##########################################################################################
# SUBROUTINE

sub generate_output {

    my $data = $_[0];
    
    my $table = $options{ -t };
    
    open( OUT, ">data_${table}.tsv" );
    # id = UUID
    my $uuid_cnt = 0;
    
    foreach my $uuid ( keys %{ $data } ) {
	
	$gen->pprint( -tag => $options{ -t },
		      -val => "UUID : $uuid", 
		      -d => 1 );
	$uuid_cnt ++;
	
	my $spid = $data->{ $uuid }{ patient }{ stable_patient_id };

	my $sn = $data->{ $uuid }{ patient }{ study_name };

	
	# $cat = patient, sample, sample-2, sample-3
	foreach my $cat ( sort keys %{ $data->{ $uuid } } ) { 

	    my @line;

	    # Print to patient file
	    if( $cat eq 'patient' && $table eq 'patient' ) {
		
		foreach my $id( @{ $header{ $cat } } ) {
		    
		    my $val = $data->{ $uuid }{ $cat }{ lc($id) };
		    
		    if( $id =~ /study_name/i ) {

			$val = $mainDB->get_data( -id => $id, 
						  -val => $val );
		    }
		    push( @line, $val );
		 
		}

		print OUT join( "\t", @line ),"\n";
		
	    } elsif( $cat eq 'patient' && $table eq 'patient_meta' ) {
		
		@line = ();

		my $pid = $mainDB->get_data( -id => 'stable_patient_id',
					     -val => $spid );
		
		foreach my $id( keys %{ $header_meta{ $cat } } ) {
		    
		    $id = map_key( -id => $id );
		    
		    my $val = $data->{ $uuid }{ $cat }{ $id };
		    
		    next if( $id =~ /stable_patient_id/i ||
			     ! defined $val );
		    
		    print OUT "$pid\t$id\t$val\n";
		    
		}
		# Store the study name into the sample hash
		$data->{ $uuid }{ sample }{ study_name } = $data->{ $uuid }{ $cat }{ study_name };
	    
	    } elsif( $cat =~ /^sample/ && $table eq 'sample' ) {
	    
		next if( $data->{ $uuid }{ $cat }{ stable_sample_id } eq 'NA');
		
		# Always use the sample header for sample (not sample-2 or sample-3)
		# This ensure consistencies among all the samples are not all sample (sample-2, sample-3)
		# will have the same header

		foreach my $id( @{ $header{ sample } } ) {
		    
		    # sample-2, sample-3, sample-4 might be 'NA'
		    # its 'NA', as by default it will look through all the samples
		    
		    my $val = (defined $data->{ $uuid }{ $cat }{ lc($id) } ) ?
			$data->{ $uuid }{ $cat }{ lc($id) } : 'NA';
		    
		    if( $id =~ /stable_patient_id/i ) {
			
			$val = $mainDB->get_data( -id => $id,
						  -val => $val );
		    }

		    next if( $val eq 'NA' );

		    $gen->pprint( -tag => $options{ -t },
				  -val => "$id >>>> $val",
				  -d => 1 );
		    
		    push( @line,  $val );
		}
		
		print OUT join( "\t", @line ),"\n";

	    } elsif( $cat =~ /^sample/ && $table eq 'sample_meta' ) {

		my $sid = $mainDB->get_data( -id => 'stable_sample_id',
					     -val => $data->{ $uuid }{ $cat }{ stable_sample_id } );

		next unless (defined $sid );
		
		foreach my $id( keys %{ $header_meta{ $cat } } ) {
		    
		    $id = map_key( -id => $id );
		    
		    my $val = $data->{ $uuid }{ $cat }{ $id } ;
		    
		    next if( $id =~ /stable_sample_id/i ||
			     ! defined $val );
		    
		    print OUT "$sid\t$id\t$val\n";
		}
		
	    }
	}
    }
    
    $gen->pprint( -tag => $options{ -t },
		  -val => "Total Patient = $uuid_cnt" );
    
    
    if( $table eq 'study') {
	
	
	# Print to STUDY (data_study.txt) file
	my @study_out;
	my @cancer_study_out;
	
	foreach my$cs ( keys %data_s ) {
	    
	    foreach my $id ( @{ $header{ study } } ) {

		my $val = (defined $data_s{ $cs }{ $id }) ? $data_s{ $cs }{ $id } : 'NA';
		
		push( @study_out, $val );
	    }
	    

	    print OUT join( "\t", @study_out );
	    
	}
    }

    if( $table eq 'cancer_study' ) {

	foreach my$cs ( keys %data_s ) {
	    
	    my $study_name = $mainDB->get_data( -id => 'study_name',
						-val => $data_s{ $cs }{ study_name } );
	    
	    my $cancer_id = $mainDB->get_data( -id  => 'cancer_id',
					       -val => $data_s{ $cs }{ cancer_id } );
	    
	    foreach( split( ',', $cancer_id ) ) {
		print OUT "$study_name\t$_\n";
	    }
	    
	}
    }
    close( OUT );
}

sub map_key {
    
    my (%param) = @_;

    my $id = $param{ -id };
    
    my $ret = $id;
    
    if ( exists $map_key{ lc($id) } ) {
	$ret = $map_key{ lc($id) };
	
    } elsif ( exists $map_key{ uc($id) } ) {
	$ret = $map_key{ uc($id) } 
    }
    
    return( $ret );
    
}

# Loads the data from *clin.merged.txt into a hash data structure.
# The file is formated in something like admin.patient.patient-2.sample.etc...

sub process_patient_sample {

    my @files = glob("*.clin.merged.txt");
    
    # there should only be one file, if not error out
    $gen->pprint( -id => 'error', 
		  -val => 'Multiple *.clin.merged.txt Found' ) if( $#files != 0 );

    open( IN, "<$files[0]" ) or die "$!\n";					   
    
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
