#!/bin/sh

TOTAL=`more $1 | wc -l`;

DIV=$((TOTAL/4));

PART1=1;
PART2=$((DIV*1));
echo "Total Lines : $TOTAL/4 = $DIV per file";
# Part 1
echo "tcga_mutations_extended.txt.1.maf = $PART1-$PART2 lines";
#head -n $PART $1 > tcga_mutations_extended.txt.1.maf;
sed -n "$PART1,${PART2}p" $1 > tcga_mutations_extended.txt.1.maf;

# Part 2
head -n 1 $1 > tcga_mutations_extended.txt.2.maf;
PART1=$(($PART2+1));
PART2=$((DIV*2));
echo "tcga_mutations_extended.txt.2.maf = $PART1-$PART2 lines";
#tail -n +$DIV $1 >> tcga_mutations_extended.txt.2.maf;
sed -n "$PART1,${PART2}p" $1 >> tcga_mutations_extended.txt.2.maf;

# Part 3
head -n 1 $1 > tcga_mutations_extended.txt.3.maf;
PART1=$(($PART2+1));
PART2=$((DIV*3));
echo "tcga_mutations_extended.txt.3.maf = $PART1-$PART2 lines";
#tail -n +$DIV $1 >> tcga_mutations_extended.txt.2.maf;
sed -n "$PART1,${PART2}p" $1 >> tcga_mutations_extended.txt.3.maf;

# Part 3
head -n 1 $1 > tcga_mutations_extended.txt.4.maf;
PART1=$(($PART2+1));
PART2=$TOTAL;
echo "tcga_mutations_extended.txt.4.maf = $PART1-$PART2 lines";
#tail -n +$DIV $1 >> tcga_mutations_extended.txt.2.maf;
sed -n "$PART1,${PART2}p" $1 >> tcga_mutations_extended.txt.4.maf;
