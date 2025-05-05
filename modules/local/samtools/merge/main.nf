process SAMTOOLS_MERGE {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(bams), path(bais) 

    output:
    tuple val(meta), path("*.merged.bam"), path("*.merged.bam.bai"), emit: merged_bam

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    #!/usr/bin/env bash

    ## merge & index
    samtools merge -pf ${prefix}.merged.bam ${bams.join(' ')} --threads $task.cpus
    samtools index ${prefix}.merged.bam --threads $task.cpus

    """
}