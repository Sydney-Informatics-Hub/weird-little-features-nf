process MULTIQC {
    publishDir "${params.outdir}/multiqc", mode: 'copy'
    container 'quay.io/biocontainers/multiqc:1.35--pyhdfd78af_1'
    label 'small_job'

    input:
    path "*"

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data", emit: data

    script:
    """
    multiqc .
    """
}