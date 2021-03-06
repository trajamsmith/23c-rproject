# Fianko Buckle and Travis Smith
# !!! ADDITIONAL POINTS #22

## ----------------------------------------------------------------
## Setup
## ----------------------------------------------------------------

# Empty the global environmentß
rm(list = ls())

# Import packages
library(dplyr)
library(ggplot2)
library(mixtools)
lib <- modules::use("./R")
analysis <- lib$analysis
graphing <- lib$graphing

# Import the by-part table as `table`
load("./data/Global Party Survey by Party Stata V2_1_Apr_2020.RData")
# !!! THIS DATASET MEETS ALL REQUIRED DATASET STANDARDS --
# !!! IT CONTAINS OVER 150 COLUMNS, MANY LOGICAL AND MANY CONTINUOUS, ACROSS 1043 OBSERVATIONSs
# !!! ADDITIONAL POINT #1

## ----------------------------------------------------------------
## Important Project Notes
## ----------------------------------------------------------------

# This project analyzes the Global Party Survey, an expert-led survey of political parties around
# the globe. For full documentation surrounding both the survey and the dataset, please see the `/docs`
# directory of this repository.
#
# Some background -- We intended to structure this project as though it were a professional R package.
# See here: http://r-pkgs.had.co.nz/intro.html
# Per the above, our intention was to have a library, stored in our `/R` directory, from which we would
# import functions into our R Markdown `vignettes`. Each vignette would explore a topic in the dataset.
#
# Because of the stringent submission requirements for this project, we've attempted to import much of
# our analysis from the individual vignette notebooks into this "long R script," but many of the analytic
# steps are still bundled into our library files. If any issues arise when running this script, please
# reach out to Travis (as he's responsible for the goofy structural choices)!
# !!! ADDITIONAL POINT #10
#
# To quickly find any of the project requirements (including the ten additional points), search this
# document for the following string: `# !!!`
#
# Additionally, in the same `proj_submission` directory as this script, we've included a written
# document addressing one of the ethical issues explored in this dataset.
# !!! ADDITIONAL POINT #4


###########################################################################
###########################################################################
#
#           1. Examing the Distribution of Party Alignments
#
###########################################################################
###########################################################################
# More-detailed version (alignment_distribution.Rmd) can be found in vignettes folder

# Let's look at the ideological alignments of all political parties globally and see if they adhere to some distribution.
# We'll be looking specifically at the economic alignments of the parties along a left-right axis, as reported by local political experts.

# Let's start by just looking at the binary counts for the party alignments. Note that we chose
# to use the _global_ convention of using red for left and socialist parties and blue for conservative
# parties (in contrast to the US-centric convention).

graphing$alignment_barchart(table)

# We can see that the counts are roughly even for economic ideology, with a slight advantage
# to the economic left. This is in stark contrast to the substantially higher number of
# socially conservative parties.
# !!! REQUIRED GRAPHICAL DISPLAY #1

# Having looked at the counts, let's now to turn to the distributions.


## ----------------------------------------------------------------
## Without Influence Weighting
## ----------------------------------------------------------------

# A priori, having not looked at the data, it might be reasonable to assume that the counts follow
# a normal distribution. In other words, we might assume that political parties tend to tack to the
# center (especially after weighting for influence) and that there are far fewer parties to either extreme.

# Let's test this naive assumption. We can calculate the mean and standard deviation from the data and
# overlay it on our histogram:

mu <- mean(table$V4_Scale, na.rm = TRUE)
sigma <- sd(table$V4_Scale, na.rm = TRUE)

plot <- graphing$alignment_histogram(table, "V4_Scale")
plot + stat_function(fun = dnorm, args = list(mean = mu, sd = sigma))
# !!! REQUIRED GRAPHICAL DISPLAY #2

# We can pretty clearly see from the graphs that the naive assumption is incorrect, but let's test that
# hypothesis. We can calculate _expected_ counts for each of our ten bins by integrating over the distribution.
# Then we can run a chi-square test to see if our _observed_ bins might likely have been drawn from the normal
# distribution:

data <- table$V4_Scale

# Bin our original data (our histogram function did this for us above).
observed <- 1:10
for (i in 1:length(observed)) {
  inds <- which((i - 1) <= data & data < i)
  observed[i] <- length(inds)
}

