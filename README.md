# Weird-little-features-nf

## Workflow description

Repeat expansion genotyping and QC reporting from short-read Illumina BAM files.

For each sample, the pipeline:

1. Runs `samtools flagstat` on the BAM for basic alignment QC
2. Resolves the sample's sex from the samplesheet if given, otherwise infers it from the BAM via ngs-bits `SampleGender`
3. Genotypes short tandem repeats with ExpansionHunter (catalog-based) and/or GangSTR (region-based), using the resolved sex where relevant
4. QC-filters GangSTR's calls down to reliable expansion candidates with TRTools `dumpSTR`
5. Annotates ExpansionHunter's calls with pathogenicity/disease thresholds using Stranger
6. Summarises every VCF with `bcftools stats` and rolls all QC (flagstat, sex check, VCF stats) into a single MultiQC report

```mermaid
flowchart LR
    A[BAM + BAI] --> F[SAMTOOLS_FLAGSTAT]
    A --> B[SEX_CHECK]
    B --> C[ExpansionHunter]
    B --> D[GangSTR]
    D --> D2[GangSTR concat/sort]
    D2 --> G[DumpSTR]
    C --> E[Stranger]
    C --> S[bcftools stats]
    G --> S
    E --> S
    F --> M[MultiQC]
    B --> M
    S --> M
```

## User guide

### Requirements

