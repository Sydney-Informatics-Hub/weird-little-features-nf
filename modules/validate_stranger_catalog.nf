// Checks whether a repeat catalog already matches Stranger's expected
// flat schema (NormalMax/PathologicMin directly on each locus) or uses
// a nested per-disease structure (e.g. some ExpansionHunter-style
// catalogs, with thresholds under "Diseases"). Downstream, only
// catalogs that need it are routed through CONVERT_STRANGER_CATALOG —
// see subworkflows/repeat_expansions.nf.

process VALIDATE_STRANGER_CATALOG {
    tag "validate"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/55/55a349b5b0e3d7b9421bd7bde8f19037ef1cd974eb675c660084c9636a26002f/data':
        'community.wave.seqera.io/library/stranger_tabix:4b6ab25b5e5e07a6' }"
    label 'small_job'

    input:
    tuple val(meta), path(catalog)

    output:
    tuple val(meta), path(catalog), stdout, emit: result

    script:
    """
    #!/usr/bin/env python3
    import json

    with open("${catalog}") as f:
        loci = json.load(f)

    flat = sum(1 for x in loci if "NormalMax" in x and ("PathologicMin" in x or "PathogenicMin" in x))
    nested = sum(1 for x in loci if any("NormalMax" in d for d in (x.get("Diseases") or [])))

    print("flat" if flat >= nested else "nested", end="")
    """

    stub:
    """
    echo -n "flat"
    """
}
