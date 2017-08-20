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
my %id = ( 'cbio' => ['entrez_gene_id',
		      'case_id',
		      'start_position',
		      'end_position',
		      'amino_acid_change' ],
		      
	   
	   'local' => ['Entrez_Gene_Id',
		       'Tumor_Sample_Barcode',		       
		       'Start_Position',
		       'End_Position',
		       'HGVSp_Short|MA:protein.change|amino_acid_change|AAChange']);

# my $study = `pwd`; 
# chomp $study;
# $study =~ s/.*\/tcga\/(.*?)\/data_mutations_extended.BAK/$1/;

# debug( -t => "id",
#        -id => "INFO",
#        -val => "Study : $study" );

		       

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

my $cbio_dat = load_data_cbio();

# COUNT DUPLICATE
open( IN, "< data_mutations_extended.txt.fix.entrez.chr" ) or die "$!\n";

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
	
	if( $_ =~ /\|/ ) {

	    my @tag = split( '\|', $_ );
	    
	    foreach( @tag ) {

		next unless exists( $line{ $_ } );
		
		$line{ $_ } =~ s/p\.//;
		
		my $id = join( "+", @id_val ) . '+' . $line{ $_ } || "";
		
		if (exists $cbio_dat->{ $id } ) {
		    print "$id ---> YES $_\n" if ( $options{ -d } == 1);
		    push( @id_val, $line{ $_ } );
		    last;
		}
	    }
	    
	} else {
	    push( @id_val, $line{ $_ } );
	}
    }
    my $id = join( "+", @id_val );    

    $dup{ $id }++;
    
}
close( IN );

# Message for duplicate id
my $dup_cnt_NA = 0;
my $dup_cnt = 0;
foreach my $id ( keys %dup ) {
    
    if( $dup{ $id } > 1 && exists $cbio_dat->{ $id } ) {
	
	my $ttotcov = $cbio_dat->{ $id }{ 'reference_read_count_tumor' };
	my $ntotcov = $cbio_dat->{ $id }{ 'reference_read_count_normal' };
	
	my $tvarcov = $cbio_dat->{ $id }{ 'variant_read_count_tumor' };
	my $nvarcov = $cbio_dat->{ $id }{ 'variant_read_count_normal' };
	                                   
	if( $ttotcov eq "NA" &&
	    $tvarcov eq "NA" &&
	    $ntotcov eq "NA" &&
	    $nvarcov eq "NA" ) {
	    
	} else {
	    debug( -id => "DUPLICATE",
		   -val => "LOCAL : $ttotcov, $tvarcov, $ntotcov, $nvarcov | $id ($dup{ $id })" );
	    $dup_cnt++
	}
	
	$dup_cnt_NA++
    }
}

if( $dup_cnt > 0 ) {
    printf "[WARNING] There are $dup_cnt_NA Duplicate ID with NA\n";
    printf "[WARNING] There are $dup_cnt Duplicate ID with no NA\n";
}

open( IN, "< data_mutations_extended.txt.fix.entrez.chr" ) or die "$!\n";
open( OUT,"> data_mutations_extended.txt.fix.entrez.chr.refvar" ) or die "$!\n";
    
@header = ();
my %line_match;

while( <IN> ) {

    chomp $_;

    if( $_ =~ /^Hugo_Symbol/ ) {
	@header = split( /\t/, $_ );

	print OUT join( "\t", @header ) . "\n";

	next;
    }
    my @line = split( /\t/, $_ );
    
    my %line;

    @line{ @header } = @line;
        
    my @id_val;

    
    foreach ( @{ $id{ 'local'} } ) {

	# check to see which aa would work
	if( $_ =~ /\|/ ) {
	    
	    my @tag = split( '\|', $_ );
	    
	    foreach( @tag ) {

		next unless exists( $line{ $_ } );
		
		$line{ $_ } =~ s/p\.//;
		
		my $id = join( "+", @id_val ) . '+' . $line{ $_ } || "";
		
		if (exists $cbio_dat->{ $id } ) {
		    print "$id ---> YES $_\n" if ( $options{ -d } == 1);
		    push( @id_val, $line{ $_ } );
		    last;
		} 
	    }
	    
	} else {
	    push( @id_val, $line{ $_ } );
	}
    }
    
    my $id = join( "+", @id_val );
    
    if (exists $cbio_dat->{ $id } ) {

	# Message for duplicate id
	#if( $dup{ $id } > 1 ) {
        #}

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
	
	while ( my( $id_loc, $id_cbio) = each (%map)) {

	    # skip if id doesn't exists in local file (i.e see brca file the header is different)
	    next if( ! exists $line{ $id_loc } );
	    
	    my $old_val = $line{ $id_loc };

	    my $new_val;

	    if( $id_cbio =~ /\+/ ) {

		my @line = split( /\+/, $id_cbio );
		
		foreach( @line ) {
		    
		    if( $cbio_dat->{ $id }{ $_ } eq 'NA' ) {
			$new_val = 'NA';
			last;
		    } else {
			$new_val += $cbio_dat->{ $id }{ $_ };
		    }
		}
		
	    } else {
		$new_val = $cbio_dat->{ $id }{ $id_cbio };
	    }
	    
	    print "[INFO] $id_loc : $old_val >  $new_val\n" if( $options{ -d } == 1 );
	    
	    $line{ $id_loc } = $new_val;
	    
	    
	}

	$line_match{ yes }++;
	
    } else {
	
	$line_match{ no }++;
	
	#debug( -id => 'NO_MATCH',
	#       -val => $id );
	
    }
    
    my $line;

    foreach( @header ) {
	$line .= $line{ $_ } . "\t";
    }

    chop $line;
    print OUT $line,"\n";
    $line_match{ total }++;
    
}

debug( -id => "INFO",
       -val => "Fixing : refvar ( $line_match{ yes } / $line_match{ total } )" );
 
close( IN );
close( OUT );
