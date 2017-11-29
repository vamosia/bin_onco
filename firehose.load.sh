
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
(>&2 echo "Creating New Database $1");
#maindb.dump_and_create.sh $1;

for i in COADREAD;
do 
   (>&2 date);
   cd $i;

    (>&2 echo "$i - 1/9 Loading Study");
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t study -c;
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t cancer_study -c;
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t study_meta -c;
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t patient -c;
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t patient_meta -c;
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t sample -c ;
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_clinical.txt -t sample_meta -c;

    (>&2 echo "$i - 2/9 Loading Patient and Samples from CNV" );
    cp $2_CNV.txt.BAK $2_CNV.txt;
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t patient -c ;
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t sample -c ;

    (>&2 echo "$i - 3/9 Processing CNV");
    maindb.process_CNV.pl -db $1 -s $2 -sv $3;
    
    (>&2 echo "$i - 4/9 Loading Analysis" )
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t analysis -a cnv -c;
    (>&2 echo "$i - 5/9 Loading Analysis Meta");
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t analysis_meta -a cnv -c;
    (>&2 echo "$i - 6/9 Loading Analysis Data");
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t analysis_data -a cnv -c;

    (>&2 echo "$i - 7/9 Loading CNV");
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t cnv -c;
    (>&2 echo "$i - 8/9 Loading CNV Sample");
    maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_CNV.txt -t cnv_sample -c;
        
    split_file.pl -f $2_mutations_extended.txt.BAK;
    
    for j in *maf;
    do
	(>&2 echo "$i - 9/9 - 1/6 Processing $j");
	echo "$i - Processing $j";
	cp $j $2_mutations_extended.txt;
	
	# cd mutations;
	(>&2 echo "$i - 9/9 - 2/6 Loading Patient and Samples from Variants");
	maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t patient -c;
	maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t sample -c;
	
	(>&2 echo "$i - 9/9 - 3/6 Loading Variant");
	maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant -c;
	
	(>&2 echo "$i - 9/9 - 4/6 Loading Variant Meta");
	maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_meta -c;
	
	(>&2 echo "$i - 9/9 - 5/6 Loading Variant Sample");
	maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_sample -c;
	
	(>&2 echo "$i - 9/9 - 6/6 Loading Variant Sample Meta");
	maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_sample_meta -c;
    done;
    
   
   # rm variant.log;
   # for j in *maf.txt;
   # do
   #     echo "=========$i=$j============" >> variant.log;
   #     cp $j tcga_mutations_extended.txt;
   #     (>&2 echo "$i - Loading Variant");
   #     maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant -c >> variant.log;

   #     (>&2 echo "$i - Loading Variant Meta");
   #     maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_meta -c >> variant.log;

   #     (>&2 echo "$i - Loading Variant Sample");
   #     maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_sample -c >> variant.log;

   #     (>&2 echo "$i - Loading Variant Sample Meta");
   #     maindb.load_study.pl -db $1 -s $2 -sv $3 -v -f $2_mutations_extended.txt -t variant_sample_meta -c >> variant.log;
   # done;

#   cd ../;
   
   cd ../;
done;
   
   
