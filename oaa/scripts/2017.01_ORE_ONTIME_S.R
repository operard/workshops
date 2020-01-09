#####################################################
##
## Oracle R Enterprise - Short Demo Script
## January 2017, Olivier Perard
## (c)2015 Oracle
##
#####################################################

#---------------------------------------
# O R A C L E   R   E N T E R P R I S E
#---------------------------------------

#-----------------------
# TRANSPARENCY LAYER
#-----------------------
# Load the ORE client packages
library(ORE)

options(ore.warn.order=FALSE)

ore.connect(user="moviedemo",sid="orcl",host="localhost",password="welcome1", all=TRUE)

#-- List tables and views available in the database schema
ore.ls()        

ore.disconnect()

ore.connect(user="moviedemo",sid="orcl",host="localhost",password="welcome1")
ore.sync(table="ONTIME_S")
ore.attach()

ore.ls()

#-- The following operations all occur in Oracle Database
#-- Computations occur via SQL in the database -- achieving scalability and performance

#-- Projection / column selection using standard R Syntax

names(ONTIME_S)

df <- ONTIME_S[,c("YEAR","DEST","ARRDELAY")]
class(df)
head(df)
dim(df)

# Filter per columns 1, 4, 23
head(ONTIME_S[,c(1,4,23)])
# Remove Columns 5 through 26
head(ONTIME_S[,-(5:26)])
# Remove Columns 1 through 22
head(ONTIME_S[,-(1:22)])

# Row Selection

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
merge (TEST_DF1, TEST_DF2,                        # Join data using overloaded merge function
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


#-- Switch to SQL Developer to execute same function from SQL

#-- Use Group Apply to build one model per destination airport

dim(ONTIME_S)
ONTIME_S$DEST <- substr(as.character(ONTIME_S$DEST),1,3)
DAT <-   ONTIME_S[ONTIME_S$DEST %in% c("BOS","SFO","LAX","ORD","ATL","PHX","DEN"),]
dim(DAT)

modList <- ore.groupApply(X=DAT,
                          INDEX=DAT$DEST,
                          function(dat) {
                            lm(ARRDELAY ~ DISTANCE + DEPDELAY, dat)
                          })

modList_local <- ore.pull(modList)
summary(modList_local$BOS) ## return model for BOS


ore.disconnect()
## End of File
