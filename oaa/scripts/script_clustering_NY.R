##############################################################################
### NYC Taxi Trip Segmentation Script
### This is a small sample of the original NYC Taxi Data
### The original dataset includes trip records from all trips completed
### in yellow and green taxis in NYC in 2013 to 2015. Records include
### fields capturing pick-up and drop-off dates/times, pick-up and drop-off
### locations, trip distances, itemized fares, rate types, payment types, and
### driver-reported passenger counts.
### More information at:
### http://www.nyc.gov/html/tlc/html/about/trip_record_data.shtml
###
### Script by Marcos Arancibia
### Last Revision: 05/20/2016
###
##############################################################################

## Load ORAAH's libraries
library(ORCH)

### Loading data from CSV into R (for this local simulation only)
### Is is expected to already be as a HIVE table, which we will do afterwards
### This sample contains only trips considered slow, of less than 20mph
lcl.nyct_20mph <- read.csv("~/Downloads/taxi dropoff airports less than 20mph.csv")

### Adding a unique ID number to the original data so we can link
### the prediction back to the original data
lcl.nyct_20mph$id <- (1:nrow(lcl.nyct_20mph))

### Connect to the HIVE Server, making sure no other connection is active
ore.disconnect()
ore.connect(type='HIVE',host='bigdatalite.localdomain',
            user='oracle',password='welcome1',
            port='10000',all=TRUE)

### Check all the tables available in HIVE
ore.ls()

### Create a new table in HIVE that is going to store the NYC Tables
### This will run automatically a Map-Reduce job on the cluster
### A warning is normal and it's an indication that the names of the
### columns were converted to make them compatible with HIVE
ore.create(lcl.nyct_20mph,table="nyc20m")


### Check all the tables available in HIVE
ore.ls()

### Verify variable names of the variables from the file
names(nyc20m)

### Get basic statistics from tip_amount (slow Map-Reduce process)
summary(nyc20m$tip_amount)

### Check the first 5 records of the dataset
head(nyc20m,5)

### Connects to Spark and create an exclusive Context
### Making sure first that there is no other ORAAH Spark session
### active for the current user
spark.disconnect()
spark.connect(master='yarn-client',
              memory='2G',
              dfs.namenode='bigdatalite.localdomain',
              spark.ui.showConsoleProgress = 'false')

### Create a Clustering Model using Spark MLlib k-means algorithm ###
### Step 1 - Define the Formula that contains which columns to
###          use for building the Clusters.
form_seg <- ~ pickup_hour_of_day + trip_distance

### STEP 2 - Build a k-Means Clustering Model with ORAAH's API into
###          Spark MLlib's k-means, orch.ml.kmeans, using as input the
###          HIVE table. We will specify 6 Clusters to be built
system.time({
  seg_model  <- orch.ml.kmeans(formula = form_seg,
                                 data = nyc20m,
                                 nParallelRuns = 2,
                                 maxIterations = 50,
                                 nClusters = 6)
})

### STEP 3 - Score the k-Means Clustering model using ORAAH's API predict
###          for Spark MLlib's k-means, which is done in-memory.
###          We will use the same data in HIVE to score, and the only
###          additional column we want other than the predicted Cluster itself
###          is the unique ID so that we can join the predictions with the data
###          The output is still going to be an in-memory RDD object
system.time(
pred   <- predict(seg_model,
                  newdata = nyc20m,
                  supplemental = c("id"))
)

### STEP 4- Write the Resulting in-memory RDD object to HDFS as a CSV
###         We need to map the result back into HIVE to join with the
###         original data
system.time(
  hdfs.write(pred, outPath = "nycTaxiClustering",overwrite = TRUE)
)

### Loads the Metadata from the resulting HDFS CSV file
### We will put the option force=TRUE in case we create several
### versions of the scoring, to be sure we update the underlying
### metadata at every run
seg_hdfs_nyt20m <- hdfs.attach("nycTaxiClustering",force=TRUE)

### Change the names of the resulting columns to "id" and "cluster"
hdfs.meta(seg_hdfs_nyt20m, names=c('id','cluster'))

### Pushes the Result from HDFS to HIVE
### We delete the HIVE table with the same name if it exists
ore.drop(table='nyc20m_seg')
output <- hdfs.toHive(seg_hdfs_nyt20m, table='nyc20m_seg')

### Check that both tables are available in HIVE
ore.ls()

### Check the number of records in each cluster
table(nyc20m_seg$cluster)

### Views the names of the columns in both datasets
names(nyc20m_seg)
names(nyc20m)

### Joins both HIVE tables by unique ID into a new temporary HIVE VIEW
nyc20m_join <- merge(nyc20m,nyc20m_seg,by='id')

