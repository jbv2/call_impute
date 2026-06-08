#!/usr/bin/env nextflow

/* 
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 'call_impute' - A Nextflow pipeline to call genotypes with ATLAS and optionally impute with GLIMPSE
 v0.1.0
May 2026
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 Judith Ballesteros Villascán
 GitHub: https://github.com/jbv2/call_impute
 ----------------------------------------------------------------------------------------
 */

/* 
 Enable DSL 2 syntax
 */
nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Installed directly from nf-core/subworkflows
//

//include { VCF_IMPUTE_GLIMPSE } from './subworkflows/nf-core/vcf_impute_glimpse/main'

//
// MODULE: Installed directly from nf-core/modules
//
include { BCFTOOLS_REHEADER } from './modules/nf-core/bcftools/reheader/main'
// include { BCFTOOLS_REHEADER as BCFTOOLS_REHEADER_HC } from './modules/nf-core/bcftools/reheader/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BCFTOOLS_VIEW } from './modules/local/bcftools/view/main'
include { BCFTOOLS_MERGE } from './modules/local/bcftools/merge/main'


// 
// MODULES: Consisting of local modules
//

//include { ASSIGN2RUN } from './modules/local/assign2run/main'
include { SETRG } from './modules/local/setRG/main'
include { SAMTOOLS_SPLITBAM } from './modules/local/samtools/splitbam/main'
include { SAMTOOLS_MERGE } from './modules/local/samtools/merge/main'
include { DEF_NEWNAMES } from './modules/local/def_newnames/main'
include { BCFTOOLS_CALL } from './modules/local/bcftools/call/main'
include { BCFTOOLS_CONCAT } from './modules/local/bcftools/concat/main'
include { BCFTOOLS_GET_1240K } from './modules/local/bcftools/get_1240k/main'
include { BCFTOOLS_STATS_1240K } from './modules/local/bcftools/stats_1240k/main'



//
// SUBWORKFLOW: Consisting of local subworkflows
//
include { ATLAS } from './subworkflows/local/atlas/main'
include { GLIMPSE } from './subworkflows/local/glimpse/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    ch_versions = Channel.empty()

    
// Read the TSV file and extract columns
    ch_samples = Channel
        .fromPath(params.input)
        .splitCsv(header: true, sep: '\t')
        .map { row -> 
            def meta = [ id: row.sample ]
            def bam  = file(row.bam)
            def bai  = file(row.bai)
            return [meta, bam, bai]
        }
        .groupTuple(by: 0)

    // Branch: multi-BAM vs single-BAM
    ch_samples
        .branch { meta, bams, bais ->
            merge:  bams.size() > 1
            single: true
        }
        .set { ch_bam_branch }

    // Merge multi-BAM samples
    SAMTOOLS_MERGE(ch_bam_branch.merge)

    // Flatten single-BAM samples from [meta, [bam], [bai]] -> [meta, bam, bai]
    ch_single_normalized = ch_bam_branch.single
        .map { meta, bams, bais -> 
            [meta, bams[0], bais[0]]  // Unwrap single-element lists
        }

    // Combine both into a single channel for downstream use
    ch_merged_bams = SAMTOOLS_MERGE.out.merged_bam
    .mix(ch_single_normalized)

SETRG(ch_merged_bams)
ch_rg_output = ch_merged_bams
ch_rg_txt = SETRG.out.rg_txt

// Split bam in chromosomes
ch_i = Channel.fromList(params.chromosomes)
//ch_i = Channel.of(20)
ch_input_split = ch_rg_output
    .combine(ch_i)
    .map { meta, bam, bai, chr ->
        return [meta, bam, bai, chr]
    }
ch_splittedbam = SAMTOOLS_SPLITBAM(ch_input_split).split_bam

ch_fasta = Channel.from(params.fasta)
ch_fai = Channel.from(params.fai)

ch_atlas_input = ch_splittedbam
.combine(ch_rg_txt, by:0).distinct()
.combine(ch_fasta)
.combine(ch_fai)
.multiMap { meta, bam, bai, chr, rg_txt, fasta, fai ->
    bam: [meta, bam, bai, rg_txt, chr]
    fasta: fasta
    fai: fai
}

//Subworkflow: ATLAS 
ATLAS(ch_atlas_input.bam, ch_atlas_input.fasta, ch_atlas_input.fai)

// BCFTOOLS MERGE: To merge all individual chromosome VCFs

ch_project_name = Channel.from(params.project_name)

// ATLAS output not compatible with bcftools
// Re-compressing for compatibility
BCFTOOLS_VIEW(ATLAS.out.vcfs)

// split per sample

DEF_NEWNAMES(BCFTOOLS_VIEW.out.csi)

// Rename 
ch_reheader_input = BCFTOOLS_VIEW.out.csi
    .map { meta, vcf, index, chr ->
        return [meta, vcf, chr]
    }.combine(DEF_NEWNAMES.out.samples, by: [0,2])
    .multiMap{meta, chr, vcf, samples ->
    vcf: [meta, vcf, [], samples, chr]
    fasta: [[], []]}

BCFTOOLS_REHEADER(ch_reheader_input.vcf, ch_reheader_input.fasta)


