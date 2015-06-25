-- Logistic regression on continuous predictors, adapted for sparse matrices.
-- Implemented entirely in Postgres' dialect of SQL.
-- William Brannon, will.brannon@gmail.com, Dec 2013.

-- Estimation is by maximum likelihood. The log likelihood is given by
-- 	l(t) = log L(t)
--           = log p(Y | X; t)
--           = sum(i=1,i=m, y(i)*log(h(x(i))) + (1 - y(i)) * log(1 - h(x(i)))),
-- where h(x(i)) := logit(transpose(t) * x(i)). Because l(t) is convex, we'll
-- fit the model with stochastic gradient ascent. The update rule after taking the partials is
-- 	t_j := t_j + a * sum(i=1,i=m, (y(i) - h(x(i)))* x(i)_j)
-- so we need to compute this iteratively and check for convergence.

-- the sigmoid function
CREATE OR REPLACE FUNCTION sigmoid(FLOAT)
	RETURNS FLOAT
	RETURNS NULL ON NULL INPUT
	IMMUTABLE
AS $$
	SELECT 1.0 / (1.0 + exp(-1.0 * $1))
$$ LANGUAGE sql;

-- TODO
-- make this work right...
-- estimate the intercept term
-- calculate the log likelihood and actually check convergence
CREATE OR REPLACE FUNCTION lreg(X REGCLASS, Y REGCLASS, alpha FLOAT = 0.1)
	RETURNS TABLE (rownum INT, val FLOAT)
	RETURNS NULL ON NULL INPUT
	VOLATILE
AS $func$
DECLARE
	lastnorm FLOAT		:= 0;
	curnorm FLOAT		:= 0;
	diff FLOAT			:= 1;-- difference between param vector norm on successive iterations
	mindiff FLOAT		:= 0.0001;
	iters INT			:= 0;
	max_iters INT		:= 2;
BEGIN
	CREATE LOCAL TEMPORARY TABLE theta
	(
		rownum INT,
		val FLOAT,
		PRIMARY KEY(rownum)
	) ON COMMIT PRESERVE ROWS;

	-- the initial guess for theta
	INSERT INTO theta
		(rownum, val)
	SELECT DISTINCT
		colnum,
		0.9
	FROM X;
	
	WHILE diff >= mindiff AND iters < max_iters LOOP
			lastnorm := (SELECT SQRT(SUM(T.val^2)) FROM theta T);

			UPDATE theta
			SET val = theta.val + alpha * it.val
			FROM
			(
				SELECT
					x.colnum,
					SUM(X.val * resid.val) AS val
				FROM X
					INNER JOIN
					(
						SELECT DISTINCT
							X.rownum,
							(y.val::INT - sigmoid(SUM(T.val * X.val) OVER (PARTITION BY X.rownum))) AS val
						FROM theta T
							INNER JOIN X ON T.rownum = X.colnum
							INNER JOIN Y ON Y.rownum = X.rownum
						ORDER BY X.rownum
					) resid ON X.rownum = resid.rownum
				GROUP BY x.colnum
			) it
			WHERE it.colnum = theta.rownum;

			-- scale the coefficients
			UPDATE theta
			SET val = theta.val / norm.norm
			FROM
			(
				SELECT SQRT(SUM(T.val ^ 2)) AS norm -- the Euclidean norm
				FROM theta T
			) norm;

			iters := iters + 1;
			curnorm := (SELECT SQRT(SUM(T.val^2)) FROM theta T);
			diff := ABS(curnorm - lastnorm);
	END LOOP;

	RETURN QUERY
	SELECT * FROM theta;
END
$func$ LANGUAGE plpgsql;

-- Create table shells for the design matrix, response vector and
-- parameter vector, and populate them.
DROP TABLE IF EXISTS X;
CREATE TABLE X
(
	rownum INT,
	colnum INT,
	val FLOAT,
	PRIMARY KEY(rownum, colnum)
);

DROP TABLE IF EXISTS Y;
CREATE TABLE Y
(
	rownum INT,
	val BOOLEAN,
	PRIMARY KEY(rownum)
);

COPY X
	(rownum, colnum, val)
FROM '/home/will/bin/xvar.csv'
WITH
(
	FORMAT CSV,
	HEADER TRUE
);

COPY Y
	(rownum, val)
FROM '/home/will/bin/yvar.csv'
WITH
(
	FORMAT CSV,
	HEADER TRUE
);

-- estimate!
SELECT lreg('X', 'Y');

