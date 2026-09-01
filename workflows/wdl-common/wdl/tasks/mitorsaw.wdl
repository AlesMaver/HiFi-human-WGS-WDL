version 1.0

import "../structs.wdl"

task mitorsaw {
  meta {
    description: "Identify and quantify mitochondrial variants and haplotypes from aligned BAM files."
  }

  parameter_meta {
    aligned_bam: {
      name: "Aligned BAM"
    }
    aligned_bam_index: {
      name: "Aligned BAM index"
    }
    ref_fasta: {
      name: "Reference FASTA"
    }
    ref_index: {
      name: "Reference index"
    }
    out_prefix: {
      name: "Output prefix"
    }
    runtime_attributes: {
      name: "Runtime attributes"
    }
    vcf: {
      name: "VCF"
    }
    vcf_index: {
      name: "VCF index"
    }
    hap_stats: {
      name: "Haplotype stats"
    }
  }

  input {
    File aligned_bam
    File aligned_bam_index

    File ref_fasta
    File ref_index

    String out_prefix
    String output_suffix = ""
    Boolean disable_hp_filter = true
    Float minimum_maf = 0.10

    RuntimeAttributes runtime_attributes
  }

  Int threads   = 4
  Int mem_gb    = 32
  Int disk_size = ceil((size(aligned_bam, "GB") + size(ref_fasta, "GB")) * 2 + 20)

  String vcf_name = "~{out_prefix}.mitorsaw~{output_suffix}.vcf.gz"
  String hap_stats_name = "~{out_prefix}.mitorsaw~{output_suffix}.json"

  command <<<
    set -euo pipefail

    mitorsaw haplotype \
      --reference ~{ref_fasta} \
      --bam ~{aligned_bam} \
      --minimum-maf ~{minimum_maf} \
      ~{if disable_hp_filter then "--disable-hp-filter" else ""} \
      --output-vcf ~{vcf_name} \
      --output-hap-stats ~{hap_stats_name}
  >>>

  output {
    File vcf = vcf_name
    File vcf_index = vcf_name + ".tbi"
    File hap_stats = hap_stats_name
  }

  runtime {
    docker: "~{runtime_attributes.container_registry}/mitorsaw:0.2.13_build1"
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
