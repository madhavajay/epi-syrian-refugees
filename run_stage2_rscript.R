args <- commandArgs(trailingOnly = TRUE)
cmd <- paste("./run_stage2.sh", paste(shQuote(args), collapse = " "), "--no-docker")
status <- system(cmd)
quit(status = status, save = "no")
