firehose.import.pl -db $1 -t cancer_type -v -seed -c;
firehose.import.pl -db $1 -t gene -v -seed -c;
firehose.import.pl -db $1 -t gene_alias -v -seed -c;
firehose.import.pl -db $1 -t gene_meta -v -seed -c;
