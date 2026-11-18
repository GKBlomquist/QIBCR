#' Infer cell cycle of each cell based on DAPI and EdU intensity
#'
#' @param data data frame: Data frame with QIBC data
#' @param DAPI_column character: Name of the column with DAPI intensity
#' @param EdU_column character: Name of the column with EdU intensity
#' @param max_uncertainty float: Maximum accepted cluster uncertainty value. Cells below this threshold will be annotated as background. Defaults to Inf (no cells filtered)
#' @param thresholds list: Named list containing manually provided thresholds to use for inferring cycle phase. If specified, unsupervised clustering will not be performed. First, cells over EdU threshold are assigned to S-phase. Afterwards, remaining cells over DAPI threshold are assigned to G2/M, while those below are assigned to G1. Example list: list(DAPI = 1, EdU = 30)
#'
#' @returns original data frame with added 'phase' column with inferred cell cycle stage for each cell
#' @export
#' @importFrom mclust Mclust mclustBIC
infer_cycle_phases <- function(data, DAPI_column = "Total.Intensity.A405.DAPI", EdU_column = "Mean.Intensity.A647.EdU", max_uncertainty = Inf, thresholds = NULL) {
  if (!is.null(thresholds)) {
    if (!is.list(thresholds)) {
      stop("Thresholds must be named list with thresholds (e.g., list(DAPI = 1, EdU = 2)")
    }

    message("Inferring cycle phases using provided thresholds")
    classification_data <- data.frame(
      DAPI = data[, DAPI_column], EdU = data[, EdU_column]
    ) %>%
      dplyr::mutate(phase = case_when(
        EdU > thresholds[["EdU"]] ~ "S",
        DAPI > thresholds[["DAPI"]] ~ "G2/M",
        TRUE ~ "G1"
      ), phase = factor(phase, levels = c("G1", "S", "G2/M")))

    return(tibble::add_column(data, phase = classification_data$phase))
  }

  message("Inferring cycle phases using gaussian mixture models")
  DAPI <- data[[DAPI_column]]
  EdU <- log10(data[[EdU_column]])
  ok <- is.finite(DAPI) & is.finite(EdU)

  phase <- rep(NA_character_, nrow(data))
  uncertainty <- rep(NA_real_, nrow(data))

  message("Fitting EdU mixture model")
  S_fit <- mclust::Mclust(EdU[ok], G = 2, verbose = FALSE)
  S_high <- S_fit$classification == which.max(S_fit$parameters$mean)

  S_idx <- which(ok)[S_high]
  phase[S_idx] <- "S"
  uncertainty[S_idx] <- S_fit$uncertainty[S_high]


  message("Fitting DAPI mixture model on EdU-negative cells")
  G_idx <- which(ok)[!S_high]
  G_fit <- mclust::Mclust(DAPI[G_idx], G = 2, verbose = FALSE, modelNames = "E")
  G2_high <- G_fit$classification == which.max(G_fit$parameters$mean)

  phase[G_idx] <- ifelse(G2_high, "G2/M", "G1")
  uncertainty[G_idx] <- G_fit$uncertainty
  phase[!is.na(uncertainty) & uncertainty > max_uncertainty] <- "Background"

  out <- data
  out$phase <- factor(phase, levels = c("Background", "G1", "S", "G2/M"))
  out$phase_uncertainty <- uncertainty
  return (out)
}


#' DAPI axis scale labelled in DNA content (2n / 4n)
#'
#' Places breaks at the median DAPI intensity of G1 cells (2n) and twice that
#' (4n).
#'
#' @param DAPI_column character: optional, defaults to "Total.Intensity.A405.DAPI"
#' @param ... passed on to `ggplot2::scale_x_continuous()`
#' @export
scale_x_DAPI <- function(data, DAPI_column = "Total.Intensity.A405.DAPI", ...) {
  G1_DAPI <- mean(data[data$phase == "G1", DAPI_column])
  ggplot2::scale_x_continuous(breaks = c(G1_DAPI, 2 * G1_DAPI), labels = c("2n", "4n"), ...)
}


#' Scales plot colors using default cell cycle palette
#'
#' @export
scale_color_cycle <- function() {
  ggplot2::scale_color_manual(values = cell_cycle_colors)
}


#' Scales plot fill colors using default cell cycle palette
#'
#' @export
scale_fill_cycle <- function() {
  ggplot2::scale_fill_manual(values = cell_cycle_colors)
}
