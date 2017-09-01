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
-- Create Sequences
-- -----------------------------------------------------

-- patient_id_seq
CREATE SEQUENCE public.patient_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.patient_id_seq
  OWNER TO postgres;

-- sample_id_seq
CREATE SEQUENCE public.sample_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.sample_id_seq
  OWNER TO postgres;

-- study_id_seq
CREATE SEQUENCE public.study_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.study_id_seq
  OWNER TO postgres;

-- patient_event_id_seq
CREATE SEQUENCE public.patient_event_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.patient_event_id_seq
  OWNER TO postgres;

-- variant_id_seq
CREATE SEQUENCE public.variant_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.variant_id_seq
  OWNER TO postgres;

-- variant_sample_id_seq
CREATE SEQUENCE public.variant_sample_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.variant_sample_id_seq
  OWNER TO postgres;

-- cnv_sample
CREATE SEQUENCE public.cnv_sample_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.cnv_sample_id_seq
  OWNER TO postgres;

-- cnv
CREATE SEQUENCE public.cnv_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.cnv_id_seq
  OWNER TO postgres;

-- analysis
CREATE SEQUENCE public.analysis_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.variant_id_seq
  OWNER TO postgres;

--analysis_data
CREATE SEQUENCE public.analysis_data_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.analysis_data_id_seq
  OWNER TO postgres;

-- -----------------------------------------------------
-- Table public.study
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.study (
  study_id INT NOT NULL DEFAULT nextval('study_id_seq'::regclass),
  source VARCHAR(45) NOT NULL,
  study_name VARCHAR(255) NOT NULL,
  description VARCHAR(255) NULL,
  PRIMARY KEY (study_id));

ALTER TABLE public.study
  ADD CONSTRAINT study_uniq UNIQUE(source, study_name);

-- -----------------------------------------------------
-- Table public.study_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.study_meta (
  study_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (study_id),
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
  patient_id INT NOT NULL DEFAULT nextval('patient_id_seq'::regclass),
  stable_patient_id VARCHAR(45) NOT NULL,
  study_id INT NOT NULL,
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
  patient_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (patient_id),
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
  entrez_gene_id INT NOT NULL,
  hugo_gene_symbol VARCHAR(45) NOT NULL,
  PRIMARY KEY (entrez_gene_id));

ALTER TABLE public.gene
  ADD CONSTRAINT gene_uniq UNIQUE(entrez_gene_id, hugo_gene_symbol);

