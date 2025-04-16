--This option is used with the COPY INTO <location> command, not COPY INTO <table>, to export only failed rows from a previous load.

COPY INTO {DATABASE_NAME}.{SCHEMA_NAME}.{TABLE_NAME}
    FROM @{STAGE_NAME}
    file_format= (type = csv field_delimiter=',' skip_header=1)
    ON_ERROR =CONTINUE
    RETURN_FAILED_ONLY = TRUE;