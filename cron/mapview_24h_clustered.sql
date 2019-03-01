CREATE OR REPLACE FUNCTION mapview_24h_clustered(BOOLEAN, BOOLEAN) RETURNS JSON AS $$
DECLARE
    json_out_txt JSON;
BEGIN
-- $1 -- date filter -- restricts to last 24 hours and last 30 days
-- $2 -- test filter -- restricts to not loc.is_motion and not dev_test
-- both should normally be true for standard output

-- 2019-03-01 ND: Fix for syntax error in boolean compare of distance
-- 2019-02-28 ND: Fix for ambiguous column names preventing device_id list
-- 2018-12-03 ND: Fix device_id query performance.
-- 2017-04-01 ND: Moved to function mapview_24h_clustered() except final \copy
-- 2017-03-29 ND: Moved schema defs to mapview_24h_processing.sql
-- 2017-03-29 ND: Moved schema defs to mapview_schema.sql
-- 2017-03-29 ND: Refactor code with functions - math/magic numbers, etc.
-- 2017-03-29 ND: Change output UI display unit to parts for UI formatting.
-- 2017-03-26 ND: Allow 0-values for RH%.  Add sanity filter for (0,0) locs.
-- 2017-03-25 ND: Add float casts to mean update calculations to possibly address 0-mean issue.
-- 2017-03-24 ND: Double clustering radius to address GPS deviation: 13 -> 26 pixel x/y at zoom level 13
-- 2017-03-24 ND: Add device_id array output per location.
-- 2017-03-17 ND: Add support for excluding data with dev_test flag per Ray.





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
--                        Output: Last 24 Hours, By Hour + Last 30 Days, By Day
-- ===============================================================================================



-- temp table to hold current hour so an hour change mid-execution doesn't break things
CREATE TEMPORARY TABLE IF NOT EXISTS ch(h INT, ts TIMESTAMP WITHOUT TIME ZONE);
TRUNCATE TABLE ch;

INSERT INTO ch(h, ts) VALUES ((EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) / 3600)::INT, CURRENT_TIMESTAMP);


-- copy results to temp table for later modification as they're clustered
CREATE TEMPORARY TABLE IF NOT EXISTS outagg(xyt INT8, 
                                              u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                              v FLOAT,
                                              n INT);
TRUNCATE TABLE outagg;

INSERT INTO outagg(xyt, u, v, n)
SELECT xyt, u, convert_cpm_to_usvh(v, u), n
FROM m3hh
WHERE   (NOT $1 OR xyt_decode_t(xyt) > (SELECT h FROM ch LIMIT 1) - 24)
    AND (NOT $2 OR xyt_decode_m(xyt) = 0);



-- query for device_id list for extra info
CREATE TEMPORARY TABLE IF NOT EXISTS pre_outdev(xyt INT8, 
                                          device_id INT8,
                                                  x INT,
                                                  y INT);
TRUNCATE TABLE pre_outdev;

--INSERT INTO pre_outdev(xyt, device_id)
--SELECT DISTINCT AG.xyt, device_id
--FROM outagg as AG
--INNER JOIN m2
--    ON m2.xyt = AG.xyt
--INNER JOIN measurements AS M
--    ON M.id = m2.original_id;
CREATE TEMPORARY TABLE IF NOT EXISTS pre_pre_outdev(oxyt INT8, 
                                                    omid INT, 
                                              odevice_id INT8);
TRUNCATE TABLE pre_pre_outdev;

INSERT INTO pre_pre_outdev(oxyt, omid)
SELECT xyt, original_id FROM m2 WHERE xyt IN (SELECT xyt FROM outagg);

UPDATE pre_pre_outdev
SET odevice_id = (SELECT device_id FROM measurements WHERE id = omid);

INSERT INTO pre_outdev(xyt, device_id)
SELECT DISTINCT oxyt, odevice_id
FROM pre_pre_outdev;



-- create distinct locs with sample count for clustering
-- the idea being to cluster to the point with the most samples
-- 2019-02-28 ND: preface x/y col names to avoid ambiguous naming issue
CREATE TEMPORARY TABLE IF NOT EXISTS out_locs(loc_x INT, loc_y INT, loc_n INT);
TRUNCATE TABLE out_locs;

INSERT INTO out_locs(loc_x, loc_y, loc_n)
SELECT   xyt_decode_x(xyt)
        ,xyt_decode_y(xyt)
        ,SUM(n)
FROM outagg
GROUP BY  xyt_decode_x(xyt)
         ,xyt_decode_y(xyt);


