// GangSTR: STR genotyping from BAM using a region file
//
// GangSTR has no multithreading option, so it's scattered one chromosome
// per task (--chrom) instead — see subworkflows/repeat_expansions.nf,
// which gathers the per-chromosome VCFs back together afterwards.
//
// --numbstrap is left at GangSTR's default (bootstrap resampling to
// compute REPCI) rather than 0 — without it REPCI collapses to 0-0,0-0
// for every call, which makes dumpSTR's --gangstr-filter-badCI (see
// modules/dumpstr.nf) reject every call regardless of genotype.

process GANGSTR {
    tag "${meta.id}:${chrom}"
    container 'quay.io/biocontainers/gangstr:2.5.0--h7337834_10'
    label 'medium_job'

    input:
    tuple val(meta), path(bam), path(bai), val(chrom)
    path ref
    path ref_fai
    path ref_str

    output:
    tuple val(meta), path("${meta.id}.${chrom}.gangstr.vcf"), emit: vcf

    script:
    """
    GangSTR \\
        --bam ${bam} \\
        --ref ${ref} \\
        --regions ${ref_str} \\
        --chrom ${chrom} \\
        --out ${meta.id}.${chrom}.gangstr \\
        --skip-qscore \\
        --verbose
    """

    stub:
    """
    touch ${meta.id}.${chrom}.gangstr.vcf
    """
}
