---
title: "Readme"
author: "Amanda Coston"
output: html_notebook
---

This readme outlines the steps needed to reproduce the results in ["Leveraging Administrative Data for Bias Audits: Assessing Disparate Coverage with Mobility Data for COVID-19 Policy."](https://arxiv.org/abs/2011.07194)

# Dependencies
## Data dependencies
This analysis requires data from SafeGraph and L2.

### SafeGraph data
SafeGraph data downloads require an account which can be obtained via the [SafeGraph Community](https://safegraph-community.slack.com
) of researchers.
Once you have an account, you can download the following data from the [SafeGraph website](https://catalog.safegraph.io/):

1. Patterns data is required for October and November of 2020.
2. SafeGraph Core Places US (Pre-Nov-2020) is required. 

### L2 data

## Code dependencies
### R Packages
The following R packages are required:

- [Tidyverse](https://www.tidyverse.org/packages/)
- [fastDummies](https://cran.r-project.org/web/packages/fastDummies/fastDummies.pdf)
- [fuzzyjoin](https://cran.r-project.org/web/packages/fuzzyjoin/index.html)
- [Here](https://here.r-lib.org/) (or you can modify the file paths so they don't require "here")


### Bespoke R functions

This repo includes a few .R files with bespoke variables and functions required for the analysis:

- _read_specs.R_ contains variables that define the specification for _[read_cvs](https://readr.tidyverse.org/reference/read_delim.html)_.
- _process_patterns.R_ contains functions to process the SafeGraph patterns data based on _[safegraph_process_patterns_functions.R](https://github.com/stanfordfuturebay/stanfordfuturebay.github.io/blob/master/covid19/safegraph_process_patterns_functions.R)_
- _utils.R_ contains functions for processing.


# Run Analysis 
1. Match poll locations to SafeGraph places of interest (POIs) using _preprocess.py_ and _postprocess.py_.
2. Process North Carolina patterns data for November 2018 using _nc.Rmd_. Modify the data file paths as necessary.  
3. Process North Carolina patterns data for October 2018 using _nc_get_October_placebos.Rmd_. Modify the data file paths as necessary. 
4. Compute summary stats in _summary_stats.Rmd_.
5. Preprocess and perform preliminary analysis including visualizations of the heatmap and scatterplots as well as correlations in _preliminary.Rmd_.
6. Perform the main analysis in _hypothesis_testing.Rmd_.
7. Perform policy analysis in _policy.Rmd_.
8. Perform supplementary analysis in appendix in _appendix.Rmd_.

Please cite as 
@inproceedings{coston2021leveraging,
  title={Leveraging Administrative Data for Bias Audits: Assessing Disparate Coverage with Mobility Data for COVID-19 Policy},
  author={Coston, Amanda and Guha, Neel and Ouyang, Derek and Lu, Lisa and Chouldechova, Alexandra and Ho, Daniel E},
  booktitle={Proceedings of the 2021 ACM Conference on Fairness, Accountability, and Transparency},
  pages={173--184},
  year={2021}
}

