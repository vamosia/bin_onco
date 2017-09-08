#!/usr/bin/perl -w

use Data::Dumper;
use utf8;
use strict;
use warnings;
use lib "/home/ionadmin/bin";
use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;
use Text::Unidecode;
$| = 1;

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
my %options = ( -f => 'data_variant.tsv',
		-s => 'tcga' );


GetOptions( 'db=s'   => \$options{ -db },
	    'd'      => \$options{ -d },   # Debug
	    'dd'     => \$options{ -dd },
	    'ddd'    => \$options{ -ddd },
	    't=s'    => \$options{ -t },
	    's=s'    => \$options{ -s },   # Source
	    'v'      => \$options{ -v },   # Verbose
	    'sm'     => \$options{ -sm }
    ) or die "Incorrect Options $0!\n";

unless( defined $options{ -db } ) {
    print "-db Required\n"; exit;
}

unless( defined $options{ -t } ) {
    print" -t Required\n"; exit;
}

my $gen = new Generic( %options );
my $mainDB = new MainDB( %options );
my $pwd = `pwd`; chomp $pwd;
my $merge_file = "data_variant.tsv.merge";
my $table = $options{ -t };
my %data;


$mainDB->load_db_data( -table => 'gene' );
$mainDB->load_db_data( -table => 'gene_alias' );
$mainDB->load_db_data( -table => 'variant' );
$mainDB->load_db_data( -table => 'sample' );



# Load specific columns that needs to be remap
my %map = ( 'Tumor_Sample_Barcode' => 'Stable_Sample_Id',
	    'Chromosome' => 'Chr',
	    'NCBI_Build' => 'Genome_Build',
	    'Hugo_Symbol' => 'Hugo_Gene_Symbol',
	    'Reference_Allele' => 'Ref_Allele',
	    'Tumor_Seq_Allele2' => 'Var_Allele',
	    'Start_position' => 'Start_Position',
	    'End_position' => 'End_Position' );

