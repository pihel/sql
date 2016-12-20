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
WHERE ("STAT$BH".PCT>=1) and snap_date BETWEEN to_date('14.11.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and to_date('21.11.2016 00:00:00', 'dd.mm.yyyy hh24:mi:ss')
and "STAT$BH".OBJ_NAME like 'ZEINVOICE_DOC%'
group by "STAT$BH".SNAP_DATE, "STAT$BH".OBJ_NAME
ORDER BY "STAT$BH".SNAP_DATE, "STAT$BH".OBJ_NAME asc

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
