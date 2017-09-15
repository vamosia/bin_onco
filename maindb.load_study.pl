#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;

my %options = ( -s => 'genie',
		-sv => 'release_1.0.1' );

GetOptions( "d"      => \$options{ -d },
	    "dd"     => \$options{ -dd },
	    "ddd"    => \$options{ -ddd },
	    "db=s"   => \$options{ -db },
	    "v"      => \$options{ -v },
	    "s=s"    => \$options{ -s },
	    "a=s"    => \$options{ -a }, #analysis name
	    "t=s"    => \$options{ -table },   # Table
	    "f=s"    => \$options{ -f },   # File
	    "c"      => \$options{ -c },   # Copy to DB
	    "tr"     => \$options{ -tr }   # Truncate
    ) or die "Incorrect Options $0!\n";


my $gen = new Generic (%options);

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
		  -val => "$0 : -a (Analysis Name) required" );
}

my $url;
if( $options{ -s } eq 'genie' ) {
    $url = "www.aacr.org/RESEARCH/RESEARCH/PAGES/AACR-PROJECT-GENIE-DATA.ASPX";
}
$| = 1;
my %map;
my @data;

my %case;

my $pwd = `pwd`; chomp $pwd;

load_header_map();

my $mainDB = new MainDB( %options );

$mainDB->truncate( %options );

my $table = $options{ -table };

load_file( -f => $options{ -f } );

my %copy = ( 
    study =>         qq(study(source, study_name, description)),
    study_meta =>    qq(study_meta(study_id, attr_id, attr_value)),
    cancer_study =>  qq(cancer_study(study_id, cancer_id) ),
    patient =>       qq(patient(stable_patient_id, study_id)),
    patient_meta =>  qq(patient_meta(patient_id, attr_id, attr_value)),
    sample =>        qq(sample(stable_sample_id, cancer_id, patient_id)),
    sample_meta =>   qq(sample_meta(sample_id, attr_id, attr_value)),
    variant =>       qq(variant(varkey, entrez_gene_id, chr, start_position, end_position, ref_allele, var_allele_1, var_allele_2, genome_build, strand)),
    variant_meta =>  qq(variant_meta(variant_id, attr_id, attr_value)),
    analysis =>      qq(analysis(study_id, sample_id, name)),
    analysis_meta => qq(analysis_meta(analysis_id, attr_id, attr_value)),
    analysis_data => qq(analysis_data(analysis_id, entrez_gene_id, attr_id, attr_value))
    );

unless( defined $copy{ $table } ) {
    $gen->pprint( -tag => "ERROR",
		  -val => "psql COPY query not defined" );
}

my $copy = qq(copy $copy{$table} FROM '$pwd/data_$table.tsv' using DELIMITERS E'\\t' WITH NULL AS '');

my %process = ( study         => \&process_study,
		study_meta    => \&process_study_meta,
		cancer_study  => \&process_cancer_study,
		patient       => \&process_patient,
		patient_meta  => \&process_patient_meta,
		sample        => \&process_sample,
		sample_meta   => \&process_sample_meta,
		variant       => \&process_variant,
		variant_meta  => \&process_variant_meta,
		analysis      => \&process_analysis,
		analysis_meta => \&process_analysis_meta,
		analysis_data => \&process_analysis_data
    );
if( exists $process{ $table } ) {

    $gen->pprint( -level => 0,
		  -tag => "PROCESSING",
		  -val => "$table" );

    # Process the data depending on the table type
    &{ $process{ $table } };

} else  {
    $gen->pprint( -tag => "ERROR 99",
		  -val => "$options{-table} not defined in $0" );
}

# pring data_[TABLE].tsv to disk
$mainDB->print_data( -data => \@data,
		     -table => $options{ -table } );


if( $options {-c} ) {
    $gen->pprint( -val => "Copying data_$options{-table}.tsv to database" );    

    my $st = qq(sudo -i -u postgres psql $options{-db} -c "$copy" );

    system($st) 
}

###### SUBROUTINE
		


