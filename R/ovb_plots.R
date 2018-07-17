
# Plots -------------------------------------------------------------------


# generic plot function ---------------------------------------------------


#' @export
plot.sensemakr = function(x, type = "contour", ...) {
  if (is.null(type) || !type %in% c("contour", "extreme", "ovb")) {
    stop("`type` argument to `plot.sensemakr` must be 'contour', 'extreme', ",
         "or 'ovb'.")
  }

  # Call the dispatch function of interest
  switch(type,
         "contour" = dispatch_contour,
         "extreme" = dispatch_extreme)(x, ...)
}

dispatch_contour = function(x, ...) {
  # Use dispatcher rather than direct call so we can allow modifying call if
  # necessary
  ovb_contour_plot(x, ...)
}

dispatch_extreme = function(x, ...) {
  # Use dispatcher rather than direct call so we can allow modifying call if
  # necessary
  ovb_extreme_plot(x, ...)
}




# contour plot ------------------------------------------------------------



#' test
#' @param ... test
#' @export
ovb_contour_plot = function(...) {
  UseMethod("ovb_contour_plot")
}





#' @importFrom graphics contour points text
#' @importFrom stats coef
#' @export
ovb_contour_plot.numeric = function(estimate,
                                    se,
                                    dof,
                                    reduce = TRUE,
                                    estimate.threshold = 0,
                                    r2dz.x = NULL,
                                    r2yz.dx = r2dz.x,
                                    bound_label = "",
                                    type = c("estimate", "t-value"),
                                    t.threshold = 2,
                                    lim = c(0, 0.4, 0.001),
                                    nlevels = 20,
                                    col.contour = "grey40",
                                    col.thr.line = "red",
                                    label.text = TRUE,
                                    label.bump = 0.02,
                                    ...) {

  error_estimate(estimate)
  error_limit(lim)
  type <- match.arg(type)

  # Set up the grid for the contour plot
  grid_values = seq(lim[1], lim[2], by = lim[3])

  # Are we plotting t or bias in r2?
  if (type == "estimate") {
    z_axis = t(outer(grid_values, grid_values,
                     FUN = "adjusted_estimate",
                     estimate = estimate,
                     se = se,
                     dof = dof,
                     reduce = reduce))
    threshold = estimate.threshold
    plot_estimate = estimate

    if (!is.null(r2dz.x))
      bound_value <- adjusted_estimate(estimate = estimate,
                                       se = se,
                                       dof = dof,
                                       r2dz.x = r2dz.x,
                                       r2yz.dx = r2yz.dx,
                                       reduce = reduce)

  }

  if (type == "t-value") {
    z_axis = t(outer(grid_values, grid_values,
                     FUN = "adjusted_t",
                     se = se, dof = dof, estimate = estimate))
    threshold = t.threshold
    plot_estimate = estimate / se

    if (!is.null(r2dz.x))
      bound_value <- adjusted_t(estimate = estimate,
                                se = se,
                                dof = dof,
                                r2dz.x = r2dz.x,
                                r2yz.dx = r2yz.dx,
                                reduce = reduce)

  }

  out = list(r2dz.x = grid_values,
             r2yz.dx = grid_values,
             value = z_axis)

  # Aesthetic: Override the 0 line; basically, check which contour curve is
  # the zero curve, and override that contour curve with alternate aesthetic
  # characteristics
  default_levels = pretty(range(z_axis), nlevels)
  line_color = ifelse(default_levels == threshold,
                      col.thr.line,
                      col.contour)
  line_type = ifelse(default_levels == threshold,
                     2, 1)
  line_width = ifelse(default_levels == threshold,
                      2, 1)

  # Plot contour plot:
  contour(
    grid_values, grid_values, z_axis, nlevels = nlevels,
    xlab = expression(paste("Hypothetical partial ", R^2, " of unobserved",
                            " confounder(s) with the treatment")),
    ylab = expression(paste("Hypothetical partial ", R^2, " of unobserved",
                            " confounder(s) with the outcome")),
    cex.main = 1, cex.lab = 1, cex.axis = 1,
    col = line_color, lty = line_type, lwd = line_width,
    ...)

  # Add the point of the initial estimate.
  points(0, 0, pch = 17, col = "black", cex = 1)

  text(0.0, 0.02,
       paste0("Unadjusted\n(",
              signif(plot_estimate, 2),
              ")"),
       cex = 1)

  # add bounds
  if (!is.null(r2dz.x)) {

    error_r2(r2dz.x = r2dz.x, r2yz.dx = r2yz.dx)


    add_bound_to_contour(r2dz.x = r2dz.x,
                         r2yz.dx = r2yz.dx,
                         bound_value = bound_value,
                         bound_label = bound_label,
                         type = type,
                         label.text = label.text,
                         label.bump = label.bump)
    out$bounds = data.frame(r2dz.x = r2dz.x,
                            r2yz.dx = r2yz.dx,
                            bound_label = bound_label)
  }
  invisible(out)
}



