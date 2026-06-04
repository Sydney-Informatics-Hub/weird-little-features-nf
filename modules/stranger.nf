// Stranger: annotate STR VCFs with disease thresholds and pathogenicity flags
//
// ⚠️  HUMAN ONLY — Stranger's built-in database (STRchive / OMIM) contains
//     human disease loci only. Non-human VCFs are not routed to this process.
//     If a custom STR definition file is ever provided for non-human species,
//     pass it via -f; otherwise skip.
//
// Container tag: verify against quay.io/biocontainers/stranger before running.

process STRANGER {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/stranger/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/stranger:0.9.1--pyhdfd78af_0'
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
