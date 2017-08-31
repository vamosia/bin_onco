#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Generic qw(pprint);
use Getopt::Long;
use Storable;

my %options = ( -d => 0,
		-s => 'TCGA (2016_01_28)' );

GetOptions( "d=s"      => \$options{ -d },
	    "v"      => \$options{ -v },
	    "s=s"      => \$options{ -s }
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
# ps = patient_study
my %map_key = ( 'cancer_study' => 'study_name',
		'bcr_patient_barcode' => 'stable_patient_id',
		'bcr_sample_barcode' => 'stable_sample_id' );


my %header = ( 'study'         => [qw(STUDY_NAME SOURCE DESCRIPTION)],
	       'cancer_study'  => [qw(STUDY_NAME CANCER_ID)],
	       'patient'       => [qw(STABLE_PATIENT_ID)],
	       'patient_study' => [qw(STABLE_PATIENT_ID STUDY_NAME)],
	       'sample'        => [qw(STABLE_PATIENT_ID STABLE_SAMPLE_ID STUDY_NAME CANCER_ID)] 
    );


my %header_pm;
my %header_sm;

# cs = study_name
my %data_s;
my @header_s = qw(STUDY_NAME SOURCE DESCRIPTION);

pprint( -level => 0, -val => 'Processing Patient Sample Files' );

my $map_cancer_id = load_cancer_id();

pprint( -val => "Processing Patient Samples" );

my $data = process_patient_sample();

pprint( -val => "Generating Output" );

generate_output( $data );

##########################################################################################
# SUBROUTINE

sub generate_output {

    my $data = $_[0];
    
    my @header_pm = sort keys %header_pm;
    my @header_sm = sort keys %header_sm;
    
    # print header as upper case
    $_ = uc for @header_pm;
    
    # move STABLE_PATIENT_ID to the index 0;
    for( 0 ..$#header_pm ) {
	if( $header_pm[$_] eq 'STABLE_PATIENT_ID' ) {
	    my $pid = splice @header_pm, $_, 1;
	    unshift( @header_pm, $pid );
	}
    }
    
    $_ = uc for @header_sm;
    
    # move STABLE_*_ID to the index 0;
    for( 0 ..$#header_sm ) {
	if( $header_sm[$_] eq 'STABLE_SAMPLE_ID' ) {
	    my $pid = splice @header_sm, $_, 1;
	    unshift( @header_sm, $pid );

	} elsif( $header_sm[$_] eq 'STABLE_PATIENT_ID' ) {
	    my $pid = splice @header_sm, $_, 1;
	    unshift( @header_sm, $pid );
	}
    }
    
    open( PATIENT, ">data_patient.txt" );
    print PATIENT join( "\t", @{ $header{ patient } } ) . "\n";

    open( PATIENT_STUDY, ">data_patient_study.txt" );
    print PATIENT_STUDY join( "\t", @{ $header{ patient_study } } ) . "\n";

    open( PATIENT_META, ">data_patient_meta.txt" );
    print PATIENT_META join( "\t", @header_pm ) . "\n";
    
    open( SAMPLE, ">data_sample.txt" );
    print SAMPLE join( "\t", @{  $header{ sample } } ) . "\n";
    
    open( SAMPLE_META, ">data_sample_meta.txt" );
    print SAMPLE_META join( "\t", @header_sm ) . "\n";

    open( STUDY, ">data_study.txt" );
    print STUDY join( "\t", @{ $header{ study } } ) . "\n";

    open( CANCER_STUDY, ">data_cancer_study.txt" );
    print CANCER_STUDY join( "\t", @{ $header{ cancer_study } } ) . "\n";

    # revert back to lower case, since the values in the hash are all lower case
    $_ = lc for @header_pm;
    $_ = lc for @header_sm;
    $_ = lc for @header_s;
    
    # id = UUID
    my $uuid_cnt = 0;
    
    foreach my $uuid ( keys %{ $data } ) {
	
	pprint( -val => "UUID : $uuid", -level => 1 ) if( $options{ -v } );
	$uuid_cnt ++;
	
	my $pid = $data->{ $uuid }{ 'patient' }{ 'stable_patient_id' };
	my $sn = $data->{ $uuid }{ 'patient' }{ 'study_name' };
	
	# $cat = patient, sample, sample-2, sample-3
	foreach my $cat ( sort keys %{ $data->{ $uuid } } ) { 
	    
	    if( $cat eq 'patient' ) {
				
		print PATIENT_STUDY "$pid\t$sn\n";
		print PATIENT "$pid\n";
		
		my @line;
		
		foreach my $id ( @header_pm ) {
		    
		    $id = map_key( -id => $id );

		    push( @line, $data->{ $uuid }{ $cat }{ $id } );
		}
		
		print PATIENT_META join( "\t", @line ), "\n";
		   
		   
	    } elsif( $cat =~ /^sample/ ) {
		
		my $sid = $data->{ $uuid }{ $cat }{ 'stable_sample_id' };
		my $cid = $data->{ $uuid }{ $cat }{ 'cancer_id' };

		print SAMPLE "$pid\t$sid\t$sn\t$cid\n";
		
		# Store the capitalised back to the hash
		$data->{ $uuid }{ $cat }{ 'stable_sample_id' } = $sid;
		my @line;
		
		foreach my $id ( @header_sm ) {
		    print Dumper "$id $data->{ $uuid }{ $cat }{ $id }" if ($options{ -d } );

		    $id = map_key( -id => $id );
		    push( @line, $data->{ $uuid }{ $cat }{ $id } );
		}
		
		print SAMPLE_META join( "\t", @line ), "\n";						
	    }
	}
    }

    pprint( -level => 1, -val => "Total Samples = $uuid_cnt" ) if( $options{ -v } );
    
    # Print to STUDY (data_study.txt) file
    my @study_out;
    my @cancer_study_out;
    
    foreach my$cs ( keys %data_s ) {
	foreach my $id (@header_s ) {
	    push( @study_out, $data_s{ $cs }{ $id } || 'NA' )		 
	}

	foreach my $id ( @{ $header{ cancer_study } } ) {
	    
	    push( @cancer_study_out, $data_s{ $cs }{ lc($id) } );
	}

    }

    print STUDY join( "\t", @study_out );
    
    print CANCER_STUDY join( "\t", @cancer_study_out );

    close( PATIENT );
    close( PATIENT_META );
    close( SAMPLE );
    close( SAMPLE_META );
    close( STUDY );
    close( CANCER_STUDY );

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

sub process_patient_sample {

    my @files = glob("*.clin.merged.txt");
    
    # there should only be one file, if not error out
    pprint( id => 'error', -val => 'Multiple *.clin.merged.txt Found' ) if( $#files != 0 );

    open( IN, "<$files[0]" ) or die "$!\n";					   
    
    my %data;
    my @disease_code;
    my @key;
    my @patient_list;
    my %added;
	
    while( <IN> ) {
	chomp $_;
	
	my @line = split( /\t/ );

	my @header = split( /\./, $line[0] );

	#admin.batch_number     304.62.0        313.56.0;
	shift @line; # remove first index, this is stored in header

	# Map the header as needed
	foreach( 0 ..$#header ) {
	    $header[$_] = map_key( -id => $header[$_] );
	}

	# Need to store disease code line, since we have not encountered the key yet
	if( $header[0] eq 'admin' ) {
	    @disease_code = @line if( $header[1] eq 'disease_code' );

	    if( $header[1] eq 'file_uuid' ) {
		@key = @line; # store the column key used in the data hash
		
		# initialize UUID
		$data{ $_ } = undef foreach( @key );

		# add 'tcga' to the disaese code to make the study_name
		my @study_name = @disease_code;

 		$_ = "${_}_tcga" for @study_name;
		
		# ADD TO HASH : the study_name tag to the patient hash
		store_to_data( -id0 => 'patient',
			       -id1 => 'study_name',
			       -key => \@key,
			       -data => \%data, 
			       -line => \@study_name );
		
		
		# ADD TO HASH : Study_Name
		foreach( @disease_code ) {
		    $data_s{ $_ . "_tcga" }{ 'source' } = $options{ -s };
		    $data_s{ $_ . "_tcga" }{ 'description' } = $map_cancer_id->{ $_ }{ 'description' };
		    $data_s{ $_ . "_tcga" }{ 'study_name' } = $_ . "_tcga";
		    $data_s{ $_ . "_tcga" }{ 'cancer_id' } = $_;

		}

		
		# check to see if there are more than 1 study_name
		my $cnt = scalar keys %data_s;
		
		pprint( -tag => 'error', -val => 'More that 1 Cancer Study Found' ) if( $cnt != 1 );
		
	    }	    
	}

	# based on the merged data from firehouse, we're only going to store specific column
	# this will be chosen based on the length of the header
	
	if( ($header[0] eq 'patient' && $#header == 1) ) {
	    
	    # Capitalize 
	    if( $header[1] eq 'stable_patient_id' ) {
		$_ = uc for @line;
	    }
	    
	    @patient_list = @line if( $header[1] eq 'stable_patient_id' );
	    
	    store_to_data( -id0 => 'patient',
			   -id1 => $header[1],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );

	} elsif($header[1] eq 'primary_pathology' && $#header == 2) {

	    store_to_data( -id0 => 'patient',
			   -id1 => $header[2],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );
	    
 
	} elsif( $header[1] =~ /^sample/ && $#header == 3 ) {

	    # Capitalize 
	    if( $header[3] eq 'stable_sample_id' ) {
		$_ = uc for @line;
	    }
	    
	    # id0 has to be header[2] as sometiems its sample-2, sample-3
	    store_to_data( -id0 => $header[2],
			   -id1 => $header[3],
			   -key => \@key,
			   -data => \%data, 
			   -line => \@line );

	    # cancer_id is not part of the normal data input, so need to manually added this for each sample (sample-2, sample-3)
	    # but only add it once
	    
	    unless( exists $added{ $header[2] }{ 'cancer_' } ) {

		# Disease code != cancer_id as sometimes its different (i.e pcpg cancer study = mnet cancer type)
		# so we need to map it
		
		my @cancer_id = @disease_code;
		$_ = $map_cancer_id->{ $_ }{ 'cancer_id' } for @cancer_id;
		
		store_to_data( -id0 => $header[2],
			       -id1 => 'cancer_id',
			       -key => \@key,
			       -data => \%data, 
			       -line => \@cancer_id );
		
		# Add the stable_patient_id to the sample hash
		store_to_data( -id0 => $header[2],
			       -id1 => 'stable_patient_id',
			       -key => \@key,
			       -data => \%data, 
			       -line => \@patient_list );
	
		
		$added{ $header[2] }{ 'cancer_id' } = 1;
	    }

	}
	
    }    
    
    close( IN );
    print Dumper \%data if( $options{ -d } );
    return( \%data );
}

sub store_to_data {

    my (%param) = @_;
    
    my $max = scalar @{ $param{ -key } } - 1;
    
    for my $idx( 0 .. $max ) {
	my $key = $param{ -key }[ $idx ];
	my $id0 = $param{ -id0 };
	my $id1 = $param{ -id1 };
	my $val = $param{ -line }[ $idx ];
	
	$param{ -data }{ $key }{ $id0 }{ $id1 } = $val;

	# store the header for meta columns
	if( $id0 eq 'patient' ) {
	    $header_pm{ $id1 } = undef;
	} elsif ( $id0 eq 'sample' ) {
	    $header_sm{ $id1 } = undef;
	}
	
    }
}

sub load_cancer_id {

    my %ret;
    
    my $dir = `echo \$DATAHUB`; chomp $dir;

    my $file = "$dir/firehose/disease_code_to_cancer_id.txt";

    pprint( -val => "Loading cancer mapping\n" );
    
    open( IN, "<$file" ) or die "$!\n";
    
    my $header = 0;
    my @header;
    while( <IN> ) {
	chomp $_;
	
	if( $header == 0 ) {
	    @header = split( /\t/, $_ );
	    
	    $header[$_] = map_key( -id => $header[$_]) foreach( 0 .. $#header );
	    $header++;
	    next;
	}
	
	# 0 = cancer_project (acc_tcga)
	# 1 = cancer_type(acc)
	
	my @l = split( /\t/, $_ );
	my %line;
	@line{ @header } = @l;

	$ret{ $line{ study_name } } = \%line;
	
    }

    close( IN );

    return( \%ret );

}
