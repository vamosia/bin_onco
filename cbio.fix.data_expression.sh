for i in */tcga/data_expression.txt;
 do A=`dirname $i`;
    cd $A;
    echo '[WORKING ON] ' $i;
    pwd;
    cp data_expression.txt data_expression.BAK;
    more data_expression.txt | grep $'Composite Element REF\t\tSignal' -v > a;
    mv a data_expression.txt
    cd ../../;
 done



