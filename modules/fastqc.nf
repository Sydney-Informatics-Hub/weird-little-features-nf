process FASTQC {
    tag "fastqc: ${sample}"
    publishDir "${params.outdir}/fastqc", mode: 'copy'
    container 'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0'
    label 'medium_job'

    input:
    tuple val(sample), path(fastq_1), path(fastq_2)

    output:
    tuple val(sample), path("fastqc_${sample}_logs"), emit: logs

    script:
    fq2 = fastq_2 ?: ''
    """
    mkdir fastqc_${sample}_logs
    fastqc --outdir fastqc_${sample}_logs --format fastq ${fastq_1} ${fq2} -t ${task.cpus}
    """
}
