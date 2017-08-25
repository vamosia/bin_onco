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
    my $id = $param{ -id } || "INFO";
    my $txt = $param{ -txt };
    my $level = $param{ -lv };
    my $time  = `date`; chomp $time;

    my $tag = "[$time] [" . uc($id) ."] ";
    
    my $buffer = " "x$level;
    
    unless( exists $param{ -lv } ) {
	
	print "$tag" . '-' x 40 . "\n$tag";
	
	print "$txt\n";
	
	print "$tag" . '-' x 40 . "\n";
	print "$tag\n";
    } elsif( $level == 1 ) {
	print $tag;
	print "$txt\n";
	
    } else {
	print $tag;
	
	print "$buffer -> $param{ -txt }\n";
    }
    
}

sub counter {
    
}

1;
