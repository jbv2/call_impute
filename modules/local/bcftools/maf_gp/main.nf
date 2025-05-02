process BCFTOOLS_MAF_GP {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(vcf), path(index), val(chr)
    tuple val(min_raf), val(max_raf)
    val(gp)

    output:
    tuple val(meta), path("*.maf_gp.vcf.gz"), path("*.maf_gp.vcf.gz.csi"), val(chr), emit: vcf_maf_gp
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
        -i 'INFO/RAF[0]>${min_raf} && INFO/RAF[0]<${max_raf} && FORMAT/GP[0:*]>${gp}' \\
        --regions $chr \\
        --threads $task.cpus \\
        -Oz \\
        -W=csi \\
        -o "\${sample}"".${chr}.maf_gp.vcf.gz" \\
        $vcf 
    done


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """


}

