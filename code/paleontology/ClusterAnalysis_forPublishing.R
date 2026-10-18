# Load required libraries
library(stringr)
library(dplyr)
library(readxl)
library(tidyr)
library(ggplot2)
library(mclust)
library(plotly)

# Function to read and preprocess the data
read_and_preprocess_data <- function(file_path) {
  dataset <- read_excel(file_path, na = c('NA', '-'))
  
  # Identify numeric and non-numeric columns
  column_types <- sapply(dataset, class)
  numeric_columns <- which(column_types %in% c("numeric", "integer"))
  non_numeric_columns <- length(which(!column_types %in% c("numeric", "integer")))
  
  # Prompt the user to input VarNumber
  VarNumber <- -1
  while (VarNumber < 1 || VarNumber > length(numeric_columns) || is.na(VarNumber)) {
    cat("Enter the number of numeric variables to include in the analysis (between 1 and", length(numeric_columns), "): ")
    input <- readline(prompt = "")
    if (!grepl("^[0-9]+$", input) || input < 1 || input > length(numeric_columns)) {
      cat("Invalid input! Please enter an integer between 1 and", length(numeric_columns), ".\n\n")
    } else {
      VarNumber <- as.integer(input)
    }
  }
  
  VarNumber <- VarNumber + non_numeric_columns
  
  # Data Preprocessing
  dataset <- dataset %>%
    drop_na(all_of((non_numeric_columns+1):VarNumber)) %>%
    mutate(across(all_of((non_numeric_columns+1):VarNumber), as.numeric)) %>%
    select(all_of(1:VarNumber))
  
  # Optional logarithmic transformation
  logcheck <- -1
  while (logcheck != "y" && logcheck != "n") {
    cat("Do you want to apply a logarithmic transformation to all numeric data (y/n)? ")
    logcheck <- readline(prompt = "")
    if (logcheck == "y") {
      if (any(dataset[, (non_numeric_columns + 1):VarNumber] <= 0)) {
        cat("Warning: Some numeric values are non-positive. The samples with such values have been removed from the analysis.\n")
        dataset <- dataset %>%
          mutate(across((non_numeric_columns + 1):VarNumber, ~ ifelse(. > 0, ., NA))) %>%
          drop_na(all_of((non_numeric_columns + 1):VarNumber))
      }
      dataset <- dataset %>%
        mutate(across((non_numeric_columns + 1):VarNumber, log))
    }
    if (logcheck != "y" && logcheck != "n") {
      cat("Invalid input. Please enter y or n.\n")
    }
  }
  
  return(list(dataset = dataset, VarNumber = VarNumber, non_numeric_columns = non_numeric_columns))
}

# Function to perform PCA
perform_pca <- function(dataset, VarNumber, non_numeric_columns) {
  # Prompt the user for the desired total variance
  desired_total_variance <- -1
  while (desired_total_variance < 0 || desired_total_variance > 1) {
    cat("Enter the desired total variance (e.g., 0.9 for 90%): ")
    desired_total_variance <- as.numeric(readline(prompt = ""))
    if (desired_total_variance < 0 || desired_total_variance > 1) {
      cat("Invalid input. Value should be between 0 and 1.\n")
    }
  }
  
  # Perform PCA
  pca_result <- prcomp(dataset[, (non_numeric_columns+1):VarNumber], center = TRUE, scale. = TRUE, retx = TRUE)
  cumulative_variance <- cumsum(pca_result$sdev^2) / sum(pca_result$sdev^2)
  num_components_needed <- which.max(cumulative_variance >= desired_total_variance)
  cat("Number of components needed for at least", round(desired_total_variance * 100), "% cumulative variance:", num_components_needed, "\n")
  
  # Add PCA results to the dataset
  pca_data_final <- data.frame(matrix(pca_result$x[, 1:num_components_needed], ncol = num_components_needed))
  colnames(pca_data_final) <- paste("PC", 1:num_components_needed, sep = "")
  dataset <- cbind(dataset, pca_data_final)
  
  return(list(dataset = dataset, pca_result = pca_result, num_components_needed = num_components_needed))
}

