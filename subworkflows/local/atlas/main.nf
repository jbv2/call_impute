include { ATLAS_CALL } from '../../../modules/nf-core/atlas/call/main'
include { ATLAS_RECAL } from '../../../modules/nf-core/atlas/recal/main'
include { ATLAS_PMD } from '../../../modules/nf-core/atlas/pmd/main' 
include { ATLAS_SPLITMERGE } from '../../../modules/nf-core/atlas/splitmerge/main' 

workflow ATLAS {

    take:
    bam_file // [meta, bam, bai, rg, chr]
    fasta_file
    fai_file

    main:
    ch_versions       = Channel.empty()

    ch_bam = bam_file
    ch_fasta = fasta_file
    ch_fai = fai_file

    // Run ATLAS PMD
    ch_input_pmd = ch_bam

    ch_pmd_output = ATLAS_PMD(ch_bam, ch_fasta, ch_fai)
    ch_versions = ch_versions.mix(ATLAS_PMD.out.versions)


    // Run RECAL
    ch_recal_input = ch_input_pmd
    .map{ meta, bam, bai, rg, chr ->
        [meta, chr, bam, bai, rg ]
    }
    .combine(ch_pmd_output.empiric, by: [0,1]).distinct()
    .map {meta, chr, bam, bai, rg, empiric ->
        [meta, bam, bai, empiric, rg, chr]
    }

    ch_recal_regions = Channel.from(params.atlas_recal_regions)
    ch_recal_input_chr = ch_recal_input
    .filter { meta, bam, bai, empiric, rg, chr ->
        chr == 20 // Here use chrom 20
    }
    .map{
        meta, bam, bai, empiric, rg, chr ->
        [meta, bam, bai, empiric, rg]
    }
    .combine(ch_recal_regions)
    .multiMap{ meta, bam, bai, empiric, rg, regions ->
        input: [meta, bam, bai, empiric, rg]
        regions: regions
        alleles: []
        sites: []
    }

    ATLAS_RECAL(ch_recal_input_chr.input, ch_recal_input_chr.regions, ch_recal_input_chr.alleles, ch_recal_input_chr.sites)
    ch_versions = ch_versions.mix(ATLAS_RECAL.out.versions)


    // RUN ATLAS CALL

    ch_known_alleles = Channel.from(params.alleles)
    ch_method = Channel.from(params.method)

    ch_refs = ch_fasta
    .merge(ch_fai)
    .merge(ch_known_alleles)
    .merge(ch_method)

    ch_atlas_call_input = ch_recal_input // meta, bam, bai, empiric, rg, chr
    .combine(ATLAS_RECAL.out.recal_patterns, by: 0)
    .combine(ch_refs)
    .multiMap{ meta, bam, bai, empiric, rg, chr, recal, fasta, fai, known_alleles, method ->
        bam: [meta, bam, bai, empiric, recal, chr]
        fasta: fasta
        fai: fai
        known_alleles: known_alleles
        method: method
    }

    ch_calls = ATLAS_CALL(ch_atlas_call_input.bam, ch_atlas_call_input.fasta, ch_atlas_call_input.fai, ch_atlas_call_input.known_alleles, ch_atlas_call_input.method) 
    ch_versions = ch_versions.mix(ATLAS_CALL.out.versions)

    emit:
    vcfs     = ch_calls.vcf
    versions = ch_versions


}