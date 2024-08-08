#!/usr/bin/env Rscript

# This global processing script is derived from the global processing notebook 
#the input can be the iso3 code (3-character) for one or multiple countries 

library("terra")
library("dplyr")
library("sf")
#install.packages("s3")
library("s3")

#To test, we define the variables manually. For final version, run the commented out section below
#iso3 <-"ECU"
gediwk <- 24

#-------------------------------------------------------------------------------
args = commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
} else if (length(args)>=1) {
  
  iso3 <- args[1]  #country to process
  #gediwk <- args[2]   #the # of weeks GEDI data to use
  #mproc <- as.integer(args[3])  #the number of cores to use for matching
}
#-------------------------------------------------------------------------------

cat("Step 0: Loading global variables for", iso3,"with wk", gediwk, "data \n")

#f.path <- "/projects/my-public-bucket/GEDI_global_PA_v2/"
f.path <- "s3://maap-ops-workspace/shared/leitoldv/GEDI_global_PA_v2/"

matching_tifs <- c("wwf_biomes","wwf_ecoreg","lc2000","d2roads", "dcities","dem",
                   "pop_cnt_2000","pop_den_2000","slope", "tt2cities_2000", "wc_prec_1990-1999",
                   "wc_tmax_1990-1999","wc_tavg_1990-1999","wc_tmin_1990-1999" )

ecoreg_key <- read.csv(s3_get(paste(f.path,"wwf_ecoregions_key.csv",sep="")))
#unlink(s3_get(paste(f.path,"wwf_ecoregions_key.csv",sep="")))

allPAs <- readRDS(s3_get(paste(f.path,"WDPA_shapefiles/WDPA_polygons/",iso3,"_PA_poly.rds",sep="")))

MCD12Q1 <- rast(s3_get(paste(f.path,"GEDI_ANCI_PFT_r1000m_EASE2.0_UMD_v1_projection_defined_6933.tif",sep="")))
crs(MCD12Q1)  <- "epsg:6933"

world_region <- rast(s3_get(paste(f.path,"GEDI_ANCI_CONTINENT_r1000m_EASE2.0_UMD_v1_revised_projection_defined_6933.tif",sep="")))
crs(world_region)  <- "epsg:6933"

s3_get_files(c(paste(f.path,"WDPA_countries/shp/",iso3,".shp",sep=""),
              paste(f.path,"WDPA_countries/shp/",iso3,".shx",sep=""),
              paste(f.path,"WDPA_countries/shp/",iso3,".prj",sep=""),
              paste(f.path,"WDPA_countries/shp/",iso3,".dbf",sep="")),confirm = FALSE)

adm <- st_read(s3_get(paste(f.path,"WDPA_countries/shp/",iso3,".shp",sep="")))
adm_prj <- project(vect(adm), "epsg:6933")

load(s3_get(paste(f.path,"rf_noclimate.RData",sep="")))
#source(s3_get(paste(f.path,"matching_func.R",sep="")))
#source(s3_get(paste(f.path,"matching_func_2024.R",sep="")))


# STEP1. Create 1km sampling grid with points only where GEDI data is available; first check if grid file exist to avoid reprocessing 
#if(!file.exists(paste(f.path,"WDPA_grids/",iso3,"_grid_wk",gediwk,".RDS", sep=""))){
  cat("Step 1: Creating 1km sampling grid filter GEDI data for", iso3,"\n")
  GRID.lats <- rast(s3_get(paste(f.path,"EASE2_M01km_lats.tif", sep="")))
  GRID.lons <- rast(s3_get(paste(f.path,"EASE2_M01km_lons.tif", sep="")))
  GRID.lats.adm   <- crop(GRID.lats, adm_prj)
  GRID.lats.adm.m <- mask(GRID.lats.adm, adm_prj)
  GRID.lons.adm   <- crop(GRID.lons, adm_prj)
  GRID.lons.adm.m <- mask(GRID.lons.adm, adm_prj)
  rm(GRID.lats, GRID.lons, GRID.lats.adm, GRID.lons.adm)
  
  #1.3) extract coordinates of raster cells with valid GEDI data in them
  gedi_folder <- paste(f.path,"WDPA_gedi_L4A_tiles/",sep="")
  tileindex_df <- read.csv(s3_get(paste(f.path,"vero_1deg_tileindex/tileindex_",iso3,".csv", sep="")))
  iso3_tiles <- tileindex_df$tileindexiso3_tiles <- tileindex_df$tileindex
    
  GRID.coords <- data.frame()
  for(i in 1:length(iso3_tiles)){
    
    iso3_tile_in <- paste("tile_num_",iso3_tiles[i],sep="")
    
    #if(!file.exists(paste(gedi_folder,iso3_tile_in,"_L4A.gpkg",sep=""))){
    #    print(paste(iso3_tile_in," does not exist",sep=""))
    #    } else {
    print(paste(iso3_tile_in," processing",sep=""))
    print(paste(gedi_folder,iso3_tile_in,"_L4A.gpkg",sep=""))
  }
