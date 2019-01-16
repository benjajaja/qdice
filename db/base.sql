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
    'telegram'
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
    network_id character varying(100) NOT NULL
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
    game_start timestamptz,
    turn_start timestamptz,
    turn_index integer,
    turn_activity boolean,
    lands json,
    turn_count integer,
    round_count integer,
    watching json
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
    registration_time timestamp with time zone NOT NULL
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
-- Data for Name: authorizations; Type: TABLE DATA; Schema: public; Owner: bgrosse
--

COPY authorizations (user_id, profile, network, network_id) FROM stdin;
29	{"chat_id": 208216602, "user_id": 208216602, "chat_type": "private", "message_id": 21}	telegram	208216602
30	{"id": "100948697675205720281", "link": "https://plus.google.com/100948697675205720281", "name": "Benjamin Grosse", "email": "ste3ls@gmail.com", "gender": "male", "locale": "es", "picture": "https://lh5.googleusercontent.com/-NImrHewvp6s/AAAAAAAAAAI/AAAAAAAAAxU/cGC29MaHdqE/photo.jpg", "given_name": "Benjamin", "family_name": "Grosse", "verified_email": true}	google	100948697675205720281
31	{"hd": "qustodio.com", "id": "108152863150366309599", "name": "Benjamin Grosse", "email": "benjamin.grosse@qustodio.com", "locale": "en", "picture": "https://lh3.googleusercontent.com/-Z6fJAvpeIJ4/AAAAAAAAAAI/AAAAAAAAAAo/lhe79FvnutM/photo.jpg", "given_name": "Benjamin", "family_name": "Grosse", "verified_email": true}	google	108152863150366309599
60	{}	password	bot_1
\.


--
-- Data for Name: tables; Type: TABLE DATA; Schema: public; Owner: bgrosse
--

COPY tables (tag, name, map_name, stack_size, player_slots, start_slots, points) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: bgrosse
--

COPY users (id, name, email, picture, points, level, registration_time) FROM stdin;
43	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:51:07.87467+01
44	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:55:28.547214+01
45	Pepe the bot	\N	assets/empty_profile_picture.svg	50	0	2018-01-24 20:56:02.22318+01
46	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:57:05.587285+01
47	Pepe the bot	\N	assets/empty_profile_picture.svg	50	0	2018-01-24 20:57:39.158573+01
48	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:02:19.947841+01
32	PEEP	\N	\N	220	0	2018-01-02 02:15:56.24154+01
49	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:02:51.591464+01
50	Pepe the bot	\N	assets/empty_profile_picture.svg	50	0	2018-01-24 21:03:12.814651+01
33	PEPE	\N	\N	100	0	2018-01-04 15:07:35.945205+01
28	Benja	\N	/pictures//user_7q4BcOd3wxKuZW0w.jpg	0	0	2018-01-01 16:59:28.320618+01
29	Benja	\N	/pictures//user_utWv9OaVCDcRPGrL.jpg	0	0	2018-01-01 17:03:28.000381+01
51	Pepe the bot	\N	assets/empty_profile_picture.svg	50	0	2018-01-24 21:03:51.293431+01
52	Pepe the bot	\N	assets/empty_profile_picture.svg	50	0	2018-01-24 21:04:38.705972+01
53	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:05:33.568003+01
54	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:05:57.880942+01
55	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:06:37.581143+01
31	Benjamin Grosse	benjamin.grosse@qustodio.com	https://lh3.googleusercontent.com/-Z6fJAvpeIJ4/AAAAAAAAAAI/AAAAAAAAAAo/lhe79FvnutM/photo.jpg	2215	0	2018-01-01 19:07:20.674933+01
63	bbb	\N	\N	230	0	2019-01-05 15:14:19.757067+01
56	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:07:52.157524+01
57	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:09:41.525838+01
34	Dude	\N	\N	50	0	2018-01-24 20:01:26.751023+01
65	xxx	\N	\N	50	0	2019-01-12 18:34:18.431858+01
58	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:09:47.637198+01
59	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 21:13:13.939664+01
35	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:49:03.166431+01
36	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:49:03.188868+01
37	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:49:03.199221+01
38	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:49:03.219943+01
39	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:49:03.286876+01
40	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:49:03.304181+01
41	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:49:03.334091+01
42	Pepe the bot	\N	assets/empty_profile_picture.svg	0	0	2018-01-24 20:50:03.774571+01
66	xxx	\N	\N	0	0	2019-01-14 11:45:25.267537+01
67	xxx	\N	\N	0	0	2019-01-14 18:13:23.401962+01
60	Pepe the bot	\N	assets/empty_profile_picture.svg	240	0	2018-01-24 21:14:12.317574+01
30	Benja	ste3ls@gmail.com	https://lh5.googleusercontent.com/-NImrHewvp6s/AAAAAAAAAAI/AAAAAAAAAxU/cGC29MaHdqE/photo.jpg	1120	0	2018-01-01 17:15:46.995253+01
61	aaa	\N	\N	0	0	2019-01-05 13:39:43.235336+01
62	aaa	\N	\N	75	0	2019-01-05 13:42:31.500494+01
64	aaa	\N	\N	0	0	2019-01-12 18:31:32.223373+01
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bgrosse
--

SELECT pg_catalog.setval('users_id_seq', 67, true);


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

