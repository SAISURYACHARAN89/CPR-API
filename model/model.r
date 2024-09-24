# Sample R script: model/model.r

library(class)
library(dplyr)
library(tidyr)
library(openxlsx)

# Load the dataset
data <- read.xlsx("model/OnlineRetail.xlsx")  # Update the dataset path

# Filter out rows with missing CustomerID
args <- commandArgs(trailingOnly = TRUE)
customer_id <- as.numeric(args[1])
data <- data %>%
  filter(!is.na(CustomerID))

# Create a User-Item matrix
user_item_matrix <- data %>%
  group_by(CustomerID, StockCode) %>%
  summarise(Quantity = sum(Quantity), .groups = 'drop') %>%
  pivot_wider(names_from = StockCode, values_from = Quantity, values_fill = 0)

# Convert to a matrix, preserving CustomerID separately
customer_ids <- user_item_matrix$CustomerID
user_item_matrix <- as.matrix(user_item_matrix[,-1])

recommend_products_knn <- function(customer_id, k = 5) {
  if (!(customer_id %in% customer_ids)) {
    stop(paste("Customer ID", customer_id, "not found in the dataset."))
  }

  target_index <- which(customer_ids == customer_id)
  if (length(target_index) != 1) {
    stop(paste("Multiple or no entries found for Customer ID", customer_id))
  }

  target_customer_data <- user_item_matrix[target_index, , drop = FALSE]

  neighbors <- knn(train = user_item_matrix[-target_index, ],
                   test = target_customer_data,
                   cl = customer_ids[-target_index],
                   k = k)

  neighbor_ids <- unique(neighbors)

  if (length(neighbor_ids) == 0) {
    return(paste("No similar customers found for Customer", customer_id))
  }

  neighbor_data <- data %>%
    filter(CustomerID %in% neighbor_ids) %>%
    group_by(StockCode) %>%
    summarise(TotalQuantity = sum(Quantity), .groups = 'drop')

  purchased_products <- data %>%
    filter(CustomerID == customer_id) %>%
    pull(StockCode)

  recommendations <- neighbor_data %>%
    filter(!StockCode %in% purchased_products) %>%
    arrange(desc(TotalQuantity)) %>%
    head(5)

  if (nrow(recommendations) == 0) {
    return(paste("No new products to recommend for Customer", customer_id))
  }

  return(recommendations$StockCode)
}

recommended_products <- recommend_products_knn(customer_id)

# Prepare output data for writing to CSV
recommended_descriptions <- data %>%
  filter(StockCode %in% recommended_products) %>%
  distinct(StockCode, Description)

output_data <- recommended_descriptions %>%
  mutate(CustomerID = customer_id)

# Write output to a CSV file
write.csv(output_data, file = 'model/recommended_products.csv', row.names = FALSE)
