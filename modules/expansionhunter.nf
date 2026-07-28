// ExpansionHunter: catalog-based STR genotyping from BAM

process EXPANSIONHUNTER {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/expansionhunter/${meta.id}", mode: 'copy'
    container 'quay.io/biocontainers/expansionhunter:5.0.0--hc26b3af_5'
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
        --sex ${meta.sex} \\
        --output-prefix ${meta.id}.eh \\
        --threads ${task.cpus}
    """

    stub:
    """
    touch ${meta.id}.eh.vcf ${meta.id}.eh.json
    """
}
