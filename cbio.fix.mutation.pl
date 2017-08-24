#!/usr/bin/perl -w
use strict;
use warnings;
use lib "/home/ionadmin/bin";

use Data::Dumper;
use Bio::Generic qw(read_file debug );
use Bio::Cbioportal;
use Getopt::Long;
use Storable;

my %options;
$options{ -d } = 0;

GetOptions( 'd=s'    => \$options{ -d }
    ) or die "Incorrect Options $0!\n";

#'gene_symbol',
# Hugo_Symbol
my %id = ( 'cbio' => ['entrez_gene_id',
		      'sequencing_center',
		      'case_id',
		      'start_position',
		      'end_position',
		      'amino_acid_change' ],
		      
	   
	   'local' => ['Entrez_Gene_Id',
		       'Center',
		       'Tumor_Sample_Barcode',		       
		       'Start_Position',
		       'End_Position',
		       'HGVSp_Short|MA:protein.change|amino_acid_change|AAChange']);


my $study = `pwd`;
my $cnt = 0;
chomp $study;

$study =~ s/.*\/tcga\/(.*?)\/data_mutations_extended.BAK/$1/;

debug( -id => 'INFO', -val => 'Loading Cbio Data' );

my ($cbio_dat, $cbio_entrez) = load_cbio( -f => 'data_mutations_extended.txt.cbio' );

debug( -id => 'INFO', -val => 'Checking for consistency - data_mutation_extended.txt.fix.entrez.chr' );

my $dup = check_data( -f => 'data_mutations_extended.txt.fix.entrez.chr' );

debug( -id => 'INFO', -val => 'Running VLOOKUP' );


vlookup();


################################################################################################################################
###
### SUBROUTINE
###
################################################################################################################################

sub load_cbio {

    my %param = @_;

    my ($cbio_head, $cbio_mut) = read_file( -f => $param{ -f } );
    
    my (%cbio_dat, %cbio_entrez);
    
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
		    'amino_acid_change',
		    'mutation_type',
		    'gene_symbol' );
	
	foreach ( @rep ) {
	    
	    $cbio_dat{ $id }{ $_ } = $line->{ $_ };
	}
	
	$cbio_dat{ $id }{ cnt }++;
	
	if( $cbio_dat{ $id }{ cnt } > 1 ) {
	    debug( -id => 'DUPLICATE',
		   -val => "CBIOPORTAL $study | $cbio_dat{ $id }{ gene_symbol } | $id" );
	}

	# check to see if all the entrez from cbio was found in local data
	$cbio_entrez{ $line-> { 'entrez_gene_id' } }++
	
	
	
    }
    return( \%cbio_dat, \%cbio_entrez );
}


