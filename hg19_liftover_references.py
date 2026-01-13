import os
import urllib.request
import subprocess
import sys

try:
    from pyliftover import LiftOver
except ImportError:
    print("pyliftover not found. Installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyliftover"])
    from pyliftover import LiftOver


# -----------------------------
# 1. Download chain file
# -----------------------------
CHAIN_URL = (
    "https://raw.githubusercontent.com/broadgsa/gatk/"
    "41147a655594c2aae6e2cad8462bd1648570b32b/public/chainFiles/b37tohg19.chain"
)
CHAIN_FILE = "b37tohg19.chain"

try:
    urllib.request.urlretrieve(CHAIN_URL, CHAIN_FILE)
    print("Downloaded chain file:", CHAIN_FILE)
except Exception as e:
    print("Chain file already exists or download failed:", e)

# -----------------------------
# 1. Download chain file
# -----------------------------
CHAIN_URL = (
    "https://github.com/multimeric/CrossMap/raw/refs/heads/master/data/GRCh37ToHg19.over.chain.gz"
)

CHAIN_FILE = "GRCh37ToHg19.over.chain.gz"

if not os.path.exists(CHAIN_FILE):
    print("Downloading chain file...")
    urllib.request.urlretrieve(CHAIN_URL, CHAIN_FILE)
    print("Downloaded:", CHAIN_FILE)
else:
    print("Chain file already exists:", CHAIN_FILE)

# -----------------------------
# 2. Load liftover object
# -----------------------------
lo = LiftOver(CHAIN_FILE)

# -----------------------------
# 3. Convert BED files
# -----------------------------
import gzip

input_dir = "/cmg1scratch/cromwell/PacBio_testing/human_hs37d5"
output_dir = "/cmg1scratch/cromwell/PacBio_testing/human_hg19"

# Define files to convert: (filename, needs_tabix_index)
bed_files = [
    ("human_hs37d5.trf.bed", False),
    ("human_hs37d5.excluded_regions.bed.gz", True),
    ("human_hs37d5.expected_cn.XX.bed", False),
    ("human_hs37d5.expected_cn.XY.bed", False),
]

def convert_bed_file(input_path, output_path, unmapped_path, input_gzipped=False, output_gzipped=False):
    """Convert a BED file from hs37d5 to hg19 coordinates."""
    input_open = gzip.open if input_gzipped else open
    input_mode = "rt" if input_gzipped else "r"
    
    output_open = gzip.open if output_gzipped else open
    output_mode = "wt" if output_gzipped else "w"
    
    with input_open(input_path, input_mode) as infile, \
         output_open(output_path, output_mode) as outfile, \
         open(unmapped_path, "w") as out_unmapped:
         
        for line in infile:
            if line.startswith("#") or not line.strip():
                continue
            
            fields = line.strip().split("\t")
            chrom, start, end = fields[0], int(fields[1]), int(fields[2])
            rest = fields[3:]
            
            new_start = lo.convert_coordinate(chrom, start)
            new_end = lo.convert_coordinate(chrom, end)
            
            if new_start and new_end:
                new_chrom = new_start[0][0]
                new_start_pos = new_start[0][1]
                new_end_pos = new_end[0][1]
            
                outfile.write(
                    f"{new_chrom}\t{new_start_pos}\t{new_end_pos}\t" +
                    "\t".join(rest) + "\n"
                )
            else:
                out_unmapped.write(line)

# Process each BED file
for filename, needs_index in bed_files:
    print(f"\nConverting {filename}...")
    
    input_path = os.path.join(input_dir, filename)
    output_filename = filename.replace("human_hs37d5", "human_hg19")
    output_path = os.path.join(output_dir, output_filename)
    unmapped_path = filename.replace(".bed", ".unmapped.bed")
    
    is_gzipped = filename.endswith(".gz")
    
    # If the file needs indexing, write to temp uncompressed file first
    if needs_index:
        temp_output = output_path.replace(".gz", "")
        convert_bed_file(input_path, temp_output, unmapped_path, 
                        input_gzipped=is_gzipped, output_gzipped=False)
        print(f"  ✓ Converted to temporary file: {temp_output}")
        print(f"  ✓ Unmapped intervals: {unmapped_path}")
        
        # Sort the file (required for tabix)
        print(f"  Sorting BED file...")
        sorted_temp = temp_output + ".sorted"
        subprocess.run(
            f"sort -k1,1 -k2,2n {temp_output} > {sorted_temp}",
            shell=True, check=True
        )
        os.rename(sorted_temp, temp_output)
        print(f"  ✓ Sorted")
        
        # Compress with bgzip (required for tabix)
        print(f"  Compressing with bgzip...")
        subprocess.run(["bgzip", "-f", temp_output], check=True)
        print(f"  ✓ Compressed: {output_path}")
        
        # Create tabix index
        print(f"  Creating tabix index...")
        try:
            subprocess.run(["tabix", "-p", "bed", output_path], check=True)
            print(f"  ✓ Created index: {output_path}.tbi")
        except Exception as e:
            print(f"  ✗ Failed to create tabix index: {e}")
    else:
        convert_bed_file(input_path, output_path, unmapped_path, 
                        input_gzipped=is_gzipped, output_gzipped=is_gzipped)
        print(f"  ✓ Mapped BED: {output_path}")
        print(f"  ✓ Unmapped intervals: {unmapped_path}")

print("\n" + "="*50)
print("ALL CONVERSIONS COMPLETE")
print("="*50)
