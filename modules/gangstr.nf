// GangSTR: STR genotyping from BAM using a region file
//
// ⚠️  GangSTR ships human reference STR sets (hg38, hg19) only.
//     Non-human genomes require a custom --ref_str TSV/BED.
//     This process is only called when --ref_str is provided.
//
// Container tag: verify against quay.io/biocontainers/gangstr before running.

process GANGSTR {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/gangstr/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/gangstr:2.5.0--hd03093a_0'
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