density <- function(x) {
  dnorm(x, mean = mu, sd = sigma)
}

# Get proportions of results by region of normal distribution.
bins <- 1:10
for (i in 1:length(bins)) {
  bins[i] <- integrate(density, lower = (i - 1), upper = i)$value
}

# Calculate expected values.
expected <- bins * sum(observed)
chi_sq <- sum((observed - expected)^2 / expected)

# We have ten bins and are measuring one variable, so DoF = 9
pvalue <- pchisq(chi_sq, 9, lower.tail = FALSE)
pvalue

# Our p-value is very, very small, suggesting that there's a very, very small probability
# that our observed data was drawn from a normal distribution. We'll probably need a more
# complicated model to describe the data.

## ----------------------------------------------------------------
## Accounting for Party Influence
## ----------------------------------------------------------------
# To be included, time permitting...

## ----------------------------------------------------------------
## Finding a Bimodal Distribution
## ----------------------------------------------------------------

# So, this is a little outside the scope of the class, but our histogram really looks like it has
# a bimodal underlying distribution. More specifically, it looks like we might want to try some kind
# of mixture model, maybe a mix of two normal distributions. We can use a package to calculate a likely
# mixture model (`mixtools`, using expectation-maximation), then we can run a chi-square test like above
# to see how well the model fits:

cleaned <- table$V4_Scale[!is.na(table$V4_Scale)]
mix_mdl <- normalmixEM(cleaned)

means <- mix_mdl$mu
sigmas <- mix_mdl$sigma
lambdas <- mix_mdl$lambda

f1 <-
  function(x) {
    lambdas[1] * dnorm(x, mean = means[1], sd = sigmas[1])
  }
f2 <-
  function(x) {
    lambdas[2] * dnorm(x, mean = means[2], sd = sigmas[2])
  }

plot <- graphing$alignment_histogram(table, "V4_Scale")
plot + stat_function(fun = f1) + stat_function(fun = f2)
# !!! REQUIRED GRAPHICAL DISPLAY #3
# !!! ADDITIONAL POINT #6

# To run a chi-square test, let's try sampling this time. Our lambda values give us the proportions
# of the two constituent normal distributions and, therefore, the probability that any single sample
# is drawn from each. So we can then sample from the two normal distributions probabilistically:

samples <- 1:1000
for (i in samples) {
  if (runif(1) < lambdas[1]) {
    # Sample from the first distribution
    samples[i] <- rnorm(1, mean = means[1], sd = sigmas[1])
  } else {
    # Sample from the second distribution
    samples[i] <- rnorm(1, mean = means[2], sd = sigmas[2])
  }
}

# Drop any samples (<0) or (>10)
samples <- samples[samples > 0 & samples < 10]
hist(samples)

# Bin the samples
bins <- 1:10
for (i in 1:length(bins)) {
  inds <- which((i - 1) <= samples & samples < i)
  bins[i] <- length(inds)
}


chi_sq <- sum((observed - bins)^2 / bins)
pvalue <- pchisq(chi_sq, 9, lower.tail = FALSE)
pvalue
# !!! REQUIRED ANALYSIS #2

# This p-value at least describes something in the realm of possibility, but it's still below
# the threshold of what we would consider likely. There's only a 0.6% chance that our observed party
# alignments came from this mixed distribution. This makes sense given that our sample size isn't that
# large, and, even if it were, we're analyzing such an abstract, subjective set of values that modeling is
# naturally very difficult.

# TODO: Check these results, I don't think they're correct. Attempting to fit the
# Gaussian mixture model is still cool though!


###########################################################################
###########################################################################
#
#   2. Exploring the Relationship between Gender and Political Ideology
#
###########################################################################
###########################################################################
rm(list = ls())

# Opening the questionairre response data
data <- read.csv("data/ResponsesByExpert.csv")

# Null hypothesis - there is no significant difference in average political ideologies between genders

# extract gender and ideology columns

# 1 is male, 2 is female
gender <- data$R_Gender

# ideologies range from 0 (very left) to 10 (very right).
ideologies <- data$R_ideology

