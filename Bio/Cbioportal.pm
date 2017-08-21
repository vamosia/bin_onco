package Bio::Cbioportal;
use strict;
use warnings;
use Data::Dumper;
use lib "/home/ionadmin/bin";
use Bio::Gene;
use Bio::Generic qw(read_file debug );

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

sub load_file {
    
    my ($self,
	%param ) = @_;
    
    open( IN, "<$param{ -file }" ) or die "$!\n";
    
    
    my $header = 0;
    my @header;
    my %data;
    my $delim = $param{ -delim } || "\t";
    
    while( <IN> ) {
	chomp $_;

	if( $header == 0 ) {
	    
	    @header = split( /$delim/, $_ );
	    $header ++;
	    next;
	}
	
	my @line = split( /$delim/, $_ );
	
	my %line;
	
	@line{ @header } = @line;
		
	
	my $key = $line{ $param{ -id } } || "";
	my $val = $line{ $param{ -val } } || "";

	# Concatenate ID as needed
	if( $param{ -id } =~ /\+/ ) {

	    foreach( split( /\+/, $param{ -id } ) ){
		$key .= $line{ $_ } . "+";
	    }
	    
	    chop $key;
	    
	} 

	if( exists $data{ $key } && $data{ $key } != $val ) {
	    
	    debug( -id => 'WARNING',
		   -val => "$key | $line{ 'gene_symbol' } > Duplicate Source Value $data{ $key } != $val" );
	    
	}
	
	
	$data{ $key } = $val;

	
	
	
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
    my %fix;

    
    open( IN, "< $param{ -file_in }" );

    open( OUT, ">$param{ -file_out }" );

    # initialize fix
    foreach( @{ $param{ -id } } ) {
	my @array = split( ">", $_ );
	$fix{ $array[1] } = 0;
    }

    while( <IN> ) {
	    
	chomp $_;

	next if( $_ =~ /^#/ );

	$_ =~ s/\[Not.Available\]/NA/g;

	if( $header == 0 ) {

	    @header = split( /\t/, $_ );

	    print OUT join( "\t", @header );

	    print OUT "\n";
	    $header++;
	    next;
	    
	}
	
	my @line = split( /\t/, $_ );
	my %line;
	@line{ @header } = @line;


	my $id;
	my $val;

	for my $idx ( 0 .. $#{ $param{ -id } } ) {
	    	    
	    my @key_val = split( />/, $param{ -id }[ $idx ] );
	    
	    # Concatenate ID as needed
	    if( $key_val[0] =~ /\+/ ) {
		
		foreach( split( /\+/, $key_val[0] ) ){
		    
		    $id .= $line{ $_ } . "+";
		}
		
		chop $id;
		
	    } else {
		$id = $line{ $key_val[0] };
	    }
	    
	    $val = $line{ $key_val[1] };
	    
	    if( $val eq 'NA' or $val eq '0') {
		
		$fix{ total }++;

		# If there is a dot on the Entrez name, don't count it probably not valid
		$fix{ total }-- if( ($key_val[0] =~ 'Hugo_Symbol') && $id =~ /\./ );
		
		if ( exists $param{ -data }[ $idx ]->{ $id } ) {
		    
		    $fix{ $key_val[1] }++;
		    
		    my $new_val = $param{ -data }[ $idx ]->{ $id };

		    $line{ $key_val[1] } = $new_val;


		    #if( $key_val[1] eq "Entrez_Gene_Id" ){
		#	print Dumper "$key_val[0] > $key_val[1] | $line{ $key_val[0] } > $line{ $key_val[1] }";
		 #   }
		    

		    # printf "%10s : %s > %s\n", $id, $val, $new_val;
			
	
		    #$totalFIX++;
		    
		}
	    }
	
 	}
	my $p;
	foreach( @header ) {
	    $p .= $line{ $_ } || "";
	    $p .= "\t";
	}
	chomp $p;
	print OUT "$p\n";
    }

    close( IN );
    close( OUT );

    foreach( sort keys %fix ) {
	
	next if $_ =~ /total/;

	my $a = $fix{ $_ } || 0;
	my $b = $fix{ 'total' } || 0;
	
	print "[INFO] Fixing : $_ ( $a / $b )\n";
    }
    
    #debug( -id => 'INFO',
    #-val => "Fixing : $param{ -val } ( $totalFIX / $totalNA )" );

}

1;