### Create a final HIVE table from the temporary one, making sure to drop
### the table if there was any previous one with the same name
ore.drop(table='nyc20m_final')
ore.create(nyc20m_join,table='nyc20m_final')

### Verify that the final HIVE table is part of the listing now
ore.ls()

### Only needed for this Local example. Usually Big Data Discovery would
### pickup the HIVE table and continue the Visual Analysis
### Brings the final joined dataset locally
loc.nyct_final <- ore.pull(nyc20m_final)
names(loc.nyct_final)

### Export the resulting HIVE table to CSV
write.csv(loc.nyct_final,file="~/Downloads/taxi dropoff airports lt20mph Clustered.csv")

### Check the number of records in each cluster
### First convert the Cluster Number to a Factor
loc.nyct_final$cluster <- as.factor(loc.nyct_final$cluster)

### Check Cluster frequencies
table(loc.nyct_final$cluster)

### Load the library for nice graphics with ggplot2
library(ggplot2)
### Generate several plots across the Clusters for a better
### Understanding of the results, and evaluation of the Cluster
### behaviors
ggplot(loc.nyct_final,aes(x=pickup_hour_of_day,
                          y=trip_distance,
                          color=cluster))+
  geom_jitter(position=position_jitter(1),cex=1)+
  ggtitle("Taxi Riders: Clusters by Hour of Day and Distance")+
  labs(x="Hour of Day",y="Trip Distance") +
  theme(plot.title = element_text(family = "Trebuchet MS",
                                  color="#666666",
                                  face="bold",
                                  size=14, hjust=0)) +
  theme(axis.title = element_text(family = "Trebuchet MS",
                                  color="#666666",
                                  face="bold",
                                  size=12))
 

### From the Chart we see a good potential candidate for a Campaign
### as our Cluster #4, which are the earlier morning to mid-morning
### riders with trips between 5 and 15 miles.
### Segment 1, even though are also early morning riders, seem to ride
### at many hours at night and only very short rides, which most likely
### indicate that these people work at the Airport or at Airlines,
### potentially staying at Airport-based Hotels.

ggplot(loc.nyct_final,aes(x=pickup_hour_of_day,
                          y=trip_ave_speed,
                          color=cluster)) +
       geom_jitter(position=position_jitter(1),cex=1.5)+
       ggtitle("Taxi Riders: Clusters by Hour of Day and Avg Speed")+
       labs(x="Hour of Day",y="Average Speed") +
       theme(plot.title = element_text(family = "Trebuchet MS",
                                       color="#666666",
                                       face="bold",
                                       size=14, hjust=0)) +
       theme(axis.title = element_text(family = "Trebuchet MS",
                                       color="#666666",
                                       face="bold",
                                       size=12))

### In terms of Average Speed, Cluster 4 is on the better performers
### of the group

ggplot(loc.nyct_final,aes(x=trip_distance,
                          y=fare_amount,
                          color=cluster)) +
  geom_jitter(position=position_jitter(0.2),cex=0.9)+
  ggtitle("Taxi Riders: Clusters by Distance and Fare Amount")+
  labs(x="Trip Distance",y="Fare Amount") +
  theme(plot.title = element_text(family = "Trebuchet MS",
                                  color="#666666",
                                  face="bold",
                                  size=14, hjust=0)) +
  theme(axis.title = element_text(family = "Trebuchet MS",
                                  color="#666666",
                                  face="bold",
                                  size=12))
### And on terms of Fare, Cluster 4 spends between $20 and $40


### Faceted histogram for Pickup hour of the day
ggplot(loc.nyct_final, aes(pickup_hour_of_day,fill=cluster)) +
  geom_bar() + facet_wrap(~ cluster) +
  ggtitle("Taxi Riders: Hour of Day frequencies by Cluster")+
  labs(x="Hour of Day",y="Number of Riders") +
  theme(plot.title = element_text(family = "Trebuchet MS",
                                  color="#666666",
                                  face="bold",
                                  size=14, hjust=0)) +
  theme(axis.title = element_text(family = "Trebuchet MS",
                                  color="#666666",
                                  face="bold",
                                  size=12))
### From the Chart we confirm that cluster #4 is the second most frequent
### early morning rider

### Faceted histogram for Trip Distance
ggplot(loc.nyct_final, aes(trip_distance,fill=cluster)) +
  geom_histogram(breaks=seq(0, 40, by = 2))  +
  facet_wrap(~ cluster) +
  ggtitle("Taxi Riders: Trip Distance frequencies by Cluster")+
  labs(x="Trip Distance",y="Number of Riders") +
  theme(plot.title = element_text(family = "Trebuchet MS",
                                  color="#666666",
                                  face="bold",
                                  size=14, hjust=0)) +
  theme(axis.title = element_text(family = "Trebuchet MS",
                                  color="#666666",
                                  face="bold",
                                  size=12))
