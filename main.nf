#!/usr/bin/env nextflow

/* 
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 'call_impute' - A Nextflow pipeline to call genotypes with ATLAS and optionally impute with GLIMPSE
 v0.0.1
 March 2025
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

include { VCF_IMPUTE_GLIMPSE } from './subworkflows/nf-core/vcf_impute_glimpse/main'

//
// MODULE: Installed directly from nf-core/modules
//
include { BCFTOOLS_REHEADER } from './modules/nf-core/bcftools/reheader/main'
include { BCFTOOLS_REHEADER as BCFTOOLS_REHEADER_HC } from './modules/nf-core/bcftools/reheader/main'

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

include { ASSIGN2RUN } from './modules/local/assign2run/main'
include { SETRG } from './modules/local/setRG/main'
include { ATLAS_QUALITYTRANSFORMATION } from './modules/local/atlas/qualityTransformation/main'
include { SAMTOOLS_SPLITBAM } from './modules/local/samtools/splitbam/main'
include { DEF_NEWNAMES } from './modules/local/def_newnames/main'
include { DEF_NEWNAMES as DEF_NEWNAMES_HC} from './modules/local/def_newnames/main'
include { BCFTOOLS_MAF_GP } from './modules/local/bcftools/maf_gp/main'
include { BCFTOOLS_INTERSECTBED } from './modules/local/bcftools/intersectbed/main'
include { BCFTOOLS_INTERSECTBED as BCFTOOLS_INTERSECTBED_HIGHCOV} from './modules/local/bcftools/intersectbed/main'
include { BCFTOOLS_FILTER_QUAL_DP } from './modules/local/bcftools/filter_qual_dp/main'
include { BCFTOOLS_CALL } from './modules/local/bcftools/call/main'
include { BCFTOOLS_CONCAT } from './modules/local/bcftools/concat/main'


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
        .fromPath(params.input_tsv)
        .splitCsv(header: true, sep: '\t')
        .map { row -> 
            def meta = [ id: row.sample_id ]
            def bam  = file(row.bam)
            def bai  = file(row.bai)
            return [meta, bam, bai]
        }
        .groupTuple(by: 0) // Group by sample_id

SETRG(ch_samples)
ch_rg_output = ch_samples
ch_rg_txt = SETRG.out.rg_txt

// Split bam in chromosomes
ch_i = Channel.of(1..22)
//ch_i = Channel.of(20)
ch_input_split = ch_rg_output
    .combine(ch_i)
    .map { meta, bam, bai, chr ->
        return [meta, bam, bai, chr]
    }
ch_splittedbam = SAMTOOLS_SPLITBAM(ch_input_split)

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
// ATLAS(ch_splittedbam, ch_rg_txt, ch_fasta, ch_fai)
ATLAS(ch_atlas_input)

// BCFTOOLS MERGE: To merge all individual chromosome VCFs

ch_project_name = Channel.from(params.project_name)

BCFTOOLS_VIEW(ATLAS.out.vcfs)

//Rename .split

DEF_NEWNAMES_HC(BCFTOOLS_VIEW.out.csi)

ch_reheader_input_hc = BCFTOOLS_VIEW.out.csi
    .map { meta, vcf, index, chr ->
        return [meta, vcf, chr]
    }.combine(DEF_NEWNAMES_HC.out.samples, by: [0,2])
    .multiMap{meta, chr, vcf, samples ->
    vcf: [meta, vcf, [], samples, chr]
    fasta: [[], []]}

BCFTOOLS_REHEADER_HC(ch_reheader_input_hc)


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

BCFTOOLS_CALL(ch_input_call_missing)

// Concat atlas & missing calls

ch_concat_input = BCFTOOLS_CALL.out.missing
.combine(BCFTOOLS_REHEADER_HC.out.vcf, by: [0, 3]) // Ensure keys [0, 3] exist in both channels
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
    }.view()
    
//Run GLIMPSE subworkflow 
GLIMPSE(ch_phase_input)

//Rename .split
// DEF_NEWNAMES(GLIMPSE.out.annotated_vcf)

// ch_reheader_input = GLIMPSE.out.annotated_vcf
//     .map { meta, vcf, index, chr ->
//         return [meta, vcf, chr]
//     }.combine(DEF_NEWNAMES.out.samples, by: [0,2])
//     .multiMap{meta, chr, vcf, samples ->
//     vcf: [meta, vcf, [], samples, chr]
//     fasta: [[], []]}

// BCFTOOLS_REHEADER(ch_reheader_input)

// Run FILTER MAF and GP by sample
ch_max_raf = Channel.from(params.max_raf)
ch_min_raf = Channel.from(params.min_raf)
ch_gp = Channel.from(params.gp)

ch_maf_gp_input = GLIMPSE.out.annotated_vcf
.combine(ch_max_raf)
.combine(ch_min_raf)
.combine(ch_gp)
.multiMap{meta, vcf, index, chr, max_raf, min_raf, gp ->
    vcf: [meta, vcf, index, chr]
    raf: [min_raf, max_raf]
    gp: gp
    }

BCFTOOLS_MAF_GP(ch_maf_gp_input)

// ? Mask 1KGP, 35kmer and cpg islands
ch_mask_bed = Channel.fromPath("${params.mask_bed}/*.bed")
    .map { file_path -> 
            def match = file_path.name =~ /(\d+)\.bed/
            def chr = match ? match[0][1].toInteger() : null  // Extract chromosome number if present
            tuple(chr, file_path)  // Create (chr, bed) tuple
    }

// Post-process maf_gp output
ch_intersect_input = BCFTOOLS_MAF_GP.out.vcf_maf_gp
    .flatMap { meta, vcfs, csis, chr ->
        vcfs.collect { vcf ->
            def id = vcf.getBaseName().tokenize('.')[0]
            def new_meta = meta.clone()      // clone to avoid shared reference
            new_meta.id = id
            def csi = csis.find { it.name.startsWith(id) }
            tuple(new_meta, vcf, csi, chr)
        }
    }
    .map { meta, vcf, index, chr ->
        return [chr, meta, vcf, index]
    }
    .combine(ch_mask_bed, by: 0)
    .multiMap {chr, meta, vcf, index, bed -> 
    vcf: [meta, vcf, index, chr]
    bed: bed
    }

BCFTOOLS_INTERSECTBED(ch_intersect_input)

// ? 1240k 

// Concat

// Count overages GP > 0.8

// PLINK 
}

else {
    // High coverage individuals only 
    // Restrict to 1KGP accesible genome mask, 35kmer and cpg islands
    ch_mask_bed = Channel.fromPath("${params.mask_bed}/*.bed")
    .map { file_path -> 
            def match = file_path.name =~ /(\d+)\.bed/
            def chr = match ? match[0][1].toInteger() : null  // Extract chromosome number if present
            tuple(chr, file_path)  // Create (chr, bed) tuple
    }

ch_intersect_input = BCFTOOLS_REHEADER_HC.out.vcf
    .map { meta, vcf, csi, chr -> 
        return [chr, meta, vcf, csi ]
    }
    .combine(ch_mask_bed, by: 0)
    .multiMap {chr, meta, vcf, index, bed -> 
    vcf: [meta, vcf, index, chr]
    bed: bed
    }
 
BCFTOOLS_INTERSECTBED_HIGHCOV(ch_intersect_input)

// Filter QUAL and DP
ch_limits = Channel.from(params.limits)

ch_validation_input = BCFTOOLS_INTERSECTBED_HIGHCOV.out.vcf_filtered 
.combine(ch_limits)
.multiMap({meta, vcf, index, chr, limits ->
    vcf: [meta, vcf, index, chr]
    limits: limits
    })

BCFTOOLS_FILTER_QUAL_DP(ch_validation_input)

}

}