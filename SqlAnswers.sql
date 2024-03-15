-- 90 minutes total on SQL questions

-- Before diving into answering questions for the vet clinic, its important
-- to do some basic exploration.  

-- start by looking at metadata for the tables (assuming mssql and case 
-- insensitive collation)
select table_schema
    , table_name
    , column_name 
    , column_default
    , is_nullable 
    , data_type 
    , character_maximum_length
    , collation_name 
from information_schema.columns 
where table_name in ('dogs'
    , 'cats'
    , 'veterinary visit record'
    , 'visit procedure')
order by table_name 
    , ordinal_position

-- then row counts, missing data checks and check data to type mismatches

select 'dogs'
    , count(1)
from dogs 
union all 
select 'cats'
    , count(1)
from cats 
-- .... continue for each table

select 'dogs' as TableName
    , sum(case when [name] is null then 1 else 0 end) as MissingNameCount
    , sum(case when birth_date is null then 1 else 0 end) as MissingBirthDate
-- .... continue for each table / column 

select count(1)
-- select *
-- assuming the count is reasonble, manually review the "broken" records
from dogs 
where isnumeric([name]) = 1
    or isdate([name]) = 1
    or isdate([birth_date]) = 0
    or gender not in ('m','f','u') -- or whatever the expected values are 
-- .... continue for each table / column

-- make sure that the expected keys are in fact unique
select animal_id 
from dogs 
group by animal_id
having count(1) > 1

select animal_id 
from cats 
group by animal_id
having count(1) > 1

select visit_id 
from [veterinary visit record]
group by visit_id
having count(1) > 1

select visit_id
    , procedure_code 
from [visit procedure]
group by visit_id 
    , procedure_code 
-- this likely does have results as the same procedure could be performed multiple
-- times in a visit.  such as wound closure stitching if a surgery with multiple
-- sites is performed.  anesthesia or other calming interventions may create 
-- duplicates as well.  with this likely being the largest table, no unique key
-- could be problematic

-- hopefully dogs and cats have unique animal_ids between the tables and this 
-- returns 0
select count(dogs.animal_id)
from dogs 
    join cats 
        on cats.animal_id = dogs.animal_id
-- if not, its likely uniqueness would be present anyway once the other columns
-- are considered (animals with the same id would not share a name, birth_date, 
-- gender and address).  it would take considerably more effort to account for this
-- in other queries.

-- the remaining queries will assume hundreds of millions of records found for 
-- visits and tens of millions in each of dogs and cats.  visit procedure 
-- is assumed to possible be billions.  for simplicity, no other problems
-- were found with the data.  if there were problems, these would be accounted
-- for in each query.  for example...
where isnumeric([name]) = 0
    and isdate(birth_date) = 1

-- validation and data exploration took 30 minutes 





-- assuming database is part of production system and answers to the questions 
-- asked can be 99% accurate (as opposed to 100%), dirty reads would be preferable
set transaction isolation level read uncommitted 

-- visit frequency, animal volumes, total costs per physician in cy 2019 
-- for animals < 3 years old as of service date.
declare @StartDate date = '2019-01-01'
    , @EndDate date = '2020-01-01'
    , @AgeInMonths int = 36 -- months used to avoid leap day problems

-- assuming animal_id is unique across dogs and cats tables 
drop table if exists #animal 
create table #animal (
    animal_id bigint -- or w/e the appropriate type is
    , birth_date date 
)

insert into #animal 
select animal_id
    , birth_date 
from dogs 
union all -- more peformant than union if assumptions on animal_id uniqueness hold
select animal_id 
    , birth_date 
from cats 

