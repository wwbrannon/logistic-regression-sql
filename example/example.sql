-- create shell table
drop table if exists data;
create local temporary table data
(
    id serial,
    admit int,
    gre int,
    gpa float,
    rank int
)
on commit preserve rows;

-- load in data
copy data
	(admit, gre, gpa, rank)
from '/home/will/projects/logistic_sql/example/data.csv'
with csv header;

-- estimate!
select lregr(data);

