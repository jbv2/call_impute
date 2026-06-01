process BCFTOOLS_GET_1240K {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(vcf), path(index), val(chr)
    path(regions)

    output:
    tuple val(meta), path("*.ch*.vcf.gz"), path("*.ch*.vcf.gz.csi"), val(chr), emit: vcf_1240k
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.${chr}"

    """
    samples="\$(bcftools query -l "${vcf}")"
    for sample in \${samples} ; do
    bcftools view \\
        $args \\
        -s "\${sample}" \\
        -T $regions \\
        -M2 \\
        -v snps \\
        --threads $task.cpus \\
        -Oz \\
        -W=csi \\
        -o "\${sample}"".ch${chr}.vcf.gz" \\
        $vcf 
    done


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """


}

