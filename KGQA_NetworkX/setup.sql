-- =====================================================
-- Snowflake Knowledge Graph Database for Soccer
-- =====================================================
-- This script creates a complete knowledge graph database
-- for soccer data using the node-edge pattern for maximum flexibility

-- Create database and schema
CREATE OR REPLACE DATABASE KNOWLEDGE_GRAPH_DB;
USE DATABASE KNOWLEDGE_GRAPH_DB;

CREATE OR REPLACE SCHEMA SOCCER_KG;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- STAGE FOR SEMANTIC MODEL
-- =====================================================
CREATE OR REPLACE STAGE SEMANTIC_MODEL
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for storing Cortex Analyst semantic model YAML files';

-- =====================================================
-- CORE NODE-EDGE TABLES
-- =====================================================

-- =========================
-- Core node table
-- =========================
CREATE OR REPLACE TABLE KG_NODE (
    NODE_ID      STRING          NOT NULL,        -- stable global id
    NODE_TYPE    STRING          NOT NULL,        -- e.g., PLAYER | COACH | CLUB | MATCH
    NAME         STRING,
    PROPS        VARIANT,                          -- flexible attributes per type
    TS_INGESTED  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_KG_NODE PRIMARY KEY (NODE_ID)
)
CLUSTER BY (NODE_TYPE);

COMMENT ON TABLE KG_NODE IS 'All entities (players, coaches, clubs, matches).';

-- =========================
-- Core edge table (directed)
-- =========================
CREATE OR REPLACE TABLE KG_EDGE (
    EDGE_ID          STRING          NOT NULL,      -- can be a hash of (src, dst, type, start)
    SRC_ID           STRING          NOT NULL,
    DST_ID           STRING          NOT NULL,
    EDGE_TYPE        STRING          NOT NULL,      -- e.g., PLAYS_FOR | COACHES | PLAYED_IN
    WEIGHT           FLOAT DEFAULT 1.0,
    PROPS            VARIANT,
    EFFECTIVE_START  DATE,
    EFFECTIVE_END    DATE,
    TS_INGESTED      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_KG_EDGE PRIMARY KEY (EDGE_ID)
)
CLUSTER BY (EDGE_TYPE, SRC_ID, DST_ID);

COMMENT ON TABLE KG_EDGE IS 'All relationships between nodes; time-bounded where relevant.';

-- =====================================================
-- CONVENIENCE ENTITY VIEWS (TYPE SLICES OVER NODES)
-- =====================================================

-- Players
CREATE OR REPLACE VIEW V_PLAYER AS
SELECT
    NODE_ID,
    NAME,
    PROPS:position::STRING     AS POSITION,
    PROPS:nationality::STRING  AS NATIONALITY,
    PROPS:birthdate::DATE      AS BIRTHDATE,
    PROPS
FROM KG_NODE
WHERE NODE_TYPE = 'PLAYER';

-- Coaches
CREATE OR REPLACE VIEW V_COACH AS
SELECT
    NODE_ID,
    NAME,
    PROPS:nationality::STRING   AS NATIONALITY,
    PROPS:license_level::STRING AS LICENSE_LEVEL,
    PROPS
FROM KG_NODE
WHERE NODE_TYPE = 'COACH';

-- Clubs
CREATE OR REPLACE VIEW V_CLUB AS
SELECT
    NODE_ID,
    NAME,
    PROPS:league::STRING  AS LEAGUE,
    PROPS:country::STRING AS COUNTRY,
    PROPS:stadium::STRING AS STADIUM,
    PROPS:founded_year::INT AS FOUNDED_YEAR,
    PROPS
FROM KG_NODE
WHERE NODE_TYPE = 'CLUB';

-- Matches
CREATE OR REPLACE VIEW V_MATCH AS
SELECT
    NODE_ID,
    NAME,
    PROPS:event_date::DATE AS EVENT_DATE,
    PROPS:venue::STRING    AS VENUE,
    PROPS:score_home::INT  AS SCORE_HOME,
    PROPS:score_away::INT  AS SCORE_AWAY,
    PROPS:competition::STRING AS COMPETITION,
    PROPS
FROM KG_NODE
WHERE NODE_TYPE = 'MATCH';

-- =====================================================
-- RELATIONSHIP VIEWS (EDGE SLICES, NORMALIZED KEYS)
-- =====================================================

-- Player -> Club
CREATE OR REPLACE VIEW V_PLAYS_FOR AS
SELECT
    SRC_ID                AS PLAYER_ID,
    DST_ID                AS CLUB_ID,
    EDGE_TYPE,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS:jersey_number::INT AS JERSEY_NUMBER,
    PROPS:contract_value::DECIMAL(15,2) AS CONTRACT_VALUE,
    PROPS
FROM KG_EDGE
WHERE EDGE_TYPE = 'PLAYS_FOR';

-- Coach -> Club
CREATE OR REPLACE VIEW V_COACHES AS
SELECT
    SRC_ID                AS COACH_ID,
    DST_ID                AS CLUB_ID,
    EDGE_TYPE,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS:contract_value::DECIMAL(15,2) AS CONTRACT_VALUE,
    PROPS
FROM KG_EDGE
WHERE EDGE_TYPE = 'COACHES';

-- Player -> Match
CREATE OR REPLACE VIEW V_PLAYED_IN AS
SELECT
    SRC_ID                AS PLAYER_ID,
    DST_ID                AS MATCH_ID,
    EDGE_TYPE,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS:minutes_played::INT AS MINUTES_PLAYED,
    PROPS:goals_scored::INT AS GOALS_SCORED,
    PROPS:assists::INT AS ASSISTS,
    PROPS:yellow_cards::INT AS YELLOW_CARDS,
    PROPS:red_cards::INT AS RED_CARDS,
    PROPS
FROM KG_EDGE
WHERE EDGE_TYPE = 'PLAYED_IN';

-- Club -> Match (Home team)
CREATE OR REPLACE VIEW V_HOME_TEAM AS
SELECT
    SRC_ID                AS CLUB_ID,
    DST_ID                AS MATCH_ID,
    EDGE_TYPE,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS
FROM KG_EDGE
WHERE EDGE_TYPE = 'HOME_TEAM';

-- Club -> Match (Away team)
CREATE OR REPLACE VIEW V_AWAY_TEAM AS
SELECT
    SRC_ID                AS CLUB_ID,
    DST_ID                AS MATCH_ID,
    EDGE_TYPE,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS
FROM KG_EDGE
WHERE EDGE_TYPE = 'AWAY_TEAM';

-- =====================================================
-- SAMPLE DATA INSERTION
-- =====================================================

-- Insert CLUBS as nodes
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT column1, column2, column3, PARSE_JSON(column4)
FROM VALUES
    ('club_1', 'CLUB', 'Real Madrid', '{"country":"Spain","stadium":"Santiago Bernabéu","founded_year":1902,"league":"La Liga"}'),
    ('club_2', 'CLUB', 'Manchester City', '{"country":"England","stadium":"Etihad Stadium","founded_year":1880,"league":"Premier League"}'),
    ('club_3', 'CLUB', 'Liverpool', '{"country":"England","stadium":"Anfield","founded_year":1892,"league":"Premier League"}'),
    ('club_4', 'CLUB', 'Paris Saint-Germain', '{"country":"France","stadium":"Parc des Princes","founded_year":1970,"league":"Ligue 1"}'),
    ('club_5', 'CLUB', 'Inter Miami CF', '{"country":"USA","stadium":"Chase Stadium","founded_year":2018,"league":"MLS"}'),
    ('club_6', 'CLUB', 'Al Nassr', '{"country":"Saudi Arabia","stadium":"Al-Awwal Park","founded_year":1955,"league":"Saudi Pro League"}'),
    ('club_7', 'CLUB', 'Bayern Munich', '{"country":"Germany","stadium":"Allianz Arena","founded_year":1900,"league":"Bundesliga"}'),
    ('club_8', 'CLUB', 'Arsenal', '{"country":"England","stadium":"Emirates Stadium","founded_year":1886,"league":"Premier League"}'),
    ('club_9', 'CLUB', 'Chelsea', '{"country":"England","stadium":"Stamford Bridge","founded_year":1905,"league":"Premier League"}'),
    ('club_10', 'CLUB', 'Barcelona', '{"country":"Spain","stadium":"Camp Nou","founded_year":1899,"league":"La Liga"}'),
    ('club_11', 'CLUB', 'Atletico Madrid', '{"country":"Spain","stadium":"Wanda Metropolitano","founded_year":1903,"league":"La Liga"}'),
    ('club_12', 'CLUB', 'AC Milan', '{"country":"Italy","stadium":"San Siro","founded_year":1899,"league":"Serie A"}'),
    ('club_13', 'CLUB', 'Juventus', '{"country":"Italy","stadium":"Allianz Stadium","founded_year":1897,"league":"Serie A"}'),
    ('club_14', 'CLUB', 'Inter Milan', '{"country":"Italy","stadium":"San Siro","founded_year":1908,"league":"Serie A"}'),
    ('club_15', 'CLUB', 'Borussia Dortmund', '{"country":"Germany","stadium":"Signal Iduna Park","founded_year":1909,"league":"Bundesliga"}');

