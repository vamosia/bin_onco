#!/usr/bin/perl -w

use Data::Dumper;

use strict;
use warnings;
use lib "/home/ionadmin/bin";

use Data::Dumper;
use Bio::Generic qw(read_file debug );
use Generic qw( pprint );
use Getopt::Long;
use Storable;

my %options;
$options{ -d } = 0;

GetOptions( 'd=s'    => \$options{ -d } 
    ) or die "Incorrect Options $0!\n";

my $file_mut = 'data_mutation_extended.txt';

merge_files( -out => $file_mut );

process_mutation( -in => => $file_mut );

############################################
#
# SUBROUTINE

sub process_mutation {

    my %param = @_;
    
    read_file( -f => $param{ -in } );
    
}


sub merge_files {

    my %param = @_;
    
    pprint( -val => "Merging Files to $param{ -out }" );

    # Remove output if exists
    system( "rm $param{ -out }" ) if( -e $param{ -out } );
    
    open( OUT, ">>$param{ -out }" );

    my $dirname = '.';
    my $check_header = 1;

    opendir(DIR, $dirname) or die "Could not open $dirname\n";

    while (my $filename = readdir(DIR)) {
	
	next if( $filename eq $param{ -out } );
	
	open( IN, "<$filename" );

	while( <IN> ) {

	    chomp $_;

	    # Capture header only once
	    if( $check_header ) {
		
		# Note if '#' is found it will simply print out and not quite
		# only when it encounters Hugo_Symbol will it quit
		
		$check_header = 0 if( $_ =~ /^Hugo_Symbol/ );
		
		print OUT $_,"\n";
		
		next;

	    } else {
		print OUT $_,"\n";
	    }

	    
	}
	
	close( IN );
	

    }

    closedir(DIR);


    close( OUT );

}
