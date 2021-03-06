% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/computeSumFactors.R
\name{computeSumFactors}
\alias{computeSumFactors}
\alias{calculateSumFactors}
\alias{calculateSumFactors,ANY-method}
\alias{calculateSumFactors,SummarizedExperiment-method}
\title{Normalization by deconvolution}
\usage{
calculateSumFactors(x, ...)

\S4method{calculateSumFactors}{ANY}(
  x,
  sizes = seq(21, 101, 5),
  clusters = NULL,
  ref.clust = NULL,
  max.cluster.size = 3000,
  positive = TRUE,
  scaling = NULL,
  min.mean = NULL,
  subset.row = NULL,
  BPPARAM = SerialParam()
)

\S4method{calculateSumFactors}{SummarizedExperiment}(x, ..., assay.type = "counts")

computeSumFactors(x, ..., assay.type = "counts")
}
\arguments{
\item{x}{For \code{calculateSumFactors}, a  numeric matrix-like object of counts, where rows are genes and columns are cells.
Alternatively, a \linkS4class{SummarizedExperiment} object containing such a matrix.

For \code{computeSumFactors}, a \linkS4class{SingleCellExperiment} object containing a count matrix.}

\item{...}{For the \code{calculateSumFactors} generic, additional arguments to pass to each method.
For the \linkS4class{SummarizedExperiment} method, additional methods to pass to the ANY method.

For the \code{computeSumFactors} function, additional arguments to pass to \code{calculateSumFactors}.}

\item{sizes}{A numeric vector of pool sizes, i.e., number of cells per pool.}

\item{clusters}{An optional factor specifying which cells belong to which cluster, for deconvolution within clusters.}

\item{ref.clust}{A level of \code{clusters} to be used as the reference cluster for inter-cluster normalization.}

\item{max.cluster.size}{An integer scalar specifying the maximum number of cells in each cluster.}

\item{positive}{A logical scalar indicating whether linear inverse models should be used to enforce positive estimates.}

\item{scaling}{A numeric scalar containing scaling factors to adjust the counts prior to computing size factors.}

\item{min.mean}{A numeric scalar specifying the minimum (library size-adjusted) average count of genes to be used for normalization.}

\item{subset.row}{See \code{?"\link{scran-gene-selection}"}.}

\item{BPPARAM}{A BiocParallelParam object specifying whether and how clusters should be processed in parallel.}

\item{assay.type}{A string specifying which assay values to use when \code{x} is a SummarizedExperiment or SingleCellExperiment.}
}
\value{
For \code{calculateSumFactors}, a numeric vector of size factors for all cells in \code{x} is returned.

For \code{computeSumFactors}, an object of class \code{x} is returned containing the vector of size factors in \code{\link{sizeFactors}(x)}.
}
\description{
Scaling normalization of single-cell RNA-seq data by deconvolving size factors from cell pools.
}
\section{Overview of the deconvolution method}{

The \code{computeSumFactors} function implements the deconvolution strategy (Lun et al., 2016) for scaling normalization of sparse count data.
Briefly, a pool of cells is selected and the expression profiles for those cells are summed together.
The pooled expression profile is normalized against an average reference pseudo-cell, constructed by averaging the counts across all cells.
This defines a size factor for the pool as the median ratio between the count sums and the average across all genes.

The scaling bias for the pool is equal to the sum of the biases for the constituent cells.
The same applies for the size factors, as these are effectively estimates of the bias for each cell.
This means that the size factor for the pool can be written as a linear equation of the size factors for the cells.
Repeating this process for multiple pools will yield a linear system that can be solved to obtain the size factors for the individual cells.

In this manner, pool-based factors are deconvolved to yield the relevant cell-based factors.
The advantage is that the pool-based estimates are more accurate, as summation reduces the number of stochastic zeroes and the associated bias of the size factor estimate.
This accuracy feeds  back into the deconvolution process, thus improving the accuracy of the cell-based size factors.
}