#' @export
ovb_contour_plot.lm = function(model,
                               treatment,
                               benchmark_covariates = NULL,
                               kd = 1,
                               ky = kd,
                               reduce = TRUE,
                               estimate.threshold = 0,
                               r2dz.x = NULL,
                               r2yz.dx = r2dz.x,
                               bound_label = NULL,
                               type = c("estimate", "t-value"),
                               t.threshold = 2,
                               lim = c(0, 0.4, 0.001),
                               nlevels = 20,
                               col.contour = "grey40",
                               col.thr.line = "red",
                               label.text = TRUE,
                               label.bump = 0.02,
                               ...) {


  error_multipliers(ky = ky, kd = kd)
  type <- match.arg(type)
  # extract model data
  if (!is.character(treatment)) stop("Argument treatment must be a string.")
  if (length(treatment) > 1) stop("You must pass only one treatment")

  model_data <- model_helper(model, covariates = treatment)
  estimate <- model_data$estimate
  se <- model_data$se
  dof <- model_data$dof

  if (!is.null(r2dz.x)) {
    error_r2(r2dz.x = r2dz.x, r2yz.dx = r2yz.dx)
    bounds <-  data.frame(r2dz.x = r2dz.x,
                          r2yz.dx = r2yz.dx,
                          bound_label = bound_label,
                          stringsAsFactors = FALSE)
  } else{
    bounds <-  NULL
  }

  if (!is.null(benchmark_covariates)) {

    # we will need to add an option for the bound type
    bench_bounds <- ovb_bounds(model = model,
                               treatment = treatment,
                               benchmark_covariates = benchmark_covariates,
                               kd = kd,
                               ky = ky,
                               adjusted_estimates = FALSE)
    bounds <- rbind(bounds, bench_bounds)
  }

  ovb_contour_plot(estimate = estimate,
                   se = se,
                   dof = dof,
                   reduce = reduce,
                   estimate.threshold = estimate.threshold,
                   r2dz.x = bounds$r2dz.x,
                   r2yz.dx = bounds$r2yz.dx,
                   bound_label = bounds$bound_label,
                   type = type,
                   t.threshold = t.threshold,
                   lim = lim,
                   nlevels = nlevels,
                   col.contour = col.contour,
                   col.thr.line = col.thr.line,
                   label.text = label.text,
                   label.bump = label.bump,
                   ...)


}