;with flat_physician as (
    select [veterinary visit record].service_date 
        , [veterinary visit record].visit_id
        , [veterinary visit record].physican_1 as Physician
        , [veterinary visit record].animal_id
        , case when [veterinary visit record].physician_2 is not null 
                and [veterinary visit record].physician_2 != [veterinary visit record].physician_1 
            then sum(coalesce([visit procedure].procedure_cost, 0.0)) / 2
          else 
            sum(coalesce([visit procedure].procedure_cost, 0.0)) end as VisitCost
          -- assuming visits with no procedures are free, but should count towards volume
          -- with no link between physician and procedure, dividing the cost between
          -- all physicians present on the record seemed the next best alternative
    from [veterinary visit record]
        join #animal 
            on #animal.animal_id = [veterinary visit record].animal_id 
        -- assumption is that visit records without an animal id should likely be excluded 
        -- from volume and revenue figures
        left join [visit procedure]
            on [visit procedure].visit_id = [veterinary visit record].visit_id 
    where [veterinary visit record].service_date >= @StartDate 
        and [veterinary visit record].service_date < @EndDate 
        and datediff(month, #animal.birth_date, [veterinary visit record].service_date) <= @AgeInMonths
        and [veterinary visit record].physician_1 is not null
    union all
    select [veterinary visit record].service_date 
        , [veterinary visit record].visit_id
        , [veterinary visit record].physican_2 as Physician
        , [veterinary visit record].animal_id
        , case when [veterinary visit record].physician_1 is not null 
                and [veterinary visit record].physician_1 != [veterinary visit record].physician_2
            then sum(coalesce([visit procedure].procedure_cost, 0.0)) / 2
          else 
            sum(coalesce([visit procedure].procedure_cost, 0.0)) end as VisitCost
    from [veterinary visit record]
        join #animal
            on #animal.animal_id = [veterinary visit record].animal_id 
        left join [visit procedure]
            on [visit procedure].visit_id = [veterinary visit record].visit_id 
    where [veterinary visit record].service_date >= @StartDate 
        and [veterinary visit record].service_date < @EndDate 
        and datediff(month, #animal.birth_date, [veterinary visit record].service_date) <= @AgeInMonths
        and [veterinary visit record].physician_2 is not null
        and ([veterinary visit record].physician_1 is null or 
             [veterinary visit record].physician_1 != [veterinary visit record].physician_2
        )
), animal_roster as ( -- assuming animal volume refers to total animals seen in the period 
    select physician 
        , count(distinct animal_id) as RosterSize
    from flat_physician
    group by physician 
)
select service_date 
    , flat_physician.Physician 
    , animal_roster.RosterSize 
    , count(distinct flat_physician.visit_id)
    , count(distinct flat_physician.animal_id)
    , sum(flat_physician.VisitCost)
from flat_physician 
    join animal_roster 
        on animal_roster.physician = flat_physician.physician
group by service_date 
    , flat_physician.Physician 
    , animal_roster.RosterSize 
-- assumption is that service_date is only a date.  aggregation to the day allows room for the 
-- visualization tool to aggregate at higher levels dynamically.

-- query A took 1 hour




-- visits ordered from least to most expesive 
-- assuming here that this is a first look at the data and part of exploration for an analysis
-- possibly going into a histogram.  with the size of the data, i want to keep this as small
-- as possible 

select visit_id
    , sum(procedure_cost)
from [visit procedure]
group by visit_id
order by sum(procedure_cost)

-- physician_2 that is not physician_1 at some point
-- same as above, keeping this as simple as possible.  
-- except returns distinct values, requiring a sort.  this is best run in off-peak hours or offloaded
-- to another server cluster or tool.
select physician_2
from [veterinary visit record]
except  
select physician_1
from [veterinary visit record]

-- query B and C took 10 minutes including comments 





-- errors in data entry on physician name

/*
If "several" means <20 or so physicians in the request and there are <500 total physicians, I would 
pull a distinct list, then order and manually search that list.  Otherwise, i would try the soundex 
implementation in whatever dbms I am using. I would expect limited benefit here though as typos come
from both choosing the wrong spelling of a name "smith" vs "smythe" and hitting the wrong key "smith" 
vs "snutg" (right hand moved left 1 key).

I would also have a conversation with my manager about the data entry problem and suggest working with 
vendor to patch the issue.  once a fix was in place to prevent the most common source of the errors, 
I would plan a one time update, including backups, peer reviewed update scripts and pair programming 
for running the script
*/

-- section d took 5 minutes



-- poor query performance
/*
1 - blocking (possibly a looped chain) on objects used in the query.  For example, trying to run 
    the procedure cost query on line 206 while a batch of visits was being loaded and clinicians
    adding to animal's charts.  

2 - resource contention, possibly tempdb filling up the server disk or another query using all of 
    the processor / memory.  In this case, I would try to move my query to another time or work 
    with the DBAs to figure out when / where to run my query

3 - logical error in my query resulting in a cross join.  for example */
    from dogs 
        join cats
            on cats.animal_id = cats.animal_id -- should be dogs on the right side
-- in this case, i would isolate smaller sections of my code to run individually to find the error.  
-- the same isolation strategy is how i would proceed with finding the problematic section of code as well.

/*
4 - compute resources not matched to database size - for example using a workstation to host the vet 
    database.  this is an extreme example, but the query could be broken into batches and the results 
    combined at the end.  this would be appropriate for an adhoc query, but not sustainable and upgrades 
    should be recommended.

5 - missing indexes - work with DBAs to build the needed indexes.

6 - poorly written code - unneeded distincts, union alls, order bys, not using available indexes, unneccessary
    joins, selecting more columns than are needed, using unnecessary window functions or aggregates.  these can 
    be fixed with a practiced eye.  either your own or a peer's. 

7 - poorly organized code - pulling all visit records and cost into a temp table, then using it as as base for 
    further filtering on animal age. 
*/

-- question 2 took 10 minutes