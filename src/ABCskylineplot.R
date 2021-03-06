################################################################################
#
#                     SCRIPT FOR ABC SKYLINE PLOT
#
################################################################################

################################################################################
# by Miguel Navascués
################################################################################

# USAGE
#  R --no-save --args num_of_sims 10000 proportion_of_sims_kept 0.1 seed 1234 < ABCskylineplot.R

# REQUIREMENTS:

# [ ] diyabc-comput-XXX (DIYABC command line executable): www1.montpellier.inra.fr/CBGP/diyabc/
#     default location in bin folder
# [ ] R-package abc      for ABC analysis
# [ ] R-package adegenet for reading genepop files
# [ ] R-package graphics for plotting PCA     
# [ ] R-package gplots   for plotting 2D histograms     
# [ ] R-package hexbin   for hexbin plots of summary statistic PCA
# [ ] R-package batch    for running R script from command line with arguments

library(abc);library(adegenet);library(graphics);library(gplots);library(hexbin);library(batch);require(grid)

# REQUIREMENTS for analysing pseudo observed data (simulated data):

# [ ] fastsimcoal: cmpg.unibe.ch/software/fastsimcoal/
#     default location in bin folder
# [ ] .simcoal files (ad-hoc format which specify a given demographic scenario, 
#                     i.e. the simcoal input file without the genetic information,
#                     see examples under src/Scenari)

#NB: currently only implemented for diploid autosomal microsatellites

# TODO
#
# * Analysis scaled to Ne_tau (aDNA or prior on mutation rate per year)
# * other DNA markers
# * Add check of presence of all necessary files on folder
# * Add upper time limit to skyline plot based on the expected TMRCA calculated
#   using Wojdyla et al. 2012 algorithm (http://dx.doi.org/10.1016/j.tpb.2011.09.003) ???

# STEP 0. SETTINGS (OPTIONS, INPUT DATA, CONSTANT VALUES, PRIORS, ETC)
#======================================================================

# ON ABC SIMULATIONS
#--------------------
num_of_sims              <- 100000#0      # Number of simulations
proportion_of_sims_kept  <- 0.01       # Tolerance level for ABC
seed                     <- 6132       # For random number generation (in R, DIYABC & fastsimcoal)

# ON DEMOGRAPHIC & MUTATIONAL MODEL
#----------------------------------
num_of_points      <- 30    # number of points to draw skyline plot

num_of_time_samples <- 4

# prior on number of periods
prior_PERIODS      <- "constant" # "Poisson" or "constant" (num_of_periods = max_num_of_periods)
Poisson_lambda     <- log(2)     # log(2) for 50% constant - 50% non-constant demography 
max_num_of_periods <- 2          # max number of periods to simulate

prior_on_theta <- F

if (prior_on_theta){
  # prior on theta
  prior_THETA      <- "LU"    # "LU" for log-uniform, "UN" for uniform
  prior_THETA_min  <- 1E-3    # minumum theta=4Nu (MUST: prior_THETA_min>=4*MUTRATE)
  prior_THETA_max  <- 1E4     # maximum theta=4Nu
  MUTRATE          <- prior_THETA_min/4
  
  # prior on time of population size changes
  prior_TAU            <- "LU"    # "LU" for log-uniform, "UN" for uniform
  prior_TAU_min        <- MUTRATE # maximum time (measured in number of mutations)
  prior_TAU_max        <- 4      # maximum time (measured in number of mutations)

  # prior on mutational model
  prior_MUTRATE         <- "UN"   # "LU" for log-uniform, "UN" for uniform, "GA" for gamma
  prior_MUTRATE_min     <- MUTRATE
  prior_MUTRATE_max     <- MUTRATE
  prior_MUTRATE_mean    <- 0
  prior_MUTRATE_shape   <- 0
  prior_MUTRATE_i_min   <- prior_MUTRATE_min
  prior_MUTRATE_i_max   <- prior_MUTRATE_max
  prior_MUTRATE_i_mean  <- "Mean_u"
  prior_MUTRATE_i_shape <- 0 # set shape to 0 if you want all individual loci to take the same value (= mean)
}else{
  # prior on Ne
  prior_N      <- "LU"    # "LU" for log-uniform, "UN" for uniform
  prior_N_min  <- 1    # minumum theta=4Nu (MUST: prior_THETA_min>=4*MUTRATE)
  prior_N_max  <- 1E6  # maximum theta=4Nu

  # prior on time of population size changes
  prior_T            <- "LU"    # "LU" for log-uniform, "UN" for uniform
  prior_T_min        <- 1     # maximum time (measured in number of mutations)
  prior_T_max        <- 5000  # maximum time (measured in number of mutations)
  
  
  # prior on mutational model
  prior_MUTRATE         <- "LU"   # "LU" for log-uniform, "UN" for uniform, "GA" for gamma
  prior_MUTRATE_min     <- 0.0011
  prior_MUTRATE_max     <- 0.0021
  prior_MUTRATE_mean    <- 0
  prior_MUTRATE_shape   <- 0
  prior_MUTRATE_i_min   <- prior_MUTRATE_min
  prior_MUTRATE_i_max   <- prior_MUTRATE_max
  prior_MUTRATE_i_mean  <- "Mean_u"
  prior_MUTRATE_i_shape <- 0 # set shape to 0 if you want all individual loci to take the same value (= mean)
}



