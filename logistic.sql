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
CREATE OR REPLACE FUNCTION lregr(data REGCLASS)
    RETURNS TABLE (predictor varchar, theta FLOAT, converged BOOLEAN) -- coefficients in the same order as in data
    RETURNS NULL ON NULL INPUT
    VOLATILE
AS $$
DECLARE
    tol          FLOAT         := 0.0001; -- the tolerance parameter
    iters        INT           := 1;
    max_iters    INT           := 50;
    alpha        INT           := 0.1;
    
    long_query   VARCHAR       := "";

    lastnorm     FLOAT         := 0;
    curnorm      FLOAT         := 0;
    diff         FLOAT         := 1;      -- absolute value of change in norm(theta) on successive iterations
BEGIN
    -- the coefficients
    CREATE LOCAL TEMPORARY TABLE theta
    (
        predictor varchar,
        theta FLOAT
    ) ON COMMIT PRESERVE ROWS;

    -- the data is assumed to be passed in wide format, with one column per predictor
    -- let's turn it into long format, because column-by-column operations are so hard
    CREATE LOCAL TEMPORARY TABLE pkeys
    ON COMMIT PRESERVE ROWS AS
    SELECT
        a.attname,
        format_type(a.atttypid, a.atttypmod) AS data_type
    FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
    WHERE
        i.indrelid = 'data'::regclass AND
        i.indisprimary;
    
    CREATE LOCAL TEMPORARY TABLE predictors
    ON COMMIT PRESERVE ROWS AS
    SELECT
        column_name
    FROM information_schema.columns
    WHERE
        ordinal_position <> 1 AND
        table_name = 'data' and
        table_schema = ;

    long_query := 'CREATE LOCAL TEMPORARY TABLE long_data
    (
        variable varchar,
        val double,
    ';

    FOR colname, type_name IN SELECT attname, data_type FROM pkeys LOOP
        long_query := long_query || ' ' || colname || ' ' || type_name || ', ';
    END LOOP;

    long_query := long_query || ') ON COMMIT PRESERVE ROWS;'

    EXECUTE long_query;

    FOR LOOP
    END LOOP;

    -- initialize theta with that many variables
    INSERT INTO theta (theta)
    SELECT 0.0
    FROM generate_series(1, @nvars);
    
    -- loop until convergence, or until we hit too many iterations.
    WHILE diff >= tol AND iters < max_iters LOOP
            -- partly to make this easier, the stopping criterion is based
            -- on the L2 norm of the coefficient vector theta.
            lastnorm := (SELECT SQRT(SUM(theta ^ 2)) FROM theta);

            -- center and scale the data.
            -- for efficiency on large datasets, we're not going to modify
            -- the data argument, we're just going to compute the 

            UPDATE theta
            SET theta = theta.theta + alpha * it.val
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

            iters := iters + 1;
            curnorm := (SELECT SQRT(SUM(theta ^ 2)) FROM theta);
            diff := ABS(curnorm - lastnorm);
    END LOOP;

    RETURN QUERY
    SELECT
        id,
        theta,
        iters <= max_iters
    FROM theta;
END
$$ LANGUAGE plpgsql;

