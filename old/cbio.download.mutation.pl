#!/usr/bin/perl

use Data::Dumper;
use Getopt::Long;
use Bio::Cbioportal;
use Storable;
#%options;
#GetOptions( "i=s" => \$options{ -i },
#	    "f=s" => \$options{ -f } ) or die ($!);

sub download_mutation {

    open( IN, "more data_mutations_extended.txt | grep -e 'Hugo_Symbol' -e '#' -v | awk '{print \$1 }' | sort | uniq |" ) or die ($!);

    
    my $cnt = 0;
    
    %gene;
    @query;

    my $cancerCode = `basename \`pwd\``;
    chomp $cancerCode;

    my $api = "'www.cbioportal.org/public-portal/webservice.do?cmd=getMutationData&case_set_id=${cancerCode}_tcga_all&genetic_profile_id=${cancerCode}_tcga_mutations&gene_list='";
    
    if( $cancerCode =~ /nsclc_tcga_broad_2016/ ) {
	$api = "'www.cbioportal.org/public-portal/webservice.do?cmd=getMutationData&case_set_id=${cancerCode}_all&genetic_profile_id=${cancerCode}_mutations&gene_list='";
    }


    my $query;
    my $length;
    
    while ( <IN> ) {
	
	chomp $_;


	push( @query, uc( $_ ) );	   
	$query = join( ",", @query );
	
	$length = length( $query );
	
	if( $length >= 7600 ) {
	    
	    system( "wget -O data_mutations_extended.txt.cbio.$length.last $api" . $query );
	    @query = ();
	    $query = ();
	    sleep 1;
	}
	
	$cnt++;
    }

    if( $length > 0 ) {
	
	system( "wget -O data_mutations_extended.txt.cbio.$length.last $api" . $query );
	
	sleep 1;
	
	@query = ();
    }
    
    
    close( IN );
}

sub merge_mutation {
    system( "more *cbio*.last | grep '^entrez' > data_mutations_extended.txt.cbio" );
    system( "cat *cbio* > a" );
    system( "more a | grep -e '#' -e '^entrez_gene_id' -v | sort | uniq >> data_mutations_extended.txt.cbio" );
    system( "rm a" );    
}



download_mutation();
merge_mutation();
