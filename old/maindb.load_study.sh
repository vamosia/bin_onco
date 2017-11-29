#!/bin/bash
echo $PWD;

if [ -z "$1" ]
then
    echo "Argument DB required";
    exit;
fi;


if [ "$2" = "truncate" ]
then
    sudo -i -u postgres psql $1 -c "
truncate table study cascade;
SELECT SETVAL( 'analysis_analysis_id_seq', 1, false);
SELECT SETVAL( 'analysis_data_analysis_data_id_seq', 1, false);
SELECT SETVAL( 'study_study_id_seq', 1, false);
SELECT SETVAL( 'cancer_study_cancer_study_id_seq', 1, false);
SELECT SETVAL( 'patient_patient_id_seq', 1, false);
SELECT SETVAL( 'patient_event_event_id_seq', 1, false);
SELECT SETVAL( 'sample_sample_id_seq', 1, false);
SELECT SETVAL( 'variant_variant_id_seq', 1, false);
SELECT SETVAL( 'variant_sample_variant_sample_id_seq', 1, false);
SELECT SETVAL( 'cnv_sample_cnv_sample_id_seq', 1, false);
"
fi;

# mysqldump -u root -p cbioportal gene | grep INSERT | sed 's/),(/\n/g' | sed 's/,/\t/g' | sed "s/'//g" | awk '{ print $1 "\t" $2 }' > data_gene.tsv

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

firehose.process.mutation.pl -v -db $1 -t variant
sudo -i -u postgres psql $1 -c "
copy variant(varkey, entrez_gene_id, chr, start_position, end_position, ref_allele, var_allele, genome_build, strand) FROM '$PWD/data_variant.tsv' using DELIMITERS E'\t'";

firehose.process.mutation.pl -v -db $1 -sm -t variant_meta;
sudo -i -u postgres psql $1 -c "
copy variant_meta(variant_id, attr_id, attr_value) FROM '$PWD/data_variant_meta.tsv' using DELIMITERS E'\t'";

firehose.process.mutation.pl -v -db $1 -sm -t variant_sample
sudo -i -u postgres psql $1 -c "
copy variant_sample(sample_id, variant_id) FROM '$PWD/data_variant_sample.tsv' using DELIMITERS E'\t'";

firehose.process.cna.pl -v -db $1 -s tcga -t analysis
sudo -i -u postgres psql $1 -c "
copy analysis(study_id, sample_id, name) FROM '$PWD/data_cnv_analysis.tsv' using DELIMITERS E'\t' WITH NULL AS 'null'";


firehose.process.cna.pl -v -db $1 -s tcga -t analysis_data;
sudo -i -u postgres psql $1 -c "
copy analysis_data(analysis_id, entrez_gene_id, attr_id, attr_value) FROM '$PWD/data_cnv_analysis_data.tsv' using DELIMITERS E'\t' WITH NULL AS 'null';
copy analysis_meta(analysis_id, attr_id, attr_value) FROM '$PWD/data_cnv_analysis_meta.tsv' using DELIMITERS E'\t' WITH NULL AS 'null'";

firehose.process.cna.pl -v -db $1 -s tcga -t cnv_sample;

# Becase both gene and gene alias exists, we need to uniq it
# PRAMEF21 > Gene alias to 645425
# PRAMEF20 > Entrez 645425
more data_cnv_sample.tsv | sort | uniq > /tmp/data_cnv_sample.tsv;
mv /tmp/data_cnv_sample.tsv data_cnv_sample.tsv;

sudo -i -u postgres psql $1 -c "
copy cnv_sample(sample_id, cnv_id) FROM '$PWD/data_cnv_sample.tsv' using DELIMITERS E'\t'";



