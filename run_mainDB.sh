for i in *; do cd $i/20160128/*Mutation*; echo $i; firehose.process.mutation.pl -v -d > $i.log; cd ../../../; done;
for i in *; do cd $i/20160128/*Clinical*; echo $i; firehose.process.study.pl -v -d > $i.log; cd ../../../; done;
for i in *; do cd $i; echo $i; cbio.process_cna.pl -v > cna.process.log; cd ../; done;


firehose.import.pl -db test -t study;



