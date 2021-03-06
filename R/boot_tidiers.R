#' Tidying methods for bootstrap computations
#'
#' Tidying methods for "boot" objects from the "boot" package.
#'
#' @param x \code{\link{boot}} object
#' @param conf.int whether to include a confidence interval
#' @param conf.level confidence level for CI
#' @param conf.method method for computing confidence intervals (see \code{\link{boot.ci}})
#' @param \dots extra arguments (not used)
#'
#' @return The \code{tidy} method returns a data frame with one row per
#' bootstrapped statistic that was calculated, and the
#' following columns:
#'   \item{term}{Name of the computed statistic, if present}
#'   \item{statistic}{The original values of the statistic}
#'   \item{bias}{The bias of the original statistic value}
#'   \item{std.error}{Standard error of the statistic}
#'
#' If weights were provided to the \code{boot} function, an \code{estimate}
#' column is included showing the weighted bootstrap estimate, and the
#' standard error is of that estimate.
#'
#' If there are no original statistics in the "boot" object, such as with a
#' call to \code{tsboot} with \code{orig.t = FALSE}, the \code{original}
#' and \code{statistic} columns are omitted, and only \code{estimate} and
#' \code{std.error} columns shown.
#'
#' @name boot_tidiers
#'
#' @examples
#' if (require("boot")) {
#'    clotting <- data.frame(
#'           u = c(5,10,15,20,30,40,60,80,100),
#'           lot1 = c(118,58,42,35,27,25,21,19,18),
#'           lot2 = c(69,35,26,21,18,16,13,12,12))
#'
#'    g1 <- glm(lot2 ~ log(u), data = clotting, family = Gamma)
#'
#'    bootfun <- function(d, i) {
#'       coef(update(g1, data= d[i,]))
#'    }
#'    bootres <- boot(clotting, bootfun, R = 999)
#'    tidy(g1, conf.int=TRUE)
#'    tidy(bootres, conf.int=TRUE)
#' }
#'
#' @export
tidy.boot <- function(x,
                      ## is there a convention for the default value of
                      ## conf.int?
                      conf.int = FALSE,
                      conf.level = 0.95,
                      conf.method = "perc", ...) {
  # calculate the bias and standard error
  # this is an adapted version of the code in print.boot, where the bias
  # and standard error are calculated
  boot.out <- x
  index <- 1:ncol(boot.out$t)
  sim <- boot.out$sim
  cl <- boot.out$call
  t <- matrix(boot.out$t[, index], nrow = nrow(boot.out$t))
  allNA <- apply(t, 2L, function(t) all(is.na(t)))
  index <- index[!allNA]
  t <- matrix(t[, !allNA], nrow = nrow(t))
  rn <- paste("t", index, "*", sep = "")
  if (is.null(t0 <- boot.out$t0)) {
    if (is.null(boot.out$call$weights)) {
      op <- cbind(apply(t, 2L, mean, na.rm = TRUE), sqrt(apply(t, 2L, function(t.st) var(t.st[!is.na(t.st)]))))
    } else {
      op <- NULL
      for (i in index) op <- rbind(op, boot::imp.moments(boot.out, index = i)$rat)
      op[, 2L] <- sqrt(op[, 2])
    }
    colnames(op) <- c("estimate", "std.error")
  } else {
    t0 <- boot.out$t0[index]
    if (is.null(boot.out$call$weights)) {
      op <- cbind(t0, apply(t, 2L, mean, na.rm = TRUE) -
        t0, sqrt(apply(t, 2L, function(t.st) var(t.st[!is.na(t.st)]))))
      colnames(op) <- c("statistic", "bias", "std.error")
    }
    else {
      op <- NULL
      for (i in index) op <- rbind(op, boot::imp.moments(boot.out,
          index = i
        )$rat)
      op <- cbind(t0, op[, 1L] - t0, sqrt(op[, 2L]), apply(t,
        2L, mean,
        na.rm = TRUE
      ))
      colnames(op) <- c("statistic", "bias", "std.error", "estimate")
    }
  }

  # bring in rownames as "term" column, and turn into a data.frame
  ret <- fix_data_frame(op)

  if (conf.int) {
    ci.list <- lapply(seq_along(x$t0),
      boot::boot.ci,
      boot.out = x,
      conf = conf.level, type = conf.method
    )
    ## boot.ci uses c("norm", "basic", "perc", "stud") for types
    ## stores them with longer names
    ci.pos <- pmatch(conf.method, names(ci.list[[1]]))
    ci.tab <- t(sapply(ci.list, function(x) x[[ci.pos]][4:5]))

    colnames(ci.tab) <- c("conf.low", "conf.high")
    ret <- cbind(ret, ci.tab)
  }
  return(ret)
}
