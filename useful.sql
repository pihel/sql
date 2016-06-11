--sql hist ---
select distinct v.FIRST_LOAD_TIME, U.MACHINE, v.sql_text
      from v$sql v, DBA_HIST_ACTIVE_SESS_HISTORY u
where to_date(v.FIRST_LOAD_TIME,'YYYY-MM-DD hh24:mi:ss')>ADD_MONTHS(trunc(sysdate,'MM'),-2)
and U.SQL_ID = V.SQL_ID
and v.PARSING_SCHEMA_NAME IN('BI_SA', 'BI_DWH')
and U.MACHINE <> 'ovs5s.sigma-it.local'
order by v.FIRST_LOAD_TIME desc;

----- tablespace size ----
select
   fs.tablespace_name                          "Tablespace",
   (df.totalspace - fs.freespace)              "Used MB",
   fs.freespace                                "Free MB",
   df.totalspace                               "Total MB",
   round(100 * (fs.freespace / df.totalspace)) "Pct. Free",
   round(SUM(df.totalspace - fs.freespace) OVER()/1024,2) as fl
from
   (select
      tablespace_name,
      round(sum(bytes) / 1048576) TotalSpace
   from
      dba_data_files
   group by
      tablespace_name
   ) df,
   (select
      tablespace_name,
      round(sum(bytes) / 1048576) FreeSpace
   from
      dba_free_space
   group by
      tablespace_name
   ) fs
where
   df.tablespace_name = fs.tablespace_name(+);


---- TEMP ---
   SELECT tablespace_name, SUM(bytes_used)/1024/1024/1024, SUM(bytes_free)
FROM   V$temp_space_header
GROUP  BY tablespace_name;

select s.sid||','||s.serial# as kill, s.osuser, s.username, u."USER", u.tablespace, u.contents, u.extents, u.blocks*vp.value/1024/1024 as mb
from   sys.v_$session s, sys.v_$sort_usage u, sys.v_$parameter vp
where  s.saddr = u.session_addr
and  vp.name = 'db_block_size'
order by mb desc;
   
------ LOCK ---

select SESSION_ID,ORACLE_USERNAME,OS_USER_NAME,session_id, 
a.object_id, xidsqn, oracle_username, b.owner owner,
b.object_name object_name, b.object_type object_type
FROM v$locked_object a, dba_objects b
WHERE xidsqn != 0
and b.object_id = a.object_id;

--- lock hist ---
SELECT  distinct a.sample_time, a.sql_id ,a.inst_id,a.blocking_session,a.blocking_session_serial#,a.user_id, u.username, a.module, s.sql_text
FROM  GV$ACTIVE_SESSION_HISTORY a  ,gv$sql s, dba_users u
where a.sql_id=s.sql_id
and u.user_id = a.user_id
--and blocking_session is not null
--and a.user_id <> 0 
and a.sample_time between TO_DATE('04.02.2016 23:50', 'dd.mm.yyyy hh24:mi') and TO_DATE('05.02.2016 00:05', 'dd.mm.yyyy hh24:mi')
order by a.sample_time desc;

--who lock
select --+rule
       do.object_name, do2.object_name as object_name2, s.INST_ID, s.SID, s.SERIAL#, s.USERNAME, s.STATUS, s.MACHINE , S.Osuser
  from gv$lock l, gv$session s , dba_objects do , dba_objects do2
 where l.INST_ID=s.INST_ID
   and l.TYPE='TO'
   and l.SID=s.SID
   and do.object_id(+) = l.id1
   and do2.object_id(+) = l.id2
   and l.id1 in (select o.object_id from dba_objects o 
                  where o.object_name IN( Upper('ETL_TARIF_EX'),Upper('ETL_TARIF_PT'),Upper('DIM_TARIF') ));

----- used memory
select (pga)/1024/1024 as "PGA"
from
(select sum(pga_alloc_mem) pga from v$process);--PGA_AGGREGATE_TARGET
exec dbms_session.free_unused_user_memory;

--- pga used ---
SELECT NVL(a.username,'(oracle)') AS username,
       a.module,
       a.program,
       Trunc(b.value/1024) AS memory_kb
FROM   v$session a,
       v$sesstat b,
       v$statname c
