-- -----------------------------------------------------
-- Schema public
-- -----------------------------------------------------
DROP SCHEMA IF EXISTS public CASCADE;

-- -----------------------------------------------------
-- Schema public
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS public ;
-- DEFAULT CHARACTER -- SET utf8 ;
-- USE public ;


-- -----------------------------------------------------
-- Table public.study
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.study (
  study_id SERIAL NOT NULL,
  source TEXT NOT NULL,
  study_name TEXT NOT NULL,
  description TEXT NULL,
  PRIMARY KEY (study_id));

ALTER TABLE public.study
  ADD CONSTRAINT study_uniq UNIQUE(source, study_name);

-- -----------------------------------------------------
-- Table public.study_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.study_meta (
  study_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (study_id, attr_id),
  CONSTRAINT fk_study_id
    FOREIGN KEY (study_id)
    REFERENCES public.study (study_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.study_meta
  ADD CONSTRAINT study_meta_uniq UNIQUE(study_id, attr_id);

-- -----------------------------------------------------
-- Table public.patient
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.patient (
  patient_id SERIAL NOT NULL,
  stable_patient_id TEXT NOT NULL,
  study_id INTEGER NOT NULL,
  PRIMARY KEY (patient_id),
  CONSTRAINT fk_study_id
    FOREIGN KEY (study_id)
    REFERENCES public.study (study_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


ALTER TABLE public.patient
  ADD CONSTRAINT patient_uniq UNIQUE(stable_patient_id, study_id);

-- -----------------------------------------------------
-- Table public.patient_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.patient_meta (
  patient_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (patient_id, attr_id),
  CONSTRAINT fk_patient_id
    FOREIGN KEY (patient_id)
    REFERENCES public.patient (patient_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.patient_meta
  ADD CONSTRAINT patient_meta_uniq UNIQUE(patient_id, attr_id);
  
-- -----------------------------------------------------
-- Table public.gene
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.gene (
  entrez_gene_id INTEGER NOT NULL,
  hugo_gene_symbol TEXT NOT NULL,
  PRIMARY KEY (entrez_gene_id));

ALTER TABLE public.gene
  ADD CONSTRAINT gene_uniq UNIQUE(entrez_gene_id, hugo_gene_symbol);

-- -----------------------------------------------------
-- Table public.variant
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.variant (
  variant_id SERIAL NOT NULL,
  varkey TEXT NOT NULL,
  entrez_gene_id INTEGER NOT NULL,
  chr TEXT NOT NULL,
  start_position BIGINT NOT NULL,
  end_position BIGINT NOT NULL,
  ref_allele TEXT NULL,
  var_allele TEXT NULL,
  genome_build TEXT NOT NULL,
  strand TEXT NULL,
  PRIMARY KEY (variant_id),
  CONSTRAINT fk_entrez_gene_id
    FOREIGN KEY (entrez_gene_id)
    REFERENCES public.gene (entrez_gene_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.variant
  ADD CONSTRAINT variant_uniq UNIQUE(varkey, entrez_gene_id,
  chr, start_position, end_position, genome_build, strand);

-- -----------------------------------------------------
-- Table public.cancer_type
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cancer_type (
  cancer_id TEXT NOT NULL,
  cancer_name TEXT NOT NULL,
  parent TEXT NULL,
  PRIMARY KEY (cancer_id));

ALTER TABLE public.cancer_type
  ADD CONSTRAINT cancer_type_uniq UNIQUE(cancer_id, cancer_name);

-- -----------------------------------------------------
-- Table public.sample
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.sample (
  sample_id SERIAL NOT NULL,
  patient_id INTEGER NOT NULL,
  stable_sample_id TEXT NOT NULL,
  cancer_id TEXT NOT NULL,
  PRIMARY KEY (sample_id),
  CONSTRAINT fk_patient_id
    FOREIGN KEY (patient_id)
    REFERENCES public.patient (patient_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_cancer_id
    FOREIGN KEY (cancer_id)
    REFERENCES public.cancer_type (cancer_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.sample
  ADD CONSTRAINT sample_uniq UNIQUE(patient_id, stable_sample_id, cancer_id);

-- -----------------------------------------------------
-- Table public.sample_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.sample_meta (
  sample_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (sample_id, attr_id),
  CONSTRAINT fk_sample_id
    FOREIGN KEY (sample_id)
    REFERENCES public.sample (sample_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.sample_meta
  ADD CONSTRAINT sample_meta_uniq UNIQUE(sample_id, attr_id);


-- -----------------------------------------------------
-- Table public.patient_event
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.patient_event (
  event_id SERIAL NOT NULL,
  patient_id INTEGER NOT NULL,
  event_name TEXT NOT NULL,
  start_date DATE NULL,
  end_date DATE NULL,
  PRIMARY KEY (event_id),
  CONSTRAINT fk_event_id
    FOREIGN KEY (patient_id)
    REFERENCES public.patient (patient_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.patient_event
  ADD CONSTRAINT patient_event_uniq UNIQUE(patient_id, event_name,
  start_date, end_date);


-- -----------------------------------------------------
-- Table public.variant_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.variant_meta (
  variant_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (variant_id, attr_id),
  CONSTRAINT fk_variant_id
    FOREIGN KEY (variant_id)
    REFERENCES public.variant (variant_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.variant_meta
  ADD CONSTRAINT variant_meta_uniq UNIQUE(variant_id, attr_id);


-- -----------------------------------------------------
-- Table public.gene_alias
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.gene_alias (
  entrez_gene_id INTEGER NOT NULL,
  gene_alias TEXT NOT NULL,
  PRIMARY KEY (entrez_gene_id, gene_alias),
  CONSTRAINT fk_entrez_gene_id
    FOREIGN KEY (entrez_gene_id)
    REFERENCES public.gene (entrez_gene_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table public.info
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.info (
  db_schema_version TEXT NOT NULL,
  last_update TEXT NULL,
  PRIMARY KEY (db_schema_version));


-- -----------------------------------------------------
-- Table public.meta_list
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.meta_list (
  meta_id INTEGER NOT NULL,
  PRIMARY KEY (meta_id));


-- -----------------------------------------------------
-- Table public.patient_event_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.patient_event_meta (
  event_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (event_id, attr_id),
  CONSTRAINT fk_event_id
    FOREIGN KEY (event_id)
    REFERENCES public.patient_event (event_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.patient_event_meta
  ADD CONSTRAINT patient_event_meta_uniq UNIQUE(event_id, attr_id);

-- -----------------------------------------------------
-- Table public.gene_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.gene_meta (
  entrez_gene_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (entrez_gene_id, attr_id),
  CONSTRAINT fk_entrez_gene_id
    FOREIGN KEY (entrez_gene_id)
    REFERENCES public.gene (entrez_gene_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.gene_meta
  ADD CONSTRAINT gene_meta_uniq UNIQUE(entrez_gene_id, attr_id);

-- -----------------------------------------------------
-- Table public.cancer_study
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cancer_study (
  cancer_study_id SERIAL NOT NULL,
  study_id INTEGER NOT NULL,
  cancer_id TEXT NOT NULL,
  PRIMARY KEY (cancer_study_id),
  CONSTRAINT fk_study_id
    FOREIGN KEY (study_id)
    REFERENCES public.study (study_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_cancer_id
    FOREIGN KEY (cancer_id)
    REFERENCES public.cancer_type (cancer_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.cancer_study
  ADD CONSTRAINT cancer_study_uniq UNIQUE(study_id, cancer_id);
-- -----------------------------------------------------
-- Table public.cnv
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cnv (
  cnv_id SERIAL NOT NULL,
  entrez_gene_id INTEGER NOT NULL,
  alteration TEXT NOT NULL,
  PRIMARY KEY (cnv_id),
  CONSTRAINT fk_entrez_gene_id
    FOREIGN KEY (entrez_gene_id)
    REFERENCES public.gene (entrez_gene_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.cnv
  ADD CONSTRAINT cnv_uniq UNIQUE(entrez_gene_id, alteration);
-- -----------------------------------------------------
-- Table public.cnv_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cnv_meta (
  cnv_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (cnv_id, attr_id),
  CONSTRAINT fk_cnv_id
    FOREIGN KEY (cnv_id)
    REFERENCES public.cnv (cnv_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.cnv_meta
  ADD CONSTRAINT cnv_meta_uniq UNIQUE(cnv_id, attr_id);

-- -----------------------------------------------------
-- Table public.cnv_sample
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cnv_sample (
  cnv_sample_id SERIAL NOT NULL,
  sample_id INTEGER NOT NULL,
  cnv_id INTEGER NOT NULL,
  PRIMARY KEY (cnv_sample_id),
  CONSTRAINT fk_cnv_id
    FOREIGN KEY (cnv_id)
    REFERENCES public.cnv (cnv_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_sample_id
    FOREIGN KEY (sample_id)
    REFERENCES public.sample (sample_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.cnv_sample
  ADD CONSTRAINT cnv_sample_uniq UNIQUE(sample_id, cnv_id);

-- -----------------------------------------------------
-- Table public.drug
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.drug (
  iddrug INTEGER NOT NULL,
  PRIMARY KEY (iddrug));

-- -----------------------------------------------------
-- Table public.drug_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.drug_meta (
  iddrug INTEGER NOT NULL,
  PRIMARY KEY (iddrug),
  CONSTRAINT fk_drug_meta1
    FOREIGN KEY (iddrug)
    REFERENCES public.drug (iddrug)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table public.drug_target
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.drug_target (
  drug_iddrug INTEGER NOT NULL,
  CONSTRAINT fk_drug_target_drug1
    FOREIGN KEY (drug_iddrug)
    REFERENCES public.drug (iddrug)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table public.drug_mechanism
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.drug_mechanism (
  iddrug INTEGER NOT NULL,
  PRIMARY KEY (iddrug),
  CONSTRAINT fk_drug_mechanism1
    FOREIGN KEY (iddrug)
    REFERENCES public.drug (iddrug)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table public.gene_uniprot_map
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.gene_uniprot_map (
  uniprot_id TEXT NOT NULL,
  uniprot_acc TEXT NOT NULL,
  entrez_gene_id INTEGER NOT NULL,
  PRIMARY KEY (uniprot_id),
  CONSTRAINT fk_uniport_id_mapping1
    FOREIGN KEY (entrez_gene_id)
    REFERENCES public.gene (entrez_gene_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table public.history
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.history (
  history_id INTEGER NOT NULL,
  PRIMARY KEY (history_id));


-- -----------------------------------------------------
-- Table public.variant_sample
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.variant_sample (
  variant_sample_id SERIAL NOT NULL,
  sample_id INTEGER NOT NULL,
  variant_id INTEGER NOT NULL,
  PRIMARY KEY (variant_sample_id),
  CONSTRAINT fk_sample_id
    FOREIGN KEY (sample_id)
    REFERENCES public.sample (sample_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_variant_id
    FOREIGN KEY (variant_id)
    REFERENCES public.variant (variant_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.variant_sample
  ADD CONSTRAINT variant_sample_uniq UNIQUE(sample_id, variant_id);

-- -----------------------------------------------------
-- Table public.variant_sample_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.variant_sample_meta (
  variant_sample_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (variant_sample_id, attr_id),
  CONSTRAINT fk_variant_sample_id
    FOREIGN KEY (variant_sample_id)
    REFERENCES public.variant_sample (variant_sample_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


ALTER TABLE public.variant_sample_meta
  ADD CONSTRAINT variant_sample_meta_uniq UNIQUE(variant_sample_id, attr_id);


-- -----------------------------------------------------
-- Table public.cnv_sample_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cnv_sample_meta (
  cnv_sample_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (cnv_sample_id, attr_id),
  CONSTRAINT fk_cnv_sample_id
    FOREIGN KEY (cnv_sample_id)
    REFERENCES public.cnv_sample (cnv_sample_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.cnv_sample_meta
  ADD CONSTRAINT cnv_sample_meta_uniq UNIQUE(cnv_sample_id, attr_id);


-- -----------------------------------------------------
-- Table public.analysis
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.analysis (
  analysis_id SERIAL NOT NULL,
  study_id INTEGER NULL,
  sample_id INTEGER NULL,
  name TEXT NOT NULL,
  PRIMARY KEY (analysis_id),
  CONSTRAINT fk_study_id
    FOREIGN KEY (study_id)
    REFERENCES public.study (study_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_sample_id
    FOREIGN KEY (sample_id)
    REFERENCES public.sample (sample_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.analysis
  ADD CONSTRAINT analysis_uniq UNIQUE(study_id, sample_id, name);
-- -----------------------------------------------------
-- Table public.analysis_data
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.analysis_data (
  analysis_data_id SERIAL NOT NULL,
  analysis_id INTEGER NOT NULL,
  entrez_gene_id INTEGER NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NOT NULL,
  PRIMARY KEY (analysis_data_id, attr_id, entrez_gene_id),
  CONSTRAINT fk_entrez_gene_id
    FOREIGN KEY (entrez_gene_id)
    REFERENCES public.gene (entrez_gene_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_analysis_id
    FOREIGN KEY (analysis_id)
    REFERENCES public.analysis (analysis_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.analysis_data
  ADD CONSTRAINT analysis_data_uniq UNIQUE(analysis_id,entrez_gene_id,attr_id);
-- -----------------------------------------------------
-- Table public.analysis_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.analysis_meta (
  analysis_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NULL,
  PRIMARY KEY (analysis_id, attr_id),
  CONSTRAINT fk_analysis_id
    FOREIGN KEY (analysis_id)
    REFERENCES public.analysis (analysis_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION

);

ALTER TABLE public.analysis_meta
  ADD CONSTRAINT analysis_meta_uniq UNIQUE(analysis_id, attr_id);



-- -----------------------------------------------------
-- Table public.genetic_alteration
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.genetic_alteration (
  genetic_alteration_id INTEGER NOT NULL,
  study_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  sample_list TEXT NULL,
  value_list TEXT NULL,
  PRIMARY KEY (genetic_alteration_id),
  CONSTRAINT fk_genetic_alteration1
    FOREIGN KEY (study_id)
    REFERENCES public.study (study_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table public.genetic_alteration_meta
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.genetic_alteration_meta (
  genetic_alteration_id INTEGER NOT NULL,
  attr_id TEXT NOT NULL,
  attr_value TEXT NULL,
  PRIMARY KEY (genetic_alteration_id, attr_id),
  CONSTRAINT fk_genetic_alteration_meta1
    FOREIGN KEY (genetic_alteration_id)
    REFERENCES public.genetic_alteration (genetic_alteration_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

