package Bio::Generic;

use strict;
use warnings;
use Data::Dumper;
 
use Exporter qw(import);
 
our @EXPORT_OK = qw(read_file debug);

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

sub debug {
    
    my %param = @_;

    my $id = uc( $param{ -id } ) || "INFO";
    my $tag = $param{ -t } || "";
    
    if( $tag eq 'id' ) {
	
	print "[$id]" . '-' x 40 . "\n";
	print "[$id] $param{ -val }\n";
	print "[$id]" . '-' x 40 . "\n";
	print "[$id]\n";
	
    } else {
	print "[$id] $param{ -val }\n";
    }
    
}

1;