-- rewrite the x/y coordinates if a point with more samples was found within a ~500m radius
-- 2018-12-03 ND: "< 26.0" -> "<= 0.0" to remove clustering.  This is because it is otherwise impossible to sync with the new
--                daily results.
UPDATE outagg
SET xyt = xyt_update_encode_xy( xyt
                                ,(SELECT loc_x FROM out_locs WHERE calc_dist_pythag(loc_x::FLOAT, loc_y::FLOAT, xyt_decode_x(xyt)::FLOAT, xyt_decode_y(xyt)::FLOAT) <= 0.0
                                               ORDER BY loc_n DESC LIMIT 1)::INT8
                                ,(SELECT loc_y FROM out_locs WHERE calc_dist_pythag(loc_x::FLOAT, loc_y::FLOAT, xyt_decode_x(xyt)::FLOAT, xyt_decode_y(xyt)::FLOAT) <= 0.0
                                               ORDER BY loc_n DESC LIMIT 1)::INT8 );



-- also do the same for the devices
UPDATE pre_outdev
SET xyt = xyt_update_encode_xy( xyt
                                ,(SELECT loc_x FROM out_locs WHERE calc_dist_pythag(loc_x::FLOAT, loc_y::FLOAT, xyt_decode_x(xyt)::FLOAT, xyt_decode_y(xyt)::FLOAT) <= 0.0
                                               ORDER BY loc_n DESC LIMIT 1)::INT8
                                ,(SELECT loc_y FROM out_locs WHERE calc_dist_pythag(loc_x::FLOAT, loc_y::FLOAT, xyt_decode_x(xyt)::FLOAT, xyt_decode_y(xyt)::FLOAT) <= 0.0
                                               ORDER BY loc_n DESC LIMIT 1)::INT8 );


UPDATE pre_outdev
SET  x = xyt_decode_x(xyt)
    ,y = xyt_decode_y(xyt);



CREATE TEMPORARY TABLE IF NOT EXISTS outdev(x INT, y INT, ids INT8[]);
TRUNCATE TABLE outdev;

INSERT INTO outdev(x, y, ids)
SELECT x,y,array_agg(DISTINCT device_id) 
FROM pre_outdev
GROUP BY x,y;






-- since the x/y coordinates of previous different points may now be the same,
-- the data for those points needs to be re-aggregated for clustering to be
-- complete.
CREATE TEMPORARY TABLE IF NOT EXISTS outaggc(xyt INT8, 
                                               u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                             xyu TEXT,
                                               v FLOAT,
                                               n INT);
TRUNCATE TABLE outaggc;

INSERT INTO outaggc(xyt, u, xyu, v, n)
SELECT  xyt
        ,u
        ,xyt_decode_x(xyt)::TEXT || '_' || xyt_decode_y(xyt)::TEXT || '_' || u::TEXT
        ,SUM(v * n) / SUM(n)
        ,SUM(n)
FROM outagg
GROUP BY xyt
        ,u
        ,xyt_decode_x(xyt)::TEXT || '_' || xyt_decode_y(xyt)::TEXT || '_' || u::TEXT;





-- next step after clustering it to pivot the data such that the time-series data eventually becomes an array.
-- as crosstab is limited to a single row name this will be a concatenation of x, y and unit
CREATE TEMPORARY TABLE IF NOT EXISTS outct(row_name TEXT, v FLOAT[]);
TRUNCATE TABLE outct;

INSERT INTO outct(row_name, v)
SELECT  row_name
        ,ARRAY["-23", "-22", "-21", "-20", "-19", "-18", "-17", "-16", "-15", "-14", "-13", "-12", "-11", "-10", "-9", "-8", "-7", "-6", "-5", "-4", "-3", "-2", "-1", "0"]
FROM (SELECT *
        FROM crosstab('SELECT xyu, xyt_decode_t(xyt) - (SELECT h FROM ch LIMIT 1), v
                        FROM outaggc
                        ORDER BY xyu, xyt_decode_t(xyt) - (SELECT h FROM ch LIMIT 1)'
                        ,'SELECT generate_series(-23,0) AS name')
        AS ct(row_name TEXT
            ,"-23" FLOAT, "-22" FLOAT, "-21" FLOAT, "-20" FLOAT
            ,"-19" FLOAT, "-18" FLOAT, "-17" FLOAT, "-16" FLOAT
            ,"-15" FLOAT, "-14" FLOAT, "-13" FLOAT, "-12" FLOAT
            ,"-11" FLOAT, "-10" FLOAT,  "-9" FLOAT,  "-8" FLOAT
            , "-7" FLOAT,  "-6" FLOAT,  "-5" FLOAT,  "-4" FLOAT
            , "-3" FLOAT,  "-2" FLOAT,  "-1" FLOAT,   "0" FLOAT)
        ) AS q;









-- DAYS VERSION
-- copy results to temp table for later modification as they're clustered
CREATE TEMPORARY TABLE IF NOT EXISTS outagg_dd(xyt INT8, 
                                                 u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                 v FLOAT,
                                                 n INT);
