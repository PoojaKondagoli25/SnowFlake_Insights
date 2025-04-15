--Error handling using the ON_ERROR CONTINUE option
/*This tells Snowflake to skip rows that cause errors during the load.
It continues loading all other valid rows from the file(s).
It doesn’t abort the statement — instead, it logs the errors and goes on.*/

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('{FILE_NAME}.csv')
    ON_ERROR = 'CONTINUE';

--Error handling using the ON_ERROR option = ABORT_STATEMENT (default)
/*ABORT_STATEMENT is the default behavior.
If any error occurs while loading any of the specified files, the entire COPY INTO statement fails.
No rows will be loaded at all, even if only a single row from one file has an issue.*/

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('{FILE_NAME_1}.csv','{FILE_NAME_2}.csv')
    ON_ERROR = 'ABORT_STATEMENT';

--Error handling using the ON_ERROR option = SKIP_FILE
/*If any error is encountered in a file, that entire file is skipped.
Snowflake does not load any rows from that file—even if only one row is bad.
It continues processing the other files in the list.
*/

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('{FILE_NAME_1}.csv','{FILE_NAME_2}.csv')
    ON_ERROR = 'SKIP_FILE';

--Error handling using the ON_ERROR option = SKIP_FILE_<number>
/*"Skip the file only if it has more than 2 errors."
If a file has 0, 1, or 2 errors, it still gets loaded (bad rows are skipped).
If a file has more than 2 errors, the entire file is skipped.*/

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('{FILE_NAME_1}.csv','{FILE_NAME_2}.csv')
    ON_ERROR = 'SKIP_FILE_2';   

--Error handling using the ON_ERROR and size limit
/*Limits the maximum size (in MB) of data loaded per file.
Any file larger than 30 MB will be skipped and not processed.
*/

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{DATABASE_NAME}.{SCHEMA_NAME}.{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('{FILE_NAME_1}.csv','{FILE_NAME_2}.csv')
    ON_ERROR = SKIP_FILE_3 
    SIZE_LIMIT = 30;
