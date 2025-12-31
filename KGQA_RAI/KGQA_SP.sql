CREATE OR REPLACE PROCEDURE KGQA(question STRING)
RETURNS TABLE (RESULT VARIANT)
LANGUAGE SQL
AS
$$
DECLARE
  model   STRING DEFAULT 'snowflake-llama-3.3-70b';
  p       STRING;
  gen_sql STRING;
  ok      BOOLEAN;
  rs      RESULTSET;
BEGIN
  /* Build the prompt */
  p := 'You are a Snowflake SQL generator. Output only ONE SELECT statement, no comments, no semicolons.' || '\n' ||
       '\n' ||
       'Tables:' || '\n' ||
       '  KG_NODES(NODE_ID STRING, NODE_TYPE STRING, PROPERTIES VARIANT)' || '\n' ||
       '  KG_EDGES(SRC_ID STRING, DST_ID STRING, EDGE_TYPE STRING, PROPERTIES VARIANT)' || '\n' ||
       '\n' ||
       'Node semantics:' || '\n' ||
       '  Post(title, content, published, source_url, siteurl, type)' || '\n' ||
       '  User(author)' || '\n' ||
       '  Platform(domain)' || '\n' ||
       '  Source(origin)' || '\n' ||
       '  Movie(name)' || '\n' ||
       '  Actor(name)' || '\n' ||
       '  Hashtag(text)' || '\n' ||
       '  Sentiment(polarity in {''positive'',''negative'',''neutral''})' || '\n' ||
       '  Question(text)' || '\n' ||
       '  Intent(flag in {true,false})' || '\n' ||
       '\n' ||
       'Edge semantics:' || '\n' ||
       '  POSTED_BY(Post -> User)' || '\n' ||
       '  ON_PLATFORM(Post -> Platform)' || '\n' ||
       '  FROM_SOURCE(Post -> Source)' || '\n' ||
       '  HAS_SENTIMENT(Post -> Sentiment)' || '\n' ||
       '  MENTIONS_MOVIE(Post -> Movie)' || '\n' ||
       '  MENTIONS_ACTOR(Post -> Actor)' || '\n' ||
       '  FEATURES_ACTOR(Movie -> Actor)' || '\n' ||
       '  USES_HASHTAG(Post -> Hashtag)' || '\n' ||
       '  ASKS_QUESTION(Post -> Question)' || '\n' ||
       '  HAS_INTENT(Post -> Intent)' || '\n' ||
       '\n' ||
       'Task:' || '\n' ||
       '  Generate a single SELECT to answer: "' || question || '"' || '\n' ||
       '  Prefer grouping/ordering for top-N style questions.' || '\n' ||
       '  Use PROPERTIES fields via colon access (e.g., PROPERTIES:polarity::string).';

  /* Ask the model for SQL */
  gen_sql := SNOWFLAKE.CORTEX.AI_COMPLETE(
                model            => model,
                prompt           => p,
                model_parameters => OBJECT_CONSTRUCT('temperature', 0.0, 'max_tokens', 2048),
                show_details     => FALSE
             );

  gen_sql := TRIM(gen_sql);

  /* Safety checks */
  ok := REGEXP_LIKE(gen_sql, '^\\s*(with\\b|select\\b)', 'is')
        AND NOT REGEXP_LIKE(gen_sql, '\\b(insert|update|delete|merge|grant|revoke|create|drop|alter|truncate|call)\\b', 'is')
        AND NOT REGEXP_LIKE(gen_sql, ';');

  IF (NOT ok) THEN
    rs := (
      SELECT
        OBJECT_CONSTRUCT(
          'message', 'Rejected unsafe SQL',
          'sql', :gen_sql
        )::VARIANT AS RESULT
    );
    RETURN TABLE(rs);
  END IF;

  /* Execute generated SQL */
  EXECUTE IMMEDIATE :gen_sql;

  /* Capture output and force single-column VARIANT result */
  rs := (
    SELECT
      OBJECT_CONSTRUCT(*)::VARIANT AS RESULT
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
  );

  RETURN TABLE(rs);
END;
$$;



SELECT * FROM TABLE(KGQA('top 10 hashtags used in positive posts'));

CALL KGQA('Which movie has the highest count of posts with positive sentiment?');

CALL KGQA('Which movie has the highest count of posts with positive sentiment?');


-- Example 1: Which movie has the highest count of posts with positive sentiment?
CALL KGQA('Which movie has the highest count of posts with positive sentiment?');

-- Example 2: Top 10 hashtags used in posts mentioning Fantastic Four
CALL KGQA('Top 10 hashtags used in posts mentioning Fantastic Four');

-- Example 3: Which actors are most co-mentioned with movies containing "Superman"?
CALL KGQA('Which actors are most co-mentioned with movies containing "Superman"?');

-- Example 4: Post counts with intent-to-watch true grouped by platform
CALL KGQA('Show post counts with intent-to-watch true grouped by platform domain');

SELECT T1.PROPERTIES:name::string 
FROM KG_NODES T1 
JOIN KG_EDGES T2 ON T1.NODE_ID = T2.DST_ID 
JOIN KG_EDGES T3 ON T2.SRC_ID = T3.SRC_ID 
JOIN KG_NODES T4 ON T3.DST_ID = T4.NODE_ID 
WHERE T2.EDGE_TYPE = 'MENTIONS_MOVIE' AND T3.EDGE_TYPE = 'HAS_SENTIMENT' AND T4.PROPERTIES:polarity::string = 'positive' 
GROUP BY T1.PROPERTIES:name::string 
ORDER BY COUNT(T1.NODE_ID) DESC LIMIT 1;

select * from enriched_movies
limit 20;
