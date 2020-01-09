#####################################################
##
## Oracle R Enterprise - Short Demo Script
## (c)2015 Oracle
##
#####################################################


#-----------------------
# EMBEDDED R EXECUTION
#-----------------------
library(ORE)

options(ore.warn.order=FALSE)

ore.connect(user="moviedemo",sid="orcl",host="localhost",password="welcome1", all=TRUE)


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

ore.disconnect()
## End of File

