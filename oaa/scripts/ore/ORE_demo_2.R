#####################################################
##
## Oracle R Enterprise - Short Demo Script
## (c) Oracle
##
#####################################################

# If you are new to R, here are a few examples using open source R to highlight
# R's statistics and visualization capabilities

#-- Explore a data set

?LifeCycleSavings           # see documentation
class(LifeCycleSavings)     # What is the class of this object...a data.frame
head(LifeCycleSavings)      # see the first few rows of data
summary(LifeCycleSavings)   # get summary statistics on the data set

#-- Build a predictive model

?lm      # Bulit-in function documentation...see examples at end of each doc page

lm.SR <- lm(sr ~ pop15 + pop75 + dpi + ddpi, data = LifeCycleSavings)
summary(lm.SR)
plot(lm.SR)

#-- 3D Rotational Plots

library(rgl)
open3d()
x <- sort(rnorm(5000))
y <- rnorm(5000)
z <- rnorm(5000) + atan2(x,y)
plot3d(x, y, z, col=rainbow(1000))

example(persp3d)


#-- Customized graphs - histogram example

set.seed(25)
x <- rchisq(1000, df = 3)

hist(x, freq = FALSE, ylim = c(0, 0.25),
     main="Histogram of Random Chi Square Distribution",
     xlab="Values for X",
     ylab="Values for Y")
curve(dchisq(x, df = 3), col = 2, lty = 2, 
      lwd = 2, add = TRUE)
legend(5,0.15,"model distribution", 
       col="red", lty=2)


#-- Bubble Plot with ggplot2

library(ggplot2)
crime <-read.csv("http://datasets.flowingdata.com/crimeRatesByState2005.tsv", header=TRUE, sep="\t")
ggplot(crime, aes(x=murder, y=burglary, size=population, label=state),guide=FALSE)+
  geom_point(colour="white", fill="red", shape=21)+  #scale_size_area(c(1,25))+
  scale_x_continuous(name="Murders per 1,000 population", limits=c(0,12))+
  scale_y_continuous(name="Burglaries per 1,000 population", limits=c(0,1250))+
  geom_text(size=4)+
  theme_bw()


#-- Stock time series data

library(tseries)
open(url("http://quote.yahoo.com"))
x <- get.hist.quote(instrument = "orcl", start = "2008-01-01",
                    quote = c("Close","Hi","Low"))
plot(x$Close, main="Oracle (ORCL) from January 1, 2008")


#---------------------------------------
# O R A C L E   R   E N T E R P R I S E
#---------------------------------------

#-----------------------
# TRANSPARENCY LAYER
#-----------------------

library(ORE)
options(ore.warn.order=FALSE)
ore.connect(user = "ruser", host = "130.61.60.94", password = "ruser#123ruser#123", 
            service_name = "pdb1.sub03010825490.devopsvcn.oraclevcn.com",all=TRUE) 

#-- List tables and views available in the database schema

ore.ls()        



#-- The following operations all occur in Oracle Database
#-- Computations occur via SQL in the database -- achieving scalability and performance

#-- Projection / column selection using standard R Syntax

names(ONTIME_S)

df <- ONTIME_S[,c("YEAR","DEST","ARRDELAY")]
dim(df)

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



#-----------------------
# EMBEDDED R EXECUTION
#-----------------------

# Random Red Dots

RandomRedDots <- function(numDots=100){
  id <- 1:10
  print(plot( 1:numDots, rnorm(numDots), pch = 21, 
              bg = "red", cex = 2 ))
  data.frame(id=id, val=id / 100)
}

#-- Execute R function straight from R
RandomRedDots(500)  

#-- Now execute same function at the database server, passing an argument
res <- NULL
res <- ore.doEval(RandomRedDots, numDots=200)
res

#-- Store function in R Script repository
ore.scriptDrop("RandomRedDots")
ore.scriptCreate("RandomRedDots", RandomRedDots)

#-- Execute function in the database by name 
res <- NULL
res <- ore.doEval(FUN.NAME="RandomRedDots", numDots=200)
res


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

## End of File

