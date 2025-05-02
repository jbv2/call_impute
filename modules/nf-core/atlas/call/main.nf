process ATLAS_CALL {
    tag "$meta.id"
    label 'process_low'


    input:
    tuple val(meta), path(bam), path(bai), path(pmd), path(recal), val(chr)
    path fasta
    path fai
    path known_alleles
    val method

    output:
    tuple val(meta), path("*.vcf.gz"), val(chr), emit: vcf
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args               = task.ext.args ?: ''
    def prefix             = task.ext.prefix ?: "${meta.id}"
    def recal_file         = recal ? "recal=${recal}" : ""
    def pmd_file           = pmd ? "pmdFile=${pmd}" : ""
    def known_alleles_file = known_alleles ? "alleles=${known_alleles}" : ""
    //def chr = task.ext.prefix ?: "chr=${meta.chr}" 

    def valid_method = ['MLE', 'Bayesian', 'allelePresence', 'randomBase', 'majorityBase']
    if ( !valid_method.contains(method) )  { error "Unrecognised calling method for ATLAS_CALL. Options: MLE, Bayesian, allelePresence, randomBase, majorityBase" }

    """
    atlas \\
        task=call \\
        bam=${bam} \\
        fasta=${fasta} \\
        chr=$chr \\
        $recal_file \\
        $pmd_file \\
        $known_alleles_file \\
        method=${method} \\
        $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        atlas: \$((atlas 2>&1) | grep Atlas | head -n 1 | sed -e 's/^[ \t]*Atlas //')
    END_VERSIONS
    """
}