\section{Pooling with a sliding window}{

Within each cluster (if not specified, all cells are put into a single cluster), cells are sorted by increasing library size and a sliding window is applied to this ordering.
Each location of the window defines a pool of cells with similar library sizes.
This avoids inflated estimation errors for very small cells when they are pooled with very large cells.
Sliding the window will construct an over-determined linear system that can be solved by least-squares methods to obtain cell-specific size factors.

Window sliding is repeated with different window sizes to construct the linear system, as specified by \code{sizes}.
By default, the number of cells in each window ranges from 21 to 101.
Using a range of window sizes improves the precision of the estimates, at the cost of increased computational work.
The defaults were chosen to provide a reasonable compromise between these two considerations.
The default set of \code{sizes} also avoids rare cases of linear dependencies and unstable estimates when all pool sizes are not co-prime with the number of cells.

The smallest window should be large enough so that the pool-based size factors are, on average, non-zero.
We recommend window sizes no lower than 20 for UMI data, though smaller windows may be possible for read count data.
The total number of cells should also be at least 100 for effective pooling.
(If \code{cluster} is specified, we would want at least 100 cells per cluster.)

If there are fewer cells than the smallest window size, the function will naturally degrade to performing library size normalization.
This yields results that are the same as \code{\link{librarySizeFactors}}.
}

\section{Prescaling of the counts}{

The simplest approach to pooling is to simply add the counts together for all cells in each pool.
However, this is suboptimal as any errors in the estimation of the pooled size factor will propagate to all component cell-specific size factors upon solving the linear system.
If the error is distributed evenly across all cell-specific size factors, the small size factors will have larger relative errors compared to the large size factors.

To avoid this, we perform \dQuote{prescaling} where we divide the counts by a cell-specific factor prior to pooling.
Ideally, the prescaling factor should be close to the true size factor for each cell.
Solving the linear system constructed with prescaled values should yield estimates that are more-or-less equal across all cells.
Thus, given similar absolute errors, the relative errors for all cells will also be similar.

Obviously, the true size factor is unknown (otherwise why bother running this function?)
so we use the library size for each cell as a proxy instead.
This may perform poorly in pathological scenarios involving extreme differential expression and strong composition biases.
In cases where a more appropriate initial estimate is available, 
this can be used as the prescaling factor by setting the \code{scaling} argument.

One potential approach is to run \code{computeSumFactors} twice to improve accuracy.
The first run is done as usual and will yield an initial estimate of the size factor for each cell.
In the second run, we supply our initial estimates in the \code{scaling} argument to serve as better prescaling factors.
Obviously, this involves twice as much computational work so we would only recommend attempting this in extreme circumstances.
}

