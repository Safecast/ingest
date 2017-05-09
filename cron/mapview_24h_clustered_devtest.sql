-- 2017-05-09 ND: Created

-- This export script is a variant of `mapview_24h_clustered.sql`
-- It should be executed after `mapview_24h_clustered.sql` only,
-- as it relies on the function that is created/updated by
-- `mapview_24h_clustered.sql` to run.  It simply supplies a
-- different parameter for alternate dev/test output.

-- The difference between the output of this script and 
-- `mapview_24h_clustered.sql` is that this script's output will
-- include all data, whereas `mapview_24h_clustered.sql` excludes
-- anything with the flags `loc_motion` or `dev_test` set.

-- Thus, the output of this script allows for visualizing hardware
-- running in dev/test modes that would normally not be visible.

\COPY (SELECT mapview_24h_clustered(TRUE, FALSE)) TO stdout
