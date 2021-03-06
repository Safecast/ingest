CREATE OR REPLACE FUNCTION mapview_24h_daily(BOOLEAN, TEXT) RETURNS JSON AS $$
DECLARE
    json_out_txt JSON;
BEGIN
-- $1 -- test filter -- restricts to not loc.is_motion and not dev_test
-- $2 -- date -- ISO date to run the query for, eg, '2018-12-04T01:23:45Z'
-- test filter should be TRUE for normal use

-- 2019-03-01 ND: Fix for syntax error in date parsing
-- 2019-02-28 ND: FIx for ambiguous column names preventing device_id list
-- 2018-12-04 ND: initial implementation




-- ===============================================================================================
--                                         ATTENTION!
-- ===============================================================================================
-- This script relies on data populated by the following:
-- 1. mapview_schema.sql            (no output)
-- 2. mapview_24h_processing.sql    (no output)
-- ===============================================================================================




-- ===============================================================================================
--                   Output: Single day, by hour/location/unit, for input date
-- ===============================================================================================



-- temp table to hold current hour so an hour change mid-execution doesn't break things
CREATE TEMPORARY TABLE IF NOT EXISTS ch(h INT, sh INT, eh INT, ts TIMESTAMP WITHOUT TIME ZONE);
TRUNCATE TABLE ch;

INSERT INTO ch(h, sh, eh, ts) VALUES (   ((EXTRACT(EPOCH FROM ($2::TIMESTAMP WITHOUT TIME ZONE)) / 3600)::INT                    ), 
                                         ((EXTRACT(EPOCH FROM ($2::TIMESTAMP WITHOUT TIME ZONE)) / 3600)::INT / 24       * 24    ), 
                                       ((((EXTRACT(EPOCH FROM ($2::TIMESTAMP WITHOUT TIME ZONE)) / 3600)::INT / 24) + 1) * 24 - 1), 
                                                              ($2::TIMESTAMP WITHOUT TIME ZONE));


-- copy results to temp table for later modification as they're clustered
CREATE TEMPORARY TABLE IF NOT EXISTS outagg(xyt INT8, 
                                              u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                              v FLOAT,
                                              n INT);
TRUNCATE TABLE outagg;

INSERT INTO outagg(xyt, u, v, n)
SELECT xyt, u, convert_cpm_to_usvh(v, u), n
FROM m3hh
WHERE   (xyt_decode_t(xyt) BETWEEN (SELECT sh FROM ch LIMIT 1) 
                               AND (SELECT eh FROM ch LIMIT 1) )
    AND (NOT $1 OR xyt_decode_m(xyt) = 0);


-- query for device_id list for extra info
CREATE TEMPORARY TABLE IF NOT EXISTS pre_outdev(xyt INT8, 
                                          device_id INT8,
                                                  x INT,
                                                  y INT);
TRUNCATE TABLE pre_outdev;


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
-- nb: disabled as clustering can shift depending on input
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
        ,ARRAY["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23"]
FROM (SELECT *
        FROM crosstab('SELECT xyu, xyt_decode_t(xyt) - (SELECT h FROM ch LIMIT 1), v
                       FROM outaggc
                       ORDER BY xyu, xyt_decode_t(xyt) - (SELECT h FROM ch LIMIT 1)'
                       ,'SELECT generate_series(0,23) AS name')
        AS ct(row_name TEXT
            ,  "0" FLOAT,   "1" FLOAT,   "2" FLOAT,   "3" FLOAT
            ,  "4" FLOAT,   "5" FLOAT,   "6" FLOAT,   "7" FLOAT
            ,  "8" FLOAT,   "9" FLOAT,  "10" FLOAT,  "11" FLOAT
            , "12" FLOAT,  "13" FLOAT,  "14" FLOAT,  "15" FLOAT
            , "16" FLOAT,  "17" FLOAT,  "18" FLOAT,  "19" FLOAT
            , "20" FLOAT,  "21" FLOAT,  "22" FLOAT,  "23" FLOAT)
        ) AS q;












-- now combine the crosstab output with the clustered points into a new table
CREATE TEMPORARY TABLE IF NOT EXISTS outagg_ar(x INT,
                                               y INT,
                                               u measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                              rn TEXT,
                                              vs FLOAT[],
                                          vs_min FLOAT,
                                          vs_max FLOAT,
                                          vs_cur FLOAT,
                                          vs_off BOOLEAN);
TRUNCATE TABLE outagg_ar;


INSERT INTO outagg_ar(x, y, u, rn)
SELECT DISTINCT  xyt_decode_x(xyt)
                ,xyt_decode_y(xyt)
                ,u
                ,xyt_decode_x(xyt)::TEXT || '_' || xyt_decode_y(xyt)::TEXT || '_' || u::TEXT
FROM outaggc;

UPDATE outagg_ar
SET             vs = (SELECT v FROM outct    WHERE row_name = rn LIMIT 1)
           ,vs_min = (SELECT MIN(v) FROM (SELECT unnest(v) AS v FROM outct    WHERE row_name = rn) AS q)
           ,vs_max = (SELECT MAX(v) FROM (SELECT unnest(v) AS v FROM outct    WHERE row_name = rn) AS q)
           ,vs_cur = (SELECT v FROM (SELECT unnest(array_reverse(v)) AS v FROM outct    WHERE row_name = rn) AS q WHERE v IS NOT NULL LIMIT 1)
           ,vs_off = (SELECT is_array_offline(v) FROM outct    WHERE row_name = rn LIMIT 1);







-- final output to JSON
json_out_txt := (
SELECT array_to_json(array_agg(row_to_json(t, FALSE)), FALSE)
FROM (SELECT  lat
             ,lon 
             ,array_to_json(ids) AS device_ids
             ,(SELECT array_to_json(array_agg(row_to_json(d, FALSE)), FALSE)
               FROM (SELECT  u::TEXT AS unit
                            ,get_ui_display_unit_parts(u) AS ui_display_unit_parts
                            ,(SELECT array_to_json(array_agg(row_to_json(dd, FALSE)), FALSE)
                              FROM ((
                                     SELECT  convert_tstz_to_isostring( to_timestamp( (SELECT sh FROM ch LIMIT 1) * 3600    ) ) AS start_date
                                            ,convert_tstz_to_isostring( to_timestamp( (SELECT eh FROM ch LIMIT 1) * 3600 - 1) ) AS   end_date
                                            ,(SELECT sh FROM ch LIMIT 1) AS start_epoch_timepart
                                            ,(SELECT eh FROM ch LIMIT 1) AS   end_epoch_timepart
                                            ,3600       AS ss_per_epoch_timepart
                                            ,OA2.vs     AS values
                                            ,OA2.vs_min AS min
                                            ,OA2.vs_max AS max
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
DROP TABLE pre_outdev;
DROP TABLE pre_pre_outdev;
DROP TABLE outdev;


RETURN json_out_txt;


END;
$$ LANGUAGE 'plpgsql' VOLATILE;



\COPY (SELECT mapview_24h_daily(TRUE, :v1)) TO stdout

