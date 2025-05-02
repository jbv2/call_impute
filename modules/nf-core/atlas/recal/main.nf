process ATLAS_RECAL {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(bam), path(bai), path(empiric), path(readgroups)
    path(recal_regions)
    path(alleles)
    path(invariant_sites)

    output:
    tuple val(meta), path("*.txt"), emit:recal_patterns
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def PMD = empiric ? "pmdFile=${empiric}" : ""
    def ALLELES = alleles ? "alleleFile=${alleles}" : ""
    def REGIONS = recal_regions ? "regions=${recal_regions}" : ""
    def INVARIANTS = invariant_sites ? "window=${invariant_sites}" : ""
    def READGROUPS = (readgroups.size() > 0) ? "poolReadGroups=${readgroups}" : ""

    """
    atlas \\
        task=recal \\
        bam=$bam \\
        $PMD \\
        $READGROUPS \\
        $ALLELES \\
        $INVARIANTS \\
        $REGIONS \\
        out=$prefix \\
        chr=$args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        atlas: \$((atlas 2>&1) | grep Atlas | head -n 1 | sed -e 's/^[ \t]*Atlas //')
    END_VERSIONS
    """
}
