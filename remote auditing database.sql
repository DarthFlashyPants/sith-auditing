-- Create a remote pgsql db and execute this script against it to create
-- your "audit" table.


CREATE SEQUENCE public.next_gen_permissions_change_id_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE public.next_gen_permissions_change_id_seq
    OWNER TO <some pgsql user goes here>;

-- Table: public.next_gen_permissions_change in audit database

-- DROP TABLE public.next_gen_permissions_change;

CREATE TABLE public.next_gen_permissions_change
(
    id integer NOT NULL DEFAULT nextval('next_gen_permissions_change_id_seq'::regclass),
    authorizable_type character varying(64) ,
    authorizable_id integer,
    grantee_id integer,
    grantee_type character varying(255) ,
    capability_id integer NOT NULL,
    permission integer DEFAULT 0,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(10),
    CONSTRAINT "next_gen_permissionsPK" PRIMARY KEY (event_time, id)
)
WITH (
    OIDS = FALSE
)
;

ALTER TABLE public.next_gen_permissions_change
    OWNER to <some pgsql user goes here>;

GRANT ALL ON TABLE public.next_gen_permissions_change TO <some pgsql user goes here>;
