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

--- описать алгоритмы ---
external sort: http://faculty.simpson.edu/lydia.sinapova/www/cmsc250/LN250_Weiss/L17-ExternalSortEX1.htm
b+tree - http://www.cs.usfca.edu/~galles/visualization/BPlusTree.html

* реализовать btree дерево на c++
  t - число элементов в узле/листе: т.к. индекс читается по уровняем, то t выбирается таким, чтобы влезать целиком в память
  значение в листе упорядочены, чтобы быстро отбирать данные
 ** очень хреново вставка, если число записей в узле превысит 2t-1 - в этом случае нужно разделить родителя
 ** обратная ситуация с удалением, если меньше t-1 то объединяется с соседом и разбивается заново
   если удаляется элемент из узла (не листа), то нужно новое разбиние
   rowid содержатся только в листах

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