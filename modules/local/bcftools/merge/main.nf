process BCFTOOLS_MERGE {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(vcfs), path(tbis), val(chr) 

    output:
    tuple val(meta), path("${meta.id}.${chr}.{bcf,vcf}{,.gz}"), path("${meta.id}.${chr}.{bcf,vcf}{,.gz}.{csi,tbi}"), val(chr), path("${meta.id}.samples.txt"), emit: vcf 
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def input = (vcfs.collect().size() > 1) ? vcfs.sort{ it.name } : vcfs

    """
    bcftools merge \\
        $args \\
        --regions $chr \\
        --threads $task.cpus \\
        --force-single \\
        -Oz \\
        -W=csi \\
        -o ${prefix}.$chr".vcf.gz" \\
        $input

    bcftools query -l ${prefix}.$chr".vcf.gz" | awk '{print \$1, "2"}' > $prefix".samples.txt"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """


}
