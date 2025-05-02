process ASSIGN2RUN {
    tag "$meta.id"
    //label 'process_single'

    input:
    tuple val(meta), path(bam)
    path(bai)

    output:
    path "(*.assigned.bam)", emit: assigned_bam_files

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    X=\$(samtools view -H ${bam} | grep '^@RG' | wc -l)
    if (( \$X >= 2 ))
    then
        Y=\$(samtools view -H ${bam} | grep '^@RG' | grep PI | wc -l)
        if (( \$Y = 1 ))
        then 
            let X-=1
                picard AddOrReplaceReadGroups \
                I=\${i}.bam \
                O=\${i}.assigned.bam \
                RGID=\${ID}.\${PU} \
                RGLB=\$LB \
                RGPL=\$PL \
                RGSM=\$SM \
                RGPU=\$PU \
                RGPI=\$PI \
                RGPM=\$PM \
                RGDS=\$DS

                samtools index ${i}.assigned.bam 

        elif ((Y == 0))
        then
            echo "Calculate PI from samtools stats" ## Aqui me quede
            fi

    elif (( \$X == 1 ))
    then
        ID=\$(samtools view -H ${bam} | grep ^@RG | tr "\\t" "\\n" | grep "ID" | sed 's/.*\\://g' | sed 's/-.*//g')
        LB=\$(samtools view -H ${bam} | grep ^@RG | tr "\\t" "\\n" | grep "LB"  | sed 's/.*\\://g')
        PL=\$(samtools view -H ${bam} | grep ^@RG | tr "\\t" "\\n" | grep "PL"  | sed 's/.*\\://g')
        SM=\$(samtools view -H ${bam} | grep ^@RG | tr "\\t" "\\n" | grep "SM"  | sed 's/.*\\://g')
        PU=\$(samtools view -H ${bam} | grep ^@RG | tr "\\t" "\\n" | grep "PU"  | sed 's/.*\\://g')
        PI=\$(samtools view -H ${bam} | grep ^@RG | tr "\\t" "\\n" | grep "PI"  | sed 's/.*\\://g')
        PM=\$(samtools view -H ${bam} | grep ^@RG | tr "\\t" "\\n" | grep "PM"  | sed 's/.*\\://g')
        DS=\$(samtools view -H ${bam} | grep ^@RG | tr "\\t" "\\n" | grep "DS"  | sed 's/.*\\://g')

       picard AddOrReplaceReadGroups \
        I=${bam} \
        O=${prefix}.assigned.bam \
        RGID=\${ID}.\${PU} \
        RGLB=\$LB \
        RGPL=\$PL \
        RGSM=\$SM \
        RGPU=\$PU \
        RGPI=\$PI \
        RGPM=\$PM \
        RGDS=\$DS
    fi

    """
}