sub get_id {

    my( %param
	) = @_;
    
    my $id = $param{ -id };
    my $line = $param{ -line };
    my $ret;
    
    if( $id eq 'study_id' ) {

	$ret = $mainDB->get_data( -id => $id,
				  -val => $line->{ study_name } );
	
    } elsif( $id eq 'patient_id' ) {

	my $stable = $line->{ stable_patient_id };
	
	my $study_id = get_id( -id => 'study_id', -line => $line );
	
	my $pkey = "${study_id}_${stable}";

	$ret = $mainDB->get_data( -id => $id,
				  -val => $pkey );

    }
    return( $ret );
    
}

sub process_study_meta {

    my %seen;
    my @new_data;
    # keep only uniq study_name;
    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];
	
	next if( exists $seen{ $line->{study_name} } );
	$seen{ $line->{study_name} } = undef;
	
	my $study_name = $line->{study_name};
	
	my $study_id = $mainDB->get_data( -id => 'study_name',
					  -val => $study_name );
        
	$line->{study_id} = $study_id;

	if( $options{-f} =~ /^genie/ ) {
	    push( @{ $line->{ study_meta } }, { 'attr_id' => "download",
						'attr_value' => "http://www.aacr.org/Research/Research/PAGES/AACR-PROJECT-GENIE-DATA.ASPX" });
	}
	
	# Set the primary key for the meta
	foreach my $meta( @{ $line->{ study_meta } } ) {
	    $meta->{ pk } = $study_id;
	}
	
	push( @new_data, $line );
    }

    @data = undef;
    @data = @new_data;

    
}




sub process_study {

    my @new_data;
    my %seen;

    # keep only uniq study_name;
    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];
	
	next if( exists $seen{ $line->{study_name } } );
	$seen{ $line->{study_name} } = undef;

	my $study_name = $line->{study_name};
	my $study_id = $mainDB->get_data( -id => 'study_name',
					  -val => $study_name,
					  -tag => 'EXISTS' );

	next if( defined $study_id );
	
	push( @new_data, $line );
    }

    @data = undef;
    @data = @new_data;
    
}

sub process_cancer_study {

    my @new_data;
    my %cancer_study;
    my %seen;
    
    # keep only uniq study_name;
    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];
	
	
	my $stable = $line->{stable_patient_id};
	my $study_name = $line->{study_name};
	
	my $study_id = $mainDB->get_data( -id => 'study_id',
					  -val => $study_name );
	
	$line->{study_id} = $study_id;
	
	my $cs_key = sprintf "%s+%s", $study_id, $line->{cancer_id};

	# Avoid duplicates
	next if( exists $seen{ $cs_key } );
	
	$seen{ $cs_key } = undef;
	
	my $cs_id = $mainDB->get_data( -id => 'cancer_study_id',
				       -val => $cs_key,
				       -tag => 'EXISTS' );

	next if ( defined $cs_id );
	
	push( @new_data, $line );
    }
    @data =();
    @data = @new_data;
    
}

sub process_patient {

    my @new_data;
    my %seen;

    # keep only uniq stable_patient_id
    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];
	
	
	my $study_name = $line->{study_name};
	
	my $study_id = $mainDB->get_data( -id => 'study_name',
					  -val => $study_name );
	
	$line->{ study_id } = $study_id;
	
	my $stable = $line->{stable_patient_id};
	
	my $pkey = sprintf "%s_%s", $study_id, $stable;
	
	next if( exists $seen{ $pkey } );	
	
	$seen{ $pkey } = undef;
	
	# Check to see if patient is already defined.
	my $patient_id  = $mainDB->get_data( -id => 'patient_id',
					     -val => $pkey,
					     -tag => 'EXISTS' );
	
	next if( defined $patient_id );
	
	push( @new_data, $line );
    }

    @data = undef;
    @data = @new_data;

    $gen->pprint( -val => "Processing Patient : " . ($#data + 1) );
}

sub process_patient_meta {
    
    my %seen;
    my @new_data;

    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];
	
	my $study_name = $line->{study_name};
	
	my $study_id = $mainDB->get_data( -id => 'study_name',
					  -val => $study_name );
	
	my $stable = $line->{ stable_patient_id };
	
	# Patients may have 2 samples, record patient_id once
	next if( exists $seen{ $stable } );
	
	$seen{ $stable } = undef;
	
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
    
    @data = undef;
    @data = @new_data;
}

