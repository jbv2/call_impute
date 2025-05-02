process BCFTOOLS_CALL {
    tag "$meta.id"
    label 'process_single'


    input:
    tuple val(meta), path(bam), path(bai), val(chr)
    path fasta
    path fai
    path alleles2
    path snps_only

    output:
    tuple val(meta), path("*.missing.vcf.gz"), path("*.missing.vcf.gz.tbi"), val(chr), emit: missing
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args               = task.ext.args ?: ''
    def prefix             = task.ext.prefix ?: "${meta.id}"

    """
    bcftools \\
        mpileup -f $fasta -E -a 'FORMAT/DP' --ignore-RG -T $snps_only -Q 20 -q 30 -C 50 -r $chr $bam | bcftools call \\
        -Aim \\
        -C alleles \\
        -T $alleles2 \\
        --ploidy 2 \\
    | bcftools annotate -x FORMAT/AD \\
    | bcftools \\
        view \\
        --genotype miss \\
        -e 'INFO/DP>0' \\
        -Oz \\
        -o ${prefix}.tmp.vcf.gz 

    new_name=\$(bcftools query -l ${prefix}.tmp.vcf.gz | awk '{print \$1,\$1}' | sed "s#.[0-9]*.split.bam##2")
    echo \${new_name} > samples.txt

    bcftools \\
        reheader \\
        -s samples.txt \\
        ${prefix}.tmp.vcf.gz \\
    | bcftools \\
        view \\
        -Oz \\
        -W=tbi \\
        -o ${prefix}.${chr}.missing.vcf.gz \\
        

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}
