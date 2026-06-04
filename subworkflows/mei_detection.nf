// MEI detection subworkflow — STUB
//
// Tools planned:
//   xTEa            — LINE1, Alu, SVA, ERV detection
//                     ⚠️  Bundled repeat library is human-specific.
//                         Non-human runs require --xtea_lib pointing to a
//                         custom library, or xTEa will be skipped.
//   NUMT_DETECT     — Nuclear mitochondrial insert detection
//   Per-sample genotyping (TBD)

workflow MEI_DETECTION {

    take:
    ch_bam  // tuple val(meta), path(bam), path(bai)

    main:
    // TODO: implement xTEa, NUMT detection, and per-sample genotyping modules

    ch_mei_vcf = Channel.empty()

    emit:
    mei_vcf = ch_mei_vcf  // tuple val(meta), path(vcf)
}
