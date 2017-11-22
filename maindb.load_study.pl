#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;
use Text::Unidecode;
use Term::ANSIColor;
#$| = 1;

use Encode;
require Encode::Detect;

my %options = ( -sv => 'release_1.0.1',
		-mf => "/srv/datahub/mainDB.seedDB/map.tsv" );


( $#ARGV > -1 ) || die "

DESCRIPTION:


USAGE:
     $0 -v

EXAMPLE:
     $0 -v -d -sm

OPTIONS :
     -v     Verbose Mode
     -d     Debug Mode
     -sm    Skip Merging of data

AUTHOR:
    Alexander Butarbutar (ab\@oncodna.com), OncoDNA
\n\n";

GetOptions( "d"      => \$options{ -d },
	    "dd"     => \$options{ -dd },
	    "ddd"    => \$options{ -ddd },
	    "db=s"   => \$options{ -db },
	    "v"      => \$options{ -v },
	    "mf=s"   => \$options{ -mf },      # map file path
	    "e"      => \$options{ -e },       # empty, include empty value to metaDB
	    "s=s"    => \$options{ -s },       # source
	    "sv=s"   => \$options{ -sv },      # source version
	    "a=s"    => \$options{ -a },       # analysis name
	    "t=s"    => \$options{ -table },   # Table
	    "f=s"    => \$options{ -f },       # File
	    "c"      => \$options{ -c },       # Copy to DB
	    "cid=s"  => \$options{ -cid },     # Cancer ID
	    "cc"     => \$options{ -cc },      # Copy to DB
	    "tr"     => \$options{ -tr },      # Truncate
	    "tre"    => \$options{ -tre }      # Truncate & Ex
	   
    ) or die "Incorrect Options $0!\n";

my %study_cancer_map = ( 'DLBC' => 'DLBCL',
			 'KICH' => 'CHRCC',
			 'KIRC' => 'CCRCC',
			 'KIRP' => 'PRCC',
			 'LAML' => 'AML',
			 'LGG' => 'DIFG',
			 'LIHC' => 'HCC',
			 'OV' => 'HGSOC',
			 'PCPG' => 'MNET',
			 'SARC' => 'SOFT_TISSUE',
			 'TGCT' => 'NSGCT',
			 'THCA' => 'THPA',
			 'UVM' => 'UM');

my %url = ( 'genie' => "www.aacr.org/RESEARCH/RESEARCH/PAGES/AACR-PROJECT-GENIE-DATA.ASPX",
	    'tcga' => "http://gdac.broadinstitute.org/runs/stddata__2016_01_28/" );
   

my %process = ( study               => \&process_study,
		study_meta          => \&process_study_meta,
		cancer_study        => \&process_cancer_study,
		patient             => \&process_patient,
		patient_meta        => \&process_patient_meta,
		sample              => \&process_sample,
		sample_meta         => \&process_sample_meta,
		variant             => \&process_variant,
		variant_sample      => \&process_variant_sample,
		variant_sample_meta => \&process_variant_sample_meta,
		variant_meta        => \&process_variant_meta,
		cnv                 => \&process_cnv,
		cnv_sample          => \&process_cnv_sample,
		analysis            => \&process_analysis,
		analysis_meta       => \&process_analysis_meta,
		analysis_data       => \&process_analysis_data
    );


my %alt_type = ( '2'    => 'high_level_amplification',
		 '1.5'  => 'high_level_amplification',
		 '-1.5' => 'deep_loss',
		 '-2'   => 'deep_loss' );

my %copy = ( 
    study                => qq(study(source, study_name, description)),
    study_meta           => qq(study_meta(study_id, attr_id, attr_value)),
    cancer_study         => qq(cancer_study(study_id, cancer_id) ),
    patient              => qq(patient(stable_patient_id, study_id)),
    patient_meta         => qq(patient_meta(patient_id, attr_id, attr_value)),
    sample               => qq(sample(stable_sample_id, cancer_id, patient_id)),
    sample_meta          => qq(sample_meta(sample_id, attr_id, attr_value)),
    variant              => qq(variant(varkey, entrez_gene_id, chr, start_position, end_position, ref_allele, var_allele, genome_build, strand)),
    variant_meta         => qq(variant_meta(variant_id, attr_id, attr_value)),
    variant_sample       => qq(variant_sample(sample_id, variant_id)),
    variant_sample_meta  => qq(variant_sample_meta(variant_sample_id, attr_id, attr_value)),
    cnv                  => qq(cnv(entrez_gene_id, alteration, alteration_type)),
    cnv_sample           => qq(cnv_sample(sample_id, cnv_id)),
    analysis             => qq(analysis(study_id, sample_id, name)),
    analysis_meta        => qq(analysis_meta(analysis_id, attr_id, attr_value)),
    analysis_data        => qq(analysis_data(analysis_id, entrez_gene_id, attr_id, attr_value))
    );

my %col = ( 
    study                => qq(source, study_name, description),
    study_meta           => qq(study_id, attr_id, attr_value),
    cancer_study         => qq(study_id, cancer_id),
    patient              => qq(stable_patient_id, study_id),
    patient_meta         => qq(patient_id, attr_id, attr_value),
    sample               => qq(stable_sample_id, cancer_id, patient_id),
    sample_meta          => qq(sample_id, attr_id, attr_value),
    variant              => qq(varkey, entrez_gene_id, chr, start_position, end_position, ref_allele, var_allele, genome_build, strand),
    variant_meta         => qq(variant_id, attr_id, attr_value),
    variant_sample       => qq(sample_id, variant_id),
    variant_sample_meta  => qq(variant_sample_id, attr_id, attr_value),
    cnv                  => qq(entrez_gene_id, alteration, alteration_type),
    cnv_sample           => qq(sample_id, cnv_id),
    analysis             => qq(study_id, sample_id, name),
    analysis_meta        => qq(analysis_id, attr_id, attr_value),
    analysis_data        => qq(analysis_id, entrez_gene_id, attr_id, attr_value)
    );


unless( defined( $options{-s} ) ) {
    print "$0 : -s [SOURCE=tcga|genie] Required\n";
    exit;
}

if( $options{ -tre } ) {
    print "Type db '$options{-db}' to truncate : ";
    my $input = <STDIN>;
    chomp $input;
    if( $input eq $options{-db} ) {
	my $mainDB = new MainDB( %options );
	$mainDB->truncate( %options );
    }
    exit;
}

my %meta = ( tcga    => \&load_tcga_cancer_type_map );

my $gen;
my $mainDB;
my @data;

my @header_sort;
my (%map, %meta_study, %case, %seen, %sample_list);
my ($table);
my $pwd = `pwd`; chomp $pwd;
my $pwd_study = `basename $pwd`; chomp $pwd_study;

# Loads the mapping table 
# external table name to maindb table name
load_header_map();

$gen = new Generic ( %options );

$table = $options{ -table };

# Check to see if all the required parameter are enabled
precheck(); 

$gen->pprint( -level => 0,
	      -val => "Start - $table" );

$mainDB = new MainDB( %options );

# Truncate database if truncate is enable.
$mainDB->truncate( %options );

run();

copy_to_db() if( $options {-c} );


sub run {
        
    # Load meta study
    &{ $meta{ $options{-s} } } if( exists $meta{ $options{-s} } );
    
    # For TCGA, need to handle the CNV seperately
    if( $options{-table} eq 'analysis_data' && $options{-s} eq 'tcga' ) {
	
	load_tcga_cnv( -f => $options{f} );
	
    } else {

	load_file( -f => $options{ -f } );
    }
}

sub copy_to_db {
    
    # # Process the data depending on the table type
    # &{ $process{ $table } };
    
    # # pring data_[TABLE].tsv to disk
    # $mainDB->print_data( -data => \@data,
    # 			 -table => $options{ -table } );

 
    my $in_file = sprintf "data_%s.tsv", $table;;
    
    #my $copy = qq(copy $copy{$table} FROM '$pwd/data_$table.tsv' using DELIMITERS E'\\t' WITH NULL AS '');
    
    my %pk = ( study => 'study_id' );
    my $pk = $pk{ $table };
    
    my $copy = 
	qq(CREATE TEMP TABLE tmp_table ON COMMIT DROP AS SELECT $col{$table} FROM $table WITH NO DATA;
COPY tmp_table FROM '$pwd/$in_file' using DELIMITERS E'\\t' WITH NULL AS '';
INSERT INTO $copy{$table} SELECT DISTINCT $col{$table} FROM tmp_table ON CONFLICT DO NOTHING;);

    my $st = qq(sudo -i -u postgres psql $options{-db} -c "set client_encoding to 'latin1';$copy" );

    $gen->pprint( -id => "COPY",
		  -val => $st,
		  -d => 1 );

    print color('bold blue');
    $gen->pprint( -val => "COPY $in_file to database" );
    $gen->pprint( -val => "$st",
		  -d => 1  );
    print color('reset');



    my $a = system($st);

    if( $a == -1 ) {
	$gen->pprint( -tag => "ERROR",
		      -val => "Copy to database failed\n$st" );
    }
	
}
    

sub precheck {
    
    unless( defined $options{ -table } ) {
	$gen->pprint( -tag => "ERROR",
		      -val => "$0 : -t (MainDB Table) Required" );
    }

    unless( defined $options{ -f } ) {
	$gen->pprint( -tag => "ERROR",
		      -val => "$0 : -f (File) Required" );
    }

    if( $options{-table} =~ /analysis/ && ! defined $options{-a} ) {
	$gen->pprint( -tag => "ERROR",
		      -val => "$0 : -a (Analysis Name) Required" );
    }

    
    unless( defined $process{ $table } ) {
	$gen->pprint( -tag => "ERROR " . __LINE__,
		      -val => "$options{-table} not defined in $0" );
    }

    unless( defined $copy{ $table } ) {
	$gen->pprint( -tag => "ERROR",
		      -val => "psql COPY query not defined" );
    }
    
}

###### SUBROUTINE

sub process_study {

    my @new_data;
    
    my $line = $data[0];

    check_data( -id => 'line ' . __LINE__ . ' - study_name',  
		-val => $line->{study_name}, -ref => "" );
    
    if( ! exists $seen{ $table }{ $line->{study_name} } ) {
	
	
	$seen{ $table }{ $line->{study_name} } = undef;
	
	push( @new_data, $line );
    }
    
    undef @data;
    @data = @new_data;

}

sub process_study_meta {

    my @new_data;

    my $line = $data[0];
    
    if( ! exists $seen{ $table }{ $line->{study_name} } ) {
	
	$seen{ $table }{ $line->{study_name} } = undef;
	
	$line->{study_id} = $mainDB->get_data( -id => 'study_name',
					       -val => $line->{study_name} );
	
	if( $options{-s} || $options{-s} eq 'tcga' ) {
	    push( @{ $line->{ study_meta } }, { 'attr_id' => "download",
						'attr_value' => $url{ $options{-s} } } );
	}
	
	# Set the primary key for the meta
	foreach my $meta( @{ $line->{ study_meta } } ) {
	    $meta->{ pk } = $line->{study_id};
	}
	
	push( @new_data, $line );
    }	
    undef @data;
    @data = @new_data;
    

}



sub process_cancer_study {
    
    my @new_data;
    my %cancer_study;

    
    # keep only uniq study_name;
    my $line = $data[0];
        
    my $study_id = $mainDB->get_data( -id => 'study_id',
				      -val => $line->{study_name} );

    $line->{study_id} = $study_id;
    
    my $cs_key = sprintf "%s+%s", $study_id, $line->{cancer_id};
    
    # Avoid duplicates
    if( ! exists $seen{ $table }{ $cs_key } ) {
    
	$seen{ $table }{ $cs_key } = undef;
	push( @new_data, $line );
	#my $cs_id = $mainDB->get_data( -id => 'cancer_study_id',
        # 			       -val => $cs_key,
	#			       -tag => 'EXISTS' );
	
	#push( @new_data, $line ) if ( ! defined $cs_id );      
    }
    
    undef @data;
    @data = @new_data;
    
}

sub get_stable_patient_from_sample {
    
    my @stable_patient = split( /\-/, $_[0]);
    
    splice( @stable_patient, 3 );
    
    my $stable_patient = join( "-", @stable_patient );
    
    return( $stable_patient );    
}


sub process_patient {

    my @new_data;

    my $line = $data[0];

    my $study_id;
    my $stable_patient;
    if( $options{-s} eq 'tcga' && $options{-f} =~ /CNV/ ) {

	foreach my $entrez( keys %{ $line } ) {
	    foreach my $stable_sample( keys %{ $line->{ $entrez } } ) {

		$stable_patient = get_stable_patient_from_sample( $stable_sample );
		
		my @pwd = split( /\//, $pwd );
		my $cancer_id = uc( pop @pwd );
		my $study_name = sprintf( "%s_%s", lc( $cancer_id ), $options{-s} );
		$study_id = $mainDB->get_data( -id => 'study_id',
					       -val => $study_name );
		
		my $pkey = sprintf "%s_%s", $study_id, $stable_patient;
		
		my $patient_id = $mainDB->get_data( -id => 'patient_id',
						    -val => $pkey,
						    -tag => 'EXISTS' );
		if( ! defined $patient_id ) {
		    # Study Name is not always equal ty cancer id.. map them accordingly
		    if (defined $study_cancer_map{ uc($cancer_id) } ) {
			$cancer_id = $study_cancer_map{ $cancer_id };
		    }		
		    push( @new_data, { stable_patient_id => $stable_patient,
				       study_id => $study_id,
				       cancer_id => $cancer_id } );
		    
		}
	    }
	}

    } elsif( $options{-s} eq 'tcga' && $options{-f} =~ /mutations_extended/ ) {

	my $stable_sample = $line->{ stable_sample_id };
	my $stable_patient = get_stable_patient_from_sample( $stable_sample );
	
	my @pwd = split( /\//, $pwd );
	my $cancer_id = uc( pop @pwd );
	my $study_name = sprintf( "%s_%s", lc( $cancer_id ), $options{-s} );
	$study_id = $mainDB->get_data( -id => 'study_id',
				       -val => $study_name );
	
	my $pkey = sprintf "%s_%s", $study_id, $stable_patient;
	
	my $patient_id = $mainDB->get_data( -id => 'patient_id',
					    -val => $pkey,
					    -tag => 'EXISTS' );
	
	if( ! defined $patient_id ) {
	    
	    # Study Name is not always equal ty cancer id.. map them accordingly
	    if (defined $study_cancer_map{ uc($cancer_id) } ) {
		$cancer_id = $study_cancer_map{ $cancer_id };
	    }
	    
	    push( @new_data, { stable_patient_id => $stable_patient,
			       study_id => $study_id,
			       cancer_id => $cancer_id } );
	}
		
    } else { 
	$study_id = $mainDB->get_data( -id => 'study_name',
					  -val => $line->{study_name} );
	
	$stable_patient =$line->{stable_patient_id};
    
    
	$line->{ study_id } = $study_id;
	
	my $pkey = sprintf "%s_%s", $study_id, $stable_patient;
	
	# keep only uniq stable_patient_id
	if( ! exists $seen{ $table }{ $pkey } ) {
	    
	    $seen{ $table }{ $pkey } = undef;
	    push( @new_data, $line );
	    
	    # Check to see if patient is already defined.
	    #	my $patient_id  = $mainDB->get_data( -id => 'patient_id',
	    #					     -val => $pkey,
	    #					     -tag => 'EXISTS' );
	    #	
	    #	push( @new_data, $line ) if( ! defined $patient_id );
	}
    }
    
    
    undef @data;
    @data = @new_data;

}

sub process_patient_meta {
    
    my @new_data;
	
    my $line = $data[0];
    
    my $study_name = $line->{study_name};
    
#    check_data( -id => 'line ' . __LINE__ . ' - study_name',   
#		-val => $study_name, -ref => "" );
    
    my $study_id = $mainDB->get_data( -id => 'study_name',
				      -val => $study_name );
    
    my $stable = $line->{ stable_patient_id };

#    check_data( -id => 'line ' . __LINE__ . ' - stable_patient_id',
#		-val => $stable, -ref => "" );
    
    # Patients may have 2 samples, record patient_id once
    if( ! exists $seen{ $table }{ $stable } ) {
	
	$seen{ $table }{ $stable } = undef;
	
	my $pkey = "${study_id}_${stable}";
	
	my $patient_id = $mainDB->get_data( -id => 'stable_patient_id',
					    -val => $pkey );
	
	$line->{patient_id} = $patient_id;
	
	# Set the primary key for the meta
	foreach my $meta( @{ $line->{ patient_meta } } ) {
	    $meta->{ pk } = $patient_id
	}
	
	push( @new_data, $line );
    }
    
    undef @data;
    @data = @new_data;
}

sub process_sample {

    my @new_data;
    
    my $line = $data[0];

    if( $options{-s} eq 'tcga' ) {

	if( $options{-f} =~ /clinical/ ) {
	    
	    my $study_id = $mainDB->get_data( -id => 'study_id',
					      -val => $line->{study_name});
	    
	    my $patient_id = $mainDB->get_data( -id => 'patient_id',
						-val => sprintf "%s_%s", $study_id, $line->{ stable_patient_id } );
	    $line->{patient_id} = $patient_id;

	    for my $cnt( qw( sample sample-2 sample-3 sample-4 sample-5 sample-6 sample-7 sample-8 sample-9 ) ) {
		
		my $id = "patient.samples.${cnt}.bcr_sample_barcode";
		
		if( exists $line->{ $id } ) {
		    
		    my $stable_sample = uc( $line->{ $id } );
		    next if( ! defined $stable_sample || $stable_sample eq 'NA'  );
		    my @stable_sample = split( /\-/, $stable_sample );
		    $stable_sample[3] =~ s/(\d+)[A-Z]/$1/g;
		    $stable_sample = join( "-", @stable_sample );
		    $line->{ stable_sample_id } = $stable_sample;
		    
		    # "TCGA-A8-A09I-01-A"		
		    # "(TCGA-A8-A09I-)(01)(A)"
		    
		    # if( $stable_sample =~ /(TCGA-.+-.+)-(\d+)(\w)/ ) {
		    #     # 01 - 09 : Tumor
		    #     # 10 - 19 : Normal
		    #     # 20 - 29 : Control
		    #     next if( $2 >= 10 );
		    #     $stable_sample = "$1-$2";
		    # }
		    
		    #		my $sample_id = $mainDB->get_data( -id => 'sample_id',
		    #						   -val => $stable_sample,
		    #						   -tag => 'EXISTS' );
		    # Only store once
		    next if( exists $seen{ $table }{ $stable_sample } );
		    # defined $sample_id );
		    
		    $seen{ $table }{ $stable_sample } = undef;

		    push( @new_data, {stable_sample_id => $stable_sample,
				      patient_id => $patient_id,
				      cancer_id => $line->{cancer_id}});
		}
	    }


	} elsif ( $options{-f} =~ /CNV/ ) {

	    foreach my $entrez( keys %{ $line } ) {

		foreach my $stable_sample( keys %{ $line->{ $entrez } } ) {

		    my @stable_sample = split( /\-/, $stable_sample );
		    		    
		    $stable_sample[3] =~ s/(\d+)[A-Z]/$1/g;
		    $stable_sample = join( "-", @stable_sample );
		    
		    my $sample_id = $mainDB->get_data( -id => 'sample_id',
						       -val => $stable_sample,
						       -tag => 'EXISTS' );
		    if( ! defined $sample_id ) {
			# STUDY_ID
			my @pwd = split( /\//, $pwd );
			my $cancer_id = uc( pop @pwd );
			my $study_name = sprintf( "%s_%s", lc( $cancer_id ), $options{-s} );
			my $study_id = $mainDB->get_data( -id => 'study_id',
							  -val => $study_name );
			
			# PATIENT_ID
			my $stable_patient = get_stable_patient_from_sample( $stable_sample );
			
			my $pkey = sprintf "%s_%s", $study_id, $stable_patient;
			
			my $patient_id = $mainDB->get_data( -id => 'patient_id',
							    -val => $pkey );
			
			# Study Name is not always equal ty cancer id.. map them accordingly
			if (defined $study_cancer_map{ uc($cancer_id) } ) {
		     	    $cancer_id = $study_cancer_map{ $cancer_id };
			}
			
		     	push( @new_data, { stable_sample_id => $stable_sample,
		     			   patient_id => $patient_id,
					   study_id => $study_id,
		     			   cancer_id => $cancer_id } );
		    }
		}
	    }
	    
	} elsif ( $options{-f} =~ /mutations_extended/ ) {

	    my $stable_sample = $line->{ stable_sample_id };
	    
	    my @stable_sample = split( /\-/, $stable_sample );
	    $stable_sample[3] =~ s/(\d+)[A-Z]/$1/g;
	    $stable_sample = join( "-", @stable_sample );
	    
	    my $sample_id = $mainDB->get_data( -id => 'sample_id',
					       -val => $stable_sample,
					       -tag => 'EXISTS' );
	    if( ! defined $sample_id ) {
		# STUDY_ID
		my @pwd = split( /\//, $pwd );
		my $cancer_id = uc( pop @pwd );
		my $study_name = sprintf( "%s_%s", lc( $cancer_id ), $options{-s} );
		my $study_id = $mainDB->get_data( -id => 'study_id',
						  -val => $study_name );
		
		# PATIENT_ID
		my $stable_patient = get_stable_patient_from_sample( $stable_sample );
		
		my $pkey = sprintf "%s_%s", $study_id, $stable_patient;
		
		my $patient_id = $mainDB->get_data( -id => 'patient_id',
						    -val => $pkey );
		
		# Study Name is not always equal ty cancer id.. map them accordingly
		if (defined $study_cancer_map{ uc($cancer_id) } ) {
		    $cancer_id = $study_cancer_map{ $cancer_id };
		}
		
		push( @new_data, { stable_sample_id => $stable_sample,
				   patient_id => $patient_id,
				   study_id => $study_id,
				   cancer_id => $cancer_id } );
	    }
	}
	
    } elsif( $options{-s} eq 'genie' ) {
	
	my $study_id = $mainDB->get_data( -id => 'study_id',
					  -val => $line->{study_name});
	
	my $pkey = sprintf "%s_%s", $study_id, $line->{ stable_patient_id };
	
	my $patient_id = $mainDB->get_data( -id => 'patient_id',
					    -val => $pkey );
	
#	my $sample_id = $mainDB->get_data( -id => 'sample_id',
#					   -val => $line->{stable_sample_id},
#					   -tag => 'EXISTS' );

#	if ( ! defined $sample_id ) {
	    
	    $line->{patient_id} = $patient_id;
	    
	    push( @new_data, $line );
#	}
	
    }
    
    @data = ();
    
    @data = @new_data;
    
}

sub process_sample_meta {
        
    my @new_data;
    
    my $line = $data[0];


    if( $options{-s} eq 'tcga' ) {

	my %sample_map;

	my $study_id = $mainDB->get_data( -id => 'study_id',
					  -val => $line->{study_name});
	
	my $patient_id = $mainDB->get_data( -id => 'patient_id',
					    -val => sprintf "%s_%s", $study_id, $line->{ stable_patient_id } );
	$line->{patient_id} = $patient_id;
	
	for my $cnt( qw( sample sample-2 sample-3 sample-4 sample-5 sample-6 sample-7 sample-8 sample-9 ) ) {
	    
	    my $id = "patient.samples.${cnt}.bcr_sample_barcode";
	    
	    if( exists $line->{ $id } ) {
		
		my $stable = uc( $line->{ $id } );
		next if( ! defined $stable || $stable eq 'NA'  );		
		my @stable = split( /\-/, $stable );

		$stable[3] =~ s/(\d+)[A-Z]/$1/g;

		$stable = join( "-", @stable );

		# if( $stable =~ /(TCGA-.+-.+)-(\d+)(\w)/ ) {
		#     # 01 - 09 : Tumor
		#     # 10 - 19 : Normal
		#     # 20 - 29 : Control
		#     next if( $2 >= 10 );
		#     $stable = "$1-$2";
		# }

		my $sample_id = $mainDB->get_data( -id => 'sample_id',
						   -val => $stable,
						   -tag => 'EXISTS' );

		$sample_map{ $cnt } = "$sample_id";
	    }
	}
	
	my @new_meta;
	foreach my $meta ( @{ $line->{ sample_meta } } ) {
	    #patient.samples.sample-2.pathology_report_uuid
	    my @curr = split( /\./, $meta->{attr_id} );
	    
	    if( exists $sample_map{ $curr[2] } ) {
		$meta->{attr_id} = pop( @curr );
		$meta->{ pk } = $sample_map{ $curr[2] };

		push( @new_meta, $meta );
	    } 	    
	}

	$line->{ sample_meta } = \@new_meta;
	
	
    } elsif( $options{-s} eq 'genie' ) {
	

	my $stable = $line->{ stable_sample_id };
	
	my $sample_id = $mainDB->get_data( -id => 'sample_id',
					   -val => $stable );
	
	# Set the primary key for the meta
	foreach my $meta( @{ $line->{ sample_meta } } ) {
	    $meta->{ pk } = $sample_id
	}
	
	push( @new_data, $line );
        
	undef @data;
	@data = @new_data;
    }
}

sub process_cnv {
 
   my @new_data;
   my $line = $data[0];

    if( $options{-s} eq 'tcga' or $options{-s} eq 'genie' ) {
	
	foreach my $entrez ( keys %{ $line } ) {

	    foreach my $sample_id( keys %{ $line->{ $entrez } } ) {

		my $alt = $line->{ $entrez }{ $sample_id };

		next unless( $alt eq '2' || $alt eq '-2' || $alt eq '1.5' || $alt eq '-1.5' );
		
		#foreach my $alt( qw( -2  2 ) ) {
		
		my $key = sprintf "%s_%s_%s", $entrez, $alt, $alt_type{ $alt };
		
#		my $cnv_id = $mainDB->get_data( -id => 'cnv_id',
#						-val => $key,
#						-tag => 'EXISTS' );
		
#		next if( defined $cnv_id || $seen{ $table }{ $key } );
	
		next if( $seen{ $table }{ $key } );
		
		$seen{ $table }{ $key  } = undef;
	
		push( @new_data, { entrez_gene_id => $entrez,
				   alteration => $alt,
				   alteration_type => $alt_type{ $alt } } );
		
	    }
	}
	
    } else {
	
	$gen->pprint( -tag => "ERROR " . __LINE__,
		      -val => "Dont know how to process the source '$options{-s}'. Please update code" );
    }
    
    #print Dupmer \@new_data;
    @data = ();
    @data = @new_data;
}

# What do "-2", "-1", "0", "1", and "2" mean in the copy-number data?
# These levels are derived from the copy-number analysis algorithms GISTIC or RAE, and indicate the copy-number level per gene. 
# "-2" is a deep loss, possibly a homozygous deletion, 
# "-1" is a shallow loss (possibly heterozygous deletion), 
# "0" is diploid, "1" indicates a low-level gain, 
# "2" is a high-level amplification. Note that these calls are putative.

sub process_cnv_sample {

    my $line = $data[0];
    my @new_data;
    
    if( $options{-s} eq 'tcga' or $options{-s} eq 'genie' ) {

	foreach my $entrez( keys %{ $line } ) {

	    # PRAMEF21 (old) & PRAMEF20 (new) both map to entrez 645425
	    
	    next if ( exists $seen{ $table }{ $entrez } );
	    
	    $seen{ $table }{ $entrez } = undef;
	    
	    foreach my $stable ( keys %{ $line->{ $entrez } } ) {
		
		my $sample_id = $mainDB->get_data( -id => 'sample_id',
						   -val => $stable );
		
		next if( ! defined $sample_id );
		
		my %alt_map = ( '-2.0' => '-2',
				'-1.0' => '-1',
				'0.0' => '0',
				'1.0' => '1',
				'2.0' => '2' );

		my $alt = $line->{ $entrez }->{ $stable };

		$alt = $alt_map{ $alt } if ( exists $alt_map{ $alt } );

		next unless( $alt eq '2' || $alt eq '-2' || $alt eq '1.5' || $alt eq '-1.5' );
		
		my $key = sprintf( "%s_%s_%s", $entrez, $alt, $alt_type{ $alt } );
		
		my $cnv_id = $mainDB->get_data( -id => 'cnv_id',
						-val => $key );
		
		push( @new_data, { sample_id => $sample_id,
				   cnv_id => $cnv_id,
				   alteration_type => $alt_type{ $alt } } );
		
	    }
	    
	}
    } else {
	$gen->pprint( -tag => "ERROR " . __LINE__,
		      -val => "Dont know how to process the source '$options{-s}'. Please update code" );
    }

    @data = ();
    @data = @new_data;
    
}

sub process_analysis {

    my (%param) = @_;
	
    my @new_data;
	
    my $line = $data[0];

    # Map the stable_id to the sample_id
    # Do this only once to speed up
    if( $#header_sort == -1 ) {
	foreach my $entrez( keys %{ $line } ) {
	    
	    foreach my $stable( sort keys %{ $line->{ $entrez } } ) {

		my $sample_id = $mainDB->get_data( -id => 'sample_id',
						   -val => $stable,
						   -tag => "EXISTS" );
		
		next if( ! defined $sample_id );
		
		my $patient_id = $mainDB->get_data( -id => 'sample2patient_id',
						    -val => $sample_id );
	
		my $study_id = $mainDB->get_data( -id => 'patient2study_id',
						  -val => $patient_id );
		
		push( @header_sort, {stable_id => $stable,
				     sample_id => $sample_id,
				     study_id => $study_id } );
		
	    }
	}
    }

    # now that stable has been map, process the current line
    foreach my $stable ( @header_sort ) {

	my $study_id = $stable->{ study_id };
	
	# keep only uniq study_name;
	next if( exists $seen{ $study_id } );
	
	$seen{ $study_id } = undef;

	# processing the current line
	push( @new_data, { study_id  => $study_id,
			   sample_id => "",
			   name => $options{ -a } } );
	
	
    }
    @data = ();
    @data = @new_data;
    
    
    
}


		
sub process_analysis_meta {

    my (%param) = @_;
	
    my @new_data;

    # keep only uniq study_name;
	
    my $line = $data[0];

    # Only need to do this once
    my $total = keys %sample_list;
    if( $total == 0 ) {
	
	foreach my $entrez( keys %{ $line } ) {

	    foreach my $stable_sample( sort keys %{ $line->{ $entrez } } ) {
		
		my $sample_id = $mainDB->get_data( -id => 'sample_id',
						   -val => $stable_sample,
						   -tag => "EXISTS" );
		
		next if( ! defined $sample_id );
		
		my $patient_id = $mainDB->get_data( -id => 'sample2patient_id',
						    -val => $sample_id );
		
		my $study_id = $mainDB->get_data( -id => 'patient2study_id',
						  -val => $patient_id );
		
		# don't need sampleId in the key for study level analysis
		my $akey = sprintf "%s++%s", $study_id, $options{-a};
		
		my $analysis_id = $mainDB->get_data( -id => 'analysis_id',
						     -val => $akey );
		
		push( @{ $sample_list{ $analysis_id } }, $sample_id );
		
		if( exists $seen{ $table }{ $sample_id } ) {
		    $gen->pprint( -tag => "ERROR",
				  -val => "StudyID = $sample_id, seen multiple times. Please correct" );
		}
		$seen{ $table }{ $sample_id } = undef;
		
	    }
	}

    }
    # Construct sample_list structure
    # [
    #      {
    #        'analysis_meta' => [
    #                             {
    #                               'attr_value' => '105,179,....
    #                               'attr_id' => 'sample_list',
    #                               'analysis_id' => '43'
    #                             }
    #                           ]
    #      },
    foreach my $analysis_id (sort { $a <=> $b } keys %sample_list) {
	
	my @list = sort{ $a <=> $b } @{ $sample_list{ $analysis_id } };
	
	push( @new_data, { analysis_meta => [{ pk => $analysis_id,
					       attr_id => 'sample_list',
					       attr_value => join( ",", @list)
					     }]});
    }
    
    @data = ();
    @data = @new_data;
}


sub load_tcga_cnv {
    
    my @new_data;
    
    open( IN, "<$options{-f}" ) or die "$! : $options{-f}\n";
    my $out = "data_${table}.tsv";

    open(my $fh, ">", "$out" ) or die "$out : $!\n";
    my $header = 0;
    
    my $study_name = `basename \$PWD`; chomp $study_name;
    
    $study_name = sprintf "%s_%s", lc( $study_name ), $options{-s};
    
    my $study_id = $mainDB->get_data( -id => 'study_id',
				      -val => $study_name );

    # Counter
    my $total = `more $options{-f} | wc -l`; chomp $total;
    my @header;
    
    while(my $curr = <IN>) {
	
	chomp $curr;

	$gen->pprogress( -total => $total,
			 -v => 1 );
	
	if( $header == 0 ) {
	    @header = split( /\t/, $curr );
	    splice( @header, 0, 3) if( $options{-s} eq 'tcga' );
	    $header++;
	    next;
	}
	
	my @line = split( /\t/, $curr );
	
	my $hugo = $line[0];
	
	splice( @line, 0, 3 ) if( $options{-s} eq 'tcga' );
	
	my $entrez = $mainDB->get_data( -id => 'entrez',
					-hugo => $hugo );
	
	if( $entrez eq 'NA' ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping entrez, Unknown Hugo : '$hugo'",
			  -d => 1 );
	    next;
	}

	next if (exists $seen{ $table }{ $entrez } );
	
	$seen{ $table }{ $entrez } = undef;
	
	my $analysis_id = $mainDB->get_data( -id => 'analysis_id',
	 				     -val => "${study_id}++$options{-a}"    );
	
	#splice( @line, 0,33);
	
	push( @new_data, { analysis_data => [{ pk => $analysis_id,
					       entrez_gene_id => $entrez,
					       attr_id => 'cnv_sample_list',
					       attr_value => join( ",", @line )
					     }]});

    }
    
    close(IN);
    @data = ();
    @data = @new_data;
    
    $gen->pprogress_end();

    # pring data_[TABLE].tsv to disk
    $mainDB->print_data( -data => \@data,
			 -table => $options{ -table },
			 -fh => $fh );
    
}

sub process_analysis_data {

    my (%param) = @_;
    my @new_data;
    my %analysis;
    
#    $gen->pprogress_reset();

    foreach my $line( @data ) {
	
	foreach my $entrez( keys %{ $line } ) {

	    foreach my $stable_sample( keys %{ $line->{ $entrez } } ) {
		
		my $sample_id = $mainDB->get_data( -id => 'sample_id',
						   -val => $stable_sample,
						   -tag => "EXISTS" );
		# Create patient & sample_id
		next if( ! defined $sample_id );
		
#		my $patient_id = $mainDB->get_data( -id => 'sample2patient_id',
#						    -val => $sample_id );
		
#		my $study_id = $mainDB->get_data( -id => 'patient2study_id',
#						  -val => $patient_id );

		my $study_id = $mainDB->get_data( -id => 'sample2study',
						  -val => $sample_id );
		
		# don't need sampleId in the key for study level analysis
		my $analysis_id = $mainDB->get_data( -id => 'analysis_id',
						     -val => sprintf "%s++%s", $study_id, $options{-a} );
		
		# Store $alt = $line->{ $entrez }{ $stable_sample };
		$analysis{ $analysis_id }{ $entrez }{ $sample_id } = $line->{ $entrez }{ $stable_sample };
	    }
	}
	
#	$gen->pprogress( -tag => "Pre-Processing",
#			 -total => $#data + 1,
#			 -v => 1 );
    }
    
#    $gen->pprogress_end();

#     store( \%analysis, "/tmp/genie_analysis_data.storable" );
#    print "Retrieve\n";
#    %analysis  = %{ retrieve( "/tmp/genie_analysis_data.storable" ) };
    # free up memory
    @data = ();

    
    # Construct data structure
    # [
    #      {
    #        'analysis_meta' => [
    #                             {
    #                               'attr_value' => '-2,0,2,0,-1...
    #                               'attr_id' => 'cnv_sample_list',
    #                               'analysis_id' => '43'
    #                             }
    #                           ]
    #      },
    my $total = keys %analysis;

#    $gen->pprogress_reset();
    
    foreach my $analysis_id ( sort { $a <=> $b } keys %analysis ) {
	
	foreach my $entrez( sort{ $a <=> $b } keys %{ $analysis{ $analysis_id } } ) {
	    # Constrcut comma seperated CNV list 
	    my @join;

	    foreach my $sample_id ( sort{ $a <=> $b } keys %{ $analysis{ $analysis_id }{ $entrez } } ) {
		# my $alt = $analysis{ $analysis_id }{ $entrez }{ $sample_id };
		push( @join, $analysis{ $analysis_id }{ $entrez }{ $sample_id } );
	    }
	    
	    push( @new_data, { analysis_data => [{ pk => $analysis_id,
						   entrez_gene_id => $entrez,
						   attr_id => 'cnv_sample_list',
						   attr_value => join( ",", @join )
						 }]});
	}

#	$gen->pprogress( -tag => "Processing",
#			 -total => $total,
#			 -v => 1 );
    }

    
#    $gen->pprogress_end();
    
    @data = ();
    @data = @new_data;
}


sub process_variant {
    
    my @new_data;
    
    # keep only uniq study_name;
    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];

	check_data( -id => 'line ' . __LINE__ . ' - hugo',   -val => $line->{hugo_gene_symbol}, -ref => "" );
	
	my $entrez = $mainDB->get_data( -id => 'entrez',
					-hugo => $line->{hugo_gene_symbol},
					-entrez => $line->{entrez_gene_id} );
	
	$line->{entrez_gene_id } = $entrez;
	
	if( $entrez eq 'NA' ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping entrez, Unknown Hugo : '$line->{hugo_gene_symbol}'",
			  -d => 1 );
	    next;
	}
	
	my $chr = $line->{chr};
	my $start = $line->{start_position};
	my $ref = $line->{ref_allele};
	my $var2 = $line->{var_allele_2};
	$line->{var_allele} = $var2;
	
	check_data( -id => 'line ' . __LINE__ . ' - chr',   -val => $chr, -ref => "" );
	check_data( -id => 'line ' . __LINE__ . ' - start', -val => $start, -ref => "" );
	check_data( -id => 'line ' . __LINE__ . ' - ref',   -val => $ref, -ref => "" );
	check_data( -id => 'line ' . __LINE__ . ' - var2',   -val => $var2, -ref => "" );
	
	my $varkey = sprintf "%s_%s_%s_%s", $chr, $start, $ref, $var2;

#	my $variant_id = $mainDB->get_data( -id => 'variant_id',
#					    -val => $varkey,
#					    -tag => 'EXISTS' );

#	if( exists $seen{ $table }{ $varkey } || defined $variant_id ) {
	if( exists $seen{ $table }{ $varkey } ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping varkey, already exists or seen : '$varkey'",
			  -d => 1);
	    
	    next;
	}

	
	# only store the varkey once
	$seen{ $table }{ $varkey } = undef;
	
	$line->{varkey} = $varkey;
	
	push( @new_data, $line );

    }
    @data = ();
    @data = @new_data;
    
    # $gen->pprint( -val => "Total Variants : " . ($#data + 1) );
    
}

