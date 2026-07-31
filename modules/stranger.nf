// Stranger: annotate STR VCFs with disease thresholds and pathogenicity flags
//
// Uses the same variant catalog as ExpansionHunter (--catalog) so repeat
// definitions match the reference build in use, rather than Stranger's
// bundled GRCh37 default.

process STRANGER {
    tag "${meta.id}"
    publishDir "${params.outdir}/repeat_expansions/stranger/${meta.id}", mode: 'copy'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/55/55a349b5b0e3d7b9421bd7bde8f19037ef1cd974eb675c660084c9636a26002f/data':
        'community.wave.seqera.io/library/stranger_tabix:4b6ab25b5e5e07a6' }"
    label 'process_low'

    input:
    tuple val(meta), path(vcf)
    tuple val(meta2), path(variant_catalog)

    output:
    tuple val(meta), path("*.vcf.gz")    , emit: vcf
    tuple val(meta), path("*.vcf.gz.tbi"), emit: tbi
    path("*_status_mqc.tsv")             , emit: mqc_status
    tuple val("${task.process}"), val('stranger'), eval("stranger --version 2>&1 | head -1"), topic: versions, emit: versions_stranger
    tuple val("${task.process}"), val('tabix'), eval("echo \$(tabix -h 2>&1) | sed 's/^.*Version: //; s/ .*\$//'"), topic: versions, emit: versions_tabix

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_stranger"
    def options_variant_catalog = variant_catalog ? "--repeats-file $variant_catalog" : ""

    if ("${vcf}" == "${prefix}.vcf.gz") error "Input and output names are the same, use \"task.ext.prefix\" to disambiguate!"
    """
    stranger \\
        $args \\
        $vcf \\
        $options_variant_catalog | bgzip $args2 -c --threads ${task.cpus} > ${prefix}.vcf.gz

    tabix \\
        $args3 \\
        --threads ${task.cpus} \\
        ${prefix}.vcf.gz

    STATUS_COUNTS=\$(zcat ${prefix}.vcf.gz | grep -v '^#' | grep -o 'STR_STATUS=[a-zA-Z_]*' | sed 's/STR_STATUS=//' | sort | uniq -c)
    COUNT_NORMAL=\$(echo "\$STATUS_COUNTS"   | awk '\$2=="normal"{print \$1}')
    COUNT_PREMUT=\$(echo "\$STATUS_COUNTS"   | awk '\$2=="pre_mutation"{print \$1}')
    COUNT_FULLMUT=\$(echo "\$STATUS_COUNTS"  | awk '\$2=="full_mutation"{print \$1}')
    COUNT_NORMAL=\${COUNT_NORMAL:-0}
    COUNT_PREMUT=\${COUNT_PREMUT:-0}
    COUNT_FULLMUT=\${COUNT_FULLMUT:-0}

    {
        echo "# id: 'stranger_str_status'"
        echo "# section_name: 'Stranger: Repeat Expansion Classification'"
        echo "# description: 'Per-sample counts of STR loci by Stranger pathogenicity classification (STR_STATUS): normal, pre_mutation, or full_mutation.'"
        echo "# plot_type: 'bargraph'"
        echo "# pconfig:"
        echo "#     id: 'stranger_str_status_bargraph'"
        echo "#     title: 'Stranger: Repeat Expansion Classification'"
        printf 'Sample\\tnormal\\tpre_mutation\\tfull_mutation\\n'
        printf '%s\\t%s\\t%s\\t%s\\n' "${meta.id}" "\$COUNT_NORMAL" "\$COUNT_PREMUT" "\$COUNT_FULLMUT"
    } > ${prefix}_status_mqc.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}_stranger"

    if ("${vcf}" == "${prefix}.vcf.gz") error "Input and output names are the same, use \"task.ext.prefix\" to disambiguate!"
    """
    echo "" | gzip > ${prefix}.vcf.gz
    touch ${prefix}.vcf.gz.tbi
    touch ${prefix}_status_mqc.tsv
    """
}
