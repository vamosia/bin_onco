for i in */tcga;
 do echo '[DATA_MUTATION_EXTENDED] : ' $i;
    cd $i
    if [ -e data_mutation_extended.txt ]
    then 
	echo '> [RUNNING]'
	cp data_mutations_extended.txt data_mutations_extended.txt.BAK
	more data_mutations_extended.txt | sed 's/\[Not Available\]/[Not_Available]/g' | sed 's/---/NA/g' > a;
	mv a data_mutations_extended.txt;
    else
	echo '> [SKIP] : does not exists'
    fi

    echo '[DATA_EXPRESSION_MEDIAN] : ' $i;
    if [-e data_expression_media.txt ]
    then
	echo '> [RUNNING]';
	cp data_expression_median.txt data_expression_median.txt.BAK
	more data_expression_median.txt | grep $'Composite Element REF\t\tlog2 lowess normalized (cy5/cy3) collapsed by gene symbol' -v > a
	mv a data_expression_median.txt;
    else
	echo '> [SKIP] : does not exists'	
    fi