sub process_variant_sample {
    
    my @new_data;
    # keep only uniq study_name;
    # my $file = sprintf "data_%s.tsv", $options{-table};
    #open( $fh, ">$file" );
    
    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];
	
	my $entrez = $mainDB->get_data( -id => 'entrez',
					-hugo => $line->{hugo_gene_symbol},
					-entrez => $line->{entrez_gene_id} );
	
	$line->{entrez_gene_id } = $entrez;
	
	if( $entrez eq 'NA' ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping entrez, Unknown Hugo : '$line->{hugo_gene_symbol}'",
			  -d => 1 );
	    next;
	}
	
#	check_data( -id => 'entrez ' . __LINE__ . ' - entrez',   -val => $entrez, -ref => "" );
#	check_data( -id => 'hugo ' . __LINE__ . ' - hugo',   -val => $line->{hugo_gene_symbol}, -ref => "" );
	
	my $chr = $line->{chr};
	my $start = $line->{start_position};
	my $ref = $line->{ref_allele};
	my $var2 = $line->{var_allele_2};
	$line->{var_allele} = $var2;


#	check_data( -id => 'line ' . __LINE__ . ' - chr',   -val => $chr, -ref => "" );
#	check_data( -id => 'line ' . __LINE__ . ' - start', -val => $start, -ref => "" );
#	check_data( -id => 'line ' . __LINE__ . ' - ref',   -val => $ref, -ref => "" );
#	check_data( -id => 'line ' . __LINE__ . ' - var2',   -val => $var2, -ref => "" );

	my $varkey = sprintf( "%s_%s_%s_%s", $chr, $start,$ref, $var2 );
	$line->{variant_id} = $mainDB->get_data( -id => 'variant_id',
						 -val => $varkey );
	
	$line->{sample_id}  = $mainDB->get_data( -id => 'sample_id',
						 -val => $line->{stable_sample_id}) ;
	
	# if the variant - sample is defined twice
	# this happens due to issue from the source.
	# see variants from BRCA  TCGA-A2-A0T0-01 ABCA4, is defined twice difference is just the ref count 

	my $vkey = sprintf "%s+%s", $line->{variant_id}, $line->{sample_id};  
	
