
-- SQL script for moving data from one year to the next.
-- Useful for updating demo databases with sample data.

-- (Write) Move startdate and enddate in period to next year
-- Change the year to reflect the current time. Periods are
-- moved one year at the time to avoid unique constraint violations.

update period set
startdate = (startdate + interval '1 year')::date,
enddate = (enddate + interval '1 year')::date
where date_part('year', startdate)::int = 2020;

update period set
startdate = (startdate + interval '1 year')::date,
enddate = (enddate + interval '1 year')::date
where date_part('year', startdate)::int = 2019;

update period set -- Handle financial year data
startdate = (startdate + interval '1 year')::date,
enddate = (enddate + interval '1 year')::date
where date_part('year', startdate)::int = 2018;

-- (Write) Move programstageinstance

update programstageinstance set
duedate = (duedate + interval '1 year'),
executiondate = (executiondate + interval '1 year'),
completeddate = (completeddate + interval '1 year');

-- (Write) Move programinstance to next year

update programinstance set
incidentdate = (incidentdate + interval '1 year'),
enrollmentdate = (enrollmentdate + interval '1 year'),
enddate = (enddate + interval '1 year');

-- (Write) Move interpretations created / lastupdated to next year

update interpretation set created = (created + interval '1 year');
update interpretation set lastupdated = created;

-- (Write) Move favorite start/end dates to next year

update mapview set startdate = (startdate + interval '1 year') where startdate is not null;
update mapview set enddate = (enddate + interval '1 year') where enddate is not null;

update eventreport set startdate = (startdate + interval '1 year') where startdate is not null;
update eventreport set enddate = (enddate + interval '1 year') where enddate is not null;

update eventchart set startdate = (startdate + interval '1 year') where startdate is not null;
update eventchart set enddate = (enddate + interval '1 year') where enddate is not null;

-- (Write) Move date event values to next year

update trackedentitydatavalue set value = to_char((value::date + interval '1 year'), 'YYYY-MM-dd')
where dataelementid in (
  select dataelementid from dataelement where valuetype in ('DATE','DATETIME') and domaintype = 'TRACKER'
);


-- HAVING NAIVELY MOVED PERIOD DATES ONE YEAR FORWARD, WE NEED TO TWEAK THE DATES TO ALIGN PERIODS CORRECTLY

-- Deal with all of the start dates first, then adjust the end dates at the end.
-- Move the start day of all Weekly periods to Monday
UPDATE period
	SET startdate = startdate + 1 - cast(abs(extract(isodow from startdate)) as int)
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('Weekly');
-- Move the start day of all WeeklyWednesday periods to Wednesday
UPDATE period
	SET startdate = startdate + 3 - cast(abs(extract(isodow from startdate)) as int)
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('WeeklyWednesday');
-- Move the start day of all WeeklyThursday periods to Thursday
UPDATE period
	SET startdate = startdate + 4 - cast(abs(extract(isodow from startdate)) as int)
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('WeeklyThursday');
-- Move the start day of all WeeklySaturday periods to Saturday
UPDATE period
	SET startdate = startdate + 6 - cast(abs(extract(isodow from startdate)) as int)
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('WeeklySaturday');
-- Move the start day of all WeeklySunday periods to Sunday
UPDATE period
	SET startdate = startdate + 7 - cast(abs(extract(isodow from startdate)) as int)
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('WeeklySunday');
-- Set all weeks to one week long :)
UPDATE period
	SET enddate = to_char(startdate + interval '6 days', 'YYYY-MM-DD')::date
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('%Weekly%');
-- Ensure all months are correct length
-- Monthly
UPDATE period
	SET enddate = (period.startdate + (interval '1 month') - (interval '1 day'))::date
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('Monthly');
-- BiMonthly
UPDATE period
	SET enddate = (period.startdate + (interval '2 months') - (interval '1 day'))::date
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('BiMonthly');
-- SixMonthly
UPDATE period
	SET enddate = (period.startdate + (interval '6 months') - (interval '1 day'))::date
	FROM periodtype
 	WHERE period.periodtypeid = periodtype.periodtypeid AND periodtype.name LIKE ('SixMonthly%');

-- CHECK FOR DUPLICATES
SELECT * FROM period p
    WHERE (SELECT count(*) FROM period q
    WHERE concat(p.startdate,'-id-',p.periodtypeid) = concat(q.startdate,'-id-',q.periodtypeid)) > 1 ;



-- Vacuum to remove dead tuples

vacuum period;
vacuum programstageinstance;
vacuum programinstance;
vacuum interpretation;
vacuum mapview;
vacuum eventreport;
vacuum eventchart;
vacuum trackedentitydatavalue;
