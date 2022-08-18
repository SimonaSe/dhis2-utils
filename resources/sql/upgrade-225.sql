
-- 2.25 upgrade script

-- Add deleted column to datavalue table

-- This will be handled by DHIS 2, however running this script will be much faster in comparison for large datavalue tables

begin;

-- 1) Drop indexes and foreign keys

alter table datavalue drop constraint datavalue_pkey;
drop index in_datavalue_lastupdated;

-- 2) Add deleted column, set to false, set to not-null and create index

alter table datavalue add column deleted boolean;
update datavalue set deleted = false where deleted is null;
alter table datavalue alter column deleted set not null;
create index in_datavalue_deleted on datavalue(deleted);

-- 3) Recreate indexes and foreign keys

alter table datavalue add constraint datavalue_pkey primary key(dataelementid, periodid, sourceid, categoryoptioncomboid, attributeoptioncomboid);
create index in_datavalue_lastupdated on datavalue(lastupdated);

end;
