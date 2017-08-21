-- 2017-04-24 ND: Add idx_measurements_created, idx_measurements_device_id to managed indices.
-- 2017-04-20 ND: Add unit support: lnd_712, lnd_712c, lnd_78017, lnd_78017u, lnd_78017b, lnd_78017c, lnd_7318, lnd_7128
-- 2017-04-07 ND: Add dev_label to measurement_unit, table/index defs for device stats metadata
-- 2017-04-05 ND: Add table/index defs for device stats.
-- 2017-04-05 ND: Add scalar min/max functions.
-- 2017-04-05 ND: Add new enum types for other queries
-- 2017-03-30 ND: Add typecheck functions
-- 2017-03-29 ND: Moved schema/defs to their own .sql script




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
--                                    Defs / Schema Creation
-- ===============================================================================================


BEGIN TRANSACTION;
    -- typedef: measurement_unit
    -- note: new units that need to flow through must be added to this.

    CREATE TYPE measurement_unit AS ENUM (
        'none',
        'lnd_7318', 
        'lnd_7318u', 
        'lnd_7318c', 
        'lnd_7128',
        'lnd_7128ec',
        'lnd_712',
        'lnd_712u',
        'lnd_712c',
        'lnd_78017',
        'lnd_78017u',
        'lnd_78017c',
        'lnd_78017w',
        'opc_pm01_0',
        'opc_pm02_5',
        'opc_pm10_0',
        'pms_pm01_0',
        'pms_pm02_5',
        'pms_pm10_0',
        'env_temp',
        'env_humid',
        'env_press',
        'bat_charge',
        'bat_current',
        'bat_voltage',
        'dev_humid',
        'dev_press',
        'dev_temp',
        'loc_lat',
        'loc_lon',
        'dev_label',
        'dev_test');
COMMIT TRANSACTION;


-- Helper functions