my %header = ( 'variant' => [ 'VarKey',
			      'Entrez_Gene_Id',
			      'Chromosome',			      
			      'Start_position',
			      'End_position',
			      'Reference_Allele',,
			      'Tumor_Seq_Allele2',
			      'NCBI_Build',
			      'Strand' ],
	       
	       'variant_sample' => [ 'VarKey',
				     'Tumor_Sample_Barcode' ],

	       'variant_meta' => [ 'VarKey' ],
	       
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
					  'Other_Transcripts',
					  # BLCA
					  'i_t_alt_count_full',
					  'i_t_ref_count_full',
					  'pox_cutoff',
					  't_alt_count',
					  't_ref_count',
					  
					  
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


# Merge the multiple maf from firehose into one file
merge_files() unless( $options{ -sm } );

# Process the merged file
process_mutation();

    

############################################
#
# SUBROUTINE

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

    open( OUT, ">data_$options{-t}.tsv" ) or die "!\n";
    open( IN, "<$merge_file" ) or die "$!\n";

    # variant header
    my %header_v = map{ $_ => undef } @{ $header{ variant} };

    # variant_sample_header
    my %header_vsm = map{ $_ => undef } @{ $header{ variant_sample_meta} };
    
    
    while( <IN> ) {

	chomp $_;

	next if( $_ =~ /^#/ );

	my @join_var_meta;
	my @join_var_sample_meta;
	
	# Need to store the header to generate meta file
	if( $header == 0 ) {
	
	    @header = split( /\t/, $_ );

	    push( @join, "VarKey" );
	    
	    # Map the header as needed
	    foreach( 0 ..$#header ) {
		
		my $col = $header[$_];

		if( $table eq 'variant_meta' ) {
		
		    # Skip header from variant table or variant_sampleMeta
		    next if( exists $header_v{ $col } ||
			     exists $header_vsm{ $col } ||
			     $col eq 'Hugo_Symbol' );
		    
			push( @{ $header{ variant_meta } }, $col );
		    
		    my $val = (exists $map{ $col } ) ? $map{ $col } : $col;
		    
		    push( @join_var_meta, $val );
		}

		if ($table eq 'variant_sample_meta' ) {
		    
#		    # Everything that has "i_" and not already in variant_sample_meta header
#		    if( $col =~ /^i_/ ) {
#			
#			push( @join_var_sample_meta, $val );
#			
#			push( @{ $header{ variant_sample_meta } }, $col );
#		    }
		}
	    }

	    # print header for var_meta
	    #$fh{ variant_meta }->print( join( "\t", @join_var_meta ) . "\n" );
	    #$fh{ variant_sample_meta }->print( join( "\t", @join_var_sample_meta) . "\n" );
	    $header++;
	    
	    next;
	}

	# Process non header
	my %line;
	@line{ @header } = split( /\t/, $_ );
	my @l = split( /\t/, $_ );

	# Check for consitency
	my $check = check_fix_line( \%line );

	next if( $check );

	my $varkey  = sprintf "%s_%s_%s_%s", $line{ Chromosome } || 'NA',
	                                     $line{ Start_position } || 'NA',
	                                     $line{ Reference_Allele } || 'NA',
	                                     $line{ Tumor_Seq_Allele2 } || 'NA';

	my (@join, $variant_id, $sid);

	if( $table ne 'variant' ) {
	    
	    $variant_id = $mainDB->get_data( -id => 'varkey',
					     -val => $varkey );
	    unless( defined $variant_id ) {
		$gen->pprint( -tag => "ERROR",
			      -val => "VarKey ($varkey) not yet defined in DB" );
	    }
	    
	    $sid = $mainDB->get_data( -id => 'stable_sample_id',
				      -val => $line{ Tumor_Sample_Barcode } );
							  
	}

	if( $table eq 'variant_meta') {
	    $data{ $table }{ $variant_id } = $_;

	} elsif( $table eq 'variant' ) {
	    foreach my $id( @{ $header{ $table } } ) {

		my $val = $line{ $id };

		$val = 'null' unless( defined $val );
		
		$val =~ s/\"//g;

		if( $id =~ /varkey/i ) {
		    $val = $varkey;
		} elsif( $id =~ /tumor_sample_barcode/i ) {
		    $val = $sid;
		}
		
		if( $table eq 'variant') {
		    
		    # VarKey is actually the hash key don't need it
		    next if( $id =~ /varkey/i );
		    
		    # store to array > then to hash to avoid duplicate
		    push( @join, $val );		
		    
		}
	    }
	    
	    # Store to hash to avoid duplicates;
	    $data{ $table }{ $varkey } = join( "\t", @join );
	    
	} elsif( $table eq 'variant_sample' ) {
	    
	    print OUT "$sid\t$variant_id\n";
	}	    
	       
	# print counters
	$gen->pprogres( -total => $total,
			-v => 1 );
    }
    
    print "\n" if( $options{ -v } );

    $gen->pprint( -val => "Printing to disk" );
    
    $total = keys %{ $data{ $table } };
    
    $gen->pprogres_reset();
    
    if( $table eq 'variant' ) {
	
	while( my( $var_key, $value ) = each ( %{ $data{ $table } } ) ) {
	    
	    print OUT "$var_key\t$value\n";
	    
	    $gen->pprogres( -total => $total,
			    -v => 1 );
	}
	
    } elsif( $table eq 'variant_meta' ) {
	
	while( my( $variant_id, $line ) = each ( %{ $data{ $table } } )) {
	    
	    $gen->pprogres( -total => $total,
			    -v => 1 );
	    
	    my @line = split( /\t/, $line );
	    
	    foreach my $idx (0 .. $#header ) {
		
		my $col = $header[$idx];
		my $val = $line[$idx];
		
		# Skip header from variant table or variant_sampleMeta
		next if( ! defined $val ||
			 $val eq '' ||
			 exists $header_v{ $col } ||
			 exists $header_vsm{ $col } ||
			 $col eq 'Hugo_Symbol' );
		
		$val =~ s/\'/\'\'/g;
		$val =~ s/\"//g;
		$val =~ s/Marinesco-Sj.gren_syndrome/Marinesco-Sjogren_syndrome/g;
		$val =~ tr/ö/o/s;
		$val =~ tr/é/e/s;
		# icon': iconv -f ISO-8859-1 -t UTF-8 data_variant.tsv.merge 
		print OUT unidecode("$variant_id\t$col\t$val\n");
	    }
	}
    }
    
    print "\n" if ( $options{ -v } );
    
    close( OUT );
    close( IN );
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
    }
    
    closedir(DIR);
    close( IN );
    close( OUT );

}

