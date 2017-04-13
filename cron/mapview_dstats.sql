CREATE OR REPLACE FUNCTION mapview_dstats() RETURNS JSON AS $$
DECLARE
    json_out_txt JSON;
BEGIN
-- 2017-04-05 ND: Initial file creation

json_out_txt := (
SELECT array_to_json(array_agg(row_to_json(aa, FALSE)), FALSE)
FROM (
SELECT ds.device_id
    ,(SELECT val
      FROM dstatsmeta AS dsm
      WHERE dsm.device_id = ds.device_id
        AND dsm.unit = 'dev_label'
      LIMIT 1) AS dev_label
    ,(SELECT array_to_json(array_agg(row_to_json(bb, FALSE)), FALSE)
      FROM (SELECT ds2.unit
                ,(SELECT row_to_json(cc, FALSE)
                  FROM (SELECT min, max, val, n, convert_ts_to_isostring(min_ts) AS min_ts, convert_ts_to_isostring(max_ts) AS max_ts
                        FROM dstats AS ds3
                        WHERE ds3.unit = ds2.unit
                            AND ds3.device_id = ds.device_id) AS cc) AS stats
            FROM dstats AS ds2
            WHERE ds2.device_id = ds.device_id
            ORDER BY ds2.unit) AS bb) AS units
    FROM (SELECT DISTINCT device_id FROM dstats) AS ds
) AS aa);

RETURN json_out_txt;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;

\COPY (SELECT mapview_dstats()) TO stdout

