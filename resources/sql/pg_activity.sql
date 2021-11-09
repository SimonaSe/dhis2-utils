
--
-- PostgreSQL queries for monitoring performance, slow queries and locks.
--
-- Enable sloq query logging in postgresql.conf:
--
-- log_statement = none
-- log_min_duration_statement = 200
--
-- Increase size of captured query:
--
-- track_activity_query_size = 8192
--

-- Current queries

select pid, datname, usename, query_start, now() - pg_stat_activity.query_start as duration, state, query 
from pg_catalog.pg_stat_activity 
where state != 'idle' 
and query not ilike '%pg_stat_activity%';

-- Count of current queries

select count(*) 
from pg_catalog.pg_stat_activity 
where state != 'idle' 
and query not ilike '%pg_stat_activity%';

-- Last queries

select pid, datname, usename, query_start, now() - pg_stat_activity.query_start as duration, state, query 
from pg_catalog.pg_stat_activity 
where query not ilike '%pg_stat_activity%';

-- Count of last queries

select count(*) 
from pg_catalog.pg_stat_activity 
where query not ilike '%pg_stat_activity%';

-- Queries running for more than 5 seconds

select pid, datname, usename, query_start, now() - pg_stat_activity.query_start as duration, state, query 
from pg_catalog.pg_stat_activity 
where (now() - pg_stat_activity.query_start) > interval '5 seconds' 
and state != 'idle' 
and query not ilike '%pg_stat_activity%';

-- Count of queries running for more than 5 seconds

select count(*) 
from pg_catalog.pg_stat_activity 
where (now() - pg_stat_activity.query_start) > interval '5 second' 
and state != 'idle' 
and query not ilike '%pg_stat_activity%';

-- Queries running for more than 1 minute

select pid, datname, usename, query_start, now() - pg_stat_activity.query_start as duration, state, query 
from pg_catalog.pg_stat_activity 
where (now() - pg_stat_activity.query_start) > interval '1 minutes' 
and state != 'idle' 
and query not ilike '%pg_stat_activity%';

-- Count of queries running for more than 1 minutes

select count(*) 
from pg_catalog.pg_stat_activity 
where (now() - pg_stat_activity.query_start) > interval '1 minutes' 
and state != 'idle' 
and query not ilike '%pg_stat_activity%';

-- Count of queries by time interval

with cte_activity as (
  select *
  from pg_catalog.pg_stat_activity 
  where state != 'idle' 
  and query not ilike '%pg_stat_activity%'
)
select 'query_gt_1ms' as "time_interval", count(*) from cte_activity 
where (now() - cte_activity.query_start) > interval '1 milliseconds'
union all select 'query_gt_100ms' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '100 milliseconds'
union all select 'query_gt_200ms' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '200 milliseconds'
union all select 'query_gt_500ms' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '500 milliseconds'
union all select 'query_gt_1s' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '1 seconds'
union all select 'query_gt_2s' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '2 seconds'
union all select 'query_gt_5s' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '5 seconds'
union all select 'query_gt_10s' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '10 seconds'
union all select 'query_gt_20s' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '20 seconds'
union all select 'query_gt_40s' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '40 seconds'
union all select 'query_gt_90s' as "time_interval", count(*) from cte_activity
where (now() - cte_activity.query_start) > interval '90 seconds';

-- Current locks

select pl.pid, pl.locktype, pl.mode, pl.granted, pa.datname, pa.client_addr, pa.query_start, pa.state, substring(pa.query for 1000)
from pg_catalog.pg_locks pl 
left join pg_stat_activity pa on pl.pid = pa.pid;

-- Locks older than 5 seconds

select pl.pid, pl.locktype, pl.mode, pl.granted, pa.datname, pa.client_addr, pa.query_start, pa.state, substring(pa.query for 1000)
from pg_catalog.pg_locks pl
left join pg_stat_activity pa on pl.pid = pa.pid
where (now() - pa.query_start) > interval '5 seconds';

-- Locks older than 10 minutes

select pl.pid, pl.locktype, pl.mode, pl.granted, pa.datname, pa.client_addr, pa.query_start, pa.state, substring(pa.query for 1000)
from pg_catalog.pg_locks pl
left join pg_stat_activity pa on pl.pid = pa.pid
where (now() - pa.query_start) > interval '10 minutes';

-- Count of locks

select count(*) 
from pg_catalog.pg_locks;

-- Count of connections

select sum(numbackends) 
from pg_stat_database;

-- Cancel query

select pg_cancel_backend(_pid_);

-- Terminate query

select pg_terminate_backend(_pid_);

-- Blocked and blocking activity

select blocked_locks.pid as blocked_pid, blocked_activity.usename as blocked_user, blocking_locks.pid as blocking_pid, 
    blocking_activity.usename as blocking_user, blocked_activity.query as blocked_statement, blocking_activity.query as current_statement_in_blocking_process
from pg_catalog.pg_locks blocked_locks
    join pg_catalog.pg_stat_activity blocked_activity on blocked_activity.pid = blocked_locks.pid
    join pg_catalog.pg_locks blocking_locks on blocking_locks.locktype = blocked_locks.locktype
        and blocking_locks.database is not distinct from blocked_locks.database
        and blocking_locks.relation is not distinct from blocked_locks.relation
        and blocking_locks.page is not distinct from blocked_locks.page
        and blocking_locks.tuple is not distinct from blocked_locks.tuple
        and blocking_locks.virtualxid is not distinct from blocked_locks.virtualxid
        and blocking_locks.transactionid is not distinct from blocked_locks.transactionid
        and blocking_locks.classid is not distinct from blocked_locks.classid
        and blocking_locks.objid is not distinct from blocked_locks.objid
        and blocking_locks.objsubid is not distinct from blocked_locks.objsubid
        and blocking_locks.pid != blocked_locks.pid
    join pg_catalog.pg_stat_activity blocking_activity on blocking_activity.pid = blocking_locks.pid
where not blocked_locks.granted;

-- Show performance related settings

select version();
show max_connections; 
show shared_buffers; 
show work_mem; 
show maintenance_work_mem; 
show effective_cache_size; 
show checkpoint_completion_target; 
show synchronous_commit; 
show wal_writer_delay;
show random_page_cost;

-- Enable full logging

alter system set log_statement = 'all';
select pg_reload_conf();
show log_statement;

-- Enable slow query logging (in ms)

alter system set log_statement = 'ddl';
alter system set log_min_duration_statement = 500;
select pg_reload_conf();
show log_statement;
show log_min_duration_statement;

-- Disable logging

alter system set log_statement = 'none';
alter system set log_min_duration_statement = -1;
select pg_reload_conf();
show log_statement;

-- List tables by size

select table_name, pg_relation_size(quote_ident(table_name))
from information_schema.tables
where table_schema = 'public'
order by 2 desc;