if (params.run_glimpse) {

// Call missing with bcftools

ch_bcftools_alleles = Channel.from(params.bcftools_alleles)
ch_snps_only = Channel.from(params.ref_snps_only)

ch_input_call_missing = ch_splittedbam
.combine(ch_fasta)
.combine(ch_fai)
.combine(ch_bcftools_alleles)
.combine(ch_snps_only)
.multiMap { meta, bam, bai, chr, fasta, fai, alleles, snps ->
    bam: [meta, bam, bai, chr]
    fasta: fasta
    fai: fai
    alleles: alleles
    snps: snps
    }

BCFTOOLS_CALL(ch_input_call_missing.bam, ch_input_call_missing.fasta, ch_input_call_missing.fai, ch_input_call_missing.alleles, ch_input_call_missing.snps)

// Concat atlas & missing calls

ch_concat_input = BCFTOOLS_CALL.out.missing
.combine(BCFTOOLS_REHEADER.out.vcf, by: [0, 3]) // Ensure keys [0, 3] exist in both channels
.groupTuple(by: [0, 1]) // Group by meta and chr
.map { meta, chr, missing_vcf, missing_index, reheader_vcf, reheader_index ->
    return [meta, [missing_vcf, reheader_vcf].flatten(), [missing_index, reheader_index].flatten(), chr]
}


BCFTOOLS_CONCAT(ch_concat_input)

ch_vcfs = BCFTOOLS_CONCAT.out.concatenated
    .map { meta, vcf, csi, chr -> 
        return [chr, meta, vcf, csi ]
    }
    .groupTuple(by: 0)  // Group by chromosome
    .map{ chr, meta, vcf, csi ->
        return [ vcf, csi, chr] }
    .combine(ch_project_name)
    .map{ vcf, csi, chr, project_name -> 
        def meta = [id: project_name]
        return [meta, vcf, csi, chr]
    }

BCFTOOLS_MERGE(ch_vcfs) //
ch_merged_vcf = BCFTOOLS_MERGE.out.vcf

// Run GLIMPSE PHASE

// First loading reference files

ch_glimpse_ref = Channel.fromPath("${params.glimpse_ref}/chr*.vcf.gz")
    .map { file_path -> 
            def match = file_path.name =~ /.*chr(\d+)\.?.*\.vcf\.gz/
            def chr = match ? match[0][1].toInteger() : null  // Extract chromosome number if present
            def tbi_path = file_path.toString() + ".tbi"
            def csi_path = file_path.toString() + ".csi"

            // Check if .tbi or .csi exists and assign the appropriate path
            def index_path = file(tbi_path).exists() ? file(tbi_path) : file(csi_path).exists() ? file(csi_path) : null

            tuple(chr, file_path, file(index_path))  // Create (chr, vcf, tbi) tuple
    }

ch_glimpse_map = Channel.fromPath("${params.glimpse_map}/*.gmap.gz")
    .map { file_path -> 
        def match = file_path.name =~ /chr(\d+)\.?.*\.gmap\.gz/
        def chr = match ? match[0][1].toInteger() : null  // Extract chromosome number if present
        tuple(chr, file_path)  // Create (chr, file) tuple
    }

ch_glimpse_chunks = Channel.fromPath("${params.glimpse_chunks}/*.txt")
    .splitCsv(header: ['ID', 'Chr', 'RegionIn', 'RegionOut', 'Size1', 'Size2'], sep: "\t", skip: 0)
    .map { row -> 
        def chr = row["Chr"].toInteger()  // Extract chromosome number
        tuple(chr, row["RegionIn"], row["RegionOut"])  // Create (chr, RegionIn, RegionOut) tuple
    }
    .groupTuple(by: [0,1,2])

ch_phase_input = ch_merged_vcf
    .map{meta, vcf, csi, chr, samples -> 
        return [chr, meta, vcf, csi, samples]
    }
    .join(ch_glimpse_ref)
    .join(ch_glimpse_map)
    .combine(ch_glimpse_chunks, by: 0)
    .map{ chr, meta, vcf, csi, samples, ref, index, map, regionin, regionout ->
        return [meta, vcf, csi, samples, regionin, regionout, ref, index, map, chr]
    }
    
//Run GLIMPSE subworkflow 
GLIMPSE(ch_phase_input)

//  Subset only to the 1240k 
if (params.get_1240k == true ) {
    ch_1240k_csv = Channel.fromPath("${params.csv_1240k}/*.csv")
    .map { file_path -> 
            def match = file_path.name =~ /(\d+)\.csv/
            def chr = match ? match[0][1].toInteger() : null  // Extract chromosome number if present
            tuple(chr, file_path)  // Create (chr, bed) tuple
    }

    ch_1240k_input = GLIMPSE.out.annotated_vcf
    .map { meta, vcf, index, chr ->
        return [chr, meta, vcf, index]
    }
    .combine(ch_1240k_csv, by: 0)
    .multiMap {chr, meta, vcf, index, csv -> 
    vcf: [meta, vcf, index, chr]
    csv: csv
    }

BCFTOOLS_GET_1240K(ch_1240k_input.vcf, ch_1240k_input.csv)

// Collect ALL vcfs and indexes across all samples into single lists
ch_all_vcfs = BCFTOOLS_GET_1240K.out.vcf_1240k
    .map { meta, vcf, index, chr -> [vcf, index] }
    .collect()
    .map { files ->
        def vcfs  = files.findAll { it.toString().endsWith('.vcf.gz') }
        def index = files.findAll { it.toString().endsWith('.csi') }
        [vcfs, index]
    }

BCFTOOLS_STATS_1240K(ch_all_vcfs)

}

}

}