#	my $variant_sample_id = $mainDB->get_data( -id => 'variant_sample_id',
#						   -val => $vkey,
#						   -tag => 'EXISTS' );

	# if (defined $variant_sample_id ) {
	#     $gen->pprint( -tag => "WARNING",
	# 		  -val => "Skipping variant_sample, already in DB. $vkey (variant_id+sample_id)" );
	#     next;

	# }

	if( exists $seen{ $table }{ $vkey } ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping variant_sample, already seen. $vkey (variant_id+sample_id)",
			  -d => 1 );
	    next;
	}

	$seen{ $table }{ $vkey } = 1;
	
	push( @new_data, $line );

    }
    @data = ();
    @data = @new_data;

}


sub process_variant_sample_meta {

    my @new_data;

    my $line = $data[0];

    my $entrez = $mainDB->get_data( -id => 'entrez',
				    -hugo => $line->{hugo_gene_symbol},
				    -entrez => $line->{entrez_gene_id} );
    
    # keep only uniq study_name;
    if( $entrez eq 'NA' ) {
	$gen->pprint( -tag => "WARNING",
		      -val => "Skipping entrez, Unknown Hugo : '$line->{hugo_gene_symbol}'",
		      -d => 1 );

    } elsif( $options{ -s } eq 'tcga' || $options{-s} eq 'genie') {
	
	$line->{entrez_gene_id } = $entrez;
	
#	check_data( -id => 'entrez ' . __LINE__ . ' - entrez',   -val => $entrez, -ref => "" );
#	check_data( -id => 'hugo ' . __LINE__ . ' - hugo',   -val => $line->{hugo_gene_symbol}, -ref => "" );
	
	my $chr = $line->{chr};
	my $start = $line->{start_position};
	my $ref = $line->{ref_allele};
	my $var1 = $line->{var_allele_1};
	my $var2 = $line->{var_allele_2};
	$line->{var_allele} = $var2;

#	check_data( -id => 'line ' . __LINE__ . ' - chr',   -val => $chr, -ref => "" );
#	check_data( -id => 'line ' . __LINE__ . ' - start', -val => $start, -ref => "" );
#	check_data( -id => 'line ' . __LINE__ . ' - ref',   -val => $ref, -ref => "" );
#	check_data( -id => 'line ' . __LINE__ . ' - var2',   -val => $var2, -ref => "" );
	
	my $varkey = sprintf( "%s_%s_%s_%s", $chr, $start,$ref, $var2 );
	my $variant_id = $mainDB->get_data( -id => 'variant_id',
					    -val => $varkey );

	my $sample_id = $mainDB->get_data( -id => 'sample_id',
					   -val => $line->{stable_sample_id}) ;
	
	my $variant_sample_id = $mainDB->get_data( -id => 'variant_sample_id',
						   -val => sprintf( "%s+%s", $variant_id, $sample_id ) );
						   
	my @meta;
	
	foreach my $meta( @{ $line->{ variant_sample_meta } } ) {

	    next if( ! defined $meta->{ attr_value } );

	    my $key = sprintf "%s+%s", $variant_sample_id, $meta->{attr_id};
	    
#	    my $variant_sample_meta = $mainDB->get_data( -id => 'variant_sample_meta',
#							 -val => $key,
#							 -tag => 'EXISTS' );
	    
#	    if (defined $variant_sample_meta ) {
#		$gen->pprint( -tag => "WARNING",
#			      -val => "Skipping variant_sample, already in DB. $key (variant_id+attr_id)" );
#		next;
#	    }
	    
	    # Set the primary key for the meta
	    $meta->{ pk } = $variant_sample_id;
	    
	    push( @meta, $meta );
	}

	# Add Allel1 & Allel2
	push( @meta, { pk => $variant_sample_id,
		       attr_id => 'Tumor_Seq_Allele1',
		       attr_value => $var1 } );

	push( @meta, { pk => $variant_sample_id,
		       attr_id => 'Tumor_Seq_Allele2',
		       attr_value => $var2 } );
	
	$line->{ variant_sample_meta } = \@meta;
	
	push( @new_data, $line );

    } else {
	$gen->pprint( -tag => "ERROR " . __LINE__,
		      -val => "Dont know how to process the source '$options{-s}'. Please update code" );
    }

    
    undef @data;
    @data = @new_data;
}



