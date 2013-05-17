--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: annotation_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE annotation_versions (
    id integer NOT NULL,
    annotation_id integer,
    version integer,
    collage_id integer,
    annotation character varying(10240) DEFAULT NULL::character varying,
    annotation_start character varying(255) DEFAULT NULL::character varying,
    annotation_end character varying(255) DEFAULT NULL::character varying,
    word_count integer,
    annotated_content character varying(1048576) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    ancestry character varying(255) DEFAULT NULL::character varying,
    public boolean DEFAULT true,
    active boolean DEFAULT true,
    annotation_word_count integer,
    collage_version integer
);


--
-- Name: annotation_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE annotation_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: annotation_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE annotation_versions_id_seq OWNED BY annotation_versions.id;


--
-- Name: annotations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE annotations (
    id integer NOT NULL,
    collage_id integer,
    annotation character varying(10240),
    annotation_start character varying(255),
    annotation_end character varying(255),
    word_count integer,
    annotated_content character varying(1048576),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    ancestry character varying(255),
    public boolean DEFAULT true,
    active boolean DEFAULT true,
    annotation_word_count integer,
    collage_version integer,
    version integer
);


--
-- Name: annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE annotations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE annotations_id_seq OWNED BY annotations.id;


--
-- Name: brain_busters; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE brain_busters (
    id integer NOT NULL,
    question character varying(255),
    answer character varying(255)
);


--
-- Name: brain_busters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE brain_busters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: brain_busters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE brain_busters_id_seq OWNED BY brain_busters.id;


--
-- Name: case_citation_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_citation_versions (
    id integer NOT NULL,
    case_citation_id integer,
    version integer,
    case_id integer,
    volume character varying(200) DEFAULT NULL::character varying,
    reporter character varying(200) DEFAULT NULL::character varying,
    page character varying(200) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    case_version integer
);


--
-- Name: case_citation_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_citation_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_citation_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_citation_versions_id_seq OWNED BY case_citation_versions.id;


--
-- Name: case_citations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_citations (
    id integer NOT NULL,
    case_id integer,
    volume character varying(200) NOT NULL,
    reporter character varying(200) NOT NULL,
    page character varying(200) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    case_version integer,
    version integer
);


--
-- Name: case_citations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_citations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_citations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_citations_id_seq OWNED BY case_citations.id;


--
-- Name: case_docket_number_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_docket_number_versions (
    id integer NOT NULL,
    case_docket_number_id integer,
    version integer,
    case_id integer,
    docket_number character varying(200) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    case_version integer
);


--
-- Name: case_docket_number_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_docket_number_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_docket_number_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_docket_number_versions_id_seq OWNED BY case_docket_number_versions.id;


--
-- Name: case_docket_numbers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_docket_numbers (
    id integer NOT NULL,
    case_id integer,
    docket_number character varying(200) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    case_version integer,
    version integer
);


--
-- Name: case_docket_numbers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_docket_numbers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_docket_numbers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_docket_numbers_id_seq OWNED BY case_docket_numbers.id;


