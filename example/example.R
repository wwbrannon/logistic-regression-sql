## Example 1
df <- read.csv("data.csv")
summary(df)
dim(df)

table(df$admit, useNA="ifany")
table(df$rank, useNA="ifany")

#so that the sql is simpler, we'll treat rank as a continuous variable
summary(glm(admit ~ gre + gpa + rank, data=df, family=binomial("logit")))