sub process_variant_meta {


    my @new_data;

    # keep only uniq study_name;
    for my $idx( 0 .. $#data ) {

	my $line = $data[$idx];

	# check_data( -id => 'line ' . __LINE__ . ' - hugo',   -val => $line->{hugo_gene_symbol}, -ref => "" );
	
	my $entrez = $mainDB->get_data( -id => 'entrez',
					-hugo => $line->{hugo_gene_symbol},
					-entrez => $line->{entrez_gene_id} );
	
	$line->{entrez_gene_id } = $entrez;
	
	if( $entrez eq 'NA' ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping entrez, Unknown Id '$line->{hugo_gene_symbol}'",
			  -d => 1 );
	    next;
	}
	
	my $chr = $line->{chr};
	my $start = $line->{start_position};
	my $ref = $line->{ref_allele};
	my $var2 = $line->{var_allele_2};
	$line->{var_allele} = $var2;
	
	# check_data( -id => 'line ' . __LINE__ . ' - chr',   -val => $chr, -ref => "" );
	# check_data( -id => 'line ' . __LINE__ . ' - start', -val => $start, -ref => "" );
	# check_data( -id => 'line ' . __LINE__ . ' - ref',   -val => $ref, -ref => "" );
	# check_data( -id => 'line ' . __LINE__ . ' - var2',   -val => $var2, -ref => "" );

	my $varkey = sprintf "%s_%s_%s_%s", $chr, $start, $ref, $var2;

	my $variant_id = $mainDB->get_data( -id => 'variant_id',
					    -val => $varkey );
	# Only store it once
		
	my @meta;

	foreach my $meta( @{ $line->{ variant_meta } } ) {
	    
	    next if( ! defined $meta->{ attr_value } );
	    $meta->{ attr_value } =~ s/\"//g;
		     
	    # Set the primary key for the meta
	    $meta->{ pk } = $variant_id;
	
	    my $key = sprintf "%s+%s", $variant_id, $meta->{ attr_id };

	    next if( exists $seen{ $table }{ $key } );
	    $seen{ $table }{ $key } = undef;
	    
	    # my $var_meta = $mainDB->get_data( -id => 'variant_meta',
	    # 				      -val => $key,
	    # 				      -tag => "GET" );

	    # # Already seen
	    # next if( defined $var_meta );
	    
	    push( @meta, $meta );
	}
	
		
	$line->{ variant_meta } = \@meta;
	
	push( @new_data, $line );
    }
    
    undef @data;
    @data = @new_data;
    
}