BEGIN TRANSACTION;
    -- Generic helper functions

    -- Generic array reverse
    -- From https://wiki.postgresql.org/wiki/Array_reverse
    CREATE OR REPLACE FUNCTION array_reverse(anyarray) RETURNS anyarray AS $$
    SELECT ARRAY(
        SELECT $1[i]
        FROM generate_series(
            array_lower($1,1),
            array_upper($1,1)
        ) AS s(i)
        ORDER BY i DESC
    );
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    -- Coverts timestamp to ISO text format
    CREATE OR REPLACE FUNCTION convert_ts_to_isostring(TIMESTAMP WITHOUT TIME ZONE) RETURNS TEXT AS $$
    SELECT to_char($1, 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION convert_tstz_to_isostring(TIMESTAMP WITH TIME ZONE) RETURNS TEXT AS $$
    SELECT convert_ts_to_isostring(($1)::TIMESTAMP WITHOUT TIME ZONE);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    -- Pythagorean distance computation
    CREATE OR REPLACE FUNCTION calc_dist_pythag(FLOAT, FLOAT, FLOAT, FLOAT) RETURNS FLOAT AS $$
    SELECT SQRT(  POWER($1 - $3, 2.0)
                + POWER($2 - $4, 2.0) );
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;


    CREATE OR REPLACE FUNCTION scalar_max(FLOAT, FLOAT) RETURNS FLOAT AS $$
    SELECT CASE WHEN $1 IS NULL THEN $2
                WHEN $2 IS NULL THEN $1
                WHEN $1 > $2    THEN $1
                ELSE $2
           END
    $$ LANGUAGE 'sql' IMMUTABLE;

    CREATE OR REPLACE FUNCTION scalar_max(INT, INT) RETURNS INT AS $$
    SELECT CASE WHEN $1 IS NULL THEN $2
                WHEN $2 IS NULL THEN $1
                WHEN $1 > $2    THEN $1
                ELSE $2
           END
    $$ LANGUAGE 'sql' IMMUTABLE;

    CREATE OR REPLACE FUNCTION scalar_max(TIMESTAMP WITHOUT TIME ZONE, TIMESTAMP WITHOUT TIME ZONE) RETURNS TIMESTAMP WITHOUT TIME ZONE AS $$
    SELECT CASE WHEN $1 IS NULL THEN $2
                WHEN $2 IS NULL THEN $1
                WHEN $1 > $2    THEN $1
                ELSE $2
           END
    $$ LANGUAGE 'sql' IMMUTABLE;

    CREATE OR REPLACE FUNCTION scalar_min(FLOAT, FLOAT) RETURNS FLOAT AS $$
    SELECT CASE WHEN $1 IS NULL THEN $2
                WHEN $2 IS NULL THEN $1
                WHEN $1 < $2    THEN $1
                ELSE $2
           END
    $$ LANGUAGE 'sql' IMMUTABLE;

    CREATE OR REPLACE FUNCTION scalar_min(INT, INT) RETURNS INT AS $$
    SELECT CASE WHEN $1 IS NULL THEN $2
                WHEN $2 IS NULL THEN $1
                WHEN $1 < $2    THEN $1
                ELSE $2
           END
    $$ LANGUAGE 'sql' IMMUTABLE;

    CREATE OR REPLACE FUNCTION scalar_min(TIMESTAMP WITHOUT TIME ZONE, TIMESTAMP WITHOUT TIME ZONE) RETURNS TIMESTAMP WITHOUT TIME ZONE AS $$
    SELECT CASE WHEN $1 IS NULL THEN $2
                WHEN $2 IS NULL THEN $1
                WHEN $1 < $2    THEN $1
                ELSE $2
           END
    $$ LANGUAGE 'sql' IMMUTABLE;


    CREATE OR REPLACE FUNCTION is_nan(FLOAT) RETURNS BOOLEAN AS $$
    SELECT $1 = 'NaN'::FLOAT;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;


    -- http://stackoverflow.com/questions/16195986/isnumeric-with-postgresql
    CREATE OR REPLACE FUNCTION is_numeric(TEXT) RETURNS BOOLEAN AS $$
    DECLARE x NUMERIC;
    BEGIN
        x = $1::NUMERIC;
        RETURN TRUE;
    EXCEPTION WHEN others THEN
        RETURN FALSE;
    END;
    $$ LANGUAGE plpgsql STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION is_float(TEXT) RETURNS BOOLEAN AS $$
    DECLARE x FLOAT;
    BEGIN
        x = $1::FLOAT;
        RETURN TRUE;
    EXCEPTION WHEN others THEN
        RETURN FALSE;
    END;
    $$ LANGUAGE plpgsql STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION is_timestamp(TEXT) RETURNS BOOLEAN AS $$
    DECLARE x TIMESTAMP WITHOUT TIME ZONE;
    BEGIN
        x = $1::TIMESTAMP WITHOUT TIME ZONE;
        RETURN TRUE;
    EXCEPTION WHEN others THEN
        RETURN FALSE;
    END;
    $$ LANGUAGE plpgsql STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION is_boolean(TEXT) RETURNS BOOLEAN AS $$
    DECLARE x BOOLEAN;
    BEGIN
        x = $1::BOOLEAN;
        RETURN TRUE;
    EXCEPTION WHEN others THEN
        RETURN FALSE;
    END;
    $$ LANGUAGE plpgsql STRICT IMMUTABLE;


    -- Derived from http://www.joshslauson.com/2014/11/15/automatically-define-postgresql-crosstab-output-columns/
    -- This is intended to be used in place of the regular crosstab function.
    CREATE OR REPLACE FUNCTION crosstab_autocols(query varchar, columns_query varchar, column_type varchar default 'FLOAT')
    RETURNS VARCHAR
    AS $$
    DECLARE
        columns_sql varchar;
        columns_txt varchar;
    BEGIN
        columns_sql = 'SELECT ''row_name TEXT, "'' || string_agg(name::TEXT, ''" ' || column_type || ', "'' ) || ''" ' || column_type || ''' FROM (' || columns_query || ') subquery';
        EXECUTE columns_sql INTO columns_txt;
        RETURN 'SELECT * FROM crosstab(''' || REPLACE(query, '''', '''''') || ''',''' || REPLACE(columns_query, '''', '''''') || ''') as ct(' || columns_txt || ');';
    END
    $$LANGUAGE plpgsql STRICT IMMUTABLE;
    COMMIT TRANSACTION;



BEGIN TRANSACTION;
    -- Misc helper functions

    -- Converts CPM to uSv/h for known radiation units.  Returns original value if not radiation unit.
    CREATE OR REPLACE FUNCTION convert_cpm_to_usvh(FLOAT, measurement_unit) RETURNS FLOAT AS $$
    SELECT $1 / (CASE WHEN $2 IN ('lnd_7318',  'lnd_7318u',  'lnd_7318c')                       THEN 334.0
                      WHEN $2 IN ('lnd_7128',  'lnd_7128ec', 'lnd_712', 'lnd_712u', 'lnd_712c') THEN 120.5
                      WHEN $2 IN ('lnd_78017', 'lnd_78017u', 'lnd_78017c', 'lnd_78017w')        THEN 960.0
                                                                                                ELSE   1.0 
                 END);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;


    -- Combines two means.  Note the number of samples also must be updated.
    -- $1 FLOAT: mean1
    -- $2 FLOAT: mean2
    -- $3 INT:      n1
    -- $4 INT:      n2
    CREATE OR REPLACE FUNCTION calc_combined_mean(FLOAT, FLOAT, INT, INT) RETURNS FLOAT AS $$
    SELECT   $1 * (($3)::FLOAT / (($3 + $4)::FLOAT))
           + $2 * (($4)::FLOAT / (($3 + $4)::FLOAT));
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;


    -- For timeseries aggregate data, considers the series "offline" if the
    -- latest two bins are null.  It cannot be only one bin because of bin
    -- breakpoints. (eg, hour changes but unit hasn't posted yet)
    -- It may be better to requery the latest value's date instead.
    CREATE OR REPLACE FUNCTION is_array_offline(anyarray) RETURNS BOOLEAN AS $$
    SELECT array_upper($1,1) >= 2
        AND (array_reverse($1))[array_upper($1,1)    ] IS NULL
        AND (array_reverse($1))[array_upper($1,1) - 1] IS NULL;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;
COMMIT TRANSACTION;




BEGIN TRANSACTION;
    -- Coordinate system reprojection helper functions:
    -- * EPSG3857 web mercator pixel x/y at zoom level 13
    -- * EPSG4326 lat/lon
    CREATE OR REPLACE FUNCTION epsg3857_px_to_lon_z13(INT) RETURNS FLOAT AS $$
    SELECT 360.0 * (($1)::FLOAT * 0.000000476837158203125000 - 0.5);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION epsg3857_py_to_lat_z13(INT) RETURNS FLOAT AS $$
    SELECT 90.0 - 360.0 * ATAN(EXP(-(0.5 - ($1)::FLOAT * 0.000000476837158203125000) * 6.283185307179586476925286766559)) * 0.31830988618379067153776752674503;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION lon_to_epsg3857_px_z13(FLOAT) RETURNS INT AS $$
    SELECT (($1 + 180.0) * 5825.422222222222 + 0.5)::INT;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION lat_to_epsg3857_py_z13(FLOAT) RETURNS INT AS $$
    SELECT ( (0.5 - LN(  (1.0 + SIN($1 * 0.0174532925199433))
                       / (1.0 - SIN($1 * 0.0174532925199433)))
                    * 0.0795774715459477) * 2097152.0 + 0.5)::INT;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;
COMMIT TRANSACTION;




BEGIN TRANSACTION;
    -- "xyt" multifield column-related helper functions

    CREATE OR REPLACE FUNCTION xyt_convert_ts_to_t(TIMESTAMP WITHOUT TIME ZONE) RETURNS INT8 AS $$
    SELECT (EXTRACT(EPOCH FROM $1) / 3600)::INT8;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_convert_t_to_ts(INT8) RETURNS TIMESTAMP WITHOUT TIME ZONE AS $$
    SELECT to_timestamp($1 * 3600)::TIMESTAMP WITHOUT TIME ZONE;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_convert_t_to_isostring(INT8) RETURNS TEXT AS $$
    SELECT convert_ts_to_isostring(to_timestamp($1 * 3600)::TIMESTAMP WITHOUT TIME ZONE);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_convert_ism_to_m(BOOLEAN) RETURNS INT8 AS $$
    SELECT (CASE WHEN $1 = TRUE THEN 1 ELSE 0 END)::INT8;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;



    CREATE OR REPLACE FUNCTION xyt_encode_x(INT8) RETURNS INT8 AS $$
    SELECT $1 << 43;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_encode_y(INT8) RETURNS INT8 AS $$
    SELECT $1 << 22;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_encode_m(INT8) RETURNS INT8 AS $$
    SELECT $1 << 21;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_encode_t(INT8) RETURNS INT8 AS $$
    SELECT $1;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;



    CREATE OR REPLACE FUNCTION xyt_encode_xymt(INT8, INT8, INT8, INT8) RETURNS INT8 AS $$
    SELECT   xyt_encode_x($1)
           | xyt_encode_y($2)
           | xyt_encode_m($3)
           | xyt_encode_t($4);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;



    CREATE OR REPLACE FUNCTION xyt_convert_lat_lon_ism_ts_to_xyt(FLOAT, FLOAT, BOOLEAN, TIMESTAMP WITHOUT TIME ZONE) RETURNS INT8 AS $$
    SELECT xyt_encode_xymt(  (lon_to_epsg3857_px_z13($2))::INT8
                            ,(lat_to_epsg3857_py_z13($1))::INT8
                               ,xyt_convert_ism_to_m($3)
                                ,xyt_convert_ts_to_t($4) );
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;




    CREATE OR REPLACE FUNCTION xyt_decode_x(INT8) RETURNS INT8 AS $$
    SELECT ((($1)::bit(64) & x'FFFFFC0000000000') >> 43)::INT8
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_decode_y(INT8) RETURNS INT8 AS $$
    SELECT ((($1)::bit(64) & x'000007FFFFC00000') >> 22)::INT8
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_decode_m(INT8) RETURNS INT8 AS $$
    SELECT ((($1)::bit(64) & x'0000000000200000') >> 21)::INT8
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_decode_t(INT8) RETURNS INT8 AS $$
    SELECT (($1)::bit(64) & x'00000000001FFFFF')::INT8
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;




    CREATE OR REPLACE FUNCTION xyt_clear_xy(INT8) RETURNS INT8 AS $$
    SELECT (($1)::bit(64) & x'00000000003FFFFF')::INT8
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_clear_xym(INT8) RETURNS INT8 AS $$
    SELECT xyt_decode_t($1);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_clear_t(INT8) RETURNS INT8 AS $$
    SELECT (($1)::bit(64) & x'FFFFFFFFFFE00000')::INT8
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;



    CREATE OR REPLACE FUNCTION xyt_update_encode_xy(INT8, INT8, INT8) RETURNS INT8 AS $$
    SELECT   xyt_clear_xy($1)
           | xyt_encode_x($2)
           | xyt_encode_y($3);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_update_encode_t(INT8, INT8) RETURNS INT8 AS $$
    SELECT    xyt_clear_t($1)
           | xyt_encode_t($2);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

    CREATE OR REPLACE FUNCTION xyt_update_convert_thh_to_tdd(INT8) RETURNS INT8 AS $$
    SELECT xyt_update_encode_t($1, xyt_decode_t($1) / 24);
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;

COMMIT TRANSACTION;



BEGIN TRANSACTION;
    -- misc unit-related things that should probably be in tables

    CREATE OR REPLACE FUNCTION get_ui_display_unit_parts(measurement_unit) RETURNS JSON AS $$
    SELECT (CASE
                WHEN $1 = 'opc_pm01_0' THEN '{ "mfr":"Alphasense", "model":"OPC-N2",  "ch":"PM 1.0",  "si":"μg/m³" }'
                WHEN $1 = 'opc_pm02_5' THEN '{ "mfr":"Alphasense", "model":"OPC-N2",  "ch":"PM 2.5",  "si":"μg/m³" }'
                WHEN $1 = 'opc_pm10_0' THEN '{ "mfr":"Alphasense", "model":"OPC-N2",  "ch":"PM 10.0", "si":"μg/m³" }'
                WHEN $1 = 'pms_pm01_0' THEN '{ "mfr":"Plantower",  "model":"PMS5003", "ch":"PM 1.0",  "si":"μg/m³" }'
                WHEN $1 = 'pms_pm02_5' THEN '{ "mfr":"Plantower",  "model":"PMS5003", "ch":"PM 2.5",  "si":"μg/m³" }'
                WHEN $1 = 'pms_pm10_0' THEN '{ "mfr":"Plantower",  "model":"PMS5003", "ch":"PM 10.0", "si":"μg/m³" }'
                WHEN $1 = 'lnd_712'    THEN '{ "mfr":"LND",        "model":"712",     "ch":null,      "si":"μSv/h" }'
                WHEN $1 = 'lnd_712u'   THEN '{ "mfr":"LND",        "model":"712",     "ch":null,      "si":"μSv/h" }'
                WHEN $1 = 'lnd_712c'   THEN '{ "mfr":"LND",        "model":"712",     "ch":"(γ)",     "si":"μSv/h" }'
                WHEN $1 = 'lnd_7318'   THEN '{ "mfr":"LND",        "model":"7318",    "ch":null,      "si":"μSv/h" }'
                WHEN $1 = 'lnd_7318u'  THEN '{ "mfr":"LND",        "model":"7318",    "ch":null,      "si":"μSv/h" }'
                WHEN $1 = 'lnd_7318c'  THEN '{ "mfr":"LND",        "model":"7318",    "ch":"(γ)",     "si":"μSv/h" }'
                WHEN $1 = 'lnd_7128'   THEN '{ "mfr":"LND",        "model":"7128",    "ch":null,      "si":"μSv/h" }'
                WHEN $1 = 'lnd_7128ec' THEN '{ "mfr":"LND",        "model":"7128",    "ch":null,      "si":"μSv/h" }'
                WHEN $1 = 'lnd_78017'  THEN '{ "mfr":"LND",        "model":"78017",   "ch":null,      "si":"μSv/h" }'
                WHEN $1 = 'lnd_78017u' THEN '{ "mfr":"LND",        "model":"78017",   "ch":null,      "si":"μSv/h" }'
                WHEN $1 = 'lnd_78017c' THEN '{ "mfr":"LND",        "model":"78017",   "ch":"(γ)",     "si":"μSv/h" }'
                WHEN $1 = 'lnd_78017w' THEN '{ "mfr":"LND",        "model":"78017",   "ch":"(γ)",     "si":"μSv/h" }'
                WHEN $1 = 'env_temp'   THEN '{ "mfr":null,         "model":null,      "ch":null,      "si":"°C"    }'
                WHEN $1 = 'env_humid'  THEN '{ "mfr":null,         "model":null,      "ch":null,      "si":"RH%"   }'
                WHEN $1 = 'env_press'  THEN '{ "mfr":null,         "model":null,      "ch":null,      "si":"hPa"   }'
                                       ELSE '{ "mfr":null,         "model":null,      "ch":null,      "si":null    }'
           END)::json::jsonb::json;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;



    CREATE OR REPLACE FUNCTION get_ui_display_category(measurement_unit) RETURNS INT AS $$
    SELECT CASE
                WHEN $1 IN ('lnd_7318u',  'opc_pm01_0', 'opc_pm02_5', 'opc_pm10_0')              THEN 1
                WHEN $1 IN ('pms_pm01_0', 'pms_pm02_5', 'pms_pm10_0')                            THEN 2
                WHEN $1 IN ('lnd_7318c',  'lnd_7128ec', 'env_temp',   'env_humid',  'env_press') THEN 3
                                                                                                 ELSE 3
           END;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;



    CREATE OR REPLACE FUNCTION is_accepted_unit(TEXT) RETURNS BOOLEAN AS $$
    SELECT $1 IN ('lnd_7318',   'lnd_7318u',  'lnd_7318c',
                  'lnd_7128',   'lnd_7128ec', 
                  'lnd_712',    'lnd_712u',   'lnd_712c', 
                  'lnd_78017',  'lnd_78017u', 'lnd_78017c', 'lnd_78017w',
                  'opc_pm01_0', 'opc_pm02_5', 'opc_pm10_0',
                  'pms_pm01_0', 'pms_pm02_5', 'pms_pm10_0',
        	      'env_temp',   'env_humid',  'env_press');
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;



    CREATE OR REPLACE FUNCTION is_value_in_range_for_unit(FLOAT, measurement_unit) RETURNS BOOLEAN AS $$
    SELECT CASE
                WHEN ($2 IN ('lnd_7318',  'lnd_7318u',  'lnd_7318c',  
                             'lnd_7128',  'lnd_7128ec', 
                             'lnd_712',   'lnd_712u',   'lnd_712c', 
                             'lnd_78017', 'lnd_78017u', 'lnd_78017c', 'lnd_78017w',
                             'env_press')
                      AND ($1 <= 0.0 OR $1 > (1<<30)))
                    THEN FALSE
                WHEN ($2 IN ('opc_pm01_0', 'opc_pm02_5', 'opc_pm10_0',
                             'pms_pm01_0', 'pms_pm02_5', 'pms_pm10_0',
                             'env_humid')
                      AND ($1 <  0.0 OR $1 > (1<<30)))
                    THEN FALSE
                ELSE TRUE
           END;
    $$ LANGUAGE 'sql' STRICT IMMUTABLE;
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

    -- secondary table for device-specific stats
    CREATE TABLE IF NOT EXISTS dstats(       id SERIAL PRIMARY KEY,
                                      device_id INT8 NOT NULL,
                                           unit measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                            min FLOAT,
                                            max FLOAT,
                                            val FLOAT,
                                              n INT NOT NULL,
                                         min_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
                                         max_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL);

    -- secondary table for device-specific stats (non-numeric metadata)
    CREATE TABLE IF NOT EXISTS dstatsmeta(       id SERIAL PRIMARY KEY,
                                          device_id INT8 NOT NULL,
                                               unit measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                                val TEXT,
                                                 ts TIMESTAMP WITHOUT TIME ZONE NOT NULL);
COMMIT TRANSACTION;



-- index defs
BEGIN TRANSACTION;
    CREATE INDEX IF NOT EXISTS idx_m2_original_id ON m2(original_id);
    CREATE INDEX IF NOT EXISTS idx_m2_xyt_unit ON m2(xyt, unit);
    CREATE INDEX IF NOT EXISTS idx_m3hh_xyt_u ON m3hh(xyt, u);
    CREATE INDEX IF NOT EXISTS idx_m3dd_xyt_u ON m3dd(xyt, u);
    CREATE INDEX IF NOT EXISTS idx_dstats_device_id_unit ON dstats(device_id, unit);
    CREATE INDEX IF NOT EXISTS idx_dstatsmeta_device_id_unit ON dstatsmeta(device_id, unit);
    CREATE INDEX IF NOT EXISTS idx_measurements_created_at ON measurements(created_at);
    CREATE INDEX IF NOT EXISTS idx_measurements_device_id ON measurements(device_id);
COMMIT TRANSACTION;



