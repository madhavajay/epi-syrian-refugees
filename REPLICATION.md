# Replication Guide: Syrian Refugee Epigenetic Study

This guide provides a step-by-step plan to replicate the entire analysis pipeline from raw IDAT files to final publication results.

## Overview

The analysis pipeline consists of 4 major stages:

```
Stage 1: Quality Control (22183534)
   Raw IDAT files → QC filtered data → final_igp_data.rds + combatBetas.rds

Stage 2: EWAS Analysis (22183384)
   final_igp_data.rds → Differential methylation analysis → EWAS results

Stage 3: Epigenetic Age QC (23498670)
   Raw IDAT files → Horvath clock calculation → PC-Clocks estimation

Stage 4: Epigenetic Age Analysis (23498658)
   Epigenetic age data → Age acceleration analysis → Final results
```

---

## Computational Requirements

- **CPU**: 16 cores minimum
- **RAM**: 128 GB minimum
- **Storage**: 15 GB free space
- **OS**: Linux/macOS (scripts may need modification for Windows)

---

## Stage 1: Quality Control & Data Processing

### Purpose
Process raw IDAT files through quality control, normalization, and batch correction to create clean methylation datasets.

### Input Files Required

**From `data/idat/`:**
- All 320 `.idat.gz` files (160 samples × 2 channels: Red + Green)
  - Format: `GSM*_<SentrixID>_<Position>_Red.idat.gz`
  - Format: `GSM*_<SentrixID>_<Position>_Grn.idat.gz`
  - **Note**: Current repo only has 2 sample files. Full dataset must be downloaded from GEO GSE226085

**Metadata files (from `data/22183534/`):**
- `cMulligan_SampleSheet160.csv` - Sample manifest linking Sample_Name to Sentrix IDs
- `cMulligan_SampleManifest160.csv` - Detailed sample information
- `IGP_SwabType.csv` - Swab type for each sample
- `igp_ages.csv` - Age and demographic data
- `datMiniAnnotation3.csv` - Probe annotation for Horvath clock
- `IGP_Epi_Metadata20220330.csv` - Violence/trauma exposure metadata
- `all_samples_log_compiled_20220106.csv` - Sample collection log
- `igp_relatedness_coded_20220105.csv` - Family relationship coding
- `infinium-methylationepic-v-1-0-b5-manifest-file.csv` - Illumina EPIC array manifest

**Pre-calculated files needed (from `data/22183534/`):**
- `igp_horvath_betas_20211104.csv` - Beta values for Horvath clock (generated externally)
- `igp_horvath_samplesheet_20211104.csv` - Sample sheet for Horvath
- `igp_horvath_betas_20211104.output.csv` - Horvath clock output

### Script
`data/22183534/igp_quality_control_20230222.Rmd`

### Directory Structure Setup

```bash
project_root/
├── igp.Rproj
├── data/
│   ├── *.idat (all 320 IDAT files, unzipped)
│   └── cMulligan_SampleSheet160.csv
├── script/
│   └── igp_quality_control_20230222.Rmd
├── output/
│   ├── igp_horvath_betas_20211104.csv
│   ├── igp_horvath_samplesheet_20211104.csv
│   └── igp_horvath_betas_20211104.output.csv
└── supp_data/
    ├── cMulligan_SampleManifest160.csv
    ├── IGP_SwabType.csv
    ├── igp_ages.csv
    ├── datMiniAnnotation3.csv
    ├── IGP_Epi_Metadata20220330.csv
    ├── all_samples_log_compiled_20220106.csv
    ├── igp_relatedness_coded_20220105.csv
    └── infinium-methylationepic-v-1-0-b5-manifest-file.csv
```

### Analysis Steps

**Step 1.1: Contamination Check (ewastools)**
- Read IDAT files using `ewastools::read_idats()`
- Extract SNP probes from methylation data
- Calculate detection p-values and mask failed probes (p > 0.01)
- Apply dye bias correction
- Call genotypes from SNP probes
- Identify contaminated samples using `snp_outliers()` (threshold: outlier > -4)
- **Output**: `output/snps.rds`, contamination report

**Step 1.2: Sex Check (ewastools)**
- Predict sex from X/Y chromosome methylation
- Compare predicted vs reported sex
- Flag mismatches for review
- **Output**: Sex mismatch report

