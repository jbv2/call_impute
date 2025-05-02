process BCFTOOLS_FILTER_QUAL_DP {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(vcf), path(index), val(chr)
    path(limits)

    output:
    tuple val(meta), path("*.validation.vcf.gz"), path("*.validation.vcf.gz.tbi"), val(chr), emit: vcf_qual_dp
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.${chr}"
    def chr = task.ext.chr ?: "${meta.chr}"

    """
    # calculate genome depth of coverage
    DOC=\$(bcftools query -f '%INFO/DP\\n' $vcf | awk 'BEGIN { s = 0; l=0; } { s+=\$1; l++; } END { print s/l;}')

    LOW=\$(python3 $limits \${DOC} | awk '{print \$1}')
    UPP=\$(python3 $limits \${DOC} | awk '{print \$2}')

    bcftools filter \\
        --exclude "FORMAT/DP<\${LOW} | FMT/DP>\${UPP}" \\
        $args \\
        --threads $task.cpus \\
        $vcf | bcftools filter \\
        --exclude "GQ<30" \\
        -Oz \\
        -W=tbi \\
        -o ${prefix}.validation.vcf.gz 


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """


}