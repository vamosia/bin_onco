for i in */tcga;
 do echo '[DATA_EXPRESSION_MEDIAN] : ' $i;
    cd $i;   
    if [-e data_expression_media.txt ]
    then
	echo '> [RUNNING]';
	cp data_expression_median.txt data_expression_median.txt.BAK
	more data_expression_median.txt | grep $'Composite Element REF\t\tlog2 lowess normalized (cy5/cy3) collapsed by gene symbol' -v > a
	mv a data_expression_median.txt;
    else
	echo '> [SKIP] : does not exists'	
    fi
    cd ../../;
    echo '';
 done



for i in */tcga;
 do echo '[DATA_EXPRESSION_MEDIAN] : ' $i;
    cd $i;   
    if [-e data_expression_media.txt ]
    then
	echo '> [RUNNING]';
	cp data_expression_median.txt data_expression_median.txt.BAK
	more data_expression_median.txt | grep $'Composite Element REF\t\tlog2 lowess normalized (cy5/cy3) collapsed by gene symbol' -v > a
	mv a data_expression_median.txt;
    else
	echo '> [SKIP] : does not exists'	
    fi
    cd ../../;
    echo '';
 done



