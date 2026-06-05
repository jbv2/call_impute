include { BCFTOOLS_INDEX as INDEX_PHASE } from '../../../modules/nf-core/bcftools/index/main'
include { BCFTOOLS_INDEX as INDEX_LIGATE } from '../../../modules/nf-core/bcftools/index/main'
include { BCFTOOLS_INDEX as INDEX_SAMPLE } from '../../../modules/nf-core/bcftools/index/main'
include { GLIMPSE_PHASE } from '../../../modules/nf-core/glimpse/phase/main'
include { GLIMPSE_LIGATE } from '../../../modules/nf-core/glimpse/ligate/main'
include { GLIMPSE_SAMPLE } from '../../../modules/local/glimpse/sample/main'
include { BCFTOOLS_ANNOTATE } from '../../../modules/local/bcftools/annotate/main'
include { BCFTOOLS_STATS_WG } from '../../../modules/local/bcftools/stats_wg/main'


workflow GLIMPSE {

    take:
    ch_input      // channel (mandatory): [meta, vcf, index, sample_infos, regionin, regionout, ref, ref_index, map, chr]

    main:

    ch_versions = Channel.empty()

GLIMPSE_PHASE ( ch_input ) // [meta, vcf, index, sample_infos, regionin, regionout, ref, ref_index, map, chr]
ch_versions = ch_versions.mix(GLIMPSE_PHASE.out.versions )
ch_phased = GLIMPSE_PHASE.out.phased_variants

// Index GLIMPSE phase output
INDEX_PHASE(ch_phased)
ch_versions = ch_versions.mix( INDEX_PHASE.out.versions )

ch_ligate_input = ch_phased
        .groupTuple( by: [0,2] )
        .combine( INDEX_PHASE.out.csi
            .groupTuple( by: 0 ),
            by: 0
        )
.map{meta, vcf, chr, csi ->
return[meta, vcf, csi, chr]}

GLIMPSE_LIGATE ( ch_ligate_input )
ch_ligated_vcfs = GLIMPSE_LIGATE.out.merged_variants    
ch_versions = ch_versions.mix(GLIMPSE_LIGATE.out.versions )

// Index GLIMPSE ligate output
INDEX_LIGATE(ch_ligated_vcfs)
ch_versions = ch_versions.mix( INDEX_LIGATE.out.versions )

// Run GLIMPSE SAMPLE
ch_glimpse_sample_input = ch_ligated_vcfs
.groupTuple( by: [0,2] )
        .combine( INDEX_LIGATE.out.csi
            .groupTuple( by: 0 ),
            by: 0
        )
.map{meta, vcf, chr, csi ->
return[meta, vcf, csi, chr]}

GLIMPSE_SAMPLE(ch_glimpse_sample_input)
ch_versions = ch_versions.mix(GLIMPSE_SAMPLE.out.versions )
INDEX_SAMPLE(GLIMPSE_SAMPLE.out.sample_vcf)
ch_versions = ch_versions.mix( INDEX_SAMPLE.out.versions )

// Annotate GP
ch_annotate_input = GLIMPSE_SAMPLE.out.sample_vcf
.groupTuple( by: [0,2] )
        .combine( INDEX_SAMPLE.out.csi
            .groupTuple( by: 0 ),
            by: 0
        )
    .map{meta, vcf, chr, csi ->
    return[meta, vcf, csi, chr]}
        .combine( ch_glimpse_sample_input,
            by: [0,3]
        )
    .map{ meta, chr, vcf, csi, ligated_vcf, lig_csi -> 
        return [meta, vcf, csi, ligated_vcf, lig_csi, chr]
    }


BCFTOOLS_ANNOTATE(ch_annotate_input)
ch_versions = ch_versions.mix( BCFTOOLS_ANNOTATE.out.versions )

// Add here stats fot WG vcfs
// Collect ALL vcfs and indexes across all samples into single lists
ch_all_vcfs = BCFTOOLS_ANNOTATE.out.vcf_annotated
    .map { meta, vcf, index, chr -> [vcf, index] }
    .collect()
    .map { files ->
        def vcfs  = files.findAll { it.toString().endsWith('.vcf.gz') }
        def index = files.findAll { it.toString().endsWith('.csi') }
        [vcfs, index]
    }

BCFTOOLS_STATS_WG(ch_all_vcfs)

emit:
annotated_vcf = BCFTOOLS_ANNOTATE.out.vcf_annotated
versions = ch_versions  

}