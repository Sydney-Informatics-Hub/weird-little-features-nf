// Quick BAM QC: samtools flagstat, consumed by MultiQC

process SAMTOOLS_FLAGSTAT {
    tag "${meta.id}"
    publishDir "${params.outdir}/bam_qc/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/samtools:1.24--h9dcdb79_1'
    label 'small_job'

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    path("*.flagstat"), emit: flagstat
    tuple val("${task.process}"), val('samtools'), eval("samtools --version 2>&1 | head -1 | sed 's/^samtools //'"), topic: versions, emit: versions_samtools

    script:
    """
    samtools flagstat --threads ${task.cpus} ${bam} > ${meta.id}.flagstat
    """

    stub:
    """
    touch ${meta.id}.flagstat
    """
}
