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

my $gen = new Generic( %options );

my $merge_file = "tcga_mutations_extended.txt";
    
merge_files() unless( $options{ -sm } );

sub merge_files {

    my $pwd = `pwd`; chomp $pwd;
    
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
