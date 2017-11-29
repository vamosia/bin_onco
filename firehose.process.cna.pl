#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;
$| = 1;
my %options;

GetOptions( "d"      => \$options{ -d },
	    "dd"     => \$options{ -dd },
	    "ddd"    => \$options{ -ddd },
	    "db=s"   => \$options{ -db },
	    "v"      => \$options{ -v },
	    "s=s"    => \$options{ -s },
	    "t=s"    => \$options{ -t },
	    "f=s"     => \$options{ -f }
    ) or die "Incorrect Options $!\n";


unless( defined $options{ -db } ) {
    print "-db [Database i.e test2] Required\n"; exit;
}

unless( defined $options{ -s } ) {
    print "-s [STUDY_SOURCE i.e tcga] Required\n"; exit;
}

unless( defined $options{ -t } ) {
    print "-t [TABLE i.e analysis] Required\n"; exit;
} 

my $gen = new Generic( %options );
my $mainDB = new MainDB( %options );

$mainDB->load_dbdata( -table => 'sample' );
$mainDB->load_dbdata( -table => 'cnv' );
$mainDB->load_dbdata( -table => 'gene' );
$mainDB->load_dbdata( -table => 'gene_alias' );
$mainDB->load_dbdata( -table => 'study' );
$mainDB->load_dbdata( -table => 'analysis' );

my $pwd = `pwd`; chomp $pwd;
my $study_name = `basename $pwd`; chomp $study_name;

$study_name = lc( $study_name . "_$options{-s}" );

my $study_id = $mainDB->get_data( -id => 'study_name',
				  -val => $study_name );
$gen->pprint( -level => 0, 
	      -tag => $options{ -t },
	      -val => "Loading CNV data - $study_name" );

if( $options{ -t } eq 'analysis' ) {

    my $analysis_id = $mainDB->get_data( -id => 'analysis_id',
					 -val => "${study_id}++gistic" );
    
    open( OUT,">data_cnv_analysis.tsv" ) or die "$!\n";
    print OUT "$study_id\tnull\tgistic\n";
    close( OUT );
    
} else {
    
    process_file();

}