**Step 1.3: Quality Control (meffil)**
- Load IDAT files using `meffil`
- Perform quality control with `meffil.qc()`
- Check detection p-values, bead counts, controls
- Generate QC summary report
- **Output**: `meffil_qc_summary_report_20211004.html`

**Step 1.4: Age Prediction Check**
- Load Horvath clock predictions (pre-calculated)
- Compare epigenetic age vs chronological age
- Flag samples with large discrepancies
- Confirm no switched/mislabeled samples
- **Output**: Age prediction plots

**Step 1.5: Normalization (SeSAMe)**
- Load IDAT files using `sesame::readIDATpair()`
- Apply noob background correction
- Apply non-linear dye bias correction
- Calculate detection p-values
- **Output**: Normalized beta value matrix

**Step 1.6: Probe Filtering**
Apply masks to remove problematic probes:
- Probes with zero intensity
- Cross-reactive probes
- Non-CpG probes (CH probes)
- Probes with <3 beads
- Sex chromosome probes (chrX, chrY)
- Probes failing detection (p < 0.05 in >10% of samples)
- **Result**: 768,625 probes retained from original 866K

**Step 1.7: Sample Filtering**
- Remove contaminated samples (from Step 1.1)
- Remove samples with sex mismatches (from Step 1.2)
- Remove samples failing QC thresholds
- Check methylated/unmethylated intensity ratios
- **Final n**: Should retain 160 samples (or fewer if QC fails)

**Step 1.8: Cell Type Estimation**
- Use `EpiDISH` with robust partial correlation method
- Estimate epithelial cell proportions from buccal methylation
- Add epithelial proportion to sample metadata
- **Output**: Cell type proportion data

**Step 1.9: Batch Correction (ComBat)**
- Use `sva::ComBat()` to adjust for bisulfite conversion plate
- Preserve biological variables (age, sex, exposure group)
- Correct technical batch effects
- **Output**: `combatBetas.rds` (871 MB)

**Step 1.10: Final Dataset Creation**
- Combine normalized/corrected beta values with metadata
- Merge demographic, exposure, and technical variables
- Create master dataset with all QC flags
- **Output**: `final_igp_data.rds` (720 MB)

### Expected Outputs

| File | Size | Description |
|------|------|-------------|
| `final_igp_data.rds` | 720 MB | Clean methylation data + metadata |
| `combatBetas.rds` | 871 MB | Batch-corrected beta values |
| `igp_quality_control_20230222.html` | 9.8 MB | QC report with plots |

### Key QC Metrics to Monitor
- Detection p-value pass rate: >90% of probes per sample
- SNP outlier score: should be < -4 for clean samples
- Sex prediction concordance: 100%
- Age prediction correlation: R² > 0.9
- Number of probes retained: 768,625
- Number of samples retained: 160 (or document exclusions)

---

## Stage 2: EWAS Analysis

### Purpose
Perform epigenome-wide association study to identify differentially methylated positions (DMPs) associated with violence trauma exposure.

### Input Files Required

**From Stage 1 outputs:**
- `final_igp_data.rds` (720 MB)
- `igp_methylation_special.rds` (53 MB) - **Note**: This subset may need to be created from final_igp_data.rds

**Metadata (from `data/22183384/`):**
- `IGP_Epi_Metadata_20221016.csv` - Updated exposure/trauma metadata
- `igp_demo_special.csv` - Demographic subset

**Annotation files:**
- `EPIC.hg38.manifest.tsv` (272 MB) - hg38 probe mappings
- `EPIC.hg38.manifest.gencode.v36.tsv` (252 MB) - Gene annotations
- `infinium-methylationepic-v-1-0-b5-manifest-file.csv` (522 MB)

### Script
`data/22183384/IGP_HiperGator_Code_v24.Rmd`

### Directory Structure Setup

```bash
project_root/
├── igp.Rproj
├── data/
│   ├── final_igp_data.rds
│   ├── igp_methylation_special.rds
│   └── IGP_Epi_Metadata_20221016.csv
├── script/
│   └── IGP_HiperGator_Code_v24.Rmd
├── output/
│   ├── EPIC.hg38.manifest.gencode.v36.tsv
│   └── EPIC.hg38.manifest.tsv
└── supp_data/
    └── infinium-methylationepic-v-1-0-b5-manifest-file.csv
```

