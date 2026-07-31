// bcftools stats: per-VCF summary stats, consumed by MultiQC
//
// ExpansionHunter/GangSTR/Stranger VCFs don't have a dedicated MultiQC
// module, so this generates the generic bcftools stats MultiQC already
// knows how to parse (variant counts, etc.) for each of them.

process BCFTOOLS_STATS {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/bcftools_stats/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/bcftools:1.24--h487d631_1'
    label 'small_job'

    input:
    tuple val(meta), path(vcf)

    output:
    path("*.stats"), emit: stats
    tuple val("${task.process}"), val('bcftools'), eval("bcftools --version 2>&1 | head -1 | sed 's/^bcftools //'"), topic: versions, emit: versions_bcftools

    script:
    def prefix = vcf.name.replaceAll(/\.vcf(\.gz)?$/, '')
    """
    bcftools stats ${vcf} > ${prefix}.stats
    """

    stub:
    """
    touch stub.stats
    """
}
