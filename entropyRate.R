################################################################################
#
# Functions related to calculating the Entropy Rate of Finite Markov Processes
#   - Author: Brian Vegetabile, University of California - Irvine
#
################################################################################

################################################################################
# Loading relevent packages

library("stringr")
Rcpp::sourceCpp("/Users/bvegetabile/git/entropyRate/swlz_c.cpp")

################################################################################
# Simulating Finite Markov Chains

#####
# Simulation of a Finite Markov Chain

SimulateMarkovChain <- function(trans_mat, n_sims=100){
  n_states <- nrow(trans_mat)
  states <- seq(1, n_states)
  
  simulations <- matrix(0, nrow = 1, ncol = n_sims)
  
  stat_mat <- CalcEigenStationary(trans_mat = trans_mat)
  init_state <- sample(x = states, 
                       size = 1, 
                       replace = TRUE, 
                       prob = stat_mat)
  simulations[1,1] <- init_state
  
  for (i in 2:n_sims){
    prev_step <- simulations[1,(i-1)]
    next_step <- sample(states, 
                        size = 1, 
                        replace = TRUE, 
                        prob = trans_mat[prev_step,])
    simulations[1, i] <- next_step
  }
  return(as.vector(simulations))
}

################################################################################
# Direct Estimation of Entropy Rate

#####
# Calculation of the observed counts of a finite Markov Chain.  
#
# @examples
# 

CalcTransitionCounts <- function(event_seq, n_states=8){
  obs_trans <- matrix(nrow = n_states, ncol = n_states, 0)
  for (t in 1:(length(event_seq) - 1)){
    obs_trans[event_seq[t], 
              event_seq[t + 1]] <- obs_trans[event_seq[t], event_seq[t + 1]] + 1
  }
  return(obs_trans)
}

CalcTC_Mth_Order <- function(event_seq, state_space, mc_order=1){
  n_obs <- length(event_seq)
  n_states <- length(state_space)
  states <- data.frame(matrix(NA, nrow=n_states, ncol=mc_order))
  for(i in 1:mc_order){
    states[,i] <- state_space
  }
  df_args <- c(expand.grid(states), sep=":")
  vector_states <- do.call(paste, df_args)
  obs_trans <- matrix(0, nrow = length(vector_states), ncol = length(vector_states))
  rownames(obs_trans) <- vector_states
  colnames(obs_trans) <- vector_states 
  
  if(mc_order > 1){
    n_new <- n_obs - (mc_order-1)
    mth_order_seq <- rep(NA, n_new)
    for(i in 1:n_new){
      mth_order_seq[i] <- paste(event_seq[i:(i+(mc_order-1))], collapse = ':')  
    }    
  } else {
    mth_order_seq <- event_seq
  }
  for (t in 1:(length(mth_order_seq) - 1)){
    obs_trans[mth_order_seq[t],
              mth_order_seq[t + 1]] <- obs_trans[mth_order_seq[t], 
                                                 mth_order_seq[t + 1]] + 1
  }
  return(obs_trans)
}


#####
# Calculation of the empirical estimate of the transition matrix of a 
# finite Markov Chain.  

CalcTransitionMatrix <- function(trans_counts){
  mat_dim = ncol(trans_counts)
  row_totals <- rowSums(trans_counts)
  row_tot_mat <- matrix(rep(row_totals, ncol(trans_counts)), 
                        nrow=mat_dim, ncol=mat_dim)
  trans_mat <- trans_counts / row_tot_mat
  trans_mat[trans_mat=="NaN"] <- 0
  return(trans_mat)
}

#####
# Calculation of the Eigenvalue Decomposition of the Transition Matrix as an 
# estimate of the Stationary Distribution
# 
# @examples
# > tm <- matrix(c(0,0,1,1,0,0,0,1,0),3,3,TRUE)
# > CalcEigenStationary(tm)
# [1] 0.3333333 0.3333333 0.3333333

CalcEigenStationary <- function(trans_mat){
  tm_eig <- eigen(t(trans_mat))
  if(any(round(Mod(tm_eig$values),10)==1)){
    lamb1 <- which(abs(tm_eig$values-1) == min(abs(tm_eig$values-1)))
    stat_vec <- tm_eig$vectors[,lamb1] / sum(tm_eig$vectors[,lamb1])
    return(Re(stat_vec))  
  } else{
    stat_vec <- rep(0, nrow(trans_mat))
    return(stat_vec)
  }
}

