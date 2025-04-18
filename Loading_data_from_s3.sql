--Create table first
CREATE OR REPLACE TABLE {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}( 
  show_id STRING,
  type STRING,
  title STRING,
  director STRING,
  cast STRING,
  country STRING,
  date_added STRING,
  release_year STRING,
  rating STRING,
  duration STRING,
  listed_in STRING,
  description STRING )

--Create file format object
--null_if=('Null','null'): if there are any emplty values then it will replace with null
CREATE OR REPLACE file format {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME}
    type = csv
    field_delimiter = ','
    skip_header = 1
    null_if = ('NULL','null')
    empty_field_as_null = TRUE;

-- Create stage object with integration object & file format object
CREATE OR REPLACE {DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    URL = 's3://<your-bucket-name>/<your-path>/'
    STORAGE_INTEGRATION = s3_int
    FILE_FORMAT = {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME}

--Use Copy command       
COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}

--Create file format object
--FIELD_OPTIONALLY_ENCLOSED_BY = '"'  : if any columns contains like "abc,xyz,qwe" then this is used to separate them
CREATE OR REPLACE file format {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME}
    type = csv
    field_delimiter = ','
    skip_header = 1
    null_if = ('NULL','null')
    empty_field_as_null = TRUE    
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'; 

SELECT * FROM {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME};
    

    
