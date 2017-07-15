#!/bin/bash
more $1 | sed 's/`//g' | sed 's/SET/-- SET/g' | sed 's/ENGINE/-- ENGINE/g' | sed 's/USE/-- USE/g' | sed 's/NO ACTION)/NO ACTION);/g' | sed 's/DEFAULT/; -- DEFAULT/g' | sed 's/))/));/g' | sed 's/INDEX /-- INDEX /g' | sed 's/BIGINT(.*)/BIGINT/g' | sed 's/TINYINT/SMALLINT/g' 