# get row indices of males and females and get average ideologies for each gender
idx.male <- which(gender == 1)
idx.male
male.avg <- mean(na.omit(ideologies[idx.male]))
male.avg # 4.837

idx.female <- which(gender == 0)
idx.female
female.avg <- mean(na.omit(ideologies[idx.female]))
female.avg # 4.502

obs <- male.avg - female.avg
obs
# observed difference of 0.3349686

# Running a permutation test for the null hypothesis
# num of trials
N <- 10000
# vector to store results
Diffs <- numeric(N)

for (i in 1:N) {
  Labels <- sample(gender)

  idx.male.loop <- which(Labels == 1)
  male.avg.loop <- mean(na.omit(ideologies[idx.male.loop]))

  idx.fmale.loop <- which(Labels == 0)
  female.avg.loop <- mean(na.omit(ideologies[idx.fmale.loop]))

  Diffs[i] <- male.avg.loop - female.avg.loop
}


mean(Diffs) # average difference is 0.0001830085

# visual of the distribution of differences
hist(Diffs, breaks = "Fd")

abline(v = obs, col = "blue")

# 1-tailed pvalue
pv.1t <- (sum(Diffs >= obs) + 1) / (N + 1)
pv.1t # 0.00359964

# 2-tailed pvalue
pv.2t <- 2 * pv.1t
pv.2t # 0.00719928


# The 2-tailed pvalue of 0.00719928 is quite low (less than .05), so there is a .7% chance that we
# could get this observed discrepacncy in average ideology by chance. Hence there is sufficient
# evidence against the null hypothesis.
# !!! REQUIRED ANALYSIS #1

# Let's see what we get if we calculate the significance of this difference with a t-test and compare.
# Using TA Michael Liotti's R function, Automate, we can do just this:

male_ideologies <- na.omit(ideologies[idx.male])
fem_ideologies <- na.omit(ideologies[idx.female])
analysis$automate(fem_ideologies, male_ideologies, .05)

# the t-test gives a confidence interval of [0.1233620, 0.5465752]  and a pvalue of 0.00194038,
# which is lower than the chosen alpha level of 0.05. So the t-test also shows sufficient evidence
# to reject the null hypothesis.
# !!! REQUIRED ANALYSIS #4
# !!! ADDITIONAL POINT #20


###########################################################################
###########################################################################
#
#      3. Examining the Relationship Between Ideology and Populism
#
###########################################################################
###########################################################################
# More-detailed Rmd version (populism_and_ideology.Rmd) can be found in vignettes folder

# In addition to the left-right ideological alignment that most people would find familiar, our data set also
# measures parties on a spectrum from "pluralist" to "populist." The definitions are as follows:

# POPULIST language typically challenges the legitimacy of established political institutions and emphasizes
# that the will of the people should prevail.

# By contrast, PLURALIST rhetoric rejects these ideas, believing that elected leaders should govern, constrained
# by minority rights, bargaining and compromise, as well as checks and balances on executive power.

# We might take as a baseline assumption that, at present, global right-wing parties are generally more populist (or are,
# at least, perceived to be more populist). Examples include the Republican Party in the US, the BJP in India, or Jair Bolsonaro's
# Alianca (though technically a nascent political organization, rather than a registered party). These political organizations
# have an authoritarian-populist bent, but left-wing authoritarian-populist parties are popular in a number of places as well,
# such as the PDP-Laban in the Philippines.

# To explore whether there exists a correlation between left-right ideology and populism, let's first examine some contingency
# tables. Note that we generally explore "left" vs "right"-ness using the scalar columns in our data — these give us roughly
# continuous variables for ideological measures. Included in the data source, however (as part of the expert questionnaire), are
# two ordinal measures of party alignment, one binary and another ranging from $1$ to $4$.

# Let's first take a look at the crosstabs for binary measurements of ideology and populism:

# Binary
econ_align_bin <- table$V4_Bin
soc_align_bin <- table$V6_Bin
pop_align_bin <- table$V8_Bin

# Plot
cont <- table(econ_align_bin, pop_align_bin)
graphing$contingency_table(cont,
  title = "Economic Ideology — Populism",
  x_label = "Left   —   Economic Ideology   —   Right",
  y_label = "Pluralist      —      Populist"
)

