process BCFTOOLS_VIEW {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(vcf), val(chr)

    output:
    tuple val(meta), path("*.recompressed.vcf.gz"), path("*.csi"), val(chr), emit: csi
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.${chr}"

    """
    zcat $vcf \\
    | bcftools \\
        view \\
        $args \\
        --threads $task.cpus \\
        -Oz \\
        --write-index=csi \\
        -o ${prefix}.recompressed.vcf.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

}