# Function to visualize loadings
visualize_loadings <- function(dataset, pca_result, VarNumber, non_numeric_columns) {
  loadings <- pca_result$rotation[, 1:2]
  loadings_df <- data.frame(Parameter = colnames(dataset[, (non_numeric_columns+1):VarNumber]), 
                            PC1_Loadings = loadings[, 1], PC2_Loadings = loadings[, 2])
  
  ggplot(loadings_df, aes(x = PC1_Loadings, y = PC2_Loadings, label = Parameter)) +
    geom_point() +
    geom_text(hjust = 1, vjust = -0.4) +
    xlab("PC1 Loadings") +
    ylab("PC2 Loadings") +
    ggtitle("Loadings of Parameters on PC1 and PC2")
}

# Function to perform and visualize clustering
perform_clustering <- function(pca_result, num_components_needed) {
  fit_pc <- Mclust(pca_result$x[, 1:num_components_needed], G = 1:5)
  BIC_pc <- mclustBIC(pca_result$x[, 1:num_components_needed], G = 1:5)
  
  plot(BIC_pc)
  print(summary(BIC_pc, data = pca_result$x))
  chosen_option <- 0
  suppressWarnings({
    while (!(chosen_option %in% 1:3)) {
      chosen_option <- as.integer(readline(prompt = "Enter the number of the desired option (1, 2, or 3): "))
      if (!(chosen_option %in% 1:3)) {
        cat("Invalid input. Please enter 1, 2, or 3.\n")
      }
    }
  })
  
  BIC_matrix <- cbind(BIC = BIC_pc)
  top_models_indices <- order(BIC_matrix, decreasing = TRUE)[1:3]
  top_models_info <- list(
    BIC = BIC_matrix[top_models_indices],
    Clusters = rownames(BIC_matrix)[row(BIC_matrix)[top_models_indices]],
    Model = colnames(BIC_matrix)[col(BIC_matrix)[top_models_indices]]
  )
  
  desired_number_of_clusters <- top_models_info$Clusters[chosen_option]
  desired_model_type <- top_models_info$Model[chosen_option]
  
  fit_specific_model <- Mclust(pca_result$x[, 1:num_components_needed], G = desired_number_of_clusters, modelNames = desired_model_type)
  plot(fit_specific_model, what = 'classification')
  
  return(fit_specific_model$classification)
}

# Function to visualize data with Plotly
visualize_with_plotly <- function(dataset, pca_result, cluster_numbers, specimens_to_label = c()) {
  data_to_plot <- data.frame(
    PC1 = pca_result$x[, 1],
    PC2 = pca_result$x[, 2],  
    Cluster = cluster_numbers,
    Place = dataset$Place,
    Specimen = dataset$Specimen,
    Chosen = ifelse(dataset$Specimen %in% specimens_to_label, " listed", "")
  )
  data_to_plot$Shape <- paste(data_to_plot$Place, data_to_plot$Chosen, sep = "")
  
  plot_ly(
    data_to_plot,
    x = ~PC1,
    y = ~PC2,
    color = ~as.factor(Cluster),
    symbol = ~Place,
    text = ~Specimen,
    type = "scatter",
    mode = "markers",
    marker = list(
      size = 10,
      line = list(color = "black", width = 1),
      colors = c("black", "blue", "green", "purple")
    )
  ) %>%
    add_text(
      data = plotly::filter(data_to_plot, Specimen %in% specimens_to_label),
      text = ~Specimen,
      showlegend = FALSE,
      textposition = "bottom center"
    ) %>%
    plotly::layout(
      xaxis = list(title = "PC1"),
      yaxis = list(title = "PC2"),
      title = "Specimens Divided by Clusters and Place",
      legend = list(title = "Clusters")
    )
}

# Main function to run all steps
run_analysis <- function(file_path) {
  preprocessed_data <- read_and_preprocess_data(file_path)
  pca_result <- perform_pca(preprocessed_data$dataset, preprocessed_data$VarNumber, preprocessed_data$non_numeric_columns)
  visualize_loadings(pca_result$dataset, pca_result$pca_result, preprocessed_data$VarNumber, preprocessed_data$non_numeric_columns)
  cluster_numbers <- perform_clustering(pca_result$pca_result, pca_result$num_components_needed)
  visualize_with_plotly(pca_result$dataset, pca_result$pca_result, cluster_numbers)
}

run_analysis("Dickinsonia2024.xlsx")
