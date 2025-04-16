--Creating file format object
CREATE OR REPLACE file format {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME};

-- See properties of file format object
DESC file format {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME};

--Using file format object in Copy command       
COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    file_format= (FORMAT_NAME={DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME})
    files = ('{FILE_NAME}.csv')
    ON_ERROR = 'SKIP_FILE_3'; 

--Altering file format object
ALTER file format {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME}
    SET SKIP_HEADER = 1;

--Defining properties on creation of file format object   
CREATE OR REPLACE file format {DATABASE_NAME}.{FILE_FORMAT_NAME}.{FORMAT_NAME}
    TYPE=JSON,
    TIME_FORMAT=AUTO;    
    
