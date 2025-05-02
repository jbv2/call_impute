process ATLAS_QUALITYTRANSFORMATION {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(bam), path(bai), path(empiric)
    tuple val(meta), path(recal)

    output:
    tuple val(meta), path("*_recalibrationEM.txt"), emit:recal_patterns
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def PMD = empiric ? "pmdFile=${empiric}" : ""

    """
    atlas \\
        task=qualityTransformation \\
        bam=$bam \\
        recal=$recal \\
        $PMD \\
        logFile=${prefix}.qualTrans.log \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        atlas: \$((atlas 2>&1) | grep Atlas | head -n 1 | sed -e 's/^[ \t]*Atlas //')
    END_VERSIONS
    """
}
