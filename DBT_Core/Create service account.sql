-- 1) Create the role
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS SVC_SAMPLE_ROLE;

-- 2) Create the service user (set default role to the one that exists)
CREATE USER IF NOT EXISTS SVC_SAMPLE_DATA
  PASSWORD = 'Snowflake@2025'       -- for demo only; prefer key-pair auth in real setups
  DEFAULT_ROLE = SVC_SAMPLE_ROLE
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT = 'Service account for accessing Snowflake sample data';

-- 3) Grant role to service user
GRANT ROLE SVC_SAMPLE_ROLE TO USER SVC_SAMPLE_DATA;

-- 4) Grant imported privileges on the shared sample database (db-level only)
USE ROLE ACCOUNTADMIN;              -- or role with MANAGE GRANTS
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE SVC_SAMPLE_ROLE;

-- 5) Allow warehouse usage
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SVC_SAMPLE_ROLE;

-- 6) (Optional) Let your admin user test with that role
USE ROLE SECURITYADMIN;
GRANT ROLE SVC_SAMPLE_ROLE TO USER SVC_SAMPLE_DATA;

SELECT CURRENT_USER(), CURRENT_ROLE();

USE ROLE SECURITYADMIN;
GRANT ROLE SVC_SAMPLE_ROLE TO USER POOJAKONDAGOLI;



USE ROLE SVC_SAMPLE_ROLE;
USE WAREHOUSE COMPUTE_WH;       -- or your actual warehouse name
SELECT TOP 10 * 
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER;