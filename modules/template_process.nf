// Define the process
process generate_report {
    // Define directives
    // See: https://docs.seqera.io/nextflow/process#processes
    tag "${id}"
    publishDir "${params.outdir}/", mode: 'copy'
    container ''
    label 'small_job'

    // Define input
    // See: https://docs.seqera.io/nextflow/process#inputs
    input:
    tuple val(id), path(infile)

    // Define output(s)
    // See: https://docs.seqera.io/nextflow/process#outputs
    output:
    tuple val(id), path("${id}.output")

    // Define code to execute
    // See: https://docs.seqera.io/nextflow/process#script
    script:
    """
    cp ${infile} ${id}.output
    """
}