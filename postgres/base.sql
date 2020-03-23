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
    'google',
    'password',
    'telegram',
    'reddit'
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
    network_id character varying(128) NOT NULL
);


ALTER TABLE authorizations OWNER TO bgrosse;

--
-- Name: tables; Type: TABLE; Schema: public; Owner: bgrosse
--

CREATE TABLE tables (
    tag character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    map_name character varying(100) NOT NULL,
    stack_size integer NOT NULL,
    player_slots integer NOT NULL,
    start_slots integer NOT NULL,
    points integer NOT NULL,
    players json,
    player_start_count integer NOT NULL,
    status character varying(20),
    game_start timestamp with time zone,
    turn_start timestamp with time zone,
    turn_index integer,
    turn_activity boolean,
    lands json,
    turn_count integer,
    round_count integer,
    watching json,
    attack json,
    params json,
    retired json,
    current_game integer
);


ALTER TABLE tables OWNER TO bgrosse;

--
-- Name: users; Type: TABLE; Schema: public; Owner: bgrosse
--

CREATE TABLE users (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(100),
    picture character varying(500),
    points bigint DEFAULT 0,
    level integer DEFAULT 0,
    level_points integer DEFAULT 0,
    registration_time timestamp with time zone NOT NULL,
    preferences json,
    voted jsonb DEFAULT '[]'::jsonb,
    awards jsonb DEFAULT '[]'::jsonb
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

ALTER TABLE ONLY users ADD CONSTRAINT users_uniq UNIQUE (email);

--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: bgrosse
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Data for Name: authorizations; Type: TABLE DATA; Schema: public; Owner: bgrosse
--

COPY authorizations (user_id, profile, network, network_id) FROM stdin;
\.


--
-- Data for Name: tables; Type: TABLE DATA; Schema: public; Owner: bgrosse
--

COPY tables (tag, name, map_name, stack_size, player_slots, start_slots, points, players, player_start_count, status, game_start, turn_start, turn_index, turn_activity, lands, turn_count, round_count, watching, attack) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: bgrosse
--

COPY users (id, name, email, picture, points, level, registration_time) FROM stdin;
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bgrosse
--

SELECT pg_catalog.setval('users_id_seq', 1, true);


--
-- Name: authorizations authorizations_pk; Type: CONSTRAINT; Schema: public; Owner: bgrosse
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT authorizations_pk PRIMARY KEY (network, network_id);


--
-- Name: authorizations authorizations_uniq; Type: CONSTRAINT; Schema: public; Owner: bgrosse
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT authorizations_uniq UNIQUE (user_id, network, network_id);


--
-- Name: tables tables_pkey; Type: CONSTRAINT; Schema: public; Owner: bgrosse
--

ALTER TABLE ONLY tables
    ADD CONSTRAINT tables_pkey PRIMARY KEY (tag);


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

CREATE TABLE push_subscriptions (
  user_id int NOT NULL,
  subscription jsonb NOT NULL,
  CONSTRAINT push_subscriptions_pk PRIMARY KEY (user_id,subscription),
  CONSTRAINT push_subscriptions_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

CREATE TABLE push_subscribed_events (
  user_id integer NOT NULL,
  "event" varchar NOT NULL,
  CONSTRAINT push_subscribed_events_pk PRIMARY KEY (user_id,"event"),
  CONSTRAINT push_subscribed_events_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);



CREATE TABLE games (
    id integer NOT NULL,
    tag character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    map_name character varying(100) NOT NULL,
    stack_size integer NOT NULL,
    player_slots integer NOT NULL,
    start_slots integer NOT NULL,
    points integer NOT NULL,
    game_start timestamp with time zone,
    params json,
    players json,
    lands json
);


ALTER TABLE games OWNER TO bgrosse;
CREATE SEQUENCE games_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE games_id_seq OWNER TO bgrosse;
ALTER SEQUENCE games_id_seq OWNED BY games.id;
ALTER TABLE ONLY games ALTER COLUMN id SET DEFAULT nextval('games_id_seq'::regclass);
ALTER TABLE ONLY games
    ADD CONSTRAINT games_pkey PRIMARY KEY (id);


CREATE TABLE game_events (
    id integer NOT NULL,
    game_id integer NOT NULL,
    command character varying(100) NOT NULL,
    params json,
    result json
);

ALTER TABLE game_events OWNER TO bgrosse;
CREATE SEQUENCE game_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE game_events_id_seq OWNER TO bgrosse;
ALTER SEQUENCE game_events_id_seq OWNED BY game_events.id;
ALTER TABLE ONLY game_events ALTER COLUMN id SET DEFAULT nextval('game_events_id_seq'::regclass);
ALTER TABLE ONLY game_events
    ADD CONSTRAINT game_events_game_fkey FOREIGN KEY (game_id) REFERENCES games(id);