### From the Chart we confirm that cluster #4 does typically medium rides,
### between 5 and 15 miles with the majority at 10 miles

### Aggregation Summaries
form_agg <- cbind(pickup_hour_of_day,trip_distance,tip_percentage,
                  trip_ave_speed,fare_amount)~ cluster

### Min, Avg, Median and Maxof several variables for each Cluster
aggregate(form_agg,
          data=loc.nyct_final,
          FUN=function(x) c(min=formatC(min(x),digits=2,format='fg'),
                            avg=formatC(mean(x),digits=2,format='fg'),
                            med=formatC(median(x),digits=2,format='fg'),
                            max=formatC(max(x),digits=2,format='fg')))

### Disconnects the Spark and HIVE Sessions
spark.disconnect()
ore.disconnect()


##################################################################

# Additional Code to create 3D Plot and Animated GIF for NYC Taxi Demo
# Inspired by many samples on the Web, including:

# http://www.genomearchitecture.com/2014/03/3d-animations-with-r

# Post-processing using ImageMagick to join the PNGs into a GIF
# http://www.imagemagick.org/script/index.php
# Requires the ability to use an X11 display configuration if on linux
# Load the 3d Interactive Plotting library
library(rgl)

# Load the Resulting Data from the Clustering locally into R's memory
lcl.nyct_20mph <- read.csv("~/Advanced Analytics/Taxi Demo/taxi dropoff airports lt20mph Clustered.csv")

# Need to add 1 number to the Cluster numbers just for the plot colors
# Because it can't take the number 0
lcl.nyct_20mph$cluster <- lcl.nyct_20mph$cluster+1
# Cutoff some of the outliers that only make the graph look worse, for trips >20 miles
lcl.nyct_20mph2 <- lcl.nyct_20mph[lcl.nyct_20mph$trip_distance < 20,]

# Create a custom function that will generate the 3D plot using the Data.frame, the name
# of the cluster variable, the 3 columns with data and the 3 labels we want to pass to
# the Chart
# We are also going to generate one Ellipsis per Cluster to illustrate the Point Clouds
# in the 3d Space, requesting an 80% of Confidence (to make it tighter)

genClusElipsis <- function(df,clusvar,col1,col2,col3,lab1,lab2,lab3){
# Only keep the required columns to make it lighter
df <- df[,c(clusvar,col1,col2,col3)]
# Initialize the separate cluster list and ellipsis list
seg <- vector("list",(length(unique(df[,clusvar]))))
ellips <- vector("list",(length(unique(df[,clusvar]))))
# Plot the basic data in 3D with the cluster as color
plot3d(df[,c(col1,col2,col3)],
       type = 'p', col = df[,clusvar],
       size=8,
       xlab=lab1,
       ylab=lab2,
       zlab=lab3,
       box=FALSE)
# Repeat for each Cluster, build a separate 3D ellipsis
# Centered in the mean of the cluster
   for (i in 1:length(unique(df[,clusvar]))){
     j<-i-1
   seg[[i]] <- subset(df,df[,clusvar]==i)
   ellips[[i]] <- ellipse3d(cov(seg[[i]][,c(col1,col2,col3)])
                        ,centre=c(mean(seg[[i]][,col1]),
                                  mean(seg[[i]][,col2]),
                                  mean(seg[[i]][,col3])),
                        level = 0.80)
   shade3d(ellips[[i]], col = i, alpha = 0.2, lit = FALSE)
# Add title and legend for the Clusters, with fixed numbers that start at 0
   legend3d("top", legend = paste('Clus', 0:(length(unique(df[,clusvar]))-1)),
            title="Taxi Rides to Airports in NYC, slower than 20mph Avg Speeds",
            pch = 16, col = 1:6, cex=2,
            inset=c(0.02),ncol=6,bty="n")
   }
}
# Call the function using the name of the clustering variable, and for example the hour,
# distance and fare amount as the 3 variables desired, and give them the desired labels
# The Graph is going to open in a separate window. You should resize this window to a bigger
# size until the desired resolution to make sure the next step takes the "pictures" of it
# while moving in the desired resolution and aspect. Will probably need to be run twice,
# because when you adjust the window size for the first time, the title and labels are
# going to be all wrong. Running it a second time with the plotting window open works.

genClusElipsis(lcl.nyct_20mph2,
               "cluster",
               "pickup_hour_of_day",
               "trip_distance",
               "fare_amount",
               "Hour",
               "Distance",
               "Fare")

# Set a folder to write the 40 PNG files
setwd("~/Advanced Analytics/Taxi Demo/")
for (i in 1:40) {
  rgl.viewpoint((i+5)*6, i,10)
  filename <- paste("pic", formatC(i, digits = 2, width=4,flag = "00"), ".png", sep = "")
  rgl.snapshot(filename)
}
