
-- Use an admin role with grant privileges
USE ROLE ACCOUNTADMIN;

-- Grant the Cortex database role to a working role (replace YOUR_ROLE)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACCOUNTADMIN;  -- enables LLM functions
GRANT ROLE YOUR_ROLE TO USER YOUR_USER;                       -- assign to you
-- If your org opted-out from PUBLIC, the above grant is necessary. [4](https://docs.snowflake.com/en/en/user-guide/snowflake-cortex/cortex-rest-api)

-- Switch to your working role & warehouse
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- Create a working database/schema
CREATE DATABASE IF NOT EXISTS KGQA_DEMO;
CREATE SCHEMA IF NOT EXISTS KGQA_DEMO.PUBLIC;
USE DATABASE DEV_DB;
USE SCHEMA DBT_LEARNING;

-- (Optional) make error handling for AI functions tolerant for batch ops
ALTER SESSION SET AI_SQL_ERROR_HANDLING_USE_FAIL_ON_ERROR = false;  -- continue on row errors [2](https://docs.snowflake.com/en/sql-reference/functions/ai_complete)


-- See columns we have (adjust object path if needed)
DESC VIEW MOVIE_VIEWS;

-- Quick sample
SELECT * FROM MOVIE_VIEWS LIMIT 20;



CREATE OR REPLACE VIEW DEV_DB.DBT_LEARNING.ENRICHED_MOVIES AS
SELECT
  MD5(
    COALESCE(SOURCE_URL, SITEURL, '') || '|' ||
    COALESCE(TITLE, CONTENT, '')      || '|' ||
    COALESCE(AUTHOR, '')              || '|' ||
    COALESCE(TO_VARCHAR(PUBLISHED), '')
  ) AS POST_ID,

  CONTENT, TITLE, AUTHOR, SITEURL, SOURCE, SOURCE_DOMAIN, SOURCE_URL, TYPE,
  PUBLISHED, FILMS, ACTOR_MENTIONS, QUESTIONS, INTENT_TO_WATCH,

  /* Sentiment */
  SNOWFLAKE.CORTEX.AI_SENTIMENT(CONTENT) AS SENTIMENT_LABEL,

  /* Structured extraction via AI_COMPLETE with response_format (single-string variant) */
  SNOWFLAKE.CORTEX.AI_COMPLETE(
    model           => 'snowflake-llama-3.3-70b',
    prompt          => 'Return ONLY a JSON object: {"hashtags": []} extracted from this text. ' ||
                       'Include tokens starting with #; do not add other keys. Text: ' || CONTENT,
    -- optional tuning; keep deterministic and limit tokens
    model_parameters=> OBJECT_CONSTRUCT('temperature', 0.0, 'max_tokens', 256),
    ---temp: creativity level(sometime it assumes and give) max_tokens:output parameter length
    -- response_format must be a SQL sub-object (JSON schema), not a string
    response_format => OBJECT_CONSTRUCT(
                         'type','json',
                         'schema', OBJECT_CONSTRUCT(
                           'type','object',
                           'properties', OBJECT_CONSTRUCT(
                             'hashtags', OBJECT_CONSTRUCT(
                               'type','array',
                               'items', OBJECT_CONSTRUCT('type','string')
                             )
                           ),
                           'required', ARRAY_CONSTRUCT('hashtags')
                         )
                       ),
    show_details    => FALSE
  ) AS EXTRACT_HASHTAGS
FROM DEV_DB.DBT_LEARNING.MOVIES;

SELECT * FROM enriched_movies LIMIT 20;


CREATE OR REPLACE TABLE KG_NODES (
  NODE_ID     STRING,
  NODE_TYPE   STRING,   -- Post | User | Platform | Source | Movie | Actor | Hashtag | Sentiment | Question | Intent
  PROPERTIES  VARIANT
);

CREATE OR REPLACE TABLE KG_EDGES (
  SRC_ID      STRING,
  DST_ID      STRING,
  EDGE_TYPE   STRING,   -- POSTED_BY | ON_PLATFORM | FROM_SOURCE | MENTIONS_MOVIE | MENTIONS_ACTOR | USES_HASHTAG | HAS_SENTIMENT | ASKS_QUESTION | HAS_INTENT
  PROPERTIES  VARIANT
);

TRUNCATE TABLE KG_NODES;
TRUNCATE TABLE KG_EDGES;


/* Post nodes */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  POST_ID, 'Post',
  OBJECT_CONSTRUCT(
    'title', TITLE,
    'content', CONTENT,
    'published', PUBLISHED,
    'source_url', SOURCE_URL,
    'siteurl', SITEURL,
    'type', TYPE
  )
FROM ENRICHED_MOVIES;

/* User (author) nodes */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  AUTHOR, 'User',
  OBJECT_CONSTRUCT('source', 'MOVIES')
FROM ENRICHED_MOVIES
WHERE AUTHOR IS NOT NULL;

/* Platform (domain) nodes */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  SOURCE_DOMAIN, 'Platform',
  OBJECT_CONSTRUCT('source', 'MOVIES')
FROM ENRICHED_MOVIES
WHERE SOURCE_DOMAIN IS NOT NULL;

/* Source (logical origin) nodes */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  SOURCE, 'Source',
  OBJECT_CONSTRUCT('source', 'MOVIES')
FROM ENRICHED_MOVIES
WHERE SOURCE IS NOT NULL;

/* Sentiment nodes */

/* Sentiment nodes */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  'sentiment::' || LOWER(SENTIMENT_LABEL::STRING) AS NODE_ID,
  'Sentiment' AS NODE_TYPE,
  OBJECT_CONSTRUCT('polarity', SENTIMENT_LABEL::STRING) AS PROPERTIES
FROM ENRICHED_MOVIES
WHERE SENTIMENT_LABEL::STRING IS NOT NULL;


/* Movie nodes (from FILMS array) */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  CAST(f.VALUE AS STRING), 'Movie',
  OBJECT_CONSTRUCT('source', 'FILMS_column')
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => FILMS) f
WHERE f.VALUE IS NOT NULL;

/* Actor nodes (from ACTOR_MENTIONS array) */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  CAST(a.VALUE AS STRING), 'Actor',
  OBJECT_CONSTRUCT('source', 'ACTOR_MENTIONS_column')
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => ACTOR_MENTIONS) a
WHERE a.VALUE IS NOT NULL;