sub check_data {

    my %param = @_;
    
    # COUNT DUPLICATE
    open( IN, "< $param{ -f }" ) or die "$!\n";

    my @header;
    my %dup;
    my %dup_remove;
    my %loc_entrez;
    
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

	    # AA can be mapped to 'HGVSp_Short|MA:protein.change|amino_acid_change|AAChange']);
	    # check to see which one maps
	    if( $_ =~ /\|/ ) {
		
		my @tag = split( '\|', $_ );
		
		foreach( @tag ) {

		    # Skip if tag doesn't exists
		    next unless( exists( $line{ $_ } ) && defined $line{ $_ } );
		    
		    # Replace p.Y282K to Y282K
		    $line{ $_ } =~ s/p\.//;
		    
		    # Relace Y219X to Y219*
		    $line{ $_ } =~ s/(\d)X$/$1*/g if( $_ eq 'AAChange' && $line{ $_ } =~ /X$/);
		    
		    my $id = join( "+", @id_val ) . '+';
		    $id .= $line{ $_ } || "";

		    # Check to see if this AA tag is correct, if so use it.
		    if (exists $cbio_dat->{ $id } ) {
			print "$id ---> YES $_\n" if ( $options{ -d } == 1 && $_ ne 'HGVSp_Short' );
			push( @id_val, $line{ $_ } );
			last;
		    }
		}
		
	    } else {
		push( @id_val, $line{ $_ } );
	    }
	}

	my $id = join( "+", @id_val );    

	$dup{ $id }{ cnt }++;
	$dup{ $id }{ 'type' }{ $line{ 'Variant_Classification' } }++;
	
	# Count the number of times the local entrez exists
	$loc_entrez{ $line{ 'Entrez_Gene_Id' } }++;
    }
    
    close( IN );

    # if any of the cbio entrez cannot be found on the local file, print warning
    foreach( keys %{ $cbio_entrez } ) {
	
	unless( exists $loc_entrez{ $_ } ) {
	    debug( -id => 'INFO', -val => "  -> CBio Entrez not found in local : $_" );
	}
    }

    # Message for duplicate id
    my $dup_cnt_NA = 0;
    my $dup_cnt = 0;
    foreach my $id ( keys %dup ) {
	
	if( $dup{ $id }{ cnt } > 1 && exists $cbio_dat->{ $id } ) {
	    
	    my $a = $cbio_dat->{ $id }{ 'reference_read_count_tumor' } || "-";
	    my $b = $cbio_dat->{ $id }{ 'reference_read_count_normal' } || "-";
	    my $c = $cbio_dat->{ $id }{ 'variant_read_count_tumor' } || "-";
	    my $d = $cbio_dat->{ $id }{ 'variant_read_count_normal' } || "-";
	    
	    if( $a eq "NA" &&
		$b eq "NA" &&
		$c eq "NA" &&
		$c eq "NA" ) {

		$dup_cnt_NA++;
		
	    } else {
		my $gene = $cbio_dat->{ $id }{ 'gene_symbol' } || "";
		my $type = "";

		foreach( $dup{ $id }{ 'type' } ) {
		    while( my( $key, $val) = each( %{ $_ } ) ) {
			$type .= "$key ($val),";
		    }
		}
		chop $type;

		debug( -id => "DUPLICATE",
		       -val => "LOCAL : $type | $study | $gene |  $a,$b,$c,$d | $id ($dup{ $id }{ cnt })" );
		
		$dup_cnt++;
	    }
	}
    }
    if( $dup_cnt > 0 ) {
	printf "[WARNING] There are $dup_cnt_NA Duplicate ID with all NA\n";
	printf "[WARNING] There are $dup_cnt Duplicate ID with some NA\n";
    }

    return( \%dup );
}