\section{Solving the linear system}{

The linear system is solved using the sparse QR decomposition from the \pkg{Matrix} package.
However, this has known problems when the linear system becomes too large (see \url{https://stat.ethz.ch/pipermail/r-help/2011-August/285855.html}).
In such cases, we set \code{clusters} to break up the linear system into smaller, more manageable components that can be solved separately.
The default \code{max.cluster.size} will arbitrarily break up the cell population (within each cluster, if specified) so that we never pool more than 3000 cells.
}

\section{Normalization within and between clusters}{

In general, it is more appropriate to pool more similar cells to avoid violating the assumption of a non-DE majority of genes.
This can be done by specifying the \code{clusters} argument where cells in each cluster have similar expression profiles.
Deconvolution is subsequently applied on the cells within each cluster, where there should be fewer DE genes between cells.
A convenience function \code{\link{quickCluster}} is provided for this purpose, though any reasonable clustering can be used.
Only a rough clustering is required here, as \code{computeSumFactors} is robust to a moderate level of DE within each cluster.

Size factors computed within each cluster must be rescaled for comparison between clusters.
This is done by normalizing between the per-cluster pseudo-cells to identify the rescaling factor.
One cluster is chosen as a \dQuote{reference} to which all others are normalized.
Ideally, the reference cluster should have a stable expression profile and not be extremely different from all other clusters.
The assumption here is that there is a non-DE majority between the reference and each other cluster
(which is still a weaker assumption than that required without clustering).

By default, the cluster with the most non-zero counts is used as the reference.
This reduces the risk of obtaining undefined rescaling factors for the other clusters, while improving the precision (and also accuracy) of the median-based estimate of each factor.
Alternatively, the reference can be manually specified using \code{ref.clust} if there is prior knowledge about which cluster is most suitable, e.g., from PCA or t-SNE plots.

Each cluster should ideally be large enough to contain a sufficient number of cells for pooling.
Otherwise, \code{computeSumFactors} will degrade to library size normalization.
}

\section{Dealing with negative size factors}{

It is possible for the deconvolution algorithm to yield negative estimates for the size factors.
These values are obviously nonsensical and \code{computeSumFactors} will raise a warning if they are encountered.
Negative estimates are mostly commonly generated from low quality cells with few expressed features, such that most genes still have zero counts even after pooling.
They may also occur if insufficient filtering of low-abundance genes was performed.

To avoid negative size factors, the best solution is to increase the stringency of the filtering.
\itemize{
\item If only a few negative size factors are present, they are likely to correspond to a few low-quality cells with few expressed features.
Such cells are difficult to normalize reliably under any approach, and can be removed by increasing the stringency of the quality control.
\item If many negative size factors are present, it is probably due to insufficient filtering of low-abundance genes.
This results in many zero counts and pooled size factors of zero, and can be fixed by filtering out more genes with a higher \code{min.mean} - see \dQuote{Gene selection} below.
}
Another approach is to increase in the number of \code{sizes} to improve the precision of the estimates.
This reduces the chance of obtaining negative size factors due to estimation error, for cells where the true size factors are very small.

As a last resort, \code{positive=TRUE} is set by default, which uses \code{\link{cleanSizeFactors}} to coerce any negative estimates to positive values.
This ensures that, at the very least, downstream analysis is possible even if the size factors for affected cells are not accurate.
Users can skip this step by setting \code{positive=FALSE} to perform their own diagnostics or coercions.
}

\section{Gene selection}{

If too many genes have consistently low counts across all cells, even the pool-based size factors will be zero.
This results in zero or negative size factor estimates for many cells.
We avoid this by filtering out low-abundance genes using the \code{min.mean} argument.
This represents a minimum threshold \code{min.mean} on the library size-adjusted average counts from \code{\link{calculateAverage}}.

By default, we set \code{min.mean} to 1 for read count data and 0.1 for UMI data.
The exact values of these defaults are more-or-less arbitrary and are retained for historical reasons.
The lower threshold for UMIs is motivated by (i) their lower count sizes, which would result in the removal of too many genes with a higher threshold; and (ii) the lower variability of UMI counts, which results in a lower frequency of zeroes compared to read count data at the same mean.
We use the median library size to detect whether the counts are those of reads (above 100,000) or UMIs (below 50,000) to automatically set \code{min.mean}.
Mean library sizes in between these two limits will trigger a warning and revert to using \code{min.mean=0.1}.

If \code{clusters} is specified, filtering by \code{min.mean} is performed on the per-cluster average during within-cluster normalization,
and then on the (library size-adjusted) average of the per-cluster averages during between-cluster normalization.

Performance can generally be improved by removing genes that are known to be strongly DE between cells.
This weakens the assumption of a non-DE majority and avoids the error associated with DE genes.
For example, we might remove viral genes when our population contains both infected and non-infected cells.
Of course, \code{computeSumFactors} is robust to some level of DE genes - that is, after all, its raison d'etre -
so one should only explicitly remove DE genes if it is convenient to do so.
}

\section{Obtaining standard errors}{

Previous versions of \code{computeSumFactors} would return the standard error for each size factor when \code{errors=TRUE}.
This argument is no longer available as we have realized that standard error estimation from the linear model is not reliable.
Errors are likely underestimated due to correlations between pool-based size factors when they are computed from a shared set of underlying counts.
Users wishing to obtain a measure of uncertainty are advised to perform simulations instead, using the original size factor estimates to scale the mean counts for each cell.
Standard errors can then be calculated as the standard deviation of the size factor estimates across simulation iterations.
}

\examples{
library(scuttle)
sce <- mockSCE(ncells=500)

# Computing the size factors.
sce <- computeSumFactors(sce)
head(sizeFactors(sce))
plot(librarySizeFactors(sce), sizeFactors(sce), log="xy")

# Using pre-clustering.
preclusters <- quickCluster(sce)
table(preclusters)

sce2 <- computeSumFactors(sce, clusters=preclusters)
head(sizeFactors(sce2))

}
\references{
Lun ATL, Bach K and Marioni JC (2016).
Pooling across cells to normalize single-cell RNA sequencing data with many zero counts.
\emph{Genome Biol.} 17:75
}
\seealso{
\code{\link{quickCluster}}, to obtain a rough clustering for use in \code{clusters}.

\code{\link{logNormCounts}}, which uses the computed size factors to compute normalized expression values.
}
\author{
Aaron Lun and Karsten Bach
}
