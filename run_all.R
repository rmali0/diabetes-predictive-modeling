# Reproduce every result in this repository:
#   Rscript run_all.R          full run (about 15 minutes on 2 cores)
#   QUICK=1 Rscript run_all.R  small smoke run; writes to a temp folder only
source("R/utils.R")

notebooks <- c("analysis/01_brfss_diabetes_classification.Rmd",
               "analysis/02_inpatient_los_regression.Rmd")
quick <- quick_run()
out_dir <- if (quick) outputs_dir("notebooks") else NULL

for (nb in notebooks) {
  message("Rendering ", nb, if (quick) " (quick run)")
  t0 <- Sys.time()
  rmarkdown::render(nb, output_dir = out_dir, envir = new.env(), quiet = TRUE)
  message(sprintf("  done in %.1f minutes", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}

if (!quick) {
  writeLines(utils::capture.output(utils::sessionInfo()), "outputs/session_info.txt")
}