# In terms of economic ideology, there doesn't seem to be much difference poportionally
# between pluralist vs. populist positioning. We might think that social ideology is more telling,
# so let's try it:

cont <- table(soc_align_bin, pop_align_bin)
graphing$contingency_table(cont,
  title = "Social Ideology — Populism",
  x_label = "Left   —   Social Ideology   —   Right",
  y_label = "Pluralist      —      Populist"
)

# And we would be absolutely right! This is a fascinating result (if not a surprising one),
# so let's explore it further. Let's explore tabs using ordinal rather than binary categories:

# Ordinal (1 - 4)
econ_align_ord <- table$V4_Ord
soc_align_ord <- table$V6_Ord
pop_align_ord <- table$V8_Ord

cont <- table(soc_align_ord, pop_align_ord)
graphing$contingency_table(cont,
  title = "Social Ideology — Populism",
  x_label = "Left   —   Social Ideology   —   Right",
  y_label = "Pluralist      —      Populist"
)
# !!! REQUIRED GRAPHICAL DISPLAY #4
# !!! ADDITIONAL POINT #11

# This data is a little hard to interpret purely from this contingency table, but
# we can eyeball a couple of things. Firstly, there are a lot of very socially conservative
# parties, and they skew very populist. Secondly, more socially left-wing parties tend to
# have mixed values with regards to populism, with a preference for what we'll call
# "center-pluralism." In other words, there appear to be two peaks: "center-left, center-pluralist"
# and "hard-right, hard-populist." Remember, however, that this is only true for _social_ ideology!
# Let's look at the larger, ordinal contingency table for economic ideology:
# !!! REQUIRED ANALYSIS #3

cont <- table(econ_align_ord, pop_align_ord)
graphing$contingency_table(cont,
  title = "Economic Ideology — Populism",
  x_label = "Left   —   Economic Ideology   —   Right",
  y_label = "Pluralist      —      Populist"
)

# There's no clear axis from one diagonal corner to another here,
# like there was with our social ideology table.

## ----------------------------------------------------------------
## Scatterplot Analysis
## ----------------------------------------------------------------

# Let's repeat the above analysis with scatterplots and scalar values. This
# might give us a more granular view of how these different ideological metrics are correlated:

# Continuous
econ_align_scale <- table$V4_Scale
soc_align_scale <- table$V6_Scale
pop_align_scale <- table$V8_Scale

graphing$scatterplot(
  table,
  econ_align_scale,
  pop_align_scale,
  means = TRUE,
  regression = TRUE,
  title = "Economic Ideology — Populism",
  x_label = "Left   —   Economic Ideology   —   Right",
  y_label = "Pluralist      —      Populist"
)

# Our scatterplot shows axis means with dotted lines and a linear regression,
# shown in red. Confirming our results above, there doesn't seem to be any correlation
# between economic ideology and populism. Let's even run a correlation test as a sanity check:
# !!! ADDITIONAL POINT #9
# !!! ADDITIONAL POINT #14

# Create correlation scatterplot -- gives us a different metric
# than the regression plot above.
graphing$corr_scatterplot(table,
  "V4_Scale",
  "V8_Scale",
  x_label = "Left   —   Economic Ideology   —   Right",
  y_label = "Pluralist      —      Populist"
)
# !!! ADDITIONAL POINT #5

# We can see that we have a very near-zero Pearson correlation coefficient,
# as expected. Now let's do the same with the social ideological spectrum:
# !!! ADDITIONAL POINT #16

graphing$scatterplot(
  table,
  soc_align_scale,
  pop_align_scale,
  means = TRUE,
  regression = TRUE,
  title = "Social Ideology — Populism",
  x_label = "Left   —   Social Ideology   —   Right",
  y_label = "Pluralist      —      Populist"
)

# This looks a lot more promising. Let's calculate the correlation coefficient for this one too:

graphing$corr_scatterplot(table,
  "V6_Scale",
  "V8_Scale",
  x_label = "Left   —   Social Ideology   —   Right",
  y_label = "Pluralist      —      Populist"
)
# !!! ADDITIONAL POINT #8

# The correlation here is much stronger, as we'd predicted.