-- Insert PLAYERS as nodes
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT column1, column2, column3, PARSE_JSON(column4)
FROM VALUES
-- Current Stars
    ('player_1', 'PLAYER', 'Kylian Mbappé', '{"nationality":"France","position":"Forward","birthdate":"1998-12-20"}'),
    ('player_2', 'PLAYER', 'Erling Haaland', '{"nationality":"Norway","position":"Forward","birthdate":"2000-07-21"}'),
    ('player_3', 'PLAYER', 'Jude Bellingham', '{"nationality":"England","position":"Midfielder","birthdate":"2003-06-29"}'),
    ('player_4', 'PLAYER', 'Virgil van Dijk', '{"nationality":"Netherlands","position":"Defender","birthdate":"1991-07-08"}'),
    ('player_5', 'PLAYER', 'Lionel Messi', '{"nationality":"Argentina","position":"Forward","birthdate":"1987-06-24"}'),
    ('player_6', 'PLAYER', 'Cristiano Ronaldo', '{"nationality":"Portugal","position":"Forward","birthdate":"1985-02-05"}'),
    ('player_7', 'PLAYER', 'Kevin De Bruyne', '{"nationality":"Belgium","position":"Midfielder","birthdate":"1991-06-28"}'),
    ('player_8', 'PLAYER', 'Mohamed Salah', '{"nationality":"Egypt","position":"Forward","birthdate":"1992-06-15"}'),
    ('player_9', 'PLAYER', 'Sadio Mané', '{"nationality":"Senegal","position":"Forward","birthdate":"1992-04-10"}'),
    ('player_10', 'PLAYER', 'Luka Modrić', '{"nationality":"Croatia","position":"Midfielder","birthdate":"1985-09-09"}'),
    ('player_11', 'PLAYER', 'Toni Kroos', '{"nationality":"Germany","position":"Midfielder","birthdate":"1990-01-04"}'),
    ('player_12', 'PLAYER', 'Casemiro', '{"nationality":"Brazil","position":"Midfielder","birthdate":"1992-02-23"}'),
    ('player_13', 'PLAYER', 'Neymar Jr', '{"nationality":"Brazil","position":"Forward","birthdate":"1992-02-05"}'),
    ('player_15', 'PLAYER', 'Robert Lewandowski', '{"nationality":"Poland","position":"Forward","birthdate":"1988-08-21"}'),
    ('player_16', 'PLAYER', 'Pedri', '{"nationality":"Spain","position":"Midfielder","birthdate":"2002-11-25"}'),
    ('player_17', 'PLAYER', 'Gavi', '{"nationality":"Spain","position":"Midfielder","birthdate":"2004-08-05"}'),
    ('player_18', 'PLAYER', 'Frenkie de Jong', '{"nationality":"Netherlands","position":"Midfielder","birthdate":"1997-05-12"}'),
    ('player_19', 'PLAYER', 'Antoine Griezmann', '{"nationality":"France","position":"Forward","birthdate":"1991-03-21"}'),
    ('player_20', 'PLAYER', 'Jan Oblak', '{"nationality":"Slovenia","position":"Goalkeeper","birthdate":"1993-01-07"}'),
    ('player_21', 'PLAYER', 'Koke', '{"nationality":"Spain","position":"Midfielder","birthdate":"1992-01-08"}'),
    ('player_22', 'PLAYER', 'João Félix', '{"nationality":"Portugal","position":"Forward","birthdate":"1999-11-10"}'),
    ('player_23', 'PLAYER', 'Rafael Leão', '{"nationality":"Portugal","position":"Forward","birthdate":"1999-06-10"}'),
    ('player_24', 'PLAYER', 'Theo Hernández', '{"nationality":"France","position":"Defender","birthdate":"1997-10-06"}'),
    ('player_25', 'PLAYER', 'Mike Maignan', '{"nationality":"France","position":"Goalkeeper","birthdate":"1995-07-03"}'),
    ('player_26', 'PLAYER', 'Lautaro Martínez', '{"nationality":"Argentina","position":"Forward","birthdate":"1997-08-22"}'),
    ('player_27', 'PLAYER', 'Nicolò Barella', '{"nationality":"Italy","position":"Midfielder","birthdate":"1997-02-07"}'),
    ('player_28', 'PLAYER', 'Federico Dimarco', '{"nationality":"Italy","position":"Defender","birthdate":"1997-11-10"}'),
    ('player_29', 'PLAYER', 'Dusan Vlahović', '{"nationality":"Serbia","position":"Forward","birthdate":"2000-01-28"}'),
    ('player_30', 'PLAYER', 'Federico Chiesa', '{"nationality":"Italy","position":"Forward","birthdate":"1997-10-25"}'),
    ('player_31', 'PLAYER', 'Manuel Locatelli', '{"nationality":"Italy","position":"Midfielder","birthdate":"1998-01-08"}'),
    ('player_32', 'PLAYER', 'Jadon Sancho', '{"nationality":"England","position":"Forward","birthdate":"2000-03-25"}'),
    ('player_33', 'PLAYER', 'Marco Reus', '{"nationality":"Germany","position":"Midfielder","birthdate":"1989-05-31"}'),
    ('player_34', 'PLAYER', 'Mats Hummels', '{"nationality":"Germany","position":"Defender","birthdate":"1988-12-16"}'),
    ('player_35', 'PLAYER', 'Bukayo Saka', '{"nationality":"England","position":"Forward","birthdate":"2001-09-05"}'),
    ('player_36', 'PLAYER', 'Martin Ødegaard', '{"nationality":"Norway","position":"Midfielder","birthdate":"1998-12-17"}'),
    ('player_37', 'PLAYER', 'Declan Rice', '{"nationality":"England","position":"Midfielder","birthdate":"1999-01-14"}'),
    ('player_38', 'PLAYER', 'William Saliba', '{"nationality":"France","position":"Defender","birthdate":"2001-03-24"}'),
    ('player_39', 'PLAYER', 'Cole Palmer', '{"nationality":"England","position":"Midfielder","birthdate":"2002-05-06"}'),
    ('player_40', 'PLAYER', 'Enzo Fernández', '{"nationality":"Argentina","position":"Midfielder","birthdate":"2001-01-17"}'),
    ('player_41', 'PLAYER', 'Mason Mount', '{"nationality":"England","position":"Midfielder","birthdate":"1999-01-10"}'),
('player_42', 'PLAYER', 'Reece James', '{"nationality":"England","position":"Defender","birthdate":"1999-12-08"}');