TRUNCATE TABLE outagg_dd;

INSERT INTO outagg_dd(xyt, u, v, n)
SELECT  xyt, u, convert_cpm_to_usvh(v, u), n
FROM m3dd
WHERE   (NOT $1 OR xyt_decode_t(xyt) > (SELECT h FROM ch LIMIT 1) / 24 - 30)
    AND (NOT $2 OR xyt_decode_m(xyt) = 0);


-- DAYS VERSION
-- rewrite the x/y coordinates if a point with more samples was found within a ~500m radius
-- 2018-12-03 ND: "< 26.0" -> "<= 0.0" to remove clustering.  This is because it is otherwise impossible to sync with the new
--                daily results.
UPDATE outagg_dd
SET xyt = xyt_update_encode_xy( xyt
                                ,(SELECT loc_x FROM out_locs WHERE calc_dist_pythag(loc_x::FLOAT, loc_y::FLOAT, xyt_decode_x(xyt)::FLOAT, xyt_decode_y(xyt)::FLOAT) <= 0.0
                                               ORDER BY loc_n DESC LIMIT 1)::INT8
                                ,(SELECT loc_y FROM out_locs WHERE calc_dist_pythag(loc_x::FLOAT, loc_y::FLOAT, xyt_decode_x(xyt)::FLOAT, xyt_decode_y(xyt)::FLOAT) <= 0.0
                                               ORDER BY loc_n DESC LIMIT 1)::INT8 );



-- DAYS VERSION
-- it's possible some 30d locs may not map to the 24h locs
-- these should be purged, as this is only used for graph data.
DELETE FROM outagg_dd WHERE xyt IS NULL;



-- DAYS VERSION
-- since the x/y coordinates of previous different points may now be the same,
-- the data for those points needs to be re-aggregated for clustering to be
-- complete.
CREATE TEMPORARY TABLE IF NOT EXISTS outaggc_dd(xyt INT8, 
                                                  u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                xyu TEXT,
                                                  v FLOAT,
                                                  n INT);
TRUNCATE TABLE outaggc_dd;

INSERT INTO outaggc_dd(xyt, u, xyu, v, n)
SELECT  xyt
        ,u
        ,xyt_decode_x(xyt)::TEXT || '_' || xyt_decode_y(xyt)::TEXT || '_' || u::TEXT
        ,SUM(v * n) / SUM(n)
        ,SUM(n)
FROM outagg_dd
GROUP BY  xyt
         ,u
         ,xyt_decode_x(xyt)::TEXT || '_' || xyt_decode_y(xyt)::TEXT || '_' || u::TEXT;


-- DAYS VERSION
-- next step after clustering it to pivot the data such that the time-series data eventually becomes an array.
-- as crosstab is limited to a single row name this will be a concatenation of x, y and unit
CREATE TEMPORARY TABLE IF NOT EXISTS outct_dd(row_name TEXT, v FLOAT[]);
TRUNCATE TABLE outct_dd;

INSERT INTO outct_dd(row_name, v)
SELECT  row_name
        ,ARRAY["-29", "-28", "-27", "-26", "-25", "-24", "-23", "-22", "-21", "-20", "-19", "-18", "-17", "-16", "-15", "-14", "-13", "-12", "-11", "-10", "-9", "-8", "-7", "-6", "-5", "-4", "-3", "-2", "-1", "0"]
