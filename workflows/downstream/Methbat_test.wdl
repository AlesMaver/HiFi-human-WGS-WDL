version 1.0

import "../wdl-common/wdl/tasks/methbat_v2.wdl" as Methbat

workflow Methbat_wf {

 input {
    String sample_id
    Array[File] cpg_pileup_beds
    File ref_map_file

    RuntimeAttributes default_runtime_attributes
  }

  Map[String, String] ref_map = read_map(ref_map_file)

  if (length(cpg_pileup_beds) > 0) {
    # If any cpg_pileup_beds are generated, we can run methbat
    call Methbat.methbat {
      input:
        sample_prefix           = "~{sample_id}.~{ref_map['name']}.cpg_pileup",
        methylation_pileup_beds = cpg_pileup_beds,
        region_tsv              = ref_map["methbat_region_tsv"],     # !FileCoercion
        report_regions          = ref_map["methbat_report_regions"],
        out_prefix              = "~{sample_id}.~{ref_map['name']}",
        runtime_attributes      = default_runtime_attributes
    }
  }

  output {
    File?  methbat_profile = methbat.profile
  }
}
