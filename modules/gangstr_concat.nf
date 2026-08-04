// Gather step for GangSTR's per-chromosome scatter (see modules/gangstr.nf).
// Concatenates the per-chromosome VCFs for a sample and coordinate-sorts
// the result, since task completion order isn't guaranteed to be
// chromosome order.

process GANGSTR_CONCAT {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/gangstr/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/bcftools:1.24--h487d631_1'
    label 'small_job'

    input:
    tuple val(meta), path(vcfs)

    output:
    tuple val(meta), path("${meta.id}.gangstr.vcf"), emit: vcf

    script:
    """
    bcftools concat ${vcfs} | bcftools sort -Ov -o ${meta.id}.gangstr.vcf
    """

    stub:
    """
    touch ${meta.id}.gangstr.vcf
    """
}
