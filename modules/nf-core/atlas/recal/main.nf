process ATLAS_RECAL {
    tag "$meta.id"

    input:
    tuple val(meta), path(bam), path(bai), path(empiric), path(rg)
    val regions
    val alleles
    val sites
    val chr

    output:
    tuple val(meta), path("*.txt"), emit:recal_patterns
    path "versions.yml",             emit: versions

    script:
    def alleles_arg = alleles ? "alleles=${alleles}" : ""
    def sites_arg    = sites   ? "sites=${sites}"     : ""
    """
    atlas \\
        task=recal \\
        bam=${bam} \\
        pmdFile=${empiric} \\
        ${alleles_arg} \\
        ${sites_arg} \\
        regions=${regions} \\
        out=${meta.id} \\
        chr="${chr}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        atlas: \$(atlas 2>&1 | grep -i version | head -n1)
    END_VERSIONS
    """
}