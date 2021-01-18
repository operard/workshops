library(ORE)

# Connect to Database with all tables
ore.connect(user = "ruser", host = "130.61.215.115",
            password = "ruser",
            service_name = "pdb1.sub12041412512.bdcevcn.oraclevcn.com",all=TRUE) 

# List all tables
ore.ls()

#-- The following operations all occur in Oracle Database
#-- Computations occur via SQL in the database -- achieving scalability and performance

#-- Projection / column selection using standard R Syntax

names(ONTIME_S)

#column selection
df <- ONTIME_S[,c("YEAR","DEST","ARRDELAY")]
dim(df)
View(df)

head(df)
head(ONTIME_S[,c(1,4,23)])
head(ONTIME_S[,-(5:26)])


#-- Selection / row filtering using standard R Syntax

df1 <- df[df$ARRDELAY>20,]           # Simple filter predicate
head(df1,3)

df2 <- df[df$ARRDELAY>20,c(1,3)]     # Filter rows and columns
head(df2,3)

df3 <- df[df$ARRDELAY>20 | df$DEST=="BOS",1:3]   # Complex predicate with column filter
head(df3,6)

#-- Join / merge data using overloaded R merge function

df1 <- data.frame(x1=1:5, y1=letters[1:5])        # Create on-the-fly data.frames
df2 <- data.frame(x2=5:1, y2=letters[11:15])
merge (df1, df2, by.x="x1", by.y="x2")            # Join the data in open source R

ore.drop(table="TEST_DF1")                        # Drop DB tables to recreate them
ore.drop(table="TEST_DF2")           
ore.create(df1, table="TEST_DF1")                 # Create DB table from R data.frames
ore.create(df2, table="TEST_DF2")
all <- merge (TEST_DF1, TEST_DF2,                        # Join data using overloaded merge function
       by.x="x1", by.y="x2")

#-- Aggregation using overloaded R aggregate function
#--   This equates to a "group by" query in SQL

aggdata <- aggregate(ONTIME_S$DEST, 
                     by = list(ONTIME_S$DEST), 
                     FUN = length)
class(aggdata)
head(aggdata)

aggdata <- aggregate(ONTIME_S$ARRDELAY, 
                     by = list(ONTIME_S$DEST, ONTIME_S$UNIQUECARRIER), 
                     FUN = sd, na.rm=TRUE)
names(aggdata) <- c("DEST","UNIQUECARRIER","SD")
head(aggdata,10)


#-- Use the in-database version of R's lm function to build a regression model
#-- Model building - regression

dim(ONTIME_S)

mod <- ore.lm(ARRDELAY ~ DISTANCE + DEPDELAY, ONTIME_S)
summary(mod)






res <-    ore.doEval(function (num = 10, scale = 100) { 
  ID <- seq(num)               
  data.frame(ID = ID, RES = ID / scale)               
  },      
  FUN.VALUE = data.frame(ID = 1, RES = 1)) 

class(res) 

res

# Create SQL script: 20150710_Short_Demo_Script.sql

# Execute the function
ore.doEval(FUN.NAME='RandomRedDots');


#




# ------------------------------------
# random forest : Not to execute 
options(ore.parallel=8)


df <- ONTIME_S[,c("DAYOFWEEK","DEPDELAY","DISTANCE",
                  "UNIQUECARRIER","DAYOFMONTH","MONTH")]
df <- df[complete.cases(df),]
mod <- ore.randomForest(DAYOFWEEK~DEPDELAY+DISTANCE+UNIQUECARRIER+DAYOFMONTH+MONTH, df, ntree=100,groups=20)
ans <- predict(mod, df, type="all", supplemental.cols="DAYOFWEEK")
head(ans) 

# Access to the DataStore
ore.datastore()
# ore.datastoreSummary()

ore.disconnect()


