firehose.import.pl -db $1 -c -v -t study;
firehose.import.pl -db $1 -c -v -t cancer_study;
firehose.import.pl -db $1 -c -v -t patient;
firehose.import.pl -db $1 -c -v -t patient_meta;
firehose.import.pl -db $1 -c -v -t sample;
firehose.import.pl -db $1 -c -v -t sample_meta;

firehose.import.pl -db $1 -c -v -t variant;
firehose.import.pl -db $1 -c -v -t variant_sample;
firehose.import.pl -db $1 -c -v -t variant_meta;


#for i in *; do cd $i; ln -s ../../firehose/stddata__2016_01_28/$i/20160128/*/data* .; cd ../; done;
#for i in *; do echo $i; cd $i/20160128/*Clinical.Level*; firehose.process.study.pl -v > $i.log; cd ../../../; done;
#for i in *; do echo $i; cd $i/20160128/*Oncotated*; firehose.process.mutation.pl -v; cd ../../../; done;
