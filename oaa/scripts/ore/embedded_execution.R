# script to show embedded execution capabilities
#

# do.eval() example
res <- ore.doEval(function (num=10, scale=100)
                 {ID <- seq(num)
                  data.frame(ID=ID,
                  RES = ID / scale)}
                 )
# database uses rq.Apply() to spawn a R Engine to execute the script
# res is a serialized object
Local_res <- ore.pull(res)
class(res)
class(Local_res)


# doEval specifying a return value as an ore.frame
res <- ore.doEval(function (num=10, scale=100)
                  {ID <- seq(num)
                   data.frame(ID=ID,
                   RES = ID / scale)},
                 FUN.VALUE = data.frame(ID = 1, RES = 1)
)
# now res is an ore.frame (unordered)
class(res)
res
rownames(res) <-res$ID
res


library(kernlab)
data(spam)
s<-spam
names(s)
s$TS<-as.integer(1:nrow(s)+1000)
s$USERID<-rep(1:50+350, each=2, len=nrow(s))
ore.drop(table='SPAM_PK')
ore.drop(table='SPAM_NOPK')
ore.create(s[,c(59:60,1:28)],table='SPAM_PK')
ore.create(s[,c(59:60,1:28)],table='SPAM_NOPK')

head(SPAM_PK[,1:5])
head(SPAM_NOPK[,1:5])



# SQL
#select TABLE_NAME from USER_TABLES;
#alter table SPAM_PK add constraint SPAM_PK primary key ("USERID","TS")
ore.exec('alter table SPAM_PK add constraint SPAM_PK primary key ("USERID","TS")')

# check if they are ordered now
head(SPAM_PK[,1:5])
head(SPAM_NOPK[,1:5])

# sync proxy objects to get changes
ore.sync()

# now it's ordered
head(SPAM_PK[,1:5])
head(SPAM_NOPK[,1:5])

# inspecting the scripts in the repository from R
ore.sync(table = "RQ_SCRIPTS", schema = "SYS")
ore.attach(schema = "SYS")
row.names(RQ_SCRIPTS) <- RQ_SCRIPTS$NAME

RQ_SCRIPTS[1]    # script names
RQ_SCRIPTS["RQG$plot1d",]   # see the script



# doEval with a script stored in the repository
ore.scriptDrop("SampleScript1")
ore.scriptCreate("SampleScript1",
                 function (num=10, scale=100)
                 {ID <- seq(num)
                 data.frame(ID=ID,
                            RES = ID / scale)}
)
  
res <- ore.doEval(FUN.NAME="SampleScript1", num = 20, scale=100)
class(res)
res



# execute a linear regression model loading data from DB to memory
ore.is.connected()      #session connected
# but inside a function ...

ore.doEval(function(){
  ore.is.connected()}
) # returns FALSE

ore.doEval(function(){
  ore.is.connected()},
  ore.connect=TRUE
  ) # returns TRUE

ore.doEval(function(){
  library(ORE)
  #ore.connect(user, sid, host, password)
  ore.connect("ruser","orcl","localhost", "welcome1")
  ore.is.connected()}
) # returns TRUE

mod <- ore.doEval(
  function () {
    ore.sync(table="ONTIME_S")
    dat <- ore.pull(ore.get("ONTIME_S"))
    lm(ARRDELAY ~ DISTANCE + DEPDELAY, dat)
  },
  ore.connect = TRUE
)
mod_local <- ore.pull(mod)
class(mod_local)
summary(mod_local)


# now the same lm using ore.lm, no need to copy data to R session all happens in the database
mod <- ore.doEval(
  function () {
    ore.connect("ruser","orcl","localhost", "welcome1", all=TRUE)
    ore.lm(ARRDELAY ~ DISTANCE + DEPDELAY, ONTIME_S)
  }, ore.connect=TRUE
)
mod_local <- ore.pull(mod)
class(mod_local)
summary(mod_local)



# using ore.tableApply() to build a GLM regression model

modCoef <- ore.tableApply(
  ONTIME_S[,c("ARRDELAY","DISTANCE","DEPDELAY")],  # data ore.frame, this is called x in the function
  family=gaussian(),                               # arguments to the function
  function(x,family) {
    mod <- glm(ARRDELAY ~ DISTANCE + DEPDELAY,
               data=x, family = family)
    ore.save(mod,name='modeloglm', description='Modelo GLM')
    coef(mod)                                      # return coeficients, not the model
                                                   # the model is stored in the DB for future use
  }, ore.connect=TRUE
)
modCoef
ore.datastoreSummary(name='modeloglm')

# using ore.rowApply
# 1. data for the function
# 2. define function
# 3. define return value
# 4. number of rows to process at one time (optional, by default 1)

irii <- as.ore(iris)
class(irii)
ore.create(irii,table="IRIS")
nrow(irii)

ore.rowApply(IRIS, function(dat) dat, FUN.VALUE = IRIS)
ore.rowApply(IRIS, function(dat) dat)
ore.rowApply(IRIS, function(dat) nrow(dat), rows=4)
ore.rowApply(IRIS, function(dat) nrow(dat))

# ore.groupApply() examples
# build models in parallel on partitions of data set
# 
# install.packages("biglm",repos = 'http://cran.us.r-project.org')

modList <- ore.groupApply(
  ONTIME_S,                      # data
  INDEX=ONTIME_S$DEST,           # group by destinations, one model by destination
  function(dat){
    library(biglm)               # using a opensource CRAN package
    biglm(ARRDELAY ~ DISTANCE + DEPDELAY, dat)
  }
)
modList_local <- ore.pull(modList)  # pull all the list of generated models
summary(modList_local$BOS)
summary(modList_local$JFK)

#
# ore.indexApply run a function for N times

res <- ore.indexApply(10,                                   # number of times to execute
                      function (i, scale = 100)             # i is the index from 1 to 10
                        data.frame(ID=i, RES=i/scale, HID=i*10),
                      FUN.VALUE = data.frame(ID=1, RES=1, HID=1)   # specify the output format
                      )
class(res)
res<-ore.pull(res)
res[order(res$ID),c("ID","RES")]



# writing graphics to a file

ore.doEval(function(){
  pdf("/home/oracle/my_graph.pdf")          # path local to the database server
  set.seed(25)
  x<-rchisq(1000, df=3)
  hist(x, freq = FALSE, ylim = c(0, 0.25))
  dev.off()                                 # important to stop graph recording
  TRUE
})


# embedded execution of graphs
# in R
hist(IRIS[,"Sepal.Length"])
pairs(IRIS[,c("Sepal.Length","Petal.Length")])

# in SQL developer, connect as ruser, open a SQL worksheet and run
#select *  from table(rqTableEval(cursor(select "Sepal.Length" from IRIS_TABLE),NULL,'PNG','RQG$hist'));
#select *  from table(rqTableEval(cursor(select "Sepal.Length", "Petal.Length" from IRIS_TABLE),NULL,'PNG','RQG$pairs'));
#
# then in the results, double click BLOB and select checkbox view as image, also save as im
