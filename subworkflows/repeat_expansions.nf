// Repeat expansion subworkflow
//
// Tools:
//   ExpansionHunter — catalog-based STR genotyping  (skipped if --catalog absent)
//   GangSTR         — STR genotyping from region set (skipped if --ref_str absent)
//   Stranger        — pathogenicity annotation, run on all samples (human-only database)

include { EXPANSIONHUNTER } from '../modules/expansionhunter'
include { GANGSTR          } from '../modules/gangstr'
include { STRANGER         } from '../modules/stranger'

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
        ch_catalog = Channel.value( file(params.catalog, checkIfExists: true) )

        EXPANSIONHUNTER( ch_bam, ch_ref, ch_ref_fai, ch_catalog )
        ch_eh_vcf = EXPANSIONHUNTER.out.vcf

        STRANGER( ch_eh_vcf )
        ch_stranger_vcf = STRANGER.out.vcf
    } else {
        log.warn "REPEAT_EXPANSIONS: --catalog not provided — ExpansionHunter and Stranger will be skipped. " +
                 "No standard catalog exists for non-human species; supply a custom catalog JSON to enable these tools."
    }

    // ---------------------------------------------------------------
    // GangSTR
    // ---------------------------------------------------------------
    if ( params.ref_str ) {
        ch_ref_str = Channel.value( file(params.ref_str, checkIfExists: true) )

        GANGSTR( ch_bam, ch_ref, ch_ref_str )
        ch_gangstr_vcf = GANGSTR.out.vcf
    } else {
        log.warn "REPEAT_EXPANSIONS: --ref_str not provided — GangSTR will be skipped. " +
                 "GangSTR ships human STR sets (hg38/hg19) only; provide a custom TSV/BED for non-human genomes."
    }

    emit:
    eh_vcf       = ch_eh_vcf        // tuple val(meta), path(vcf)
    gangstr_vcf  = ch_gangstr_vcf   // tuple val(meta), path(vcf)
    stranger_vcf = ch_stranger_vcf  // tuple val(meta), path(vcf)
}
