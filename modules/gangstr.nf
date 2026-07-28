// GangSTR: STR genotyping from BAM using a region file

process GANGSTR {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/gangstr/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/gangstr:2.5.0--h7337834_10'
    label 'medium_job'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref
    path ref_str

    output:
    tuple val(meta), path("${meta.id}.gangstr.vcf"), emit: vcf

    script:
    """
    GangSTR \\
        --bam ${bam} \\
        --ref ${ref} \\
        --regions ${ref_str} \\
        --out ${meta.id}.gangstr \\
        --num-threads ${task.cpus}
    """

    stub:
    """
    touch ${meta.id}.gangstr.vcf
    """
}