-- Insert COACHES as nodes
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT column1, column2, column3, PARSE_JSON(column4)
FROM VALUES
    ('coach_101', 'COACH', 'Carlo Ancelotti', '{"nationality":"Italy","license_level":"UEFA Pro","birthdate":"1959-06-10"}'),
    ('coach_102', 'COACH', 'Pep Guardiola', '{"nationality":"Spain","license_level":"UEFA Pro","birthdate":"1971-01-18"}'),
    ('coach_103', 'COACH', 'Arne Slot', '{"nationality":"Netherlands","license_level":"UEFA Pro","birthdate":"1978-09-17"}'),
    ('coach_104', 'COACH', 'Mikel Arteta', '{"nationality":"Spain","license_level":"UEFA Pro","birthdate":"1982-03-26"}'),
    ('coach_105', 'COACH', 'Mauricio Pochettino', '{"nationality":"Argentina","license_level":"UEFA Pro","birthdate":"1972-03-02"}'),
    ('coach_106', 'COACH', 'Xavi Hernández', '{"nationality":"Spain","license_level":"UEFA Pro","birthdate":"1980-01-25"}'),
    ('coach_107', 'COACH', 'Diego Simeone', '{"nationality":"Argentina","license_level":"UEFA Pro","birthdate":"1970-04-28"}'),
    ('coach_108', 'COACH', 'Stefano Pioli', '{"nationality":"Italy","license_level":"UEFA Pro","birthdate":"1965-10-20"}'),
    ('coach_109', 'COACH', 'Massimiliano Allegri', '{"nationality":"Italy","license_level":"UEFA Pro","birthdate":"1967-08-11"}'),
    ('coach_110', 'COACH', 'Simone Inzaghi', '{"nationality":"Italy","license_level":"UEFA Pro","birthdate":"1976-04-05"}'),
    ('coach_111', 'COACH', 'Edin Terzić', '{"nationality":"Germany","license_level":"UEFA Pro","birthdate":"1982-10-30"}');

-- Insert MATCHES as nodes
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT column1, column2, column3, PARSE_JSON(column4)
FROM VALUES
    -- 2025-2026 Season Matches
    ('match_1', 'MATCH', 'Manchester City vs Liverpool', '{"event_date":"2025-10-25","venue":"Etihad Stadium","score_home":2,"score_away":2,"competition":"Premier League"}'),
    ('match_2', 'MATCH', 'Real Madrid vs Bayern Munich', '{"event_date":"2025-11-05","venue":"Santiago Bernabéu","score_home":3,"score_away":1,"competition":"Champions League"}'),
    ('match_3', 'MATCH', 'Paris Saint-Germain vs Manchester City', '{"event_date":"2025-11-06","venue":"Parc des Princes","score_home":1,"score_away":2,"competition":"Champions League"}'),
    ('match_4', 'MATCH', 'Liverpool vs Real Madrid', '{"event_date":"2026-02-18","venue":"Anfield","score_home":1,"score_away":1,"competition":"Champions League"}'),
    ('match_5', 'MATCH', 'Bayern Munich vs Manchester City', '{"event_date":"2026-03-10","venue":"Allianz Arena","score_home":0,"score_away":1,"competition":"Champions League"}'),
    ('match_6', 'MATCH', 'Arsenal vs Chelsea', '{"event_date":"2025-10-26","venue":"Emirates Stadium","score_home":3,"score_away":1,"competition":"Premier League"}'),
    ('match_7', 'MATCH', 'Barcelona vs Atletico Madrid', '{"event_date":"2025-10-27","venue":"Camp Nou","score_home":2,"score_away":0,"competition":"La Liga"}'),
    ('match_8', 'MATCH', 'AC Milan vs Inter Milan', '{"event_date":"2025-10-28","venue":"San Siro","score_home":1,"score_away":1,"competition":"Serie A"}'),
    ('match_9', 'MATCH', 'Juventus vs Borussia Dortmund', '{"event_date":"2025-10-29","venue":"Allianz Stadium","score_home":2,"score_away":1,"competition":"Serie A"}'),
    ('match_10', 'MATCH', 'Real Madrid vs Barcelona', '{"event_date":"2025-11-12","venue":"Santiago Bernabéu","score_home":2,"score_away":1,"competition":"Champions League"}'),
    ('match_11', 'MATCH', 'Manchester City vs Arsenal', '{"event_date":"2025-11-13","venue":"Etihad Stadium","score_home":1,"score_away":0,"competition":"Premier League"}'),
    ('match_12', 'MATCH', 'Liverpool vs Chelsea', '{"event_date":"2025-11-14","venue":"Anfield","score_home":2,"score_away":1,"competition":"Premier League"}'),
    ('match_13', 'MATCH', 'Paris Saint-Germain vs Bayern Munich', '{"event_date":"2025-11-15","venue":"Parc des Princes","score_home":1,"score_away":3,"competition":"Champions League"}'),
    ('match_14', 'MATCH', 'Arsenal vs Liverpool', '{"event_date":"2025-12-01","venue":"Emirates Stadium","score_home":1,"score_away":2,"competition":"Premier League"}'),
    ('match_15', 'MATCH', 'Chelsea vs Manchester City', '{"event_date":"2025-12-02","venue":"Stamford Bridge","score_home":0,"score_away":2,"competition":"Premier League"}'),
    ('match_16', 'MATCH', 'Barcelona vs Real Madrid', '{"event_date":"2025-12-03","venue":"Camp Nou","score_home":1,"score_away":3,"competition":"La Liga"}'),
    ('match_17', 'MATCH', 'Atletico Madrid vs Barcelona', '{"event_date":"2025-12-04","venue":"Wanda Metropolitano","score_home":2,"score_away":1,"competition":"La Liga"}'),
    ('match_18', 'MATCH', 'AC Milan vs Juventus', '{"event_date":"2025-12-05","venue":"San Siro","score_home":1,"score_away":0,"competition":"Serie A"}'),
    ('match_19', 'MATCH', 'Inter Milan vs AC Milan', '{"event_date":"2025-12-06","venue":"San Siro","score_home":2,"score_away":1,"competition":"Serie A"}'),
    ('match_20', 'MATCH', 'Borussia Dortmund vs Bayern Munich', '{"event_date":"2025-12-07","venue":"Signal Iduna Park","score_home":1,"score_away":1,"competition":"Bundesliga"}');

-- =====================================================
-- EDGE DATA INSERTION (RELATIONSHIPS)
-- =====================================================

