# population size in number of individuals

demography <- function(generation){
  
  population_size <- array(NA,length(generation))
  
  population_size_0 <- 2000 #(in number of genes)
  growth_rate <- -0.00460517
  time <- 500
  	  

  # constant size
  for (gen in 1:length(generation)){
    if (generation[gen]<=time){
	population_size[gen] <- population_size_0 * exp(growth_rate * generation[gen])
    }else{
	population_size[gen] <- population_size_0 * exp(growth_rate * time)
    }
  }

  return(population_size)
}
