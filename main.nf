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

include { SEX_CHECK         } from './subworkflows/sex_check'
include { REPEAT_EXPANSIONS } from './subworkflows/repeat_expansions'

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
    sexcheck_method : ${params.sexcheck_method}
    outdir          : ${params.outdir}
    workDir         : ${workflow.workDir}
    =======================================================================================

    """.stripIndent()
}

def helpMessage() {
    log.info"""
    Usage:  nextflow run main.nf --input samplesheet.csv --ref /path/to/ref.fa --catalog /path/to/catalog.json

    Required Arguments:

    --input         Path to samplesheet CSV.
                    Columns: sampleID,bam,sex
                    The .bai index is located automatically next to each BAM
                    (as <bam>.bai or <bam base>.bai) — do not include it.
                    sex is optional (male/female, M/F, XX/XY). If missing or
                    unrecognised, it's inferred via ngs-bits SampleGender
                    before any repeat expansion module runs.

    --ref           Path to reference genome FASTA.
                    A samtools .fai index must exist alongside it.

    --catalog       Path to ExpansionHunter variant catalog (JSON) and/or GangSTR
                    STR region file (TSV/BED) — see --ref_str for GangSTR.
                    Required for repeat expansion genotyping. No standard catalog
                    exists for non-human species; provide a custom one or these
                    steps will be skipped.

    Optional Arguments:

    --outdir        Output directory (default: results).

    --sexcheck_method  Method passed to ngs-bits SampleGender for samples
                    with no usable sex in the samplesheet (default: xy).
                    One of: xy, hetx, cnv — see ngs-bits documentation.

    """.stripIndent()
}

workflow {

    printInfo()

    if ( params.help || !params.input || !params.ref || !params.catalog ) {
        helpMessage()
        exit 1
    }

    // ---------------------------------------------------------------
    // INPUT — parse samplesheet and build meta map
    // Columns: sampleID, bam, sex (optional)
    // The .bai index is not read from the samplesheet — it's located
    // automatically next to each BAM (as <bam>.bai or <bam base>.bai).
    // ---------------------------------------------------------------
    ch_input = channel
        .fromPath( params.input, checkIfExists: true )
        .splitCsv( header: true )
        .map { row ->
            assert row.sampleID : "samplesheet: missing sampleID"
            assert row.bam      : "samplesheet: missing bam for ${row.sampleID}"

            def bam = file( row.bam, checkIfExists: true )
            def bai = file( "${bam}.bai" )

            if ( !bai.exists() ) {
                bai = file( bam.toString().replaceAll(/\.bam$/, '.bai') )
            }
            if ( !bai.exists() ) {
                error "samplesheet: could not find a .bai index for ${row.sampleID} — " +
                      "expected ${bam}.bai or ${bam.toString().replaceAll(/\.bam$/, '.bai')}"
            }

            def meta = [
                id  : row.sampleID,
                sex : row.sex?.trim() ?: null
            ]

            tuple( meta, bam, bai )
        }

    // ---------------------------------------------------------------
    // SUBWORKFLOWS
    // SEX_CHECK resolves meta.sex for every sample before any
    // repeat-expansion module runs.
    // ---------------------------------------------------------------
    SEX_CHECK( ch_input )
    REPEAT_EXPANSIONS( SEX_CHECK.out.bam )

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
