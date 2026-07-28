// Repeat expansion subworkflow
//
// Tools:
//   ExpansionHunter — catalog-based STR genotyping  (skipped if --catalog absent)
//   GangSTR         — STR genotyping from region set (skipped if --ref_str absent)
//   Stranger        — pathogenicity annotation, run on all samples (human-only database)

include { EXPANSIONHUNTER            } from '../modules/expansionhunter'
include { GANGSTR                    } from '../modules/gangstr'
include { GANGSTR_CONCAT             } from '../modules/gangstr_concat'
include { VALIDATE_STRANGER_CATALOG  } from '../modules/validate_stranger_catalog'
include { CONVERT_STRANGER_CATALOG   } from '../modules/convert_stranger_catalog'
include { STRANGER                   } from '../modules/stranger'
include { BCFTOOLS_STATS             } from '../modules/bcftools_stats'

workflow REPEAT_EXPANSIONS {

    take:
    ch_bam  // tuple val(meta), path(bam), path(bai)

    main:
    ch_ref     = Channel.value( file(params.ref, checkIfExists: true) )
    ch_ref_fai = Channel.value( file("${params.ref}.fai", checkIfExists: true) )

    ch_eh_vcf       = Channel.empty()
    ch_gangstr_vcf  = Channel.empty()
    ch_stranger_vcf = Channel.empty()

    // ---------------------------------------------------------------
    // ExpansionHunter + Stranger
    // ---------------------------------------------------------------
    if ( params.catalog ) {
        ch_catalog      = Channel.value( file(params.catalog, checkIfExists: true) )
        ch_catalog_meta = Channel.value( [ [id: 'catalog'], file(params.catalog, checkIfExists: true) ] )

        EXPANSIONHUNTER( ch_bam, ch_ref, ch_ref_fai, ch_catalog )
        ch_eh_vcf = EXPANSIONHUNTER.out.vcf

        // Only catalogs with nested per-disease thresholds (rather than
        // Stranger's expected flat NormalMax/PathologicMin) get converted.
        VALIDATE_STRANGER_CATALOG( ch_catalog_meta )

        ch_catalog_branch = VALIDATE_STRANGER_CATALOG.out.result
            .map { meta, catalog, format -> tuple( meta, catalog, format.trim() ) }
            .branch {
                needs_conversion: it[2] == 'nested'
                ready:            it[2] == 'flat'
            }

        CONVERT_STRANGER_CATALOG( ch_catalog_branch.needs_conversion.map { meta, catalog, _f -> tuple( meta, catalog ) } )

        ch_stranger_catalog = CONVERT_STRANGER_CATALOG.out.catalog
            .mix( ch_catalog_branch.ready.map { meta, catalog, _f -> tuple( meta, catalog ) } )

        STRANGER( ch_eh_vcf, ch_stranger_catalog )
        ch_stranger_vcf = STRANGER.out.vcf
    } else {
        log.warn "REPEAT_EXPANSIONS: --catalog not provided — ExpansionHunter and Stranger will be skipped. " +
                 "No standard catalog exists for non-human species; supply a custom catalog JSON to enable these tools."
    }

    // ---------------------------------------------------------------
    // GangSTR — scattered one chromosome per task (no multithreading
    // option in GangSTR itself), then gathered back per sample.
    // ---------------------------------------------------------------
    if ( params.ref_str ) {
        if ( !(params.ref_str instanceof CharSequence) ) {
            error "REPEAT_EXPANSIONS: --ref_str must be a path to a GangSTR region file (TSV/BED), got: ${params.ref_str}"
        }
        ch_ref_str = Channel.value( file(params.ref_str, checkIfExists: true) )

        def chroms = [] as LinkedHashSet
        file(params.ref_str, checkIfExists: true).eachLine { line -> chroms << line.tokenize('\t')[0] }
        ch_chroms = Channel.fromList( chroms.toList() )

        GANGSTR( ch_bam.combine(ch_chroms), ch_ref, ch_ref_fai, ch_ref_str )
        GANGSTR_CONCAT( GANGSTR.out.vcf.groupTuple() )
        ch_gangstr_vcf = GANGSTR_CONCAT.out.vcf
    } else {
        log.warn "REPEAT_EXPANSIONS: --ref_str not provided — GangSTR will be skipped. " +
                 "GangSTR ships human STR sets (hg38/hg19) only; provide a custom TSV/BED for non-human genomes."
    }

    // ---------------------------------------------------------------
    // Summary stats — consumed by MultiQC
    // ---------------------------------------------------------------
    BCFTOOLS_STATS( ch_eh_vcf.mix( ch_gangstr_vcf, ch_stranger_vcf ) )

    emit:
    eh_vcf       = ch_eh_vcf                // tuple val(meta), path(vcf)
    gangstr_vcf  = ch_gangstr_vcf           // tuple val(meta), path(vcf)
    stranger_vcf = ch_stranger_vcf          // tuple val(meta), path(vcf)
    stats        = BCFTOOLS_STATS.out.stats // path(stats)
}