sub check_data {

    my (%param) = @_;

    my $line = (defined $param{-line}) ? " $param{-line}" : "";
    
    if( ! defined $param{ -val } ) {
	
	$gen->pprint( -tag => "ERROR" . $line,
		      -val => "$param{ -id } '$param{-ref}' not defined. Please correct to continue $0" );
    }
}




sub load_file {
    
    my( %param ) = @_;

    my $total = `more $param{-f} | wc -l`; chomp $total;
    
    #open( IN, "<encoding(UTF-8)", $param{ -f } ) or die "$param{ -f } : $!\n";
    open( IN, "<$param{ -f }" ) or die "$param{ -f } : $!\n";

    my $out = "data_${table}.tsv";

    open(my $fh, ">", "$out" ) or die "$out : $!\n";
    
    my $header = 0;
    my @header;

    $gen->pprogress_reset( -val => "Loading File : $param{-f }" );
    
    while( my $curr = <IN>) {

	chomp $curr;

	$curr = unidecode($curr);
	
	next if( $curr =~ /^#/ );
	
	$curr =~ s/\"//g;
	
	if( $header == 0 ){
	    
	    @header = split( /\t/, $curr );
	    
	    # conver all the header to lower case to ease coding
	    # but store the origical lower case / upper. we will convert the case back to the original later on
	    for my $idx( 0 .. $#header ) {

		# Chromosome
		my $val = $header[$idx];
		
		if( exists $map{ $options{-f} }{ $val }{ new_col } ) {

		    # chr
		    my $new_val = $map{ $options{-f} }{ $val }{ new_col };

		    # chromosome
		    $header[$idx] = lc($new_val);
		    
		    $case{ lc($val) } = $new_val;
		    $case{ lc($new_val) } = $new_val;		    		    
		}
	    }
	    $header++;
	    next;	    
	}
	
	my %line;

	@line{ @header } = split( /\t/, $curr );

	if( $options{-s} eq 'genie' ) {

	    if( exists $line{ cancer_id } ) {
		
		# Add Study Specific Information
		my $cancer_id = $line{cancer_id};
		$line{cancer_id} = $cancer_id;
		$line{description} = sprintf "%s (GENIE)", $line{cancer_type};
		$line{source} = sprintf "%s_%s", $options{ -s }, $options{ -sv };
		
		my $study_name = sprintf "%s_%s", $line{study}, $options{-s};
		$line{study_name} = lc( $study_name );
		
	    } 
	    
	} elsif( $options{-s} eq 'tcga' ) {
	    
	    if( exists $line{ cancer_id } ) {

		# Add Study Specific Information
		my $cancer_id = uc($line{cancer_id});

		# manual overide for cancer id
		$cancer_id = uc( $options{ -cid } ) if ( defined $options{ -cid } );
		
		$line{cancer_id} = $cancer_id;
		$line{description} = $meta_study{ lc($cancer_id) }{ description };
		
		my $study_name = sprintf "%s_%s", $cancer_id, $options{-s};		
		$line{study_name} = lc( $study_name );
		$line{source} = sprintf "%s_%s", $options{ -s }, $options{ -sv };
		
		# Study Name is not always equal ty cancer id.. map them accordingly
		if (defined $study_cancer_map{ uc($cancer_id) } ) {
		    $cancer_id = $study_cancer_map{ $cancer_id };
		    $line{ cancer_id } = $cancer_id;
		}

		# COADREAD is a speacial case as its a cohort made up of COAD + READ
		$line{ study_name } = 'coadread_tcga' if( $pwd_study =~ /COADREAD/i );
		

	    }

	    # capitalize stable id
	    if(exists $line{stable_patient_id} ) {
		$line{stable_patient_id} = uc( $line{stable_patient_id} );
	    }
	    
	    # Convert
	    # TCGA-OR-A5KS-01A-11D-A30A-10
	    # TCGA-OR-A5KS-01A

	    if( exists $line{ stable_sample_id } ) {
		my $stable = $line{stable_sample_id};
		my @stable = split( /\-/, $stable );
		# TCGA-OR-A5KS-01A to 
		# TCGA-OR-A5KS-01
		if( ! defined $stable[3] ) {
		    print Dumper \@stable;exit;
		}
		   
		$stable[3] =~ s/(\d+)[A-Z]/$1/g;
		
		splice( @stable, 4 );
		$line{stable_sample_id} = uc( join("-", @stable ) );
	    }
	    
	    # Convert
	    # TCGA-OR-A5KS-01A-11D-A30A-10
	    # TCGA-OR-A5KS-01A

	    if( exists $line{ matched_norm_sample_barcode } ) {
		
		my $stable = $line{matched_norm_sample_barcode};
		my @stable = split( /\-/, $stable );
		$stable[3] =~ s/(\d+)[A-Z]/$1/g;
		splice( @stable, 4 );
		$line{matched_norm_sample_barcode} = uc( join("-", @stable ) );
	    }

	    
	} else {

	    $gen->pprint( -tag => "ERROR " . __LINE__ ,
			  -val => "unrecognize study. Please add code to handle $options{-s}" );
	}
	
	
	###############
	my %new_line;

	if( $options{-f} =~ /.*CNV.txt/ ) {
	    
	    if( $options{-s} =~ /genie/ || $options{-s} =~ /tcga/ ) {

		my $hugo = $line{hugo_gene_symbol};

		# Grab the first (SNORA2)
		# SNORA2|ENSG00000199959.1
		if( $hugo =~ /\|/ ) {
		    my @line = split( /\|/, $hugo );
		    $hugo = $line[0];
		}
		
		my $entrez = $mainDB->get_data( -id => 'entrez',
						-hugo => $hugo );

		if( $entrez eq 'NA' ) {

		    $gen->pprint( -tag => "WARNING",
				  -val => "Skipping entrez, unknown id : '$line{hugo_gene_symbol}'",
				  -d => 1 );
		    next;
		}
		
		# Delete all the mapped columns, we only care about the stable_id
		# HUGO_SYMBOL<-delete     GENIE-34324     GENIE-23434
		
		foreach my $curr (keys %{ $map{ $options{-f} } } ) {

		    next unless( exists $map{ $options{-f} }{ $curr }{ new_col } );
		    
		    my $val = lc( $map{ $options{-f} }{ $curr }{ new_col } );
		    
		    delete $line{ $val } if( exists $line{ $val } );
		    
		}
	
		# Convert for TCGA.... for genie keep the original
		# TCGA-OR-A5J1-01A-11D-A29H-01
		# TCGA-OR-A5J1-01A

		foreach my $curr ( keys %line ) {
		    
		    my $stable;
		    
		    if( $options{-s} eq 'tcga' ) {
			my @stable = split( /\-/, $curr );
			
			splice( @stable, 4 );
			$stable[3] =~ s/(\d+)[A-Z]/$1/g;
			$stable = join( "-", @stable );
			
		    } elsif( $options{-s} eq 'genie' ) {
			
			$stable = $curr;
		    }
		    
		    $new_line{ $entrez }{ $stable } = $line{ $curr };
		}
 		
		push( @data, \%new_line );
		
		# Short cut to speed transaction
		# for analysis I only need to process the header
		if( $options{-table} eq 'analysis' || $options{-table} eq 'analysis_meta' ||
		    ($options{-table} eq 'sample' && $options{-f} =~ /CNV/) ||
		    ($options{-table} eq 'patient' && $options{-f} =~ /CNV/)
		    		    
		    ) {
		   
		    # Process the data depending on the table type
		    my $ret = &{ $process{ $table } };
		    
		    if( $ret != 0 )  {
			# pring data_[TABLE].tsv to disk
			$mainDB->print_data( -data => \@data,
					     -table => $options{ -table },
					     -fh => $fh );
		    } 
		    
		    $gen->pprogress( -total => $total, 
				     -v => 1 );
		    
		    last;
		}
		
	    } 
	
	} elsif( $options{ -table } =~ /meta/i ) {
	    
	    while( my( $key, $value ) = each( %line ) ) {

		if( defined $map{ $options{-f} }{ $key }{ table_meta } ) { 

		    my $meta = $map{ $options{-f} }{ $key }{ table_meta };
		    
		    # Reformat those with meta into its own hash
		    # FROM
		    #  'sample_type' => 'Primary',
		    #  'center' => 'DFCI'
		    # TO
		    #  'sample_type' => 'Primary',
		    #  'sample_meta' => { 'attr_id' => 'center',
		    #                     'attr_value' => 'DFCI' }
		    
		    next if ( ! defined $options{-e} && 
			      (! defined $value || $value eq "" || $value eq "." || $value eq "," || 
			       $value =~ /^,+$/ || $value eq 'NA' ) );
		    
		    # for attr_id, restore the original case capitalization
		    push( @{ $new_line{ $meta } }, { 'attr_id' => $case{ $key },
						     'attr_value' => $value } );
		    
		    
		} else {
		    
		    $new_line{ $key } = $value;
		}
	    }
	    
	    push( @data, \%new_line );
	 
	} else {
	    
	    push( @data, \%line );
	}
	
	# For analysis_data, we need to process the entire data 
	#if( $options{-table} ne 'analysis_data' ) {
	    # Process the data depending on the table type
	
	my $ret = &{ $process{ $table } };
	
	# my $a = `echo 1`; chomp $a;
	# if( $a != 1 ) {

	#     open( OUT,">ACC_error.log" );
	#     print OUT $curr,"\n";
	#     close(OUT);
	#     exit;
	    
	# }
	
	if( $#data != -1 ) {
	    # print Dumper "A - " . $data[0]{study_name};
	    #print Dumper "A - " . $data[1]{study_name} || "NA";
	    $mainDB->print_data( -data => \@data,
				 -table => $options{ -table },
				 -fh => $fh );

	    undef @data;
	}
	
	$gen->pprogress( -total => $total, 
			     -v => 1 );
	
    }
    
    $gen->pprogress_end();
    
    close( IN );
    
    
    ###############
    # For TCGA, COADREAD study is compose of COAD and READ
    # So need to merge and figure out what the study name is 
    if( $options{-s} eq 'tcga' && 
	( ($options{-table} =~ /study/) || $options{-table} =~ /patient/ ) ) {
	
    	my %cancer_ids;
    	foreach my $line ( @data ) {
    	    $cancer_ids{ $line->{cancer_id} } = undef;
    	}
	
	my $total = keys %cancer_ids;

	if( $total > 1 ) {
	
	    my $cancer_ids;
	    foreach my $id ( sort keys %cancer_ids ) {
		$cancer_ids .= lc($id) . ",";
	    }
	    
	    chop $cancer_ids;
	    my $study_name = $meta_study{ $cancer_ids }{ study_name };
	    my $description = $meta_study{ $cancer_ids }{ description };
	    
	    check_data( -id => 'line ' . __LINE__ . ' - study_name',  -val => $study_name, -ref => "" );
	    check_data( -id => 'line ' . __LINE__ . ' - description',  -val => $description, -ref => "" );
	    
	    foreach my $line( @data ) {
		$line->{study_name} = $study_name;
		$line->{description} = $description;
	    }
	}	
    }

    
    # if( $options{-table} ne 'analysis_data' ) {
	
    # 	 $gen->pprint( -level => 0,
    # 		       -tag => "Processing",
    # 		       -val => "$table" );
	 
    # 	 # Process the data depending on the table type
    # 	 &{ $process{ $table } };

    # 	 # pring data_[TABLE].tsv to disk
    # 	 $mainDB->print_data( -data => \@data,
    # 			      -table => $options{ -table },
    # 			      -fh => $fh,
    # 			      -v => 1 );
    # }
    
}

sub load_header_map {

    # $gen->pprint( -val => "Loading Header Mapping File" );
    
    open( IN, "$options{-mf}" ) or die "$options{-mf} : $!\n";
    
    my @header;
    my $header = 0;
    while( my $curr = <IN> ) {
	
	chomp $curr;
	
	next if( $curr =~ /^\t/ ); # Skip empty
	
	if( $header == 0 ) {
	    @header = split( /\t/, $curr );
	    $header++;
	    next;
	}
	
	my %line;
	
	@line{ @header } = split( /\t/, $curr );
	
	check_data( -id => 'line ' . __LINE__ . ' - old_col',  -val => $line{old_col}, -ref => "" );
	check_data( -id => 'line ' . __LINE__ . ' - file',  -val => $line{file}, -ref => "" );
	
	my $h_file = $line{file};
	my $old_col = $line{old_col};
	
	# Dont store these values
	delete $line{file};
	delete $line{old_col};
 	my $new_col = ( !defined $line{new_col} ||  $line{new_col} eq '') ? $old_col : $line{new_col};
	$line{ new_col } = $new_col;
	
	my %line1 = %line;
	my %line2 = %line;
	$map{ $h_file }{ $old_col } = \%line1;
	$map{ $h_file }{ lc($old_col) } = \%line2;
	$map{ $h_file }{ lc($new_col) } = \%line2;
    }
    
    close( IN );

}

sub load_tcga_cancer_type_map {

    my $header = 0;
    my @header;

    open( IN, "</srv/datahub/mainDB.seedDB/disease_code_to_cancer_id.tsv" ) or die "$!\n";
    
    while( my $curr = <IN>) {
	
	chomp $curr;

	if( $header == 0 ) {
	    @header = split( /\t/, $curr );
	    $header++;
	    next;
	}
	my %line;
	@line{ @header } = split( /\t/, $curr );

	$meta_study{ $line{disease_code} } = \%line;
    
    }
    
    close( IN );
}
