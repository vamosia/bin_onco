#!/usr/bin/perl -w

use Data::Dumper;

use strict;
use warnings;
use lib "/home/ionadmin/bin";

use Data::Dumper;
use Bio::Generic qw(read_file debug );
use Generic;
use Getopt::Long;
use Storable;

my %options = ( -f => 'data_variant.txt',
		-s => 'tcga' );

GetOptions( 's=s'    => \$options{ -s },   # Source
	    'd'      => \$options{ -d },   # Debug
	    'v'      => \$options{ -v },   # Verbose 
	    'f=s'    => \$options{ -f },
	    
    ) or die "Incorrect Options $0!\n";

my $merge_file = "$options{ -f }.merge";

my %map_key = ( 'Tumor_Sample_Barcode' => 'stable_sample_id',
		'Matched_Norm_Sample_Barcode' => 'stable_match_norm_sample_id',
		'Reference_Allele' => 'ref_allele',
		'Tumor_Seq_Allele2' => 'var_allele',
		'Chromosome' => 'chr',
		'Strand' => 'strand',
		'Start_position' => 'start_position',
		'End_position' => 'end_position',
		'NCBI_Build' => 'ref_genome_build',
		'Entrez_Gene_Id' => 'entrez_gene_id' );


my %header = ( 'variant' => [ 'stable_sample_id', 
			      'Hugo_Symbol',            # Optional
			      'entrez_gene_id',
			      'VarKey',
			      'Protein_Change',         # Optional
			      'Variant_Classification', # Optional
			      'chr',
			      'start_position',
			      'end_position',
			      'ref_allele',
			      'var_allele',
			      'ref_genome_build',
			      'strand' ] );

my $gen = new Generic( -d => $options{ -d },
		       -v => $options{ -v } );
#merge_files();

process_mutation();

############################################
#
# SUBROUTINE

sub process_mutation {
    
    $gen->pprint( -val => "Processing $merge_file" );
    
    
    open( IN, "<$merge_file" ) or die "$!\n";

    my $header = 0;
    my @header;
    my %data;
    my @join;
    

    open( VAR_META, ">data_variant_meta.txt" );
    open( VAR, ">data_variant.txt" );

    # print header for data_variant.txt
    foreach my $id( @{ $header{ 'variant' } } ) {
	push( @join, uc($id) );

    }

    print VAR join ("\t", @join ) . "\n";
    
    my $cnt = 0;
    while( <IN> ) {
	chomp $_;

	next if( $_ =~ /^#/ );

	@join = ();

	# Process header
	if( $header == 0 ) {
	
	    @header = split( /\t/, $_ );
	    
	    # Map the header as needed
	    foreach( 0 ..$#header ) {
		$header[$_] = map_key( -id => $header[$_] );
		
		push( @join, $header[$_] );
	    }
	    # print header for var_meta
	    print VAR_META join( "\t", @join ) . "\n";

	    $header++;
	    
	    next;
	}

	# Process non header
	my @line = split( /\t/, $_ );
	
	@data{ @header } = @line;

	# Check for consitency
	check_fix_data( \%data );
	
	@join = ();
	
	# Generate data_variant.txt
	foreach my $id( @{ $header{ 'variant' } } ) {
	    my $val;

	    # VarKey need to be added, as this is an internal way of looking up
	    # variants. ex chr1_23231_G_A
	    
	    if( $id eq 'VarKey' ) {
		
		$val  = sprintf "%s_%s_%s_%s", $data{ chr } || 'NA',
		                               $data{ start_position } || 'NA',
		                               $data{ ref_allele } || 'NA',
		                               $data{ var_allele } || 'NA';
		
	    } else {
		$val = $data{ $id } || "NA";
	    }
	    
	    push( @join, $val );
	}

	print VAR join( "\t", @join ) . "\n";

	# Generate data_variant_meta.txt
	@join = ();
	
	push( @join, $data{ $_ } ) foreach ( @header );
	
	print VAR_META join( "\t", @join ) . "\n";

	# print counters
	print "$cnt\r" if( $options{ -v } );

	$cnt++;
    }
    print "\n" if( $options{ -v } );



    close( IN );
    close( VAR );
    close( VAR_META );
}


sub map_key {
    
    my (%param) = @_;

    my $id = $param{ -id };
    
    my $ret = $id;
    
    $ret = $map_key{ $id } if defined $map_key{ $id };
    
    return( $ret );
    
}


sub merge_files {
    
    $gen->pprint( -val => "Merging Files to $merge_file" );

    # Remove output if exists
    
    system( "rm $merge_file" ) if( -e $merge_file );
    
    open( OUT, ">>$merge_file" );

    my $dirname = '.';
    my $check_header = 1;

    opendir(DIR, $dirname) or die "Could not open $dirname\n";

    while (my $filename = readdir(DIR)) {

	next unless( $filename =~ /.maf.txt/ );
	
	$gen->pprint( -val => "Processing : $filename" );
	
	open( IN, "<$filename" );

	while( <IN> ) {

	    chomp $_;

	    # Capture header only once
	    if( $check_header ) {
		
		# Note if '#' is found it will simply print out and not quite
		# only when it encounters Hugo_Symbol will it quit
		
		$check_header = 0 if( $_ =~ /^Hugo_Symbol/ );
		
		print OUT $_,"\n";
		
		next;

	    } else {
		print OUT $_,"\n";
	    }

	    
	}
	
	close( IN );
	

    }

    closedir(DIR);


    close( OUT );

}

sub check_fix_data {

    my $data = $_[0];

    
    # Reference_Allele should always equal Tumor_Seq_Allele1
    #
    # Line Contain
    # Reference_Allele    Tumor_Seq_Allele1    Tumo_Seq_Allele2

    if( $data->{ ref_allele } ne $data->{ Tumor_Seq_Allele1 } ) {
	$gen->pprint( -tag => 'ERROR', -val => "$data->{ Reference_Allele } != $data->{ Tumor_Seq_Allele }" );
    }

    
    # Add GRCh to the number
    # if reference genome contains digits, if not generate an error
    if( $data->{ ref_genome_build } =~ /^\d+$/ ) {
	$data->{ ref_genome_build } = "GRCh" . $data->{ ref_genome_build };
    } else {
	$gen->pprint( -tag => 'ERROR', -val => "ref_genome_build : $data->{ ref_genome_build }" );
    }
    
    # Fix stable id
    # from TCGA-OR-A5KP-10A-01D-A30A-10 to TCGA-OR-A5KP-10A
    
    # fix stable sample_id
    my $sid = $data->{ stable_sample_id };
    my @sid = split( /\-/, $sid );
    splice( @sid, -3 );
    $data->{ stable_sample_id } = join( "-", @sid );
    
    # fix stable_match_norm_sample_id
    $sid = $data->{ stable_match_norm_sample_id };
    @sid = split( /\-/, $sid );
    splice( @sid, -3 );
    $data->{ stable_match_norm_sample_id } = join( "-", @sid );

}
