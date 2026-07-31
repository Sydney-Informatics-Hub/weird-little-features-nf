// ngs-bits SampleGender: infer sample sex from X/Y coverage in a BAM
//
// Only run for samples missing/unrecognised `sex` in the samplesheet —
// see subworkflows/sex_check.nf. Sex is required before ExpansionHunter
// runs, since it changes ploidy assumptions for X-linked STR loci.

process NGSBITS_SAMPLEGENDER {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fb/fbf8cfd89c36e9a18a895066bb1da04b93ef585a593b0821ec7037aba6c03474/data':
        'community.wave.seqera.io/library/ngs-bits:2025_12--958625b0e620100a' }"

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)
    val method

    output:
    tuple val(meta), path("*_ngsbits_sex.tsv"), emit: tsv
    path("*_ngsbits_sex_mqc.tsv"), emit: mqc_tsv
    tuple val("${task.process}"), val('ngsbits'), eval("SampleGender --version  2>&1 | sed 's/SampleGender //'"), topic: versions, emit: versions_ngsbits

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_ngsbits_sex"
    def ref = fasta ? "-ref ${fasta}" : ""
    """
    SampleGender \\
        -in ${bam} \\
        -method ${method} \\
        -out ${prefix}.tsv \\
        ${ref} \\
        ${args}

    {
        echo "# id: 'ngsbits_samplegender'"
        echo "# section_name: 'ngs-bits SampleGender'"
        echo "# description: 'Sample sex inferred from X/Y chromosome coverage ratio, used to set ExpansionHunter ploidy assumptions.'"
        echo "# plot_type: 'table'"
        echo "# pconfig:"
        echo "#     id: 'ngsbits_samplegender_table'"
        echo "#     title: 'ngs-bits: SampleGender'"
        echo "#     namespace: 'ngsbits'"
        awk -F'\\t' -v OFS='\\t' -v sample="${meta.id}" '
            NR==1 { sub(/^#/, ""); \$1 = "Sample"; print; next }
            { \$1 = sample; print }
        ' ${prefix}.tsv
    } > ${prefix}_mqc.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}_ngsbits_sex"
    """
    touch ${prefix}.tsv
    touch ${prefix}_mqc.tsv
    """
}
