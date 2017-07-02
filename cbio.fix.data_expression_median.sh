for i in */tcga/data_expression_median.txt;
 do A=`dirname $i`;
    cd $A;
    echo '[WORKING ON] ' $i;
    pwd;
    cp data_expression_median.txt data_expression_median.txt.BAK
    more data_expression_median.txt | grep $'Composite Element REF\t\tlog2 lowess normalized (cy5/cy3) collapsed by gene symbol' -v > a
    mv a data_expression_median.txt;
    cd ../../;
 done



