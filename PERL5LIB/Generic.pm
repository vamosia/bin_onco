package Generic;

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor;
use POSIX;
use Text::Unidecode;
# use Exporter qw(import);
# our @EXPORT_OK = qw(read_file pprint);

my %options;
my $p_cnt;

sub new {
    my ($class,
	%param)  = @_;

    %options = %param;
    
    my $self = {};

    $p_cnt = 0;
    
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
    
    open( IN, "<$param{ -file }" ) or die "Generic.pm - $param{-file} : $!\n";

    $delim = "\\|" if( $delim eq "|" );
    $delim = "\\," if( $delim eq "," );

    while( <IN> ) {
	
	chomp $_;
	my $line = unidecode($_);

	$line =~ s/@//g;
	$line =~ s/\///g;

	next if( $line =~ /^#/ );
	
	if( $header == 0 ) {

	    @header = split( /$delim/, $line );

	    $header++;
	    next;
	}

	my %line;

	@line{ @header } = split( /$delim/, $line );

	push( @data, \%line );
    }
    
    close( IN );
    
    return({ header => \@header, data => \@data });
}


sub pprint {

    my ($class, %param) = @_;
    
    return() if( defined $param{ -v } && ! defined $options{ -v } );
    return() if( defined $param{ -d } && ! defined $options{ -d } );
    return() if( defined $param{ -dd } && ! defined $options{ -dd } );
    return() if( defined $param{ -ddd } && ! defined $options{ -ddd } );
    
    
    my $val = $param{ -val } || "";
    # Turns out time stamp is not ideal for processing large / big data.
    # Removing it
    # TODO : figure out a better way to do this
    #my $time  = `date`; chomp $time;
    
    my $tag = $param{ -tag } || ($options{-tag0} || "INFO");
    #my $stamp = "[$time] [" . uc($tag) ."] ";
    my $stamp = "[" . uc($tag) ."] ";
    print color('bold red') if( $tag =~ /error/i );
    print color('bold blue') if( $tag =~ /warning/i );
    

    if( ! exists $param{ -level } ) {
	print $stamp;
	print "$val\n";
	
    } elsif( $param{ -level } == 0 ) {
	
	print "$stamp" . '----' x length($val) . "\n$stamp";
	print "$val\n";
	print "$stamp" . '----' x length($val) . "\n";
	
	
    } elsif( $param{ -level } == 1 ) {
	print $stamp;	
	print " -> $param{ -val }\n";

    } else {
	
	my $buffer = " "x ($param{ -level } * 2);
	print $stamp;	
	print "$buffer-> $param{ -val }\n";
    } 

    print color('reset') if ( $tag =~ /warning/i || $tag =~ /error/i );

    exit if( $tag =~ /error/i );
    
}

sub pprogress_reset {
    my ($class,
	%param ) = @_;

    $p_cnt = 0;
    
    pprint( @_ );
}

sub pprogress_end {
    print "\n" if( $options{-v} );
}

sub pprogress {

    my( $class,
	%param ) = @_;

    

    # Do nothing
    return() if( defined $param{ -d } && ! defined $options{ -d } );
    return() if( defined $param{ -dd } && ! defined $options{ -dd } );
    return() if( defined $param{ -v } && ! defined $options{ -v } );

    my $total = $param{ -total };
    
    $p_cnt++;

    my $tag = $param{ -tag } || "Processing";
    
    printf STDERR "%s.. %s/%s (%.1f%%)        \r", $tag, $p_cnt, $total, (($p_cnt/$total)*100);
 
    
}

sub pivot_file {

    my( $class,
	%param ) = @_;
       
    open( IN, "<$param{-f}" ) or die "$param{-f} : $!\n";

    my %data;
    my $max = 0;
    while( <IN> ) {
	chomp $_;

	my @line = split( /\t/, $_ );
	my $id = shift @line;

	$max = $#line if( $max < $#line );
	
	$data{ $id } = \@line;
    }
    
    close( IN );

    open( OUT, ">$param{-o}" ) or die "$param{-o} : $!\n";
    
    for my $idx ( 0 .. $max ) {

	my @val;
	
	# print header
	if( $idx == 0 ) {

	    my @header;
	    
	    foreach my $id (sort keys %data ) {
		push( @header, $id );
	    }
	    print OUT join( "\t", @header ), "\n";
	}

	# print value
	foreach my $id( sort keys %data ) {
	    push( @val, $data{ $id }[ $idx ] || "NA");
	}
	
	print OUT join( "\t", @val ),"\n";
    }

    
}


1;
