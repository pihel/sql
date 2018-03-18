--- виды преобразований запросов ---

* attribute clustering: https://blogs.oracle.com/datawarehousing/entry/optimizing_queries_with_attribute_clustering
 упорядочивание данных согласно какогото индекса - аналог order by, но делается автоматически
 ALTER TABLE sales_ac ADD CLUSTERING BY LINEAR ORDER (customer_id) WITHOUT MATERIALIZED ZONEMAP;
* zone map: https://blogs.oracle.com/datawarehousing/entry/optimizing_table_scans_with_zone
 группирует блоки таблицы по какому то столбцу и в zone-map записывает верхнее и нижнее значение конкретной части
 группировать можно по значениям другой таблицы, по join запросу:
  ALTER TABLE sales  ADD CLUSTERING sales 
  JOIN locations ON (sales_ac.location_id = locations.location_id) 
  BY LINEAR ORDER (locations.state, locations.county)
  WITH MATERIALIZED ZONEMAP;
 
* Виды преобразований запросов Optimizer Transformations  (https://docs.oracle.com/database/121/TGSQL/tgsql_transform.htm#TGSQL94896)
 ** join elimination (aggregate elimination), 
  убираются лишние неиспольлзуемые join (если есть фк?) или объединяет несколько group by(sum/max) в один
 ** view merging, 
  подзапрос разворачивается в основной запрос (в from)
 ** subquery unnesting, 
  подзапрос разворачивается в основной запрос (in/exists..)
 ** join predicate pushdown,
  фильтр из внешнего запроса проталкивается ниже, чтобы раньше отфильтровать данные 
 ** join factorization, 
   повторяющаяся часть Union all выносится во внешний запрос, внутри Union all остается только различия
 ** star transforamtion
  join измерений с фильтрами разворачивается в in фильтры
  таким образом получаем rowid битмап индексов на каждой колонке, потом мержим их через and и таблица быстро фильтруется по этим rowid без выполнения соединения
 ** Table Expansion, 
  таблица партиц по колонке 1, фильтр по индексу на колонке 2 - из индекса получаем rowid и дополнительно накладываем фильтр на партиционированный столбец 1
 ** or expansion, 
  or Запрос разворачивается фактически в Union all или используется or merge битмап индекса
 ** matview rewrite
  матвьюха с агрегатами, если встречается аналогичный запрос из матвьюхи, то запрос заменяется на запрос из матвью
 ** px: join filter/bloom - уже написано
 
* partition wise - в px запросах
  ** DFO (Data Flow Operation), PX Server Set - отпрвка данныех Px send (:TQ00000)
  ** DFO Tree, Parallelizer - PX COORDINATOR
  ** Multiple Parallelizers - с 12 версии, может побиться на 2 группы, у каждой будет свой DFO

--- сбор статистики ----

* как выбирается AUTO_SAMPLE_SIZE / incremetal в статистики, как выбираются столбцы для гистограмм?
 ** incremental - смотрит на изменения блоков в партициях, если изменилось больше 10% то собирается статистика по ним и глобальная
 ** CONCURRENT  - параллельный сбор статистики по нескольким таблицам/партициям
 ** AUTO_SAMPLE_SIZE - не для гистограмм всегда = 100%
   *** для гистограммы значительно меньший объем
* хинт /*+ GATHER_PLAN_STATISTICS */ и SELECT * FROM table(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT=>'ALLSTATS LAST')); - позволяет посмотреть актуальные числа, а не только рассчетные


---  транзитивность столбцов ---
к примеру есть функциональный constraint: col2 = trunc(col1, 'yyyy'). При фильтрации по col1 на таблицу будет наложен также и на col2

--- возможность фильтрации view ---
*** во вьюхах лучше делать lateral подзапросы с основной выборкой и измерением, по которому предположительно будет фильтроваться в будущем вьюха
тогда получится нестед лупс и ограниченное кол-во вызовов тяжелого запроса

* pattern matching??


--- статистика использования/изменения объектов ---
V$OBJECT_USAGE - статистика использования объекта

oracle поумолчанию логирует статистику объектов 30 дней
https://jonathanlewis.wordpress.com/2016/04/27/stats-history/
по ней можно узнать историю размеров/кол-ва строк, но это может и быть причиной разбухания SYSAUX , так что если история не нужна, можно уменьшить число дней "execute dbms_stats.alter_stats_history_retention(7)"


