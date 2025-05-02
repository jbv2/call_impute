process SETRG {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(bams), path(bais) 

    output:
    //tuple val(meta), path("*.merged.bam"), path("*.merged.bam.bai"), emit: merged_bam
    tuple val(meta), path("RG_*.txt"), emit: rg_txt optional true

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    #!/usr/bin/env bash

    ## merge & index
    #samtools merge -pf ${prefix}.merged.bam ${bams.join(' ')} --threads $task.cpus
    #samtools index ${prefix}.merged.bam --threads $task.cpus

    if [[ \$(samtools view -H ${bams} | grep "^@RG" | cut -f 2 | sed s/ID://g | wc -l) -ge 2 ]]; then
        samtools view -H ${bams} | grep "^@RG" | cut -f 2 | sed s/ID://g | tr '\n' ' ' > RG_${prefix}.txt
    else
        touch RG_${prefix}.txt
    fi
   

    """
}