-- Current Player Contracts (PLAYS_FOR edges)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, EFFECTIVE_START, EFFECTIVE_END, PROPS)
SELECT column1, column2, column3, column4, column5, column6, PARSE_JSON(column7)
FROM VALUES
-- Current Contracts (2025-2026)
    ('edge_1', 'player_1', 'club_1', 'PLAYS_FOR', '2024-07-01', '2029-06-30', '{"jersey_number":9,"contract_value":45000000}'),
    ('edge_2', 'player_2', 'club_2', 'PLAYS_FOR', '2022-07-01', '2025-06-30', '{"jersey_number":9,"contract_value":50000000}'),
    ('edge_3', 'player_3', 'club_1', 'PLAYS_FOR', '2023-07-01', '2029-06-30', '{"jersey_number":5,"contract_value":40000000}'),
    ('edge_4', 'player_4', 'club_3', 'PLAYS_FOR', '2021-08-13', '2026-06-30', '{"jersey_number":4,"contract_value":35000000}'),
    ('edge_5', 'player_5', 'club_5', 'PLAYS_FOR', '2023-07-01', NULL, '{"jersey_number":10,"contract_value":20000000}'),
    ('edge_6', 'player_6', 'club_6', 'PLAYS_FOR', '2023-01-01', '2025-06-30', '{"jersey_number":7,"contract_value":30000000}'),
    ('edge_7', 'player_7', 'club_2', 'PLAYS_FOR', '2015-08-30', '2025-06-30', '{"jersey_number":17,"contract_value":40000000}'),
    ('edge_8', 'player_8', 'club_3', 'PLAYS_FOR', '2017-07-01', '2025-06-30', '{"jersey_number":11,"contract_value":35000000}'),
    ('edge_9', 'player_9', 'club_4', 'PLAYS_FOR', '2022-07-01', '2026-06-30', '{"jersey_number":10,"contract_value":30000000}'),
    ('edge_10', 'player_10', 'club_1', 'PLAYS_FOR', '2012-08-27', '2024-06-30', '{"jersey_number":10,"contract_value":25000000}'),
    ('edge_11', 'player_11', 'club_1', 'PLAYS_FOR', '2014-07-17', '2024-06-30', '{"jersey_number":8,"contract_value":20000000}'),
    ('edge_12', 'player_12', 'club_2', 'PLAYS_FOR', '2022-08-22', '2027-06-30', '{"jersey_number":18,"contract_value":30000000}'),
    ('edge_13', 'player_13', 'club_4', 'PLAYS_FOR', '2017-08-03', '2025-06-30', '{"jersey_number":10,"contract_value":40000000}'),
    ('edge_15', 'player_15', 'club_7', 'PLAYS_FOR', '2022-07-19', '2026-06-30', '{"jersey_number":9,"contract_value":35000000}'),
    ('edge_16', 'player_16', 'club_10', 'PLAYS_FOR', '2020-09-02', '2026-06-30', '{"jersey_number":8,"contract_value":25000000}'),
    ('edge_17', 'player_17', 'club_10', 'PLAYS_FOR', '2021-08-31', '2026-06-30', '{"jersey_number":6,"contract_value":20000000}'),
    ('edge_18', 'player_18', 'club_10', 'PLAYS_FOR', '2019-07-01', '2026-06-30', '{"jersey_number":21,"contract_value":30000000}'),
    ('edge_19', 'player_19', 'club_11', 'PLAYS_FOR', '2019-07-14', '2026-06-30', '{"jersey_number":7,"contract_value":25000000}'),
    ('edge_20', 'player_20', 'club_11', 'PLAYS_FOR', '2014-07-16', '2028-06-30', '{"jersey_number":13,"contract_value":20000000}'),
    ('edge_21', 'player_21', 'club_11', 'PLAYS_FOR', '2011-08-31', '2024-06-30', '{"jersey_number":6,"contract_value":15000000}'),
    ('edge_22', 'player_22', 'club_4', 'PLAYS_FOR', '2023-09-01', '2024-06-30', '{"jersey_number":11,"contract_value":20000000}'),
    ('edge_23', 'player_23', 'club_12', 'PLAYS_FOR', '2019-08-01', '2028-06-30', '{"jersey_number":17,"contract_value":30000000}'),
    ('edge_24', 'player_24', 'club_12', 'PLAYS_FOR', '2019-07-06', '2026-06-30', '{"jersey_number":19,"contract_value":25000000}'),
    ('edge_25', 'player_25', 'club_12', 'PLAYS_FOR', '2021-05-27', '2026-06-30', '{"jersey_number":16,"contract_value":20000000}'),
    ('edge_26', 'player_26', 'club_14', 'PLAYS_FOR', '2018-07-01', '2026-06-30', '{"jersey_number":10,"contract_value":30000000}'),
    ('edge_27', 'player_27', 'club_14', 'PLAYS_FOR', '2019-07-12', '2026-06-30', '{"jersey_number":23,"contract_value":25000000}'),
    ('edge_28', 'player_28', 'club_14', 'PLAYS_FOR', '2018-01-31', '2026-06-30', '{"jersey_number":32,"contract_value":20000000}'),
    ('edge_29', 'player_29', 'club_13', 'PLAYS_FOR', '2022-01-28', '2026-06-30', '{"jersey_number":9,"contract_value":30000000}'),
    ('edge_30', 'player_30', 'club_13', 'PLAYS_FOR', '2020-10-05', '2025-06-30', '{"jersey_number":7,"contract_value":25000000}'),
    ('edge_31', 'player_31', 'club_13', 'PLAYS_FOR', '2021-08-18', '2026-06-30', '{"jersey_number":5,"contract_value":20000000}'),
    ('edge_32', 'player_32', 'club_15', 'PLAYS_FOR', '2021-07-23', '2026-06-30', '{"jersey_number":7,"contract_value":30000000}'),
    ('edge_33', 'player_33', 'club_15', 'PLAYS_FOR', '2012-07-01', '2024-06-30', '{"jersey_number":11,"contract_value":15000000}'),
    ('edge_34', 'player_34', 'club_15', 'PLAYS_FOR', '2019-07-01', '2024-06-30', '{"jersey_number":15,"contract_value":20000000}'),
    ('edge_35', 'player_35', 'club_8', 'PLAYS_FOR', '2019-07-01', '2027-06-30', '{"jersey_number":7,"contract_value":25000000}'),
    ('edge_36', 'player_36', 'club_8', 'PLAYS_FOR', '2021-01-27', '2028-06-30', '{"jersey_number":8,"contract_value":20000000}'),
    ('edge_37', 'player_37', 'club_8', 'PLAYS_FOR', '2023-07-15', '2030-06-30', '{"jersey_number":41,"contract_value":30000000}'),
    ('edge_38', 'player_38', 'club_8', 'PLAYS_FOR', '2019-07-25', '2027-06-30', '{"jersey_number":2,"contract_value":20000000}'),
    ('edge_39', 'player_39', 'club_9', 'PLAYS_FOR', '2023-09-01', '2030-06-30', '{"jersey_number":20,"contract_value":25000000}'),
    ('edge_40', 'player_40', 'club_9', 'PLAYS_FOR', '2023-01-31', '2031-06-30', '{"jersey_number":5,"contract_value":30000000}'),
    ('edge_41', 'player_41', 'club_9', 'PLAYS_FOR', '2023-07-05', '2030-06-30', '{"jersey_number":7,"contract_value":25000000}'),
    ('edge_42', 'player_42', 'club_9', 'PLAYS_FOR', '2019-07-01', '2028-06-30', '{"jersey_number":24,"contract_value":20000000}');

