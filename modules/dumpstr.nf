// DumpSTR (TRTools): QC filtering of GangSTR calls to surface reliable
// repeat expansion candidates.
//
// "Level 1" filters — TRTools' general-purpose recommended baseline,
// safe to apply regardless of repeat type/disease association (unlike
// expansion-probability thresholds, which need a locus-specific prior).
// See https://trtools.readthedocs.io/en/stable/dumpSTR.html
//
// The recommended locus-level segmental-duplication filter
// (--filter-regions ... SEGDUP) isn't included — it needs a
// bgzipped/tabix-indexed BED of segmental duplications for the
// reference build in use, which this pipeline doesn't currently supply.

process DUMPSTR {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/dumpstr/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/trtools:6.1.0--pyhdfd78af_1'
    label 'small_job'

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(meta), path("${meta.id}.dumpstr.vcf.gz"),     emit: vcf
    tuple val(meta), path("${meta.id}.dumpstr.vcf.gz.tbi"), emit: tbi

    script:
    """
    dumpSTR \\
        --vcf ${vcf} \\
        --vcftype gangstr \\
        --out ${meta.id}.dumpstr \\
        --zip \\
        --gangstr-filter-spanbound-only \\
        --gangstr-filter-badCI \\
        --gangstr-max-call-DP 1000 \\
        --gangstr-min-call-DP 20 \\
        --drop-filtered
    """

    stub:
    """
    touch ${meta.id}.dumpstr.vcf.gz ${meta.id}.dumpstr.vcf.gz.tbi
    """
}
