# Functions ---------------------------------------------------------------

#' Down sample each well to specified number of cells
#'
#' @param data data frame: Data frame with QIBC data
#' @param max_cells integer: Number of cells to down sample to. Wells with less cells will retain all cells.
#'
#' @returns original data frame with each well downsampled
#' @export
down_sample <- function(data, max_cells = 5000) {
  well_split <- split(data, data$Well)

  downsampled <- dplyr::bind_rows(purrr::imap(well_split, function(well_data, well) {
    if (nrow(well_data) > max_cells) {
      well_data[sample(1:nrow(well_data), size = max_cells), ]
    } else {
      well_data
    }
  }), .id = "Well")

  return(downsampled)
}


#' Map condition to each well
#'
#' @param data data frame: Data frame with QIBC data
#' @param well_to_condition list: List declaring which well corresponds to which condition (e.g., list("1" = "siCtrl", "2" = "siFH", "3" = "siMYC")). Note, well names must be character
#' @param well_column characetr: Name of the column containing the well information
#'
#' @returns original data frame with added 'condition' column
#' @export
map_conditions <- function(data, well_to_condition, well_column = "Well") {
  well_data <- data.frame(well = as.character(data[, well_column])) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(condition = well_to_condition[[well]])

  output_data <- data %>%
    tibble::add_column(condition = well_data$condition)

  return(output_data)
}
