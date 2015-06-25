-- Logistic regression in Postgres' pl/pgsql, fit by maximum likelihood.
-- William Brannon, will.brannon@gmail.com.

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
CREATE OR REPLACE FUNCTION lregr(X REGCLASS, Y REGCLASS)
	RETURNS TABLE (id INT, val FLOAT)
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
		id INT,
		val FLOAT,
		PRIMARY KEY(id)
	) ON COMMIT PRESERVE ROWS;

	-- the initial guess for theta
	INSERT INTO theta
		(id, val)
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
							X.id,
							(y.val::INT - sigmoid(SUM(T.val * X.val) OVER (PARTITION BY X.id))) AS val
						FROM theta T
							INNER JOIN X ON T.id = X.colnum
							INNER JOIN Y ON Y.id = X.id
						ORDER BY X.id
					) resid ON X.id = resid.id
				GROUP BY x.colnum
			) it
			WHERE it.colnum = theta.id;

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

