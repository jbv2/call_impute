process DEF_NEWNAMES {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(vcf), path(index), val(chr)

    output:
    tuple val(meta), path("samples.txt"), val(chr), emit: samples
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    bcftools query -l $vcf > samples.tmp

    awk '{print \$1,\$1}' samples.tmp | sed "s#.[0-9]*.split##2" > samples.txt
    """


}