- [Nextflow](https://www.nextflow.io/docs/latest/index.html) `>=24`
- Singularity/Apptainer
- A reference genome FASTA with a `.fai` index alongside it
- An ExpansionHunter STR catalog `.json`

### Quick start

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --ref /path/to/reference.fa \
  --catalog /path/to/variant_catalog.json \
  -profile singularity
```

### Running on HPC

Pre-configured profiles are provided for NCI Gadi and Pawsey Setonix. These set the executor, queue/partition selection, container caching, and job concurrency for each system — combine them with `singularity` on the `-profile` flag:

```bash
# NCI Gadi (PBS Pro)
nextflow run main.nf \
  --input samplesheet.csv \
  --ref /path/to/reference.fa \
  --catalog /path/to/variant_catalog.json \
  -profile singularity,gadi \
  --gadi_account <NCI project code> \
  --gadi_storage gdata/<project>+scratch/<project>

# Pawsey Setonix (Slurm)
nextflow run main.nf \
  --input samplesheet.csv \
  --ref /path/to/reference.fa \
  --catalog /path/to/variant_catalog.json \
  -profile singularity,setonix
```

Gadi-specific parameters:

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--gadi_account` | yes (on `gadi`) | `$PROJECT` env var | NCI project code jobs are billed/charged to |
| `--gadi_storage` | yes (on `gadi`) | `scratch/$PROJECT` | Storage mount string passed to PBS (e.g. `gdata/er01+scratch/er01`) |

Setonix picks up `$PAWSEY_PROJECT` from the environment automatically — no equivalent parameter is needed.

A `test` profile is also defined (`config/test.config`) for quick stub/preview runs, pointing at a `test_data/` samplesheet and a chr21-only reference and scaling down resource requests. **As of writing, `test_data/` isn't present in this repository** — populate it (a small samplesheet + matching BAMs/reference) before relying on this profile, or point `--input`/`--ref`/`--catalog` elsewhere:

```bash
nextflow run main.nf -profile test,singularity -stub
```

### Samplesheet

CSV with the following columns:

| Column     | Required | Description |
|------------|----------|--------------|
| `sampleID` | yes      | Sample identifier, used to tag outputs |
| `bam`      | yes      | Path to the sample's BAM file |
| `sex`      | no       | `male`/`female` (also accepts `M`/`F`, `XX`/`XY`) |

```csv
sampleID,bam,sex
sample_01,/path/to/sample_01.bam,male
sample_02,/path/to/sample_02.bam,
```

**`sex` is optional per-sample.** Leave it blank (or omit values you don't know) and the pipeline will infer it via ngs-bits `SampleGender` before ExpansionHunter or GangSTR run. See [Sex resolution](#sex-resolution) below.

**The BAM's `.bai` index is not listed in the samplesheet.** It's located automatically next to each BAM, as either `<bam>.bai` or `<bam base>.bai`. The pipeline fails fast at input parsing if neither is found.

### Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--input` | yes | – | Path to samplesheet CSV |
| `--ref` | yes | – | Reference genome FASTA (`.fai` must exist alongside it) |
| `--catalog` | yes | – | ExpansionHunter variant catalog (JSON). Also used by Stranger for annotation, so it must match the ExpansionHunter build (see [Additional notes](#additional-notes)) |
| `--ref_str` | no | not set | GangSTR STR region file (BED/TSV, uncompressed). GangSTR (and the downstream DumpSTR filtering) is skipped if this isn't provided |
| `--sexcheck_method` | no | `xy` | Method passed to ngs-bits `SampleGender` for samples with no usable `sex` in the samplesheet. One of `xy`, `hetx`, `cnv` — see the [ngs-bits documentation](https://github.com/imgag/ngs-bits) |
| `--outdir` | no | `results` | Output directory |

Run `nextflow run main.nf --help` to see this at the command line.

### Sex resolution

ExpansionHunter's genotyping of X-linked repeats depends on sample sex, so every sample needs one resolved *before* any repeat expansion module runs:

- If the samplesheet provides a recognised value (`male`/`female`, `M`/`F`, `XX`/`XY`), it's used directly.
- Otherwise, `ngs-bits SampleGender` is run on the BAM to infer it from X/Y coverage.
- If detection is inconclusive, the sample defaults to `male` (ExpansionHunter's own default) and a warning is logged.

The resolved sex is passed to ExpansionHunter as `--sex`. GangSTR and Stranger do not currently take sex into account (see [Additional notes](#additional-notes)). The per-sample `ngs-bits` result is also fed into the MultiQC report so inferred sex calls can be spot-checked.

### Repeat expansion genotyping

**ExpansionHunter** genotypes the loci defined in `--catalog` directly, producing one VCF per sample. Its output is passed straight to Stranger for annotation — see below.

**GangSTR + DumpSTR.** GangSTR has no built-in multithreading, so it's scattered one chromosome per task (using the chromosomes listed in `--ref_str`) and the resulting per-chromosome VCFs are concatenated and coordinate-sorted back into a single per-sample VCF. That VCF is then passed through TRTools `dumpSTR`, applying its recommended "Level 1" QC filters (safe to apply regardless of repeat type/disease association):

- drop calls with a genotype spanning less than the full expected bounds (`--gangstr-filter-spanbound-only`)
- drop calls with a poor confidence interval (`--gangstr-filter-badCI`)
- enforce a call-level depth window of 20–1000× (`--gangstr-min-call-DP` / `--gangstr-max-call-DP`)
- drop filtered records entirely rather than keeping them flagged (`--drop-filtered`)

The one recommended filter *not* applied is the segmental-duplication locus filter (`--filter-regions ... SEGDUP`), which needs a bgzipped/tabix-indexed BED of segmental duplications for the reference build in use — this pipeline doesn't currently supply one. The DumpSTR-filtered VCF (not the raw GangSTR output) is what gets published and fed into `bcftools stats`/MultiQC. Alongside the filtered VCF, DumpSTR also writes `.loclog.tab` and `.samplog.tab` — per-locus and per-sample filtering logs recording how many calls were dropped and why.

**Stranger** annotates ExpansionHunter's VCF with pathogenicity/disease thresholds, using the same `--catalog` JSON so repeat definitions match between genotyping and annotation:

- If the catalog already matches Stranger's expected flat schema (`NormalMax`/`PathologicMin` directly on each locus), it's used as-is.
- If the catalog instead nests thresholds under a per-locus `Diseases` list (the common ExpansionHunter style), it's automatically reshaped into Stranger's flat schema first. Loci with more than one disease entry are split into one row per disease (`LocusId` suffixed `_1`, `_2`, ...), since Stranger only supports a single threshold pair per `LocusId`. Loci with no usable threshold data are dropped, since Stranger can't annotate them either way.

This detection/conversion happens automatically — no parameter is needed to select it.

### QC and reporting

- **`samtools flagstat`** runs on every input BAM, independent of sex check/genotyping.
- **`bcftools stats`** runs on every ExpansionHunter, DumpSTR-filtered GangSTR, and Stranger VCF.
- **MultiQC** aggregates the flagstat output, the ngs-bits sex-check TSVs, and all `bcftools stats` output into a single HTML report.

### Outputs

```
<outdir>/
├── bam_qc/<sampleID>/                      # *.flagstat
├── repeat_expansions/
│   ├── expansionhunter/<sampleID>/         # *.eh.vcf, *.eh.json
│   ├── gangstr/<sampleID>/                 # *.gangstr.vcf  (raw, coordinate-sorted; only if --ref_str is set)
│   ├── dumpstr/<sampleID>/                 # *.dumpstr.vcf.gz + .tbi, *.dumpstr.loclog.tab, *.dumpstr.samplog.tab
│   ├── stranger/<sampleID>/                # *_stranger.vcf.gz + .tbi
│   ├── stranger/                           # stranger_catalog.json (only written if --catalog needed conversion)
│   └── bcftools_stats/<sampleID>/          # *.stats (one per VCF type produced for that sample)
├── multiqc/                                # multiqc_report.html, multiqc_data/
├── runInfo/                                # DAG, execution report, timeline
└── run_info/                               # trace file
```

## Component tools

| Tool | Version | Purpose |
|---|---|---|
| [samtools](https://github.com/samtools/samtools) | 1.24 | BAM alignment QC (`flagstat`) |
| [ngs-bits `SampleGender`](https://github.com/imgag/ngs-bits) | 2025_12 | Infer sample sex from BAM coverage when not given in the samplesheet |
| [ExpansionHunter](https://github.com/Illumina/ExpansionHunter) | 5.0.0 | Catalog-based STR genotyping |
| [GangSTR](https://github.com/gymreklab/GangSTR) | 2.5.0 | Region-based STR genotyping |
| [bcftools](https://github.com/samtools/bcftools) | 1.24 | Concatenating/sorting GangSTR's per-chromosome VCFs; per-VCF summary stats for MultiQC |
| [TRTools `dumpSTR`](https://trtools.readthedocs.io/en/stable/dumpSTR.html) | 6.1.0 | QC filtering of GangSTR calls down to reliable expansion candidates |
| [Stranger](https://github.com/Clinical-Genomics/stranger) | 0.9.1 | STR pathogenicity/disease-threshold annotation |
| [MultiQC](https://multiqc.info/) | 1.19 | Aggregate QC report |

All tools run via Singularity/Apptainer containers — no local installation is required. Container images are cached under `singularity/` in the pipeline directory (gitignored).

## Additional notes

- **Catalog build consistency.** `--catalog` is passed to both ExpansionHunter and Stranger, so the same repeat definitions are used for genotyping and annotation. Make sure it matches the genome build given via `--ref` (e.g. a GRCh38 catalog with a GRCh38 reference) — Stranger ships a GRCh37 default that this pipeline deliberately overrides for that reason.
- **GangSTR region file must be uncompressed.** `--ref_str` should point at a plain BED/TSV, not a `.gz`.
- **No standard catalogs exist for non-human species.** `--catalog` and `--ref_str` are both optional; if the standard human resources don't apply to your samples, supply a custom catalog/region file, or the corresponding tool will be skipped for all samples (logged as a warning, not an error).
- **GangSTR and Stranger don't currently use sex.** GangSTR does have a `--samp-sex` option for X/Y-aware genotyping, and Stranger has no sex-related option — see [ExpansionHunter's use of sex](#sex-resolution) if you're deciding whether to extend this further.
- **The published GangSTR VCF is DumpSTR-filtered, not raw.** `gangstr/<sampleID>/*.gangstr.vcf` is the concatenated/sorted output straight from GangSTR; `dumpstr/<sampleID>/*.dumpstr.vcf.gz` is what's actually recommended for downstream use, and is what feeds `bcftools stats`/MultiQC.
- **Not yet implemented.** The pipeline's name and manifest description reference mobile element insertion (MEI) detection, de novo repeat discovery, and non-human-mammal support more broadly (e.g. `--vep_cache`/`--snpeff_db` parameters exist in `nextflow.config` as placeholders) — none of this is wired up yet. Only repeat expansion genotyping (ExpansionHunter/GangSTR/DumpSTR/Stranger) is currently implemented.

## Help / FAQ / Troubleshooting

- **What are the `.loclog.tab`/`.samplog.tab` files under `dumpstr/`?** These are DumpSTR's own filtering logs, not pipeline-generated summaries — `loclog.tab` reports how many calls were dropped per locus and why, `samplog.tab` the same per sample. Useful for sanity-checking that the Level 1 QC filters aren't dropping an unexpectedly large fraction of calls at a given locus/sample.
- **GangSTR (and therefore DumpSTR) didn't run for my samples.** Check that `--ref_str` was supplied and points at an uncompressed BED/TSV — both tools are silently skipped (with a logged warning) if it's absent.
- **ExpansionHunter/Stranger didn't run for my samples.** Same as above but for `--catalog` — both tools are skipped if it's absent, since no standard catalog exists for non-human species.
- **Stranger annotation looks empty/wrong.** Double check `--catalog` matches the genome build in `--ref`. The pipeline auto-detects and converts nested (`Diseases`-style) catalogs to Stranger's flat schema, but loci with no usable `NormalMax`/`PathologicMin` (or `PathogenicMin`) values are dropped rather than guessed at.

## License(s)

Pipeline code: [GNU GPLv3](LICENSE).

Component tools are distributed under their own licenses — see each tool's repository linked in [Component tools](#component-tools).

## Acknowledgements/citations/credits

Developed by Georgie Samaha, Sydney Informatics Hub, University of Sydney.
