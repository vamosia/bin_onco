package Generic;

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor;
 
use Exporter qw(import);
 
our @EXPORT_OK = qw(read_file pprint);

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub read_file {

    my %param = @_;
    my $delim = $param{ -delim };
    my $header = 0;
    my @header; 
    my @data;
    
    open( IN, "<$param{ -file }" ) or die "$!\n";

    $delim = "\\|" if( $delim eq "|" );
    $delim = "\\," if( $delim eq "," );
    
    while( <IN> ) {
	
	chomp $_;

	next if( $_ =~ /^#/ );
	
	if( $header == 0 ) {

	    @header = split( /$delim/, $_ );

	    $header++;
	    next;
	}

	my @line = split( /$delim/, $_ );

	my %line;

	@line{ @header } = @line;

	
	push( @data, \%line );
    }
    
    close( IN );
    
    return({ header => \@header, data => \@data });
}

sub pprint {
    
    my %param = @_;
    my $tag = $param{ -tag } || "INFO";
    $tag = uc( $tag );

    my $val = $param{ -val } || "";

    my $level = $param{ -level } || 1;
    $level = 1 unless( defined $param{ -level } );

    my $time  = `date`; chomp $time;

    my $error = $tag =~ /error/i ? 1 : 0;

    my $stamp = "[$time] [" . uc($tag) ."] ";

    if( $level eq 0 ) {
	print "$stamp" . '-' x 40 . "\n$stamp";
	
	print "$val\n";
	
	print "$stamp" . '-' x 40 . "\n";
	print "$stamp\n";

    } elsif( $level == 1 ) {

	print color('bold red') if( $error );
	print $stamp;
	print "$val\n";
	print color('reset') if ( $error );
	
    } elsif( $level >= 1 ) {
	
	my $buffer = " "x $level;
	
	print $stamp;	
	print "$buffer -> $param{ -val }\n";
    } 
    
    exit if( $tag =~ /error/i );

}

sub merge_file {

}

1;
