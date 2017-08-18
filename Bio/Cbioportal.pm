package Bio::Cbioportal;
use strict;
use warnings;
use Data::Dumper;
use lib "/home/ionadmin/bin";
use Bio::Gene;

my $entrez;
my %options;

sub new {
    my ($class, 
	%param ) = @_;


    %options = %param;
    my $self = {};

    bless $self, $class;
    
    return $self;
    
}


sub load_entrez {

    my ($self,
	%param ) = @_;

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

sub map_column {

    my ($self, 
	%param ) = @_;
    
    my $header = 0;
    my @header;
    my %header;
    my $totalNA = 0;
    my $totalFIX = 0;

    
    
    open( IN, "< $param{ -file }" );

    open( OUT, ">$param{ -file }.fix" );
    
    while( <IN> ) {
	chomp $_;
	next if( $_ =~ /^#/ );

	if( $header == 0 ) {

	    @header = split( /\t/, $_ );

	    my $index = 0;
	    foreach( @header ) {
		
		$header{ $_ } = $index;
		$index++;
		
	    }
	    print OUT join( "\t", @header );
	    $header++;
	    next;
	    
	}
	
	my @line = split( /\t/, $_ );
	
	my $id_x = $header{ $param{ '-id' } };
	my $id = $line[ $id_x ];
	
	my $val_x = $header{ $param{ '-val' } };
	my $val = $line[ $val_x ];
	
	if( $val eq 'NA' ) {
	    
	    $totalNA++;
	    
	    if ( exists $param{ -data }->{ $id } ) {

		my $new_val = $param{ -data }->{ $id };
		
		$line[ $val_x ] = $new_val;
		
		if( $options{ -d } ) {
		    print "           ->  [$id] : $val > $new_val\n";
		}

		$totalFIX++;
		
	    }
	}
	print OUT join( "\t", @line );
	print OUT "\n";
    }
    close( IN );
    close( OUT );
    

    printf "%-3d / %-3d : %s\n", $totalNA, $totalFIX, $param{ -file };
    
}

1;
