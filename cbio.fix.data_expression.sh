for i in */tcga/;
 do echo '[DATA_EXPRESSION.txt] : ' $i;
    cd $i;
    if [ -e data_expression.txt ]
    then       
	echo '> [RUNNING]';
	cp data_expression.txt data_expression.BAK;
	more data_expression.txt | grep $'Composite Element REF\t\tSignal' -v > a;
	mv a data_expression.txt
    else
	echo '> [SKIP] : does not exists';
	
    fi
    cd ../../;
    echo ''
done



