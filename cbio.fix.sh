echo '[REMOVING PaxHeader]'; 
echo '';
for i in `find . -name 'PaxHeader'`; do rm -rf $i; done;

for i in *;

do cd $i
    echo '[WORKKING] : ' $i;
    # -------------
    echo '> [data_mutations_extended.txt]';
    if [ -e data_mutations_extended.txt ]
    then 
       	echo '>> [RUNNING]'
	cp data_mutations_extended.txt data_mutations_extended.txt.BAK
	more data_mutations_extended.txt | sed 's/\[Not.Available\]/[NA]/g' | sed 's/---/NA/g' > a;
	mv a data_mutations_extended.txt;
    else
	echo '>> [SKIP] : does not exists'
    fi
    echo '';

    # -------------
    echo '> [data_expression.txt] ';
    if [ -e data_expression.txt ]
    then       
	echo '>> [RUNNING]';
	cp data_expression.txt data_expression.BAK;
	more data_expression.txt | grep $'Composite Element REF\t\tSignal' -v > a;
	mv a data_expression.txt
    else
	echo '>> [SKIP] : does not exists';
    fi
    echo '';

    # -------------
    echo '> [data_expression_median.txt] : ';
    if [ -e data_expression_median.txt ]
    then
	echo '>> [RUNNING]';
	cp data_expression_median.txt data_expression_median.txt.BAK;
	more data_expression_median.txt | grep $'Composite Element REF\t\tlog2 lowess normalized (cy5/cy3) collapsed by gene symbol' -v > a;
	mv a data_expression_median.txt;
    else
	echo '>> [SKIP] : does not exists';
    fi
    
    cd ../../;
done

#cbio.fix.entrez.pl;
# Run cbio.download.mutation.pl