-- Historical Player Contracts for Transfer Analysis
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, EFFECTIVE_START, EFFECTIVE_END, PROPS)
SELECT column1, column2, column3, column4, column5, column6, PARSE_JSON(column7)
FROM VALUES
    ('edge_101', 'player_1', 'club_4', 'PLAYS_FOR', '2017-08-31', '2024-06-30', '{"jersey_number":7,"contract_value":40000000}'),
    ('edge_102', 'player_2', 'club_15', 'PLAYS_FOR', '2020-01-01', '2022-06-30', '{"jersey_number":9,"contract_value":20000000}'),
    ('edge_103', 'player_3', 'club_15', 'PLAYS_FOR', '2020-07-20', '2023-06-30', '{"jersey_number":22,"contract_value":15000000}'),
    ('edge_104', 'player_5', 'club_10', 'PLAYS_FOR', '2004-07-01', '2021-06-30', '{"jersey_number":10,"contract_value":50000000}'),
    ('edge_104a', 'player_5', 'club_4', 'PLAYS_FOR', '2021-08-01', '2023-06-30', '{"jersey_number":30,"contract_value":30000000}'),
    ('edge_105', 'player_6', 'club_1', 'PLAYS_FOR', '2009-07-01', '2018-07-10', '{"jersey_number":7,"contract_value":45000000}'),
    ('edge_106', 'player_6', 'club_8', 'PLAYS_FOR', '2003-08-12', '2009-06-30', '{"jersey_number":7,"contract_value":10000000}'),
    ('edge_107', 'player_7', 'club_9', 'PLAYS_FOR', '2012-01-31', '2015-08-30', '{"jersey_number":14,"contract_value":15000000}'),
    ('edge_108', 'player_7', 'club_15', 'PLAYS_FOR', '2015-08-30', '2015-08-30', '{"jersey_number":14,"contract_value":20000000}'),
    ('edge_109', 'player_8', 'club_9', 'PLAYS_FOR', '2014-01-26', '2017-06-30', '{"jersey_number":15,"contract_value":10000000}'),
    ('edge_110', 'player_8', 'club_13', 'PLAYS_FOR', '2015-08-06', '2017-06-30', '{"jersey_number":7,"contract_value":12000000}'),
    ('edge_111', 'player_8', 'club_13', 'PLAYS_FOR', '2016-08-31', '2017-06-30', '{"jersey_number":7,"contract_value":15000000}'),
    ('edge_112', 'player_9', 'club_3', 'PLAYS_FOR', '2016-06-28', '2022-06-30', '{"jersey_number":10,"contract_value":25000000}'),
    ('edge_113', 'player_9', 'club_8', 'PLAYS_FOR', '2014-09-01', '2016-06-30', '{"jersey_number":19,"contract_value":15000000}'),
    ('edge_114', 'player_10', 'club_12', 'PLAYS_FOR', '2010-08-26', '2012-08-27', '{"jersey_number":14,"contract_value":20000000}'),
    ('edge_115', 'player_11', 'club_15', 'PLAYS_FOR', '2007-01-31', '2014-07-17', '{"jersey_number":39,"contract_value":10000000}'),
    ('edge_116', 'player_12', 'club_1', 'PLAYS_FOR', '2013-01-31', '2022-08-22', '{"jersey_number":14,"contract_value":25000000}'),
    ('edge_117', 'player_13', 'club_10', 'PLAYS_FOR', '2013-07-03', '2017-08-03', '{"jersey_number":11,"contract_value":30000000}'),
    ('edge_118', 'player_15', 'club_10', 'PLAYS_FOR', '2014-07-09', '2022-07-19', '{"jersey_number":9,"contract_value":30000000}'),
    ('edge_119', 'player_15', 'club_15', 'PLAYS_FOR', '2010-07-01', '2014-07-09', '{"jersey_number":9,"contract_value":15000000}'),
    ('edge_120', 'player_18', 'club_15', 'PLAYS_FOR', '2016-08-31', '2019-07-01', '{"jersey_number":21,"contract_value":20000000}'),
    ('edge_121', 'player_19', 'club_10', 'PLAYS_FOR', '2014-07-28', '2019-07-14', '{"jersey_number":7,"contract_value":25000000}'),
    ('edge_122', 'player_19', 'club_11', 'PLAYS_FOR', '2011-07-27', '2014-07-28', '{"jersey_number":7,"contract_value":15000000}'),
    ('edge_123', 'player_22', 'club_10', 'PLAYS_FOR', '2019-07-03', '2023-09-01', '{"jersey_number":7,"contract_value":20000000}'),
    ('edge_124', 'player_22', 'club_11', 'PLAYS_FOR', '2019-07-03', '2023-09-01', '{"jersey_number":7,"contract_value":20000000}'),
    ('edge_125', 'player_23', 'club_10', 'PLAYS_FOR', '2018-08-09', '2019-08-01', '{"jersey_number":17,"contract_value":15000000}'),
    ('edge_126', 'player_24', 'club_10', 'PLAYS_FOR', '2017-07-12', '2019-07-06', '{"jersey_number":19,"contract_value":10000000}'),
    ('edge_127', 'player_25', 'club_12', 'PLAYS_FOR', '2015-07-01', '2021-05-27', '{"jersey_number":16,"contract_value":15000000}'),
    ('edge_128', 'player_26', 'club_12', 'PLAYS_FOR', '2018-07-01', '2018-07-01', '{"jersey_number":10,"contract_value":10000000}'),
    ('edge_129', 'player_27', 'club_12', 'PLAYS_FOR', '2017-07-12', '2019-07-12', '{"jersey_number":23,"contract_value":12000000}'),
    ('edge_130', 'player_28', 'club_12', 'PLAYS_FOR', '2016-07-01', '2018-01-31', '{"jersey_number":32,"contract_value":8000000}'),
    ('edge_131', 'player_29', 'club_13', 'PLAYS_FOR', '2018-07-01', '2022-01-28', '{"jersey_number":9,"contract_value":15000000}'),
    ('edge_132', 'player_30', 'club_13', 'PLAYS_FOR', '2016-07-01', '2020-10-05', '{"jersey_number":7,"contract_value":12000000}'),
    ('edge_133', 'player_31', 'club_13', 'PLAYS_FOR', '2018-07-01', '2021-08-18', '{"jersey_number":5,"contract_value":10000000}'),
    ('edge_134', 'player_32', 'club_8', 'PLAYS_FOR', '2017-07-01', '2021-07-23', '{"jersey_number":7,"contract_value":15000000}'),
    ('edge_135', 'player_33', 'club_15', 'PLAYS_FOR', '2009-07-01', '2012-07-01', '{"jersey_number":11,"contract_value":8000000}'),
    ('edge_136', 'player_34', 'club_15', 'PLAYS_FOR', '2008-07-01', '2019-07-01', '{"jersey_number":15,"contract_value":12000000}'),
    ('edge_137', 'player_35', 'club_8', 'PLAYS_FOR', '2018-07-01', '2019-07-01', '{"jersey_number":7,"contract_value":5000000}'),
    ('edge_138', 'player_36', 'club_1', 'PLAYS_FOR', '2015-01-16', '2021-01-27', '{"jersey_number":8,"contract_value":10000000}'),
    ('edge_139', 'player_37', 'club_8', 'PLAYS_FOR', '2014-07-01', '2023-07-15', '{"jersey_number":41,"contract_value":20000000}'),
    ('edge_140', 'player_38', 'club_8', 'PLAYS_FOR', '2016-07-01', '2019-07-25', '{"jersey_number":2,"contract_value":8000000}'),
    ('edge_141', 'player_39', 'club_8', 'PLAYS_FOR', '2010-07-01', '2023-09-01', '{"jersey_number":20,"contract_value":15000000}'),
    ('edge_142', 'player_40', 'club_8', 'PLAYS_FOR', '2019-07-01', '2023-01-31', '{"jersey_number":5,"contract_value":20000000}'),
    ('edge_143', 'player_41', 'club_8', 'PLAYS_FOR', '2005-07-01', '2023-07-05', '{"jersey_number":7,"contract_value":18000000}'),
    ('edge_144', 'player_42', 'club_8', 'PLAYS_FOR', '2018-07-01', '2019-07-01', '{"jersey_number":24,"contract_value":10000000}');

-- Current Coach Contracts (COACHES edges)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, EFFECTIVE_START, EFFECTIVE_END, PROPS)
SELECT column1, column2, column3, column4, column5, column6, PARSE_JSON(column7)
FROM VALUES
    ('edge_201', 'coach_101', 'club_1', 'COACHES', '2021-06-01', '2026-06-30', '{"contract_value":15000000}'),
    ('edge_202', 'coach_102', 'club_2', 'COACHES', '2016-07-01', '2026-06-30', '{"contract_value":20000000}'),
    ('edge_203', 'coach_103', 'club_3', 'COACHES', '2024-06-01', '2027-06-30', '{"contract_value":8000000}'),
    ('edge_204', 'coach_104', 'club_8', 'COACHES', '2019-12-22', '2027-06-30', '{"contract_value":10000000}'),
    ('edge_205', 'coach_105', 'club_9', 'COACHES', '2023-05-29', '2026-06-30', '{"contract_value":12000000}'),
    ('edge_206', 'coach_106', 'club_10', 'COACHES', '2021-11-06', '2025-06-30', '{"contract_value":8000000}'),
    ('edge_207', 'coach_107', 'club_11', 'COACHES', '2011-12-23', '2026-06-30', '{"contract_value":15000000}'),
    ('edge_208', 'coach_108', 'club_12', 'COACHES', '2019-10-09', '2025-06-30', '{"contract_value":6000000}'),
    ('edge_209', 'coach_109', 'club_13', 'COACHES', '2021-05-28', '2025-06-30', '{"contract_value":10000000}'),
    ('edge_210', 'coach_110', 'club_14', 'COACHES', '2021-06-03', '2026-06-30', '{"contract_value":8000000}'),
    ('edge_211', 'coach_111', 'club_15', 'COACHES', '2022-05-23', '2025-06-30', '{"contract_value":5000000}');

