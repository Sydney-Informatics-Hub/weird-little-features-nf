// Sort + index the ExpansionHunter realigned BAM (EH writes it unsorted,
// so it can't be indexed or viewed in IGV/REViewer as-is)

process SAMTOOLS_SORT_INDEX {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/expansionhunter/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/samtools:1.24--h9dcdb79_1'
    label 'small_job'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}.eh_realigned.sorted.bam"), path("${meta.id}.eh_realigned.sorted.bam.bai"), emit: bam

    script:
    """
    samtools sort --threads ${task.cpus} -o ${meta.id}.eh_realigned.sorted.bam ${bam}
    samtools index -@ ${task.cpus} ${meta.id}.eh_realigned.sorted.bam
    """

    stub:
    """
    touch ${meta.id}.eh_realigned.sorted.bam
    touch ${meta.id}.eh_realigned.sorted.bam.bai
    """
}