#' @export
ovb_contour_plot.formula = function(formula,
                                    data,
                                    treatment,
                                    benchmark_covariates = NULL,
                                    kd = 1,
                                    ky = kd,
                                    reduce = TRUE,
                                    estimate.threshold = 0,
                                    r2dz.x = NULL,
                                    r2yz.dx = r2dz.x,
                                    bound_label = NULL,
                                    type = c("estimate", "t-value"),
                                    t.threshold = 2,
                                    lim = c(0, 0.4, 0.001),
                                    nlevels = 20,
                                    col.contour = "grey40",
                                    col.thr.line = "red",
                                    label.text = TRUE,
                                    ...) {

  check_formula(treatment = treatment,
                formula = formula,
                data = data)

  error_multipliers(ky = ky,
                    kd = kd)

  type <- match.arg(type)


  lm.call <- call("lm", formula = substitute(formula), data = substitute(data))
  outcome_model = eval(lm.call)

  ovb_contour_plot(model = outcome_model,
                   treatment = treatment,
                   benchmark_covariates = benchmark_covariates,
                   kd = kd,
                   ky = ky,
                   reduce = reduce,
                   estimate.threshold = estimate.threshold,
                   r2dz.x = r2dz.x,
                   r2yz.dx = r2dz.x,
                   bound_label = bound_label,
                   type = type,
                   t.threshold = t.threshold,
                   lim = lim,
                   nlevels = nlevels,
                   col.contour = col.contour,
                   col.thr.line = col.thr.line,
                   label.text = label.text,
                   ...)
}


#' test
#' @param ... test
#' @export
add_bound_to_contour <- function(...){
  UseMethod("add_bound_to_contour")
}


#' @export
add_bound_to_contour.numeric <- function(r2dz.x,
                                         r2yz.dx,
                                         bound_value,
                                         bound_label = NULL,
                                         label.text = TRUE,
                                         label.bump = 0.02,
                                         ...){

  for (i in seq.int(length(r2dz.x))) {


    # Add the point on the contour:
    points(r2dz.x[i], r2yz.dx[i],
           pch = 23, col = "black", bg = "red",
           cex = 1, font = 1)

    label = paste0(bound_label[i], "\n(", signif(bound_value[i], 2), ")")

    # Add the label text
    if (label.text)
      text(r2dz.x[i], r2yz.dx[i] + label.bump,
           labels = label,
           cex = 1.1, font = 1)
  }

}

#' @export
add_bound_to_contour.lm <- function(model,
                                    treatment,
                                    benchmark_covariates,
                                    kd = 1,
                                    ky = kd,
                                    reduce = TRUE,
                                    type = c("estimate", "t-value"),
                                    label.text = TRUE,
                                    label.bump = 0.02,
                                    ...)
{
  type <- match.arg(type)
  # we will need to add an option for the bound type
  bounds <- ovb_bounds(model = model,
                       treatment = treatment,
                       benchmark_covariates = benchmark_covariates,
                       kd = kd,
                       ky = ky,
                       adjusted_estimates = TRUE,
                       reduce = reduce)

  if (type == "estimate") {
    bound_value <- bounds$adjusted_estimate
  }

  if (type == "t-value") {
    bound_value <- bounds$adjusted_t
  }
  add_bound_to_contour(r2dz.x = bounds$r2dz.x,
                       r2yz.dx = bounds$r2yz.dx,
                       bound_value = bound_value,
                       bound_label = bounds$bound_label,
                       label.text = label.text,
                       label.bump = label.bump, ...)
}

#' @export
ovb_contour_plot.sensemakr <- function(x, ...){

  if (is.null(x$bounds)) {
    r2dz.x <- NULL
    r2yz.dx <- NULL
    bound_label = ""
  } else {
    r2dz.x <- x$bounds$r2dz.x
    r2yz.dx <- x$bounds$r2yz.dx
    bound_label = x$bounds$bound_label
  }

  with(x,
       ovb_contour_plot(estimate = sensitivity_stats$estimate,
                        se = sensitivity_stats$se,
                        dof = sensitivity_stats$dof,
                        r2dz.x = r2dz.x,
                        r2yz.dx = r2yz.dx,
                        bound_label = bound_label, ...)

       )
}


# extreme plot ------------------------------------------------------------


#' test
#' @param ... test
#' @export
ovb_extreme_plot <- function(...){
  UseMethod("ovb_extreme_plot")

}