--
-- Name: case_jurisdiction_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_jurisdiction_versions (
    id integer NOT NULL,
    case_jurisdiction_id integer,
    version integer,
    abbreviation character varying(150) DEFAULT NULL::character varying,
    name character varying(500) DEFAULT NULL::character varying,
    content text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: case_jurisdiction_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_jurisdiction_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_jurisdiction_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_jurisdiction_versions_id_seq OWNED BY case_jurisdiction_versions.id;


--
-- Name: case_jurisdictions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_jurisdictions (
    id integer NOT NULL,
    abbreviation character varying(150),
    name character varying(500),
    content text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    version integer
);


--
-- Name: case_jurisdictions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_jurisdictions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_jurisdictions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_jurisdictions_id_seq OWNED BY case_jurisdictions.id;


--
-- Name: case_request_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_request_versions (
    id integer NOT NULL,
    case_request_id integer,
    version integer,
    full_name character varying(500) DEFAULT NULL::character varying,
    decision_date date,
    author character varying(150) DEFAULT NULL::character varying,
    case_jurisdiction_id integer,
    docket_number character varying(150) DEFAULT NULL::character varying,
    volume character varying(150) DEFAULT NULL::character varying,
    reporter character varying(150) DEFAULT NULL::character varying,
    page character varying(150) DEFAULT NULL::character varying,
    bluebook_citation character varying(150) DEFAULT NULL::character varying,
    status character varying(150) DEFAULT 'new'::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    case_jurisdiction_version integer
);


--
-- Name: case_request_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_request_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_request_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_request_versions_id_seq OWNED BY case_request_versions.id;


--
-- Name: case_requests; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_requests (
    id integer NOT NULL,
    full_name character varying(500) NOT NULL,
    decision_date date NOT NULL,
    author character varying(150) NOT NULL,
    case_jurisdiction_id integer,
    docket_number character varying(150) NOT NULL,
    volume character varying(150) NOT NULL,
    reporter character varying(150) NOT NULL,
    page character varying(150) NOT NULL,
    bluebook_citation character varying(150) NOT NULL,
    status character varying(150) DEFAULT 'new'::character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    case_jurisdiction_version integer,
    version integer
);


--
-- Name: case_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_requests_id_seq OWNED BY case_requests.id;


--
-- Name: case_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE case_versions (
    id integer NOT NULL,
    case_id integer,
    version integer,
    current_opinion boolean DEFAULT true,
    short_name character varying(150) DEFAULT NULL::character varying,
    full_name character varying(500) DEFAULT NULL::character varying,
    decision_date date,
    author character varying(150) DEFAULT NULL::character varying,
    case_jurisdiction_id integer,
    party_header character varying(10240) DEFAULT NULL::character varying,
    lawyer_header character varying(2048) DEFAULT NULL::character varying,
    header_html character varying(15360) DEFAULT NULL::character varying,
    content character varying(5242880) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true,
    active boolean DEFAULT false,
    case_request_id integer,
    case_jurisdiction_version integer,
    case_request_version integer
);


--
-- Name: case_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE case_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE case_versions_id_seq OWNED BY case_versions.id;


--
-- Name: cases; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cases (
    id integer NOT NULL,
    current_opinion boolean DEFAULT true,
    short_name character varying(150) NOT NULL,
    full_name character varying(500),
    decision_date date,
    author character varying(150),
    case_jurisdiction_id integer,
    party_header character varying(10240),
    lawyer_header character varying(2048),
    header_html character varying(15360),
    content character varying(5242880) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true,
    active boolean DEFAULT false,
    case_request_id integer,
    case_jurisdiction_version integer,
    case_request_version integer,
    version integer
);


--
-- Name: cases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cases_id_seq OWNED BY cases.id;


--
-- Name: collage_link_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE collage_link_versions (
    id integer NOT NULL,
    collage_link_id integer,
    version integer,
    host_collage_id integer,
    linked_collage_id integer,
    link_text_start character varying(255) DEFAULT NULL::character varying,
    link_text_end character varying(255) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    host_collage_version integer,
    linked_collage_version integer
);


--
-- Name: collage_link_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE collage_link_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collage_link_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE collage_link_versions_id_seq OWNED BY collage_link_versions.id;


--
-- Name: collage_links; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE collage_links (
    id integer NOT NULL,
    host_collage_id integer NOT NULL,
    linked_collage_id integer NOT NULL,
    link_text_start character varying(255) NOT NULL,
    link_text_end character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    host_collage_version integer,
    linked_collage_version integer,
    version integer
);


--
-- Name: collage_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE collage_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collage_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE collage_links_id_seq OWNED BY collage_links.id;


--
-- Name: collage_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE collage_versions (
    id integer NOT NULL,
    collage_id integer,
    version integer,
    annotatable_type character varying(255) DEFAULT NULL::character varying,
    annotatable_id integer,
    name character varying(250) DEFAULT NULL::character varying,
    description character varying(5120) DEFAULT NULL::character varying,
    content character varying(5242880) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    word_count integer,
    indexable_content character varying(5242880) DEFAULT NULL::character varying,
    ancestry character varying(255) DEFAULT NULL::character varying,
    public boolean DEFAULT true,
    active boolean DEFAULT true,
    readable_state character varying(5242880) DEFAULT NULL::character varying,
    words_shown integer,
    annotatable_version integer
);


--
-- Name: collage_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE collage_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collage_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE collage_versions_id_seq OWNED BY collage_versions.id;


--
-- Name: collages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE collages (
    id integer NOT NULL,
    annotatable_type character varying(255),
    annotatable_id integer,
    name character varying(250) NOT NULL,
    description character varying(5120),
    content character varying(5242880) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    word_count integer,
    indexable_content character varying(5242880),
    ancestry character varying(255),
    public boolean DEFAULT true,
    active boolean DEFAULT true,
    readable_state character varying(5242880),
    words_shown integer,
    annotatable_version integer,
    version integer
);


--
-- Name: collages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE collages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE collages_id_seq OWNED BY collages.id;


--
-- Name: collages_user_collections; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE collages_user_collections (
    collage_id integer,
    user_collection_id integer,
    collage_version integer,
    user_collection_version integer
);


--
-- Name: collages_user_collections_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE collages_user_collections_versions (
    collage_id integer,
    user_collection_id integer,
    collage_version integer,
    user_collection_version integer
);


--
-- Name: color_mapping_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE color_mapping_versions (
    id integer NOT NULL,
    color_mapping_id integer,
    version integer,
    collage_id integer,
    tag_id integer,
    hex character varying(255) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    tag_version integer,
    colllage_version integer
);


--
-- Name: color_mapping_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE color_mapping_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: color_mapping_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE color_mapping_versions_id_seq OWNED BY color_mapping_versions.id;


--
-- Name: color_mappings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE color_mappings (
    id integer NOT NULL,
    collage_id integer,
    tag_id integer,
    hex character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    tag_version integer,
    colllage_version integer,
    version integer
);


--
-- Name: color_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE color_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: color_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE color_mappings_id_seq OWNED BY color_mappings.id;


--
-- Name: defect_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE defect_versions (
    id integer NOT NULL,
    defect_id integer,
    version integer,
    description text,
    reportable_id integer,
    reportable_type character varying(255) DEFAULT NULL::character varying,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    reportable_version integer,
    reporter_version integer
);


--
-- Name: defect_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE defect_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: defect_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE defect_versions_id_seq OWNED BY defect_versions.id;


--
-- Name: defects; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE defects (
    id integer NOT NULL,
    description text NOT NULL,
    reportable_id integer NOT NULL,
    reportable_type character varying(255) NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    reportable_version integer,
    reporter_version integer,
    version integer
);


--
-- Name: defects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE defects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: defects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE defects_id_seq OWNED BY defects.id;


--
-- Name: influences; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE influences (
    id integer NOT NULL,
    resource_id integer,
    resource_type character varying(255),
    parent_id integer,
    children_count integer,
    ancestors_count integer,
    descendants_count integer,
    hidden boolean,
    "position" integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: influences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE influences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: influences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE influences_id_seq OWNED BY influences.id;


--
-- Name: item_annotations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_annotations (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_annotations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_annotations_id_seq OWNED BY item_annotations.id;


--
-- Name: item_cases; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_cases (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_cases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_cases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_cases_id_seq OWNED BY item_cases.id;


--
-- Name: item_collages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_collages (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_collages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_collages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_collages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_collages_id_seq OWNED BY item_collages.id;


--
-- Name: item_defaults; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_defaults (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true
);


--
-- Name: item_defaults_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_defaults_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_defaults_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_defaults_id_seq OWNED BY item_defaults.id;


--
-- Name: item_images; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_images (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_images_id_seq OWNED BY item_images.id;


--
-- Name: item_medias; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_medias (
    id integer NOT NULL,
    title character varying(255),
    name character varying(255),
    url character varying(1024),
    description text,
    actual_object_type character varying(255),
    actual_object_id integer,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: item_medias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_medias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_medias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_medias_id_seq OWNED BY item_medias.id;


--
-- Name: item_playlists; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_playlists (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_playlists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_playlists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_playlists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_playlists_id_seq OWNED BY item_playlists.id;


--
-- Name: item_question_instances; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_question_instances (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_question_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_question_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_question_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_question_instances_id_seq OWNED BY item_question_instances.id;


--
-- Name: item_questions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_questions (
    id integer NOT NULL,
    title character varying(255),
    name character varying(255),
    url character varying(255),
    description text,
    active boolean,
    public boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_questions_id_seq OWNED BY item_questions.id;


--
-- Name: item_rotisserie_discussions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_rotisserie_discussions (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_rotisserie_discussions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_rotisserie_discussions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_rotisserie_discussions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_rotisserie_discussions_id_seq OWNED BY item_rotisserie_discussions.id;


--
-- Name: item_text_blocks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_text_blocks (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    actual_object_type character varying(255),
    actual_object_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: item_text_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_text_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_text_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_text_blocks_id_seq OWNED BY item_text_blocks.id;


--
-- Name: item_texts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_texts (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true,
    actual_object_type character varying(255),
    actual_object_id integer
);


--
-- Name: item_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_texts_id_seq OWNED BY item_texts.id;


--
-- Name: item_youtubes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE item_youtubes (
    id integer NOT NULL,
    title character varying(255),
    name character varying(1024),
    url character varying(1024),
    description text,
    active boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true
);


--
-- Name: item_youtubes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE item_youtubes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_youtubes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE item_youtubes_id_seq OWNED BY item_youtubes.id;


--
-- Name: journal_article_types; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE journal_article_types (
    id integer NOT NULL,
    name character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: journal_article_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE journal_article_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journal_article_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE journal_article_types_id_seq OWNED BY journal_article_types.id;


--
-- Name: journal_article_types_journal_articles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE journal_article_types_journal_articles (
    journal_article_id integer,
    journal_article_type_id integer
);


--
-- Name: journal_articles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE journal_articles (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(5242880) NOT NULL,
    publish_date date NOT NULL,
    subtitle character varying(255),
    author character varying(255) NOT NULL,
    author_description character varying(5242880),
    volume character varying(255) NOT NULL,
    issue character varying(255) NOT NULL,
    page character varying(255) NOT NULL,
    bluebook_citation character varying(255) NOT NULL,
    article_series_title character varying(255),
    article_series_description character varying(5242880),
    pdf_url character varying(255),
    image character varying(255),
    attribution character varying(255) NOT NULL,
    attribution_url character varying(255),
    video_embed character varying(5242880),
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: journal_articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE journal_articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journal_articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE journal_articles_id_seq OWNED BY journal_articles.id;


--
-- Name: media_types; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE media_types (
    id integer NOT NULL,
    label character varying(255),
    slug character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: media_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE media_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE media_types_id_seq OWNED BY media_types.id;


--
-- Name: medias; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medias (
    id integer NOT NULL,
    name character varying(255),
    content text,
    media_type_id integer,
    public boolean DEFAULT true,
    active boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description character varying(5242880)
);


--
-- Name: medias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE medias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: medias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE medias_id_seq OWNED BY medias.id;


--
-- Name: metadata; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE metadata (
    id integer NOT NULL,
    contributor character varying(255),
    coverage character varying(255),
    creator character varying(255),
    date date,
    description character varying(5242880),
    format character varying(255),
    identifier character varying(255),
    language character varying(255) DEFAULT 'en'::character varying,
    publisher character varying(255),
    relation character varying(255),
    rights character varying(255),
    source character varying(255),
    subject character varying(255),
    title character varying(255),
    dc_type character varying(255) DEFAULT 'Text'::character varying,
    classifiable_type character varying(255),
    classifiable_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    classifiable_version integer,
    version integer
);


--
-- Name: metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE metadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE metadata_id_seq OWNED BY metadata.id;


--
-- Name: metadatum_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE metadatum_versions (
    id integer NOT NULL,
    metadatum_id integer,
    version integer,
    contributor character varying(255) DEFAULT NULL::character varying,
    coverage character varying(255) DEFAULT NULL::character varying,
    creator character varying(255) DEFAULT NULL::character varying,
    date date,
    description character varying(5242880) DEFAULT NULL::character varying,
    format character varying(255) DEFAULT NULL::character varying,
    identifier character varying(255) DEFAULT NULL::character varying,
    language character varying(255) DEFAULT 'en'::character varying,
    publisher character varying(255) DEFAULT NULL::character varying,
    relation character varying(255) DEFAULT NULL::character varying,
    rights character varying(255) DEFAULT NULL::character varying,
    source character varying(255) DEFAULT NULL::character varying,
    subject character varying(255) DEFAULT NULL::character varying,
    title character varying(255) DEFAULT NULL::character varying,
    dc_type character varying(255) DEFAULT 'Text'::character varying,
    classifiable_type character varying(255) DEFAULT NULL::character varying,
    classifiable_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    classifiable_version integer
);


--
-- Name: metadatum_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE metadatum_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metadatum_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE metadatum_versions_id_seq OWNED BY metadatum_versions.id;


--
-- Name: notification_invites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notification_invites (
    id integer NOT NULL,
    user_id integer,
    resource_id integer,
    resource_type character varying(255),
    email_address character varying(1024),
    tid character varying(1024),
    sent boolean DEFAULT false,
    accepted boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: notification_invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notification_invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notification_invites_id_seq OWNED BY notification_invites.id;


--
-- Name: notification_trackers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notification_trackers (
    id integer NOT NULL,
    rotisserie_discussion_id integer,
    rotisserie_post_id integer,
    user_id integer,
    notify_description character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: notification_trackers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notification_trackers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_trackers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notification_trackers_id_seq OWNED BY notification_trackers.id;


--
-- Name: permission_assignments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE permission_assignments (
    id integer NOT NULL,
    user_collection_id integer,
    user_id integer,
    permission_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: permission_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE permission_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permission_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE permission_assignments_id_seq OWNED BY permission_assignments.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE permissions (
    id integer NOT NULL,
    key character varying(255),
    label character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    permission_type character varying(255)
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE permissions_id_seq OWNED BY permissions.id;


--
-- Name: playlist_items; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE playlist_items (
    id integer NOT NULL,
    playlist_id integer,
    resource_item_id integer,
    resource_item_type character varying(255),
    active boolean DEFAULT true,
    "position" integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    ancestry character varying(255),
    playlist_item_parent_id integer,
    public boolean DEFAULT true,
    notes text,
    public_notes boolean DEFAULT true NOT NULL
);


--
-- Name: playlist_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE playlist_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: playlist_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE playlist_items_id_seq OWNED BY playlist_items.id;


--
-- Name: playlists; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE playlists (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    name character varying(1024),
    description text,
    active boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true,
    ancestry character varying(255),
    "position" integer,
    counter_start integer DEFAULT 1 NOT NULL
);


--
-- Name: playlists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE playlists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: playlists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE playlists_id_seq OWNED BY playlists.id;


--
-- Name: playlists_user_collections; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE playlists_user_collections (
    playlist_id integer,
    user_collection_id integer,
    user_collection_version integer
);


--
-- Name: playlists_user_collections_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE playlists_user_collections_versions (
    playlist_id integer,
    user_collection_id integer,
    user_collection_version integer
);


--
-- Name: question_instances; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE question_instances (
    id integer NOT NULL,
    name character varying(250) NOT NULL,
    user_id integer,
    project_id integer,
    password character varying(128),
    featured_question_count integer DEFAULT 2,
    description character varying(2000),
    parent_id integer,
    children_count integer,
    ancestors_count integer,
    descendants_count integer,
    "position" integer,
    hidden boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true,
    active boolean DEFAULT true
);


--
-- Name: question_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE question_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: question_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE question_instances_id_seq OWNED BY question_instances.id;


--
-- Name: questions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE questions (
    id integer NOT NULL,
    question_instance_id integer,
    user_id integer,
    question character varying(10000) NOT NULL,
    sticky boolean DEFAULT false,
    parent_id integer,
    children_count integer,
    ancestors_count integer,
    descendants_count integer,
    "position" integer,
    hidden boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true,
    active boolean DEFAULT true
);


--
-- Name: questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE questions_id_seq OWNED BY questions.id;


--
-- Name: role_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE role_versions (
    id integer NOT NULL,
    role_id integer,
    version integer,
    name character varying(40) DEFAULT NULL::character varying,
    authorizable_type character varying(40) DEFAULT NULL::character varying,
    authorizable_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    authorizable_version integer
);


--
-- Name: role_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE role_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: role_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE role_versions_id_seq OWNED BY role_versions.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE roles (
    id integer NOT NULL,
    name character varying(40),
    authorizable_type character varying(40),
    authorizable_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    authorizable_version integer,
    version integer
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE roles_id_seq OWNED BY roles.id;


--
-- Name: roles_users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE roles_users (
    user_id integer,
    role_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    user_version integer,
    role_version integer
);


--
-- Name: roles_users_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE roles_users_versions (
    user_id integer,
    role_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    user_version integer,
    role_version integer
);


--
-- Name: rotisserie_assignments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rotisserie_assignments (
    id integer NOT NULL,
    user_id integer,
    rotisserie_discussion_id integer,
    rotisserie_post_id integer,
    round integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: rotisserie_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rotisserie_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rotisserie_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rotisserie_assignments_id_seq OWNED BY rotisserie_assignments.id;


--
-- Name: rotisserie_discussions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rotisserie_discussions (
    id integer NOT NULL,
    rotisserie_instance_id integer,
    title character varying(250) NOT NULL,
    output text,
    description text,
    notes text,
    round_length integer DEFAULT 2,
    final_round integer DEFAULT 2,
    start_date timestamp without time zone,
    session_id character varying(255),
    active boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true
);


--
-- Name: rotisserie_discussions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rotisserie_discussions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rotisserie_discussions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rotisserie_discussions_id_seq OWNED BY rotisserie_discussions.id;


--
-- Name: rotisserie_instances; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rotisserie_instances (
    id integer NOT NULL,
    title character varying(250) NOT NULL,
    output text,
    description text,
    notes text,
    session_id character varying(255),
    active boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true
);


--
-- Name: rotisserie_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rotisserie_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rotisserie_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rotisserie_instances_id_seq OWNED BY rotisserie_instances.id;


--
-- Name: rotisserie_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rotisserie_posts (
    id integer NOT NULL,
    rotisserie_discussion_id integer,
    round integer,
    title character varying(250) NOT NULL,
    output text,
    session_id character varying(255),
    active boolean DEFAULT true,
    parent_id integer,
    children_count integer,
    ancestors_count integer,
    descendants_count integer,
    "position" integer,
    hidden boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    public boolean DEFAULT true
);


--
-- Name: rotisserie_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rotisserie_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rotisserie_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rotisserie_posts_id_seq OWNED BY rotisserie_posts.id;


--
-- Name: rotisserie_trackers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rotisserie_trackers (
    id integer NOT NULL,
    rotisserie_discussion_id integer,
    rotisserie_post_id integer,
    user_id integer,
    notify_description character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: rotisserie_trackers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rotisserie_trackers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rotisserie_trackers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rotisserie_trackers_id_seq OWNED BY rotisserie_trackers.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE sessions (
    id integer NOT NULL,
    session_id character varying(255) NOT NULL,
    data text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sessions_id_seq OWNED BY sessions.id;


--
-- Name: taggings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE taggings (
    id integer NOT NULL,
    tag_id integer,
    taggable_id integer,
    tagger_id integer,
    tagger_type character varying(255),
    taggable_type character varying(255),
    context character varying(255),
    created_at timestamp without time zone
);


--
-- Name: taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE taggings_id_seq OWNED BY taggings.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tags (
    id integer NOT NULL,
    name character varying(255)
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tags_id_seq OWNED BY tags.id;


--
-- Name: text_blocks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE text_blocks (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(5242880) NOT NULL,
    mime_type character varying(50) DEFAULT 'text/plain'::character varying,
    active boolean DEFAULT true,
    public boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: text_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE text_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: text_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE text_blocks_id_seq OWNED BY text_blocks.id;


--
-- Name: user_collection_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_collection_versions (
    id integer NOT NULL,
    user_collection_id integer,
    version integer,
    owner_id integer,
    name character varying(255) DEFAULT NULL::character varying,
    description character varying(255) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    owner_version integer
);


--
-- Name: user_collection_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_collection_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_collection_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_collection_versions_id_seq OWNED BY user_collection_versions.id;


--
-- Name: user_collections; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_collections (
    id integer NOT NULL,
    owner_id integer,
    name character varying(255),
    description character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    owner_version integer,
    version integer
);


--
-- Name: user_collections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_collections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_collections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_collections_id_seq OWNED BY user_collections.id;


--
-- Name: user_collections_users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_collections_users (
    user_id integer,
    user_collection_id integer,
    user_version integer,
    user_collection_version integer
);


--
-- Name: user_collections_users_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_collections_users_versions (
    user_id integer,
    user_collection_id integer,
    user_version integer,
    user_collection_version integer
);


--
-- Name: user_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_versions (
    id integer NOT NULL,
    user_id integer,
    version integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    login character varying(255) DEFAULT NULL::character varying,
    crypted_password character varying(255) DEFAULT NULL::character varying,
    password_salt character varying(255) DEFAULT NULL::character varying,
    persistence_token character varying(255) DEFAULT NULL::character varying,
    login_count integer DEFAULT 0,
    last_request_at timestamp without time zone,
    last_login_at timestamp without time zone,
    current_login_at timestamp without time zone,
    last_login_ip character varying(255) DEFAULT NULL::character varying,
    current_login_ip character varying(255) DEFAULT NULL::character varying,
    oauth_token character varying(255) DEFAULT NULL::character varying,
    oauth_secret character varying(255) DEFAULT NULL::character varying,
    email_address character varying(255) DEFAULT NULL::character varying,
    tz_name character varying(255) DEFAULT NULL::character varying,
    bookmark_id integer,
    karma integer,
    attribution character varying(255) DEFAULT NULL::character varying,
    perishable_token character varying(255) DEFAULT NULL::character varying,
    default_show_annotations boolean,
    tab_open_new_items boolean,
    default_font_size character varying(255) DEFAULT NULL::character varying
);


--
-- Name: user_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_versions_id_seq OWNED BY user_versions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    login character varying(255) DEFAULT NULL::character varying,
    crypted_password character varying(255) DEFAULT NULL::character varying,
    password_salt character varying(255) DEFAULT NULL::character varying,
    persistence_token character varying(255) NOT NULL,
    login_count integer DEFAULT 0 NOT NULL,
    last_request_at timestamp without time zone,
    last_login_at timestamp without time zone,
    current_login_at timestamp without time zone,
    last_login_ip character varying(255),
    current_login_ip character varying(255),
    oauth_token character varying(255),
    oauth_secret character varying(255),
    email_address character varying(255),
    tz_name character varying(255),
    bookmark_id integer,
    karma integer,
    attribution character varying(255),
    perishable_token character varying(255),
    default_show_annotations boolean,
    tab_open_new_items boolean,
    default_font_size character varying(255) DEFAULT 16,
    version integer
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: vote_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE vote_versions (
    id integer NOT NULL,
    vote_id integer,
    version integer,
    vote boolean DEFAULT false,
    voteable_id integer,
    voteable_type character varying(255) DEFAULT NULL::character varying,
    voter_id integer,
    voter_type character varying(255) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    voter_version integer,
    voteable_version integer
);


--
-- Name: vote_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE vote_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vote_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE vote_versions_id_seq OWNED BY vote_versions.id;


--
-- Name: votes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE votes (
    id integer NOT NULL,
    vote boolean DEFAULT false,
    voteable_id integer,
    voteable_type character varying(255),
    voter_id integer,
    voter_type character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    voter_version integer,
    voteable_version integer,
    version integer
);


--
-- Name: votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE votes_id_seq OWNED BY votes.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY annotation_versions ALTER COLUMN id SET DEFAULT nextval('annotation_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY annotations ALTER COLUMN id SET DEFAULT nextval('annotations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY brain_busters ALTER COLUMN id SET DEFAULT nextval('brain_busters_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_citation_versions ALTER COLUMN id SET DEFAULT nextval('case_citation_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_citations ALTER COLUMN id SET DEFAULT nextval('case_citations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_docket_number_versions ALTER COLUMN id SET DEFAULT nextval('case_docket_number_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_docket_numbers ALTER COLUMN id SET DEFAULT nextval('case_docket_numbers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_jurisdiction_versions ALTER COLUMN id SET DEFAULT nextval('case_jurisdiction_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_jurisdictions ALTER COLUMN id SET DEFAULT nextval('case_jurisdictions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_request_versions ALTER COLUMN id SET DEFAULT nextval('case_request_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_requests ALTER COLUMN id SET DEFAULT nextval('case_requests_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_versions ALTER COLUMN id SET DEFAULT nextval('case_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY cases ALTER COLUMN id SET DEFAULT nextval('cases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY collage_link_versions ALTER COLUMN id SET DEFAULT nextval('collage_link_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY collage_links ALTER COLUMN id SET DEFAULT nextval('collage_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY collage_versions ALTER COLUMN id SET DEFAULT nextval('collage_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY collages ALTER COLUMN id SET DEFAULT nextval('collages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY color_mapping_versions ALTER COLUMN id SET DEFAULT nextval('color_mapping_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY color_mappings ALTER COLUMN id SET DEFAULT nextval('color_mappings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY defect_versions ALTER COLUMN id SET DEFAULT nextval('defect_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY defects ALTER COLUMN id SET DEFAULT nextval('defects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY influences ALTER COLUMN id SET DEFAULT nextval('influences_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_annotations ALTER COLUMN id SET DEFAULT nextval('item_annotations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_cases ALTER COLUMN id SET DEFAULT nextval('item_cases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_collages ALTER COLUMN id SET DEFAULT nextval('item_collages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_defaults ALTER COLUMN id SET DEFAULT nextval('item_defaults_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_images ALTER COLUMN id SET DEFAULT nextval('item_images_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_medias ALTER COLUMN id SET DEFAULT nextval('item_medias_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_playlists ALTER COLUMN id SET DEFAULT nextval('item_playlists_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_question_instances ALTER COLUMN id SET DEFAULT nextval('item_question_instances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_questions ALTER COLUMN id SET DEFAULT nextval('item_questions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_rotisserie_discussions ALTER COLUMN id SET DEFAULT nextval('item_rotisserie_discussions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_text_blocks ALTER COLUMN id SET DEFAULT nextval('item_text_blocks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_texts ALTER COLUMN id SET DEFAULT nextval('item_texts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY item_youtubes ALTER COLUMN id SET DEFAULT nextval('item_youtubes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY journal_article_types ALTER COLUMN id SET DEFAULT nextval('journal_article_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY journal_articles ALTER COLUMN id SET DEFAULT nextval('journal_articles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY media_types ALTER COLUMN id SET DEFAULT nextval('media_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY medias ALTER COLUMN id SET DEFAULT nextval('medias_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY metadata ALTER COLUMN id SET DEFAULT nextval('metadata_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY metadatum_versions ALTER COLUMN id SET DEFAULT nextval('metadatum_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notification_invites ALTER COLUMN id SET DEFAULT nextval('notification_invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notification_trackers ALTER COLUMN id SET DEFAULT nextval('notification_trackers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY permission_assignments ALTER COLUMN id SET DEFAULT nextval('permission_assignments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions ALTER COLUMN id SET DEFAULT nextval('permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY playlist_items ALTER COLUMN id SET DEFAULT nextval('playlist_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY playlists ALTER COLUMN id SET DEFAULT nextval('playlists_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY question_instances ALTER COLUMN id SET DEFAULT nextval('question_instances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY questions ALTER COLUMN id SET DEFAULT nextval('questions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY role_versions ALTER COLUMN id SET DEFAULT nextval('role_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY roles ALTER COLUMN id SET DEFAULT nextval('roles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY rotisserie_assignments ALTER COLUMN id SET DEFAULT nextval('rotisserie_assignments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY rotisserie_discussions ALTER COLUMN id SET DEFAULT nextval('rotisserie_discussions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY rotisserie_instances ALTER COLUMN id SET DEFAULT nextval('rotisserie_instances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY rotisserie_posts ALTER COLUMN id SET DEFAULT nextval('rotisserie_posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY rotisserie_trackers ALTER COLUMN id SET DEFAULT nextval('rotisserie_trackers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sessions ALTER COLUMN id SET DEFAULT nextval('sessions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY taggings ALTER COLUMN id SET DEFAULT nextval('taggings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY tags ALTER COLUMN id SET DEFAULT nextval('tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY text_blocks ALTER COLUMN id SET DEFAULT nextval('text_blocks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_collection_versions ALTER COLUMN id SET DEFAULT nextval('user_collection_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_collections ALTER COLUMN id SET DEFAULT nextval('user_collections_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_versions ALTER COLUMN id SET DEFAULT nextval('user_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY vote_versions ALTER COLUMN id SET DEFAULT nextval('vote_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY votes ALTER COLUMN id SET DEFAULT nextval('votes_id_seq'::regclass);


--
-- Name: annotation_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY annotation_versions
    ADD CONSTRAINT annotation_versions_pkey PRIMARY KEY (id);


--
-- Name: annotations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY annotations
    ADD CONSTRAINT annotations_pkey PRIMARY KEY (id);


--
-- Name: brain_busters_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY brain_busters
    ADD CONSTRAINT brain_busters_pkey PRIMARY KEY (id);


--
-- Name: case_citation_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_citation_versions
    ADD CONSTRAINT case_citation_versions_pkey PRIMARY KEY (id);


--
-- Name: case_citations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_citations
    ADD CONSTRAINT case_citations_pkey PRIMARY KEY (id);


--
-- Name: case_docket_number_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_docket_number_versions
    ADD CONSTRAINT case_docket_number_versions_pkey PRIMARY KEY (id);


--
-- Name: case_docket_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_docket_numbers
    ADD CONSTRAINT case_docket_numbers_pkey PRIMARY KEY (id);


--
-- Name: case_jurisdiction_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_jurisdiction_versions
    ADD CONSTRAINT case_jurisdiction_versions_pkey PRIMARY KEY (id);


--
-- Name: case_jurisdictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_jurisdictions
    ADD CONSTRAINT case_jurisdictions_pkey PRIMARY KEY (id);


--
-- Name: case_request_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_request_versions
    ADD CONSTRAINT case_request_versions_pkey PRIMARY KEY (id);


--
-- Name: case_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_requests
    ADD CONSTRAINT case_requests_pkey PRIMARY KEY (id);


--
-- Name: case_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY case_versions
    ADD CONSTRAINT case_versions_pkey PRIMARY KEY (id);


--
-- Name: cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (id);


--
-- Name: collage_link_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY collage_link_versions
    ADD CONSTRAINT collage_link_versions_pkey PRIMARY KEY (id);


--
-- Name: collage_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY collage_links
    ADD CONSTRAINT collage_links_pkey PRIMARY KEY (id);


--
-- Name: collage_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY collage_versions
    ADD CONSTRAINT collage_versions_pkey PRIMARY KEY (id);


--
-- Name: collages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY collages
    ADD CONSTRAINT collages_pkey PRIMARY KEY (id);


--
-- Name: color_mapping_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY color_mapping_versions
    ADD CONSTRAINT color_mapping_versions_pkey PRIMARY KEY (id);


--
-- Name: color_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY color_mappings
    ADD CONSTRAINT color_mappings_pkey PRIMARY KEY (id);


--
-- Name: defect_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY defect_versions
    ADD CONSTRAINT defect_versions_pkey PRIMARY KEY (id);


--
-- Name: defects_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY defects
    ADD CONSTRAINT defects_pkey PRIMARY KEY (id);


--
-- Name: influences_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY influences
    ADD CONSTRAINT influences_pkey PRIMARY KEY (id);


--
-- Name: item_annotations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_annotations
    ADD CONSTRAINT item_annotations_pkey PRIMARY KEY (id);


--
-- Name: item_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_cases
    ADD CONSTRAINT item_cases_pkey PRIMARY KEY (id);


--
-- Name: item_collages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_collages
    ADD CONSTRAINT item_collages_pkey PRIMARY KEY (id);


--
-- Name: item_defaults_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_defaults
    ADD CONSTRAINT item_defaults_pkey PRIMARY KEY (id);


--
-- Name: item_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_images
    ADD CONSTRAINT item_images_pkey PRIMARY KEY (id);


--
-- Name: item_medias_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_medias
    ADD CONSTRAINT item_medias_pkey PRIMARY KEY (id);


--
-- Name: item_playlists_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_playlists
    ADD CONSTRAINT item_playlists_pkey PRIMARY KEY (id);


--
-- Name: item_question_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_question_instances
    ADD CONSTRAINT item_question_instances_pkey PRIMARY KEY (id);


--
-- Name: item_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_questions
    ADD CONSTRAINT item_questions_pkey PRIMARY KEY (id);


--
-- Name: item_rotisserie_discussions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_rotisserie_discussions
    ADD CONSTRAINT item_rotisserie_discussions_pkey PRIMARY KEY (id);


--
-- Name: item_text_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_text_blocks
    ADD CONSTRAINT item_text_blocks_pkey PRIMARY KEY (id);


--
-- Name: item_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_texts
    ADD CONSTRAINT item_texts_pkey PRIMARY KEY (id);


--
-- Name: item_youtubes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY item_youtubes
    ADD CONSTRAINT item_youtubes_pkey PRIMARY KEY (id);


--
-- Name: journal_article_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY journal_article_types
    ADD CONSTRAINT journal_article_types_pkey PRIMARY KEY (id);


--
-- Name: journal_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY journal_articles
    ADD CONSTRAINT journal_articles_pkey PRIMARY KEY (id);


--
-- Name: media_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY media_types
    ADD CONSTRAINT media_types_pkey PRIMARY KEY (id);


--
-- Name: medias_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medias
    ADD CONSTRAINT medias_pkey PRIMARY KEY (id);


--
-- Name: metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY metadata
    ADD CONSTRAINT metadata_pkey PRIMARY KEY (id);


--
-- Name: metadatum_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY metadatum_versions
    ADD CONSTRAINT metadatum_versions_pkey PRIMARY KEY (id);


--
-- Name: notification_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notification_invites
    ADD CONSTRAINT notification_invites_pkey PRIMARY KEY (id);


--
-- Name: notification_trackers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notification_trackers
    ADD CONSTRAINT notification_trackers_pkey PRIMARY KEY (id);


--
-- Name: permission_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY permission_assignments
    ADD CONSTRAINT permission_assignments_pkey PRIMARY KEY (id);


--
-- Name: permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: playlist_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY playlist_items
    ADD CONSTRAINT playlist_items_pkey PRIMARY KEY (id);


--
-- Name: playlists_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY playlists
    ADD CONSTRAINT playlists_pkey PRIMARY KEY (id);


--
-- Name: question_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY question_instances
    ADD CONSTRAINT question_instances_pkey PRIMARY KEY (id);


--
-- Name: questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);


--
-- Name: role_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY role_versions
    ADD CONSTRAINT role_versions_pkey PRIMARY KEY (id);


--
-- Name: roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: rotisserie_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rotisserie_assignments
    ADD CONSTRAINT rotisserie_assignments_pkey PRIMARY KEY (id);


--
-- Name: rotisserie_discussions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rotisserie_discussions
    ADD CONSTRAINT rotisserie_discussions_pkey PRIMARY KEY (id);


--
-- Name: rotisserie_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rotisserie_instances
    ADD CONSTRAINT rotisserie_instances_pkey PRIMARY KEY (id);


--
-- Name: rotisserie_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rotisserie_posts
    ADD CONSTRAINT rotisserie_posts_pkey PRIMARY KEY (id);


--
-- Name: rotisserie_trackers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rotisserie_trackers
    ADD CONSTRAINT rotisserie_trackers_pkey PRIMARY KEY (id);


--
-- Name: sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY taggings
    ADD CONSTRAINT taggings_pkey PRIMARY KEY (id);


--
-- Name: tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: text_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY text_blocks
    ADD CONSTRAINT text_blocks_pkey PRIMARY KEY (id);


--
-- Name: user_collection_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_collection_versions
    ADD CONSTRAINT user_collection_versions_pkey PRIMARY KEY (id);


--
-- Name: user_collections_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_collections
    ADD CONSTRAINT user_collections_pkey PRIMARY KEY (id);


--
-- Name: user_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_versions
    ADD CONSTRAINT user_versions_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vote_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY vote_versions
    ADD CONSTRAINT vote_versions_pkey PRIMARY KEY (id);


--
-- Name: votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);


--
-- Name: fk_voteables; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fk_voteables ON votes USING btree (voteable_id, voteable_type);


--
-- Name: fk_voters; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fk_voters ON votes USING btree (voter_id, voter_type);


--
-- Name: index_annotation_versions_on_annotation_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_annotation_versions_on_annotation_id ON annotation_versions USING btree (annotation_id);


--
-- Name: index_annotations_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_annotations_on_active ON annotations USING btree (active);


--
-- Name: index_annotations_on_ancestry; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_annotations_on_ancestry ON annotations USING btree (ancestry);


--
-- Name: index_annotations_on_annotation_end; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_annotations_on_annotation_end ON annotations USING btree (annotation_end);


--
-- Name: index_annotations_on_annotation_start; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_annotations_on_annotation_start ON annotations USING btree (annotation_start);


--
-- Name: index_annotations_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_annotations_on_public ON annotations USING btree (public);


--
-- Name: index_case_citation_versions_on_case_citation_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_citation_versions_on_case_citation_id ON case_citation_versions USING btree (case_citation_id);


--
-- Name: index_case_citations_on_case_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_citations_on_case_id ON case_citations USING btree (case_id);


--
-- Name: index_case_citations_on_page; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_citations_on_page ON case_citations USING btree (page);


--
-- Name: index_case_citations_on_reporter; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_citations_on_reporter ON case_citations USING btree (reporter);


--
-- Name: index_case_citations_on_volume; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_citations_on_volume ON case_citations USING btree (volume);


--
-- Name: index_case_docket_number_versions_on_case_docket_number_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_docket_number_versions_on_case_docket_number_id ON case_docket_number_versions USING btree (case_docket_number_id);


--
-- Name: index_case_docket_numbers_on_case_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_docket_numbers_on_case_id ON case_docket_numbers USING btree (case_id);


--
-- Name: index_case_docket_numbers_on_docket_number; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_docket_numbers_on_docket_number ON case_docket_numbers USING btree (docket_number);


--
-- Name: index_case_jurisdiction_versions_on_case_jurisdiction_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_jurisdiction_versions_on_case_jurisdiction_id ON case_jurisdiction_versions USING btree (case_jurisdiction_id);


--
-- Name: index_case_jurisdictions_on_abbreviation; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_jurisdictions_on_abbreviation ON case_jurisdictions USING btree (abbreviation);


--
-- Name: index_case_jurisdictions_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_jurisdictions_on_name ON case_jurisdictions USING btree (name);


--
-- Name: index_case_request_versions_on_case_request_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_request_versions_on_case_request_id ON case_request_versions USING btree (case_request_id);


--
-- Name: index_case_versions_on_case_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_case_versions_on_case_id ON case_versions USING btree (case_id);


--
-- Name: index_cases_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_active ON cases USING btree (active);


--
-- Name: index_cases_on_author; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_author ON cases USING btree (author);


--
-- Name: index_cases_on_case_jurisdiction_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_case_jurisdiction_id ON cases USING btree (case_jurisdiction_id);


--
-- Name: index_cases_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_created_at ON cases USING btree (created_at);


--
-- Name: index_cases_on_current_opinion; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_current_opinion ON cases USING btree (current_opinion);


--
-- Name: index_cases_on_decision_date; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_decision_date ON cases USING btree (decision_date);


--
-- Name: index_cases_on_full_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_full_name ON cases USING btree (full_name);


--
-- Name: index_cases_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_public ON cases USING btree (public);


--
-- Name: index_cases_on_short_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_short_name ON cases USING btree (short_name);


--
-- Name: index_cases_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cases_on_updated_at ON cases USING btree (updated_at);


--
-- Name: index_collage_link_versions_on_collage_link_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collage_link_versions_on_collage_link_id ON collage_link_versions USING btree (collage_link_id);


--
-- Name: index_collage_versions_on_collage_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collage_versions_on_collage_id ON collage_versions USING btree (collage_id);


--
-- Name: index_collages_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_active ON collages USING btree (active);


--
-- Name: index_collages_on_ancestry; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_ancestry ON collages USING btree (ancestry);


--
-- Name: index_collages_on_annotatable_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_annotatable_id ON collages USING btree (annotatable_id);


--
-- Name: index_collages_on_annotatable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_annotatable_type ON collages USING btree (annotatable_type);


--
-- Name: index_collages_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_created_at ON collages USING btree (created_at);


--
-- Name: index_collages_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_name ON collages USING btree (name);


--
-- Name: index_collages_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_public ON collages USING btree (public);


--
-- Name: index_collages_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_updated_at ON collages USING btree (updated_at);


--
-- Name: index_collages_on_word_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_collages_on_word_count ON collages USING btree (word_count);


--
-- Name: index_color_mapping_versions_on_color_mapping_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_color_mapping_versions_on_color_mapping_id ON color_mapping_versions USING btree (color_mapping_id);


--
-- Name: index_defect_versions_on_defect_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_defect_versions_on_defect_id ON defect_versions USING btree (defect_id);


--
-- Name: index_influences_on_ancestors_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_influences_on_ancestors_count ON influences USING btree (ancestors_count);


--
-- Name: index_influences_on_children_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_influences_on_children_count ON influences USING btree (children_count);


--
-- Name: index_influences_on_descendants_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_influences_on_descendants_count ON influences USING btree (descendants_count);


--
-- Name: index_influences_on_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_influences_on_parent_id ON influences USING btree (parent_id);


--
-- Name: index_influences_on_resource_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_influences_on_resource_id ON influences USING btree (resource_id);


--
-- Name: index_influences_on_resource_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_influences_on_resource_type ON influences USING btree (resource_type);


--
-- Name: index_item_annotations_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_annotations_on_active ON item_annotations USING btree (active);


--
-- Name: index_item_annotations_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_annotations_on_actual_object_id ON item_annotations USING btree (actual_object_id);


--
-- Name: index_item_annotations_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_annotations_on_actual_object_type ON item_annotations USING btree (actual_object_type);


--
-- Name: index_item_annotations_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_annotations_on_public ON item_annotations USING btree (public);


--
-- Name: index_item_annotations_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_annotations_on_url ON item_annotations USING btree (url);


--
-- Name: index_item_cases_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_cases_on_active ON item_cases USING btree (active);


--
-- Name: index_item_cases_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_cases_on_actual_object_id ON item_cases USING btree (actual_object_id);


--
-- Name: index_item_cases_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_cases_on_actual_object_type ON item_cases USING btree (actual_object_type);


--
-- Name: index_item_cases_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_cases_on_public ON item_cases USING btree (public);


--
-- Name: index_item_cases_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_cases_on_url ON item_cases USING btree (url);


--
-- Name: index_item_collages_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_collages_on_active ON item_collages USING btree (active);


--
-- Name: index_item_collages_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_collages_on_actual_object_id ON item_collages USING btree (actual_object_id);


--
-- Name: index_item_collages_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_collages_on_actual_object_type ON item_collages USING btree (actual_object_type);


--
-- Name: index_item_collages_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_collages_on_public ON item_collages USING btree (public);


--
-- Name: index_item_collages_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_collages_on_url ON item_collages USING btree (url);


--
-- Name: index_item_defaults_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_defaults_on_active ON item_defaults USING btree (active);


--
-- Name: index_item_defaults_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_defaults_on_url ON item_defaults USING btree (url);


--
-- Name: index_item_images_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_images_on_active ON item_images USING btree (active);


--
-- Name: index_item_images_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_images_on_actual_object_id ON item_images USING btree (actual_object_id);


--
-- Name: index_item_images_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_images_on_actual_object_type ON item_images USING btree (actual_object_type);


--
-- Name: index_item_images_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_images_on_url ON item_images USING btree (url);


--
-- Name: index_item_medias_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_medias_on_active ON item_medias USING btree (active);


--
-- Name: index_item_medias_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_medias_on_public ON item_medias USING btree (public);


--
-- Name: index_item_medias_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_medias_on_url ON item_medias USING btree (url);


--
-- Name: index_item_playlists_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_playlists_on_active ON item_playlists USING btree (active);


--
-- Name: index_item_playlists_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_playlists_on_actual_object_id ON item_playlists USING btree (actual_object_id);


--
-- Name: index_item_playlists_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_playlists_on_actual_object_type ON item_playlists USING btree (actual_object_type);


--
-- Name: index_item_playlists_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_playlists_on_public ON item_playlists USING btree (public);


--
-- Name: index_item_playlists_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_playlists_on_url ON item_playlists USING btree (url);


--
-- Name: index_item_question_instances_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_question_instances_on_active ON item_question_instances USING btree (active);


--
-- Name: index_item_question_instances_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_question_instances_on_actual_object_id ON item_question_instances USING btree (actual_object_id);


--
-- Name: index_item_question_instances_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_question_instances_on_actual_object_type ON item_question_instances USING btree (actual_object_type);


--
-- Name: index_item_question_instances_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_question_instances_on_public ON item_question_instances USING btree (public);


--
-- Name: index_item_question_instances_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_question_instances_on_url ON item_question_instances USING btree (url);


--
-- Name: index_item_questions_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_questions_on_active ON item_questions USING btree (active);


--
-- Name: index_item_questions_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_questions_on_actual_object_id ON item_questions USING btree (actual_object_id);


--
-- Name: index_item_questions_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_questions_on_actual_object_type ON item_questions USING btree (actual_object_type);


--
-- Name: index_item_questions_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_questions_on_public ON item_questions USING btree (public);


--
-- Name: index_item_questions_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_questions_on_url ON item_questions USING btree (url);


--
-- Name: index_item_rotisserie_discussions_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_rotisserie_discussions_on_active ON item_rotisserie_discussions USING btree (active);


--
-- Name: index_item_rotisserie_discussions_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_rotisserie_discussions_on_actual_object_id ON item_rotisserie_discussions USING btree (actual_object_id);


--
-- Name: index_item_rotisserie_discussions_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_rotisserie_discussions_on_actual_object_type ON item_rotisserie_discussions USING btree (actual_object_type);


--
-- Name: index_item_rotisserie_discussions_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_rotisserie_discussions_on_public ON item_rotisserie_discussions USING btree (public);


--
-- Name: index_item_rotisserie_discussions_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_rotisserie_discussions_on_url ON item_rotisserie_discussions USING btree (url);


--
-- Name: index_item_text_blocks_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_text_blocks_on_active ON item_text_blocks USING btree (active);


--
-- Name: index_item_text_blocks_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_text_blocks_on_actual_object_id ON item_text_blocks USING btree (actual_object_id);


--
-- Name: index_item_text_blocks_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_text_blocks_on_actual_object_type ON item_text_blocks USING btree (actual_object_type);


--
-- Name: index_item_text_blocks_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_text_blocks_on_public ON item_text_blocks USING btree (public);


--
-- Name: index_item_text_blocks_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_text_blocks_on_url ON item_text_blocks USING btree (url);


--
-- Name: index_item_texts_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_texts_on_active ON item_texts USING btree (active);


--
-- Name: index_item_texts_on_actual_object_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_texts_on_actual_object_id ON item_texts USING btree (actual_object_id);


--
-- Name: index_item_texts_on_actual_object_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_texts_on_actual_object_type ON item_texts USING btree (actual_object_type);


--
-- Name: index_item_texts_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_texts_on_url ON item_texts USING btree (url);


--
-- Name: index_item_youtubes_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_youtubes_on_active ON item_youtubes USING btree (active);


--
-- Name: index_item_youtubes_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_item_youtubes_on_url ON item_youtubes USING btree (url);


--
-- Name: index_metadata_on_classifiable_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_metadata_on_classifiable_id ON metadata USING btree (classifiable_id);


--
-- Name: index_metadata_on_classifiable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_metadata_on_classifiable_type ON metadata USING btree (classifiable_type);


--
-- Name: index_metadatum_versions_on_metadatum_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_metadatum_versions_on_metadatum_id ON metadatum_versions USING btree (metadatum_id);


--
-- Name: index_notification_invites_on_email_address; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_invites_on_email_address ON notification_invites USING btree (email_address);


--
-- Name: index_notification_invites_on_tid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_invites_on_tid ON notification_invites USING btree (tid);


--
-- Name: index_notification_invites_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_invites_on_user_id ON notification_invites USING btree (user_id);


--
-- Name: index_notification_trackers_on_rotisserie_discussion_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_trackers_on_rotisserie_discussion_id ON notification_trackers USING btree (rotisserie_discussion_id);


--
-- Name: index_notification_trackers_on_rotisserie_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_trackers_on_rotisserie_post_id ON notification_trackers USING btree (rotisserie_post_id);


--
-- Name: index_notification_trackers_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_trackers_on_user_id ON notification_trackers USING btree (user_id);


--
-- Name: index_playlist_items_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlist_items_on_active ON playlist_items USING btree (active);


--
-- Name: index_playlist_items_on_ancestry; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlist_items_on_ancestry ON playlist_items USING btree (ancestry);


--
-- Name: index_playlist_items_on_playlist_item_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlist_items_on_playlist_item_parent_id ON playlist_items USING btree (playlist_item_parent_id);


--
-- Name: index_playlist_items_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlist_items_on_position ON playlist_items USING btree ("position");


--
-- Name: index_playlist_items_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlist_items_on_public ON playlist_items USING btree (public);


--
-- Name: index_playlist_items_on_resource_item_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlist_items_on_resource_item_id ON playlist_items USING btree (resource_item_id);


--
-- Name: index_playlist_items_on_resource_item_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlist_items_on_resource_item_type ON playlist_items USING btree (resource_item_type);


--
-- Name: index_playlists_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlists_on_active ON playlists USING btree (active);


--
-- Name: index_playlists_on_ancestry; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlists_on_ancestry ON playlists USING btree (ancestry);


--
-- Name: index_playlists_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_playlists_on_position ON playlists USING btree ("position");


--
-- Name: index_question_instances_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_active ON question_instances USING btree (active);


--
-- Name: index_question_instances_on_ancestors_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_ancestors_count ON question_instances USING btree (ancestors_count);


--
-- Name: index_question_instances_on_children_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_children_count ON question_instances USING btree (children_count);


--
-- Name: index_question_instances_on_descendants_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_descendants_count ON question_instances USING btree (descendants_count);


--
-- Name: index_question_instances_on_hidden; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_hidden ON question_instances USING btree (hidden);


--
-- Name: index_question_instances_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_question_instances_on_name ON question_instances USING btree (name);


--
-- Name: index_question_instances_on_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_parent_id ON question_instances USING btree (parent_id);


--
-- Name: index_question_instances_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_position ON question_instances USING btree ("position");


--
-- Name: index_question_instances_on_project_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_project_id ON question_instances USING btree (project_id);


--
-- Name: index_question_instances_on_project_id_and_position; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_question_instances_on_project_id_and_position ON question_instances USING btree (project_id, "position");


--
-- Name: index_question_instances_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_public ON question_instances USING btree (public);


--
-- Name: index_question_instances_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_question_instances_on_user_id ON question_instances USING btree (user_id);


--
-- Name: index_questions_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_active ON questions USING btree (active);


--
-- Name: index_questions_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_created_at ON questions USING btree (created_at);


--
-- Name: index_questions_on_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_parent_id ON questions USING btree (parent_id);


--
-- Name: index_questions_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_position ON questions USING btree ("position");


--
-- Name: index_questions_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_public ON questions USING btree (public);


--
-- Name: index_questions_on_question_instance_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_question_instance_id ON questions USING btree (question_instance_id);


--
-- Name: index_questions_on_sticky; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_sticky ON questions USING btree (sticky);


--
-- Name: index_questions_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_updated_at ON questions USING btree (updated_at);


--
-- Name: index_questions_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_questions_on_user_id ON questions USING btree (user_id);


--
-- Name: index_role_versions_on_role_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_role_versions_on_role_id ON role_versions USING btree (role_id);


--
-- Name: index_roles_on_authorizable_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_on_authorizable_id ON roles USING btree (authorizable_id);


--
-- Name: index_roles_on_authorizable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_on_authorizable_type ON roles USING btree (authorizable_type);


--
-- Name: index_roles_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_on_name ON roles USING btree (name);


--
-- Name: index_roles_users_on_role_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_users_on_role_id ON roles_users USING btree (role_id);


--
-- Name: index_roles_users_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_users_on_user_id ON roles_users USING btree (user_id);


--
-- Name: index_rotisserie_assignments_on_rotisserie_discussion_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_assignments_on_rotisserie_discussion_id ON rotisserie_assignments USING btree (rotisserie_discussion_id);


--
-- Name: index_rotisserie_assignments_on_rotisserie_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_assignments_on_rotisserie_post_id ON rotisserie_assignments USING btree (rotisserie_post_id);


--
-- Name: index_rotisserie_assignments_on_round; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_assignments_on_round ON rotisserie_assignments USING btree (round);


--
-- Name: index_rotisserie_assignments_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_assignments_on_user_id ON rotisserie_assignments USING btree (user_id);


--
-- Name: index_rotisserie_discussions_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_discussions_on_active ON rotisserie_discussions USING btree (active);


--
-- Name: index_rotisserie_discussions_on_rotisserie_instance_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_discussions_on_rotisserie_instance_id ON rotisserie_discussions USING btree (rotisserie_instance_id);


--
-- Name: index_rotisserie_discussions_on_title; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_discussions_on_title ON rotisserie_discussions USING btree (title);


--
-- Name: index_rotisserie_instances_on_title; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_rotisserie_instances_on_title ON rotisserie_instances USING btree (title);


--
-- Name: index_rotisserie_posts_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_posts_on_active ON rotisserie_posts USING btree (active);


--
-- Name: index_rotisserie_posts_on_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_posts_on_parent_id ON rotisserie_posts USING btree (parent_id);


--
-- Name: index_rotisserie_posts_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_posts_on_position ON rotisserie_posts USING btree ("position");


--
-- Name: index_rotisserie_posts_on_rotisserie_discussion_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_posts_on_rotisserie_discussion_id ON rotisserie_posts USING btree (rotisserie_discussion_id);


--
-- Name: index_rotisserie_posts_on_round; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_posts_on_round ON rotisserie_posts USING btree (round);


--
-- Name: index_rotisserie_trackers_on_rotisserie_discussion_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_trackers_on_rotisserie_discussion_id ON rotisserie_trackers USING btree (rotisserie_discussion_id);


--
-- Name: index_rotisserie_trackers_on_rotisserie_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_trackers_on_rotisserie_post_id ON rotisserie_trackers USING btree (rotisserie_post_id);


--
-- Name: index_rotisserie_trackers_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rotisserie_trackers_on_user_id ON rotisserie_trackers USING btree (user_id);


--
-- Name: index_sessions_on_session_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_sessions_on_session_id ON sessions USING btree (session_id);


--
-- Name: index_sessions_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_sessions_on_updated_at ON sessions USING btree (updated_at);


--
-- Name: index_taggings_on_context; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_context ON taggings USING btree (context);


--
-- Name: index_taggings_on_tag_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_tag_id ON taggings USING btree (tag_id);


--
-- Name: index_taggings_on_taggable_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_taggable_id ON taggings USING btree (taggable_id);


--
-- Name: index_taggings_on_taggable_id_and_taggable_type_and_context; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_taggable_id_and_taggable_type_and_context ON taggings USING btree (taggable_id, taggable_type, context);


--
-- Name: index_taggings_on_taggable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_taggable_type ON taggings USING btree (taggable_type);


--
-- Name: index_taggings_on_tagger_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_tagger_id ON taggings USING btree (tagger_id);


--
-- Name: index_taggings_on_tagger_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_tagger_type ON taggings USING btree (tagger_type);


--
-- Name: index_tags_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tags_on_name ON tags USING btree (name);


--
-- Name: index_text_blocks_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_text_blocks_on_created_at ON text_blocks USING btree (created_at);


--
-- Name: index_text_blocks_on_mime_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_text_blocks_on_mime_type ON text_blocks USING btree (mime_type);


--
-- Name: index_text_blocks_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_text_blocks_on_name ON text_blocks USING btree (name);


--
-- Name: index_text_blocks_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_text_blocks_on_updated_at ON text_blocks USING btree (updated_at);


--
-- Name: index_user_collection_versions_on_user_collection_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_collection_versions_on_user_collection_id ON user_collection_versions USING btree (user_collection_id);


--
-- Name: index_user_versions_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_versions_on_user_id ON user_versions USING btree (user_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_email_address ON users USING btree (email_address);


--
-- Name: index_users_on_last_request_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_last_request_at ON users USING btree (last_request_at);


--
-- Name: index_users_on_login; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_login ON users USING btree (login);


--
-- Name: index_users_on_oauth_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_oauth_token ON users USING btree (oauth_token);


--
-- Name: index_users_on_persistence_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_persistence_token ON users USING btree (persistence_token);


--
-- Name: index_users_on_tz_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_tz_name ON users USING btree (tz_name);


--
-- Name: index_vote_versions_on_vote_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_vote_versions_on_vote_id ON vote_versions USING btree (vote_id);


--
-- Name: uniq_one_vote_only; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX uniq_one_vote_only ON votes USING btree (voter_id, voter_type, voteable_id, voteable_type);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: annotations_collage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY annotations
    ADD CONSTRAINT annotations_collage_id_fkey FOREIGN KEY (collage_id) REFERENCES collages(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: case_citations_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_citations
    ADD CONSTRAINT case_citations_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: case_docket_numbers_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY case_docket_numbers
    ADD CONSTRAINT case_docket_numbers_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cases_case_jurisdiction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_case_jurisdiction_id_fkey FOREIGN KEY (case_jurisdiction_id) REFERENCES case_jurisdictions(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: questions_question_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY questions
    ADD CONSTRAINT questions_question_instance_id_fkey FOREIGN KEY (question_instance_id) REFERENCES question_instances(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO schema_migrations (version) VALUES ('20081103171327');

INSERT INTO schema_migrations (version) VALUES ('20081106072031');

INSERT INTO schema_migrations (version) VALUES ('20090810170153');

INSERT INTO schema_migrations (version) VALUES ('20091014202053');

INSERT INTO schema_migrations (version) VALUES ('20100202182219');

INSERT INTO schema_migrations (version) VALUES ('20100202182403');

INSERT INTO schema_migrations (version) VALUES ('20100211173106');

INSERT INTO schema_migrations (version) VALUES ('20100211175731');

INSERT INTO schema_migrations (version) VALUES ('20100211180240');

INSERT INTO schema_migrations (version) VALUES ('20100211180317');

INSERT INTO schema_migrations (version) VALUES ('20100211180546');

INSERT INTO schema_migrations (version) VALUES ('20100217190623');

INSERT INTO schema_migrations (version) VALUES ('20100226171918');

INSERT INTO schema_migrations (version) VALUES ('20100407162213');

INSERT INTO schema_migrations (version) VALUES ('20100409155520');

INSERT INTO schema_migrations (version) VALUES ('20100504203006');

INSERT INTO schema_migrations (version) VALUES ('20100505125100');

INSERT INTO schema_migrations (version) VALUES ('20100506163256');

INSERT INTO schema_migrations (version) VALUES ('20100511170100');

INSERT INTO schema_migrations (version) VALUES ('20100511170106');

INSERT INTO schema_migrations (version) VALUES ('20100511170251');

INSERT INTO schema_migrations (version) VALUES ('20100511170350');

INSERT INTO schema_migrations (version) VALUES ('20100511170400');

INSERT INTO schema_migrations (version) VALUES ('20100511172144');

INSERT INTO schema_migrations (version) VALUES ('20100520165005');

INSERT INTO schema_migrations (version) VALUES ('20100520165228');

INSERT INTO schema_migrations (version) VALUES ('20100520165715');

INSERT INTO schema_migrations (version) VALUES ('20100527151846');

INSERT INTO schema_migrations (version) VALUES ('20100603140855');

INSERT INTO schema_migrations (version) VALUES ('20100607162500');

INSERT INTO schema_migrations (version) VALUES ('20100609193820');

INSERT INTO schema_migrations (version) VALUES ('20100517222624');

INSERT INTO schema_migrations (version) VALUES ('20100609193921');

INSERT INTO schema_migrations (version) VALUES ('20100610162801');

INSERT INTO schema_migrations (version) VALUES ('20100614172345');

INSERT INTO schema_migrations (version) VALUES ('20100707151105');

INSERT INTO schema_migrations (version) VALUES ('20100913221023');

INSERT INTO schema_migrations (version) VALUES ('20100914140302');

INSERT INTO schema_migrations (version) VALUES ('20100917141004');

INSERT INTO schema_migrations (version) VALUES ('20100920191522');

INSERT INTO schema_migrations (version) VALUES ('20100920200624');

INSERT INTO schema_migrations (version) VALUES ('20100921142510');

INSERT INTO schema_migrations (version) VALUES ('20100922175008');

INSERT INTO schema_migrations (version) VALUES ('20100928191830');

INSERT INTO schema_migrations (version) VALUES ('20101005150523');

INSERT INTO schema_migrations (version) VALUES ('20101012160449');

INSERT INTO schema_migrations (version) VALUES ('20101012200155');

INSERT INTO schema_migrations (version) VALUES ('20101021123659');

INSERT INTO schema_migrations (version) VALUES ('20101025173330');

INSERT INTO schema_migrations (version) VALUES ('20101025191605');

INSERT INTO schema_migrations (version) VALUES ('20101116211524');

INSERT INTO schema_migrations (version) VALUES ('20101122230916');

INSERT INTO schema_migrations (version) VALUES ('20101012200159');

INSERT INTO schema_migrations (version) VALUES ('20110608191605');

INSERT INTO schema_migrations (version) VALUES ('20110608200000');

INSERT INTO schema_migrations (version) VALUES ('20110628000000');

INSERT INTO schema_migrations (version) VALUES ('20110703220613');

INSERT INTO schema_migrations (version) VALUES ('20110725144809');

INSERT INTO schema_migrations (version) VALUES ('20110808202112');

INSERT INTO schema_migrations (version) VALUES ('20110901201017');

INSERT INTO schema_migrations (version) VALUES ('20120801172444');

INSERT INTO schema_migrations (version) VALUES ('20120801173208');

INSERT INTO schema_migrations (version) VALUES ('20120801190549');

INSERT INTO schema_migrations (version) VALUES ('20120807154434');

INSERT INTO schema_migrations (version) VALUES ('20120808160123');

INSERT INTO schema_migrations (version) VALUES ('20120809173528');

INSERT INTO schema_migrations (version) VALUES ('20120809173927');

INSERT INTO schema_migrations (version) VALUES ('20120815140931');

INSERT INTO schema_migrations (version) VALUES ('20120815155653');

INSERT INTO schema_migrations (version) VALUES ('20120828155356');

INSERT INTO schema_migrations (version) VALUES ('20120905154351');

INSERT INTO schema_migrations (version) VALUES ('20120905155517');

INSERT INTO schema_migrations (version) VALUES ('20120906140055');

INSERT INTO schema_migrations (version) VALUES ('20120906140336');

INSERT INTO schema_migrations (version) VALUES ('20120912142954');

INSERT INTO schema_migrations (version) VALUES ('20120918144615');

INSERT INTO schema_migrations (version) VALUES ('20120918155405');

INSERT INTO schema_migrations (version) VALUES ('20120920141151');

INSERT INTO schema_migrations (version) VALUES ('20120924185505');

INSERT INTO schema_migrations (version) VALUES ('20120925144619');

INSERT INTO schema_migrations (version) VALUES ('20120926154820');

INSERT INTO schema_migrations (version) VALUES ('20121005144035');

INSERT INTO schema_migrations (version) VALUES ('20121031145323');

INSERT INTO schema_migrations (version) VALUES ('20130116222728');

INSERT INTO schema_migrations (version) VALUES ('20130118154403');

INSERT INTO schema_migrations (version) VALUES ('20130205171629');

INSERT INTO schema_migrations (version) VALUES ('20130304234236');