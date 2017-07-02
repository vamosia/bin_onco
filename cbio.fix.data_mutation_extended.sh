for i in */tcga/data_mutations_extended.txt;
 do A=`dirname $i`;
    cd $A
    echo '[WORKING ON] ' $i;
    pwd;
    cp data_mutations_extended.txt data_mutations_extended.txt.BAK
    more data_mutations_extended.txt | sed 's/\[Not Available\]/[Not_Available]/g' > a;
    mv a data_mutations_extended.txt;
    cd ../../;
 done