### Analysis Steps

**Step 2.1: Data Loading & Merging**
- Load `final_igp_data.rds`
- Load exposure metadata from `IGP_Epi_Metadata_20221016.csv`
- Merge methylation data with updated trauma/exposure variables
- Verify sample sizes for each exposure group:
  - Control (n=?)
  - Direct exposure (n=?)
  - Prenatal exposure (n=?)
  - Germline exposure (n=?)

**Step 2.2: Define Exposure Contrasts**

Three separate EWAS comparisons:

1. **Direct Exposure vs Control**
   - Individuals directly exposed to violence (older siblings in 2011 group)
   - Controls: Syrian families in Jordan before 1980

2. **Prenatal Exposure vs Control**
   - In utero during violence (younger siblings in 2011, F2 in 1980)
   - Controls: Syrian families in Jordan before 1980

3. **Germline Exposure vs Control**
   - Parent exposed during pregnancy (F3 in 1980 group)
   - Controls: Syrian families in Jordan before 1980

**Step 2.3: Robust Linear Regression (Stage 1)**

For each CpG probe (768,625 probes):
- Model: `beta ~ exposure + age + sex + epithelial_proportion`
- Use robust linear regression with robust standard errors
- Extract coefficients, p-values, and effect sizes
- Run separately for each of 3 exposure contrasts

**Output per contrast:**
- β coefficients for exposure effect
- Standard errors
- P-values
- Adjusted R²

**Step 2.4: GEE Models (Stage 2)**

Apply Generalized Estimating Equations with family clustering:
- Model: `beta ~ exposure + age + sex + epithelial_proportion`
- Clustering variable: `family` (accounts for related individuals)
- Correlation structure: Exchangeable
- Run for same 3 exposure contrasts

**Output per contrast:**
- β coefficients
- Robust standard errors
- P-values accounting for family structure

**Step 2.5: Identify Significant DMPs**

For each exposure contrast:
- Require Bonferroni significance in **BOTH** Stage 1 AND Stage 2
- Bonferroni threshold: p < 6.505×10⁻⁸ (0.05 / 768,625 probes)
- Extract probes meeting dual significance criteria

**Expected results:**
- Direct exposure: X DMPs
- Prenatal exposure: Y DMPs
- Germline exposure: Z DMPs

**Step 2.6: Annotate DMPs**

For each significant DMP:
- Map to genomic coordinates (hg38)
- Annotate with gene name(s) using GENCODE v36
- Determine genomic context:
  - CpG island location
  - Relation to TSS
  - Regulatory features (enhancers, TFBS, DNase sites)
- Calculate effect sizes and direction (hyper/hypomethylation)

**Step 2.7: Sensitivity Analyses**

**A. Age-adjusted analysis (Direct vs Control):**
- Remove 2 grandmothers (F1 generation)
- Restrict to F2+F3 generations only
- Re-run robust regression + GEE
- Compare results to main analysis

**B. Cohort-specific analysis (Germline vs Control):**
- Restrict to 1980 cohort children only
- Control: Children from families in Jordan before 1980
- Re-run analysis
- Assess consistency with main findings

**C. Dose-response analysis:**
- At significant DMPs, test linear association with Trauma Events score
- Model: `beta ~ trauma_events_count + covariates`
- Assess whether methylation changes scale with trauma intensity

**Step 2.8: Enrichment Analyses (GOmeth)**

For each exposure contrast:
- Select top DMPs based on p-value cutoffs:
  - Direct vs Control: p < 4.5×10⁻⁴ (~5000 DMPs)
  - Prenatal vs Control: p < 4.7×10⁻³ (~5000 DMPs)
  - Germline vs Control: p < 1.5×10⁻³ (~5000 DMPs)
- Run `missMethyl::gometh()` for GO enrichment
- Test Biological Process GO terms with 20-200 DMPs
- Apply FDR correction (q ≤ 0.1)

**Output:**
- Enriched GO terms per contrast
- Overlap analysis between contrasts
- Biological pathway interpretation

### Expected Outputs

| File | Size | Description |
|------|------|-------------|
| `IGP_HiperGator_Code_v24.html` | 13 MB | EWAS results report |
| DMP tables (CSV) | Variable | Significant DMPs per contrast |
| GO enrichment results | Variable | Pathway analysis outputs |

