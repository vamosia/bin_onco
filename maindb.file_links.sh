#!/bin/bash

for i in *; do cd $i; ln -s ../../firehose/stddata__2016_01_28/$i/20160128/*/maf.merge.tsv .; cd ../; done;
for i in *; do cd $i; ln -s ../../firehose/stddata__2016_01_28/$i/20160128/*/*.merged.txt .; cd ../; done;
for i in *; do cd $i; ln -s ../../firehose/analyses__2016_01_28/$i/20160128/*/all_thresholded.by_genes.txt .; cd ../; done;
