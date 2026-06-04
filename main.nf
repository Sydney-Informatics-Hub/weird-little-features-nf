#!/usr/bin/env nextflow

// =================================================================
//
// Weird Little Features - nf
// Repeat expansion, MEI, and de novo repeat discovery from
// short-read Illumina BAM files (human and non-human mammals)
//
// Sydney Informatics Hub, University of Sydney
//
// ===================================================================

include { REPEAT_EXPANSIONS } from './subworkflows/repeat_expansions'
include { MEI_DETECTION     } from './subworkflows/mei_detection'
include { DENOVO_REPEATS    } from './subworkflows/denovo_repeats'

def printInfo() {
    log.info """\

    =======================================================================================
    Weird Little Features - nf
    =======================================================================================

    Created by Georgie Samaha, Sydney Informatics Hub, University of Sydney
    Find documentation @ https://sydney-informatics-hub.github.io/Nextflow_DSL2_template_guide/
    Cite this pipeline @ INSERT DOI

    =======================================================================================
    Workflow run parameters
    =======================================================================================
    input           : ${params.input}
    ref             : ${params.ref}
    catalog         : ${params.catalog  ?: 'not provided — catalog-dependent steps skipped for non-human samples'}
    ref_str         : ${params.ref_str  ?: 'not provided — GangSTR will be skipped'}
    xtea_lib        : ${params.xtea_lib ?: 'not provided — xTEa will be skipped'}
    vep_cache       : ${params.vep_cache  ?: 'not provided — VEP annotation skipped'}
    snpeff_db       : ${params.snpeff_db  ?: 'not provided — SnpEff annotation skipped'}
    outdir          : ${params.outdir}
    workDir         : ${workflow.workDir}
    =======================================================================================

    """.stripIndent()
}

def helpMessage() {
    log.info"""
    Usage:  nextflow run main.nf --input samplesheet.csv --ref /path/to/ref.fa

    Required Arguments:

    --input         Path to samplesheet CSV.
                    Columns: sampleID,bam,bai,species,is_human
                    is_human must be true or false.

    --ref           Path to reference genome FASTA.
                    A samtools .fai index must exist alongside it.

    Optional Arguments:

    --catalog       Path to ExpansionHunter variant catalog (JSON) and/or GangSTR
                    STR region file (TSV/BED) — see --ref_str for GangSTR.
                    Required for repeat expansion genotyping. No standard catalog
                    exists for non-human species; provide a custom one or these
                    steps will be skipped.

    --ref_str       Path to GangSTR STR region file. GangSTR ships human reference
                    sets (hg38/hg19). For non-human genomes, supply a custom file.

    --xtea_lib      Path to xTEa repeat library directory. The bundled library is
                    human-specific (LINE1, Alu, SVA, ERV). Non-human runs require
                    a custom library or xTEa will be skipped.

    --vep_cache     Path to VEP cache directory. Used for human samples only.

    --snpeff_db     SnpEff database name for non-human annotation
                    (e.g. 'GRCm39.105').

    --scratch       Path to scratch/temp directory on Lustre.
                    Defaults to \$TMPDIR or /tmp.

    --outdir        Output directory (default: results).

    """.stripIndent()
}

workflow {

    printInfo()

    if ( params.help || !params.input || !params.ref ) {
        helpMessage()
        exit 1
    }

    // ---------------------------------------------------------------
    // INPUT — parse samplesheet and build meta map
    // Columns: sampleID, bam, bai, species, is_human
    // ---------------------------------------------------------------
    ch_input = channel
        .fromPath( params.input, checkIfExists: true )
        .splitCsv( header: true )
        .map { row ->
            assert row.sampleID         : "samplesheet: missing sampleID"
            assert row.bam              : "samplesheet: missing bam for ${row.sampleID}"
            assert row.bai              : "samplesheet: missing bai for ${row.sampleID}"
            assert row.species          : "samplesheet: missing species for ${row.sampleID}"
            assert row.is_human != null && row.is_human != '' :
                "samplesheet: missing is_human for ${row.sampleID} — must be true or false"

            def meta = [
                id       : row.sampleID,
                species  : row.species,
                is_human : row.is_human.toBoolean()
            ]

            tuple(
                meta,
                file( row.bam, checkIfExists: true ),
                file( row.bai, checkIfExists: true )
            )
        }

    // Log routing counts once channels are materialised
    ch_input
        .filter { meta, _bam, _bai -> meta.is_human }
        .count()
        .subscribe { n -> log.info "Routing: ${n} human sample(s) — full annotation stack" }

    ch_input
        .filter { meta, _bam, _bai -> !meta.is_human }
        .count()
        .subscribe { n -> log.info "Routing: ${n} non-human sample(s) — catalog/VEP steps replaced or skipped" }

    // ---------------------------------------------------------------
    // SUBWORKFLOWS — run in parallel, all receive the full channel;
    // species routing happens inside each subworkflow
    // ---------------------------------------------------------------
    REPEAT_EXPANSIONS( ch_input )
    MEI_DETECTION( ch_input )
    DENOVO_REPEATS( ch_input )

    // Annotation subworkflow will consume outputs from all three —
    // to be wired once annotation modules are implemented.

    // ---------------------------------------------------------------
    // SUMMARY
    // ---------------------------------------------------------------
    workflow.onComplete = {
        def summary = """
        =======================================================================================
        Workflow execution summary
        =======================================================================================

        Duration    : ${workflow.duration}
        Success     : ${workflow.success}
        workDir     : ${workflow.workDir}
        Exit status : ${workflow.exitStatus}
        results     : ${params.outdir}

        =======================================================================================
        """
        println summary.replaceAll(/(^|\n)\s+/, '\n')
    }
}
