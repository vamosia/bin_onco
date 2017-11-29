#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;

my %data;

while( <STDIN>) {
    chomp $_;
    $_ =~ s/  //g;

    my @level;

    while( $_ =~ /<(.+?)>/g ) {

	if( $1 =~ /\// ) {
	    
	} else { 
	    
	    push( @level, $1 );
	}
	
	
	print Dumper \@level;
    }
    exit;
    

    #exit if( $cnt == 3 );
}
