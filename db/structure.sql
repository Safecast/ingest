SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        NEW.updated_at = now();
        RETURN NEW;
      END;
      $$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.devices (
    numeric_id bigint NOT NULL,
    location public.geography(Point,4326),
    location_name character varying,
    payload jsonb NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL
);


--
-- Name: devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.devices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.devices_id_seq OWNED BY public.devices.numeric_id;


--
-- Name: measurements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.measurements (
    id integer NOT NULL,
    device_id bigint NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    device_urn character varying
);


--
-- Name: mappable_measurements; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.mappable_measurements AS
 SELECT measurements.id,
    measurements.created_at,
    measurements.updated_at,
    measurements.device_id,
    timezone('UTC'::text, ((measurements.payload ->> 'captured_at'::text))::timestamp with time zone) AS captured_at,
    point((((measurements.payload ->> 'latitude'::text))::numeric)::double precision, (((measurements.payload ->> 'longitude'::text))::numeric)::double precision) AS location,
    measurements.payload
   FROM public.measurements
  WHERE (((measurements.payload ->> 'latitude'::text) IS NOT NULL) AND ((measurements.payload ->> 'longitude'::text) IS NOT NULL) AND ((measurements.payload ->> 'captured_at'::text) IS NOT NULL));


--
-- Name: measurements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.measurements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: measurements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.measurements_id_seq OWNED BY public.measurements.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: measurements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.measurements ALTER COLUMN id SET DEFAULT nextval('public.measurements_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- Name: measurements measurements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.measurements
    ADD CONSTRAINT measurements_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: measurements update_measurements_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_measurements_updated_at BEFORE UPDATE ON public.measurements FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();


--
-- PostgreSQL database dump complete
--

SET search_path TO public,postgis;

INSERT INTO "schema_migrations" (version) VALUES
('20170112162706'),
('20170123010933'),
('20170126020054'),
('20170126024027'),
('20170130081839'),
('20170201124248'),
('20170202014348'),
('20170210143343'),
('20170210151154'),
('20170212033722'),
('20170314184402'),
('20170328122726'),
('20180425004530');


