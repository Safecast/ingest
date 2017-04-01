-- 2017-04-01 ND: Temporarily aggregate dev_test=true payloads
-- 2017-03-30 ND: Add typechecking to JSON input
-- 2017-03-29 ND: Moved permanent table updates to their own .sql script




-- ===============================================================================================
--                                         ATTENTION!
-- ===============================================================================================
-- This script should not normally be executed by itself.
-- The following serial execution is expected:
-- 1. mapview_schema.sql            (no output)
-- 2. mapview_24h_processing.sql    (no output)
-- 3. mapview_24_clustered.sql      (JSON out)
-- ===============================================================================================



-- ===============================================================================================
--                                    Data Update - All/Shared
-- ===============================================================================================

-- new candidate rows to (possibly) add
-- depending on arch changes in future, this may need to be done with updated_at
-- instead of rowid, but rowid should be faster and have fewer errors for now.
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS c1(mid INT);
    TRUNCATE TABLE c1;

    INSERT INTO c1(mid)
    SELECT id FROM measurements
    WHERE id > COALESCE((SELECT MAX(original_id) FROM m2), 0);
COMMIT TRANSACTION;




-- add candidate rows to the deserialized measurements table
-- nb: an annoying thing about typechecks here is that the WHERE clause can get reodered
--     including nested boolean logic.  thus, case statements are used to guarantee eval
--     order.
-- nb: additionally, note that the "is_float()" etc functions will evaluate as false
--     with NULLs,as the NULL value return is always evaluated to boolean false.
--     thus, there is no need for a separatel NULL test when using these functions.
-- nb: For NaN values ('NaN', '-NaN', possibly other text forms), these need not be
--     explicitly tested for as long as an upper range is defined, as they are treated
--     as +infinity in gt/lt tests.  thus, for measurements, the upper limit is 
--     arbitrarily 1<<30.  for lat/lon, the limits are the web mercator coordinate system 
--     limits.
-- nb: Next up, we have '-inf' and '+inf'.  Like NaN, bounds checking removes the need
--     for an explicit test.
BEGIN TRANSACTION;

INSERT INTO m2(original_id, unit, value, xyt, updated_at)
SELECT  id 
	   ,key::measurement_unit AS unit
       ,value::FLOAT AS value
       ,xyt_convert_lat_lon_ism_ts_to_xyt( (payload->>'loc_lat')::FLOAT
                                          ,(payload->>'loc_lon')::FLOAT
                                          ,(CASE WHEN payload->>'loc_motion' IS NULL THEN FALSE ELSE TRUE END)
                                          ,COALESCE(COALESCE( (payload->>'when_captured'   )::TIMESTAMP WITHOUT TIME ZONE
                                                             ,(payload->>'gateway_received')::TIMESTAMP WITHOUT TIME ZONE)
                                                    ,created_at) )
       ,updated_at 
FROM (SELECT id
             ,device_id 
             ,created_at 
             ,updated_at
             ,payload
             ,(jsonb_each_text(payload)).*
      FROM measurements
      WHERE id IN (SELECT mid FROM c1)
        AND (CASE WHEN is_float(payload->>'loc_lat') 
                   AND is_float(payload->>'loc_lon') 
                       THEN     (payload->>'loc_lat')::FLOAT BETWEEN  -85.05 AND  85.05 
                            AND (payload->>'loc_lon')::FLOAT BETWEEN -180.00 AND 180.00
                            AND (   (payload->>'loc_lat')::FLOAT NOT BETWEEN -1.0 AND 1.0
                                 OR (payload->>'loc_lon')::FLOAT NOT BETWEEN -1.0 AND 1.0)
                  ELSE FALSE
             END)
        AND (CASE WHEN              payload->>'when_captured' IS NULL THEN TRUE
                  WHEN is_timestamp(payload->>'when_captured') 
                              THEN (payload->>'when_captured')::TIMESTAMP WITHOUT TIME ZONE BETWEEN TIMESTAMP '2011-03-11 00:00:00' 
                                                                                                AND CURRENT_TIMESTAMP + INTERVAL '48 hours'
                  ELSE FALSE
             END)
        AND (CASE WHEN              payload->>'gateway_received' IS NULL THEN TRUE
                  WHEN is_timestamp(payload->>'gateway_received') 
                              THEN (payload->>'gateway_received')::TIMESTAMP WITHOUT TIME ZONE BETWEEN TIMESTAMP '2011-03-11 00:00:00' 
                                                                                                   AND CURRENT_TIMESTAMP + INTERVAL '48 hours'
                  ELSE FALSE
             END)
             /*
        AND (CASE WHEN payload->>'dev_test' IS NULL THEN TRUE
                  WHEN is_boolean(payload->>'dev_test') THEN (payload->>'dev_test')::BOOLEAN = FALSE
                  ELSE FALSE
             END)
             */
        ) AS q
WHERE is_accepted_unit(key)
    AND (CASE WHEN is_float(value) THEN is_value_in_range_for_unit(value::FLOAT, key::measurement_unit) ELSE FALSE END);

COMMIT TRANSACTION;






-- regenerate candidate row list based off what actually made it in
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS c2(m2id INT);
    TRUNCATE TABLE c2;

    INSERT INTO c2(m2id)
    SELECT DISTINCT m2.id
    FROM c1
    INNER JOIN m2
        ON m2.original_id = c1.mid;
COMMIT TRANSACTION;



-- cleanup temp table
BEGIN TRANSACTION;
    DROP TABLE c1;
COMMIT TRANSACTION;




