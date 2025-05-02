process SAMTOOLS_SPLITBAM {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(bam), path(bai), val(chrom)

    output:
    tuple val(meta), path("*.split.bam"), path("*.split.bam.bai"), val(chrom), emit: split_bam
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    #!/usr/bin/env bash
    samtools view ${bam} $chrom -b > ${prefix}.${chrom}.split.bam
    samtools index ${prefix}.${chrom}.split.bam

    """
}