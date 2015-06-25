##Example 2

x <- read.csv("data/example2_x.csv")
summary(x)
dim(x)

y <- read.csv("data/example2_y.csv")
summary(y)
table(y)
dim(y)

#reshape x wide
x <- reshape(x, direction="wide", timevar="colnum", idvar="rownum")

df <- merge(x, y, by="rownum")
names(df)
dim(df)

summary(glm(y ~ val.1 + val.2, data=df, family=binomial("logit")))

