// Reshapes the pipeline's --catalog (ExpansionHunter-style, with
// per-locus threshold data nested under "Diseases") into the flat
// schema Stranger's --repeats-file expects (NormalMax/PathologicMin
// directly on the locus). Loci with no usable threshold data are
// dropped, Stranger can't annotate them either way.
//
// Loci with more than one disease entry are split into one row per
// disease (LocusId suffixed _1, _2, ...) since Stranger's schema only
// supports a single threshold pair per LocusId.

process CONVERT_STRANGER_CATALOG {
    publishDir "${params.outdir}/repeat_expansions/stranger", mode: 'copy'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/55/55a349b5b0e3d7b9421bd7bde8f19037ef1cd974eb675c660084c9636a26002f/data':
        'community.wave.seqera.io/library/stranger_tabix:4b6ab25b5e5e07a6' }"
    label 'small_job'

    input:
    tuple val(meta), path(catalog)

    output:
    tuple val(meta), path("stranger_catalog.json"), emit: catalog

    script:
    """
    #!/usr/bin/env python3
    import json

    with open("${catalog}") as f:
        loci = json.load(f)

    converted = []
    for locus in loci:
        diseases = locus.get("Diseases") or []
        region = locus.get("MainReferenceRegion", locus.get("ReferenceRegion"))
        for i, d in enumerate(diseases):
            normal_max = d.get("NormalMax")
            pathologic_min = d.get("PathogenicMin", d.get("PathologicMin"))
            if normal_max is None or pathologic_min is None:
                continue
            locus_id = locus["LocusId"] if len(diseases) == 1 else "{}_{}".format(locus["LocusId"], i + 1)
            converted.append({
                "LocusId": locus_id,
                "ReferenceRegion": region,
                "LocusStructure": locus["LocusStructure"],
                "VariantType": locus.get("VariantType", "Repeat"),
                "NormalMax": normal_max,
                "PathologicMin": pathologic_min,
                "Disease": d.get("Symbol", d.get("Name")),
                "InheritanceMode": d.get("Inheritance"),
            })

    with open("stranger_catalog.json", "w") as f:
        json.dump(converted, f, indent=2)
    """

    stub:
    """
    echo '[]' > stranger_catalog.json
    """
}
