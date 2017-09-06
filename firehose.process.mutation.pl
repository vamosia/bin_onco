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

( $#ARGV > -1 ) || die "

DESCRIPTION:
     Process all the maf files that was downloaded from firehose. This script will merge all maf files from multiple 
     patient into one file. Additional work is also done on ensuring the consistency of the data.

     NOTE : at least one argument is required !
     
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


# Get User Options
my %options = ( -f => 'data_variant.txt',
		-s => 'tcga' );

my $pwd = `pwd`; chomp $pwd;

GetOptions( 's=s'    => \$options{ -s },   # Source
	    'd'      => \$options{ -d },   # Debug
	    'v'      => \$options{ -v },   # Verbose
	    'sm'     => \$options{ -sm }

	    
    ) or die "Incorrect Options $0!\n";

my $merge_file = "$options{ -f }.merge";

# Load specific columns that needs to be remap
my %map = ( 'Tumor_Sample_Barcode' => 'Stable_Sample_Id',
	    'Chromosome' => 'Chr',
	    'NCBI_Build' => 'Genome_Build',
	    'Hugo_Symbol' => 'Hugo_Gene_Symbol',
	    'Reference_Allele' => 'Ref_Allele',
	    'Tumor_Seq_Allele2' => 'Var_Allele',
	    'Start_position' => 'Start_Position',
	    'End_position' => 'End_Position' );

my %header = ( 'variant' => [ 'Tumor_Sample_Barcode',
			      'VarKey',
			      'Hugo_Symbol',
			      'Entrez_Gene_Id',
			      'Chromosome',
			      'Start_position',
			      'End_position',
			      'Reference_Allele',,
			      'Tumor_Seq_Allele1',
			      'Tumor_Seq_Allele2',
			      'NCBI_Build',
			      'Strand' ],

	       'variant_meta' => [ 'VarKey' ],
	       
	       'variant_sample' => [ 'VarKey',
				     'Tumor_Sample_Barcode' ],
	       
	       'variant_sample_meta' => [ 'VarKey',
					  'Tumor_Sample_Barcode',
					  'Matched_Norm_Sample_Barcode',
					  'Center',
					  'Match_Norm_Seq_Allele1',
					  'Match_Norm_Seq_Allele2',
					  'Tumor_Validation_Allele1',
					  'Tumor_Validation_Allele2',
					  'Match_Norm_Validation_Allele1',
					  'Match_Norm_Validation_Allele2',
					  'Verification_Status',
					  'Validation_Status',
					  'Mutation_Status',
					  'Sequencing_Phase',
					  'Sequence_Source',
					  'Validation_Method',
					  'Score',
					  'BAM_file',
					  'Sequencer',
					  'Tumor_Sample_UUID',
					  'Matched_Norm_Sample_UUID',
					  'i_NTotCov',
					  'i_NVarCov',
					  'i_TTotCov',
					  'i_TVarCov',
					  'i_Trna_alt1',
					  'i_Trna_alt2',
					  'i_Trna_ref',
					  'i_Trna_tot',
					  'i_Trna_var' ] );

# Create a hash for var_sample_meta. Needed later on to make sure these values
# are not generated to the variant_meta



my %var_sample_meta = map{ $_ => 1 } @{ $header{ variant_sample_meta } };

my $gen = new Generic( %options );

# Merge the multiple maf from firehose into one file
merge_files() unless( $options{ -sm } );

# Process the merged file
process_mutation();

############################################
#
# SUBROUTINE

sub load_meta_mapping {

    my $file = `echo \$DATAHUB/firehose/maindb.mapping.csv`; chomp $file;
    
    open( IN, "<$file" );
    my $header = 0;
    my @header;
    while( <IN> ) {

	chomp $_;

	if( $header == 0 ) {
	    @header = split( /\t/, $_ );
	    $header++;
	    next;
	}

	my @l = split( /\t/, $_ );
	@map{ @header } = @l;
    }
    
    close( IN );
    
}

=head2 process_mutation

    Function : Process the mutation info from and generate a text file containing the processed results.
               Note : this function utilized the %data hash

    Args     : none
    Usage    : process_mutation()
    Returns  : none

               
=cut

sub process_mutation {
    
    $gen->pprint( -val => "Processing $pwd/$merge_file" );
    

    my $total = `more $merge_file | wc -l`; chomp $total;
    
    my $header = 0;
    my @header;
    my %data;
    my @join;

    my %fh;

    foreach ( keys %header ) {
	# Create file handler
	open( $fh{ $_ }, '>', "data_${_}.txt" ) or die "!\n";

	my @join;

	# For each file handler generate its header
	foreach my $id( @{ $header{ $_ } } ) {
	    
	    my $val = (exists $map{ $id })? $map{ $id } : $id;
	    
	    push( @join, $val);
	}
	
	$fh{$_}->print( join ("\t", @join ) );
	

	# Dont print line break for variant_meta, as we'll need to appeded various header based on the file
	if ($_ =~ /meta/) {
	    $fh{$_}->print( "\t" );
	} else {
	    $fh{$_}->print( "\n" ) ;
	}
    }

    open( IN, "<$merge_file" ) or die "$!\n";
    
    while( <IN> ) {

	chomp $_;

	next if( $_ =~ /^#/ );

	my @join_var_meta;
	my @join_var_sample_meta;
	
	# Process header
	if( $header == 0 ) {
	
	    @header = split( /\t/, $_ );
	    
	    push( @join, "VarKey" );
	    
	    # Map the header as needed
	    foreach( 0 ..$#header ) {

		my $col = $header[$_];
		
		# If it exists in var_sample_meta, means we don't want to print it to var_meta
		next if ( exists $var_sample_meta{ $col } );
				
		push( @{ $header{ variant_meta } }, $col );

		my $val = (exists $map{ $col } ) ? $map{ $col } : $col;
		
		push( @join_var_meta, $val );
		
		# Everything that has "i_" and not already in variant_sample_meta header
		if( $col =~ /^i_/ ) {

		    push( @join_var_sample_meta, $val );
		    
		    push( @{ $header{ variant_sample_meta } }, $col );
		}
	    }
	    
	    # print header for var_meta
	    $fh{ variant_meta }->print( join( "\t", @join_var_meta ) . "\n" );
	    $fh{ variant_sample_meta }->print( join( "\t", @join_var_sample_meta) . "\n" );

	    $header++;
	    
	    next;
	}
	

	# Process non header
	my @line = split( /\t/, $_ );
	
	@data{ @header } = @line;

	# Check for consitency
	my $check = check_fix_data( \%data );

	next if( $check );

	# Fore each header, we will generate its value 
	foreach (keys %header) {
	    my @join;
	    
	    foreach my $id( @{ $header{$_} } ) {
		my $val;
		
		if( $id eq 'VarKey' ) {
		    $val  = sprintf "%s_%s_%s_%s", $data{ Chromosome } || 'NA',
		    $data{ Start_position } || 'NA',
		    $data{ Reference_Allele } || 'NA',
		    $data{ Tumor_Seq_Allele2 } || 'NA';
		    
		} else {
		    
		    $val = (defined $data{ $id } ) ? $data{ $id } : 'NA'
		}
		
		$val =~ s/\"//g;
		
		push( @join, $val );
	    }	
	    $fh{ $_ }->print( join( "\t", @join) . "\n" );
	}
   
	
	# # Generate data_variant.txt
	# foreach my $id( @{ $header{ 'variant' } } ) {
	#     my $val;

	#     # VarKey need to be added, as this is an internal way of looking up
	#     # variants. ex chr1_23231_G_A
	    
	#     if( $id eq 'VarKey' ) {

	# 	$val  = sprintf "%s_%s_%s_%s", $data{ Chromosome } || 'NA',
	# 	                               $data{ Start_position } || 'NA',
	# 	                               $data{ Reference_Allele } || 'NA',
	# 	                               $data{ Tumor_Seq_Allele2 } || 'NA';
		
	#     } else {
	# 	$val = (defined $data{ $id } ) ? $data{ $id } : 'NA'
	#     }
	    
	#     push( @join, $val );
	# }
	
	# $fh{ variant }->print( join( "\t", @join ) . "\n" );
	
	# # Generate data_variant_meta.txt
	# @join = ();
	
	# foreach ( @header ) {
	#     my $val = (defined $data{ $_ } ) ? $data{ $_ } : 'NA';

	#     # Remove quotes
	#     $val =~ s/\"//g;

	#     push( @join, $val );
	# }
	
	# print _META join( "\t", @join ) . "\n";

	# print counters
	$gen->pprogres( -total => $total,
			-v => 1 );
	
    }
    
    print "\n" if( $options{ -v } );
    
    foreach( keys %header ) {
	$fh{ $_ }->close();
    }
}

=head2 map_key

    Function : Rename specific column name
               Specific columns from firehose will have a different terminology compared to the mainDB

    Args     : none
    Usage    : process_mutation()
    Returns  : none

=cut

sub map_key {
    
    my (%param) = @_;

    my $id = $param{ -id };
    
    my $ret = $id;
    
    $ret = $map{ $id } if defined $map{ $id };
    
    return( $ret );
    
}

=head2 process_mutation

    Function : Merge the multiple maf file from firehose and generate a single file
    Args     : none
    Usage    : process_mutation()
    Returns  : none

=cut

sub merge_files {


    $gen->pprint( -val => "Merging File $pwd/$merge_file",
		  -v => 1 );
    
    # Remove output if exists    
    system( "rm $merge_file" ) if( -e $merge_file );
    
    open( OUT, ">>$merge_file" );

    my $dirname = '.';
    
    opendir(DIR, $dirname) or die "Could not open $dirname\n";
    
    my $print_header = 0;
    
    while (my $filename = readdir(DIR)) {
	
	my $header = 0;
	    
	next unless( $filename =~ /.maf.txt/ );
	
	$gen->pprint( -val => "Merging : $filename",
		      -d => 1 );
	
	open( IN, "<$filename" );

	while( <IN> ) {

	    chomp $_;
	    
	    next if( $_ =~ /^#/ );
	    
	    # Print header only once
	    if( $print_header == 0 ) {
		$print_header = 1 if( $_ =~ /^Hugo_Symbol/ );
		print OUT $_,"\n";

	    }	
	    
	    if( $header == 0 ) {
		$header++;
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

    my $ret = 0;
    my $data = $_[0];

    
    # Reference_Allele should always equal Tumor_Seq_Allele1
    #
    # Line Contain
    # Reference_Allele    Tumor_Seq_Allele1    Tumo_Seq_Allele2

    if( $data->{ Reference_Allele } ne $data->{ Tumor_Seq_Allele1 } ) {
	print Dumper $data;
	$gen->pprint( -tag => 'ERROR', 
		      -val => "$data->{ Reference_Allele } != $data->{ Tumor_Seq_Allele1 }" );
    }

    
    # Add GRCh to the number
    # if reference genome contains digits, if not generate an error
    if( $data->{ NCBI_Build } =~ /^\d+$/ ) {
	$data->{ NCBI_Build } = "GRCh" . $data->{ NCBI_Build };
    } else {
	$gen->pprint( -tag => 'ERROR',
		      -val => "NCBI_Build : $data->{ NCBI_Build }" );
    }
    
    # Fix stable id
    # from TCGA-OR-A5KP-10A-01D-A30A-10 to TCGA-OR-A5KP-10
    
    # fix stable sample_id

    my $sid = $data->{ Tumor_Sample_Barcode };
    my @sid = split( /\-/, $sid );
    splice( @sid, -3 );
    $data->{ Tumor_Sample_Barcode } = join( "-", @sid );
    $data->{ Tumor_Sample_Barcode } =~ s/(.*)\w$/$1/;

    # fix Matched_Norm_Sample_Barcode
    $sid = $data->{ Matched_Norm_Sample_Barcode };
    @sid = split( /\-/, $sid );
    splice( @sid, -3 );
    $data->{ Matched_Norm_Sample_Barcode } = join( "-", @sid );

    # Check to see if ENTREZ_GENE_ID is NA, we'll need to skip these
    $ret = 1 if( $data->{ Entrez_Gene_Id } == 0 );
	
    return( $ret );
    
}
