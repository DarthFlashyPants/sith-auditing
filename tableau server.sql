
/*************** Create foreign remote server  **************/
-- Run all of this stuff as the tblwgadmin (admin) user of Tableau.
-- You must figure out that password yourself. I can't help you.

CREATE EXTENSION postgres_fdw;
-- WARNING! Do NOT create a fdw against your local Tableau Server pgsql and then
-- attempt to run your audit database there. Doing so will likely break your ability
-- to backup Tableau Server with Tabadmin.

-- Enter remote server, database, and user information that should be used by Tableau's
-- Postgres to connect to your remote audit database. Tableau leverages local user 'rails'
-- so it must be mapped to a foreign user  in the audit database. That user must have
-- permissions on the remote audit table.
CREATE SERVER myserver FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '<remote host or ip>', dbname 'audit', port '5432');
CREATE USER MAPPING FOR rails SERVER myserver OPTIONS (user '<remote user>', password '<remote password>');

-- Tell Tableau's Postgres what the remote table in the audit database looks like.
CREATE foreign TABLE next_gen_permissions_change
(
  id serial NOT NULL,
  authorizable_type character varying(64),
  authorizable_id integer,
  grantee_id integer,
  grantee_type character varying(255),
  capability_id integer NOT NULL,
  permission integer DEFAULT 0,
  event_time timestamp without time zone,
  event_type character varying(10))
SERVER myserver;
GRANT ALL ON TABLE next_gen_permissions_change TO rails;

-- You can use this commented SQL to test whther the remote insert works. Don't proceed until it does.
-- Since you only have a user mapping with 'rails', you'll need to login as rails and/or
-- add another mapping.

/************************************************************
INSERT INTO next_gen_permissions_change(
            id, authorizable_type, authorizable_id, grantee_id, grantee_type,
            capability_id, permission, event_time, event_type)
    VALUES (2, 'Project', 2, 3, 'Group',
            45, 1, now(), 'delete');

************************************************************/


/*************** Create Trigger Function  **************/

-- This is the function which executes the INSERT into your remote
-- audit table. If you do anything to modify this function and it 'breaks',
-- then Tableau will NOT be able to save changes to the table you bind this
-- trigger to. You have been warned.

-- Function: public.audit_permissions()

-- DROP FUNCTION public.audit_permissions();

CREATE OR REPLACE FUNCTION public.audit_permissions()
  RETURNS trigger AS
$BODY$
DECLARE
    trigger_event_time timestamp;
BEGIN
    trigger_event_time := now();
    IF (TG_OP = 'INSERT') THEN
	INSERT INTO next_gen_permissions_change(
		    id,
		    authorizable_type,
		    authorizable_id,
		    grantee_id,
		    grantee_type,
		    capability_id,
		    permission,
		    event_time,
		    event_type)
	    VALUES (NEW.id,
		    NEW.authorizable_type,
		    NEW.authorizable_id,
		    NEW.grantee_id,
		    NEW.grantee_type,
		    NEW.capability_id,
		    NEW.permission,
		    trigger_event_time,
		    'insert');
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
            INSERT INTO next_gen_permissions_change(
		    id,
		    authorizable_type,
		    authorizable_id,
		    grantee_id,
		    grantee_type,
		    capability_id,
		    permission,
		    event_time,
		    event_type)
	    VALUES (OLD.id,
		    OLD.authorizable_type,
		    OLD.authorizable_id,
		    OLD.grantee_id,
		    OLD.grantee_type,
		    OLD.capability_id,
		    OLD.permission,
		    trigger_event_time,
		    'delete');
            RETURN OLD;
      ELSIF (TG_OP = 'UPDATE') THEN
           -- save both old row value..
            INSERT INTO next_gen_permissions_change(
		    id,
		    authorizable_type,
		    authorizable_id,
		    grantee_id,
		    grantee_type,
		    capability_id,
		    permission,
		    event_time,
		    event_type)
	    VALUES (OLD.id,
		    OLD.authorizable_type,
		    OLD.authorizable_id,
		    OLD.grantee_id,
		    OLD.grantee_type,
		    OLD.capability_id,
		    OLD.permission,
		    trigger_event_time,
		    'update-D');
	    -- and new row value
            INSERT INTO next_gen_permissions_change(
		    id,
		    authorizable_type,
		    authorizable_id,
		    grantee_id,
		    grantee_type,
		    capability_id,
		    permission,
		    event_time,
		    event_type)
	    VALUES (NEW.id,
		    NEW.authorizable_type,
		    NEW.authorizable_id,
		    NEW.grantee_id,
		    NEW.grantee_type,
		    NEW.capability_id,
		    NEW.permission,
		    trigger_event_time,
		    'update-I');
            RETURN NEW;
    END IF;

    RETURN null;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.audit_permissions()
  OWNER TO tblwgadmin;

/************************************************************/

 -- This binds the trigger to Tableau's nest_gen_permissions Table.
 -- After executing same, you should be good to go.

 CREATE TRIGGER next_gen_permissions_audit
 AFTER INSERT OR DELETE or UPDATE
 ON next_gen_permissions
 FOR EACH ROW
 EXECUTE PROCEDURE audit_permissions();

 /************************************************************/

  -- Done with your mad science experiment? Run the following to
  -- Kill the trigger and trigger function, then CACSCADE drop the
  -- remote server. CASCADE will automatically remove the foreign table
  -- and mapped users.

DROP TRIGGER next_gen_permissions_audit ON next_gen_permissions;
DROP FUNCTION public.audit_permissions();
DROP SERVER myserver CASCADE;
