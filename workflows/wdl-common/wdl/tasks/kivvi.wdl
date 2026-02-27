version 1.0

import "../structs.wdl"

task kivvi {
	meta {
		description: "Run Kivvi to analyze KIV2 region from a genome-aligned BAM."
	}

	parameter_meta {
		sample_id: {
			name: "Sample ID"
		}
		wgs_bam: {
			name: "Genome-aligned BAM file"
		}
		wgs_bam_index: {
			name: "BAM index file"
		}
		genome_fasta: {
			name: "Reference genome FASTA"
		}
		genome_fasta_index: {
			name: "Reference genome FASTA index"
		}
		output_prefix: {
			name: "Prefix for output files"
		}
		runtime_attributes: {
			name: "Runtime attribute structure"
		}
		kivvi_json: {
			name: "Kivvi JSON output"
		}
		kivvi_bam: {
			name: "Kivvi BAM output"
		}
		kivvi_vcf: {
			name: "Kivvi VCF output"
		}
		kivvi_svg: {
			name: "Kivvi SVG output"
		}
	}

	input {
		String sample_id
		File wgs_bam
		File wgs_bam_index
		File genome_fasta
		File genome_fasta_index
		String output_prefix
		RuntimeAttributes runtime_attributes
	}

	command <<<!
		set -euo pipefail
		mkdir -p kivvi_out
		kivvi -b ~{wgs_bam} -o kivvi_out -p ~{output_prefix} -r ~{genome_fasta} kiv2
	>>>

	output {
		File kivvi_json = "kivvi_out/~{output_prefix}.kivvi.kiv2.json"
		File kivvi_bam  = "kivvi_out/~{output_prefix}.kivvi.kiv2.bam"
		File kivvi_vcf  = "kivvi_out/~{output_prefix}.kivvi.kiv2.vcf"
		File? kivvi_svg = "kivvi_out/~{output_prefix}.kivvi.kiv2.svg"
	}

	runtime {
		docker: "weisburd/kivvi"
		cpu: 1
		memory: "4 GiB"
		disk: "20 GB"
		preemptible: runtime_attributes.preemptible_tries
		maxRetries: runtime_attributes.max_retries
		zones: runtime_attributes.zones
		cpuPlatform: runtime_attributes.cpuPlatform
	}
}
