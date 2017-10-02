package myDBI;

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
