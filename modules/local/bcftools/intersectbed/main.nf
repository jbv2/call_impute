process BCFTOOLS_INTERSECTBED {
    tag "$meta.id"
    label 'process_single'
    scratch true

    input:
    tuple val(meta), path(vcf), path(index), val(chr)
    path(map_bed)

    output:
    tuple val(meta), path("*.filtered.vcf.gz"), path("*.filtered.vcf.gz.tbi"), val(chr),   emit: vcf_filtered

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.${chr}"
    """
    bcftools view \
        --regions-file $map_bed \
        $vcf \
        -Oz \
        -W=tbi \
        -o ${prefix}.filtered.vcf.gz
    """
}