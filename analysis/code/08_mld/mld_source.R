bs_fun <- function(z, scores, phi_deriv, pred_pc, var_scores_half, long, lat, mean_psal_one, mean_temp_one,pressure_vec,
                   mu_temp_deriv, mu_psal_deriv, K1, K2, delta, pred_interval = FALSE,
                   nugget_var_temp = rep(0, length(pressure_vec)), 
                   nugget_var_psal = rep(0, length(pressure_vec))) {
  coef_boot <- as.double(scores + var_scores_half %*% rnorm(K1 + K2))
  pred_temp <- .rowSums(pred_pc[,1:K1] %*% diag(coef_boot[1:K1]), m = length(pressure_vec), n = K1)
  pred_psal <- .rowSums(pred_pc[,(K1+1):(K1+K2)] %*% diag(coef_boot[(K1+1):(K1+K2)]), m = length(pressure_vec), n = K2)
  full_psal <- mean_psal_one + pred_psal
  full_temp <- mean_temp_one + pred_temp
  if (pred_interval == T) {
    full_temp <- full_temp + rnorm(n = length(pressure_vec), mean = 0, sd = sqrt(nugget_var_temp))
    full_psal <- full_psal + rnorm(n = length(pressure_vec), mean = 0, sd = sqrt(nugget_var_psal))
  }
  deriv_pred_boot <- .rowSums(phi_deriv[,1:K1] %*% diag(coef_boot[1:K1]), m = length(pressure_vec), n = K1)
  full_deriv_temp <- mu_temp_deriv + deriv_pred_boot
  bs_fun_preds(full_temp, full_psal, full_deriv_temp, pressure_vec, long, lat, delta)
}
bs_fun_preds <- function(full_temp, full_psal, full_deriv_temp, pressure_vec, long, lat, delta) {
  SA <- gsw_SA_from_SP(SP = full_psal,p = pressure_vec, longitude = long, latitude = lat)
  pdens <- gsw::gsw_pot_rho_t_exact(SA = SA, t = full_temp, 
                                    p = pressure_vec, p_ref = 0)
  # potential density - variable
  pdens_thresh_try <- gsw::gsw_pot_rho_t_exact(SA = SA[1], t = full_temp[1] - .2, 
                                               p = pressure_vec[1], p_ref = 0) - pdens[1]
  thresh_var_boot_d <- pressure_vec[which(pdens - pdens[1]  >= pdens_thresh_try)[1]]
  
  # potential density - constant
  pdens_sub <- pdens - pdens[1]
  thresh_boot_d <-  pressure_vec[which(pdens_sub  >= .03)[1]]
  drho_dp_all <- (pdens[2:length(pdens)] - pdens[1:(length(pdens)-1)])/delta
  drho_dp_all <- c(drho_dp_all[1] , (drho_dp_all[2:(length(drho_dp_all))] + drho_dp_all[1:(length(drho_dp_all)-1)])/2, 
                   drho_dp_all[length(drho_dp_all)])
  # 0.0005 to 0.05 kg m^4 are generally used, we use .001
  deriv_boot_d <- pressure_vec[which(drho_dp_all >= 0.001)[1]]
  
  # Temperature 
  thresh_boot <-  pressure_vec[which(full_temp - full_temp[1] <= -.2)[1]]
  deriv_boot <- pressure_vec[which(full_deriv_temp <= -.025)[1]]
  
  c(thresh_var_boot_d, thresh_boot_d, deriv_boot_d, thresh_boot, deriv_boot)
}