prior_GSM         <- "UN"   # "LU" for log-uniform, "UN" for uniform, "GA" for gamma
prior_GSM_min     <- 0 # Set minimum and maximum to 0 if you want a Stepwise Mutation Model
prior_GSM_max     <- 1
prior_GSM_mean    <- 0
prior_GSM_shape   <- 0
prior_GSM_i_min   <- prior_GSM_min
prior_GSM_i_max   <- prior_GSM_max
prior_GSM_i_mean  <- "Mean_P"
prior_GSM_i_shape <- 0 # set shape to 0 if you want all individual loci to take the same value (= mean)

prior_SNI         <- "LU"   # "LU" for log-uniform, "UN" for uniform, "GA" for gamma
prior_SNI_min     <- 0# MUTRATE*0.00001 # Set minimum and maximum to 0 if you want no SNI
prior_SNI_max     <- 0# MUTRATE
prior_SNI_mean    <- 0
prior_SNI_shape   <- 0
prior_SNI_i_min   <- prior_SNI_min
prior_SNI_i_max   <- prior_SNI_max
prior_SNI_i_mean  <- "Mean_u_SNI"
prior_SNI_i_shape <- 0 # set shape to 0 if you want all individual loci to take the same value (= mean)

# ON DIRECTORY AND FILES & TARGET DATA
#--------------------------------------

# Set working directory
directory <- getwd()

# Set project name (affects subdirectory and output files names)
project   <- "test"

# Set to FALSE to keep all DIYABC output files
# (most important files, such as the one containing reference table are always kept)
remove_DIYABC_output <- T
DIYABC_exe_name      <- "bin/diyabc2.1.0" #"/home/bin/Diyabc/2.1.0/x64/bin/general"
run_in_cluster       <- F
num_of_threads       <- 12 # maximal number of the threads
batch_size           <- 1 # number of particles per simulation batch (-g option)

# Plotting
# Number of PC from summary statistics PCA to plot
maxPCA <- 7
# Graphic output file format (possible values: pdf, png, svg)
g_out <- "pdf"

# specify whether target data will be simulated or will be read from files
simulated_target_data <- F
# Microsatellite data info
motif <- 1 # a single value if all loci have the same repeat length
           # or a factor with each motif length in the same order as in
           # inputfile
range <- 1000 # a single value or a factor for a different value for each locus

parseCommandArgs()
if (!simulated_target_data){ #specify files for target data     
  # Genepop input file. NB: use .gen extension
  if (!exists("inputfile")) inputfile <- "test.gen" #place it in data folder
}else{ #specify scenarios for simulating target data
  scenarios_number <- 1:27 #

  inputfile <- "simulated_data_genepop.gen"
  
  number_of_replicates <- 1000 # simulations to perform for each scenario
  sample_size          <- 50
  num_of_loci          <- 30
  true_mutrate         <- 1e-3
  true_gsm             <- c(0.00,0.22,0.74)
  
  # Set to FALSE to keep fastsimcoal output files
  remove_fastsimcoal_output <- T
  fastsimcoal_exe_file      <- "fastsimcoal"
  quiet                     <- T # run fastsimcoal in quiet mode

  # create BEAST (i.e. BEAUTi) input file
  do_BEAST_input            <- T
}
parseCommandArgs()
setwd(directory) 

# 0. Additionnal operations related to settings
source(file="src/ABCskylineplot.step0.R", echo = T, print.eval = T)

# 0.5 PERFORM SIMULATIONS TO ACT AS TARGET DATA
source(file="src/ABCskylineplot.step0.5.R", echo = T, print.eval = T)

# 1. SAMPLE MODEL (NUMBER OF PERIODS) FROM PRIOR & RUN SIMULATIONS (with DIYABC)
source(file="src/ABCskylineplot.step1.R", echo = T, print.eval = T)
      
# 2. CALCULATE SUMMARY STATISTICS FOR TARGET DATA
source(file="src/ABCskylineplot.step2.R", echo = T, print.eval = T)
     
# 2.5 PERFORM PCA ON SUMMARY STATISTICS
source(file="src/ABCskylineplot.step2.5.R", echo = T, print.eval = T)

# 3. ABC & SKYLINE PLOT
source(file="src/ABCskylineplot.step3.R", echo = T, print.eval = T)


# Makes some noise when it finishes:      
if(.Platform$OS.type == "unix") system( "beep -r 2" )


