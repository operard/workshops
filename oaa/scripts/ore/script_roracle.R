library(ROracle)

## create an Oracle instance and create one connection
drv <- dbDriver("Oracle")

# Create the connection string
host <- "130.61.215.115"
port <- 1521
sid <- "DB19EL7"
service <- "pdb1.sub12041412512.bdcevcn.oraclevcn.com"

connect.string <- paste(
  "(DESCRIPTION=",
  "(ADDRESS=(PROTOCOL=tcp)(HOST=", host, ")(PORT=", port, "))",
  "(CONNECT_DATA=(SERVICE_NAME=", service, ")))", sep = "")

# con <- dbConnect(drv, username = "moviedemo",
#                  password = "welcome1",dbname=connect.string)

con <- dbConnect(drv, username = "ruser",
                 password = "ruser",dbname=connect.string)

## 
rs <- dbSendQuery(con, "select TABLE_NAME from user_tables")
## fetch records from the resultSet into a data.frame
data <- fetch(rs)
## extract all rows
dim(data)
data

## use username/password authentication – if using local database
#con <- dbConnect(drv, username = "moviedemo", password = "welcome1")
## run a SQL statement by first creating a resultSet object
rs <- dbSendQuery(con, "select * from SH.CUSTOMERS")
## fetch records from the resultSet into a data.frame
data <- fetch(rs)
## extract all rows
dim(data)
data

#fetch(rs, n = 5)
#fetch(rs)
# free resources occupied by result set
dbClearResult(rs)
dbUnloadDriver(drv)

