package Bio::Gene;
use strict;
use warnings;
use Data::Dumper;
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub load_entrez {

    my ($class, %param ) = @_;

    open( IN, "<$param{ -file }" );

    my $header = 0;
    my @header;
    my %data;
    while( <IN> ) {
	chomp $_;
	
	if( $header == 0 ) {
	    
	    @header = split( /\t/, $_ );
	    $header ++;
	}
	
	my @line = split( /\t/, $_ );

	$data{ $line[0] } = $line[1];
	
    }
    
    close( IN );
    
    return( \%data );
}
1;