-- Historical Coach Contracts for Succession Analysis
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, EFFECTIVE_START, EFFECTIVE_END, PROPS)
SELECT column1, column2, column3, column4, column5, column6, PARSE_JSON(column7)
FROM VALUES
    ('edge_301', 'coach_101', 'club_2', 'COACHES', '2016-07-01', '2021-06-01', '{"contract_value":12000000}'),
    ('edge_302', 'coach_101', 'club_1', 'COACHES', '2013-06-25', '2015-05-25', '{"contract_value":10000000}'),
    ('edge_303', 'coach_102', 'club_10', 'COACHES', '2008-06-01', '2012-06-30', '{"contract_value":15000000}'),
    ('edge_304', 'coach_102', 'club_7', 'COACHES', '2013-06-24', '2016-07-01', '{"contract_value":18000000}'),
    ('edge_305', 'coach_103', 'club_15', 'COACHES', '2021-07-01', '2024-06-01', '{"contract_value":4000000}'),
    ('edge_306', 'coach_104', 'club_8', 'COACHES', '2016-12-20', '2018-05-13', '{"contract_value":5000000}'),
    ('edge_307', 'coach_105', 'club_4', 'COACHES', '2021-01-02', '2022-07-05', '{"contract_value":10000000}'),
    ('edge_308', 'coach_105', 'club_3', 'COACHES', '2014-06-01', '2019-11-20', '{"contract_value":8000000}'),
    ('edge_309', 'coach_106', 'club_10', 'COACHES', '2019-01-13', '2021-11-06', '{"contract_value":6000000}'),
    ('edge_310', 'coach_107', 'club_11', 'COACHES', '2006-01-01', '2011-12-23', '{"contract_value":8000000}'),
    ('edge_311', 'coach_108', 'club_12', 'COACHES', '2016-11-08', '2019-10-09', '{"contract_value":4000000}'),
    ('edge_312', 'coach_109', 'club_13', 'COACHES', '2014-07-16', '2019-05-17', '{"contract_value":12000000}'),
    ('edge_313', 'coach_110', 'club_14', 'COACHES', '2016-06-01', '2021-06-03', '{"contract_value":6000000}'),
    ('edge_314', 'coach_111', 'club_15', 'COACHES', '2020-12-13', '2021-05-23', '{"contract_value":3000000}');

-- Match Relationships (HOME_TEAM and AWAY_TEAM edges)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, EFFECTIVE_START, EFFECTIVE_END, PROPS)
SELECT column1, column2, column3, column4, column5, column6, PARSE_JSON(column7)
FROM VALUES
-- Match 1: Man City vs Liverpool (2-2)
    ('edge_401', 'club_2', 'match_1', 'HOME_TEAM', '2025-10-25', '2025-10-25', '{}'),
    ('edge_402', 'club_3', 'match_1', 'AWAY_TEAM', '2025-10-25', '2025-10-25', '{}'),

-- Match 2: Real Madrid vs Bayern Munich (3-1)
    ('edge_403', 'club_1', 'match_2', 'HOME_TEAM', '2025-11-05', '2025-11-05', '{}'),
    ('edge_404', 'club_7', 'match_2', 'AWAY_TEAM', '2025-11-05', '2025-11-05', '{}'),

-- Match 3: PSG vs Man City (1-2)
    ('edge_405', 'club_4', 'match_3', 'HOME_TEAM', '2025-11-06', '2025-11-06', '{}'),
    ('edge_406', 'club_2', 'match_3', 'AWAY_TEAM', '2025-11-06', '2025-11-06', '{}'),

-- Match 4: Liverpool vs Real Madrid (1-1)
    ('edge_407', 'club_3', 'match_4', 'HOME_TEAM', '2026-02-18', '2026-02-18', '{}'),
    ('edge_408', 'club_1', 'match_4', 'AWAY_TEAM', '2026-02-18', '2026-02-18', '{}'),

-- Match 5: Bayern Munich vs Man City (0-1)
    ('edge_409', 'club_7', 'match_5', 'HOME_TEAM', '2026-03-10', '2026-03-10', '{}'),
    ('edge_410', 'club_2', 'match_5', 'AWAY_TEAM', '2026-03-10', '2026-03-10', '{}'),

-- Match 6: Arsenal vs Chelsea (3-1)
    ('edge_411', 'club_8', 'match_6', 'HOME_TEAM', '2025-10-26', '2025-10-26', '{}'),
    ('edge_412', 'club_9', 'match_6', 'AWAY_TEAM', '2025-10-26', '2025-10-26', '{}'),

-- Match 7: Barcelona vs Atletico (2-0)
    ('edge_413', 'club_10', 'match_7', 'HOME_TEAM', '2025-10-27', '2025-10-27', '{}'),
    ('edge_414', 'club_11', 'match_7', 'AWAY_TEAM', '2025-10-27', '2025-10-27', '{}'),

-- Match 8: AC Milan vs Inter (1-1)
    ('edge_415', 'club_12', 'match_8', 'HOME_TEAM', '2025-10-28', '2025-10-28', '{}'),
    ('edge_416', 'club_14', 'match_8', 'AWAY_TEAM', '2025-10-28', '2025-10-28', '{}'),

-- Match 9: Juventus vs Dortmund (2-1)
    ('edge_417', 'club_13', 'match_9', 'HOME_TEAM', '2025-10-29', '2025-10-29', '{}'),
    ('edge_418', 'club_15', 'match_9', 'AWAY_TEAM', '2025-10-29', '2025-10-29', '{}'),

-- Match 10: Real Madrid vs Barcelona (2-1)
    ('edge_419', 'club_1', 'match_10', 'HOME_TEAM', '2025-11-12', '2025-11-12', '{}'),
    ('edge_420', 'club_10', 'match_10', 'AWAY_TEAM', '2025-11-12', '2025-11-12', '{}'),

-- Match 11: Man City vs Arsenal (1-0)
    ('edge_421', 'club_2', 'match_11', 'HOME_TEAM', '2025-11-13', '2025-11-13', '{}'),
    ('edge_422', 'club_8', 'match_11', 'AWAY_TEAM', '2025-11-13', '2025-11-13', '{}'),

-- Match 12: Liverpool vs Chelsea (2-1)
    ('edge_423', 'club_3', 'match_12', 'HOME_TEAM', '2025-11-14', '2025-11-14', '{}'),
    ('edge_424', 'club_9', 'match_12', 'AWAY_TEAM', '2025-11-14', '2025-11-14', '{}'),

-- Match 13: PSG vs Bayern Munich (1-3)
    ('edge_425', 'club_4', 'match_13', 'HOME_TEAM', '2025-11-15', '2025-11-15', '{}'),
    ('edge_426', 'club_7', 'match_13', 'AWAY_TEAM', '2025-11-15', '2025-11-15', '{}'),

-- Match 14: Arsenal vs Liverpool (1-2)
    ('edge_427', 'club_8', 'match_14', 'HOME_TEAM', '2025-12-01', '2025-12-01', '{}'),
    ('edge_428', 'club_3', 'match_14', 'AWAY_TEAM', '2025-12-01', '2025-12-01', '{}'),

-- Match 15: Chelsea vs Man City (0-2)
    ('edge_429', 'club_9', 'match_15', 'HOME_TEAM', '2025-12-02', '2025-12-02', '{}'),
    ('edge_430', 'club_2', 'match_15', 'AWAY_TEAM', '2025-12-02', '2025-12-02', '{}'),

-- Match 16: Barcelona vs Real Madrid (1-3)
    ('edge_431', 'club_10', 'match_16', 'HOME_TEAM', '2025-12-03', '2025-12-03', '{}'),
    ('edge_432', 'club_1', 'match_16', 'AWAY_TEAM', '2025-12-03', '2025-12-03', '{}'),

-- Match 17: Atletico vs Barcelona (2-1)
    ('edge_433', 'club_11', 'match_17', 'HOME_TEAM', '2025-12-04', '2025-12-04', '{}'),
    ('edge_434', 'club_10', 'match_17', 'AWAY_TEAM', '2025-12-04', '2025-12-04', '{}'),

-- Match 18: AC Milan vs Juventus (1-0)
    ('edge_435', 'club_12', 'match_18', 'HOME_TEAM', '2025-12-05', '2025-12-05', '{}'),
    ('edge_436', 'club_13', 'match_18', 'AWAY_TEAM', '2025-12-05', '2025-12-05', '{}'),

-- Match 19: Inter vs AC Milan (2-1)
    ('edge_437', 'club_14', 'match_19', 'HOME_TEAM', '2025-12-06', '2025-12-06', '{}'),
    ('edge_438', 'club_12', 'match_19', 'AWAY_TEAM', '2025-12-06', '2025-12-06', '{}'),