# REturn 1 to skip
sub check_fix_line {

    my $ret = 0;
    my $line = $_[0];

    
    # Reference_Allele should always equal Tumor_Seq_Allele1
    #
    # Line Contain
    # Reference_Allele    Tumor_Seq_Allele1    Tumo_Seq_Allele2
    if( $line->{ Reference_Allele } ne $line->{ Tumor_Seq_Allele1 } ) {

	$gen->pprint( -tag => 'ERROR', 
		      -val => "Inconsistency Allele : $line->{ Reference_Allele } != $line->{ Tumor_Seq_Allele1 }" );
    }
    
    if( defined $line->{ i_entrez_gene_id } &&
	defined $line->{ i_Entrez_Gene_Id} &&
	$line->{ i_entrez_gene_id } ne "" &&
	( $line->{ i_entrez_gene_id } ne $line->{ i_Entrez_Gene_Id }) ) {

	$gen->pprint( -tag => 'WARNING',
		      -val => "Inconsistency Entrez : ($line->{ Hugo_Symbol }) $line->{ i_Entrez_Gene_Id } != $line->{ i_entrez_gene_id }",
		      -d => 1 );
  
    }
    
    # ADD GRCh to the number
    # if reference genome contains digits, if not generate an error
    if( $line->{ NCBI_Build } =~ /^\d+$/ ) {
	$line->{ NCBI_Build } = "GRCh" . $line->{ NCBI_Build };
    } else {
	$gen->pprint( -tag => 'ERROR',
		      -val => "NCBI_Build : $line->{ NCBI_Build }" );
    }
    
    # FIX stable id
    # from TCGA-OR-A5KP-10A-01D-A30A-10 to TCGA-OR-A5KP-10
    my $sid = $line->{ Tumor_Sample_Barcode };
    my @sid = split( /\-/, $sid );
    splice( @sid, 4 );
    $line->{ Tumor_Sample_Barcode } = join( "-", @sid );

    # FIX Matched_Norm_Sample_Barcode
    $sid = $line->{ Matched_Norm_Sample_Barcode };
    @sid = split( /\-/, $sid );
    splice( @sid, 4 );
    $line->{ Matched_Norm_Sample_Barcode } = join( "-", @sid );
    

    # CHECK entrez_gene_id == i_Entrez_Gene_Id
    if( $line->{ Entrez_Gene_Id } != $line->{ i_Entrez_Gene_Id } ) {
	
	my $msg = sprintf "Inconsistency : 'Entrez_Gene_Id' != 'i_Entrez_Gene_Id' : (%s %s != %s)",
	                  $line->{ Hugo_Symbol },
	                  $line->{ Entrez_Gene_Id },
	                  $line->{ i_Entrez_Gene_Id };
	
	$gen->pprint( -val => $msg,
		      -tag => "WARNING",
		      -dd => 1 );
    }
    
    
    # CHECK entrez_gene_id
    if( ! defined $line->{ Entrez_Gene_Id } || $line->{ Entrez_Gene_Id } == 0 ) {

	$ret = 1;

    } else {
	
	my $entrez = $mainDB->get_entrez( -entrez => $line->{ Entrez_Gene_Id },
					  -hugo => $line->{ Hugo_Symbol } );

	if( $entrez eq 'NA' ) {
	    
	    $gen->pprint( -tag => "WARNING",
			  -val => "Unknown Entrez $line->{Hugo_Symbol} ($line->{Entrez_Gene_Id})" );
	    $ret = 1;
	} else {
	    
	    if( $entrez ne $line->{ Entrez_Gene_Id } ) {
		
		my $hugo = $mainDB->get_hugo( -entrez => $entrez,
					      -hugo => $line->{ Hugo_Symbol } );
		
		$gen->pprint( -tag => "ENTREZ_MAP",
			      -val => "$line->{Hugo_Symbol} ($line->{Entrez_Gene_Id}) > $hugo ($entrez)" );

		$line->{ Entrez_Gene_Id } = $entrez;
		
		$line->{ Hugo_Gene_Symbol } = $hugo;
		
	    }
	}
    }

    return( $ret  );
}

