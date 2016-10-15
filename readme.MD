# Monitoring Tableau Security the Sith Way

![N|Solid](http://vignette2.wikia.nocookie.net/starwars/images/5/5b/SithCultist-TPOV.jpg/revision/latest?cb=20131007195906)

A paranoid Sith demands to know when someone changes the security permissions on his precious vizzes.  This is an example of one way to capture before/after permission modifications outside of Tableau.

### Warning

You are more foolish than a gang of Sand People making fun of Anakin's robes if you do this in production without SERIOUS thought

* You will need to figure how HOW to login as the admin PostgreSQL user for Tableau Server. I won't tell you how
* Using this technique is completely unsupported, and hacking the Tableau Repository puts you outside of support. The force must be strong in you to handle all eventualities of your meddling **on your own**.
* Mis-use of the trigger could actually PREVENT you from being able to change permissions on Tableau objects
* Storing the "saved" permissions inside Tableau's PostgreSQL might break Tableau's ability to backup the Server with tabadmin
* If you use this script, Donald Trump might get elected President. Us Sith would get a laugh out of that, but whatever

### Installation

1. Backup your Tableau Server, for God's sake! If you hose your server, do a COMPLETE uninstall (including ProgramData), re-install Tableau Server, and restore your backup. I'm **not kidding**
2. Create a database named "audit" or somesuch on a **remote* PostgreSQL instance or cluster
3. Run the contents of **remote auditing database.sql** inside that database to create a table to store before/after security results
4. Login to Tableau's PostgreSQL instance as tblwgadmin (the admin user).
5. Run the stuff in **tableau server.sql** to create a foreign data wrapper against the remote audit server, map the local Tableau 'rails' user to a remote user on the Audit instance, create a foreign table, trigger function, and bind the function to the next_gen_permissions table

### Had Enough?

Run the following on Tableau Server's PostgreSQL instance:

```
  -- Done with your mad science experiment? Run the following to
  -- Kill the trigger and trigger function, then CACSCADE drop the
  -- remote server. CASCADE will automatically remove the foreign table
  -- and mapped users.

DROP TRIGGER next_gen_permissions_audit ON next_gen_permissions;
DROP FUNCTION public.audit_permissions();
DROP SERVER myserver CASCADE;
```
