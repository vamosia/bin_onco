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
use MainDB;
my %options;

( $#ARGV > -1 ) || die "

DESCRIPTION:
     
USAGE:

EXAMPLE:


OPTIONS :
   
AUTHOR:
    Alexander Butarbutar (ab\@oncodna.com), OncoDNA
\n\n";


GetOptions( 's=s'    => \$options{ -s },   # Source
	    'd'      => \$options{ -d },   # Debug
	    'v'      => \$options{ -v },   # Verbose
	    'sm'     => \$options{ -sm },
	    'db=s'   => \$options{ -db },
	    'dd'     => \$options{ -dd },
	    'ddd'    => \$options{ -ddd } );

my $gen = new Generic( %options );
my $mainDB = new MainDB( %options );

$gen->pprint( -level => 0,
	      -val => "$0" );

my $header = 0;
my @header;
my %map = ( 'Hugo_Symgol' => 'Hugo_Gene_Symbol' );

my %header = ( 'cnv' => [ 'Hugo_Gene_Symbol',
			  'Entrez_Gene_Id',
			  'Alteration'],
    
	       'cnv_sample' => [ 'Hugo_Gene_Symbol',
				 'Entrez_Gene_Id',
				 'Stable_Sample_Id',
				 'Alteration'] );

my %fh;
my %alteration;

process_file( -file => 'data_CNA.txt' );

sub process_file {

    my( %param
	) = @_;

    my $file = $param{ -file };

    my $total = `more $file | wc -l`; chomp $total;
    
    # Create file hander;
    foreach( keys %header ) {
	open( $fh{ $_ }, '>', "data_${_}.txt" ) or die "$1\n";

	my @join;
	
	# For each file handler generate its header
	foreach my $id( @{ $header{ $_ } } ) {
	    
	    my $val = (exists $map{ $id })? $map{ $id } : $id;

	    push( @join, $val);
	}
	
	$fh{$_}->print( join ("\t", @join ) . "\n" );
	
    }
    
    open( IN, "<$file" ) or die ("$\n" );
    
    while( <IN> ) {
	
	chomp $_;
	
	next if( $_  =~ /^\#/ );
    
	if( $header == 0 ) {
	    @header = split( /\t/, $_ );
	    $header++;
	    next;
	}
	my @l = split( /\t/, $_);
	my %line;
	@line{ @header } = @l;

	# Check for consistency
	check_line( -data => \%line );


	my $hugo = $line{ Hugo_Symbol };

	# Convert 'WASIR1|ENSG00000185203.7' > 'WASIR1'
	my @line = split( /\|/, $hugo );

	$hugo = $line[0];
	
	my $entrez = $line{ Entrez_Gene_Id };
	
	foreach my $sid ( keys %line ) {
	    
	    my $alt = $line{ $sid };
	    
	    next if( $sid =~ /hugo_symbol/i || $sid =~ /entrez_gene_id/i );
	    
	    $sid = process_sample_stable_id( -id => $sid );
	    
	    # Generate data_cnv_sample.txt
	    $fh{ cnv_sample }->print( "$hugo\t$entrez\t$sid\t$alt\n" );

	    my $key = "$hugo-$entrez-$alt";
	    
	    # Store entrez /alteration
	    $alteration{ $hugo }{ $entrez }{ alt }{ $alt } = undef;
	}
	$gen->pprogres( -total => $total,
			-v => 1 );
	
    }
    
    print "\n" if( $options{ -v } );
    
    close( IN );
    # Generate data_cnv.txt

    foreach my $hugo ( keys %alteration ) {
	
	foreach my $entrez ( keys %{ $alteration{ $hugo } } ) { 
	    
	    foreach my $alt ( keys %{ $alteration{ $hugo }{ $entrez }{ alt } } ) {
		
		my $valid = $mainDB->get_entrez( -entrez => $entrez,
						 -hugo => $hugo );
		
		next if( ! defined $valid || $valid eq "NA" );
		$entrez = $valid;
		#$fh{ cnv }->print( "$hugo\t$entrez\t$alt\n" );
		$fh{ cnv }->print( "$entrez\t$alt\n" );
	    }
	}
    }
    # Close file handler
    foreach( keys %fh ) {
	$fh{ $_ }->close();
    }
}



sub process_sample_stable_id {
    my (%param
	) = @_;
    
    my $sid = $param{ -id };
    my @sid = split( /\-/, $sid );
    splice( @sid, -3 );
    my $ret  = join( "-", @sid );
    $ret  =~ s/(.*)\w$/$1/;
    return( $sid );

}

sub check_line {

    my (%param
	) = @_;
    
    my $ret = 1;
    my $data = $param{ -data };
    
    # Error message, we should have a hugo
    if( ! defined $data->{ Hugo_Symbol } ) {
	
	$gen->pprint( -tag => 'error',
		      -val => 'Hugo_Symbol not defined' );
	$ret = 0;
    }

    # Error message, we should have a hugo
    if( ! defined $data->{ Entrez_Gene_Id } ) {
	
	$gen->pprint( -tag => 'error',
		      -val => 'Entrez_Gene_Id not defined' );
	$ret = 0;
    }
    
    return( $ret );
}


	    