### Key Metrics to Monitor
- Number of DMPs per contrast at Bonferroni threshold
- Direction of effects (% hypermethylated vs hypomethylated)
- Lambda inflation factor (genomic control)
- Overlap between exposure groups
- Top enriched pathways

---

## Stage 3: Epigenetic Age Quality Control

### Purpose
Calculate epigenetic age using multiple clock algorithms and perform quality control before acceleration analysis.

### Input Files Required

**From `data/idat/`:**
- All 320 `.idat` files (same as Stage 1)

**Metadata (from `data/23498670/`):**
- `cMulligan_SampleSheet160.csv`
- `cMulligan_SampleManifest160.csv`
- `igp_ages.csv`
- `IGP_SwabType.csv`
- `igp_geo_metadata_v3.csv`

**Pre-calculated Horvath outputs:**
- `igp_horvath_betas_20211104.csv` (79 MB)
- `igp_horvath_samplesheet_20211104.csv`
- `igp_horvath_betas_20211104.output.csv`

**PC-Clocks resources (from `data/23498670/`):**
- `CalcAllPCClocks.RData` (2.2 GB) - PC-Clocks calculation data
- `Example_PCClock_Data_final.RData` (243 MB)
- `run_calcPCClocks.R` - PC-Clocks calculation function
- `run_calcPCClocks_Accel.R` - Acceleration calculation
- `template_get_PCClocks_script.R` - Template script

### Scripts
- `data/23498670/igp_epigenetic_age_quality_control_20230611.Rmd` (main analysis)
- `data/23498670/run_calcPCClocks.R` (sourced function)
- `data/23498670/run_calcPCClocks_Accel.R` (sourced function)

### Directory Structure Setup

```bash
project_root/
├── IGP.Rproj
├── data/
│   ├── *.idat (all 320 IDAT files)
│   └── cMulligan_SampleSheet160.csv
├── script/
│   ├── igp_epigenetic_age_quality_control_20230611.Rmd
│   ├── run_calcPCClocks.R
│   ├── run_calcPCClocks_Accel.R
│   ├── template_get_PCClocks_script.R
│   ├── CalcAllPCClocks.RData
│   └── Example_PCClock_Data_final.RData
├── output/
│   ├── igp_horvath_betas_20211104.csv
│   ├── igp_horvath_samplesheet_20211104.csv
│   ├── igp_horvath_betas_20211104.output.csv
│   └── igp_geo_metadata_v3.csv
└── supp_data/
    ├── cMulligan_SampleManifest160.csv
    ├── IGP_SwabType.csv
    └── igp_ages.csv
```

### Analysis Steps

**Step 3.1: Load IDAT Files**
- Read all 160 sample pairs (320 IDAT files)
- Use `SeSAMe::readIDATpair()` for noob normalization
- Extract beta values matrix
- Verify all samples loaded correctly

**Step 3.2: Calculate Classic Epigenetic Ages**

