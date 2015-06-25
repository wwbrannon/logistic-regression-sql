-- create shell table
drop table if exists data;
create local temporary table data
(
    admit int,
    gre int,
    gpa float,
    rank int
) on commit preserve rows;

-- load in data
copy data
from '/home/will/projects/logistic_sql/example/data.csv'
with csv header;

-- estimate!
select lregr(data);

