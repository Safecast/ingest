
-- 2017-03-26 ND: Allow 0-values for RH%.  Add sanity filter for (0,0) locs.
-- 2017-03-25 ND: Add float casts to mean update calculations to possibly address 0-mean issue.
-- 2017-03-24 ND: Double clustering radius to address GPS deviation: 13 -> 26 pixel x/y at zoom level 13
-- 2017-03-24 ND: Add device_id array output per location.
-- 2017-03-17 ND: Add support for excluding data with dev_test flag per Ray.


-- ===============================================================================================
--                                    Defs / Schema Creation
-- ===============================================================================================


BEGIN TRANSACTION;
    -- typedef: measurement_unit
    -- note: new units that need to flow through must be added to this.

    CREATE TYPE measurement_unit AS ENUM (
        'none',
        'lnd_7318u', 
        'lnd_7318c', 
        'lnd_7128ec',
        'lnd_712u',
        'opc_pm01_0',
        'opc_pm02_5',
        'opc_pm10_0',
        'pms_pm01_0',
        'pms_pm02_5',
        'pms_pm10_0',
        'env_temp',
        'env_humid',
        'env_press'
    );
COMMIT TRANSACTION;


BEGIN TRANSACTION;
    --
    -- nb: "xyt" is a column combining several fields with bitmasking:
    --
    --     Data:
    --          - Location
    --              Web Mercator pixel x/y at zoom level 13
    --          - Time
    --              Hours since 1970
    --          - is_motion
    --              For Solarcast devices, a flag that indicates
    --              operation in a special mode emulating a bGeigie,
    --              where only radiation sensors are active and data
    --              is submitted every 5 minutes.
    --
    --     Precision:         
    --                  x | 21 bits storage | 32 bits nominal
    --                  y | 21 bits storage | 32 bits nominal
    --          is_motion |  1 bit  storage |  8 bits nominal
    --                  t | 21 bits storage | 32 bits nominal
    --
    --     Arrangement (LSB):
    --          xxxxxxxx xxxxxxxx xxxxxyyy yyyyyyyy yyyyyyyy yymttttt tttttttt tttttttt
    --          76543210 76543210 76543210 76543210 76543210 76543210 76543210 76543210
    --              7        6        5        4       3        2        1        0
    --

    -- table def: deserialized data
    CREATE TABLE IF NOT EXISTS m2(         id SERIAL PRIMARY KEY,
                                  original_id INT NOT NULL,
                                         unit measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
				                        value FLOAT NOT NULL,
                                          xyt INT8 NOT NULL,
                                   updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL);

    -- table def: aggregated data by hour
    CREATE TABLE IF NOT EXISTS m3hh( id SERIAL PRIMARY KEY,
                                    xyt INT8 NOT NULL,
                                      u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                      v FLOAT NOT NULL,
                                      n INT NOT NULL);

    -- table def: aggregated data by day
    CREATE TABLE IF NOT EXISTS m3dd( id SERIAL PRIMARY KEY,
                                    xyt INT8 NOT NULL,
                                      u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                      v FLOAT NOT NULL,
                                      n INT NOT NULL);
COMMIT TRANSACTION;



-- index defs
BEGIN TRANSACTION;
    CREATE INDEX IF NOT EXISTS idx_m2_original_id ON m2(original_id);
    CREATE INDEX IF NOT EXISTS idx_m2_xyt_unit ON m2(xyt, unit);
    CREATE INDEX IF NOT EXISTS idx_m3hh_xyt_u ON m3hh(xyt, u);
    CREATE INDEX IF NOT EXISTS idx_m3dd_xyt_u ON m3dd(xyt, u);
COMMIT TRANSACTION;




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
BEGIN TRANSACTION;

