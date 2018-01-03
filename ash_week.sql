--системная статистика
select * from sys.aux_stats$ order by pname;

---информация о биндах
select * from dba_hist_sqlbind where sql_id = 'drzsrsa1yg0w2' order by snap_id desc;
select * from v$sql_bind_capture
 

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
where s.begin_time between to_date('18.09.2017', 'dd.mm.yyyy') and to_date('20.09.2017', 'dd.mm.yyyy')
and s.MAXQUERYSQLID = '26zb33hqtus2f'
GROUP BY s.MAXQUERYSQLID
order by UNDOBLKS;

select s.MAXQUERYSQLID, trunc(s.begin_time, 'hh24') as hh, COUNT(*) , SUM(UNDOBLKS) UNDOBLKS 
from DBA_HIST_UNDOSTAT s
where s.begin_time between to_date('18.09.2017', 'dd.mm.yyyy') and to_date('20.09.2017', 'dd.mm.yyyy')
GROUP BY s.MAXQUERYSQLID, trunc(s.begin_time, 'hh24')
order by hh, UNDOBLKS desc;

--потребление undo
select *
from DBA_HIST_UNDOSTAT s
where s.begin_time between to_date('18.09.2017', 'dd.mm.yyyy') and to_date('20.09.2017', 'dd.mm.yyyy')
and s.MAXQUERYSQLID = '26zb33hqtus2f'


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
select space_used, space_allocated, chain_pcent, round(space_allocated/space_used*100,2) as pct FROM TABLE(DBMS_SPACE.OBJECT_SPACE_USAGE_TBF('SAPSR3', '/1CADMC/00000347IU', 'INDEX', NULL))

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
  procedure fix_plan(v_sql_id varchar2, v_name varchar2, v_profile sqlprof_attr) is
    v_sql clob;
  begin
    begin
    select sql_text into v_sql from dba_hist_sqltext where sql_id = v_sql_id and rownum < 2;
    exception when others then
      select SQL_FULLTEXT into v_sql from gv$sql where sql_id = v_sql_id and rownum < 2;
    end;
    
    dbms_sqltune.import_sql_profile(
      name => v_name || '_' || v_sql_id,
      sql_text => v_sql,
      profile => v_profile,
      replace => TRUE,
      force_match => TRUE
    );
  end; 
begin

fix_plan('bb6p2ur73c6xm', 'ZMATRIX', sqlprof_attr('INDEX(MARA@SEL$1, "MARA~L")'));
fix_plan('7m0uwxffqwm04', 'ZMATRIX', sqlprof_attr('INDEX(MARA@SEL$1, "MARA~L")'));
fix_plan('c5cvm3624ufph', 'ZONL_SLS', sqlprof_attr('use_nl(ZRE_ONLINE_SALES@SEL$1, MARA@SEL$1)'));
fix_plan('5s6r6nswyk40b', 'WSM3', sqlprof_attr('index(MARA@SEL$1 "MARA~O")','index(MARA@SEL$1 "MARA~0")','use_concat'));

end;
--fix plan



--- flush cache
select ADDRESS, HASH_VALUE from V$SQLAREA where SQL_ID like '0j0vrzsvb6xjv';
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
  minus
  select p.object_name from v$sql_plan p 
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

--число модификаций таблицы
insert into tmp$modif
select * from ALL_TAB_MODIFICATIONS WHERE TABLE_NAME IN('A959', 'A018', 'A929', 'A073', 'A071');

select v.table_name, min(TIMESTAMP) as st_dt, max(TIMESTAMP) as ed_dt , sum(delta_del) delta_del, sum(delta_ins) as delta_ins, sum(delta_upd) delta_upd, 
round(avg(delta_del/delta_min)) as del_per_min, round(avg( delta_ins/delta_min)) as ins_per_min, round(avg(delta_upd/delta_min)) as upd_per_min, max(t.NUM_ROWS) as NUM_ROWS
from (
select f.table_name, f.TIMESTAMP, F.DELETES, F.INSERTS, F.UPDATES, 
  round((f.TIMESTAMP - lag(f.TIMESTAMP) over(partition by f.table_name order by f.TIMESTAMP)) *24,2) as delta_min,
  f.DELETES - lag(f.DELETES) over(partition by f.table_name order by f.TIMESTAMP) as delta_del,
  f.INSERTS - lag(f.INSERTS) over(partition by f.table_name order by f.TIMESTAMP) as delta_ins,
  f.UPDATES - lag(f.UPDATES) over(partition by f.table_name order by f.TIMESTAMP) as delta_upd
from tmp$modif f
) v
join dba_tables t on t.table_name = v.table_name
where delta_min is not null
group by v.table_name
order by table_name;

--история использования целов в exadata
select * from V$CELL_THREAD_HISTORY where length(trim(sql_id)) > 1 order by snapshot_time desc

