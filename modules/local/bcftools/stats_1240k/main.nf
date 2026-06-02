process BCFTOOLS_STATS_1240K {
    tag "imputation_qc"
    label 'process_low'

    input:
    tuple path(vcfs), path(index)

    output:
    path("imputation_qc.tsv"), emit: tsv
    path "versions.yml"      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    # Write header
    echo -e "sample\\tn_sites_GP_0.99" > imputation_qc.tsv

    # Loop over unique sample prefixes, concat all chrs, then count
    for sample in \$(ls *.vcf.gz | sed 's/\\..*\$//' | sort -u); do

        count=\$(bcftools concat ${args} \$(ls \${sample}.*.vcf.gz | sort -V) \\
                    | bcftools view \\
                        --include 'FORMAT/GP[*] >= 0.99' \\
                        --no-header \\
                    | wc -l)

        echo -e "\${sample}\\t\${count}" >> imputation_qc.tsv

    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}