INSERT INTO m2(original_id, unit, value, xyt, updated_at)
SELECT  id 
	   ,CAST(key AS measurement_unit) AS unit
       ,value::FLOAT AS value
       ,  ( ( ((payload->>'loc_lon')::FLOAT + 180.0) * 5825.422222222222 + 0.5)::INT8
            << 43) 
        | ( ( (0.5 - LN(  (1.0 + SIN((payload->>'loc_lat')::FLOAT * 0.0174532925199433))
                        / (1.0 - SIN((payload->>'loc_lat')::FLOAT * 0.0174532925199433)))
                     * 0.0795774715459477) * 2097152.0 + 0.5)::INT8
            << 22) 
        | ( (CASE WHEN COALESCE((payload->>'loc_motion')::BOOLEAN, FALSE) = TRUE THEN 1 ELSE 0 END)::INT8
            << 21)
        |   (EXTRACT(EPOCH FROM COALESCE(COALESCE((payload->>'when_captured'   )::TIMESTAMP WITHOUT TIME ZONE,
                                                  (payload->>'gateway_received')::TIMESTAMP WITHOUT TIME ZONE),
		 	                             created_at) ) / 3600)::INT8
       ,updated_at 
FROM (SELECT id, 
             device_id, 
			 created_at, 
			 updated_at, 
			 payload,
			 (jsonb_each_text(payload)).*
	  FROM measurements
      WHERE id IN (SELECT mid FROM c1)
        AND payload->>'loc_lat' IS NOT NULL
        AND payload->>'loc_lon' IS NOT NULL
        AND (payload->>'loc_lat')::FLOAT BETWEEN  -85.05 AND  85.05
        AND (payload->>'loc_lon')::FLOAT BETWEEN -180.00 AND 180.00
        AND (   (payload->>'loc_lat')::FLOAT NOT BETWEEN -1.0 AND 1.0
             OR (payload->>'loc_lon')::FLOAT NOT BETWEEN -1.0 AND 1.0)
        AND (    payload->>'when_captured'    IS NULL
             OR (payload->>'when_captured'   )::TIMESTAMP WITHOUT TIME ZONE BETWEEN TIMESTAMP '2011-03-11 00:00:00' 
                                                                                AND CURRENT_TIMESTAMP + INTERVAL '48 hours')
        AND (    payload->>'gateway_received' IS NULL
             OR (payload->>'gateway_received')::TIMESTAMP WITHOUT TIME ZONE BETWEEN TIMESTAMP '2011-03-11 00:00:00' 
                                                                                AND CURRENT_TIMESTAMP + INTERVAL '48 hours')
        AND COALESCE((payload->>'dev_test')::BOOLEAN, FALSE) = FALSE
        ) AS q
