--системная статистика
select * from sys.aux_stats$ order by pname;

---информация о биндах
select * from dba_hist_sqlbind where sql_id = 'drzsrsa1yg0w2' order by snap_id desc;

--изменился план
select PLAN_HASH_VALUE, min(begin_interval_time), max(begin_interval_time) enddt, sum(EXECUTIONS_DELTA), round(avg(drid),2), round(avg(buf_red),2), round(avg(phys_gb),2), round(avg(rws),2), round(avg(ELAPSED_TIME_DELTA),2), round(max(ELAPSED_TIME_DELTA),2) from (
  select s.snap_id, s.module, t.begin_interval_time, sql_id, PLAN_HASH_VALUE, nvl(nullif(EXECUTIONS_DELTA,0),1) EXECUTIONS_DELTA, round(DISK_READS_DELTA/nvl(nullif(EXECUTIONS_DELTA,0),1)) as drid, round(BUFFER_GETS_DELTA/nvl(nullif(EXECUTIONS_DELTA,0),1)) as buf_red, round(PHYSICAL_READ_BYTES_DELTA/nvl(nullif(EXECUTIONS_DELTA,0),1)/1024/1024/1024) as phys_gb, 
  round(case when END_OF_FETCH_COUNT_TOTAL = 1 then ROWS_PROCESSED_DELTA/nvl(nullif(EXECUTIONS_DELTA,0) ,1) end) as rws, round(s.ELAPSED_TIME_DELTA/nvl(nullif(EXECUTIONS_DELTA,0),1)/1000/1000,2) as ELAPSED_TIME_DELTA, nvl(nullif(EXECUTIONS_DELTA,0),1),OPTIMIZER_COST,IOWAIT_DELTA,
  round(IO_OFFLOAD_RETURN_BYTES_DELTA/1024/1024/1024,2) as off_gb  , round(IO_OFFLOAD_ELIG_BYTES_DELTA/1024/1024/1024,2) as eligb_gb
  from DBA_HIST_SQLSTAT s
  join DBA_HIST_SNAPSHOT t on t.snap_id = s.snap_id and t.INSTANCE_NUMBER = s.INSTANCE_NUMBER
  where 1=1
  and sql_id = 'ag392jrk23gyz' --a9pcaq33wwnv5 2wcq21jyta72u
)
group by PLAN_HASH_VALUE
order by enddt desc;

--top objects
select o.object_name, count(*) 
from dba_hist_active_sess_history h
left join dba_objects o on o.object_id = h.CURRENT_OBJ#
where sql_id = '5ddfgx1m41wp7' and sample_time > sysdate-1 
group by o.object_name;

--потребление undo
select s.MAXQUERYSQLID, MIN(s.begin_time), MAX(s.begin_time), COUNT(*) , SUM(UNDOBLKS) UNDOBLKS 
from DBA_HIST_UNDOSTAT s
where s.begin_time between to_date('06.12.2016', 'dd.mm.yyyy') and to_date('07.12.2016', 'dd.mm.yyyy')
and S.Instance_Number = 2
--and s.MAXQUERYSQLID = '3wb6bxh5rtdgd';
GROUP BY s.MAXQUERYSQLID;


--longops
select * from v$session_longops where sql_id = '7m20186kwff5g' order by start_time desc