-- -----------------------------------------------------
-- Table public.variant
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.variant (
  variant_id INT NOT NULL DEFAULT nextval('variant_id_seq'::regclass),
  VarKey VARCHAR(255) NOT NULL,
  entrez_gene_id INT NOT NULL,
  chr VARCHAR(5) NOT NULL,
  start_position BIGINT NOT NULL,
  end_position BIGINT NOT NULL,
  ref_allele VARCHAR(400) NULL,
  var_allele VARCHAR(400) NULL,
  ref_genome_build VARCHAR(45) NOT NULL,
  strand VARCHAR(2) NULL,
  PRIMARY KEY (variant_id),
  CONSTRAINT fk_entrez_gene_id
    FOREIGN KEY (entrez_gene_id)
    REFERENCES public.gene (entrez_gene_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.variant
  ADD CONSTRAINT variant_uniq UNIQUE(VarKey, entrez_gene_id,
  chr, start_position, end_position, ref_genome_build, strand);

-- -----------------------------------------------------
-- Table public.cancer_type
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cancer_type (
  cancer_id VARCHAR(45) NOT NULL,
  cancer_name VARCHAR(255) NOT NULL,
  parent VARCHAR(45) NULL,
  PRIMARY KEY (cancer_id));

ALTER TABLE public.cancer_type
  ADD CONSTRAINT cancer_type_uniq UNIQUE(cancer_id, cancer_name);

-- -----------------------------------------------------
-- Table public.sample
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.sample (
  sample_id INT NOT NULL DEFAULT nextval('sample_id_seq'::regclass),
  patient_id INT NOT NULL,
  stable_sample_id VARCHAR(45) NOT NULL,
  cancer_id VARCHAR(45) NOT NULL,
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
  sample_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (sample_id),
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
  event_id INT NOT NULL DEFAULT nextval('patient_event_id_seq'::regclass),
  patient_id INT NOT NULL,
  event_name VARCHAR(45) NOT NULL,
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
  variant_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (variant_id),
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
  entrez_gene_id INT NOT NULL,
  gene_alias VARCHAR(255) NOT NULL,
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
  db_schema_version VARCHAR(45) NOT NULL,
  last_update VARCHAR(45) NULL,
  PRIMARY KEY (db_schema_version));


-- -----------------------------------------------------
-- Table public.meta_list
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.meta_list (
  meta_id INT NOT NULL,
  PRIMARY KEY (meta_id));


-- -----------------------------------------------------
-- Table public.patient_event_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.patient_event_meta (
  event_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (event_id),
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
  entrez_gene_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
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
  cancer_study_id INT NOT NULL,
  study_id INT NOT NULL,
  cancer_id VARCHAR(45) NOT NULL,
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
  cnv_id INT NOT NULL DEFAULT nextval('cnv_id_seq'::regclass),
  entrez_gene_id INT NOT NULL,
  alteration SMALLINT NOT NULL,
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
  cnv_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (cnv_id),
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
  cnv_sample_id INT NOT NULL DEFAULT nextval('cnv_sample_id_seq'::regclass),
  sample_id INT NOT NULL,
  cnv_id INT NOT NULL,
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
  iddrug INT NOT NULL,
  PRIMARY KEY (iddrug));

-- -----------------------------------------------------
-- Table public.drug_meta
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.drug_meta (
  iddrug INT NOT NULL,
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
  drug_iddrug INT NOT NULL,
  CONSTRAINT fk_drug_target_drug1
    FOREIGN KEY (drug_iddrug)
    REFERENCES public.drug (iddrug)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table public.drug_mechanism
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.drug_mechanism (
  iddrug INT NOT NULL,
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
  uniprot_id VARCHAR(255) NOT NULL,
  uniprot_acc VARCHAR(45) NOT NULL,
  entrez_gene_id INT NOT NULL,
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
  history_id INT NOT NULL,
  PRIMARY KEY (history_id));


-- -----------------------------------------------------
-- Table public.variant_sample
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.variant_sample (
  variant_sample_id INT NOT NULL DEFAULT nextval('variant_sample_id_seq'::regclass),
  sample_id INT NOT NULL,
  variant_id INT NOT NULL,
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
  variant_sample_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (variant_sample_id),
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
  cnv_sample_id INT NOT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (cnv_sample_id),
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
  analysis_id INT NOT NULL DEFAULT nextval('analysis_id_seq'::regclass),
  study_id INT NULL,
  sample_id INT NULL,
  name VARCHAR(45) NOT NULL,
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
  analysis_data_id INT NOT NULL DEFAULT nextval('analysis_data_id_seq'::regclass),
  analysis_id INT NOT NULL,
  entrez_gene_id INT NULL,
  attr_id VARCHAR(255) NOT NULL,
  attr_value VARCHAR(255) NOT NULL,
  PRIMARY KEY (analysis_data_id),
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
  analysis_id INT NOT NULL,
  attr_id VARCHAR(45) NOT NULL,
  attr_value VARCHAR(45) NULL,
  PRIMARY KEY (analysis_id),
  CONSTRAINT fk_analysis_id
    FOREIGN KEY (analysis_id)
    REFERENCES public.analysis (analysis_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

ALTER TABLE public.analysis_meta
  ADD CONSTRAINT analysis_meta_uniq UNIQUE(analysis_id, attr_id);

