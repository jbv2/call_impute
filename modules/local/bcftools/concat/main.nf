process BCFTOOLS_CONCAT {
    tag "$meta.id"
    label 'process_low'


    input:
    tuple val(meta), path(vcfs), path(index), val(chr)

    output:
    tuple val(meta), path("*.calls.vcf.gz"), path("*.calls.vcf.gz.tbi"), val(chr), emit: concatenated
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args               = task.ext.args ?: ''
    def prefix             = task.ext.prefix ?: "${meta.id}"

    """
    # Create a temporary header file
    #renamed=\$( ls *.renamed.vcf.gz)
    #missing=\$( ls *.missing.vcf.gz)
    # Apply new header to bcftools VCF
    #bcftools annotate -x FORMAT/AD \${missing} -Oz -o bcftools_fixed.vcf.gz -W=tbi

    # Concatenate the VCF files
    bcftools \\
        concat \\
        --allow-overlaps \\
        $vcfs \\
        -W=tbi \\
        -Oz \\
        -o ${prefix}.${chr}.calls.vcf.gz
        
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}