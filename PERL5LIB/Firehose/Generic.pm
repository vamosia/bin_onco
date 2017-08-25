package Firehose::Generic;

use strict;
use warnings;
use Data::Dumper;
 
use Exporter qw(import);
 
our @EXPORT_OK = qw(get_study_code);

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub get_study_code {

    my @code = qw( ACC BLCA BRCA CESC CHOL COADREAD COAD DLBC ESCA FPPP GBMLGG GBM HNSC KICH KIPAN KIRC KIRP LAML LGG LIHC LUAD LUSC MESO OV PAAD PCPG PRAD READ SARC SKCM STAD STES TGCT THCA THYM UCEC UCS UVM );
    
    return( \@code )

}

	
1;
