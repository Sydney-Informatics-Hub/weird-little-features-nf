// Sex check subworkflow — runs before any repeat-expansion module
//
// ExpansionHunter's calls for X-linked STR loci depend on sample sex
// (--sex male|female), so every sample must have one resolved before
// downstream modules run.
//
// Samplesheet may optionally provide `sex` per sample (male/female, M/F,
// XX/XY). Samples with no usable value are run through ngs-bits
// SampleGender, which infers sex from X/Y coverage in the BAM.

include { NGSBITS_SAMPLEGENDER } from '../modules/ngsbits_samplegender'

def normaliseSex(raw) {
    switch ( raw?.toString()?.trim()?.toLowerCase() ) {
        case 'male': case 'm': case 'xy':
            return 'male'
        case 'female': case 'f': case 'xx':
            return 'female'
        default:
            return null
    }
}

def parseDetectedGender(tsv) {
    def lines  = tsv.readLines().findAll { it.trim() }
    def header = lines.find { it.startsWith('#') }
    def data   = lines.find { !it.startsWith('#') }
    if ( !header || !data ) return null

    def cols = header.replaceFirst(/^#/, '').split('\t')
    def vals = data.split('\t')
    def idx  = cols.findIndexOf { it.trim().equalsIgnoreCase('gender') }

    return idx >= 0 && idx < vals.size() ? vals[idx] : null
}

workflow SEX_CHECK {

    take:
    ch_bam  // tuple val(meta), path(bam), path(bai) — meta.sex may be unset/unrecognised

    main:
    ch_ref     = Channel.value( [ [id: 'reference'], file(params.ref, checkIfExists: true) ] )
    ch_ref_fai = Channel.value( [ [id: 'reference'], file("${params.ref}.fai", checkIfExists: true) ] )
    ch_method  = Channel.value( params.sexcheck_method )

    ch_bam_sex = ch_bam.map { meta, bam, bai -> tuple( meta + [ sex: normaliseSex(meta.sex) ], bam, bai ) }

    ch_known   = ch_bam_sex.filter { meta, _bam, _bai -> meta.sex }
    ch_unknown = ch_bam_sex.filter { meta, _bam, _bai -> !meta.sex }

    ch_unknown
        .count()
        .subscribe { n -> if ( n ) log.info "SEX_CHECK: ${n} sample(s) missing/unrecognised sex — running ngs-bits SampleGender (method: ${params.sexcheck_method})" }

    NGSBITS_SAMPLEGENDER( ch_unknown, ch_ref, ch_ref_fai, ch_method )

    ch_detected = NGSBITS_SAMPLEGENDER.out.tsv
        .map { meta, tsv ->
            def detected = normaliseSex( parseDetectedGender(tsv) )
            if ( !detected ) {
                log.warn "SEX_CHECK: could not determine sex for ${meta.id} from SampleGender output — defaulting to 'male'"
                detected = 'male'
            }
            tuple( meta.id, detected )
        }

    ch_resolved = ch_unknown
        .map { meta, bam, bai -> tuple( meta.id, meta, bam, bai ) }
        .join( ch_detected )
        .map { _id, meta, bam, bai, sex -> tuple( meta + [ sex: sex ], bam, bai ) }

    emit:
    bam            = ch_known.mix( ch_resolved )        // tuple val(meta), path(bam), path(bai) — meta.sex always 'male' or 'female'
    samplegender_tsv = NGSBITS_SAMPLEGENDER.out.mqc_tsv  // path(*_ngsbits_sex_mqc.tsv) — custom_content, for MultiQC
}