BEGIN TRANSACTION;
    -- make list of new aggregate values to either be updated or added to the aggregate tables
    CREATE TEMPORARY TABLE IF NOT EXISTS newhh(new_xyt INT8, 
                                                 new_u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                 new_v FLOAT,
                                                 new_n INT,
                                                    up BOOLEAN);
    TRUNCATE TABLE newhh;

    -- find where UPDATEs can be made
    INSERT INTO newhh(new_xyt, new_u, new_v, new_n, up)
    SELECT q.xyt, q.unit, q.value, q.n, TRUE
    FROM (SELECT m2.xyt AS xyt, m2.unit AS unit, AVG(m2.value) AS value, COUNT(*) AS n
          FROM m2
          WHERE m2.id IN (SELECT m2id FROM c2)
          GROUP BY xyt, unit) AS q
    INNER JOIN m3hh
        ON m3hh.xyt = q.xyt
        AND m3hh.u = q.unit;

    -- find where new rows need to be CREATEd
    INSERT INTO newhh(new_xyt, new_u, new_v, new_n, up)
    SELECT q.xyt, q.unit, q.value, q.n, FALSE
    FROM (SELECT m2.xyt AS xyt, m2.unit AS unit, AVG(m2.value) AS value, COUNT(*) AS n
          FROM m2
          WHERE m2.id IN (SELECT m2id FROM c2)
          GROUP BY xyt, unit) AS q
    LEFT JOIN m3hh
        ON m3hh.xyt = q.xyt
        AND m3hh.u = q.unit
    WHERE m3hh.xyt IS NULL;
COMMIT TRANSACTION;




BEGIN TRANSACTION;
    -- now update the hourly aggregate table rows by combining the two means and sample counts
    -- this is sort of mathematically cheating, but testing showed that for double-precision values,
    -- error was 0.0000000000108855% for 10,000,000 iterations using ramped test values
    UPDATE m3hh
    SET  v = calc_combined_mean( v, (SELECT new_v FROM newhh WHERE new_xyt = xyt AND new_u = u LIMIT 1)
                                ,n, (SELECT new_n FROM newhh WHERE new_xyt = xyt AND new_u = u LIMIT 1) )
        ,n = n +                    (SELECT new_n FROM newhh WHERE new_xyt = xyt AND new_u = u LIMIT 1)
    WHERE id IN (SELECT id FROM m3hh
                 INNER JOIN newhh
                    ON xyt = new_xyt
                    AND  u = new_u
                WHERE up = TRUE);

    -- if there wasn't already a bin, add a new row instead.
    INSERT INTO m3hh(xyt, u, v, n)
    SELECT new_xyt, new_u, new_v, new_n
    FROM newhh
    WHERE up = FALSE;
COMMIT TRANSACTION;



BEGIN TRANSACTION;
    -- now, repeat the preocess for the daily aggregate table
    CREATE TEMPORARY TABLE IF NOT EXISTS newdd(new_xyt INT8, 
                                                 new_u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                 new_v FLOAT,
                                                 new_n INT,
                                                    up BOOLEAN);
    TRUNCATE TABLE newdd;




    -- steal the hourly rows, but convert hours to days within the xyt value
    -- also need to re-aggregate after the xyt modification
    INSERT INTO newdd(new_xyt, new_u, new_v, new_n, up)
    SELECT new_xyt, new_u, new_v, new_n, TRUE
    FROM (SELECT new_xyt, new_u, SUM(new_v * new_n) / SUM(new_n) AS new_v, SUM(new_n) AS new_n
          FROM (SELECT  xyt_update_convert_thh_to_tdd(new_xyt) AS new_xyt
                       ,new_u
                       ,new_v
                       ,new_n
                FROM newhh) AS u
          GROUP BY new_xyt, new_u) AS q
    INNER JOIN m3dd
        ON xyt = new_xyt
        AND  u = new_u;


    -- now find which rows need to be CREATEd
    INSERT INTO newdd(new_xyt, new_u, new_v, new_n, up)
    SELECT new_xyt, new_u, new_v, new_n, FALSE
    FROM (SELECT new_xyt, new_u, SUM(new_v * new_n) / SUM(new_n) AS new_v, SUM(new_n) AS new_n
          FROM (SELECT  xyt_update_convert_thh_to_tdd(new_xyt) AS new_xyt
                       ,new_u
                       ,new_v
                       ,new_n
                FROM newhh) AS u
          GROUP BY new_xyt, new_u) AS q
    LEFT JOIN m3dd
        ON xyt = new_xyt
        AND  u = new_u
    WHERE xyt IS NULL;
COMMIT TRANSACTION;



BEGIN TRANSACTION;
    -- now update the daily aggregate table rows by combining the two means and sample counts
    UPDATE m3dd
    SET  v = calc_combined_mean( v, (SELECT new_v FROM newdd WHERE new_xyt = xyt AND new_u = u LIMIT 1)
                                ,n, (SELECT new_n FROM newdd WHERE new_xyt = xyt AND new_u = u LIMIT 1) )
        ,n = n +                    (SELECT new_n FROM newdd WHERE new_xyt = xyt AND new_u = u LIMIT 1)
    WHERE id IN (SELECT id FROM m3dd
                 INNER JOIN newdd
                    ON xyt = new_xyt
                    AND  u = new_u
                WHERE up = TRUE);

    -- if there wasn't already a bin, add a new row instead.
    INSERT INTO m3dd(xyt, u, v, n)
    SELECT new_xyt, new_u, new_v, new_n
    FROM newdd
    WHERE up = FALSE;    
COMMIT TRANSACTION;


-- free candidates list and temp udpate tables
BEGIN TRANSACTION;
    DROP TABLE c2;
    DROP TABLE newhh;
    DROP TABLE newdd;
COMMIT TRANSACTION;