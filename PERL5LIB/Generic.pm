package Generic;

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor;
use POSIX;
# use Exporter qw(import);
# our @EXPORT_OK = qw(read_file pprint);

my %options;
my $p_cnt;

sub new {
    my ($class,
	%param)  = @_;

    %options = %param;
    
    my $self = {};

    $p_cnt = 1;
    
    bless $self, $class;

    return $self;
}

sub read_file {

    my ($class,
	%param)  = @_;
    
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
    
    my ($class, %param) = @_;

    my $val = $param{ -val } || "";
    my $time  = `date`; chomp $time;
    my $tag = $param{ -tag } || "INFO";
    my $error = $tag =~ /error/i ? 1 : 0;
    my $stamp = "[$time] [" . uc($tag) ."] ";
    
    # Do nothing
    return() if( defined $param{ -d } && ! defined $options{ -d } );
    return() if( defined $param{ -v } && ! defined $options{ -v } );
    
    if( ! exists $param{ -level } ) {
	
	print color('bold red') if( $error );
	print $stamp;
	print "$val\n";
	print color('reset') if ( $error );
	
    } elsif( $param{ -level } == 0 ) {
	print "$stamp\n";
	print "$stamp" . '-' x 40 . "\n$stamp";
	print "$val\n";
	print "$stamp" . '-' x 40 . "\n";
	print "$stamp\n";
	
    } elsif( $param{ -level } == 1 ) {
	print $stamp;	
	print " -> $param{ -val }\n";

    } else {
	
	my $buffer = " "x ($param{ -level } * 2);
	print $stamp;	
	print "$buffer-> $param{ -val }\n";
    } 
    
    exit if( $tag =~ /error/i );
    
}

sub pprogress_reset {
    $p_cnt = 1;
}

sub pprogres {

    my( $class,
	%param ) = @_;
	
    # Do nothing
    return() if( defined $param{ -d } && ! defined $options{ -d } );
    return() if( defined $param{ -v } && ! defined $options{ -v } );

    my $total = $param{ -total };
    
    $p_cnt++;

    printf "Processing.. %s/%s (%.1f%%)  \r", $p_cnt, $total, (($p_cnt/$total)*100);
}
1;