#####
# Calculation of the Empirical estimate of the Stationary Distribution

CalcEmpiricalStationary <- function(m_chain, state_space){
  emp_stat <- matrix(0, nrow = 1, ncol = length(state_space))
  for(i in 1:length(state_space)){
    emp_stat[1,i] <- length(m_chain[m_chain == state_space[i]]) / length(m_chain)
  }
  return(emp_stat)
}

CalcEmpStat_Mth_Order <- function(event_seq, state_space, mc_order=1){
  n_obs <- length(event_seq)
  n_states <- length(state_space)
  states <- data.frame(matrix(NA, nrow=n_states, ncol=mc_order))
  for(i in 1:mc_order){
    states[,i] <- state_space
  }
  df_args <- c(expand.grid(states), sep=":")
  vector_states <- do.call(paste, df_args)
  
  emp_stat <- matrix(0, nrow = 1, ncol = length(vector_states))
  colnames(emp_stat) <- vector_states 
  
  if(mc_order > 1){
    n_new <- n_obs - (mc_order-1)
    mth_order_seq <- rep(NA, n_new)
    for(i in 1:n_new){
      mth_order_seq[i] <- paste(event_seq[i:(i+(mc_order-1))], collapse = ':')  
    }    
  } else {
    mth_order_seq <- event_seq
  }
  for(i in 1:length(vector_states)){
    emp_stat[1,i] <- length(mth_order_seq[mth_order_seq == vector_states[i]]) / length(mth_order_seq)
  }
  return(emp_stat)
}

#####
# Calculation of the estimate of the entropy rate of a finite Markov Chain.

CalcMarkovEntropyRate <- function(trans_mat, stat_mat){
  n_dim <- length(stat_mat)
  stat_mat <- matrix(rep(stat_mat, n_dim), n_dim, n_dim, byrow=TRUE)
  ent_rate <- -sum(t(stat_mat) * trans_mat * log2(trans_mat), na.rm = TRUE)
  return(ent_rate)
}

################################################################################
# Estimation of Entropy Rate utilizing Sliding-Window Lempel-Ziv
#
# @examples
# obs_seq = c(1,3,1,3,1,2,1,3,2,3,2,3,3,1,3,1,3,3,3,2) 
# SWLZEntRate(obs_seq, return.data=T)

SWLZEntRate <- function(obs_seq, return.data=F){
  conv_str <- str_c(obs_seq, collapse = '')
  swlz_results <- swlz_er(conv_str)
  
  include_data <- swlz_results[swlz_results[,4] == T, ]
  max_n <- include_data$i[length(include_data$i)]
  
  l2n <- log2(max_n)
  inv_er <- mean(include_data$MatchLength)/ l2n
  ent_rate <- 1/inv_er
  
  if(return.data){
    # message(paste('Entropy Estimate: ', round(ent_rate, 4)))
    return(swlz_results)
  } else {
    # message(paste('Entropy Estimate: ', round(ent_rate, 4)))
    return(ent_rate)  
  }
}

################################################################################
#
# Function to which organizes all other functions to calculate the entropy rate
#

CalcEntropyRate <- function(event_seq, 
                            state_space,
                            method='Markov', 
                            mc_order = 1,
                            stat_method='Empirical'){
  if(method == 'Markov'){
    tc <- CalcTC_Mth_Order(event_seq, state_space, mc_order)
    tm <- CalcTransitionMatrix(tc)
    if(stat_method != 'Empirical'){
      sm <- CalcEigenStationary(tm)
    } else{
      sm <- CalcEmpStat_Mth_Order(event_seq, state_space, mc_order)
    }
    ent <- CalcMarkovEntropyRate(tm, sm)
    return(ent)
  } else if(method == 'SWLZ'){
    return(SWLZEntRate(event_seq))
  } else {
    message('Error: Not a valid entropy rate estimation method -> Choose "Markov" or "SWLZ".')
    return(NULL)
  }
}


