#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Generic;
use Getopt::Long;
use Storable;
use MainDB;
use POSIX;
$| = 1; # Disable output buffering

( $#ARGV > -1 ) || die "

DESCRIPTION:
    
USAGE:

EXAMPLE:

OPTIONS :
   
AUTHOR:
    Alexander Butarbutar (ab\@oncodna.com), OncoDNA
\n\n";

my %options = ( -db => 'maindb_dev' );

GetOptions( 'd'        => \$options{ -d },
	    'dd'        => \$options{ -dd },
	    'ddd'      => \$options{ -ddd },
	    'db=s'     => \$options{ -db },
	    'c'        => \$options{ -c },
	    'v'        => \$options{ -v },
	    'dd'       => \$options{ -dd },
	    't=s'      => \$options{ -table },
	    'io'       => \$options{ -io }
    ) or die "Incorrect Options $0\n";

my $gen = new Generic( %options );


my $mainDB = new MainDB( %options );

my $file = "data_" . $options{-table} . ".txt";

process_file( -file => $file );

sub process_file {

    my( %param
	) = @_;

    my $file = $param{ -file };
    
    open( IN, "<$file" ) or die "$file $!\n";

    my $total = `more $file | wc -l`; chomp $total;
    
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

	process_line( -data => \%line );
	
	$gen->pprogres( -total => $total,
			-v => 1 );
    }
    
    $mainDB->insert_sql( %options );
    
    close( IN );
}

sub process_line {
    my( %param
	) = @_;

    my $data = $param{ -data };
    my $entrez = $data->{ Entrez_Gene_Id };
    my $hugo = $data->{ Hugo_Gene_Symbol };

    if( $hugo =~ /\|/ ) {
	my @line = split( /\|/, $hugo );
	$hugo = $line[0];
    }
    
    delete $data->{ Hugo_Gene_Symbol };
    delete $data->{ Entrez_Gene_Id };

    my @many_sql;
    
    while( my( $key, $val ) = each( %{ $data } ) ) {
	
	my $sid = $mainDB->format_stable_id( %param,
					     -val => $key,
					     -id => 'sample' );

	$mainDB->generate_sql( %options,
			       -data => { 'Sample_Stable_Id' => $sid,
					  'Alteration' => $val,
					  'Entrez_Gene_Id' => $entrez,
					  'Hugo_Gene_Symbol' => $hugo });
    }    
    
}

