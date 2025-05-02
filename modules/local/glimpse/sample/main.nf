process GLIMPSE_SAMPLE {
    tag "$meta.id"
    label 'process_low'


    input:
    tuple val(meta), path(vcf), path(index), val(chr)

    output:
    tuple val(meta), path("*.{sample.vcf,sample.bcf,sample.vcf.gz,sample.bcf.gz}"), val(chr), emit: sample_vcf
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.${chr}"
    def suffix = task.ext.suffix ?: "sample.vcf.gz"
    """

    GLIMPSE_sample \\
        $args \\
        --input $vcf \\
        --thread $task.cpus \\
        --solve \\
        --output ${prefix}.${suffix}

    cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            glimpse: "\$(GLIMPSE_sample --help | sed -nr '/Version/p' | grep -o -E '([0-9]+.){1,2}[0-9]')"
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.${chr}"
    def suffix = task.ext.suffix ?: "vcf.gz"
    def args    = task.ext.args   ?: ""
    """
    touch ${prefix}.${suffix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        glimpse: "\$(GLIMPSE_sample --help | sed -nr '/Version/p' | grep -o -E '([0-9]+.){1,2}[0-9]')"
    END_VERSIONS
    """
}
