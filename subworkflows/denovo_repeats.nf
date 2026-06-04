// De novo repeat discovery subworkflow — STUB
//
// Tools planned:
//   STRLING_GENOME    — genome-wide STR scan (works on any genome)
//   STRLING_OUTLIERS  — outlier detection across cohort
//   Confidence filtering and human/non-human stratification
//                       Human: filter against STRchive/known loci
//                       Non-human: novel loci only, no pathogenicity reference

workflow DENOVO_REPEATS {

    take:
    ch_bam  // tuple val(meta), path(bam), path(bai)

    main:
    // TODO: implement STRling genome scan, outlier detection, and stratification modules

    ch_strling_vcf = Channel.empty()

    emit:
    strling_vcf = ch_strling_vcf  // tuple val(meta), path(vcf)
}