FROM (SELECT *
        FROM crosstab('SELECT xyu, xyt_decode_t(xyt) - (SELECT h FROM ch LIMIT 1) / 24, v
                        FROM outaggc_dd
                        ORDER BY xyu, xyt_decode_t(xyt) - (SELECT h FROM ch LIMIT 1) / 24'
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








-- now combine the crosstab output with the clustered points into a new table
CREATE TEMPORARY TABLE IF NOT EXISTS outagg_ar(x INT,
                                               y INT,
                                               u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                              rn TEXT,
                                              vs FLOAT[],
                                           vs_dd FLOAT[],
                                          vs_min FLOAT,
                                          vs_max FLOAT,
                                       vs_dd_min FLOAT,
                                       vs_dd_max FLOAT,
                                          vs_cur FLOAT,
                                       vs_dd_cur FLOAT,
                                          vs_off BOOLEAN,
                                       vs_dd_off BOOLEAN);
TRUNCATE TABLE outagg_ar;


INSERT INTO outagg_ar(x, y, u, rn)
SELECT DISTINCT  xyt_decode_x(xyt)
                ,xyt_decode_y(xyt)
                ,u
                ,xyt_decode_x(xyt)::TEXT || '_' || xyt_decode_y(xyt)::TEXT || '_' || u::TEXT
FROM outaggc;

UPDATE outagg_ar
SET             vs = (SELECT v FROM outct    WHERE row_name = rn LIMIT 1)
            ,vs_dd = (SELECT v FROM outct_dd WHERE row_name = rn LIMIT 1)
           ,vs_min = (SELECT MIN(v) FROM (SELECT unnest(v) AS v FROM outct    WHERE row_name = rn) AS q)
           ,vs_max = (SELECT MAX(v) FROM (SELECT unnest(v) AS v FROM outct    WHERE row_name = rn) AS q)
        ,vs_dd_min = (SELECT MIN(v) FROM (SELECT unnest(v) AS v FROM outct_dd WHERE row_name = rn) AS q)
        ,vs_dd_max = (SELECT MAX(v) FROM (SELECT unnest(v) AS v FROM outct_dd WHERE row_name = rn) AS q)
           ,vs_cur = (SELECT v FROM (SELECT unnest(array_reverse(v)) AS v FROM outct    WHERE row_name = rn) AS q WHERE v IS NOT NULL LIMIT 1)
        ,vs_dd_cur = (SELECT v FROM (SELECT unnest(array_reverse(v)) AS v FROM outct_dd WHERE row_name = rn) AS q WHERE v IS NOT NULL LIMIT 1)
           ,vs_off = (SELECT is_array_offline(v) FROM outct    WHERE row_name = rn LIMIT 1)
        ,vs_dd_off = (SELECT is_array_offline(v) FROM outct_dd WHERE row_name = rn LIMIT 1);







-- final output to JSON
json_out_txt := (
SELECT array_to_json(array_agg(row_to_json(t, FALSE)), FALSE)
FROM (SELECT  lat
             ,lon 
             ,array_to_json(ids) AS device_ids
             ,(SELECT array_to_json(array_agg(row_to_json(d, FALSE)), FALSE)
               FROM (SELECT  u::TEXT AS unit
                            ,get_ui_display_unit_parts(u) AS ui_display_unit_parts
                            ,get_ui_display_category(u)   AS ui_display_category_id
                            ,(SELECT array_to_json(array_agg(row_to_json(dd, FALSE)), FALSE)
                              FROM ((SELECT  convert_tstz_to_isostring( to_timestamp(((SELECT h FROM ch LIMIT 1)/24-29) * 86400) ) AS start_date
                                            ,convert_ts_to_isostring( (SELECT ts FROM ch LIMIT 1) ) AS end_date
                                            ,(SELECT h FROM ch LIMIT 1)/24 - 29 AS start_epoch_timepart
                                            ,(SELECT h FROM ch LIMIT 1)/24      AS   end_epoch_timepart
                                            ,86400         AS ss_per_epoch_timepart
                                            ,OA2.vs_dd     AS values
                                            ,OA2.vs_dd_min AS min
                                            ,OA2.vs_dd_max AS max
                                            ,OA2.vs_dd_cur AS value_newest
                                            ,OA2.vs_dd_off AS is_offline
                                     FROM outagg_ar AS OA2
                                     WHERE OA.x = OA2.x
                                       AND OA.y = OA2.y
                                       AND OA.u = OA2.u
                                     LIMIT 1
                                     ) UNION (
                                     SELECT  convert_tstz_to_isostring( to_timestamp(((SELECT h FROM ch LIMIT 1)-23) * 3600) ) AS start_date
                                            ,convert_ts_to_isostring( (SELECT ts FROM ch LIMIT 1) ) AS end_date
                                            ,(SELECT h FROM ch LIMIT 1) - 23 AS start_epoch_timepart
                                            ,(SELECT h FROM ch LIMIT 1)      AS   end_epoch_timepart
                                            ,3600       AS ss_per_epoch_timepart
                                            ,OA2.vs     AS values
                                            ,OA2.vs_min AS min
                                            ,OA2.vs_max AS max
                                            ,OA2.vs_cur AS value_newest
                                            ,OA2.vs_off AS is_offline
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
                            ,epsg3857_py_to_lat_z13(AR.y) AS lat
                            ,epsg3857_px_to_lon_z13(AR.x) AS lon
                            ,ids
            FROM outagg_ar AS AR
            LEFT JOIN outdev AS OD
                ON AR.x = OD.x
                AND AR.y = OD.y) AS OX
) AS t);



-- cleanup temp tables
DROP TABLE outagg;
DROP TABLE out_locs;
DROP TABLE outct;
DROP TABLE outaggc;
DROP TABLE outagg_ar;
DROP TABLE ch;
DROP TABLE outagg_dd;
DROP TABLE outct_dd;
DROP TABLE outaggc_dd;
DROP TABLE pre_outdev;
DROP TABLE pre_pre_outdev;
DROP TABLE outdev;


RETURN json_out_txt;


END;
$$ LANGUAGE 'plpgsql' VOLATILE;



\COPY (SELECT mapview_24h_clustered(TRUE, TRUE)) TO stdout