---- обращение к конкретной партиции ---
select DATA_OBJECT_ID from ALL_OBJECTS where OWNER = 'SYS' and OBJECT_NAME = 'T' and SUBOBJECT_NAME = 'P1';
update T partition (DATAOBJ_TO_PARTITION (T, :DATA_OBJECT_ID)) set N = N + 1;
если есть только row_id то можно через dbms_rowid  узнать название объекта в котором он лежит и использовать его

-- параллельное выполенение через chain ---
http://www.sql.ru/forum/1217028/using-chains#19259629

--- в merge (using) ---
нужно использовать только необходимые столбцы, иначе будут использованы все, что плохо: могут не взяться iffs или inmemory столбцы

--- индекс на маленькой таблице ---
 почти всегда лучше, чем сканирование даже по 1 блоку таблицы. Т.к. при поиске строки в блоке нужно польностью его просмотреть, в то время как данные в индексе упорядочены и можно применить алгоритм быстрого поиска с разделением (подтверждено практически). Также поиск по таблице усложняется, если столбец не первый, для каждой строки нужно делать смещение.

---- распараллеливание индексного доступа и создания constraint ----
http://www.xt-r.com/2012/09/parallel-index-range-scan.html

---- expand sql ----
https://jonathanlewis.wordpress.com/2012/07/10/expanding-sql/
 dbms_sql2.expand_sql_text

-- остановка запроса без kill ---
 sys.dbms_system.set_ev(v_sid, v_serial, 10237, 1, '');
остановка запроса без убийства сессии (аналог ctrl-c)