WHERE  a.sid = b.sid
AND    b.statistic# = c.statistic#
AND    c.name = 'session pga memory'
AND    a.program IS NOT NULL
ORDER BY b.value DESC;

--- tbs recomendations ---
SELECT   tablespace_name,
           segment_owner,
           segment_name,
           segment_type,
           round (allocated_space/1024/1024,2) "Allocated, Mb",
           round (used_space/1024/1024,2) "Used, Mb",
           round (reclaimable_space/1024/1024,2) "Reclaimable, Mb",
           recommendations,
           c1,
           c2,
           c3
    FROM   TABLE (DBMS_SPACE.asa_recommendations ())
  WHERE   segment_owner = 'BI_SA_TEST'
ORDER BY   reclaimable_space DESC;

---
--last analyz
SELECT * FROM DBA_AUTOTASK_CLIENT;
select temporary, last_analyzed, table_name from all_tables where owner = 'BI_SA_PSK' order by LAST_ANALYZED desc nulls last;

--params
select * from V$PARAMETER where name IN( 'hash_area_size', 'pga_aggregate_target', 'sort_area_size');

--- events stat --
SELECT a.event, a.WAIT_CLASS, a.average_wait ,round(a.TIME_WAITED_FG / SUM(a.TIME_WAITED_FG) over() * 100, 2)  as pct
   FROM sys.v_$system_event a
   where a.WAIT_CLASS NOT IN('Queueing', 'Idle', 'Other', 'Administrative', 'Application') and a.average_wait  > 0
   order by pct desc;
  
--- tbs size ---
select owner, TABLESPACE_NAME, segment_name, SUM(bytes)/1024/1024 as mb from dba_segments 
where TABLESPACE_NAME = 'BI_SA_PES' and owner = 'REPORTS_PES'
GROUP BY SEGMENT_NAME, TABLESPACE_NAME, owner
order by  mb desc;

select value from v$parameter where name = 'db_block_size' ;--8192
select num_rows, blocks*8192/1024/1024 as mb from SYS.ALL_TAB_SUBPARTITIONS WHERE TABLE_NAME = 'FCT_BYT_BAL_DT' order by num_rows desc;

---- sessions -----
SELECT count(*) over(), count(distinct sql_id) over() as cnt_rep, count(case when program='JDBC Thin Client' then 1 end) over() as cnt_sess,
 kill, exec_start, status, username, osuser, program, sql_id, txt FROM (
select 
s.sid||','||s.serial# as kill, s.status,
s.username, TO_CHAR(NVL(NVL(s.sql_exec_start, s.prev_exec_start),s.logon_time), 'YYYY-MM-DD HH24:MI:SS') exec_start,
s.schemaname, s.osuser, s.machine, s.program, s.module,
NVL(s.sql_id,s.prev_sql_id) as sql_id,
trim(NVL((select max(sql_text) from V$SQL q where q.sql_id = s.sql_id),
(select max(sql_text) from V$SQL q where q.sql_id = s.prev_sql_id) )) txt
FROM GV$SESSION s 
where ( s.sql_id IS NOT NULL OR s.prev_sql_id IS NOT NULL )
--AND s.OSUSER = 'askahin'
--AND s.schemaname = 'BI_SA_PSK'
and s.osuser NOT IN('oracle') --and s.program <> 'JDBC Thin Client' and s.module <> 'JDBC Thin Client' 
and s.program not like 'oracle@%(P%)'
)
where txt NOT IN( 
'begin :id := sys.dbms_transaction.local_transaction_id; end;',
'select sid, serial# from v$session where audsid = userenv(''SESSIONID'')',
'select value from v$sesstat where sid = :sid order by statistic#',
'select ''x'' from dual',
'SELECT 1 FROM DUAL')
order by osuser, exec_start desc;

alter system kill session '61,7229' immediate;

SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(sql_id => '2az2tp6wccj85', session_id =>2481, type=>'ACTIVE') from dual;

--- format plan ---
set linesize 180
set trimspool on
set pagesize 60
set serveroutput off
 
alter session set "_rowsource_execution_statistics"=true;
alter session set statistics_level=all;
 
select /*+ gather_plan_statistics */ * from user_tablespaces;
 
select * from table(dbms_xplan.display_cursor(null,null,'allstats last cost'));
