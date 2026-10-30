version 1.0

import "../structs.wdl"

task svtopo {
  meta {
    description: "Analyze structural variant topology from HiPhase haplotagged alignments and generate visualizations."
  }

  input {
    String sample_id
    File haplotagged_bam
    File haplotagged_bam_index
    File phased_sv_vcf
    File phased_sv_vcf_index
    File? supporting_reads_json
    File? exclude_regions
    String assembly = "GRCh38"
    String docker_image = "alesmaver/svtopo:0.3.1_mpl3.10"
    Int threads = 4
    RuntimeAttributes runtime_attributes
  }

  Int mem_gb = 8
  Int disk_size = ceil(size(haplotagged_bam, "GB") * 2 + 20)
  String results_dir = sample_id + ".svtopo"
  String archive_name = results_dir + ".tar.gz"

  command <<<
    set -euo pipefail

    # Local aliases ensure that indices are adjacent even when localized separately.
    ln -s "~{haplotagged_bam}" input.bam
    ln -s "~{haplotagged_bam_index}" input.bam.bai
    ln -s "~{phased_sv_vcf}" variants.vcf.gz
    ln -s "~{phased_sv_vcf_index}" variants.vcf.gz.tbi

    mkdir "~{results_dir}"

    exclude_regions="~{exclude_regions}"
    if [[ -z "$exclude_regions" ]]; then
      case "~{assembly}" in
        GRCh38|hg38) assembly=hg38 ;;
        GRCh37|hg19) assembly=hg19 ;;
        *) echo "Supply exclude_regions for assembly ~{assembly}" >&2; exit 1 ;;
      esac
      exclude_regions="excluded_regions.bed.gz"
      wget -q -O "$exclude_regions" \
        "https://github.com/PacificBiosciences/HiFiCNV/raw/refs/heads/main/data/excluded_regions/cnv.excluded_regions.${assembly}.bed.gz"
    fi

    # svtopo refuses to run if the output directory does not already exist.
    mkdir -p "~{results_dir}"

    args=(
      --bam input.bam
      --vcf variants.vcf.gz
      --svtopo-dir "~{results_dir}"
      --prefix "~{sample_id}"
      --exclude-regions "$exclude_regions"
    )
    if [[ -n "~{supporting_reads_json}" ]]; then
      args+=(--variant-readnames "~{supporting_reads_json}")
    fi
    svtopo "${args[@]}"
    svtopovz --svtopo-dir "~{results_dir}" \
      || echo "svtopovz failed; archiving svtopo output without images" >&2
    tar -czf "~{archive_name}" "~{results_dir}"
  >>>

  output {
    File svtopo_archive = archive_name
  }

  runtime {
    docker: docker_image
    cpu: threads
    memory: mem_gb + " GiB"
    disk: disk_size + " GB"
    disks: "local-disk " + disk_size + " HDD"
    preemptible: runtime_attributes.preemptible_tries
    maxRetries: runtime_attributes.max_retries
    awsBatchRetryAttempts: runtime_attributes.max_retries  # !UnknownRuntimeKey
    zones: runtime_attributes.zones
    cpuPlatform: runtime_attributes.cpuPlatform
  }
}
