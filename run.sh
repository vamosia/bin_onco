for i in */data_mutations_extended.BAK;

do cd $i;
   A=`dirname $i`;
   echo $A;
   cbio.fix.entrez.pl > ../../$A.log;
   cbio.fix.mutation.pl >> ../../$A.log;
   cd ../../;
done;
