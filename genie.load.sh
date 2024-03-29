
#!/bin/bash

if [ -z "$1" ]
then
    echo "Usage maindb.build_db [DATABASE_NAME] [STUDY: tcga|genie] [RELEASE_VERSION]";
    exit;
fi;

if [ -z "$2" ]
then
    echo "Usage maindb.build_db [DATABASE_NAME] [STUDY: tcga|genie] [RELEASE_VERSION]";
    exit;
fi;

if [ -z "$3" ]
then
    echo "Usage maindb.build_db [DATABASE_NAME] [STUDY: tcga|genie] [RELEASE_VERSION]";
    exit;
fi;

#(>&2 echo "GENIE - Creating New Database on $1");   
#maindb.dump_and_create.sh $1;

(>&2 echo "GENIE - Loading Study");   
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t study -c;
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t study_meta -c;

maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t cancer_study -c;

(>&2 echo "GENIE - Loading Patient");   
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t patient -c;
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t patient_meta -c;

(>&2 echo "GENIE - Loading Sample");   
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t sample -c ;
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t sample_meta -c;

(>&2 echo "GENIE - Processing CNV" );
maindb.process_CNV.pl -db $1 -s $2 -sv $3;

(>&2 echo "GENIE - Loading Analysis");
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t analysis -a cnv -c;
(>&2 echo "GENIE - Loading Analysis Meta");
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t analysis_meta -a cnv -c;
(>&2 echo "GENIE - Loading Analysis Data");
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t analysis_data -a cnv -c;

(>&2 echo "GENIE - Loading CNV");

# CNV
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t cnv -c;
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t cnv_sample -c;

# Variant
(>&2 echo "GENIE - Loading Variants");
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant -c;
(>&2 echo "GENIE - Loading Variants Meta");
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_meta -c;
(>&2 echo "GENIE - Loading Variants Sample");
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_sample -c;
(>&2 echo "GENIE - Loading Variants Sample Meta");
maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_sample_meta -c;
   
