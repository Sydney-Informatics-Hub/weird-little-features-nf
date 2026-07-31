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
    tuple val(meta), path("${meta.id}.dumpstr.loclog.tab"),  emit: loclog
    tuple val(meta), path("${meta.id}.dumpstr.samplog.tab"), emit: samplog
    path("${meta.id}.dumpstr_samplog_mqc.tsv"), emit: mqc_samplog
    path("${meta.id}.dumpstr_loclog_mqc.tsv"),  emit: mqc_loclog
    tuple val("${task.process}"), val('trtools'), eval("dumpSTR --version 2>&1 | head -1"), topic: versions, emit: versions_trtools

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

    {
        echo "# id: 'dumpstr_samplog'"
        echo "# section_name: 'DumpSTR: Sample Call Summary'"
        echo "# description: 'Per-sample GangSTR call counts before/after DumpSTR QC filtering (TRTools). numcalls is the count of calls retained after filtering; the remaining columns show how many calls were dropped by each filter.'"
        echo "# plot_type: 'table'"
        echo "# pconfig:"
        echo "#     id: 'dumpstr_samplog_table'"
        echo "#     title: 'DumpSTR: Sample Call Summary'"
        echo "#     namespace: 'dumpstr'"
        awk -F'\\t' -v OFS='\\t' -v sample="${meta.id}" '
            NR==1 { \$1 = "Sample"; print; next }
            { \$1 = sample; print }
        ' ${meta.id}.dumpstr.samplog.tab
    } > ${meta.id}.dumpstr_samplog_mqc.tsv

    {
        echo "# id: 'dumpstr_loclog'"
        echo "# section_name: 'DumpSTR: Locus Filter Summary'"
        echo "# description: 'Aggregate per-locus filtering outcomes from DumpSTR (TRTools) for this sample -- how many loci passed vs were dropped, and why.'"
        echo "# plot_type: 'table'"
        echo "# pconfig:"
        echo "#     id: 'dumpstr_loclog_table'"
        echo "#     title: 'DumpSTR: Locus Filter Summary'"
        echo "#     namespace: 'dumpstr'"
        awk -F'\\t' -v OFS='\\t' -v sample="${meta.id}" '
            {
                key = \$1
                gsub(/[: ]/, "_", key)
                keys[NR] = key
                vals[NR] = \$2
            }
            END {
                header = "Sample"
                data = sample
                for (i = 1; i <= NR; i++) {
                    header = header OFS keys[i]
                    data = data OFS vals[i]
                }
                print header
                print data
            }
        ' ${meta.id}.dumpstr.loclog.tab
    } > ${meta.id}.dumpstr_loclog_mqc.tsv
    """

    stub:
    """
    touch ${meta.id}.dumpstr.vcf.gz ${meta.id}.dumpstr.vcf.gz.tbi ${meta.id}.dumpstr.loclog.tab ${meta.id}.dumpstr.samplog.tab
    touch ${meta.id}.dumpstr_samplog_mqc.tsv ${meta.id}.dumpstr_loclog_mqc.tsv
    """
}