-- Match 20: Dortmund vs Bayern Munich (1-1)
    ('edge_439', 'club_15', 'match_20', 'HOME_TEAM', '2025-12-07', '2025-12-07', '{}'),
    ('edge_440', 'club_7', 'match_20', 'AWAY_TEAM', '2025-12-07', '2025-12-07', '{}');

-- Player Match Appearances (PLAYED_IN edges)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, EFFECTIVE_START, EFFECTIVE_END, PROPS)
SELECT column1, column2, column3, column4, column5, column6, PARSE_JSON(column7)
FROM VALUES
    -- Match 1: Man City vs Liverpool (2-2)
    ('edge_501', 'player_2', 'match_1', 'PLAYED_IN', '2025-10-25', '2025-10-25', '{"goals_scored":1,"assists":1,"minutes_played":90}'),
    ('edge_502', 'player_7', 'match_1', 'PLAYED_IN', '2025-10-25', '2025-10-25', '{"goals_scored":1,"assists":0,"minutes_played":85}'),
    ('edge_503', 'player_4', 'match_1', 'PLAYED_IN', '2025-10-25', '2025-10-25', '{"goals_scored":0,"assists":0,"minutes_played":90}'),
    ('edge_504', 'player_8', 'match_1', 'PLAYED_IN', '2025-10-25', '2025-10-25', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_505', 'player_9', 'match_1', 'PLAYED_IN', '2025-10-25', '2025-10-25', '{"goals_scored":1,"assists":0,"minutes_played":80}'),

-- Match 2: Real Madrid vs Bayern Munich (3-1)
    ('edge_506', 'player_1', 'match_2', 'PLAYED_IN', '2025-11-05', '2025-11-05', '{"goals_scored":2,"assists":0,"minutes_played":90}'),
    ('edge_507', 'player_3', 'match_2', 'PLAYED_IN', '2025-11-05', '2025-11-05', '{"goals_scored":1,"assists":1,"minutes_played":90}'),
    ('edge_508', 'player_15', 'match_2', 'PLAYED_IN', '2025-11-05', '2025-11-05', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 3: PSG vs Man City (1-2)
    ('edge_509', 'player_13', 'match_3', 'PLAYED_IN', '2025-11-06', '2025-11-06', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_510', 'player_2', 'match_3', 'PLAYED_IN', '2025-11-06', '2025-11-06', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_511', 'player_7', 'match_3', 'PLAYED_IN', '2025-11-06', '2025-11-06', '{"goals_scored":0,"assists":1,"minutes_played":85}'),

-- Match 4: Liverpool vs Real Madrid (1-1)
    ('edge_512', 'player_8', 'match_4', 'PLAYED_IN', '2026-02-18', '2026-02-18', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_513', 'player_1', 'match_4', 'PLAYED_IN', '2026-02-18', '2026-02-18', '{"goals_scored":0,"assists":0,"minutes_played":90}'),
    ('edge_514', 'player_3', 'match_4', 'PLAYED_IN', '2026-02-18', '2026-02-18', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 5: Bayern Munich vs Man City (0-1)
    ('edge_515', 'player_2', 'match_5', 'PLAYED_IN', '2026-03-10', '2026-03-10', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 6: Arsenal vs Chelsea (3-1)
    ('edge_516', 'player_35', 'match_6', 'PLAYED_IN', '2025-10-26', '2025-10-26', '{"goals_scored":1,"assists":1,"minutes_played":90}'),
    ('edge_517', 'player_36', 'match_6', 'PLAYED_IN', '2025-10-26', '2025-10-26', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_518', 'player_37', 'match_6', 'PLAYED_IN', '2025-10-26', '2025-10-26', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_519', 'player_39', 'match_6', 'PLAYED_IN', '2025-10-26', '2025-10-26', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 7: Barcelona vs Atletico (2-0)
    ('edge_520', 'player_16', 'match_7', 'PLAYED_IN', '2025-10-27', '2025-10-27', '{"goals_scored":1,"assists":1,"minutes_played":90}'),
    ('edge_521', 'player_17', 'match_7', 'PLAYED_IN', '2025-10-27', '2025-10-27', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 8: AC Milan vs Inter (1-1)
    ('edge_522', 'player_23', 'match_8', 'PLAYED_IN', '2025-10-28', '2025-10-28', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_523', 'player_26', 'match_8', 'PLAYED_IN', '2025-10-28', '2025-10-28', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 9: Juventus vs Dortmund (2-1)
    ('edge_524', 'player_29', 'match_9', 'PLAYED_IN', '2025-10-29', '2025-10-29', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_525', 'player_30', 'match_9', 'PLAYED_IN', '2025-10-29', '2025-10-29', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_526', 'player_32', 'match_9', 'PLAYED_IN', '2025-10-29', '2025-10-29', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 10: Real Madrid vs Barcelona (2-1)
    ('edge_527', 'player_1', 'match_10', 'PLAYED_IN', '2025-11-12', '2025-11-12', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_528', 'player_3', 'match_10', 'PLAYED_IN', '2025-11-12', '2025-11-12', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_529', 'player_16', 'match_10', 'PLAYED_IN', '2025-11-12', '2025-11-12', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 11: Man City vs Arsenal (1-0)
    ('edge_530', 'player_2', 'match_11', 'PLAYED_IN', '2025-11-13', '2025-11-13', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 12: Liverpool vs Chelsea (2-1)
    ('edge_531', 'player_8', 'match_12', 'PLAYED_IN', '2025-11-14', '2025-11-14', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_532', 'player_9', 'match_12', 'PLAYED_IN', '2025-11-14', '2025-11-14', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_533', 'player_39', 'match_12', 'PLAYED_IN', '2025-11-14', '2025-11-14', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 13: PSG vs Bayern Munich (1-3)
    ('edge_534', 'player_13', 'match_13', 'PLAYED_IN', '2025-11-15', '2025-11-15', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_535', 'player_15', 'match_13', 'PLAYED_IN', '2025-11-15', '2025-11-15', '{"goals_scored":2,"assists":0,"minutes_played":90}'),
    ('edge_536', 'player_33', 'match_13', 'PLAYED_IN', '2025-11-15', '2025-11-15', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 14: Arsenal vs Liverpool (1-2)
    ('edge_537', 'player_35', 'match_14', 'PLAYED_IN', '2025-12-01', '2025-12-01', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_538', 'player_8', 'match_14', 'PLAYED_IN', '2025-12-01', '2025-12-01', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_539', 'player_9', 'match_14', 'PLAYED_IN', '2025-12-01', '2025-12-01', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 15: Chelsea vs Man City (0-2)
    ('edge_540', 'player_2', 'match_15', 'PLAYED_IN', '2025-12-02', '2025-12-02', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_541', 'player_7', 'match_15', 'PLAYED_IN', '2025-12-02', '2025-12-02', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 16: Barcelona vs Real Madrid (1-3)
    ('edge_542', 'player_16', 'match_16', 'PLAYED_IN', '2025-12-03', '2025-12-03', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_543', 'player_1', 'match_16', 'PLAYED_IN', '2025-12-03', '2025-12-03', '{"goals_scored":2,"assists":0,"minutes_played":90}'),
    ('edge_544', 'player_3', 'match_16', 'PLAYED_IN', '2025-12-03', '2025-12-03', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 17: Atletico vs Barcelona (2-1)
    ('edge_545', 'player_19', 'match_17', 'PLAYED_IN', '2025-12-04', '2025-12-04', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_546', 'player_22', 'match_17', 'PLAYED_IN', '2025-12-04', '2025-12-04', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_547', 'player_16', 'match_17', 'PLAYED_IN', '2025-12-04', '2025-12-04', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 18: AC Milan vs Juventus (1-0)
    ('edge_548', 'player_23', 'match_18', 'PLAYED_IN', '2025-12-05', '2025-12-05', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 19: Inter vs AC Milan (2-1)
    ('edge_549', 'player_26', 'match_19', 'PLAYED_IN', '2025-12-06', '2025-12-06', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_550', 'player_27', 'match_19', 'PLAYED_IN', '2025-12-06', '2025-12-06', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_551', 'player_23', 'match_19', 'PLAYED_IN', '2025-12-06', '2025-12-06', '{"goals_scored":1,"assists":0,"minutes_played":90}'),

-- Match 20: Dortmund vs Bayern Munich (1-1)
    ('edge_552', 'player_32', 'match_20', 'PLAYED_IN', '2025-12-07', '2025-12-07', '{"goals_scored":1,"assists":0,"minutes_played":90}'),
    ('edge_553', 'player_15', 'match_20', 'PLAYED_IN', '2025-12-07', '2025-12-07', '{"goals_scored":1,"assists":0,"minutes_played":90}');

-- =====================================================
-- LEGACY VIEWS FOR BACKWARD COMPATIBILITY
-- =====================================================

-- View for active player contracts (legacy format)
CREATE OR REPLACE VIEW ACTIVE_PLAYERS AS
SELECT 
    p.NODE_ID AS PERSON_ID,
    p.NAME,
    p.PROPS:nationality::STRING AS NATIONALITY,
    p.PROPS:position::STRING AS POSITION,
    c.NAME AS CLUB_NAME,
    pf.PROPS:jersey_number::INT AS JERSEY_NUMBER,
    pf.EFFECTIVE_START AS START_DATE,
    pf.EFFECTIVE_END AS END_DATE
FROM V_PLAYER p
JOIN V_PLAYS_FOR pf ON p.NODE_ID = pf.PLAYER_ID
JOIN V_CLUB c ON pf.CLUB_ID = c.NODE_ID
WHERE pf.EFFECTIVE_END IS NULL OR pf.EFFECTIVE_END > CURRENT_DATE();

-- View for active coach contracts (legacy format)
CREATE OR REPLACE VIEW ACTIVE_COACHES AS
SELECT 
    p.NODE_ID AS PERSON_ID,
    p.NAME,
    p.PROPS:nationality::STRING AS NATIONALITY,
    c.NAME AS CLUB_NAME,
    cf.EFFECTIVE_START AS START_DATE,
    cf.EFFECTIVE_END AS END_DATE
FROM V_COACH p
JOIN V_COACHES cf ON p.NODE_ID = cf.COACH_ID
JOIN V_CLUB c ON cf.CLUB_ID = c.NODE_ID
WHERE cf.EFFECTIVE_END IS NULL OR cf.EFFECTIVE_END > CURRENT_DATE();

-- View for match results with club names (legacy format)
CREATE OR REPLACE VIEW MATCH_RESULTS AS
SELECT 
    m.NODE_ID AS MATCH_ID,
    hc.NAME AS HOME_TEAM,
    ac.NAME AS AWAY_TEAM,
    m.PROPS:event_date::DATE AS MATCH_DATE,
    m.PROPS:score_home::INT AS HOME_SCORE,
    m.PROPS:score_away::INT AS AWAY_SCORE,
    m.PROPS:competition::STRING AS COMPETITION,
    m.PROPS:venue::STRING AS VENUE
FROM V_MATCH m
JOIN V_HOME_TEAM ht ON m.NODE_ID = ht.MATCH_ID
JOIN V_CLUB hc ON ht.CLUB_ID = hc.NODE_ID
JOIN V_AWAY_TEAM at ON m.NODE_ID = at.MATCH_ID
JOIN V_CLUB ac ON at.CLUB_ID = ac.NODE_ID;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Verify data integrity
SELECT 'KG_NODE' as TABLE_NAME, COUNT(*) as RECORD_COUNT FROM KG_NODE
UNION ALL
SELECT 'KG_EDGE', COUNT(*) FROM KG_EDGE
UNION ALL
SELECT 'V_PLAYER', COUNT(*) FROM V_PLAYER
UNION ALL
SELECT 'V_COACH', COUNT(*) FROM V_COACH
UNION ALL
SELECT 'V_CLUB', COUNT(*) FROM V_CLUB
UNION ALL
SELECT 'V_MATCH', COUNT(*) FROM V_MATCH
UNION ALL
SELECT 'V_PLAYS_FOR', COUNT(*) FROM V_PLAYS_FOR
UNION ALL
SELECT 'V_COACHES', COUNT(*) FROM V_COACHES
UNION ALL
SELECT 'V_PLAYED_IN', COUNT(*) FROM V_PLAYED_IN;

-- Show sample relationships
SELECT 'Sample Player-Club Relationships:' as INFO;
SELECT p.NAME, c.NAME AS CLUB_NAME, pf.PROPS:jersey_number::INT AS JERSEY_NUMBER
FROM V_PLAYER p
JOIN V_PLAYS_FOR pf ON p.NODE_ID = pf.PLAYER_ID
JOIN V_CLUB c ON pf.CLUB_ID = c.NODE_ID
WHERE pf.EFFECTIVE_END IS NULL OR pf.EFFECTIVE_END > CURRENT_DATE()
LIMIT 5;

SELECT 'Sample Coach-Club Relationships:' as INFO;
SELECT p.NAME, c.NAME AS CLUB_NAME
FROM V_COACH p
JOIN V_COACHES cf ON p.NODE_ID = cf.COACH_ID
JOIN V_CLUB c ON cf.CLUB_ID = c.NODE_ID
WHERE cf.EFFECTIVE_END IS NULL OR cf.EFFECTIVE_END > CURRENT_DATE();

SELECT 'Sample Match Results:' as INFO;
SELECT HOME_TEAM, AWAY_TEAM, HOME_SCORE, AWAY_SCORE, COMPETITION, MATCH_DATE
FROM MATCH_RESULTS
LIMIT 5;

-- =====================================================
-- SAMPLE GRAPH QUERIES USING NEW SCHEMA
-- =====================================================

-- Find all players who have been teammates through shared clubs
SELECT 'Teammate Analysis:' as INFO;
WITH player_clubs AS (
    SELECT 
        p.NODE_ID as player_id, 
        p.NAME as player_name, 
        c.NODE_ID as club_id, 
        c.NAME as club_name,
        pf.EFFECTIVE_START,
        pf.EFFECTIVE_END
    FROM V_PLAYER p
    JOIN V_PLAYS_FOR pf ON p.NODE_ID = pf.PLAYER_ID
    JOIN V_CLUB c ON pf.CLUB_ID = c.NODE_ID
),
teammate_connections AS (
    SELECT 
        pc1.player_name as player1, 
        pc2.player_name as player2, 
        pc1.club_name,
        pc1.EFFECTIVE_START as overlap_start,
        LEAST(pc1.EFFECTIVE_END, pc2.EFFECTIVE_END) as overlap_end
    FROM player_clubs pc1
    JOIN player_clubs pc2 ON pc1.club_id = pc2.club_id 
                          AND pc1.player_id < pc2.player_id
    WHERE pc1.EFFECTIVE_START <= pc2.EFFECTIVE_END 
      AND pc2.EFFECTIVE_START <= pc1.EFFECTIVE_END
)
SELECT player1, player2, club_name, overlap_start, overlap_end
FROM teammate_connections
ORDER BY player1, player2
LIMIT 10;

-- Find transfer chains between clubs
SELECT 'Transfer Chain Analysis:' as INFO;
WITH transfer_chain AS (
    SELECT 
        p.NAME as player_name,
        c1.NAME as from_club,
        c2.NAME as to_club,
        pf1.EFFECTIVE_END as transfer_date
    FROM V_PLAYER p
    JOIN V_PLAYS_FOR pf1 ON p.NODE_ID = pf1.PLAYER_ID
    JOIN V_CLUB c1 ON pf1.CLUB_ID = c1.NODE_ID
    JOIN V_PLAYS_FOR pf2 ON p.NODE_ID = pf2.PLAYER_ID
    JOIN V_CLUB c2 ON pf2.CLUB_ID = c2.NODE_ID
    WHERE pf1.CLUB_ID != pf2.CLUB_ID
      AND pf2.EFFECTIVE_START > pf1.EFFECTIVE_END
)
SELECT player_name, from_club, to_club, transfer_date
FROM transfer_chain
ORDER BY transfer_date DESC
LIMIT 10;