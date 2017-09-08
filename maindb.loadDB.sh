#!/bin/bash
echo $PWD;

if [ -z "$1" ]
then
    echo "Argument DB required";
    exit;
fi;

sudo -i -u postgres psql test2 -c "truncate table study cascade;"

firehose.process.study.pl -v  -db $1 -t study;
sudo -i -u postgres psql $1 -c "
copy study(study_name, source, description) FROM '$PWD/data_study.tsv' using DELIMITERS E'\t'";

firehose.process.study.pl -v -db $1 -t cancer_study;
sudo -i -u postgres psql $1 -c "
copy cancer_study(study_id, cancer_id) FROM '$PWD/data_cancer_study.tsv' using DELIMITERS E'\t';"

firehose.process.study.pl -v -db $1 -t patient;
sudo -i -u postgres psql $1 -c "
copy patient(stable_patient_id, study_id) FROM '$PWD/data_patient.tsv' using DELIMITERS E'\t';";

firehose.process.study.pl -v -db $1 -t patient_meta;
sudo -i -u postgres psql $1 -c "
copy patient_meta(patient_id, attr_id, attr_value) FROM '$PWD/data_patient_meta.tsv' using DELIMITERS E'\t';"

firehose.process.study.pl -v -db $1 -t sample
sudo -i -u postgres psql $1 -c "
copy sample(patient_id, stable_sample_id, cancer_id) FROM '$PWD/data_sample.tsv' using DELIMITERS E'\t';"


firehose.process.study.pl -v -db $1 -t sample_meta
sudo -i -u postgres psql $1 -c "
copy sample_meta(sample_id, attr_id, attr_value) FROM '$PWD/data_sample_meta.tsv' using DELIMITERS E'\t';"

exit;

firehose.process.mutation.pl -v -db $1 -t variant
sudo -i -u postgres psql $1 -c "
copy variant(varkey, entrez_gene_id, chr, start_position, end_position, ref_allele, var_allele, genome_build, strand) FROM '$PWD/data_variant.tsv' using DELIMITERS E'\t'";

firehose.process.mutation.pl -v -db $1 -sm -t variant_meta;
sudo -i -u postgres psql $1 -c "
copy variant_meta(variant_id, attr_id, attr_value) FROM '$PWD/data_variant_meta.tsv' using DELIMITERS E'\t'";

firehose.process.mutation.pl -v -db $1 -sm -t variant_sample
sudo -i -u postgres psql $1 -c "
copy variant_sample(sample_id, variant_id) FROM '$PWD/data_variant_sample.tsv' using DELIMITERS E'\t'";