--- kill session
begin
  for i IN(
    select * from v$session where sql_id = 'b8wmkkdcnrku9'
  ) loop
    execute immediate('ALTER SYSTEM KILL SESSION '''||i.sid||',' ||i.serial#||'''');
  end loop;
end;

---топ sql запросов на объекте по числу чтений
select h.sql_id, sum(H.DELTA_READ_IO_BYTES) as DELTA_READ_IO_BYTES, 
ROUND(SUM( DELTA_READ_IO_BYTES) / SUM(SUM( DELTA_READ_IO_BYTES)) OVER() * 100,2) as read_prc, max(DBMS_LOB.SUBSTR (t.sql_text,2000)) as SQL_TEXT
 FROM   dba_hist_active_sess_history h
 join SYS.DBA_HIST_SQL_PLAN p on h.sql_id = p.sql_id and h.SQL_PLAN_HASH_VALUE = p.PLAN_HASH_VALUE and p.id = h.SQL_PLAN_LINE_ID
 left join dba_hist_sqltext t on t.sql_id = h.sql_id
      where 
      h.sample_time between to_date('14.08.2017', 'dd.mm.yyyy hh24:mi:ss') and to_date('25.08.2017', 'dd.mm.yyyy hh24:mi:ss')
      and p.object# = 48750
      and h.sql_id is not null
group by h.sql_id
order by DELTA_READ_IO_BYTES desc nulls last;

--статистика времени чтений
select dt, 
  avg(case when EVENT_NAME = 'cell single block physical read' then  WAIT_AVG end) as singl_ph_rd,
  avg(case when EVENT_NAME = 'cell list of blocks physical read' then  WAIT_AVG end) as list_ph_rd,
  avg(case when EVENT_NAME = 'cell multiblock physical read' then  WAIT_AVG end) as multy_ph_rd
from (
  select trunc(t.BEGIN_INTERVAL_TIME, 'hh') as dt, EVENT_NAME, 
    round(sum(case when WAIT_TIME_MILLI = 1 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_1,
    round(sum(case when WAIT_TIME_MILLI = 2 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_2,
    round(sum(case when WAIT_TIME_MILLI = 4 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_4,
    round(sum(case when WAIT_TIME_MILLI = 8 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_8,
    round(sum(case when WAIT_TIME_MILLI = 16 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_16,
    round(sum(case when WAIT_TIME_MILLI = 32 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_32,
    round(sum(case when WAIT_TIME_MILLI = 64 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_64,
    round(sum(case when WAIT_TIME_MILLI = 128 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_128,
    round(sum(case when WAIT_TIME_MILLI = 256 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_256,
    round(sum(case when WAIT_TIME_MILLI = 512 then WAIT_COUNT end)/sum(WAIT_COUNT)*100,2) as WAIT_512,
    ROUND(SUM(WAIT_COUNT  * WAIT_TIME_MILLI) / SUM(WAIT_COUNT),2) as WAIT_AVG
  from DBA_HIST_EVENT_HISTOGRAM h
  join DBA_HIST_SNAPSHOT t on t.snap_id = h.snap_id and t.INSTANCE_NUMBER = h.INSTANCE_NUMBER
  where h.event_name IN('cell single block physical read', 'cell list of blocks physical read', 'cell multiblock physical read') 
  and  t.BEGIN_INTERVAL_TIME between to_date('20.11.2017', 'dd.mm.yyyy hh24:mi:ss') and to_date('30.12.2017', 'dd.mm.yyyy hh24:mi:ss')
  group by trunc(t.BEGIN_INTERVAL_TIME, 'hh'), EVENT_NAME
  order by dt, EVENT_NAME
)
group by dt
order by dt;

--профили
select * FROM   DBA_SQL_PROFILES order by created desc;

--table locks
select l.*, o.object_name, s.client_identifier, s.client_info, s.SQL_ID, substr(q.sql_text,1,250) as sql_text, s.prev_sql_id, substr(q1.sql_text,1,250) as sql_text_prev,
ROW_WAIT_OBJ#,ROW_WAIT_FILE#,ROW_WAIT_BLOCK#,ROW_WAIT_ROW#
from v$locked_object l
join dba_objects o on o.object_id = l.object_id
join v$session s on s.sid = l.session_id
left join v$sql q on q.sql_id = s.SQL_ID
left join v$sql q1 on q1.sql_id = s.prev_sql_id
where xidsqn != 0;

---temp and pga use
select sql_exec_start, SQL_ID, max(sample_time) as sample_time, sum(DELTA_PGA_MB) PGA_MB, SUM(DELTA_TEMP_MB) as TEMP_MB
from
(
select SESSION_ID,SESSION_SERIAL#,sample_id,SQL_ID,SAMPLE_TIME,IS_SQLID_CURRENT,SQL_CHILD_NUMBER,PGA_ALLOCATED,
greatest(PGA_ALLOCATED - first_value(PGA_ALLOCATED) over (partition by SESSION_ID,SESSION_SERIAL# order by sample_time rows 1 preceding),0)/power(1024,2) "DELTA_PGA_MB",
greatest(temp_space_allocated - first_value(temp_space_allocated) over (partition by SESSION_ID,SESSION_SERIAL# order by sample_time rows 1 preceding),0)/power(1024,2) "DELTA_TEMP_MB",
sql_exec_start
from
dba_hist_active_sess_history
where sql_id = '7gtrsyx9g50fj' and
IS_SQLID_CURRENT='Y'
order by 1,2,3,4
)
group by sql_id, sql_exec_start
order by sample_time desc;

---замена биндов:
set serveroutput on;
declare 
v_ret clob;
begin
dbms_output.enable(10000);
select sql_text into v_ret from dba_hist_sqltext t where sql_id = 'b8kt5qg0r02af';
for i in(select  NAME, VALUE_STRING from dba_hist_sqlbind where sql_id = 'b8kt5qg0r02af' and last_captured <= sysdate order by last_captured desc) loop
v_ret := replace(v_ret, i.name||' ', ''''||i.VALUE_STRING||''' ');
end loop;
DBMS_OUTPUT.PUT_LINE(v_ret);
end;