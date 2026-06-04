// ExpansionHunter: catalog-based STR genotyping from BAM
//
// ⚠️  No standard variant catalog exists for non-human species.
//     This process is only called when --catalog is provided.
//     Provide a custom catalog JSON for non-human genomes.
//
// Container tag: verify against quay.io/biocontainers/expansionhunter before running.

process EXPANSIONHUNTER {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/expansionhunter/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/expansionhunter:5.0.0--h9ee0642_1'
    label 'medium_job'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref
    path ref_fai
    path catalog

    output:
    tuple val(meta), path("${meta.id}.eh.vcf"),  emit: vcf
    tuple val(meta), path("${meta.id}.eh.json"), emit: json

    script:
    """
    ExpansionHunter \\
        --reads ${bam} \\
        --reference ${ref} \\
        --variant-catalog ${catalog} \\
        --output-prefix ${meta.id}.eh \\
        --threads ${task.cpus}
    """

    stub:
    """
    touch ${meta.id}.eh.vcf ${meta.id}.eh.json
    """
}
