
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


maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_clinical.txt -t study -c;

maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_clinical.txt -t cancer_study -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_clinical.txt -t study_meta -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_clinical.txt -t patient -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_clinical.txt -t patient_meta -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_clinical.txt -t sample -c ;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_clinical.txt -t sample_meta -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_mutations_extended.txt -t variant -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_mutations_extended.txt -t variant_meta -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_CNV.txt -t analysis -a cnv -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_CNV.txt -t analysis_meta -a cnv -c;
maindb.load_study.pl -db $1 -v -s $2 -sv $3 -f $2_CNV.txt -t analysis_data -a cnv -c;