sub process_sample {

    my @new_data;

    for my $idx( 0 .. $#data ) {

	my $line = $data[$idx];
	
	my $study_id = $mainDB->get_data( -id => 'study_id',
					  -val => $line->{study_name});
	my $stable = $line->{ stable_patient_id };

	my $pkey = "${study_id}_${stable}";

	my $patient_id = $mainDB->get_data( -id => 'patient_id',
					    -val => $pkey );

	my $sample_id = $mainDB->get_data( -id => 'sample_id',
					   -val => $line->{stable_sample_id},
					   -tag => 'EXISTS' );
	next if ( defined $sample_id );
	
	$line->{patient_id} = $patient_id;
	
	push( @new_data, $line );
	
    }
    
    @data = ();
    @data = @new_data;
    
}

sub process_sample_meta {
    
    my %seen;
    my @new_data;

    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];
	
	my $stable = $line->{ stable_sample_id };
	
	my $sample_id = $mainDB->get_data( -id => 'sample_id',
					   -val => $stable );
 	
	# Set the primary key for the meta
	foreach my $meta( @{ $line->{ sample_meta } } ) {
	    $meta->{ pk } = $sample_id
	}

	push( @new_data, $line );
    }
    
    @data = undef;
    @data = @new_data;

}

sub process_variant {
    
    my %seen;
    my @new_data;
    # keep only uniq study_name;
    for my $idx( 0 .. $#data ) {
	
	my $line = $data[$idx];
	
	my $entrez = $mainDB->get_data( -id => 'entrez',
					-hugo => $line->{hugo_gene_symbol},
					-entrez => $line->{entrez_gene_id} );
	
	$line->{entrez_gene_id } = $entrez;
	
	if( $entrez eq 'NA' ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping entrez, unknown id : '$line->{hugo_gene_symbol}'" );
	    next;
	}

	my $chr = $line->{chr};
	my $start = $line->{start_position};
	my $end = $line->{end_position};
	my $ref = $line->{ref_allele};
	my $var = $line->{var_allele_2};

	check_data( -id => 'chr',   -val => $chr, -ref => "" );
	check_data( -id => 'start', -val => $start, -ref => "" );
	check_data( -id => 'end',   -val => $end, -ref => "" );
	check_data( -id => 'ref',   -val => $ref, -ref => "" );
	check_data( -id => 'var',   -val => $var, -ref => "" );
	
	my $varkey = sprintf "%s_%s_%s_%s_%s", $chr, $start, $end, $ref, $var;

	my $variant_id = $mainDB->get_data( -id => 'variant_id',
					    -val => $varkey,
					    -tag => 'EXISTS' );
	
	if( exists $seen{ $varkey } ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping varkey, already exists or seen : '$varkey'" );
	    
	    next;
	}

	# only store the varkey once
	$seen{ $varkey } = undef;
	
	$line->{varkey} = $varkey;
	
	
	push( @new_data, $line );

    }
    @data = ();
    @data = @new_data;
    
    $gen->pprint( -val => "Total Variants : " . ($#data + 1) );
    
}


sub process_variant_meta {

    my %seen;
    my @new_data;
    
    # keep only uniq study_name;
    for my $idx( 0 .. $#data ) {

	my $line = $data[$idx];

	my $entrez = $mainDB->get_data( -id => 'entrez',
					-hugo => $line->{hugo_gene_symbol},
					-entrez => $line->{entrez_gene_id} );
	
	$line->{entrez_gene_id } = $entrez;
	
	if( $entrez eq 'NA' ) {
	    $gen->pprint( -tag => "WARNING",
			  -val => "Skipping entrez, Unknown Id '$line->{hugo_gene_symbol}'" );
	    next;
	}
	
	my $chr = $line->{chr};
	my $start = $line->{start_position};
	my $end = $line->{end_position};
	my $ref = $line->{ref_allele};
	my $var = $line->{var_allele_2};
	
	check_data( -id => 'chr',   -val => $chr, -ref => "" );
	check_data( -id => 'start', -val => $start, -ref => "" );
	check_data( -id => 'end',   -val => $end, -ref => "" );
	check_data( -id => 'ref',   -val => $ref, -ref => "" );
	check_data( -id => 'var',   -val => $var, -ref => "" );

	my $varkey = sprintf "%s_%s_%s_%s_%s", $chr, $start, $end, $ref, $var;

	my $variant_id = $mainDB->get_data( -id => 'variant_id',
					    -val => $varkey );

	my @meta;
	
	# Set the primary key for the meta
	foreach my $meta( @{ $line->{ variant_meta } } ) {
	    next if( ! defined $meta->{ attr_value } );
	    
	    $meta->{ pk } = $variant_id;

	    push( @meta, $meta );
	}

	$line->{ variant_meta } = \@meta;

	# Only store it once
	next if( exists $seen{ $variant_id } );
	$seen{ $variant_id } = undef;
	
	push( @new_data, $line );
    }
    
    @data = ();
    @data = @new_data;
    
}

sub process_analysis {

    my (%param) = @_;
	
    my %seen;

    my @new_data;
    # keep only uniq study_name;
	
    my $line = $data[0];
    
    foreach my $entrez( keys %{ $line } ) {
	
	foreach my $stable( sort keys %{ $line->{ $entrez } } ) {
	    
	    my $sample_id = $mainDB->get_data( -id => 'sample_id',
					       -val => $stable );
	    
	    my $patient_id = $mainDB->get_data( -id => 'sample2patient_id',
						-val => $sample_id );
	    
	    my $study_id = $mainDB->get_data( -id => 'patient2study_id',
					      -val => $patient_id );
	    
	    next if( exists $seen{ $study_id } );
		    
	    $seen{ $study_id } = undef;
	    
	    push( @new_data, { study_id  => $study_id,
			       sample_id => '',
			       name => $options{ -a } } );
	}
    }
    
    @data = ();
    @data = @new_data;
    
}


		
sub process_analysis_meta {

    my (%param) = @_;
	
    my %seen;

    my @new_data;
    my %sample_list;
    # keep only uniq study_name;
	
    my $line = $data[0];

    foreach my $entrez( keys %{ $line } ) {

	# Only need to do this once
	my $total = keys %sample_list;
	next if( $total > 0 );
	
	foreach my $stable( sort keys %{ $line->{ $entrez } } ) {
	    
	    my $sample_id = $mainDB->get_data( -id => 'sample_id',
					       -val => $stable );
	    
	    my $patient_id = $mainDB->get_data( -id => 'sample2patient_id',
						-val => $sample_id );
	    
	    my $study_id = $mainDB->get_data( -id => 'patient2study_id',
					      -val => $patient_id );
	    
	    # don't need sampleId in the key for study level analysis
	    my $akey = sprintf "%s++%s", $study_id, $options{-a};
	    
	    my $analysis_id = $mainDB->get_data( -id => 'analysis_id',
						 -val => $akey );
	    push( @{ $sample_list{ $analysis_id } }, $sample_id );
	    
	    if( exists $seen{ $sample_id } ) {
		$gen->pprint( -tag => "ERROR",
			      -val => "StudyID = $sample_id, seen multiple times. Please correct" );
	    }
	    $seen{ $sample_id } = undef;
	    
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

sub process_analysis_data {

    my (%param) = @_;
	
    my %seen;
    my @new_data;
    my %analysis;


    foreach my $line( @data ) {

	foreach my $entrez( sort keys %{ $line } ) {
	    
	    my @join;
	    
	    foreach my $stable( sort keys %{ $line->{ $entrez } } ) {
		
		my $sample_id = $mainDB->get_data( -id => 'sample_id',
						   -val => $stable );
		
		my $patient_id = $mainDB->get_data( -id => 'sample2patient_id',
						    -val => $sample_id );
		
		my $study_id = $mainDB->get_data( -id => 'patient2study_id',
						  -val => $patient_id );
		
		my $alt = $line->{ $entrez }{ $stable };
		
		# don't need sampleId in the key for study level analysis
		my $akey = sprintf "%s++%s", $study_id, $options{-a};
		
		my $analysis_id = $mainDB->get_data( -id => 'analysis_id',
						     -val => $akey );
		
		$analysis{ $analysis_id }{ $entrez }{ $sample_id } = $alt;
	    }
	}
    }
    
    
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

    foreach my $analysis_id ( sort { $a <=> $b } keys %analysis ) {
	
	foreach my $entrez( sort sort{ $a <=> $b } keys %{ $analysis{ $analysis_id } } ) {
	    # Constrcut comma seperated CNV list 
	    my @join;

	    foreach my $sample_id ( sort{ $a <=> $b } keys %{ $analysis{ $analysis_id }{ $entrez } } ) {
		my $alt = $analysis{ $analysis_id }{ $entrez }{ $sample_id };
		push( @join, $alt );
	    }
	    
	    push( @new_data, { analysis_data => [{ pk => $analysis_id,
						   entrez_gene_id => $entrez,
						   attr_id => 'cnv_sample_list',
						   attr_value => join( ",", @join )
						 }]});
	}
    }

    @data = ();
    @data = @new_data;
}



sub check_data {

    my (%param) = @_;

    if( ! defined $param{ -val } ) {
	
	$gen->pprint( -tag => "ERROR",
		      -val => "$param{ -id } '$param{-ref}' not defined. Please correct to continue $0" )
    }
    
}

sub load_file {
    
    my( %param ) = @_;

    my $total = `more $param{-f} | wc -l`; chomp $total;
    
    open( IN, "<$param{ -f }" ) or die "$param{ -f } : $!\n";
    
    my $header = 0;
    my @header;

    $gen->pprogress_reset( -val => "Loading File : $param{-f }" );

    while(<IN>) {
	
	chomp $_;

	$gen->pprogress( -total => $total, -v => 1 );

	next if( $_ =~ /^#/ );
	
	if( $header == 0 ){

	    @header = split( /\t/, $_ );
	    
	    # conver all the header to lower case to ease coding
	    # but store the origical lower case / upper. we will convert the case back to the original later on
	    for my $idx( 0 .. $#header ) {
		
		my $val = $header[$idx];
		
		if( defined $map{ $options{-f} }{ $val } ) {
		    
		    my $new_val = $map{ $options{-f} }{ $val }{ new_col };
		    
		    $header[$idx] = lc($new_val);
		    
		    $case{ lc($val) } = $new_val;
		    
		}

	    }
	    $header++;
	    next;	    
	}
	
	my %line;

	$_ =~ s/\"//g;

	@line{ @header } = split( /\t/, $_ );
	
	if( exists $line{ cancer_id } ) {
	    
	    # Add Study Specific Information
	    my $cancer_id = $line{cancer_id};
	    $line{cancer_id} = $cancer_id;
	    $line{description} = "$line{cancer_type_detailed} (GENIE)";
	    $line{source} = $options{ -s } . "_" . $options{ -sv };
	    $line{study_name} = lc("${cancer_id}_genie");
	}

	my %new_line;
	
	
	if( $options{-f} =~ /cna/i && $options{-f} =~ /genie/ ) {
	    
	    my $entrez = $mainDB->get_data( -id => 'entrez',
					    -hugo => $line{hugo_gene_symbol});
	    
	    if( $entrez eq 'NA' ) {
		$gen->pprint( -tag => "WARNING",
			      -val => "Skipping entrez, unknown id : '$line{hugo_gene_symbol}'" );
		next;
	    }
	    
	    # Delete all the mapped columns, we only care about the stable_id
	    # HUGO_SYMBOL<-delete     GENIE-34324     GENIE-23434
	    
	    foreach (keys %{ $map{ $options{-f} } } ) {
		my $val = lc( $map{ $options{-f} }{ $_ }{ new_col } );
		delete $line{lc($val)} if( exists $line{ lc($val) } );
	    }
	    
	    $new_line{ $entrez } = \%line;
	    
	    push( @data, \%new_line );
	    
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
    
	
    }
    
    close( IN );
    
    $gen->pprogress_end();
    
}

sub load_header_map {

    $gen->pprint( -val => "Loading map.tsv" );
    
    open( IN, "map.tsv" ) or die "$options{-f}.map : $!\n";
    
    my @header;
    my $header = 0;
    while( <IN> ) {
	
	chomp $_;
	if( $header == 0 ) {
	    @header = split( /\t/, $_ );
	    $header++;
	    next;
	}
	my %line;
	
	@line{ @header } = split( /\t/, $_ );

	my $file = $line{file};
	my $old_col = $line{old_col};
	
	# Dont store these values
	delete $line{file};
	delete $line{old_col};
	
	$line{ new_col } = ( $line{new_col} eq '' ) ? $old_col : $line{new_col};

	my %line1 = %line;
	my %line2 = %line;
	$map{ $file }{ $old_col } = \%line1;
	$map{ $file }{ lc($old_col) } = \%line2;
    }
    
    close( IN );
    
}


