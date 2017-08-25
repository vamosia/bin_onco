package Generic;

use strict;
use warnings;
use Data::Dumper;
 
use Exporter qw(import);
 
our @EXPORT_OK = qw(read_file pprint);

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub read_file {

    #my( $class, 
    #	%param ) = @_;
    my %param = @_;

    my $header = 0;
    my @header;
    my @data;
    
    open( IN, "<$param{ -f }" );

    while( <IN> ) {
	
	chomp $_;

	next if( $_ =~ /^#/ );
	
	if( $header == 0 ) {
	    @header = split( /\t/, $_ );
	    $header++;
	    next;
	}

	my @line = split( /\t/, $_ );

	my %line;

	@line{ @header } = @line;

	push( @data, \%line );
    }
    
    close( IN );

    return( \@header, \@data );
}

sub pprint {
    
    my %param = @_;
    my $tag = $param{ -tag } || "INFO";
    my $val = $param{ -val };
    my $id = $param{ -id };
    my $time  = `date`; chomp $time;

    my $foo = "[$time] [" . uc($tag) ."] ";
    
    unless( exists $param{ -id } ) {

	print $foo;
	print "$val\n";

    } elsif( $id == 0 ) {
	print "$foo" . '-' x 40 . "\n$foo";
	
	print "$val\n";
	
	print "$foo" . '-' x 40 . "\n";
	print "$foo\n";
	
    } elsif( $id >= 1 ) {
	
	my $buffer = " "x $id;
	
	print $foo;	
	print "$buffer -> $param{ -val }\n";
    } 
    
}

sub merge_file {

}

1;