--- параллельность в 12 ---
*** в 11 версии filter выполняется не многопоточно, всегда через координатор (http://oracle-randolf.blogspot.ru/2015/07/12c-parallel-execution-new-features.html) в 12 многопоточно
** в 12 версии както распараллели rownum и аналитические функции (lag/lead) http://oracle-randolf.blogspot.ru/2015/06/12c-parallel-execution-new-features-1.html
** параллельность для доступа к индексу: https://jonathanlewis.wordpress.com/2016/06/10/uniquely-parallel/

--- нумерация групп --
lag(a, 1, a) over (order by b) start_of_group -> sum(start_of_group) over(order by a) - определение начала группы, потом нарастающий итога по группам


--- кеширование результатов ----
http://www.oracle-developer.net/display.php?id=503
  *** кеширование в rac : http://www.oracle.com/technetwork/articles/datawarehouse/vallath-resultcache-rac-284280.html
  
--- вставка игноря consraint, но с сохранением ошибок --- 
ALTER TABLE dept ENABLE PRIMARY KEY EXCEPTIONS INTO EXCEPTIONS;
а потом смотреть
SELECT * FROM EXCEPTIONS;
например, в случае пк, так покажутся дублирующие строки.
IGNORE_ROW_ON_DUPKEY_INDEX - хинтом вообще можно заставить игнорить


--- oracle join - выбор последовательности ---
 * факториал перестановок
 * жадный алгоритм - ищется отправная таблица 1, вычисляется наименьшая стоимость соединения с другой таблицей 2, результат join 1 и 2 ищет наименьшую стоимость с 3 таблицей и т.д. (т.е. нет перестановок каждый с каждым)
 * генетический алгоритм - оцениваются стоимости соединения таблиц между собой, выбираются лучшие варианты - перемешиваются и повторяется выбор
 
 * влияние гистограмм, как если больше 2 таблиц?
 * что первое: join или where? http://www.sql.ru/forum/1232979/gde-luchshe-ukazyvat-uslovie-v-join-ili-where#19730594
 
--- id блока индекса ---
SELECT object_id FROM user_objects WHERE object_name = 'IDX_TBL_SHIP_TMP';
select sys_op_lbid( 900382 ,'L',rowid) as block_id from tbl_ship ; --rowid блока индекса

--- очистить таблицу из буферного кэша ---
через вызов oradebug :
oradebug call kcbrbrl 4 0xАДРЕС N_блоков
http://www.sql.ru/forum/1212587/ochistit-kesh-tolko-po-opredelenoy-tablice

--- top n в группе ---
http://www.fors.ru/upload/magazine/07/http_text/russia_s.malakshinov_distinct_top.html
самый быстрый "top N в oracle 12" по нескольким категориям (целиком подойдет и аналитическая функция, она пропушится)
по xt_test.a, xt_test.b - должен быть индекс (ix_xt_test_ab)!!
xt_test.a-это категория (их относительно немного), b - другие поля, которых много
это лучше чем distinct - т.к. просматривается не весь индекс, а только ветви редкостречающегося xt_test.a
потом по xt_test.b берется пара первых значений также по индексу (index range scan + stop key)

with t_unique( a ) as (
              select min(t1.a)
              from xt_test t1
              union all
              select (select min(t1.a) from xt_test t1 where t1.a>t.a)
              from t_unique t
              where a is not null
)
select/*+ use_nl(rids tt) */ *
from t_unique v
    ,lateral(
              select/*+ index_desc(tt ix_xt_test_ab) */ tt.*
              from xt_test tt
              where tt.a=v.a
                and rownum<=5
              order by tt.a, b desc
     ) r
order by r.a,r.b desc

--- генерация undo --
изменение поля самого на себя генерит redo/undo , т.к. все равно должны отработать триггеры

-- быстрый count distinct с join
count distinct выгодней делать на запросе с join как сначала distinct - потом count, потом join
обычный алгоритм делает: join, потом group и count (получается экономия на соединении)
select P.PER_NAME, count(distinct s.POINTABON_ID) --14 332 641
from tbl_ship s
join ETL_ACCOUNT_PER p on p.ACCOUNT_PER_ID = s.in_per_id --696247--hj
group by P.PER_NAME;

select P.PER_NAME, s.cnt --1 116 915
from ETL_ACCOUNT_PER p
join (
  select in_per_id, count(1) as cnt from (
  select distinct in_per_id, POINTABON_ID from tbl_ship
  ) group by in_per_id
) s
on s.in_per_id = p.ACCOUNT_PER_ID;

--- последовательная вставка может раздуть ITL у индекса!!!, т.к. ITL листа наследуюется при расщеплении!
http://www.sql.ru/forum/754211/itl-listevogo-bloka-indeksa-v-pol-bloka?mid=8691002#8691002

-- системные вью --
* V$OSSTAT - статистика о ос
* V$BH - статистика данных в буферном кэше
* V$SQL_SHARED_CURSOR - почему разные планы для одного sql_id
-- план:
OMEM column -(estimated memory needed for an optimal execution)
1MEM column (estimated memory needed for a one-pass operation)
Used-Mem column (actual amount of memory used during the last execution)

--- dbms_redefine
* создаем таблицу с новыми настройками
* стартуем перенос:
 ** включаем для сессии параллельность 
 ** копируем данные в новую таблицу
 ** вешаем matview log на изменения на промежуток переноса зависимостей (индексы, триггеры, констрэйнты, гранты и т.д.)
BEGIN
 execute immediate 'ALTER SESSION ENABLE PARALLEL DML';
 execute immediate 'ALTER SESSION FORCE PARALLEL DML PARALLEL 16';
 execute immediate 'ALTER SESSION FORCE PARALLEL QUERY PARALLEL 16'; 
 DBMS_REDEFINITION.START_REDEF_TABLE('SCHEM','OLD_T','NEW_T', options_flag=>2); --2 - rowid
END;
* завершаем перенос:
 ** таблица блокируется
 ** новые/измененные данные мержатся в промежуточную таблицу
 ** ид объектов меняются местами 
BEGIN
  DBMS_REDEFINITION.FINISH_REDEF_TABLE ('SCHEM', 'OLD_T', 'NEW_T');
END;

+ можно делать почти в online
- нужно двойное место
- медленней, чем alter + move

-- создание profile
-- отличие профилей, от baseline: profile дают доп.информацию существующим планам, тогда как baseline хранит набор планов и жестко их фиксирует
DECLARE
l_sql_id v$session.prev_sql_id%TYPE;
l_tuning_task VARCHAR2(30);
BEGIN
l_tuning_task := dbms_sqltune.create_tuning_task(sql_id => l_sql_id);
dbms_sqltune.execute_tuning_task(:tuning_task);
dbms_output.put_line(l_tuning_task);
end;

SELECT dbms_sqltune.report_tuning_task('TASK_16467') FROM dual;

dbms_sqltune.accept_sql_profile(
task_name => 'TASK_16467',
task_owner => 'OPS$CHA',
name => 'first_rows',
description => 'switch from ALL_ROWS to FIRST_ROWS_n',
category => 'TEST',
replace => TRUE,
force_match => TRUE
);

-- ручное создание профиля:
begin
dbms_sqltune.import_sql_profile(
  name => 'test prof',
  sql_text => 'select * from t$t where skew = :a and mandt = :b and c1 = :c and c2 = :d',
  profile => sqlprof_attr('NO_INDEX("T$T" "IDX_T$T2")', 'NO_INDEX(@"SEL$1" T$T@"SEL$1" "IDX_T$T2")'),
  replace => TRUE,
  force_match => TRUE
);
end;

---
c append не генерируется Undo?, т.к. это direct вставка минуя буферный кэш

* при наличии индекса на нескольких столбцах: distinct values будет браться с него и игнорироваться гистограмма..

v$io_calibration_status

--
при наличии max функции , сканирование должно идти с конца секций, т.к. можно остановиться при первом найденом значении
до 11 версии нужно писать хинт index_desc
http://www.sql.ru/forum/actualutils.aspx?action=gotomsg&tid=1233742&msg=19754999

--
оптимизация текстовых индексов: http://www.oracle.com/technetwork/testcontent/index-maintenance-089308.html

* ALL_TAB_MODIFICATIONS - кол-во insert/delete/update на таблице

* разные части параллельного плана могут иметь разную степень параллелизма
 ** это нужно смотреть на вкладке parallel
 ** dfo = parallel group = один receiver/sender
 
https://recurrentnull.wordpress.com/2013/06/30/direct-path-nologging-ctas-and-gtt-a-comparison-of-undo-and-redo-generated/
ctas == insert + append
append - уменьшает undo
append+nologging - уменьшает и undo и redo
просто nologging в insert ничего не меняет (в ctas также как с append)

каждая итерация concatenation становится сложней, т.к. нужно доплонительно отфильтровать записи, которые уже попали в предыдущий этап конкатенации!! (чем больше уровней, тем сложней фильтровать)
параллельность запросов: https://blogs.oracle.com/datawarehousing/entry/auto_dop_and_parallel_statemen
рекурсивные запросы: https://oracle-base.com/articles/11g/recursive-subquery-factoring-11gr2
автономная транзакция: https://plsqlchallenge.oracle.com/pls/apex/f?p=10000:659:::NO:659:P659_COMP_EVENT_ID,P659_QUESTION_ID,P659_QUIZ_ID:8841,5615,&cs=1810AF111FE0929B1390FF8D1E47238FF
автономность начинает работать с begin, все select в declare работают в основной
merge: https://jonathanlewis.wordpress.com/2016/06/06/merge-precision/
в merge лучше писать только нужные колонки, если их не написать то будут селектится все (index+table asccess), если только нужные, то может быть только индексный доступ
SGA:
 * buffer Cahce
 * redo buffer
 * shared pool:
	** library cache  - кэщ plsql
	** sql cache - кэш sql запросов
	** result cache - кэширование результатов sql или plsql
	  *** хорошо подойдет для пагинации, для сохранения полного результата и хождения по нему
	
--- dnf: 16 + 103
olap: https://docs.oracle.com/database/121/OLAUG/overview.htm#OLAUG100
+ precompute_subquery(@sel$2)  - в первую очередь предрасчитывает подзапрос, а потом использует его результат в основном запросе (не join и не фильтрация)
перехват exception быстрей, чем min/max, если исключений немного?: http://orasql.org/2012/05/18/about-the-performance-of-exception-handling/
??? попробовать вариации match_recognize
??? преимущества кластерных таблиц http://www.sql.ru/forum/1217985/tablicu-v-klaster  ?
* dbms_stat:
skewed: The first is the 'skewonly' option which very time-intensive because it examines the distribution of values for every column within every index. 
auto: skewed + columns on where
* semi join - join ищет в правой таблице до первого совпадения (очень быстро по индексу, если в левой таблице немного строк)
	** exists по правой таблице
	** distinct по левой таблице
* http://www.sql.ru/forum/1085431/kak-zapretit-vypolnenie-zaprosa?mid=15903763#15903763
  https://blogs.oracle.com/imc/entry/sql_translation_framework
  sys.dbms_advanced_rewrite.declare_rewrite_equivalence - можно задать эквивалент sql запроса
* ALL_TAB_MODIFICATIONS - модификации таблицы (вставка/обновление)
* приблизительный count distinct https://habrahabr.ru/post/119852/
* dbms_shared_pool.markHot(hash, namespace) - Оракл делает несколько клонов "горячих" объектов в пуле и, так скажем, соревновательность между сессиями за эти объекты несколько снижается.
* поиск одного пропуска математической формулой:
  ** select (max(n)-min(n))*(max(n)-min(n)+1)/2+(count(*)+1)*min(n)-sum(n) from t;
     ( max-min ) * ( max - min + 1 ) / 2 + (count + 1) * min - sum ~= квадрат разницы/2 + число элементов - сумма
  ** через minus / not exists с генеренной полной последовательность тоже будет быстро (2 FTS + antijoin/sort)
  ** если n возрастающее число, то можно так: (1 FTS, возможно сортировка для аналитики)
  select n-rownum, to_char(max(n)+1) --последнее число группы (перед разрывом)
		||'-'||(lead(min(n)) over (order by n-rownum)-1),n-rownum --первое число следующей группы (после разрыва)
	from t
	group by n-rownum --делаем группы (каждый разрыв даст новую группу)
	order by n-rownum;

* dml с db link будет всегда выполняться на текущей стороне (если все таблицы на удаленной бд, то будет на удаленной) (т.е. таблицы будут целиком выкачиваться?)
  http://www.sql.ru/forum/1227224-2/tormoza-pri-join-e-neskolkih-tablic-cheroz-dblink
* length вернет 0 для empty_clob (в иных случаях null)
* model: https://habrahabr.ru/post/101003/
* установка clinet/module/action + запись в v$long_ops (можно встроить в цикл для информаирования): https://docs.oracle.com/cd/E11882_01/appdev.112/e40758/d_appinf.htm#ARPLS65241
 И еще так: http://www.igormelnikov.com/2016/04/real-time-database-operation-monitoring.html
* http://www.sql.ru/forum/1249064-3/replace - при вставке в varchar данных больше 4000, то он обрезается до максимума (если вставляется в середину, то вставка не пройдет, строка просто обрежется)
select replace('hello xulio', 'x',  rpad('x', 32767)) from dual -- вернет hello


----------
* для инкрементального сбора статистики на партицированной таблице создается дополнительная структура где хранися информация об уникальных значениях таблицы
EXEC dbms_stats.set_table_prefs(null,'SALES','INCREMENTAL','TRUE')

https://blogs.oracle.com/optimizer/efficient-statistics-maintenance-for-partitioned-tables-using-incremental-statistics-part-1
c 12.2 используется призительный distinct HLL (http://blog.skahin.ru/2017/02/oracle-hash-distinct.html)
* устаревшая статистика определеяется по числу DML после сбора статистики.
Если она превышает STALE_PERCENT в настройках таблицы, то будет пересбор
select  * from    dba_tab_modifications where   table_owner = 'DWH'
* oracle собирает гистограммы на уникальных столбцах у которых запросы через равно (на основе SYS.COL_USAGE$) и был обнаружен перекос.
* написать, что на NO_DUBLICATE в RAC данные равномерно распределяются по нодам, что замедляет запросы за счет кластерных ожиданий.


* классификация времени запроса по LogIO и строкам:
	** Logic IO per row * rows * (1 - buffer hit ratio for query) * sreadtim
	  sreadtim - время одноблочного чтения
	** причем
	  *** Logic IO per row < 10 - Хорошо
	  *** 10 - 100 - Средн
	  *** > 100 - плохо
    
    
 * индекс - кандидат на удаление, если "db block changes" > "logical reads"/3 из DBA_HIST_SEG_STAT (т.е. запись превышает логические чтения)
  ++ проверить по ash
  
  -----
  * exadata 12.2:
1. кэширование temp в flash disk (раньше только физ. диски) - ускорение!
2. smart scan на сжатых индексах (раньше не работало, только бд)
3. lob до 4 кб смогут использоваться в smart scan (иначе на бд)
* dbms_profiler: https://oracle-base.com/articles/9i/dbms_profiler
  чтобы смотреть сколько времени работала какая строка процедуры
* локальные и глобальные индексы (добавить в статью про индексы)
  ** локальный - партиции = партициям таблицам, управляется совместно
  ** глобальный может не иметь вообще партиции, или партицирован произвольно самостоятельно
* шардинг в 12.2
http://www.oracle.com/technetwork/database/availability/con6532-oracle-sharding-3334967.pdf
* dynamic sampling 11g = 4
!!! будет сэмплировать результаты выборок, если есть функции или or
https://docs.oracle.com/cd/E11882_01/server.112/e41573/stats.htm#PFGRF95254
alter session set OPTIMIZER_DYNAMIC_SAMPLING=6;
ALTER SESSION ENABLE PARALLEL DML;
* forall - в статистике (ash/awr) будет выглядеть как одно выполнение (exec), но обработавшее N строк. Даже если внутри запрос обрабатывающий 1 строку по первичному ключу!
* выявление skew через oem monitor:
 ** по активити смотрим, сразу видно
 ** потом делаем монитор в разрезе plan_line - сразу будет видно на каком этапе
 ** потом на parallel будет видно какое parallel set выполнял большую часть работы
 ** зная plan_line и сервер переходим в статистику выполнения, выбираем из выпадающего списка наш сервер и смотрим нашу plan_line
	** в actual rows увидим сколько строк было обработано (оцениваем с общим числом), тамже размер памяти будет
* ???? где смотреть статистику таблиц в кэше exadata  - V$CELL_THREAD_HISTORY
	** возможно для избранных делать keep flash cache
	** _serial_direct_read=true - читать минуя буферный кэш
	** частые запросы враг экзадаты, хотябы по тому, что таблица целиком уходит в кэш и смарт сканы не используются
* hcc:
 ? взаимосвязь строк в колонках (фильтровали по 1 выбрать эту же строку из другой?
	select col1, col2 from T where col1 = 1
   ?? отсортированная колонка
   ?? неотсортированна (данные в порядке вставки)
   https://jonathanlewis.wordpress.com/2012/07/20/compression_units/
 ? есть ли доступ по ключу rowid?
 ? как происходит работа со сжатыми данными или это дедубликация ?
 ? синхронизация дельты с основной колонкой ? (hana и oracle)
* http://www.sql.ru/forum/1256392/sozdanie-pustogo-polya-po-bolshoy-tablice-srazu-s-indeksom
Создание нового not null поля с default не создает блоки физически, а только помечает в словаре.
Только при следующих измнеениях обновляется это значение.
* Edition-Based_Redefinition_2017_04_13-overview
plsql redefinition - возможность делать ревизии (несколько версий) пакета и переключать через alter session/system. Т.е. возможно выкладка изменений без остановки работы пользователей.
* sql функция возвращает данные на момент своего вызова, а не на момент старта основного запроса.
* для инкрементального сбора статистики на партицированной таблице создается дополнительная структура где хранися информация об уникальных значениях таблицы
EXEC dbms_stats.set_table_prefs(null,'SALES','INCREMENTAL','TRUE')
https://blogs.oracle.com/optimizer/efficient-statistics-maintenance-for-partitioned-tables-using-incremental-statistics-part-1
c 12.2 используется призительный distinct HLL (http://blog.skahin.ru/2017/02/oracle-hash-distinct.html)
* устаревшая статистика определеяется по числу DML после сбора статистики.
Если она превышает STALE_PERCENT в настройках таблицы, то будет пересбор
select  * from    dba_tab_modifications where   table_owner = 'DWH'
* oracle собирает гистограммы на уникальных столбцах у которых запросы через равно (на основе SYS.COL_USAGE$) и был обнаружен перекос.
* написать, что на NO_DUBLICATE в RAC данные равномерно распределяются по нодам, что замедляет запросы за счет кластерных ожиданий.
* index coalesce - перемещает пустоты в конец индекса, которые потом можно будет использовать при равномерном добавлении (размер индекса не уменьшеается, blvel тоже, индекс и таблица не блокируется)
* select * from v$event_histogram - Гистограмма изменения времени события
* https://richardfoote.wordpress.com/2013/05/01/storage-indexes-vs-database-indexes-iv-8-column-limit-eight-line-poem/
в exadata только 8 столбцов могут находится в storage index (но какие - определяет оракл, это не порядок запросов и не порядок в таблице)
* http://www.sql.ru/forum/1184757/parallel-sequential-scan#20754710
параллельное чтение индекса - 1 поток читает адреса в связанном списке, а другие потоки считывают сами данные из блоков + возможно дофильтрация индекса
* вставка в новую таблицу будет идти хуже, чем в старую, но с truncate. Т.к. asm в новой постоянно выделяет место на диске, а в старой место выделено, просто смещено HWM
* настройка сетевых параметров в листенере бд:
http://www.sql.ru/forum/actualutils.aspx?action=gotomsg&tid=1273034&msg=20839650
* dbms_workload_repository.add_colored_sql
запрос всегда будет попадать в awr , несмотря на его частоту и скорость
* устранение конкуренции за plsql - автоматическое размножение пакетов (mark hot ?)
* при выборе порядка столбцов в индексе руководствоваться:
 - степенью сжатия
 - полезностью для других
 - фактором кластеризации!!!!!
* bind data: table(dbms_sqltune.extract_binds(ad.bind_data))
* Хинт: COLUMN_STATS(DD, VN, scale, length=3 distinct=5 nulls=0 min=2 max=10)
http://www.hellodba.com/reader.php?ID=200&lang=en
* еще один профайлер для plsql
https://docs.oracle.com/cd/E11882_01/appdev.112/e41502/adfns_profiler.htm#ADFNS02305
** 10053 trace file for the query 
alter session set tracefile_identifier='10053_&your_name'; 
alter session set timed_statistics = true; 
alter session set statistics_level=all; 
alter session set max_dump_file_size = unlimited; 
alter session set events '10053 trace name context forever, level 1'; 
EXPLAIN PLAN FOR /*ACTUAL QUERY TEXT HERE */; --> use EXPLAIN PLAN FOR to actually avoid having the query run 
alter session set events '10053 trace name context off'; 
* стоимость основных операции в тактах CPU:
https://hsto.org/webt/6k/gv/4b/6kgv4bwokemkgl39uevpixx3gzi.png
* not null + default 
не создают физически данные в столбце, а только заполняют значением в метаданных (которое потом возвращется при любом запросе)
http://www.sql.ru/forum/1278952/flashback-database-i-ddl-na-bolshih-tablicah
* http://orasql.org/2017/02/12/intra-block-row-chaining/
при вставке в таблицу с более 255 колонок, block chain кладется в 1 блок
при update в разные - так что такие таблицы имеет смысл ребилдить периодически, для избавления от одноблочных чтений (в 12.2 пофиксили и это)
поколоночное чтение поможет только при первом чтении, все последующие из буферного кэша читаются построчно
* http://dbaora.com/partition-outer-join-oracle-data-densification-2/
partition join Добавляет недостающие данные в факте по f.cust_id (не нужно самому генерить, говорят аналог union all ) особых преимуществ в скорости не вижу???
SELECT 
  f.cust_id, 
  to_char(t.mth, 'DD.MON.YYYY') mth_name, 
  sum(nvl(vol,0)) vol
FROM 
  time_dim t LEFT OUTER JOIN 
  fct_tbl f  PARTITION BY  (f.cust_id) 
ON(t.mth = f.mth)
GROUP BY f.cust_id, t.mth
order by t.mth, f.cust_id;
** round = int(x+0.5)
* https://habrahabr.ru/company/ruvds/blog/346442/
оплату и логин лучше делать на отдельной странице (или через iframe)
** https://docs.microsoft.com/ru-ru/sql/relational-databases/indexes/clustered-and-nonclustered-indexes-described
у mssql вторичные индексы ссылаются на кластерный первичный ключ, а не на саму таблицу.
(в pg , как в оракле : https://www.postgresql.org/docs/current/static/sql-cluster.html )
* установка памяти под HJ или сорт, если память автоматическая
http://dbakevlar.com/2010/01/when-pga-size-is-not-enough/
pga_target + pga_limit - общие значения, и скрытые _smm_max_size и _pga_max_size под одну операцию
* https://docs.oracle.com/cd/E11882_01/server.112/e25494/views.htm#i1006318
DELETE   FROM (
    SELECT
        s.item item,
        s.loc loc
    FROM
        stsc.sku s,
        stsc.planarriv pa
    WHERE
    s.item = pa.item
        AND   s.loc = pa.dest
        )
возьмется таблица с максимальным ключом, которая однозначно определяем результат джойна
если у sku ключ из 2 полей, а planarriv из 3, то возьмется максимальный с 3 полями: planarriv
* http://www.sql.ru/forum/1235740/chtenie-plana-zaprosa?mid=19813880#19813880
читать план правильно сверху вниз, как будто это вызовы процедур (пример с FILER вначале, который вообще может выключить работу sql)
сверху спускаемся до самого глубокого листа и от него стэк разворачивается в обратную сторону
* ассоциация статистики к процедуре:
http://www.oracle-developer.net/display.php?id=426
* huge pages
https://oracle-base.com/articles/linux/configuring-huge-pages-for-oracle-on-linux-64
поумолчанию в linux размер блока = 4кб, что увеличивает накладные расходы на менеджмент, + данные могут быть вытеснены из озу
+ стрраница размером в гиг всегда будет залочена и не уйдет из кэша
+ нет затрат линукса, все делает оракл
* кол-во не NULL колонок:
select cardinality(    ku$_vcnt(   1,    2,    0,    null,    3)
multiset except ku$_vcnt(null, null, null, null, null) ) from dual
* партицирование:
 + системное партицирование - нет указания колонки при создании, нужно указывать конкретную партицию при вставке или выборке.
 + reference partitions:
  create table orders (id integer, sm number, odate date, CONSTRAINT opk PRIMARY KEY (id) PARTITION BY RANGE(odate) (...);
  create table order_itemss (oid integer, sm number, CONSTRAINT ofk FK to orders) PARTITION BY REFERENCE(ofk)
  --т.е. в строках нет даты, она автоматом подтягивается по фк из заголовка и партицируется по ней
 + iOT также могут быть партицированы по range/hash
 + object table - также можно пратицировать. 
 + nested table - партицируется аналогично родительской
 + глобальные индексы можно партицировать только по range и hash
 + INDEXinG OFF|On - можно задать активность индексов на конкретной партиции (ora 12)
 индекс при этом должен быть создан как INDEXING PARTIAL
 при запросе на партиции без индекса и с ним, будет конкатенация
 + coalesce - это merge всех партиций для hash партицирования
 + на основании статистики использования партиций (DBA_HEAT_MAP_SEG_HISTOGRAM) можно включить компресию
 ALTER TABLE T MODIFY [PART] ILM ADD POLICY COMPRESS ADVANCED ROW AFTER 30 DAYS OF NO MODIFICATION;
 + матвьюхи?
* главная сессия при параллельном запросе:
select distinct decode(session_id, qc_session_id, 'main', 'slave') sess_type, sql_child_number--, sql_exec_start
  from v$active_session_history
 where sql_id = 'dknw7mqyg5789';

* result_cache 
 - есть интересные хинты:
  -- заставить кэшировать системные объекты
  -- задать время жизни
 - при активации кэша на таблице, нужно проверить что запросов на ней немного и они возвращают небольшое число строк (основное время тратится на запрос, а не на возвращение строк)
  -- есть блэк лист (или хинтом) - отключить для разовых
 - один latch на весь result_cache, так что вставка/чтение блокирует всех остальных
* heat map - раз в день, статистика по использованию сегмента (запись, фул, лукап)
select * from DBA_HEAT_MAP_SEG_HISTOGRAM WHERE OBJECT_NAME='WALE' order by TRACK_TIME desc
---
Real Appl Test
http://www.cyberguru.ru/database/oracle/oracle11-database-replay.html?showall=1
http://www.sql.ru/forum/1212593/podskazhite-analogi-rat-real-application-testing-dlya-oracle?hl=real%20application%20testing

---
mssql:
* хинты: https://msdn.microsoft.com/ru-ru/library/ms181714.aspx
* профили: https://msdn.microsoft.com/ru-ru/library/ms179880.aspx


---
время работы фоновых заданий:
select TBTCO.JOBCOUNT, TBTCO.STEPCOUNT, TBTCO.STRTDATE, TBTCO.STRTTIME, TBTCO.ENDDATE, TBTCO.ENDTIME, TBTCO.RELUNAME ,
TBTCO.ENDTIME-TBTCO.STRTTIME as sec,
TBTCP.PROGNAME, TBTCP.AUTHCKNAM, TBTCP.VARIANT
from TBTCO 
join TBTCP on TBTCO.JOBCOUNT = TBTCP.JOBCOUNT and TBTCO.STEPCOUNT = TBTCP.STEPCOUNT
where TBTCO.jobname = 'Z_HR_USER_LOCK' 
order by TBTCO.STRTDATE desc, TBTCO.STRTTIME desc

---
java:
* hash;  Встроенный хеш-код генерируется лишь один раз для каждого объекта при первом вызове hashCode(), после сохраняется в заголовке объекта для последующих вызовов. 
Но для первого раза используется random или Xorshift:
  0 – Park-Miller RNG (по умолчанию)
  1 – f(адрес, глобальное_состояние)
  2 – константа 1
  3 – последовательный счетчик
  4 – адрес объекта
  5 – Thread-local Xorshift (псевдослучайное от threadid)

* code review