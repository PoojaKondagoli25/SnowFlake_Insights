--This option tells Snowflake to truncate (cut off) data in a column if it exceeds the column's defined length, instead of throwing an error.

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    pattern='.*Order.*'
    TRUNCATECOLUMNS = true; 