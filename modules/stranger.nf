// Stranger: annotate STR VCFs with disease thresholds and pathogenicity flags

process STRANGER {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/stranger/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/stranger:0.9.1--pyh7e72e81_0'
    label 'small_job'

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(meta), path("${meta.id}.stranger.vcf"), emit: vcf

    script:
    """
    stranger ${vcf} > ${meta.id}.stranger.vcf
    """

    stub:
    """
    touch ${meta.id}.stranger.vcf
    """
}
