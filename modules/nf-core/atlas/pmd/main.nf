process ATLAS_PMD {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(bam), path(bai), path(readgroups), val(chr)
    path(fasta)
    path(fai)

    output:
    tuple val(meta), val(chr), path("*_PMD_input_Empiric.txt")   , emit: empiric
    tuple val(meta), path("*_PMD_input_Exponential.txt"), emit: exponential
    tuple val(meta), path("*_PMD_Table_counts.txt")     , emit: counts
    tuple val(meta), path("*_PMD_Table.txt")            , emit: table
    path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.${chr}"
    def READGROUPS = (readgroups.size() > 0) ? "poolReadGroups=${readgroups}" : ""


    """
    atlas \\
        $READGROUPS \\
        chr=$chr \\
        task=PMD \\
        bam=${bam} \\
        fasta=${fasta} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        atlas: \$((atlas 2>&1) | grep Atlas | head -n 1 | sed -e 's/^[ \t]*Atlas //')
    END_VERSIONS
    """
}
