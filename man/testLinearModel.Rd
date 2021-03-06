% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/testLinearModel.R
\name{testLinearModel}
\alias{testLinearModel}
\alias{testLinearModel,ANY-method}
\alias{testLinearModel,SummarizedExperiment-method}
\title{Hypothesis tests with linear models}
\usage{
testLinearModel(x, ...)

\S4method{testLinearModel}{ANY}(
  x,
  design,
  coefs = ncol(design),
  contrasts = NULL,
  block = NULL,
  equiweight = FALSE,
  method = "stouffer",
  subset.row = NULL,
  BPPARAM = SerialParam()
)

\S4method{testLinearModel}{SummarizedExperiment}(x, ..., assay.type = "logcounts")
}
\arguments{
\item{x}{A numeric matrix-like object containing log-expression values for cells (columns) and genes (rows).
Alternatively, a \linkS4class{SummarizedExperiment} containing such a matrix.}

\item{...}{For the generic, further arguments to pass to specific methods.

For the SummarizedExperiment method, further arguments to pass to the ANY method.}

\item{design}{A numeric design matrix with number of rows equal to \code{ncol(x)}.}

\item{coefs}{An integer vector specifying the coefficients to drop to form the null model.
Only used if \code{contrasts} is not specified.}

\item{contrasts}{A numeric vector or matrix specifying the contrast of interest.
This should have length (if vector) or number of rows (if matrix) equal to \code{ncol(x)}.}

\item{block}{A factor specifying the blocking levels for each cell in \code{x}.
If specified, variance modelling is performed separately within each block and statistics are combined across blocks.}

\item{equiweight}{A logical scalar indicating whether statistics from each block should be given equal weight.
Otherwise, each block is weighted according to its number of cells.
Only used if \code{block} is specified.}

\item{method}{String specifying how p-values should be combined when \code{block} is specified, see \code{\link{combineParallelPValues}}.}

\item{subset.row}{See \code{?"\link{scran-gene-selection}"}, specifying the rows for which to model the variance.
Defaults to all genes in \code{x}.}

\item{BPPARAM}{A \linkS4class{BiocParallelParam} object indicating whether parallelization should be performed across genes.}

\item{assay.type}{String or integer scalar specifying the assay containing the log-expression values.}
}
\value{
A \linkS4class{DataFrame} containing test results with one row per row of \code{x}.
It contains the estimated values of the contrasted coefficients
as well as the p-value and FDR for each gene.
}
\description{
Perform basic hypothesis tests with linear models in an efficient manner.
}
\details{
This function can be considered a more efficient version of \code{\link{lmFit}}
that works on a variety of matrix representations (see \code{\link{fitLinearModel}}).
It also omits the empirical Bayes shrinkage step,
which is acceptable given the large number of residual d.f. in typical single-cell studies.

If \code{contrasts} is specified, the null hypothesis is defined by the contrast matrix or vector in the same manner 
that is used in the \pkg{limma} and \pkg{edgeR} packages.
Briefly, the contrast vector specifies a linear combination of coefficients that sums to zero under the null.
For contrast matrices, the joint null consists of the intersection of the nulls defined by each column vector.

Otherwise, if only \code{coefs} is specified, 
the null model is formed by simply dropping all of the specified coefficients from \code{design}.

If \code{block} is specified, a linear model is fitted separately to the cells in each level.
The results are combined across levels by averaging coefficients and combining p-values with \code{\link{combinePValues}}.
By default, the contribution from each level is weighted by its number of cells;
if \code{equiweight=TRUE}, each level is given equal weight instead.
}
\examples{
y <- matrix(rnorm(10000), ncol=100)

# Example with categorical factors:
A <- gl(2, 50)
design <- model.matrix(~A)
testLinearModel(y, design, contrasts=c(0, 1))

# Example with continuous variables:
u <- runif(100)
design <- model.matrix(~u)
testLinearModel(y, design, contrasts=c(0, 1))

# Example with multiple variables:
B <- gl(4, 25)
design <- model.matrix(~B)
testLinearModel(y, design, contrasts=cbind(c(0,1,0,0), c(0,0,1,-1)))

}
\seealso{
\code{\link{fitLinearModel}}, which performs the hard work of fitting the linear models.
}
\author{
Aaron Lun
}
