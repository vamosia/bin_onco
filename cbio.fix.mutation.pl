#!/usr/bin/perl -w
use strict;
use warnings;
use lib "/home/ionadmin/bin";
use Data::Dumper;
use Bio::Generic qw(read_file debug );
use Bio::Cbioportal;
use Getopt::Long;

my %options;
$options{ -d } = 0;

GetOptions( 'd=s'    => \$options{ -d }
    ) or die "Incorrect Options $0!\n";

#'gene_symbol',
# Hugo_Symbol
my %id = ( 'cbio' => ['case_id',
		      'entrez_gene_id',
		      'chr',
		      'start_position',
		      'end_position',
		      'mutation_type' ],
	   
	   'local' => ['Tumor_Sample_Barcode',
		       'Entrez_Gene_Id',
		       'Chromosome',
		       'Start_Position',
		       'End_Position',
		       'Variant_Classification' ] );


sub load_data_cbio {
    
    my ($cbio_head, $cbio_mut) = read_file( -f => 'data_mutations_extended.txt.cbio' );
    
    my %cbio_dat;

    # FIX REF / COUNT
    foreach my $line ( @{ $cbio_mut } ) {
	
	# Create the variant id that's generic enough such that it can be mapped
	# between cbioportal and local
	# 'gene_symbol',
	
	my @id_val;

	foreach ( @{ $id{ 'cbio' } } ) {
	    push( @id_val, $line->{ $_ } );
	}
	my $id = join( "+", @id_val );

	# these are the values we wish to replace... so store it
	
	my @rep = ( 'reference_allele',
		    'variant_allele',
		    'variant_read_count_normal',
		    'variant_read_count_tumor',
		    'reference_read_count_normal',
		    'reference_read_count_tumor',
		    'entrez_gene_id',
		    'amino_acid_change' );
	
	foreach ( @rep ) {
	    
	    $cbio_dat{ $id }{ $_ } = $line->{ $_ };
	}
	
	$cbio_dat{ $id }{ cnt }++;
	
	if( $cbio_dat{ $id }{ cnt } > 1 ) {
	    debug( -id => 'DUPLICATE',
		   -val => "CBIOPORTAL $id" );
	}
	
    }

	return( \%cbio_dat );
}


sub fix_entrez {

    my $cbio = new Bio::Cbioportal;
    
    my $entrez = $cbio->load_entrez( -file => 'data_mutations_extended.txt.cbio',
				     -id => 2,
				     -val => 1 );
    
    my @files = ( 'data_mutations_extended.txt' );
    
    foreach my $file ( @files ) {
	
	$cbio->map_column( -id => 'Hugo_Symbol',
			   -val => 'Entrez_Gene_Id',
			   -file => $file,
			   -data => $entrez );
    }    
}

my $cbio_dat = load_data_cbio();

fix_entrez();


# COUNT DUPLICATE
open( IN, "< data_mutations_extended.txt.fix.entrez" ) or die "$!\n";

my @header;
my %dup;

while( <IN> ) {
    
    chomp $_;

    if( $_ =~ /^Hugo_Symbol/ ) {
	
	@header = split( /\t/, $_ );

	next;
    }
    
    my @line = split( /\t/, $_ );
    
    my %line;

    @line{ @header } = @line;
        
    my @id_val;
    
    foreach ( @{ $id{ 'local'} } ) {
	
	push( @id_val, $line{ $_ } );
    }
    
    my $id = join( "+", @id_val );

    $dup{ $id }++;

    
}
close( IN );

# Message for duplicate id
my $dup_cnt = 0;
foreach( keys %dup ) {
    $dup_cnt++ if( $dup{ $_ } > 1 );
}

if( $dup_cnt > 0 ) {
    printf "[WARNING] There are $dup_cnt Duplicate ID\n";
}

open( IN, "< data_mutations_extended.txt.fix.entrez" ) or die "$!\n";
open( OUT,"> data_mutations_extended.txt.fix.entrez.ref.var" ) or die "$!\n";
    
@header = ();

while( <IN> ) {

    chomp $_;

    if( $_ =~ /^Hugo_Symbol/ ) {
	@header = split( /\t/, $_ );

	print OUT join( "\t", @header ) . "\n";

	next;
    }
    
    $_ =~ s/\[Not Available\]/NA/g;
       
    my @line = split( /\t/, $_ );
    
    my %line;

    @line{ @header } = @line;
        
    my @id_val;
    
    foreach ( @{ $id{ 'local'} } ) {
	
	push( @id_val, $line{ $_ } );
    }
    
    my $id = join( "+", @id_val );

        
    if (exists $cbio_dat->{ $id } ) {
	
	print "[INFO] ID : $id\n" if( $options{ -d } == 1 );

	# Check AA
	if( $cbio_dat->{ $id }{ 'amino_acid_change' } eq "" ) {
	    print "TEST\n";
	}

	
	if( ! "p." . $cbio_dat->{ $id }{ 'amino_acid_change' } eq $line{ 'HGVSp_Short' } ) {
	    print Dumper $cbio_dat->{ $id }{ 'amino_acid_change' } . " > " . $line{ 'HGVSp_Short' };
	    print "[WARNING] : $line{ 'HGVSp_Short' } != $cbio_dat->{ $id }{ 'amino_acid_change' }\n";
	}
	    
	my %map = ( 'Reference_Allele' => 'reference_allele',
		    'Tumor_Seq_Allele1' => 'variant_allele',
		    'ttotcov' => 'reference_read_count_tumor+variant_read_count_tumor',
		    'tvarcov' => 'variant_read_count_tumor',
		    'ntotcov' => 'reference_read_count_normal',
		    'nvarcov' => 'variant_read_count_normal',
		    'TToTcov' => 'reference_read_count_tumor+variant_read_count_tumor',
		    'TVarCov' => 'variant_read_count_tumor',
		    'NTotCov' => 'reference_read_count_normal',
		    'NVarCov' => 'variant_read_count_normal' );
	
	while ( my( $id_src, $id_loc) = each (%map)) {

	    # Message for duplicate id
	    # if( $dup{ $id } > 1 ) {
	    # 	print "[DUPLICATE] LOCAL : $id ($dup{ $id })\n";
	    # }

	    # skip if id doesn't exists in local file (i.e see brca file the header is different)
	    next if( ! exists $line{ $id_loc } );
	    
	    my $old_val = $line{ $id_src };

	    my $new_val;
	    
	    if( $id_loc =~ /\+/ ) {

		my @line = split( /\+/, $id_loc );

		foreach( @line ) {
		    if( $cbio_dat->{ $id }{ $_ } eq 'NA' ) {
			$new_val = 'NA';
			last;
		    } else {
			$new_val += $cbio_dat->{ $id }{ $_ };
		    }
		}
		
	    } else {
		$new_val = $cbio_dat->{ $id }{ $id_loc };
	    }
	    
	    print "[INFO] $id_src : $old_val >  $new_val\n" if( $options{ -d } == 1 );

	    $line{ $id_src } = $new_val;
	    
	}
	
	print "[INFO]\n" if( $options{ -d } == 1 );
    }
    

    my $line;

    foreach( @header ) {
	$line .= $line{ $_ } . "\t";
    }

    chop $line;
    print OUT $line,"\n";
    
}


close( IN );
close( OUT );
