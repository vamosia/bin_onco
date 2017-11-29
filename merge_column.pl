#!/usr/bin/perl -w

use Data::Dumper;

open( IN, "<$ARGV[0]" );

my %data;

while( <IN> ) {
    chomp $_;

    my @line = split( /\t/, $_ );

    @data{ @line } = undef;
}

close( IN );

foreach my $id ( sort keys %data ) {
    my @line = split( /\./, $id );
    #my $last = pop( @line );
    #print "$id\t$last\n";
    print "$id\n";
}