WHERE key IN ('lnd_7318u',  'lnd_7318c',  'lnd_7128ec', 'lnd_712u',
			  'opc_pm01_0', 'opc_pm02_5', 'opc_pm10_0',
			  'pms_pm01_0', 'pms_pm02_5', 'pms_pm10_0',
			  'env_temp',   'env_humid',  'env_press')
    AND (key NOT IN ('lnd_7318u',  'lnd_7318c',  'lnd_7128ec', 'lnd_712u',
		 	         'opc_pm01_0', 'opc_pm02_5', 'opc_pm10_0',
		 	         'pms_pm01_0', 'pms_pm02_5', 'pms_pm10_0',
			         'env_press')
         OR value::FLOAT > 0.0)
    AND (key NOT IN ('env_humid')
         OR value::FLOAT >= 0.0);

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
    SET  v = v * (n::FLOAT / (n::FLOAT + (SELECT new_n FROM newhh WHERE new_xyt = xyt AND new_u = u LIMIT 1)::FLOAT))
                                       + (SELECT new_v FROM newhh WHERE new_xyt = xyt AND new_u = u LIMIT 1)
                                     * ( (SELECT new_n FROM newhh WHERE new_xyt = xyt AND new_u = u LIMIT 1)::FLOAT
                           / (n::FLOAT + (SELECT new_n FROM newhh WHERE new_xyt = xyt AND new_u = u LIMIT 1)::FLOAT))
        ,n = n +                         (SELECT new_n FROM newhh WHERE new_xyt = xyt AND new_u = u LIMIT 1)
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
          FROM (SELECT     (new_xyt::bit(64) & x'FFFFFFFFFFE00000')::int8
                       | ( (new_xyt::bit(64) & x'00000000001FFFFF')::int8 / 24)
                       AS new_xyt
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
          FROM (SELECT     (new_xyt::bit(64) & x'FFFFFFFFFFE00000')::int8
                       | ( (new_xyt::bit(64) & x'00000000001FFFFF')::int8 / 24)
                       AS new_xyt
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
    SET  v = v * (n::FLOAT / (n::FLOAT + (SELECT new_n FROM newdd WHERE new_xyt = xyt AND new_u = u LIMIT 1)::FLOAT))
                                       + (SELECT new_v FROM newdd WHERE new_xyt = xyt AND new_u = u LIMIT 1)
                                     * ( (SELECT new_n FROM newdd WHERE new_xyt = xyt AND new_u = u LIMIT 1)::FLOAT
                           / (n::FLOAT + (SELECT new_n FROM newdd WHERE new_xyt = xyt AND new_u = u LIMIT 1)::FLOAT))
        ,n = n +                         (SELECT new_n FROM newdd WHERE new_xyt = xyt AND new_u = u LIMIT 1)
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




-- ===============================================================================================
--                        Output: Last 24 Hours, By Hour + Last 30 Days, By Day
-- ===============================================================================================


-- temp table to hold current hour so an hour change mid-execution doesn't break things
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS ch(h INT, ts TIMESTAMP WITHOUT TIME ZONE);
    TRUNCATE TABLE ch;

    INSERT INTO ch(h, ts) VALUES ((EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) / 3600)::INT, CURRENT_TIMESTAMP);
COMMIT TRANSACTION;


-- copy results to temp table for later modification as they're clustered
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outagg(xyt INT8, 
                                                  u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                  v FLOAT,
                                                  n INT);
    TRUNCATE TABLE outagg;

    INSERT INTO outagg(xyt, u, v, n)
    SELECT  xyt
           ,u
           ,v / (CASE WHEN u IN ('lnd_7318u', 'lnd_7318c') THEN 334.0
                      WHEN u IN ('lnd_7128ec', 'lnd_712u') THEN 120.5
                                                           ELSE   1.0 
                 END)
            AS value
           ,n
    FROM m3hh
    WHERE      (xyt::bit(64) & x'00000000001FFFFF')::int8 > (SELECT h FROM ch LIMIT 1) - 24
          AND ((xyt::bit(64) & x'0000000000200000') >> 21)::int8 = 0;
COMMIT TRANSACTION;



-- query for device_id list for extra info
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS pre_outdev(xyt INT8, 
                                              device_id INT8,
                                                      x INT,
                                                      y INT);
    TRUNCATE TABLE pre_outdev;

    INSERT INTO pre_outdev(xyt, device_id)
    SELECT DISTINCT AG.xyt, device_id
    FROM outagg as AG
    INNER JOIN m2
        ON m2.xyt = AG.xyt
    INNER JOIN measurements AS M
        ON M.id = m2.original_id;
COMMIT TRANSACTION;




-- create distinct locs with sample count for clustering
-- the idea being to cluster to the point with the most samples
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS out_locs(x INT, y INT, loc_n INT);
    TRUNCATE TABLE out_locs;

    INSERT INTO out_locs(x, y, loc_n)
    SELECT  ((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8
           ,((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8
           ,SUM(n)
    FROM outagg
    GROUP BY  ((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8
             ,((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8;
COMMIT TRANSACTION;


-- rewrite the x/y coordinates if a point with more samples was found within a ~500m radius
BEGIN TRANSACTION;
    UPDATE outagg
    SET xyt = (xyt::bit(64) & x'00000000003FFFFF')::int8
              | ((SELECT x FROM out_locs WHERE SQRT(   POWER(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8 - x, 2) 
                                                     + POWER(((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8 - y, 2) ) < 26
                                         ORDER BY loc_n DESC LIMIT 1)::int8 << 43)
              | ((SELECT y FROM out_locs WHERE SQRT(   POWER(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8 - x, 2) 
                                                     + POWER(((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8 - y, 2) ) < 26
                                         ORDER BY loc_n DESC LIMIT 1)::int8 << 22);
COMMIT TRANSACTION;



-- also do the same for the devices
BEGIN TRANSACTION;
    UPDATE pre_outdev
    SET xyt = (xyt::bit(64) & x'00000000003FFFFF')::int8
              | ((SELECT x FROM out_locs WHERE SQRT(   POWER(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8 - x, 2) 
                                                     + POWER(((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8 - y, 2) ) < 26
                                         ORDER BY loc_n DESC LIMIT 1)::int8 << 43)
              | ((SELECT y FROM out_locs WHERE SQRT(   POWER(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8 - x, 2) 
                                                     + POWER(((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8 - y, 2) ) < 26
                                         ORDER BY loc_n DESC LIMIT 1)::int8 << 22);
COMMIT TRANSACTION;



BEGIN TRANSACTION;
    UPDATE pre_outdev
    SET x = ((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8
       ,y = ((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8;
COMMIT TRANSACTION;


BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outdev(x INT, y INT, ids INT8[]);
    TRUNCATE TABLE outdev;

    INSERT INTO outdev(x, y, ids)
    SELECT x,y,array_agg(DISTINCT device_id) 
    FROM pre_outdev
    GROUP BY x,y;
COMMIT TRANSACTION;





-- since the x/y coordinates of previous different points may now be the same,
-- the data for those points needs to be re-aggregated for clustering to be
-- complete.
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outaggc(xyt INT8, 
                                                   u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                 xyu TEXT,
                                                   v FLOAT,
                                                   n INT);
    TRUNCATE TABLE outaggc;

    INSERT INTO outaggc(xyt, u, xyu, v, n)
    SELECT  xyt
           ,u
           ,(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8)::TEXT || '_' || 
            (((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8)::TEXT || '_' ||
            u::TEXT
           ,SUM(v * n) / SUM(n)
           ,SUM(n)
    FROM outagg
    GROUP BY  xyt
             ,u
             ,(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8)::TEXT || '_' || 
              (((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8)::TEXT || '_' ||
              u::TEXT;
COMMIT TRANSACTION;





-- next step after clustering it to pivot the data such that the time-series data eventually becomes an array.
-- as crosstab is limited to a single row name this will be a concatenation of x, y and unit
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outct(row_name TEXT, v FLOAT[]);
    TRUNCATE TABLE outct;

    INSERT INTO outct(row_name, v)
    SELECT  row_name
           ,ARRAY["-23", "-22", "-21", "-20", "-19", "-18", "-17", "-16", "-15", "-14", "-13", "-12", "-11", "-10", "-9", "-8", "-7", "-6", "-5", "-4", "-3", "-2", "-1", "0"]
    FROM (SELECT *
          FROM crosstab('SELECT xyu, (xyt::bit(64) & x''00000000001FFFFF'')::int8 - (SELECT h FROM ch LIMIT 1), v
                         FROM outaggc
                         ORDER BY xyu, (xyt::bit(64) & x''00000000001FFFFF'')::int8 - (SELECT h FROM ch LIMIT 1)'
                         ,'SELECT generate_series(-23,0) AS name')
          AS ct(row_name TEXT
                ,"-23" FLOAT, "-22" FLOAT, "-21" FLOAT, "-20" FLOAT
                ,"-19" FLOAT, "-18" FLOAT, "-17" FLOAT, "-16" FLOAT
                ,"-15" FLOAT, "-14" FLOAT, "-13" FLOAT, "-12" FLOAT
                ,"-11" FLOAT, "-10" FLOAT,  "-9" FLOAT,  "-8" FLOAT
                , "-7" FLOAT,  "-6" FLOAT,  "-5" FLOAT,  "-4" FLOAT
                , "-3" FLOAT,  "-2" FLOAT,  "-1" FLOAT,   "0" FLOAT)
         ) AS q;
COMMIT TRANSACTION;









-- DAYS VERSION
-- copy results to temp table for later modification as they're clustered
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outagg_dd(xyt INT8, 
                                                     u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                     v FLOAT,
                                                     n INT);
    TRUNCATE TABLE outagg_dd;

    INSERT INTO outagg_dd(xyt, u, v, n)
    SELECT  xyt
           ,u
           ,v / (CASE WHEN u IN ('lnd_7318u', 'lnd_7318c') THEN 334.0
                      WHEN u IN ('lnd_7128ec', 'lnd_712u') THEN 120.5
                                                           ELSE   1.0 
                 END)
            AS value
           ,n
    FROM m3dd
    WHERE      (xyt::bit(64) & x'00000000001FFFFF')::int8 > (SELECT h FROM ch LIMIT 1) / 24 - 30
          AND ((xyt::bit(64) & x'0000000000200000') >> 21)::int8 = 0;
COMMIT TRANSACTION;


-- DAYS VERSION
-- rewrite the x/y coordinates if a point with more samples was found within a ~500m radius
BEGIN TRANSACTION;
    UPDATE outagg_dd
    SET xyt = (xyt::bit(64) & x'00000000003FFFFF')::int8
              | ((SELECT x FROM out_locs WHERE SQRT(   POWER(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8 - x, 2) 
                                                     + POWER(((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8 - y, 2) ) < 26
                                         ORDER BY loc_n DESC LIMIT 1)::int8 << 43)
              | ((SELECT y FROM out_locs WHERE SQRT(   POWER(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8 - x, 2) 
                                                     + POWER(((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8 - y, 2) ) < 26
                                         ORDER BY loc_n DESC LIMIT 1)::int8 << 22);
COMMIT TRANSACTION;



-- DAYS VERSION
-- it's possible some 30d locs may not map to the 24h locs
-- these should be purged, as this is only used for graph data.
BEGIN TRANSACTION;
    DELETE FROM outagg_dd WHERE xyt IS NULL;
COMMIT TRANSACTION;



-- DAYS VERSION
-- since the x/y coordinates of previous different points may now be the same,
-- the data for those points needs to be re-aggregated for clustering to be
-- complete.
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outaggc_dd(xyt INT8, 
                                                      u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                    xyu TEXT,
                                                      v FLOAT,
                                                      n INT);
    TRUNCATE TABLE outaggc_dd;

    INSERT INTO outaggc_dd(xyt, u, xyu, v, n)
    SELECT  xyt
           ,u
           ,(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8)::TEXT || '_' || 
            (((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8)::TEXT || '_' ||
            u::TEXT
           ,SUM(v * n) / SUM(n)
           ,SUM(n)
    FROM outagg_dd
    GROUP BY  xyt
             ,u
             ,(((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8)::TEXT || '_' || 
              (((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8)::TEXT || '_' ||
              u::TEXT;
COMMIT TRANSACTION;


-- DAYS VERSION
-- next step after clustering it to pivot the data such that the time-series data eventually becomes an array.
-- as crosstab is limited to a single row name this will be a concatenation of x, y and unit
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outct_dd(row_name TEXT, v FLOAT[]);
    TRUNCATE TABLE outct_dd;

    INSERT INTO outct_dd(row_name, v)
    SELECT  row_name
           ,ARRAY["-29", "-28", "-27", "-26", "-25", "-24", "-23", "-22", "-21", "-20", "-19", "-18", "-17", "-16", "-15", "-14", "-13", "-12", "-11", "-10", "-9", "-8", "-7", "-6", "-5", "-4", "-3", "-2", "-1", "0"]
    FROM (SELECT *
          FROM crosstab('SELECT xyu, (xyt::bit(64) & x''00000000001FFFFF'')::int8 - (SELECT h FROM ch LIMIT 1) / 24, v
                         FROM outaggc_dd
                         ORDER BY xyu, (xyt::bit(64) & x''00000000001FFFFF'')::int8 - (SELECT h FROM ch LIMIT 1) / 24'
                         ,'SELECT generate_series(-29,0) AS name')
          AS ct(row_name TEXT
                                         , "-29" FLOAT, "-28" FLOAT
                ,"-27" FLOAT, "-26" FLOAT, "-25" FLOAT, "-24" FLOAT
                ,"-23" FLOAT, "-22" FLOAT, "-21" FLOAT, "-20" FLOAT
                ,"-19" FLOAT, "-18" FLOAT, "-17" FLOAT, "-16" FLOAT
                ,"-15" FLOAT, "-14" FLOAT, "-13" FLOAT, "-12" FLOAT
                ,"-11" FLOAT, "-10" FLOAT,  "-9" FLOAT,  "-8" FLOAT
                , "-7" FLOAT,  "-6" FLOAT,  "-5" FLOAT,  "-4" FLOAT
                , "-3" FLOAT,  "-2" FLOAT,  "-1" FLOAT,   "0" FLOAT)
         ) AS q;
COMMIT TRANSACTION;













-- now combine the crosstab output with the clustered points into a new table
BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outagg_ar(x INT,
                                                   y INT,
                                                   u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                  vs FLOAT[],
                                               vs_dd FLOAT[]);
    TRUNCATE TABLE outagg_ar;


    INSERT INTO outagg_ar(x, y, u)
    SELECT DISTINCT ((xyt::bit(64) & x'FFFFFC0000000000') >> 43)::int8
                   ,((xyt::bit(64) & x'000007FFFFC00000') >> 22)::int8
                   ,u
    FROM outaggc;

    UPDATE outagg_ar
    SET     vs = (SELECT v FROM outct    WHERE row_name = x::TEXT || '_' || y::TEXT || '_' || u::TEXT LIMIT 1)
        ,vs_dd = (SELECT v FROM outct_dd WHERE row_name = x::TEXT || '_' || y::TEXT || '_' || u::TEXT LIMIT 1);
COMMIT TRANSACTION;


BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE IF NOT EXISTS outjson(x JSON);
    TRUNCATE TABLE outjson;
COMMIT TRANSACTION;



BEGIN TRANSACTION;

-- final output to JSON
INSERT INTO outjson(x)
SELECT array_to_json(array_agg(row_to_json(t, FALSE)), FALSE)
FROM (SELECT  lat
             ,lon 
             ,array_to_json(ids) AS device_ids
             ,(SELECT array_to_json(array_agg(row_to_json(d, FALSE)), FALSE)
               FROM (SELECT  u::TEXT AS unit
                            ,CASE
                                    WHEN u = 'opc_pm01_0' THEN 'Alphasense PM 1.0 μg/m³'
                                    WHEN u = 'opc_pm02_5' THEN 'Alphasense PM 2.5 μg/m³'
                                    WHEN u = 'opc_pm10_0' THEN 'Alphasense PM 10.0 μg/m³'
                                    WHEN u = 'pms_pm01_0' THEN 'Plantower PM 1.0 μg/m³'
                                    WHEN u = 'pms_pm02_5' THEN 'Plantower PM 2.5 μg/m³'
                                    WHEN u = 'pms_pm10_0' THEN 'Plantower PM 10.0 μg/m³'
                                    WHEN u = 'lnd_712u'   THEN 'LND712 μSv/h'
                                    WHEN u = 'lnd_7318u'  THEN 'LND7318 μSv/h'
                                    WHEN u = 'lnd_7318c'  THEN 'LND7318 (γ) μSv/h'
                                    WHEN u = 'lnd_7128ec' THEN 'LND7128 μSv/h'
                                    WHEN u = 'env_temp'   THEN '°C'
                                    WHEN u = 'env_humid'  THEN 'RH%'
                                    WHEN u = 'env_press'  THEN 'hPa'
                                                        ELSE u::TEXT
                                END
                                AS ui_display_unit
                            ,CASE
                                    WHEN u IN ('lnd_7318u',  'opc_pm01_0', 'opc_pm02_5', 'opc_pm10_0')              THEN 1
                                    WHEN u IN ('pms_pm01_0', 'pms_pm02_5', 'pms_pm10_0')                            THEN 2
                                    WHEN u IN ('lnd_7318c',  'lnd_7128ec', 'env_temp',   'env_humid',  'env_press') THEN 3
                                                                                                                    ELSE 3
                                END
                                AS ui_display_category_id
                            ,(SELECT array_to_json(array_agg(row_to_json(dd, FALSE)), FALSE)
                              FROM ((SELECT  to_char(to_timestamp(((SELECT h FROM ch LIMIT 1)/24-29) * 86400), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                                AS start_date
                                            ,to_char( (SELECT ts FROM ch LIMIT 1), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                                AS end_date
                                            ,(SELECT h FROM ch LIMIT 1)/24 - 29 AS start_epoch_timepart
                                            ,(SELECT h FROM ch LIMIT 1)/24      AS   end_epoch_timepart
                                            ,86400 AS ss_per_epoch_timepart
                                            ,OA2.vs_dd as values
                                     FROM outagg_ar AS OA2
                                     WHERE OA.x = OA2.x
                                       AND OA.y = OA2.y
                                       AND OA.u = OA2.u
                                     LIMIT 1
                                     ) UNION (
                                     SELECT  to_char(to_timestamp(((SELECT h FROM ch LIMIT 1)-23) * 3600), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                                AS start_date
                                           ,to_char( (SELECT ts FROM ch LIMIT 1), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                                AS end_date
                                           ,(SELECT h FROM ch LIMIT 1) - 23 AS start_epoch_timepart
                                           ,(SELECT h FROM ch LIMIT 1)      AS   end_epoch_timepart
                                           ,3600 AS ss_per_epoch_timepart
                                           ,OA2.vs as values
                                     FROM outagg_ar AS OA2
                                     WHERE OA.x = OA2.x
                                       AND OA.y = OA2.y
                                       AND OA.u = OA2.u
                                     LIMIT 1)) AS dd
                             ) AS time_series
                     FROM outagg_ar AS OA
                     WHERE OA.x = OX.jx AND OA.y = OX.jy) AS d
              ) AS data
      FROM (SELECT DISTINCT  AR.x AS jx
                            ,AR.y AS jy 
                            ,90.0 - 360.0 * ATAN(EXP(-(0.5 - AR.y * 0.000000476837158203125000) * 6.283185307179586476925286766559)) * 0.31830988618379067153776752674503 AS lat
                            ,360.0 * (AR.x * 0.000000476837158203125000 - 0.5) AS lon
                            ,ids
            FROM outagg_ar AS AR
            LEFT JOIN outdev AS OD
                ON AR.x = OD.x
                AND AR.y = OD.y) AS OX
) AS t;

COMMIT TRANSACTION;


\COPY (SELECT x FROM outjson LIMIT 1) TO stdout


-- cleanup temp tables
BEGIN TRANSACTION;
    DROP TABLE outagg;
    DROP TABLE out_locs;
    DROP TABLE outct;
    DROP TABLE outaggc;
    DROP TABLE outagg_ar;
    DROP TABLE ch;
    DROP TABLE outagg_dd;
    DROP TABLE outct_dd;
    DROP TABLE outaggc_dd;
    DROP TABLE outjson;
    DROP TABLE pre_outdev;
    DROP TABLE outdev;
COMMIT TRANSACTION;

