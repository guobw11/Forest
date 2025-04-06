# Soil Multifunctionality (SMF)
rm(list=ls())
library(tidyverse)

# Define directories
input_dir <- "~/Desktop/SMF/"
output_dir <- "~/Desktop/SMF/"

# Input data
mydata <- read.csv(file.path(input_dir, "rhizo.csv"), header = TRUE)

# Variables of interest
var <- c("NO3","NH4","C","N","P","DNA")

# Shapiro-Wilk test before standardization
for (v in var) {
  cat("Shapiro-Wilk test for", v, ":\n")
  print(shapiro.test(mydata[, v]))
  cat("\n")
}

# Standardization (Z-score transformation)
Zcore <- as.data.frame(scale(mydata))

# Calculate SMF as the row-wise mean of selected standardized variables
selected_columns <- Zcore[, var]
Zcore$SMF <- apply(selected_columns, 1, mean)

# Save results
write.csv(Zcore, file.path(output_dir, "SMF_rhizo.csv"))