sub process_file {
    
    my $file = $options{ -f } || "all_thresholded.by_genes.txt";

    my $out = "data_cnv_sample.tsv";
    
    open( IN, "<$file" ) or die "$\n";
    open( CNV_SAMPLE, ">data_cnv_sample.tsv" ) or die "$!\n";
    
    my $total = `more $file | wc -l`; chomp $total;
    my (@header);
    my $header = 0;
    my %data;
    my %seen;
    
    while( <IN> ) {
	chomp $_;

	$gen->pprogres( -total => $total,
			-v =>1 );
	
	next if( $_ =~ /^#/ );

	if( $header == 0 ) {
	    @header = split( /\t/, $_ );


	    foreach my $id ( @header ) {
		
		next if( $id =~ /Gene Symbol/i || $id =~ /Cytoband/i || $id =~ /Locus ID/i );
		
		my @stable = split( /\-/, $id );

		splice( @stable, 0-3);
		
		my $stable = join( "-", @stable );
		
		my $sid = $mainDB->get_data( -id => 'stable_sample_id',
					     -val => $stable );

		# Sample MUST exists
		if( ! defined $sid ) {
		    $gen->pprint( -tag => "ERROR",
				  -val => "SampleID not defined for '$stable'. Please load the samples first" );
		}
		
	    }
	    $header++;
	    next;
	}
	
	
	my %line;
	
	@line{ @header } = split( /\t/, $_ );

	my $hugo = $line{ 'Gene Symbol' };
	
	# TODO : for now we're ignoring genes with | in its name as it tends to be a transcript??
	next if( $hugo =~ /\|/ );

	# TODO : new enterz gene id, needs to be assigned a negative number
	my $entrez = $mainDB->get_entrez( -id => 0,
					  -hugo => $hugo );


	if( (! defined $entrez || $entrez eq 'NA' ) ) {
	    
	    unless( defined $seen{ $entrez } ) {
	
		$gen->pprint( -tag => "WARNING",
			      -val => "Unknown Entrez for gene '$hugo'. Locus Id ( $line{ 'Locus ID' } )",
			      -d => 1 );
		$seen{ $entrez } = undef;
	    }
	    
	    next;
	}

#	# Check to see if the Locus ID (which suppose to be the entrez_id) matches up
#	if( $line{ 'Locus ID' } ne $entrez && $entrez > 0 && $line{ 'Locus ID' } > 0 ) {
#	    $gen->pprint( -tag => "WARNING",
#	 		  -val => "$hugo ($entrez) != Locus ID ($line{ 'Locus ID' })",
#			  -v => 1 );
#	}
	
	while( my( $id, $alt) = each( %line ) ) {
	    
	    next if( $id =~ /Gene Symbol/i || $id =~ /Cytoband/i || $id =~ /Locus ID/i );
	    
	    if( $options{ -t } eq 'cnv_sample' ) {
		next if( $alt eq '-1' || $alt eq '0' || $alt eq '1' );
	    }

	    my @stable = split( /\-/, $id );
		
	    splice( @stable, 0-3);
	    
	    my $stable = join( "-", @stable );
	    
	    my $sid = $mainDB->get_data( -id => 'stable_sample_id',
					 -val => $stable );
	    
	    my $cnv_id = $mainDB->get_data( -id => 'cnv_id',
					    -val => "${entrez}_${alt}" );
	    

	    if( $options{ -t } eq 'cnv_sample' ) {
		
		if( ! defined $cnv_id ) {
		    $gen->pprint( -tag => "ERROR",
				  -val => "CNV ID not defined for ${entrez}_${alt}. Please add to DB to continue" );
		}
		
		print CNV_SAMPLE "$sid\t$cnv_id\n";
		
	    }
	    
	    # $data{ $hugo }{ $stable } = $hugo; # for debugging
	    
	    $data{ $entrez }{ $sid } = $alt;
	    
	}

    }

    close( IN );
    close( CNV_SAMPLE );
    
    my $analysis_id = $mainDB->get_data( -id => 'analysis_id',
					 -val => "${study_id}++gistic" );
    
    # IF we're inserting to CNV_SAMPLE no need to checek for anlaysis IS
    # in fact this may not exists yet;
    if( ! defined $analysis_id ) {
	
	$gen->pprint( -tag => "ERROR",
		      -val => "Analysis ID not found ofr (${study_id}++gistic). Please add analysis to DB to continue" );
    }
    
    if( $options{ -t } eq 'analysis_data' ) {
	open (OUT ," >data_cnv_analysis_data.tsv" ) or die "$!\n";
	open (META," >data_cnv_analysis_meta.tsv" ) or die "$!\n";


	# $data{ entrez } { sample_id }
	# 1. Create a list of sampleID
	# 2. Need to make sure the list of sampleID is the same for all gene
	# 3. Create a list comma seperated values for alteration per sampleID
	my $cnt = 0;
	
	my $alt_cnt; 

	my $sample_list;
	
	foreach my $entrez ( sort keys %data ) {

	    
	    my $alt_list;
	    
	    foreach my $sid ( sort keys %{ $data{ $entrez} } ) {
		
		$sample_list .= "$sid," if( $cnt == 0 );
		
		
		my $alt = $data{ $entrez }{ $sid };

		unless( defined $alt ) {
		    $gen->pprint( -tag => "ERROR",
				  -val => "Alteration not defined for SampleID:$sid - Entrez:$entrez" );
		}
		
		$alt_list .= "$alt,";
	
	    }
	    chop $alt_list;
	    
	    print OUT "$study_id\t$entrez\tgistic_sample_list\t$alt_list\n";
	    	   	
	    $cnt = 1;
	}
	
	chop $sample_list; # remove last comma
	print META "$study_id\tsample_list\t$sample_list\n";
	close( OUT );
	close( META );
    }
}
print "\n" if( $options{ -v } );
__END__
	if( $options{ -t } eq 'analysis_data' ) {

	    open( DATA,">data_cnv_analysis_data.tsv" ) or die "$!\n";

	    
	    my $analysis_id = $mainDB->get_data( -id => 'analysis_id',
						 -val => "${study_id}++gistic" );
	    
	    
	    unless( defined $analysis_id ) {
		$gen->pprint( -tag => "ERROR",
			      -val => "Analysis ID not found ofr (${study_id}++gistic). Please add analysis to DB to continue" );
	    }

	    print META "$analysis_id\tsample_list
	
	# $cnv_list{ cnv_list|sample_list }{ $entrez } = comma seperate cnv alteration
	foreach my $entrez( keys %{ $cnv_list{ cnv_list } } ) {
	    my $name = 'gistic_list';
	    my $val = $cnv_list{ cnv_list }{ $entrez };
	    print DATA "$analysis_id\t$entrez\t$name\t$val\n";
	}
	
	close( DATA );
	close( META );
    }
       
    
    close( IN );
    close( CNV_SAMPLE );
} 


print "\n" if( $options{ -v } );
