-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE=TRADITIONAL,ALLOW_INVALID_DATES;

-- -----------------------------------------------------
-- Schema mainDB
-- -----------------------------------------------------
DROP SCHEMA IF EXISTS `mainDB` ;

-- -----------------------------------------------------
-- Schema mainDB
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `mainDB` DEFAULT CHARACTER SET utf8 ;
USE `mainDB` ;

-- -----------------------------------------------------
-- Table `mainDB`.`study`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`study` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`study` (
  `study_id` INT NOT NULL,
  `source` VARCHAR(45) NOT NULL,
  `name` VARCHAR(255) NULL,
  `description` VARCHAR(255) NULL,
  PRIMARY KEY (`study_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_study`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_study` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_study` (
  `study_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`study_id`, `attr_id`),
  INDEX `fk_meta_study1_idx` (`study_id` ASC),
  CONSTRAINT `fk_meta_study1`
    FOREIGN KEY (`study_id`)
    REFERENCES `mainDB`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`patient`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`patient` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`patient` (
  `patient_id` INT NOT NULL,
  `stable_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`patient_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_patient`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_patient` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_patient` (
  `patient_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`attr_id`, `patient_id`),
  INDEX `fk_meta_patient1_idx` (`patient_id` ASC),
  CONSTRAINT `fk_meta_patient1`
    FOREIGN KEY (`patient_id`)
    REFERENCES `mainDB`.`patient` (`patient_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`gene`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`gene` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`gene` (
  `entrez_gene_id` INT NOT NULL,
  `hugo_gene_symbol` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`entrez_gene_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`variant`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`variant` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`variant` (
  `variant_id` INT NOT NULL,
  `var_char` VARCHAR(255) NOT NULL,
  `entrez_gene_id` INT NOT NULL,
  `chr` VARCHAR(5) NOT NULL,
  `start_position` BIGINT(20) NOT NULL,
  `end_position` BIGINT(20) NOT NULL,
  `ref_allele` VARCHAR(400) NULL,
  `var_allele` VARCHAR(400) NULL,
  `ref_genome_build` VARCHAR(45) NOT NULL,
  `strand` VARCHAR(2) NULL,
  PRIMARY KEY (`variant_id`),
  INDEX `fk_variant1_idx` (`entrez_gene_id` ASC),
  CONSTRAINT `fk_variant1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `mainDB`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`patient_study`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`patient_study` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`patient_study` (
  `patient_study_id` INT NOT NULL,
  `patient_id` INT NOT NULL,
  `study_id` INT NOT NULL,
  PRIMARY KEY (`patient_study_id`),
  INDEX `fk_patient_study1_idx` (`patient_id` ASC),
  INDEX `fk_patient_study2_idx` (`study_id` ASC),
  CONSTRAINT `fk_patient_study1`
    FOREIGN KEY (`patient_id`)
    REFERENCES `mainDB`.`patient` (`patient_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_patient_study2`
    FOREIGN KEY (`study_id`)
    REFERENCES `mainDB`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`cancer_type`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`cancer_type` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`cancer_type` (
  `cancer_id` VARCHAR(45) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `parent` VARCHAR(45) NULL,
  PRIMARY KEY (`cancer_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`sample` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`sample` (
  `sample_id` INT NOT NULL,
  `patient_study_id` INT NOT NULL,
  `stable_id` VARCHAR(45) NOT NULL,
  `cancer_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`sample_id`),
  INDEX `fk_sample1_idx` (`patient_study_id` ASC),
  INDEX `fk_sample2_idx` (`cancer_id` ASC),
  CONSTRAINT `fk_sample1`
    FOREIGN KEY (`patient_study_id`)
    REFERENCES `mainDB`.`patient_study` (`patient_study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_sample2`
    FOREIGN KEY (`cancer_id`)
    REFERENCES `mainDB`.`cancer_type` (`cancer_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_sample` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_sample` (
  `sample_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`attr_id`, `sample_id`),
  INDEX `fk_meta_sample1_idx` (`sample_id` ASC),
  CONSTRAINT `fk_meta_sample1`
    FOREIGN KEY (`sample_id`)
    REFERENCES `mainDB`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`variant_sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`variant_sample` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`variant_sample` (
  `variant_sample_id` INT NULL,
  `sample_id` INT NOT NULL,
  `variant_id` INT NOT NULL,
  PRIMARY KEY (`variant_sample_id`),
  INDEX `fk_variant_sample2_idx` (`sample_id` ASC),
  CONSTRAINT `fk_variant_sample1`
    FOREIGN KEY (`variant_id`)
    REFERENCES `mainDB`.`variant` (`variant_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_variant_sample2`
    FOREIGN KEY (`sample_id`)
    REFERENCES `mainDB`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`patient_event`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`patient_event` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`patient_event` (
  `event_id` INT NOT NULL,
  `patient_id` INT NOT NULL,
  `event_name` VARCHAR(45) NOT NULL,
  `start_date` DATE NULL,
  `end_date` DATE NULL,
  PRIMARY KEY (`event_id`),
  INDEX `fk_patient_timeline1_idx` (`patient_id` ASC),
  CONSTRAINT `fk_patient_timeline1`
    FOREIGN KEY (`patient_id`)
    REFERENCES `mainDB`.`patient` (`patient_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_variant`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_variant` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_variant` (
  `variant_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`attr_id`, `variant_id`),
  INDEX `fk_meta_variant1_idx` (`variant_id` ASC),
  CONSTRAINT `fk_meta_variant1`
    FOREIGN KEY (`variant_id`)
    REFERENCES `mainDB`.`variant` (`variant_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`gene_alias`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`gene_alias` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`gene_alias` (
  `entrez_gene_id` INT NOT NULL,
  `gene_alias` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`entrez_gene_id`, `gene_alias`),
  CONSTRAINT `fk_gene_alias1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `mainDB`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`info`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`info` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`info` (
  `db_schema_version` VARCHAR(45) NOT NULL,
  `last_update` VARCHAR(45) NULL,
  PRIMARY KEY (`db_schema_version`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_list`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_list` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_list` (
  `meta_id` INT NOT NULL,
  PRIMARY KEY (`meta_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_patient_event`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_patient_event` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_patient_event` (
  `event_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`attr_id`, `event_id`),
  INDEX `fk_meta_patient_timeline1_idx` (`event_id` ASC),
  CONSTRAINT `fk_meta_patient_timeline1`
    FOREIGN KEY (`event_id`)
    REFERENCES `mainDB`.`patient_event` (`event_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_gene`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_gene` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_gene` (
  `entrez_gene_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`entrez_gene_id`, `attr_id`),
  INDEX `fk_meta_gene1_idx` (`entrez_gene_id` ASC),
  CONSTRAINT `fk_meta_gene1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `mainDB`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`sample_analysis`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`sample_analysis` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`sample_analysis` (
  `sample_analysis_id` INT NOT NULL,
  `sample_id` INT NOT NULL,
  `analysis` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`sample_analysis_id`),
  INDEX `fk_sample_analysis1_idx` (`sample_id` ASC),
  CONSTRAINT `fk_sample_analysis1`
    FOREIGN KEY (`sample_id`)
    REFERENCES `mainDB`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_sample_analysis`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_sample_analysis` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_sample_analysis` (
  `sample_analysis_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`attr_id`, `sample_analysis_id`),
  INDEX `fk_meta_sample_analysis1_idx` (`sample_analysis_id` ASC),
  CONSTRAINT `fk_meta_sample_analysis1`
    FOREIGN KEY (`sample_analysis_id`)
    REFERENCES `mainDB`.`sample_analysis` (`sample_analysis_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`predicted_cancer_type`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`predicted_cancer_type` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`predicted_cancer_type` (
  `predicted_id` INT NOT NULL,
  `sample_id` INT NOT NULL,
  `cancer_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`predicted_id`),
  INDEX `fk_predicted_cancer_type1_idx` (`sample_id` ASC),
  INDEX `fk_predicted_cancer_type2_idx` (`cancer_id` ASC),
  CONSTRAINT `fk_predicted_cancer_type1`
    FOREIGN KEY (`sample_id`)
    REFERENCES `mainDB`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_predicted_cancer_type2`
    FOREIGN KEY (`cancer_id`)
    REFERENCES `mainDB`.`cancer_type` (`cancer_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`cancer_study`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`cancer_study` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`cancer_study` (
  `study_id` INT NOT NULL,
  `cancer_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`study_id`, `cancer_id`),
  INDEX `fk_cancer_study1_idx` (`study_id` ASC),
  INDEX `fk_cancer_study2_idx` (`cancer_id` ASC),
  CONSTRAINT `fk_cancer_study1`
    FOREIGN KEY (`study_id`)
    REFERENCES `mainDB`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_cancer_study2`
    FOREIGN KEY (`cancer_id`)
    REFERENCES `mainDB`.`cancer_type` (`cancer_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`cnv`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`cnv` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`cnv` (
  `cnv_id` INT NOT NULL,
  `entrez_gene_id` INT NOT NULL,
  `alteration` TINYINT NOT NULL,
  PRIMARY KEY (`cnv_id`),
  INDEX `fk_cnv1_idx` (`entrez_gene_id` ASC),
  CONSTRAINT `fk_cnv1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `mainDB`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_cnv`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_cnv` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_cnv` (
  `cnv_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`attr_id`, `cnv_id`),
  INDEX `fk_meta_cnv1_idx` (`cnv_id` ASC),
  CONSTRAINT `fk_meta_cnv1`
    FOREIGN KEY (`cnv_id`)
    REFERENCES `mainDB`.`cnv` (`cnv_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`cnv_sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`cnv_sample` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`cnv_sample` (
  `cnv_sample_id` INT NOT NULL,
  `sample_id` INT NOT NULL,
  `cnv_id` INT NOT NULL,
  PRIMARY KEY (`cnv_sample_id`),
  INDEX `fk_cnv_sample2_idx` (`sample_id` ASC),
  CONSTRAINT `fk_cnv_sample1`
    FOREIGN KEY (`cnv_id`)
    REFERENCES `mainDB`.`cnv` (`cnv_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_cnv_sample2`
    FOREIGN KEY (`sample_id`)
    REFERENCES `mainDB`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`drug`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`drug` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`drug` (
  `iddrug` INT NOT NULL,
  PRIMARY KEY (`iddrug`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_drug`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_drug` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_drug` (
  `iddrug` INT NOT NULL,
  INDEX `fk_meta_drug_drug1_idx` (`iddrug` ASC),
  PRIMARY KEY (`iddrug`),
  CONSTRAINT `fk_meta_drug_drug1`
    FOREIGN KEY (`iddrug`)
    REFERENCES `mainDB`.`drug` (`iddrug`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`drug_target`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`drug_target` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`drug_target` (
  `drug_iddrug` INT NOT NULL,
  INDEX `fk_drug_target_drug1_idx` (`drug_iddrug` ASC),
  CONSTRAINT `fk_drug_target_drug1`
    FOREIGN KEY (`drug_iddrug`)
    REFERENCES `mainDB`.`drug` (`iddrug`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`drug_mechanism`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`drug_mechanism` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`drug_mechanism` (
  `iddrug` INT NOT NULL,
  PRIMARY KEY (`iddrug`),
  INDEX `fk_drug_mechanism1_idx` (`iddrug` ASC),
  CONSTRAINT `fk_drug_mechanism1`
    FOREIGN KEY (`iddrug`)
    REFERENCES `mainDB`.`drug` (`iddrug`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`gene_uniprot_map`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`gene_uniprot_map` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`gene_uniprot_map` (
  `uniprot_id` VARCHAR(255) NOT NULL,
  `uniprot_acc` VARCHAR(45) NOT NULL,
  `entrez_gene_id` INT NOT NULL,
  PRIMARY KEY (`uniprot_id`),
  INDEX `fk_uniport_id_mapping1_idx` (`entrez_gene_id` ASC),
  CONSTRAINT `fk_uniport_id_mapping1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `mainDB`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`history`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`history` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`history` (
  `history_id` INT NOT NULL,
  PRIMARY KEY (`history_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_variant_sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_variant_sample` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_variant_sample` (
  `variant_sample_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`variant_sample_id`, `attr_id`),
  CONSTRAINT `fk_meta_variant_sample1`
    FOREIGN KEY (`variant_sample_id`)
    REFERENCES `mainDB`.`variant_sample` (`variant_sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_predicted`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_predicted` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_predicted` (
  `predicted_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`predicted_id`, `attr_id`),
  CONSTRAINT `fk_meta_predicted1`
    FOREIGN KEY (`predicted_id`)
    REFERENCES `mainDB`.`predicted_cancer_type` (`predicted_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_cnv_sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_cnv_sample` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_cnv_sample` (
  `cnv_sample_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`cnv_sample_id`, `attr_id`),
  CONSTRAINT `fk_meta_cnv_sample1`
    FOREIGN KEY (`cnv_sample_id`)
    REFERENCES `mainDB`.`cnv_sample` (`cnv_sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`study_analysis_gene`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`study_analysis_gene` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`study_analysis_gene` (
  `study_analysis_gene_id` INT NOT NULL,
  `study_id` INT NOT NULL,
  `analysis` VARCHAR(45) NULL,
  `entrez_gene_id` INT NOT NULL,
  PRIMARY KEY (`study_analysis_gene_id`),
  INDEX `fk_study_analysis_gene1_idx` (`entrez_gene_id` ASC),
  INDEX `fk_study_analysis_gene2_idx` (`study_id` ASC),
  CONSTRAINT `fk_study_analysis_gene1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `mainDB`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_study_analysis_gene2`
    FOREIGN KEY (`study_id`)
    REFERENCES `mainDB`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_study_analysis_gene`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_study_analysis_gene` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_study_analysis_gene` (
  `study_analysis_gene_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`study_analysis_gene_id`, `attr_id`),
  CONSTRAINT `fk_meta_study_analysis_gene1`
    FOREIGN KEY (`study_analysis_gene_id`)
    REFERENCES `mainDB`.`study_analysis_gene` (`study_analysis_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`study_analysis`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`study_analysis` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`study_analysis` (
  `study_analysis_id` INT NOT NULL,
  `study_id` INT NOT NULL,
  `analysis` VARCHAR(45) NULL,
  PRIMARY KEY (`study_analysis_id`),
  INDEX `fk_study_analysis1_idx` (`study_id` ASC),
  CONSTRAINT `fk_study_analysis1`
    FOREIGN KEY (`study_id`)
    REFERENCES `mainDB`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mainDB`.`meta_study_analysis`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mainDB`.`meta_study_analysis` ;

CREATE TABLE IF NOT EXISTS `mainDB`.`meta_study_analysis` (
  `study_analysis_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`study_analysis_id`, `attr_id`),
  CONSTRAINT `fk_meta_study_analysis1`
    FOREIGN KEY (`study_analysis_id`)
    REFERENCES `mainDB`.`study_analysis` (`study_analysis_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

