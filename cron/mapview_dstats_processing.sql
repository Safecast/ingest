-- 2017-04-05 ND: Initial file creation


CREATE TEMPORARY TABLE IF NOT EXISTS c1(mid INT);
TRUNCATE TABLE c1;

CREATE INDEX IF NOT EXISTS idx_c1_mid ON c1(mid);


INSERT INTO c1(mid)
SELECT id FROM measurements
WHERE created_at > COALESCE((SELECT MAX(max_ts) FROM dstats), TIMESTAMP '1970-01-01 00:00:00');




CREATE TABLE IF NOT EXISTS temp_ds(temp_device_id INT8 NOT NULL,
                                        temp_unit measurement_unit DEFAULT 'none'::measurement_unit NOT NULL,
                                         temp_min FLOAT,
                                         temp_max FLOAT,
                                         temp_val FLOAT,
                                           temp_n INT NOT NULL,
                                      temp_min_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
                                      temp_max_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
                                            is_up BOOLEAN);

CREATE INDEX IF NOT EXISTS idx_temp_ds_temp_device_id_temp_unit ON temp_ds(temp_device_id, temp_unit);

INSERT INTO temp_ds(temp_device_id, temp_unit, temp_min, temp_max, temp_n, temp_min_ts, temp_max_ts, is_up)
SELECT  device_id 
	   ,key::measurement_unit
       ,MIN(value::FLOAT)
       ,MAX(value::FLOAT)
       ,COUNT(*)
       ,MIN(created_at)
       ,MAX(created_at)
       ,FALSE
FROM (SELECT  device_id 
             ,created_at
             ,(jsonb_each_text(payload)).*
      FROM measurements
      WHERE id IN (SELECT mid FROM c1)
     ) AS q
WHERE key IN ('bat_charge', 'bat_current', 'bat_voltage',
              'dev_humid', 'dev_press', 'dev_temp',
              'env_humid', 'env_press', 'env_temp',
              'lnd_7128ec', 'lnd_7318c', 'lnd_7318u',
              'loc_lat', 'loc_lon',
              'opc_pm01_0', 'opc_pm02_5', 'opc_pm10_0',
              'pms_pm01_0', 'pms_pm02_5', 'pms_pm10_0')
    AND (CASE WHEN is_float(value) THEN is_value_in_range_for_unit(value::FLOAT, key::measurement_unit) ELSE FALSE END)
GROUP BY device_id, key::measurement_unit;


UPDATE temp_ds
SET temp_val = (SELECT value::FLOAT
FROM (SELECT  device_id
             ,created_at
             ,(jsonb_each_text(payload)).*
      FROM measurements
      WHERE id IN (SELECT mid FROM c1)
        AND device_id = temp_device_id
        AND created_at = temp_max_ts
     ) AS q
WHERE temp_unit::TEXT = key
  AND key IN ('bat_charge', 'bat_current', 'bat_voltage',
              'dev_humid', 'dev_press', 'dev_temp',
              'env_humid', 'env_press', 'env_temp',
              'lnd_7128ec', 'lnd_7318c', 'lnd_7318u',
              'loc_lat', 'loc_lon',
              'opc_pm01_0', 'opc_pm02_5', 'opc_pm10_0',
              'pms_pm01_0', 'pms_pm02_5', 'pms_pm10_0')
    AND (CASE WHEN is_float(value) THEN is_value_in_range_for_unit(value::FLOAT, key::measurement_unit) ELSE FALSE END) 
LIMIT 1);




UPDATE temp_ds
SET is_up = TRUE
WHERE (SELECT id FROM dstats WHERE temp_device_id = device_id AND temp_unit = unit LIMIT 1) IS NOT NULL;


UPDATE dstats
SET  min = scalar_min(min, (SELECT temp_min FROM temp_ds WHERE device_id = temp_device_id AND unit = temp_unit LIMIT 1))
    ,max = scalar_max(max, (SELECT temp_max FROM temp_ds WHERE device_id = temp_device_id AND unit = temp_unit LIMIT 1))
    ,val = (SELECT temp_val FROM temp_ds WHERE device_id = temp_device_id AND unit = temp_unit LIMIT 1)
    ,n   = n + COALESCE((SELECT temp_n FROM temp_ds WHERE device_id = temp_device_id AND unit = temp_unit LIMIT 1), 0)
    ,min_ts = scalar_min(min_ts, (SELECT temp_min_ts FROM temp_ds WHERE device_id = temp_device_id AND unit = temp_unit LIMIT 1))
    ,max_ts = scalar_max(max_ts, (SELECT temp_max_ts FROM temp_ds WHERE device_id = temp_device_id AND unit = temp_unit LIMIT 1))
WHERE (SELECT COUNT(*) FROM temp_ds WHERE device_id = temp_device_id AND unit = temp_unit AND is_up = TRUE) > 0;


INSERT INTO dstats(device_id, unit, min, max, val, n, min_ts, max_ts)
SELECT temp_device_id, temp_unit, temp_min, temp_max, temp_val, temp_n, temp_min_ts, temp_max_ts
FROM temp_ds
WHERE is_up = FALSE;

DROP TABLE temp_ds;
DROP TABLE c1;