--логические и физические чтения
select o.object_name, SUM(LOGICAL_READS_DELTA) as lg, SUM(PHYSICAL_READS_DELTA)  as ph
from DBA_HIST_SEG_STAT s
join SYS.dba_objects o on o.object_id = s.obj#
join DBA_HIST_SNAPSHOT n on n.snap_id = s.snap_id
where n.INSTANCE_NUMBER = 2
and n.BEGIN_INTERVAL_TIME BETWEEN to_date('19.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('26.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
group by o.object_name
order by lg desc;

--статистика по использованию буфера:
select * from DBA_HIST_BUFFER_POOL_STAT where instance_number = 2 order by snap_id desc;

--текущая статистика по таблицам в буфере
--vg$bh
SELECT "STAT$BH".SNAP_DATE, "STAT$BH".OBJ_NAME, avg("STAT$BH".PCT) as pct
FROM DBSNMP."STAT$BH" "STAT$BH"
WHERE ("STAT$BH".PCT>0) and snap_date BETWEEN to_date('16.12.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('24.12.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
and "STAT$BH".OBJ_NAME = 'MBEW'
group by "STAT$BH".SNAP_DATE, "STAT$BH".OBJ_NAME
ORDER BY "STAT$BH".SNAP_DATE desc, "STAT$BH".OBJ_NAME asc;

SELECT "STAT$BH".OBJ_NAME,  SUM("STAT$BH".BLOCKS) blks, avg("STAT$BH".PCT) as av_pct, MIN(snap_date), MAX(snap_date), Stddev("STAT$BH".PCT) as dev
FROM DBSNMP."STAT$BH" "STAT$BH"
WHERE snap_date BETWEEN  to_date('16.01.2017 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('24.01.2017 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
--and to_char(snap_date, 'hh24') between 9 and 18
group by "STAT$BH".OBJ_NAME
order by blks desc;

--статистика по событиям
DBA_HIST_SYSSTAT

--значения биндов:
select * from dba_hist_sqlbind where sql_id = '25ck8vp6d7djd' and snap_id = '16389'

----
-- ash index
with t as (select /*+ MATERIALIZE PARALLEL(8) */ t.sql_id, P.PLAN_HASH_VALUE,  trim(max(DBMS_LOB.SUBSTR (sql_text,4000))) as sql_text 
from SYS.DBA_HIST_SQL_PLAN p
join dba_hist_sqltext t on t.sql_id = p.sql_id 
where upper(t.sql_text) like '%VBRP%'
and p.object_name = 'VBRP~Z02'
group by t.sql_id, P.PLAN_HASH_VALUE )
select  h.sql_id, h.SQL_PLAN_HASH_VALUE, count(*) as cnt, max(sql_text)  sql_text
from dba_hist_active_sess_history h
join t on t.sql_id = h.sql_id and t.PLAN_HASH_VALUE = h.SQL_PLAN_HASH_VALUE
where h.sample_time between to_date('01.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('20.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
group by h.sql_id, h.SQL_PLAN_HASH_VALUE
order by cnt desc


--ash table
select sql_id, SQL_PLAN_HASH_VALUE, avg(secs) av_sec, max(sql_exec_start), sum(secs) secs, count(*) cnt, count(distinct sql_id || sql_exec_start) as execs, sum(gb) as av_gb, max(sql_text) from (
with t as (select /*+ MATERIALIZE PARALLEL(8) */ sql_id, trim(DBMS_LOB.SUBSTR (sql_text,4000)) sql_text from dba_hist_sqltext where upper(sql_text) like '%VTRDI%'  )
select  h.snap_id, h.module, h.sql_id, h.SQL_PLAN_HASH_VALUE, sql_exec_start, to_char(max(sample_time),'SSSSS') - to_char(sql_exec_start,'SSSSS')  as secs, SUM (DELTA_READ_IO_REQUESTS)/1000 as rds_k, 
SUM (delta_read_io_bytes)/1024/1024/1024 as gb, SUM(TM_DELTA_TIME)/1000/1000 TM_DELTA_TIME, SUM(TM_DELTA_CPU_TIME)/1000000 TM_DELTA_CPU_TIME, SUM(TM_DELTA_DB_TIME)/1000000  TM_DELTA_DB_TIME, max(sql_text)  sql_text
from dba_hist_active_sess_history h
join t on t.sql_id = h.sql_id
where h.sample_time between to_date('19.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('29.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
group by sql_exec_start, h.sql_id, h.module, h.SQL_PLAN_HASH_VALUE, h.snap_id
order by sql_exec_start desc
)
group by sql_id, SQL_PLAN_HASH_VALUE 
order by secs  desc nulls last;


---текущая статистика
select  h.client_id, h.SQL_PLAN_HASH_VALUE, h.module, sql_exec_start, h.sql_id, h.SQL_PLAN_HASH_VALUE, to_char(max(sample_time),'SSSSS') - to_char(sql_exec_start,'SSSSS')  as secs, count(distinct sql_exec_id), count(*) cnt, SUM (delta_read_io_bytes)/1024/1024/1024 as gb, sum(h.delta_read_io_requests)/1000 as kreg
FROM   gv$active_session_history h
--FROM dba_hist_active_sess_history h
where 1=1
and h.sql_id IN( '4dx7usj8n0ubc' )--7wkb3zz6rfncs
--and h.module = 'ZMM_STOCK_MI'
--and h.sample_time > trunc(sysdate-5)
group by h.sql_id, h.SQL_PLAN_HASH_VALUE, sql_exec_start, module, h.client_id, h.SQL_PLAN_HASH_VALUE
order by sql_exec_start desc nulls last;


----- ash long ---
select max(module) KEEP (DENSE_RANK FIRST ORDER BY execs desc) as module, sql_id, min(sql_exec_start), max(sql_exec_start), max(SQL_PLAN_HASH_VALUE), sum(execs), sum(gb) as gb, round(avg(secs),2) as av_sec, sum(secs) secs, sum(smpl) smpl, max(txt) from 
(
  select h.sql_exec_start, h.module, h.sql_id, h.SQL_PLAN_HASH_VALUE, count(distinct sql_exec_id) as execs,  SUM (delta_read_io_bytes)/1024/1024/1024 as gb, 
  to_char(max(sample_time),'SSSSS') - to_char(sql_exec_start,'SSSSS')  as secs, count(*) as smpl,
  max( trim(DBMS_LOB.SUBSTR (t.sql_text,400)) ) as txt--789
   FROM   dba_hist_active_sess_history h 
  left join dba_hist_sqltext t on t.sql_id = h.sql_id
  where 
  --h.sample_time between to_date('19.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('26.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
  h.sample_time between to_date('26.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('03.10.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
  and h.sql_id is not null--5bt5hghr7dpg8
  --and h.module ='ZRE_MATRIX'
  group by h.sql_id, h.SQL_PLAN_HASH_VALUE, h.module, h.sql_exec_start
)
group by sql_id
order by smpl desc nulls last;

  
--awr plan
select * from table(DBMS_XPLAN.DISPLAY_AWR('8t69uza8uc300', '381928396') ); --bad
select * from table(DBMS_XPLAN.DISPLAY_AWR('8t3q9hfh6ddtx', '1661341798', null, 'basic +outline +peeked_binds') ); --bad
  


--stat diff
select * from table(dbms_stats.diff_table_stats_in_history(
                    ownname => 'ISCS',
                    tabname => upper('PO_BALANCE_TEMP'),
                    time1 => systimestamp,
                    time2 => sysdate-3,
                    pctthreshold => 5));  
select * from DBA_TAB_STATS_HISTORY where table_name = 'PROCESSSKU' order by STATS_UPDATE_TIME desc;


---- set stat
BEGIN
  DBMS_STATS.set_column_stats( ownname => 'STSC', tabname => 'PROCESSSKU', colname => 'BATCHNUM', distcnt => 20000, density => 1/20000, force=>true);
  DBMS_STATS.SET_INDEX_STATS (
   ownname       => 'STSC', 
   indname       => 'PROCESSSKU_BATCH',
   numdist       => 20000, 
   force         => true);
  
  --select count( distinct BATCHNUM ||  SKULEVEL || PROCESSID) from ISCS.PROCESSSKU_07112016;
  DBMS_STATS.SET_INDEX_STATS (
   ownname       => 'STSC', 
   indname       => 'PROCESS_BATCHLEVEL',
   numdist       => 20000, 
   force         => true); 
   
END;

--restore stat
begin
dbms_stats.restore_table_stats('STSC','PROCESSSKU', to_timestamp('02.09.16 15:03:55','dd.mm.yy hh24:mi:ss'), force=>true);
end;


--- user info ---
select to_char(h.sample_time, 'dd hh24'), h.module, h.client_id,  count(*) as cnt
FROM   dba_hist_active_sess_history h 
where 
h.sample_time > sysdate -10
  and  h.module is not null
  and h.sql_id  = '7ty2hyx3p41vb'
group by  h.module, h.client_id, to_char(h.sample_time, 'dd hh24')
order by cnt desc;


--строка по блоку и номеру строки в блоке
select * from REPOSRC
where SYS.dbms_rowid.rowid_block_number(rowid) = 175712 and SYS.dbms_rowid.rowid_row_number(rowid) = 5

  
---- top blockers ?? ---
select  h.BLOCKING_SESSION, h.BLOCKING_SESSION_SERIAL# , h2.client_id, h2.MODULE, h2.sql_id,  COUNT(DISTINCT h.SESSION_ID || ';' ||  h.SESSION_SERIAL#) SESSIONS_CNT , count(DISTINCT h.sample_id) as samples, max( trim(DBMS_LOB.SUBSTR (t.sql_text,4000)) )
FROM   dba_hist_active_sess_history h 
join dba_objects o on o.object_id = h.CURRENT_OBJ#
left join dba_hist_active_sess_history h2 on h2.SESSION_ID = h.BLOCKING_SESSION and h2.SESSION_SERIAL# = h.BLOCKING_SESSION_SERIAL# 
  and h2.sample_time between to_date('2016-06-28 15:00:00', 'yyyy-mm-dd hh24:mi:ss') and to_date('2016-06-28 15:50:00', 'yyyy-mm-dd hh24:mi:ss')
  and h2.snap_id = h.snap_id and h2.SAMPLE_ID = h.SAMPLE_ID
  and h.sample_time between H.Sql_Exec_Start and h2.sample_time
left join dba_hist_sqltext t on t.sql_id = h2.sql_id
where 
h.sample_time between to_date('2016-06-28 15:20:00', 'yyyy-mm-dd hh24:mi:ss') and to_date('2016-06-28 15:35:00', 'yyyy-mm-dd hh24:mi:ss')
and h.EVENT = 'enq: TX - row lock contention'
and o.object_name = 'NRIV'
--and h.TIME_WAITED > 0
group by h2.client_id, h2.MODULE, h2.sql_id, h.BLOCKING_SESSION, h.BLOCKING_SESSION_SERIAL#
having count(*) > 1
order by samples desc;

--- bhr, ph, log read
select s.begin_time, s.average 
from DBA_HIST_SYSMETRIC_SUMMARY  s
where s.begin_time between to_date('19.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('26.09.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
and S.INSTANCE_NUMBER = 2
--and metric_name = 'Logical Reads Per Sec'
and metric_name = 'Buffer Cache Hit Ratio'
--'Physical Reads Per Sec'
order by s.begin_time desc;

--fix plan
declare
v_sql clob;
v_sql_id varchar2(50) := '4tnwd1jzxvxm1';
v_name varchar2(50) := 'ZSD_PRICE_HISTOR';
begin
select sql_text into v_sql from dba_hist_sqltext where sql_id = v_sql_id and rownum = 1;
dbms_sqltune.import_sql_profile(
  name => v_name || '_' || v_sql_id,
  sql_text => v_sql,
  profile => sqlprof_attr('NO_PARALLEL', 'FULL(PRC@SEL$1)'),
  replace => TRUE,
  force_match => TRUE
);
end;


--- flush cache
select ADDRESS, HASH_VALUE from V$SQLAREA where SQL_ID like '7yc%';
exec DBMS_SHARED_POOL.PURGE ('000000085FD77CF0, 808321886', 'C');
ALTER SYSTEM FLUSH SHARED_POOL;

--- format current plan ---
set linesize 180
set trimspool on
set pagesize 60
set serveroutput off
 
alter session set "_rowsource_execution_statistics"=true;
alter session set statistics_level=all;
 
select /*+ gather_plan_statistics */ * from user_tablespaces;
 
select * from table(dbms_xplan.display_cursor(null,null,'allstats last cost'));

--session rollback /undo usage
select
        tr.start_scn, tr.log_io, tr.phy_io, tr.used_ublk, tr.used_urec, recursive
from
        v$session       se,
        V$transaction   tr
where
        se.sid = 1213
and     tr.ses_addr = se.saddr
;


---cancel sess
begin
sys.dbms_system.set_ev(2454,24463, 10237, 1, '');
end;


---sid statistics
select N.DISPLAY_NAME, SUM(s.value) as val from v$sesstat s
join v$statname n on S.STATISTIC# = N.STATISTIC# 
where s.sid = 1213
group by N.DISPLAY_NAME
order by val desc nulls last;

----

--not used index
select /*+ parallel(8) */ i.index_name, i.TABLE_NAME, round( i.NUM_ROWS / 1000 / 1000, 2) as rows_m, 
  ROUND( (NVL(m.INSERTS,0) + nvl(m.UPDATES,0) + nvl(m.DELETES,0)) / 1000 / 1000, 2) as dml_m --число dml
  , t.LAST_ANALYZED
FROM (
  select index_name from dba_indexes where owner = 'SAPSR3'
  minus
  select DISTINCT p.OBJECT_NAME
  from dba_hist_active_sess_history h
  join SYS.DBA_HIST_SQL_PLAN p on h.sql_id = p.sql_id and P.PLAN_HASH_VALUE = h.SQL_PLAN_HASH_VALUE and h.SQL_PLAN_LINE_ID = p.id
  where h.sample_time >= to_date('01.12.2016', 'dd.mm.yyyy')
  and p.OBJECT_TYPE = 'INDEX'
) o
join dba_indexes i on i.index_name = o.index_name and i.owner = 'SAPSR3'
left join dba_tables t on t.owner = 'SAPSR3' AND t.table_name = i.TABLE_NAME
left join dba_tab_modifications m on m.table_owner = 'SAPSR3' AND m.table_name = i.TABLE_NAME
order by i.NUM_ROWS desc nulls last;

----

--real top by sec?
with s as ( 
  SELECT /*+ MATERIALIZE */ sql_id, ELAPSED_TIME_DELTA, rn, sec_exec, CPU_TIME_DELTA, IOWAIT_DELTA, EXECUTIONS_DELTA FROM (
    select s.sql_id,  round( SUM(s.ELAPSED_TIME_DELTA)/1000/1000) ELAPSED_TIME_DELTA, 
        round(SUM(s.ELAPSED_TIME_DELTA) / nvl(nullif(sum(EXECUTIONS_DELTA),0) ,1) / 1000/1000,2) as sec_exec,
        ROW_NUMBER() OVER(order by SUM(s.ELAPSED_TIME_DELTA) desc nulls last) as  rn,
        SUM(s.CPU_TIME_DELTA) CPU_TIME_DELTA, SUM(s.IOWAIT_DELTA) IOWAIT_DELTA, sum(EXECUTIONS_DELTA) as EXECUTIONS_DELTA
    from DBA_HIST_SQLSTAT s
    join DBA_HIST_SNAPSHOT t on t.snap_id = s.snap_id and t.INSTANCE_NUMBER = s.INSTANCE_NUMBER
    where t.BEGIN_INTERVAL_TIME between to_date('23.01.2017', 'dd.mm.yyyy hh24:mi:ss') and to_date('30.01.2017', 'dd.mm.yyyy hh24:mi:ss')
    and to_char(t.BEGIN_INTERVAL_TIME, 'hh24') between 10 and 12
    GROUP BY s.sql_id
  ) WHERE rn <= 15
)
select s.sql_id, s.ELAPSED_TIME_DELTA as sec, s.sec_exec, s.EXECUTIONS_DELTA, s.CPU_TIME_DELTA, s.IOWAIT_DELTA, trim( DBMS_LOB.SUBSTR(t.sql_text,1000) ) as txt 
from s
left join dba_hist_sqltext t on t.sql_id = s.sql_id
order by s.rn;

--now
select  max(h.client_id), max(h.program), max(h.module),  h.sql_id, h.SQL_PLAN_HASH_VALUE, 
min(sql_exec_start), max(sample_time), count(*)/5 cnt, max(s.SQL_TEXT) as sql_text
FROM   gv$active_session_history h
left join v$sql s on s.sql_id = h.sql_id
where h.sample_time > trunc(sysdate, 'hh')
group by  h.sql_id, h.SQL_PLAN_HASH_VALUE
order by cnt desc nulls last;

-- table stat
select * FROM TABLE(DBMS_SPACE.OBJECT_SPACE_USAGE_TBF('SAPSR3', 'WALE', 'TABLE', NULL))

--- tablse size history
select n.BEGIN_INTERVAL_TIME, S.Space_Allocated_Total, S.Space_Used_Total
from DBA_HIST_SEG_STAT s
join SYS.dba_objects o on o.object_id = s.obj#
join DBA_HIST_SNAPSHOT n on n.snap_id = s.snap_id
where n.INSTANCE_NUMBER = 2
and n.BEGIN_INTERVAL_TIME BETWEEN to_date('20.01.2017 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('27.01.2017 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
and o.object_name = '/SCDL/DB_PROCI_I'
order by n.BEGIN_INTERVAL_TIME desc;

--time line??? --не получается
select SQL_PLAN_LINE_ID, avg(st_sec), max(avg(fl_sec)) OVER() from (
  select sql_exec_start, sql_exec_id, nvl( SQL_PLAN_LINE_ID, 0) SQL_PLAN_LINE_ID, (to_char(MIN(sample_time),'SSSSS') - to_char(sql_exec_start,'SSSSS')) as st_sec,
  (to_char( MAX(MAX(sample_time)) OVER(partition by sql_exec_start, sql_exec_id),'SSSSS') - to_char(sql_exec_start,'SSSSS')) as fl_sec
  FROM   dba_hist_active_sess_history h
  where 
  h.sample_time between to_date('10.01.2017', 'dd.mm.yyyy') and to_date('04.02.2017', 'dd.mm.yyyy')
  and h.sql_id = 'apkfgg9mhp7qu' AND h.SQL_PLAN_HASH_VALUE = '4180994369'
  and trunc(sample_time) = trunc(sql_exec_start)
  group by nvl( SQL_PLAN_LINE_ID, 0), sql_exec_start, sql_exec_id
)
group by SQL_PLAN_LINE_ID
order by SQL_PLAN_LINE_ID;