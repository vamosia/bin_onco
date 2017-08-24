-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

-- -----------------------------------------------------
-- Schema maindb
-- -----------------------------------------------------
DROP SCHEMA IF EXISTS `maindb` ;

-- -----------------------------------------------------
-- Schema maindb
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `maindb` DEFAULT CHARACTER SET utf8 ;
USE `maindb` ;

-- -----------------------------------------------------
-- Table `maindb`.`study`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`study` ;

CREATE TABLE IF NOT EXISTS `maindb`.`study` (
  `study_id` INT NOT NULL,
  `source` VARCHAR(45) NOT NULL,
  `name` VARCHAR(255) NULL,
  `description` VARCHAR(255) NULL,
  PRIMARY KEY (`study_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`study_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`study_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`study_meta` (
  `study_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`study_id`, `attr_id`),
  INDEX `fk_study_meta1_idx` (`study_id` ASC),
  CONSTRAINT `fk_study_meta1`
    FOREIGN KEY (`study_id`)
    REFERENCES `maindb`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`patient`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`patient` ;

CREATE TABLE IF NOT EXISTS `maindb`.`patient` (
  `patient_id` INT NOT NULL,
  `stable_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`patient_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`patient_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`patient_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`patient_meta` (
  `patient_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`patient_id`, `attr_id`),
  INDEX `fk_patient_meta1_idx` (`patient_id` ASC),
  CONSTRAINT `fk_patient_meta1`
    FOREIGN KEY (`patient_id`)
    REFERENCES `maindb`.`patient` (`patient_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`gene`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`gene` ;

CREATE TABLE IF NOT EXISTS `maindb`.`gene` (
  `entrez_gene_id` INT NOT NULL,
  `hugo_gene_symbol` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`entrez_gene_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`variant`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`variant` ;

CREATE TABLE IF NOT EXISTS `maindb`.`variant` (
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
    REFERENCES `maindb`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`patient_study`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`patient_study` ;

CREATE TABLE IF NOT EXISTS `maindb`.`patient_study` (
  `patient_study_id` INT NOT NULL,
  `patient_id` INT NOT NULL,
  `study_id` INT NOT NULL,
  PRIMARY KEY (`patient_study_id`),
  INDEX `fk_patient_study1_idx` (`patient_id` ASC),
  INDEX `fk_patient_study2_idx` (`study_id` ASC),
  CONSTRAINT `fk_patient_study1`
    FOREIGN KEY (`patient_id`)
    REFERENCES `maindb`.`patient` (`patient_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_patient_study2`
    FOREIGN KEY (`study_id`)
    REFERENCES `maindb`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`cancer_type`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`cancer_type` ;

CREATE TABLE IF NOT EXISTS `maindb`.`cancer_type` (
  `cancer_id` VARCHAR(45) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `parent` VARCHAR(45) NULL,
  PRIMARY KEY (`cancer_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`sample` ;

CREATE TABLE IF NOT EXISTS `maindb`.`sample` (
  `sample_id` INT NOT NULL,
  `patient_study_id` INT NOT NULL,
  `stable_id` VARCHAR(45) NOT NULL,
  `cancer_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`sample_id`),
  INDEX `fk_sample1_idx` (`patient_study_id` ASC),
  INDEX `fk_sample2_idx` (`cancer_id` ASC),
  CONSTRAINT `fk_sample1`
    FOREIGN KEY (`patient_study_id`)
    REFERENCES `maindb`.`patient_study` (`patient_study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_sample2`
    FOREIGN KEY (`cancer_id`)
    REFERENCES `maindb`.`cancer_type` (`cancer_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`sample_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`sample_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`sample_meta` (
  `sample_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`sample_id`, `attr_id`),
  INDEX `fk_sample_meta1_idx` (`sample_id` ASC),
  CONSTRAINT `fk_sample_meta1`
    FOREIGN KEY (`sample_id`)
    REFERENCES `maindb`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`patient_event`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`patient_event` ;

CREATE TABLE IF NOT EXISTS `maindb`.`patient_event` (
  `event_id` INT NOT NULL,
  `patient_id` INT NOT NULL,
  `name` VARCHAR(45) NOT NULL,
  `start_date` DATE NULL,
  `end_date` DATE NULL,
  PRIMARY KEY (`event_id`),
  INDEX `fk_patient_timeline1_idx` (`patient_id` ASC),
  CONSTRAINT `fk_patient_timeline1`
    FOREIGN KEY (`patient_id`)
    REFERENCES `maindb`.`patient` (`patient_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`variant_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`variant_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`variant_meta` (
  `variant_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`variant_id`, `attr_id`),
  INDEX `fk_variant_meta1_idx` (`variant_id` ASC),
  CONSTRAINT `fk_variant_meta1`
    FOREIGN KEY (`variant_id`)
    REFERENCES `maindb`.`variant` (`variant_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`gene_alias`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`gene_alias` ;

CREATE TABLE IF NOT EXISTS `maindb`.`gene_alias` (
  `entrez_gene_id` INT NOT NULL,
  `gene_alias` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`entrez_gene_id`, `gene_alias`),
  CONSTRAINT `fk_gene_alias1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `maindb`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`info`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`info` ;

CREATE TABLE IF NOT EXISTS `maindb`.`info` (
  `db_schema_version` VARCHAR(45) NOT NULL,
  `last_update` VARCHAR(45) NULL,
  PRIMARY KEY (`db_schema_version`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`meta_list`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`meta_list` ;

CREATE TABLE IF NOT EXISTS `maindb`.`meta_list` (
  `meta_id` INT NOT NULL,
  PRIMARY KEY (`meta_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`patient_event_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`patient_event_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`patient_event_meta` (
  `event_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`event_id`, `attr_id`),
  INDEX `fk_patient_event_meta1_idx` (`event_id` ASC),
  CONSTRAINT `fk_patient_event_meta1`
    FOREIGN KEY (`event_id`)
    REFERENCES `maindb`.`patient_event` (`event_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`gene_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`gene_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`gene_meta` (
  `entrez_gene_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`entrez_gene_id`, `attr_id`),
  INDEX `fk_gene_meta1_idx` (`entrez_gene_id` ASC),
  CONSTRAINT `fk_gene_meta1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `maindb`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`predicted_cancer_type`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`predicted_cancer_type` ;

CREATE TABLE IF NOT EXISTS `maindb`.`predicted_cancer_type` (
  `predicted_id` INT NOT NULL,
  `sample_id` INT NOT NULL,
  `cancer_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`predicted_id`),
  INDEX `fk_predicted_cancer_type1_idx` (`sample_id` ASC),
  INDEX `fk_predicted_cancer_type2_idx` (`cancer_id` ASC),
  CONSTRAINT `fk_predicted_cancer_type1`
    FOREIGN KEY (`sample_id`)
    REFERENCES `maindb`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_predicted_cancer_type2`
    FOREIGN KEY (`cancer_id`)
    REFERENCES `maindb`.`cancer_type` (`cancer_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`cancer_study`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`cancer_study` ;

CREATE TABLE IF NOT EXISTS `maindb`.`cancer_study` (
  `study_id` INT NOT NULL,
  `cancer_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`study_id`, `cancer_id`),
  INDEX `fk_cancer_study1_idx` (`study_id` ASC),
  INDEX `fk_cancer_study2_idx` (`cancer_id` ASC),
  CONSTRAINT `fk_cancer_study1`
    FOREIGN KEY (`study_id`)
    REFERENCES `maindb`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_cancer_study2`
    FOREIGN KEY (`cancer_id`)
    REFERENCES `maindb`.`cancer_type` (`cancer_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`cnv`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`cnv` ;

CREATE TABLE IF NOT EXISTS `maindb`.`cnv` (
  `cnv_id` INT NOT NULL,
  `entrez_gene_id` INT NOT NULL,
  `alteration` TINYINT NOT NULL,
  PRIMARY KEY (`cnv_id`),
  INDEX `fk_cnv1_idx` (`entrez_gene_id` ASC),
  CONSTRAINT `fk_cnv1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `maindb`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`cnv_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`cnv_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`cnv_meta` (
  `cnv_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`cnv_id`, `attr_id`),
  INDEX `fk_cnv_meta1_idx` (`cnv_id` ASC),
  CONSTRAINT `fk_cnv_meta1`
    FOREIGN KEY (`cnv_id`)
    REFERENCES `maindb`.`cnv` (`cnv_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`cnv_sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`cnv_sample` ;

CREATE TABLE IF NOT EXISTS `maindb`.`cnv_sample` (
  `cnv_sample_id` INT NOT NULL,
  `sample_id` INT NOT NULL,
  `cnv_id` INT NOT NULL,
  PRIMARY KEY (`cnv_sample_id`),
  INDEX `fk_cnv_sample2_idx` (`sample_id` ASC),
  CONSTRAINT `fk_cnv_sample1`
    FOREIGN KEY (`cnv_id`)
    REFERENCES `maindb`.`cnv` (`cnv_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_cnv_sample2`
    FOREIGN KEY (`sample_id`)
    REFERENCES `maindb`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`drug`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`drug` ;

CREATE TABLE IF NOT EXISTS `maindb`.`drug` (
  `iddrug` INT NOT NULL,
  PRIMARY KEY (`iddrug`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`drug_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`drug_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`drug_meta` (
  `iddrug` INT NOT NULL,
  PRIMARY KEY (`iddrug`),
  CONSTRAINT `fk_drug_meta1`
    FOREIGN KEY (`iddrug`)
    REFERENCES `maindb`.`drug` (`iddrug`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`drug_target`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`drug_target` ;

CREATE TABLE IF NOT EXISTS `maindb`.`drug_target` (
  `drug_iddrug` INT NOT NULL,
  INDEX `fk_drug_target_drug1_idx` (`drug_iddrug` ASC),
  CONSTRAINT `fk_drug_target_drug1`
    FOREIGN KEY (`drug_iddrug`)
    REFERENCES `maindb`.`drug` (`iddrug`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`drug_mechanism`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`drug_mechanism` ;

CREATE TABLE IF NOT EXISTS `maindb`.`drug_mechanism` (
  `iddrug` INT NOT NULL,
  PRIMARY KEY (`iddrug`),
  INDEX `fk_drug_mechanism1_idx` (`iddrug` ASC),
  CONSTRAINT `fk_drug_mechanism1`
    FOREIGN KEY (`iddrug`)
    REFERENCES `maindb`.`drug` (`iddrug`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`gene_uniprot_map`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`gene_uniprot_map` ;

CREATE TABLE IF NOT EXISTS `maindb`.`gene_uniprot_map` (
  `uniprot_id` VARCHAR(255) NOT NULL,
  `uniprot_acc` VARCHAR(45) NOT NULL,
  `entrez_gene_id` INT NOT NULL,
  PRIMARY KEY (`uniprot_id`),
  INDEX `fk_uniport_id_mapping1_idx` (`entrez_gene_id` ASC),
  CONSTRAINT `fk_uniport_id_mapping1`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `maindb`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`history`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`history` ;

CREATE TABLE IF NOT EXISTS `maindb`.`history` (
  `history_id` INT NOT NULL,
  PRIMARY KEY (`history_id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`variant_sample`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`variant_sample` ;

CREATE TABLE IF NOT EXISTS `maindb`.`variant_sample` (
  `variant_sample_id` INT NOT NULL,
  `sample_id` INT NOT NULL,
  `variant_id` INT NOT NULL,
  PRIMARY KEY (`variant_sample_id`),
  INDEX `fk_variant_sample1_idx` (`sample_id` ASC),
  INDEX `fk_variant_sample2_idx` (`variant_id` ASC),
  CONSTRAINT `fk_variant_sample1`
    FOREIGN KEY (`sample_id`)
    REFERENCES `maindb`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_variant_sample2`
    FOREIGN KEY (`variant_id`)
    REFERENCES `maindb`.`variant` (`variant_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`variant_sample_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`variant_sample_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`variant_sample_meta` (
  `variant_sample_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`variant_sample_id`, `attr_id`),
  INDEX `fk_variant_sample_meta1_idx` (`variant_sample_id` ASC),
  CONSTRAINT `fk_variant_sample_meta1`
    FOREIGN KEY (`variant_sample_id`)
    REFERENCES `maindb`.`variant_sample` (`variant_sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`predicted_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`predicted_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`predicted_meta` (
  `predicted_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`predicted_id`, `attr_id`),
  INDEX `fk_predicted_meta1_idx` (`predicted_id` ASC),
  CONSTRAINT `fk_predicted_meta1`
    FOREIGN KEY (`predicted_id`)
    REFERENCES `maindb`.`predicted_cancer_type` (`predicted_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`cnv_sample_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`cnv_sample_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`cnv_sample_meta` (
  `cnv_sample_id` INT NOT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`cnv_sample_id`, `attr_id`),
  INDEX `fk_cnv_sample_meta1_idx` (`cnv_sample_id` ASC),
  CONSTRAINT `fk_cnv_sample_meta1`
    FOREIGN KEY (`cnv_sample_id`)
    REFERENCES `maindb`.`cnv_sample` (`cnv_sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`analysis`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`analysis` ;

CREATE TABLE IF NOT EXISTS `maindb`.`analysis` (
  `analysis_id` INT NOT NULL,
  `study_id` INT NOT NULL,
  `sample_id` INT NULL,
  `name` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`analysis_id`),
  INDEX `fk_study_analysis1_idx` (`study_id` ASC),
  INDEX `fk_study_analysis2_idx` (`sample_id` ASC),
  CONSTRAINT `fk_study_analysis1`
    FOREIGN KEY (`study_id`)
    REFERENCES `maindb`.`study` (`study_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_study_analysis2`
    FOREIGN KEY (`sample_id`)
    REFERENCES `maindb`.`sample` (`sample_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`analysis_data`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`analysis_data` ;

CREATE TABLE IF NOT EXISTS `maindb`.`analysis_data` (
  `meta_id` INT NOT NULL,
  `analysis_id` INT NOT NULL,
  `entrez_gene_id` INT NULL,
  `attr_id` VARCHAR(255) NOT NULL,
  `attr_value` VARCHAR(255) NULL,
  PRIMARY KEY (`meta_id`, `analysis_id`, `attr_id`),
  INDEX `fk_table12_idx` (`entrez_gene_id` ASC),
  INDEX `fk_analysis_gene_meta1_idx` (`analysis_id` ASC),
  CONSTRAINT `fk_table12`
    FOREIGN KEY (`entrez_gene_id`)
    REFERENCES `maindb`.`gene` (`entrez_gene_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_analysis_gene_meta1`
    FOREIGN KEY (`analysis_id`)
    REFERENCES `maindb`.`analysis` (`analysis_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `maindb`.`analysis_meta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `maindb`.`analysis_meta` ;

CREATE TABLE IF NOT EXISTS `maindb`.`analysis_meta` (
  `analysis_id` INT NOT NULL,
  `attr_id` VARCHAR(45) NOT NULL,
  `attr_value` VARCHAR(45) NULL,
  PRIMARY KEY (`analysis_id`, `attr_id`),
  INDEX `fk_analysis_meta1_idx` (`analysis_id` ASC),
  CONSTRAINT `fk_analysis_meta1`
    FOREIGN KEY (`analysis_id`)
    REFERENCES `maindb`.`analysis` (`analysis_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