#' @importFrom graphics abline lines legend rug plot
#' @export
ovb_extreme_plot.numeric = function(estimate,
                                    se,
                                    dof,
                                    r2dz.x = NULL,
                                    r2yz.dx = c(1, 0.75, 0.5),
                                    reduce = TRUE,
                                    threshold = 0,
                                    lim = min(c(r2dz.x + 0.1, 0.5)),
                                    cex.legend = 0.5, ...) {

  # if (is.null(lim)) {
  #   if (is.null(r2dz.x)) {
  #     stop("If `lim` is not provided, `r2dz.x` must be to automatically pick a ",
  #          "plot limit.")
  #   }
  #   lim = max(r2dz.x, na.rm = TRUE) + 0.1
  # }

  # x-axis values: R^2 of confounder(s) with treatment
  r2d_values = seq(0, lim, by = 0.001)
  out = list()
  # Iterate through scenarios:
  for (i in seq.int(length(r2yz.dx))) {
    y = adjusted_estimate(estimate, r2yz.dx = r2yz.dx[i],
                          r2dz.x = r2d_values,
                          se = se,
                          dof = dof, reduce = reduce)
    # Initial plot
    if (i == 1) {
      if (estimate < 0) {
        ylim = rev(range(y))
        } else {
          ylim = range(y)
        }
      plot(
        r2d_values, y, type = "l", bty = "L",
        ylim = ylim,
        xlab = expression(paste("Hypothetical partial ", R^2, " of unobserved",
                                 " confounder(s) with the treatment")),
        ylab = "Adjusted effect estimate",
        ...)
      abline(h = threshold, col = "red", lty = 5)
    } else {
      # Add plot lines
      lines(r2d_values, y, lty = i + 1)
    }
    out[[paste0("scenario_r2yz.dx_",r2yz.dx[i])]] <- data.frame(r2dz.x = r2d_values,
                                                                r2yz.dx = r2yz.dx[i],
                                                                adjusted_estimate = y)

  }

  legend(
    x = "topright",
    inset = 0.05,
    lty = c(seq_len(length(r2yz.dx)), 5),
    col = c(rep("black", length(r2yz.dx)),
            "red"),
    # bty = "n",
    legend = paste0(r2yz.dx * 100, "%"),
    ncol = length(r2yz.dx) + 1,
    title = expression(paste("Hypothetical partial ", R^2, " of unobserved",
                             " confounder(s) with the outcome")),
    cex = cex.legend
  )

  if (!is.null(r2dz.x)) {
    rug(x = r2dz.x, col = "red", lwd = 2)
    out[["bounds"]] <- r2dz.x
  }
  return(invisible(out))
}


#' @export
ovb_extreme_plot.lm <- function(model,
                                treatment,
                                benchmark_covariates = NULL,
                                kd = 1,
                                r2yz.dx = c(1, 0.75, 0.5),
                                r2dz.x = NULL,
                                reduce = TRUE,
                                threshold = 0,
                                lim = min(c(r2dz.x + 0.1, 0.5)),
                                cex.legend = 0.5, ...){
  # extract model data
  if (!is.character(treatment)) stop("Argument treatment must be a string.")
  if (length(treatment) > 1) stop("You must pass only one treatment")

  model_data <- model_helper(model, covariates = treatment)
  estimate <- model_data$estimate
  se <- model_data$se
  dof <- model_data$dof

  if (!is.null(benchmark_covariates)) {
      # TODO: We will need to make bound_type an option later
      bounds <- ovb_bounds(model = model,
                           treatment = treatment,
                           benchmark_covariates = benchmark_covariates,
                           kd = kd,
                           ky = 1)

      r2dz.x <- c(r2dz.x, bounds$r2dz.x)

  }


  ovb_extreme_plot(estimate = estimate,
                   se = se,
                   dof = dof,
                   r2dz.x = r2dz.x,
                   r2yz.dx = r2yz.dx,
                   reduce = reduce,
                   threshold = threshold,
                   lim = lim,
                   cex.legend = cex.legend,
                   ...)



}



