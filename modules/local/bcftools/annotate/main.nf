process BCFTOOLS_ANNOTATE {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(vcf), path(index), path(vcf_gp), path(lig_csi), val(chr)

    output:
    tuple val(meta), path("*.annotated.vcf.gz"), path("*.annotated.vcf.gz.csi"), val(chr), emit: vcf_annotated
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.${chr}"
    
    """
    bcftools annotate \\
        $args \\
        -a $vcf_gp \\
        -c FORMAT/GP,FORMAT/DS \\
        --regions $chr \\
        --threads $task.cpus \\
        -Oz \\
        -W=csi \\
        -o ${prefix}".annotated.vcf.gz" \\
        $vcf


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """


}
