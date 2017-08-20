#!/usr/bin/perl

use Data::Dumper;
use Getopt::Long;
use Storable;
%options;

GetOptions( "i=s" => \$options{ -i },
	    "f=s" => \$options{ -f } )
    or die ($!);

#print Dumper $options{ -i }

#open( IN, "<$options{-i}" ) or die ($!);

my $geneInfo_cbio = 'home/ionadmin/genome/hg19/cbioportal.gene_info';
my $geneInfo_ncbi = 'home/ionadmin/genome/hg19/Homo_sapiens.gene_info';


sub load_gene_info_cbio {
    
    open( IN, "<$geneInfo_cbio" ) or die ($!);

    $line = 0;
    @header;
    @data;
    %gene_info;
    @gene_info;
    
    while( <IN> ) {
	chomp $_;

	if( $line == 0 ) {
	    @header = split( /[\s\,\t]/, $_ );
	    $line++;
	    next;
	}

	my @line = split( /[\s\,\t]/, $_ );
	
	my $gene = @line[0];
	my $entrez_gene_id = $line[1];
	my $cytoband = $line[2];
	my $chr = $cytoband;
	my $chr = ($chr =~ s/(\d+)\w+/\$1/);

	$gene_info{ $gene }{ chr } = $chr;
	$gene_info{ $gene }{ cytoband } = $cytoband;
	$gene_info{ $gene }{ entrez_gene_id } = $entrez_gene_id;

	push( @gene_info, $gene );
    }

    print "Storing File ...\n";
    
    store \%gene_info, '/tmp/gene.info.cbio.hash.storable';
    store \@gene_info, '/tmp/gene.info.cbio.array.storable';

    close( IN );
}

sub load_gene_info_ncbi {
    
    open( IN, "</$geneInfo_ncbi" ) or die ($!);

    $line = 0;
    @header;
    %gene_info;
    @gene_info;

    while( <IN> ) {
	chomp $_;
	# Header;
	
	if( $line == 0 ) {
	    
	    @header = split( /[\t]/, $_ );
	    $header[0] =~ s/#//;
	    $line++;
	    next;
	}
	
	my @line = split( /[\t]/, $_);
	# 1 - GeneID = entrez_gene_id
	# 2 - Symbol = gene
	# 6 - chromosome
	my $entrez_gene_id = $line[1];
	my $gene = $line[2];
	my $chr = $line[6];

	if( ! exists $gene_info{ $gene } ) {
	    
	    $gene_info{ $gene }{ 'chr' } = $chr;
	    $gene_info{ $gene }{ 'entrez_gene_id' } = $entrez_gene_id;

	} 

	if( ! exists $gene_info{ $gene } ) {
	    print "Gene does not exists\n";
	    print Dumper $gene;
	    print Dumper $gene_info{ $gene };
	    exit;
	}
	if( $gene_info{ $gene }{ chr } eq '' && $chr eq '') {
	    print Dumper $gene;
	    print Dumper $chr;
	    print Dumper $gene_info{ $gene };
	    exit;
	}

	
	    
	
	$gene_info{ $gene }{ cnt }++;
	
    }
    
    print "Storing File ...\n";
    
    store \%gene_info, '/tmp/gene.info.hash.storable';
    store \@gene_info, '/tmp/gene.info.array.storable';

    close( IN );
}

sub fix_file {

    open( IN, "<$options{ -f }" ) or die ($!);
    open( OUT, ">$options{ -f }.fix" ) or die ($!);
    $line = 0;

    my %map = ( 'chromosome' => 'chr',
		'entrez_gene_id' => 'entrez_gene_id',
		'strand' => 'strand' );
   
    @header = undef;
    $gene_index = undef;
    while( <IN> ) {
	chomp $_;
	
	if( $line == 0 ) {
	    @header = split( '\s', $_ );
	    
	    # if header = 0, then this is most likely something like
	    # #version 2.5
	    # we can just skip this
	    
	    if( $#header < 3 ) {
		@header = undef;
		next;
	    }

	    # get Hugo_Symbol index
	    for my $i (0 .. $#header) {
		if( $header[$i] =~ /hugo_symbol/i ) {
		    $gene_index = $i;
		}
	    }

	    # print header to out file
	    print OUT $header[0];
	    for my $i (1 .. $#header ) {
		print OUT "\t$header[$i]";
	    }
	    print OUT "\n";
	    @header = map { lc($_) } @header;
	    $line++;
	    next;
	}
	$_ =~ s/\[Not Available\]/NA/g;
	
	my @line = split( '\s', $_ );
	my $gene = $line[ $gene_index ];
	for my $i ( 0 .. $#header ) {
	    
	    if( $header[$i] =~ /entrez_gene_id/i ||
		$header[$i] =~ /strand/i ||
		$header[$i] =~ /chromosome/i  ) {
#		$header[$i] =~ /reference_allele/i ||
#		$header[$i] =~ /tumor_seq_allele1/i ) {
		
		
		if( $line[$i] == 'NA' ) {

		    $new  = $gene_info{ $gene }{ $map{ $header[$i] } };
		    #print "$gene | $header[$i] : $line[$i] -> $new\n";
		    
		    if( $new eq '' ) {
			#print "[WARNING] New value '$new' is empty\n";
		    } if( $gene_info{ $gene }{ cnt } > 1 ) {
			#print "[ERROR] Gene has multiple entrez\n";
			#exit
		    }
		    $line[$i] = $new;
		    
		}
	    }
	}
	print OUT $line[0];
	for my $i ( 1 .. $#line ) {
	    print OUT "\t$line[$i]";
	}
	print OUT "\n";
    }
    
    close( IN );
    close( OUT );
	  
}
