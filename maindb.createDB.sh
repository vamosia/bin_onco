sudo -u postgres psql $1 < /srv/alexb/bin/DB/maindb.psql.sql;

sudo -i -u postgres psql test2 -c "
copy gene(entrez_gene_id,hugo_gene_symbol) FROM '/srv/datahub/mainDB.seedDB/data_gene.tsv' using DELIMITERS E'\t';
copy gene_meta(entrez_gene_id, attr_id, attr_value) FROM '/srv/datahub/mainDB.seedDB/data_gene_meta.tsv' using DELIMITERS E'\t';
copy gene_alias(entrez_gene_id,gene_alias) FROM '/srv/datahub/mainDB.seedDB/data_gene_alias.tsv' using DELIMITERS E'\t';
copy cancer_type(cancer_id, cancer_name, parent) FROM '/srv/datahub/mainDB.seedDB/data_cancer_type.tsv' using DELIMITERS E'\t';
copy cnv(entrez_gene_id,alteration) FROM '/srv/datahub/mainDB.seedDB/data_cnv.tsv' using DELIMITERS E'\t';
"