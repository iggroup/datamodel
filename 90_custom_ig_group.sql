--
-- PostgreSQL database dump
--

--
-- Name: qgep_import; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA qgep_ig;
ALTER SCHEMA qgep_ig OWNER TO postgres;

CREATE DOMAIN qgep_ig.leve_precision AS TEXT
CONSTRAINT valid_leve_precision CHECK (
    VALUE IN ( 'releve', 'suppose', NULL )
);

CREATE DOMAIN qgep_ig.eau_type AS TEXT
CONSTRAINT valid_eau_type CHECK (
    VALUE IN ( 'eaux_claires', 'eaux_mixtes_deversees', 'eaux_cours_d_eau', 'eaux_pluviales', 'eaux_mixtes', 'eaux_industrielles', 'eaux_usees', 'inconnu', 'autre', NULL )
);

CREATE TABLE qgep_ig.leve_conduite_lineaire (
	id serial primary key,
	identifiant character varying (20),
    leve_precision qgep_ig.leve_precision,
	date_leve date,
	type_eau qgep_ig.eau_type,
	no_de_commune integer, -- lien vers table owner?
	employe varchar(50),
	materiau varchar(50),
	diametre_largeur numeric,
	hauteur numeric,
	forme varchar(50),
	fonction_hierarchique varchar(50),
	fonction_hydraulique varchar(50)
);
select AddGeometryColumn('qgep_ig','leve_conduite_lineaire', 'geom', 2056, 'Linestring', 3);

CREATE TABLE qgep_ig.leve_conduite (
	id serial primary key,
	no_point character varying (20),
    leve_precision qgep_ig.leve_precision,
	date_leve date,
	type_eau qgep_ig.eau_type,
	no_de_commune integer, -- lien vers table owner?
	employe varchar(50),
	materiau varchar(50),
	diametre_largeur numeric,
	hauteur numeric,
	forme varchar(50),
	fonction_hierarchique varchar(50),
	fonction_hydraulique varchar(50)
);
select AddGeometryColumn('qgep_ig','leve_conduite', 'geom', 2056, 'Point', 3);

CREATE TABLE qgep_ig.leve_chambre (
	id serial primary key,
	no_point character varying (20),
	date_leve date,
	no_de_commune integer, -- lien vers table owner?
	employe varchar(50),
	type_eau qgep_ig.eau_type,
	entree1_profondeur numeric,
	entree1_materiau character varying(50),
	entree1_diametre numeric,
	entree2_profondeur numeric,
	entree2_materiau character varying(50),
	entree2_diametre numeric,
	entree3_profondeur numeric,
	entree3_materiau character varying(50),
	entree3_diametre numeric,
	entree4_profondeur numeric,
	entree4_materiau character varying(50),
	entree4_diametre numeric,
	sortie1_profondeur numeric,
	sortie1_materiau character varying(50),
	sortie1_diametre numeric,
	sortie2_profondeur numeric,
	sortie2_materiau character varying(50),
	sortie2_diametre numeric
);
select AddGeometryColumn('qgep_ig','leve_chambre', 'geom', 2056, 'Point', 3);

/* Viewer */
GRANT USAGE ON SCHEMA qgep_ig  TO qgep_viewer;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA qgep_ig  TO qgep_viewer;
GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA qgep_ig  TO qgep_viewer;
ALTER DEFAULT PRIVILEGES IN SCHEMA qgep_ig GRANT SELECT, REFERENCES, TRIGGER ON TABLES TO qgep_viewer;


/* User */
GRANT ALL ON SCHEMA qgep_ig TO qgep_user;
GRANT ALL ON ALL TABLES IN SCHEMA qgep_ig TO qgep_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA qgep_ig TO qgep_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA qgep_ig GRANT ALL ON TABLES TO qgep_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA qgep_ig GRANT ALL ON SEQUENCES TO qgep_user;

/* Manager */
GRANT ALL ON ALL TABLES IN SCHEMA qgep_ig TO qgep_manager;