/* Hashtag nodes (from AI_EXTRACT output) */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  CAST(h.VALUE AS STRING), 'Hashtag',
  OBJECT_CONSTRUCT('source', 'AI_EXTRACT')
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => EXTRACT_HASHTAGS:hashtags) h
WHERE h.VALUE IS NOT NULL;

/* Question nodes (from QUESTIONS array) */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  CAST(q.VALUE AS STRING), 'Question',
  OBJECT_CONSTRUCT('source', 'QUESTIONS_column')
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => QUESTIONS) q
WHERE q.VALUE IS NOT NULL;

/* Intent nodes (boolean -> two nodes) */
INSERT INTO KG_NODES (NODE_ID, NODE_TYPE, PROPERTIES)
SELECT DISTINCT
  'intent::' || IFF(INTENT_TO_WATCH, 'true', 'false') AS NODE_ID,
  'Intent',
  OBJECT_CONSTRUCT('flag', INTENT_TO_WATCH)
FROM ENRICHED_MOVIES
WHERE INTENT_TO_WATCH IS NOT NULL;


/* POSTED_BY: Post -> User */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID, AUTHOR, 'POSTED_BY',
       OBJECT_CONSTRUCT('source', 'MOVIES')
FROM ENRICHED_MOVIES
WHERE AUTHOR IS NOT NULL;

/* ON_PLATFORM: Post -> Platform (domain) */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID, SOURCE_DOMAIN, 'ON_PLATFORM',
       OBJECT_CONSTRUCT('source', 'MOVIES')
FROM ENRICHED_MOVIES
WHERE SOURCE_DOMAIN IS NOT NULL;

/* FROM_SOURCE: Post -> Source (logical origin) */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID, SOURCE, 'FROM_SOURCE',
       OBJECT_CONSTRUCT('source', 'MOVIES')
FROM ENRICHED_MOVIES
WHERE SOURCE IS NOT NULL;

/* HAS_SENTIMENT: Post -> Sentiment */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID,
       'sentiment::' || LOWER(SENTIMENT_LABEL::STRING),
       'HAS_SENTIMENT',
       OBJECT_CONSTRUCT('derived_by', 'AI_SENTIMENT')
FROM ENRICHED_MOVIES
WHERE SENTIMENT_LABEL IS NOT NULL;

/* MENTIONS_MOVIE: Post -> Movie */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID, CAST(f.VALUE AS STRING), 'MENTIONS_MOVIE',
       OBJECT_CONSTRUCT('derived_from', 'FILMS')
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => FILMS) f
WHERE f.VALUE IS NOT NULL;

/* MENTIONS_ACTOR: Post -> Actor (direct) */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID, CAST(a.VALUE AS STRING), 'MENTIONS_ACTOR',
       OBJECT_CONSTRUCT('derived_from', 'ACTOR_MENTIONS')
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => ACTOR_MENTIONS) a
WHERE a.VALUE IS NOT NULL;

/* FEATURES_ACTOR: Movie -> Actor (co-mention within same post) */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT CAST(f.VALUE AS STRING) AS MOVIE_ID,
       CAST(a.VALUE AS STRING) AS ACTOR_ID,
       'FEATURES_ACTOR',
       OBJECT_CONSTRUCT('co_mentioned_in_post', POST_ID)
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => FILMS)          f,
     LATERAL FLATTEN(input => ACTOR_MENTIONS) a
WHERE f.VALUE IS NOT NULL AND a.VALUE IS NOT NULL;

/* USES_HASHTAG: Post -> Hashtag */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID, CAST(h.VALUE AS STRING), 'USES_HASHTAG',
       OBJECT_CONSTRUCT('derived_by', 'AI_EXTRACT')
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => EXTRACT_HASHTAGS:hashtags) h
WHERE h.VALUE IS NOT NULL;

/* ASKS_QUESTION: Post -> Question */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID, CAST(q.VALUE AS STRING), 'ASKS_QUESTION',
       OBJECT_CONSTRUCT('derived_from', 'QUESTIONS')
FROM ENRICHED_MOVIES,
     LATERAL FLATTEN(input => QUESTIONS) q
WHERE q.VALUE IS NOT NULL;

/* HAS_INTENT: Post -> Intent node (true/false) */
INSERT INTO KG_EDGES (SRC_ID, DST_ID, EDGE_TYPE, PROPERTIES)
SELECT POST_ID,
       'intent::' || IFF(INTENT_TO_WATCH, 'true', 'false'),
       'HAS_INTENT',
       OBJECT_CONSTRUCT('source', 'MOVIES')
FROM ENRICHED_MOVIES
WHERE INTENT_TO_WATCH IS NOT NULL;


select * from kg_nodes
limit 5;

select * from kg_edges
limit 5;






