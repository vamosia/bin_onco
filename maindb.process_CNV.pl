#!/usr/bin/perl -w

use Data::Dumper;
use strict;
use warnings;
use MainDB;
use Getopt::Long;

my %options;

GetOptions( "d"      => \$options{ -d },
	    "dd"     => \$options{ -dd },
	    "ddd"    => \$options{ -ddd },
	    "db=s"   => \$options{ -db },
	    "v"      => \$options{ -v },
	    "mf=s"   => \$options{ -mf },      # map file path
	    "e"      => \$options{ -e },       # empty, include empty value to metaDB
	    "s=s"    => \$options{ -s },       # source
	    "sv=s"   => \$options{ -sv },      # source version
	    "a=s"    => \$options{ -a },       # analysis name
	    "t=s"    => \$options{ -table },   # Table
	    "f=s"    => \$options{ -f },       # File
	    "c"      => \$options{ -c },       # Copy to DB
	    "tr"     => \$options{ -tr },      # Truncate
	   "tre"    => \$options{ -tre }      # Truncate & Ex
    ) or die "Incorrect Options $0!\n";


my $gen = new Generic( %options );

my $file = sprintf "%s_CNV.txt", $options{-s};

unless( defined $options{ -s } ) {
    $gen->pprint( -tag => "ERROR",
		  -val => "$0 : -s (Source) Required" );
}

my $mainDB = new MainDB( %options );

open( IN, "head -n 1 ${file}.BAK |" ) or die "$! : ${file}.BAK\n";

my %stable;

while(<IN>){
    chomp $_;
    my @line = split( /\t/, $_ );
    #splice( @line, 0,3 );
    
    foreach my $idx ( 0 .. $#line ) {

	next unless( $line[$idx] =~ /^$options{-s}/i );

	my @stable = split( /\-/, $line[$idx] );
	$stable[3] =~ s/(\d+)[A-Z]/$1/g;
	
	# only spice for tcga. for genie keep everything
	splice( @stable, 4) if( $options{-s} eq 'tcga' );

	my $stable = join("-", @stable);
	
	my $sample_id = $mainDB->get_data( -id => 'sample_id',
					   -val => $stable );					   
	next if( ! defined $sample_id );
	
	$stable{ $sample_id } = { stable => $stable,
				  idx => $idx + 1,
				  sample_id => $sample_id };
    }
}


close(IN);

my @sample_list;
my @stable_list;
my @idx;
foreach ( sort { $a <=> $b } keys %stable ) {
    push( @idx, $stable{ $_ }{ idx });
    push( @sample_list, $stable{ $_ }{ sample_id } );
    push( @stable_list, $stable{ $_ }{ stable } );
}

$gen->pprint( -id => "SAMPLE_LIST",
	      -val =>  join( ",", @sample_list ),
	      -d => 1 );
$gen->pprint( -id => "STABLE_LIST",
	      -val =>  join( ",", @stable_list ),
	      -d => 1 );
$gen->pprint( -id => "INDEX_LIST",
	      -val => join( ",", @idx ),
	      -d => 1 );
my $ord;
if( $options{-s} eq 'tcga' ) {
    $ord = q($1"\t"$2"\t"$3"\t");
    
}  elsif( $options{-s} eq 'genie' ) {
    $ord = q($1);
    
} else {
    $gen->pprint( -tag => "ERROR",
		   -val => "Unkown Study" );
}

my $st = qq( awk -F '\t' '{ print $ord }' ${file}.BAK > ${file} );

system( $st );
$ord = undef;

# Divide into 2, sh can't handle long lings (> 14300)
my $div = int( $#idx/2 );

foreach ( 0 .. $#idx ) {
    
    $ord .= q($) . $idx[$_] . q("\t");
    
    if( $_ == $div) {
	$st = qq(awk -F '\t' '{ print $ord }' ${file}.BAK > ${file}.col;
paste ${file} ${file}.col \| column -s \$'\t' -t | sed -e 's/   */\t/g' > a;
mv a ${file};
rm ${file}.col );
	
	system( $st );
	$ord = undef;
    }
}

$st = qq(awk -F '\t' '{ print $ord }' ${file}.BAK > ${file}.col;
paste ${file} ${file}.col \| column -s \$'\t' -t | sed -e 's/   */\t/g' > a;
mv a ${file};
rm ${file}.col );
system( $st );