Using `methylCIPHER` package (https://github.com/MorganLevineLab/PC-Clocks):

**A. Horvath1 (2013) - Multi-tissue clock**
- 353 CpG sites
- Applicable across multiple tissues
- Already calculated in `igp_horvath_betas_20211104.output.csv`

**B. Horvath2 (2018) - Skin & Blood clock**
- 391 CpG sites
- Optimized for skin and blood tissue
- Calculate using `methylCIPHER::calcAge()`

**C. PEDBE (2019) - Pediatric Buccal-Epigenetic**
- Designed for pediatric buccal samples
- Calculate using `methylCIPHER::calcAge()`

**Step 3.3: Calculate PC-Clocks**

Load PC-Clocks model data from `CalcAllPCClocks.RData`:

**PC-Clocks to calculate:**
1. **PCHorvath1** - PC version of Horvath (2013)
2. **PCHorvath2** - PC version of Horvath (2018)
3. **PCHannum** - PC version of Hannum clock
4. **PCPhenoAge** - PC version of PhenoAge
5. **PCGrimAge** - PC version of GrimAge
6. **PCDNAmTL** - PC-based telomere length estimator
7. **PCPACKYRS** - Smoking pack-years estimator
8. **PCADM** - Adrenomedullin
9. **PCB2M** - Beta-2-microglobulin
10. **PCCystatinC** - Cystatin C
11. **PCGDF15** - Growth differentiation factor 15
12. **PCLeptin** - Leptin
13. **PCPAI1** - Plasminogen activator inhibitor-1
14. **PCTIMP1** - Tissue inhibitor metalloproteinases-1

**Calculation process:**
```r
source("script/run_calcPCClocks.R")

# Create phenotype data frame
datPheno <- data.frame(
  sampleId = sample_ids,
  Age = chronological_ages,
  Female = sex_indicator
)

# Calculate PC clocks
pc_ages <- calcPCClocks(
  path_to_PCClocks_directory = "script/",
  datMeth = beta_matrix,
  datPheno = datPheno
)
```

**Step 3.4: Quality Control Checks**

**A. Age prediction accuracy:**
- Scatter plots: Epigenetic age vs chronological age
- Calculate correlation coefficients for each clock
- Expected correlations: R > 0.85 for most clocks
- Identify outlier samples (residuals > 3 SD)

**B. Distribution checks:**
- Histogram of epigenetic ages per clock
- Box plots by exposure group
- Check for systematic biases or batch effects

**C. Replicate concordance:**
- For samples with technical replicates
- Calculate ICC (intraclass correlation)
- Expected ICC > 0.95 for good reproducibility

**D. Missing data assessment:**
- Check % of clock CpGs available per sample
- Flag samples with >10% missing clock probes

**Step 3.5: Calculate Age Acceleration (Residuals)**

For each epigenetic clock:
- Regress epigenetic age on chronological age
- Extract residuals = Age Acceleration
- Positive residuals = accelerated aging
- Negative residuals = decelerated aging

```r
# Example for Horvath2
model <- lm(Horvath2 ~ Age, data = datPheno)
datPheno$Horvath2Accel <- residuals(model)
```

Calculate acceleration for all clocks:
- Horvath1Accel, Horvath2Accel, PEDBEAccel
- PCHorvath1Resid, PCHorvath2Resid, PCHannumResid
- PCPhenoAgeResid, PCGrimAgeResid, PCDNAmTLResid

**Step 3.6: Merge with Metadata**

Combine all epigenetic age data with:
- Sample metadata (from `igp_geo_metadata_v3.csv`)
- Exposure variables
- Cell type proportions (epithelial)
- Technical variables (plate, slide, replicate status)

**Step 3.7: Create Final Dataset**

**Output file structure (basis for `epigenetic_age_data_20230308.csv`):**
- Sample identifiers (sampleId, Sample_Name, Sentrix info)
- Demographics (Age, Sex, generation, family)
- Classic clocks (Horvath1, Horvath2, PEDBE)
- PC clocks (all 14 PC measures)
- Acceleration metrics (all *Accel and *Resid)
- Exposure variables (violence_trauma, conflict_exposed_to, generation_of_conflict_exposure)
- Socioeconomic (SES, material_deprivation, food_security)
- Technical (plate, slide, replicate, QC flags)
- Cell type (epithelial_cell_proportion)

### Expected Outputs

| File | Size | Description |
|------|------|-------------|
| Epigenetic age dataset (CSV) | ~140 KB | All clocks + acceleration + metadata |
| QC plots (PDF/PNG) | Variable | Age prediction scatter plots |
| Summary statistics | Variable | Correlation matrices, ICC values |

### Key Metrics to Monitor
- Age prediction R² for each clock (expect R² > 0.7)
- Replicate ICC (expect > 0.95)
- Missing data per sample (<10% clock probes)
- Outlier samples (flag if residual > 3 SD)
- No systematic bias by plate or batch

---

## Stage 4: Epigenetic Age Acceleration Analysis

### Purpose
Test associations between violence trauma exposure and epigenetic age acceleration using GEE models with family clustering.

### Input Files Required

**From Stage 3 output:**
- `epigenetic_age_data_20230308.csv` (133 KB) - Main dataset with 146 samples
- `replicate_epigenetic_age_data_20230308.csv` (141 KB) - Dataset including technical replicates (156 rows)

### Script
`data/23498658/igp_epigenetic_age_analysis_v6 (1).Rmd`

### Directory Structure Setup

```bash
project_root/
├── IGP.Rproj
├── data/
│   ├── epigenetic_age_data_20230308.csv
│   └── replicate_epigenetic_age_data_20230308.csv
└── script/
    └── igp_epigenetic_age_analysis_v6.Rmd
```

### Analysis Steps

**Step 4.1: Data Loading & Preparation**
- Load `epigenetic_age_data_20230308.csv` (n=146, no replicates)
- Load `replicate_epigenetic_age_data_20230308.csv` (n=156, includes replicates)
- Verify sample sizes per exposure group:
  - Control
  - Direct exposure
  - Prenatal exposure
  - Germline exposure

**Step 4.2: Descriptive Statistics**

**A. Sample characteristics by exposure group:**
- Mean age ± SD
- Sex distribution (% female)
- Generation distribution (F1/F2/F3)
- Mean epithelial cell proportion
- Socioeconomic indicators

**B. Epigenetic age summaries:**
- Mean epigenetic age per clock, by group
- Correlation matrix between clocks
- Chronological age vs epigenetic age plots

**Step 4.3: Primary Analysis - Age Acceleration by Exposure**

**Model specification (GEE with family clustering):**
```r
library(geepack)

model <- geeglm(
  EpigeneticAgeAccel ~ exposure_group + age + sex + epithelial_proportion,
  data = dataset,
  id = extended_family,  # Cluster by family
  corstr = "exchangeable"
)
```

**Run for each epigenetic age acceleration metric:**

**Classic clock accelerations:**
- Horvath1Accel
- Horvath2Accel
- PEDBEAccel

**PC clock residuals:**
- PCHorvath1Resid
- PCHorvath2Resid
- PCHannumResid
- PCPhenoAgeResid
- PCGrimAgeResid
- PCDNAmTLResid

**Exposure contrasts tested:**
1. Direct vs Control
2. Prenatal vs Control
3. Germline vs Control
4. All exposed vs Control (combined)

**Step 4.4: Extract Results**

For each clock and contrast:
- β coefficient for exposure effect
- Robust standard error
- 95% confidence interval
- P-value (Wald test)
- Adjust for multiple testing (Bonferroni or FDR)

**Results table format:**
| Clock | Contrast | β | SE | 95% CI | p-value | p-adj |
|-------|----------|---|----|----|---------|-------|
| Horvath1Accel | Direct vs Control | ... | ... | ... | ... | ... |
| Horvath2Accel | Prenatal vs Control | ... | ... | ... | ... | ... |
| ... | ... | ... | ... | ... | ... | ... |

**Step 4.5: Replicate Analysis**

Using `replicate_epigenetic_age_data_20230308.csv`:
- Include technical replicates in analysis
- Assess whether results are consistent
- Calculate ICC for replicated samples
- Report sensitivity of findings to replicate inclusion

**Step 4.6: Sensitivity Analyses**

**A. Generation-stratified analysis:**
- Restrict to F2 generation only
- Restrict to F3 generation only
- Test whether exposure effects differ by generation

**B. Sex-stratified analysis:**
- Males only
- Females only
- Test for sex × exposure interaction

**C. Adjustment for socioeconomic factors:**
- Add SES, material_deprivation, food_security to model
- Assess whether trauma effects are independent of SES

**D. Cell type sensitivity:**
- Run models without epithelial proportion adjustment
- Run models with stricter epithelial proportion matching
- Assess robustness of findings

**Step 4.7: Visualization**

Create publication-quality figures:

**A. Forest plots:**
- Effect sizes (β) and 95% CI for each clock
- Separate panels for each exposure contrast
- Highlight significant associations

**B. Box plots:**
- Age acceleration by exposure group
- Separate plots for each significant clock
- Add individual data points, show means and CI

**C. Correlation heatmaps:**
- Correlations between different clock accelerations
- By exposure group
- Identify clock-specific vs shared patterns

**D. Dose-response plots:**
- Age acceleration vs Trauma Events score
- For clocks showing significant associations
- Scatter plots with regression lines

**Step 4.8: Biological Interpretation**

For significant associations:
- Interpret direction (accelerated vs decelerated aging)
- Calculate effect sizes in "years" of age difference
- Compare across different clocks (tissue-specific vs pan-tissue)
- Discuss biological plausibility (stress pathways, inflammation, etc.)

### Expected Outputs

| File | Size | Description |
|------|------|-------------|
| `igp_epigenetic_age_analysis_v6 (12).html` | 6.3 MB | Final analysis report |
| Results tables (CSV) | Variable | Association statistics per clock |
| Figures (PNG/PDF) | Variable | Forest plots, box plots, heatmaps |

### Key Metrics to Monitor
- Statistical power (n per group)
- Effect sizes (years of age acceleration)
- Multiple testing correction threshold
- Consistency across clocks
- Robustness in sensitivity analyses

---

## External Dependencies & Prerequisites

### R Packages Required

**Core analysis packages:**
- `ewastools` - Contamination checking, sex prediction
- `meffil` - Quality control, normalization
- `sesame` (SeSAMe) - Noob normalization, dye bias correction
- `methylCIPHER` - Epigenetic age calculation (from MorganLevineLab/PC-Clocks)

**Statistical packages:**
- `geepack` - GEE models
- `sva` - ComBat batch correction
- `limma` - Robust regression
- `EpiDISH` - Cell type deconvolution
- `missMethyl` - GO enrichment (gometh)

**Data manipulation:**
- `tidyverse` (dplyr, ggplot2, etc.)
- `data.table`
- `here` - Path management

**Annotation:**
- `IlluminaHumanMethylationEPICanno.ilm10b4.hg19`
- `IlluminaHumanMethylationEPICmanifest`

### External Resources to Download

**PC-Clocks package:**
```r
# Install from GitHub
devtools::install_github("MorganLevineLab/PC-Clocks")
```

**Reference:**
- Paper: https://www.biorxiv.org/content/10.1101/2022.07.13.499978v1
- GitHub: https://github.com/MorganLevineLab/PC-Clocks

**GEO Dataset GSE226085:**
- All 320 IDAT files (160 samples × 2 channels)
- Download from: https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE226085

---

## Missing/External Components

### Pre-calculated Files

Several files appear to be generated outside the provided scripts:

**1. Horvath Clock Outputs**
- `igp_horvath_betas_20211104.output.csv`
- Calculated using Horvath's online calculator or separate pipeline
- Need to either:
  - Use Horvath's DNA Methylation Age Calculator (online tool)
  - Implement Horvath clock manually in R
  - Use `methylCIPHER` package implementation

**2. Subset Dataset**
- `igp_methylation_special.rds` (53 MB)
- Appears to be a filtered/subset version of `final_igp_data.rds`
- May need to recreate based on inclusion criteria

**3. Beta Values for Horvath**
- `igp_horvath_betas_20211104.csv` (79 MB)
- Extracted beta values for Horvath clock CpGs only
- Can be regenerated from full IDAT processing

### Potential Script Modifications Needed

**1. File path adjustments:**
- Scripts use `here::here()` for path management
- May need to adjust relative paths depending on directory structure
- Update IDAT file paths in sample sheets

**2. Memory optimization:**
- 128 GB RAM recommended but may need tuning
- Consider processing in batches if memory limited
- Save intermediate objects to disk

**3. Parallel processing:**
- Scripts may benefit from parallelization
- Use `BiocParallel` or `parallel` packages
- Adjust number of cores based on available resources

**4. Package versions:**
- Scripts written for specific package versions
- May encounter compatibility issues with newer versions
- Document package versions used (use `renv` or `packrat`)

**5. Missing metadata creation:**
- `igp_geo_metadata_v3.csv` appears to be manually curated
- Combines multiple metadata sources
- May need to recreate merging logic

---

## Data Validation Checkpoints

### After Stage 1 (QC):
- [ ] 160 samples processed successfully
- [ ] 768,625 probes retained after filtering
- [ ] No contaminated samples (SNP outlier > -4)
- [ ] Sex predictions match reported sex
- [ ] Age predictions correlate with chronological age (R² > 0.9)
- [ ] `final_igp_data.rds` is 720 MB
- [ ] `combatBetas.rds` is 871 MB

### After Stage 2 (EWAS):
- [ ] Three EWAS comparisons completed
- [ ] Bonferroni threshold applied (p < 6.505×10⁻⁸)
- [ ] DMPs identified for each contrast
- [ ] GO enrichment results with FDR q ≤ 0.1
- [ ] Sensitivity analyses completed
- [ ] Results match published findings

### After Stage 3 (Epigenetic Age QC):
- [ ] All 14 PC-clocks calculated
- [ ] Classic clocks (Horvath1, Horvath2, PEDBE) calculated
- [ ] Age prediction R² > 0.7 for all clocks
- [ ] Replicate ICC > 0.95
- [ ] Age acceleration residuals calculated
- [ ] Dataset has 146 samples (non-replicate) or 156 (with replicates)

### After Stage 4 (Age Acceleration Analysis):
- [ ] GEE models converged for all clocks
- [ ] Results for all exposure contrasts
- [ ] Sensitivity analyses completed
- [ ] Figures generated
- [ ] Results consistent with publication

---

## Expected Timeline

| Stage | Task | Estimated Time |
|-------|------|----------------|
| **Setup** | Download IDAT files from GEO | 2-4 hours |
| **Setup** | Organize directory structure | 30 min |
| **Setup** | Install R packages | 1-2 hours |
| **Stage 1** | Quality control & normalization | 8-12 hours (compute time) |
| **Stage 1** | Review QC outputs, finalize dataset | 2-4 hours (manual) |
| **Stage 2** | EWAS analysis (3 contrasts) | 12-24 hours (compute time) |
| **Stage 2** | Enrichment analysis | 2-4 hours |
| **Stage 2** | Interpretation & validation | 4-8 hours (manual) |
| **Stage 3** | Epigenetic age calculation | 4-8 hours (compute time) |
| **Stage 3** | QC and acceleration metrics | 2-4 hours |
| **Stage 4** | Age acceleration analysis | 2-4 hours |
| **Stage 4** | Sensitivity analyses | 2-4 hours |
| **Stage 4** | Visualization & interpretation | 4-8 hours (manual) |
| **Total** | **~40-80 hours compute + 14-28 hours manual** | **~1-2 weeks** |

**Note**: Compute times assume 16-core, 128 GB RAM system. Times will vary based on hardware.

---

## Troubleshooting Common Issues

### Issue 1: IDAT files not found
**Solution**: Verify IDAT file paths in sample sheet match actual file locations. Ensure files are unzipped.

### Issue 2: Out of memory errors
**Solution**: Increase RAM, process in batches, or use disk-backed matrices (e.g., `HDF5Array`).

### Issue 3: Package installation failures
**Solution**: Install Bioconductor packages using `BiocManager::install()`. Check R version compatibility.

### Issue 4: Horvath clock calculation missing
**Solution**: Use Horvath's online calculator or implement using `methylCIPHER` package.

### Issue 5: GEE models not converging
**Solution**: Check for perfect collinearity, scale variables, increase iteration limit.

### Issue 6: Different results from publication
**Solution**: Verify package versions, check random seeds, ensure same filtering criteria, validate metadata.

---

## Publication Reproducibility Notes

### Expected Findings from Paper:

**EWAS Results:**
- Significant DMPs in all three exposure groups
- Enrichment in specific biological pathways
- Genes related to stress response, immune function, development

**Epigenetic Age Acceleration:**
- Evidence of accelerated aging in exposed groups
- Variation by generation and exposure type
- Specific clocks showing stronger associations

**Key Figures to Reproduce:**
- Figure 1: Study design and sample flow
- Figure 2: EWAS Manhattan plots
- Figure 3: DMPs and enriched pathways
- Figure 4: Epigenetic age acceleration by group

### Validation Strategy:

1. **Exact replication**: Follow pipeline exactly as documented
2. **Compare intermediate outputs**: Check file sizes, sample counts, probe counts
3. **Statistical validation**: Match p-values, effect sizes, confidence intervals
4. **Visual comparison**: Regenerate figures and compare to publication
5. **Document deviations**: Note any differences and investigate causes

---

## Citation

When using this replication guide, please cite the original publication:

Mulligan CJ, Nusinovici S, Messer LB, et al. Intergenerational epigenetic inheritance of violence trauma in Syrian refugee families. *Sci Rep*. 2025;15:3621.

**PMC**: https://pmc.ncbi.nlm.nih.gov/articles/PMC11868390/
**DOI**: 10.1038/s41598-025-86783-9
**GEO**: GSE226085

---

**Last Updated**: 2025-10-02
**Status**: Draft replication plan - requires testing and validation