sub vlookup {

    open( IN, "< data_mutations_extended.txt.fix.entrez.chr" ) or die "$!\n";
    open( OUT,"> data_mutations_extended.txt.fix.entrez.chr.refvar" ) or die "$!\n";
    open( NOTFIX,"> data_mutations_extended.txt.fix.entrez.chr.refvar.notfix" ) or die "$!\n";
    
    my @header = ();

    my %fix;
    $cnt = 0;

    while( <IN> ) {

	chomp $_;

	if( $_ =~ /^Hugo_Symbol/ ) {
	    @header = split( /\t/, $_ );

	    # This is required as we're adding a new tag
	    push( @header, 'AAChange_cbio' );
	    
	    print OUT join( "\t", @header ) . "\n";
	    next;
	}
	my @line = split( /\t/, $_ );
	
	my %line;

	@line{ @header } = @line;
        
	my @id_val;
	my $entrez = $line{ 'Entrez_Gene_Id' };

	
	foreach ( @{ $id{ 'local'} } ) {

	    # AA can be mapped to 'HGVSp_Short|MA:protein.change|amino_acid_change|AAChange']);
	    # check to see which one maps
	    if( $_ =~ /\|/ ) {
		
		my @tag = split( '\|', $_ );
		
		foreach( @tag ) {
		    
		    next unless( exists( $line{ $_ } ) && 
				 defined $line{ $_ } );

		    # Replace p.Y282K to Y282K
		    $line{ $_ } =~ s/p\.//;

		    # Relace Y219X to Y219*
		    $line{ $_ } =~ s/(\d)X$/$1*/g if( $_ eq 'AAChange' && $line{ $_ } =~ /X$/);
		    
		    my $id = join( "+", @id_val ) . '+';
		    $id .= $line{ $_ } || "";
		    
		    if (exists $cbio_dat->{ $id } ) {
			
			push( @id_val, $line{ $_ } );

			# Keep tag of this correct AA, also need to add to the header so it prints correctly on the files
			$line{ 'AAChange_cbio' } = $line{ $_ };
			
			goto AAFOUND;
			last;
		    } 
		}
		
	    } else {
		push( @id_val, $line{ $_ } );
		
	    }

	  AAFOUND:
	    
	}
	
	my $id = join( "+", @id_val );
	
	if (exists $cbio_dat->{ $id } ) {
	    
	    my %map = ( 'Reference_Allele' => 'reference_allele',
			'Tumor_Seq_Allele1' => 'variant_allele',
			't_depth' => 'reference_read_count_tumor+variant_read_count_tumor',
			't_ref_count' => 'reference_read_count_tumor',
			't_alt_count' => 'variant_read_count_tumor',
			'n_depth' => 'reference_read_count_normal+variant_read_count_normal',
			'n_ref_count' => 'reference_read_count_normal',
			'n_alt_count' => 'variant_read_count_normal' );

	    my $is_dup = $dup->{ $id }{ cnt } || 0;

	    
	    while ( my( $id_loc, $id_cbio) = each (%map)) {
		
		# if its a duplicate, only change the reference. Becase A32K can be T>A or T>G
		next if( $is_dup > 1 && ($id_cbio =~ /count/ or $id_cbio =~ /variant/) );

		# TODO : if its a duplicate, check whats different, what is the same
		
		# skip if id doesn't exists in local file (i.e see brca file the header is different)
		next if( ! exists $line{ $id_loc } );
		
		my $old_val = $line{ $id_loc };

		my $new_val;

		# if + is entencountered, we need to add these two values
		if( $id_cbio =~ /\+/ ) {
		    
		    my @id_line = split( /\+/, $id_cbio );
		    
		    foreach( @id_line ) {

			if( $cbio_dat->{ $id }{ $_ } eq 'NA' || $cbio_dat->{ $id }{ $_ } eq '') {
			    $new_val = $cbio_dat->{ $id }{ $_ };
			    last;
			    
			} else {
			    $new_val += $cbio_dat->{ $id }{ $_ };
			}
		    }
		    
		} else {
		    $new_val = $cbio_dat->{ $id }{ $id_cbio };
		}

		print "[INFO] $id_loc : $old_val >  $new_val\n" if( $options{ -d } == 1 );

		# Allele counts does not accept NA, will not render correctly
		next if $new_val eq 'NA';
		
		# Replace old values
		$line{ $id_loc } = $new_val;
	    }
	    
	    $fix{ yes }++;
	    
	} else {

	    # This section if for those entry not in CBIO
	    
	    my $a = $line{ 'HGVSp_Short' } || "-";
	    my $b = $line{ 'MA:protein.change' } || "-";
	    my $c = $line{ 'amino_acid_change' } || "-";
	    my $d = $line{ 'AAChange' } || "-";
	    my $varClass = $line{ 'Variant_Classification' };
	    
	    my %ignore = qw(Silent 1 Intron 1 3'UTR 1 3'Flank 1 5'UTR 1 5'Flank 1 IGR 1 RNA 1);

	    
	    if( exists $ignore{ $varClass } ) {
		# variantClass ignored
		$fix{ no_varClass }++;
		print NOTFIX "no_varClass (included) | $varClass | $line{ Hugo_Symbol } | $id ($a,$b,$c,$d)\n";
		
	    } elsif ( ! exists $cbio_entrez->{ $line{ 'Entrez_Gene_Id' } } ) {
		# this entrez_id, doesn't exits in the CBIO file
		$fix{ no_entrez }++;
		print NOTFIX "no_entrez (excluded) | $varClass | $line{ Hugo_Symbol } | $id ($a,$b,$c,$d)\n";
		
		# We actually need to skip this so its not displayed in the web
		# next;
	    } else {

		# this entrez_id, doesn't exits in the CBIO file
		$fix{ no_entrez }++;
		print NOTFIX "ID does not exists | $varClass | $line{ Hugo_Symbol } | $id ($a,$b,$c,$d)\n";
	    }
	}
	
	# Check to see if we can restore the allele counts
	# t_depth = t_ref_count + t_alt_count
	
	if( ! $line{ 't_depth' } =~ /\d/ && 
	    $line{ 't_ref_count' } =~ /\d/ && 
	    $line{ 't_alt_count' } =~ /\d/ ) {
	    
	    $line{ 't_depth' } = $line{ 't_ref_count' } + $line{ 't_alt_count' };
	    
	}
	if( ! $line{ 't_ref_count' } =~ /\d/ && 
	    $line{ 't_depth' } =~ /\d/ && 
	    $line{ 't_alt_count' } =~ /\d/ ) {
	    $line{ 't_ref_count' } = $line{ 't_depth'} - $line{ 't_alt_count' };
	    
	}
	if( ! $line{ 't_alt_count' } =~ /\d/  &&
	    $line{ 't_depth' } =~ /\d/ && $line{ 't_ref_count' } =~ /\d/ ) {
	    $line{ 't_alt_count' } = $line{ 't_depth' } - $line{ 't_ref_count' };
	}
	
	# n_depth = n_ref_count + n_alt_count
	if( ! $line{ 'n_depth' } =~  /\d/ && 
	    $line{ 'n_ref_count' } =~ /\d/ && $line{ 'n_alt_count' } =~ /\d/) {
	    $line{ 'n_depth' } = $line{ 'n_ref_count' } + $line{ 'n_alt_count' };
	}
	if( ! $line{ 'n_ref_count' } =~ /\d/ &&
	    $line{ 'n_depth' } =~ /\d/ && $line{ 'n_alt_count' } =~ /\d/ ) {
	    $line{ 'n_ref_count' } = $line{ 'n_depth'} - $line{ 'n_alt_count'  };
	}

	if( ! $line{ 'n_alt_count' } =~ /\d/ &&
	    $line{ 'n_depth' } =~ /\d/ && $line{ 'n_ref_count' } =~ /\d/ ) {
	    $line{ 'n_alt_count' } = $line{ 'n_depth' } - $line{ 'n_ref_count' };
	}
	
	my $line = "";
	
	foreach( @header ) {
	    
	    $line .= $line{ $_ } || "";
	    $line .= "\t";
	    
	}

	chop $line;
	print OUT $line,"\n";
	$fix{ total }++;

	$cnt++;
	print $cnt,"\r" if( $options{ -d } == 1 );
    }

    print "\n" if( $options{ -d } == 1 );

    my $yes = $fix{ 'yes' } || 0;
    my $no_varClass = $fix{ 'no_varClass' } || 0;
    my $no_entrez  = $fix{ 'no_entrez' } || 0;
    my $no_total = $no_varClass + $no_entrez;
    my $total = $fix{ 'total' } || 0;

    debug( -id => "INFO",
	   -val => "Fixing : refvar ( $yes / $total )" );

    debug( -id => "INFO",
	   -val => "Fixing : refvar - Ignored Total ( $no_total / $total )" );


    debug( -id => "INFO",
	   -val => "  -> Ignored Variant Classification ( $no_varClass / $total )" );

    debug( -id => "INFO",
	   -val => "  -> Ignored Entrez not found in cBio ( $no_entrez / $total )" );
    
    close( IN );
    close( OUT );
    close( NOTFIX );

}
