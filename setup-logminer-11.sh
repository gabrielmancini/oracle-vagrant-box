#!/bin/sh

# Set archive log mode and enable GG replication
ORACLE_SID=ORCLCDB
export ORACLE_SID
sqlplus /nolog <<- EOF
	CONNECT sys/Oradoc_db1 AS SYSDBA
	alter system set db_recovery_file_dest_size = 10G;
	alter system set db_recovery_file_dest = '/u02/app/oracle/oradata/recovery_area' scope=spfile;
	shutdown immediate
	startup mount
	alter database archivelog;
	alter database open;
        -- Should show "Database log mode: Archive Mode"
	archive log list
	exit;
EOF

# Enable LogMiner required database features/settings
sqlplus sys/Oradoc_db1@ORCLCDB as sysdba <<- EOF
  ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
  ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS UNLIMITED;
  exit;
EOF

# Create Log Miner Tablespace and User
sqlplus sys/Oradoc_db1@ORCLCDB as sysdba <<- EOF
  CREATE TABLESPACE LOGMINER_TBS DATAFILE '/u02/app/oracle/oradata/ORCLCDB/logminer_tbs.dbf' SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
  exit;
EOF

sqlplus sys/Oradoc_db1@ORCLPDB1 as sysdba <<- EOF
  CREATE TABLESPACE LOGMINER_TBS DATAFILE '/u02/app/oracle/oradata/ORCLCDB/orclpdb1/logminer_tbs.dbf' SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
  exit;
EOF

sqlplus sys/Oradoc_db1@ORCLCDB as sysdba <<- EOF
  CREATE USER dbzuser IDENTIFIED BY dbz DEFAULT TABLESPACE LOGMINER_TBS QUOTA UNLIMITED ON LOGMINER_TBS CONTAINER=ALL;

  GRANT CREATE SESSION TO dbzuser CONTAINER=ALL;
  GRANT SET CONTAINER TO dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$DATABASE TO dbzuser CONTAINER=ALL;
  GRANT FLASHBACK ANY TABLE TO dbzuser CONTAINER=ALL;
  GRANT SELECT ANY TABLE TO dbzuser CONTAINER=ALL;
  GRANT SELECT_CATALOG_ROLE TO dbzuser CONTAINER=ALL;
  GRANT EXECUTE_CATALOG_ROLE TO dbzuser CONTAINER=ALL;
  GRANT SELECT ANY TRANSACTION TO dbzuser CONTAINER=ALL;
  GRANT SELECT ANY DICTIONARY TO dbzuser CONTAINER=ALL;
  GRANT LOGMINING TO dbzuser CONTAINER=ALL;

  GRANT CREATE TABLE TO dbzuser CONTAINER=ALL;
  GRANT LOCK ANY TABLE TO dbzuser CONTAINER=ALL;
  GRANT CREATE SEQUENCE TO dbzuser CONTAINER=ALL;

  GRANT EXECUTE ON DBMS_LOGMNR TO dbzuser CONTAINER=ALL;
  GRANT EXECUTE ON DBMS_LOGMNR_D TO dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$LOGMNR_LOGS TO dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$LOGMNR_CONTENTS TO dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$LOGFILE TO dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$ARCHIVED_LOG TO dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$ARCHIVE_DEST_STATUS TO dbzuser CONTAINER=ALL;

  exit;
EOF

sqlplus sys/Oradoc_db1@ORCLPDB1 as sysdba <<- EOF
  CREATE USER debezium IDENTIFIED BY dbz;
  GRANT CONNECT TO debezium;
  GRANT CREATE SESSION TO debezium;
  GRANT CREATE TABLE TO debezium;
  GRANT CREATE SEQUENCE to debezium;
  ALTER USER debezium QUOTA 100M on users;
  exit;
EOF