#' @export
ovb_extreme_plot.formula = function(formula,
                                    data,
                                    treatment,
                                    benchmark_covariates = NULL,
                                    kd = 1,
                                    r2yz.dx = c(1, 0.75, 0.5),
                                    r2dz.x = NULL,
                                    reduce = TRUE,
                                    threshold = 0,
                                    lim = min(c(r2dz.x + 0.1, 0.5)),
                                    cex.legend = 0.5, ...) {
  check_formula(treatment = treatment,
                formula = formula,
                data = data)

  lm.call <- call("lm", formula = substitute(formula), data = substitute(data))
  outcome_model = eval(lm.call)

  ovb_extreme_plot(model = outcome_model,
                   treatment = treatment,
                   benchmark_covariates = benchmark_covariates,
                   kd = kd,
                   r2yz.dx = r2yz.dx,
                   r2dz.x = r2dz.x,
                   reduce = reduce,
                   threshold = threshold,
                   lim = lim,
                   cex.legend = cex.legend, ...)
}

#' @export
ovb_extreme_plot.sensemakr <- function(x, r2yz.dx = c(1, 0.75, 0.5), ...){

  if (is.null(x$bounds)) {
    r2dz.x <- NULL
    bound_label = ""
  } else {
    r2dz.x <- x$bounds$r2dz.x
    bound_label = x$bounds$bound_label
  }

  with(x,
       ovb_extreme_plot(estimate = sensitivity_stats$estimate,
                        se = sensitivity_stats$se,
                        dof = sensitivity_stats$dof,
                        r2dz.x = r2dz.x,
                        r2yz.dx = r2yz.dx,
                        ...)

  )
}


# sanity checkers ---------------------------------------------------------


check_formula <- function(treatment, formula, data) {

  if (is.null(treatment) || !treatment %in% all.vars(formula) ||
      (!is.null(data) && !treatment %in% colnames(data)) ||
      (is.null(data) && !exists(as.character(treatment)))
  ) {
    stop("You must provide a `treatment` variable present in the model ",
         "`formula` and `data` data frame.")
  }
  if (!is.null(data) && (!is.data.frame(data) || nrow(data) < 1)) {
    stop("The provided `data` argument must be a data frame with at least ",
         "one row.")
  }

}



error_estimate = function(estimate) {
  # Error if we don't have an estimate or if it's non-numeric
  if (is.null(estimate)) {
    stop("You must supply either a `model` and `treatment_covariate` to ",
         "extract an estimate or a directly supplied `estimate` argument")
  }
  if (!is.numeric(estimate)) {
    stop("The estimated effect must be numeric.")
  }
}

error_r2 = function(r2dz.x, r2yz.dx) {
  # Check r2dz.x / r2yz.dx
  if (is.null(r2dz.x) != is.null(r2yz.dx)) {
    stop("Either both `r2dz.x` and `r2yz.dx` must be provided or neither.")
  }

  if (!is.null(r2dz.x)) {
    if (any(!is.numeric(r2dz.x) | r2dz.x < 0 | r2dz.x > 1)) {
      stop("`r2dz.x` must be a number between zero and one, if provided")
    }

    if (length(r2dz.x) != length(r2yz.dx)) {
      stop("Lengths of `r2dz.x` and `r2yz.dx` must match.")
    }
  }

  if (!is.null(r2yz.dx) &&
     any(!is.numeric(r2yz.dx) | r2yz.dx < 0 | r2yz.dx > 1)) {
    stop("`r2yz.dx` must be a number between zero and one, if provided")
  }
}

error_limit = function(lim) {
  # Error if our grid limit is wrong.
  if (any(!is.numeric(lim) | lim < 0 | lim > 1) ||
     lim[2] <= lim[1] ||
     length(lim) != 3) {
    stop("Plot grid must consist of three numbers: lim = c(start, end, by)")
  }
}

error_multipliers = function(ky, kd) {
  # Error if multipliers are wrong.
  if ( any(!is.numeric(ky)) || any(!is.numeric(kd)) ||
     any(ky < 0) || any(kd < 0)) {
    stop("`ky` and `kd` must be vectors of non-negative ",
         "numbers")
  }
  if (length(ky) != length(kd)) {
    stop("`ky` and `kd` must be the same length.")
  }
}
