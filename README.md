# call_impute

Nextflow pipeline (DSL2) that runs ATLAS to infer genotype likelihoods and the run GLIMPSE to impute ancient genomes. 

---

### Workflow overview
![General Workflow](docs/Workflow.png) 

---


### Features
  **-v 0.1.0**

* Supports bams as input.
* Option to run glimpse or not and only get ATLAS output.
* Option to get only the 1240k
* Option to do post-imputation filtering
* Scalability and reproducibility via a Nextflow-based framework.

---

## Requirements
#### Compatible OS*:
* [Ubuntu 24.04.4 LTS](https://releases.ubuntu.com/focal/)
* macOS

#### Software:
|                            Requirement                            | Version  |              Required Commands *               |
| :---------------------------------------------------------------: | :------: | :--------------------------------------------: |
|         [bcftools](https://samtools.github.io/bcftools/)          |   1.23   | reheader,view,index,merge,annotate,call,concat |
|          [samools](https://samtools.github.io/samtools/)          |   1.23   |                   view,merge                   |
|  [nextflow](https://www.nextflow.io/docs/latest/getstarted.html)  | 26.04.3  |                    nextflow                    |
| [GLIMPSE](https://odelaneau.github.io/GLIMPSE/docs/documentation) |  1.1 )   |               chunk,ligate,phase               |
|              [atlas](https://atlaswiki.netlify.app/)              | v1.4.0.2 |                 call,pmd,recal                 |

\* These commands must be accessible from your `$PATH` (*i.e.* you should be able to invoke them from your command line).  

---

### Installation
Download nf-haplotype-selection from Github repository:  
```
git clone https://github.com/jbv2/call_impute.git
```
---

#### Test
To test `call_impute` execution using test data, run:
```bash
nextflow run main.nf -profile <test>
```

This pipeline can use nf-core Institutional profiles.
For MPI EVA people, please use the following to test on GRACE:

```bash
module load apptainer/1.5.0 ## to be able to run Nextflow
module load java/1.21.0 ## to use java for nextflow
module load bcftools/1.23.1
module load samtools/1.23.1
module load bcftools/1.23.1
module load htslib/1.23.1
module load GLIMPSE/1.1.1-static
which atlas ##verify you have atlas in your $PATH

nextflow run main.nf -profile eva_grace,test
```

---

### Usage
To run `call_impute` go to the pipeline directory and execute:

```bash
nextflow run main.nf \
  --inputVCF "<path to VCF input>" \ # Needs --input_type "vcf" --samples and --half_call
    --samples <Path to file with new sample names> \ # txt file with id famid_id needed when input is VCF.
    --half_call "<h>" \ # Plink option when VCF to PLINK on how to treat how to deal with '0/.'. See https://www.cog-genomics.org/plink/1.9/input
  --inputbed "<path to PLINK bed>" \ # Needs input_type = "plink"
  --inputgeno "<Path to EIGENSTRAT geno>" \ # Needs input_type = "eigenstrat"
  --input_type <'vcf','plink','eigenstrat'> \ # Select your input type
  --popA "<Vector for population(s) in A position>" \ # Vector. Example: "CEU YRI"
  --popB "<Vector for population(s) in B position>"  \ # Vector. Example: "CEU YRI"
  --popC "<Vector for population(s) in C position>" \ # Vector. Example: "CEU YRI"
  --popD "<Vector for population(s) in D position>"  \ # Vector. Example: "CEU YRI". Not needed in qp3Pop.
  --run_qpDstat <'true','false'> \ # Can not be used with --run_qp3Pop. Needs --f4mode
    --f4mode <"YES","NO"> \ # qpDstat option
  --run_qp3Pop <'true','false'> \ # Can not be used with --run_qpDstat. Needs --inbreed.
    --inbreed <"YES","NO"> \ # qp3Pop option
  --outdir <path to results> \ # Outdir 
```