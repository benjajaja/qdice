--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.6
-- Dumped by pg_dump version 9.6.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: network; Type: TYPE; Schema: public; Owner: bgrosse
--

CREATE TYPE network AS ENUM (
    'password',
    'google'
);


ALTER TYPE network OWNER TO bgrosse;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: authorizations; Type: TABLE; Schema: public; Owner: bgrosse
--

CREATE TABLE authorizations (
    user_id integer NOT NULL,
    profile jsonb,
    network network NOT NULL,
    network_id character varying(100)
);


ALTER TABLE authorizations OWNER TO bgrosse;

--
-- Name: users; Type: TABLE; Schema: public; Owner: bgrosse
--

CREATE TABLE users (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(100),
    picture character varying(500),
    points bigint DEFAULT 0,
    level integer DEFAULT 0
);


ALTER TABLE users OWNER TO bgrosse;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: bgrosse
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_id_seq OWNER TO bgrosse;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bgrosse
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: bgrosse
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: authorizations authorizations_pk; Type: CONSTRAINT; Schema: public; Owner: bgrosse
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT authorizations_pk PRIMARY KEY (user_id, network);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: bgrosse
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: authorizations autorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: bgrosse
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT autorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- PostgreSQL database dump complete
--

