configfile: 'config.yaml'

from Bio import SeqIO
from subprocess import CalledProcessError
# module load python/3.9.6 sratoolkit samtools freebayes vcftools bwa bedtools r/4.2.2 rstudio subread star hisat2 kraken fastx_toolkit
# module load gcc/11.2.0

sample_by_name = {c['name'] : c for c in config['data_sets']}
ref_genome_by_name = { g['name'] : g for g in config['reference_genomes']}
annotation_by_name = { a['name'] : a for a in config['annotations']}

sampname_by_group = {}
sampname_by_sra = {}


for s in sample_by_name.keys():
	subgroup_lst = sample_by_name[s]['subgroups']
	for g in subgroup_lst:
		if g in sampname_by_group.keys():
			sampname_by_group[g].append(s)
		else:
			sampname_by_group[g] = [s]

	try:
		sampname_by_sra[sample_by_name[s]['SRA']] = s
	except KeyError:
		pass


def return_filename_by_sampname(sampname):
	filenames = []
	if sample_by_name[sampname]['paired']:
		filenames.append(sample_by_name[sampname]['readsfile1'])
		filenames.append(sample_by_name[sampname]['readsfile2'])
	else:
		filenames.append(sample_by_name[sampname]['readsfile'])
	return filenames

def return_file_relpath_by_sampname(wildcards):
	sampname = wildcards.samplename
	pathprefix = sample_by_name[sampname]["path"]
	filesin = return_filename_by_sampname(sampname)
	pathsout = ["".join([pathprefix, fq]) for fq in filesin]
	return pathsout





rule all:
	input: 
		pdf_out="results/exRNA2023_results.pdf",
	params:
		runmem_gb=1,
		runtime="0:01:00",
		cores=1,
	run:
		shell(""" mkdir -p results/figures/; touch results/figures/null.png; for fig in results/figures/*png; do mv $fig $(echo $fig| rev | cut -f 2- -d . | rev ).$(date +%d_%b_%Y).png; done;  rm results/figures/null.*.png; """)
		shell(""" mkdir -p results/figures/supp/ ; touch results/figures/supp/null.png; for fig in results/figures/supp/*png; do mv $fig $(echo $fig| rev | cut -f 2- -d . | rev ).$(date +%d_%b_%Y).png; done; rm results/figures/supp/null.*.png; """)

		shell(""" mkdir -p results/tables/ ; touch results/tables/null.tmp ; for phial in $(ls -p results/tables/ | grep -v /); do pre=$(echo $phial | rev | cut -f 2- -d . | rev ); suff=$(echo $phial | rev | cut -f 1 -d . | rev ); mv results/tables/$phial results/tables/$pre.$(date +%d_%b_%Y).$suff; done ; rm results/tables/null.*.tmp; """)
		shell(""" mkdir -p results/tables/supp/ ; touch results/tables/supp/null.tmp ; for phial in $(ls -p results/tables/supp/ | grep -v /); do pre=$(echo $phial | rev | cut -f 2- -d . | rev ); suff=$(echo $phial | rev | cut -f 1 -d . | rev ); mv results/tables/supp/$phial results/tables/supp/$pre.$(date +%d_%b_%Y).$suff; done ; rm results/tables/supp/null.*.tmp; """)

		shell(""" mv results/exRNA2023_results.pdf results/exRNA2023_results.$(date +%d_%b_%Y).pdf """)
		shell(""" tar cf exRNA_results.$(date +%d_%b_%Y).tar results/ """)






############################################################################  
#######		background data, eg reference genomes 	####
############################################################################  


rule reference_genome_reporter:
	input:
		fa_in = lambda wildcards: ref_genome_by_name[wildcards.ref_gen]['path'],
	output:
		report_out = "data/summaries/reference_genomes/{ref_gen}.fai.report",
		genome_out = "data/external/reference_genomes/{ref_gen}.fa",
	params:
		runmem_gb=1,
		runtime="5:00",
		cores=1,
	shell:
		"""
		mkdir -p data/summaries/external/reference_genomes/ data/external/reference_genomes/ ; 
		ln -frs {input.fa_in} {output.genome_out} ;
		samtools faidx {output.genome_out} ;
		cat {output.genome_out}.fai | awk '{{sum+=$2}} END {{ print "number_contigs\t",NR; print "number_bases\t",sum}}' | sed -e 's/^/{wildcards.ref_gen}\t/g' > {output.report_out};
		"""

rule demand_reference_genome_summary:
	input:
		refgen_reports = lambda wildcards: expand("data/summaries/reference_genomes/{ref_gen}.fai.report", ref_gen=ref_genome_by_name.keys())
	output:
		refgen_summary = "data/summaries/reference_genomes/reference_genomes.summary"
	params:
		runmem_gb=1,
		runtime="5:00",
		cores=1,
	shell:
		"cat {input.refgen_reports} > {output.refgen_summary}"

############################################################################  
#######		Read files: summon them, process them 	####
############################################################################  

#print(sampname_by_sra)
rule summon_reads_SRA_pe:
	output:
		reads1='data/external/sequence/paired_end/{samplename}/{samplename}_1.fastq',
		reads2='data/external/sequence/paired_end/{samplename}/{samplename}_2.fastq',
	params:
		runmem_gb=8,
		runtime="3:00:00",
		cores=1,
	run:
		try:
			sra = sampname_by_sra[wildcards.samplename]#["SRA"]
			shell(""" mkdir -p data/external/sequence/paired_end/{wildcards.samplename}/ """)
			shell("""
				fasterq-dump  --split-3 --outdir data/external/sequence/paired_end/{wildcards.samplename}/ {wildcards.samplename}
			""")
		except KeyError:
			raise KeyError("Sorry buddy, you can only download SRAs that are associated with a sample in the config file! " )

rule summon_reads_SRA_se:
	output:
		reads='data/external/sequence/single_end/{prefix}/{prefix}.fastq',
	params:
		runmem_gb=8,
		runtime="3:00:00",
		cores=1,
	run:

		try:
			sra = sampname_by_sra[wildcards.prefix]#["SRA"]
			shell(""" mkdir -p data/external/sequence/single_end/{wildcards.prefix}/ """)
			# shell("""
				# fasterq-dump  --split-3 --outdir data/external/sequence/single_end/{wildcards.prefix}/ {sra}
			# """)
			shell("""
				fasterq-dump  --split-3 --outdir data/external/sequence/single_end/{wildcards.prefix}/ {wildcards.prefix}
			""")

		except KeyError:
			raise KeyError("Sorry buddy, you can only download SRAs that are associated with a sample in the config file! " )



# data/ultimate/freq_shift/all.melvinCntrl_with_melvinSim_and_melvinSech.vs_dm6.bwaUniq.windowed_w100000_s100000.frqShift.bed data/ultimate/freq_shift/all.melvinSelect_with_melvinSim_and_melvinSech.vs_dm6.bwaUniq.windowed_w100000_s100000.frqShift.bed data/ultimate/freq_shift/all.melvinCntrl_with_melvinSim_and_melvinSech.vs_droSim1.bwaUniq.windowed_w100000_s100000.frqShift.bed data/ultimate/freq_shift/all.melvinSelect_with_melvinSim_and_melvinSech.vs_droSim1.bwaUniq.windowed_w100000_s100000.frqShift.bed data/ultimate/freq_shift/all.melvinCntrl_with_melvinSim_and_melvinSech.vs_droSec1.bwaUniq.windowed_w100000_s100000.frqShift.bed data/ultimate/freq_shift/all.melvinSelect_with_melvinSim_and_melvinSech.vs_droSec1.bwaUniq.windowed_w100000_s100000.frqShift.bed
# data/ultimate/freq_shift/all.Earley2011Selection_with_labSim_and_labSech.vs_dm6.bwaUniq.windowed_w100000_s100000.frqShift.bed data/ultimate/freq_shift/all.Earley2011Selection_with_labSim_and_wildSech.vs_dm6.bwaUniq.windowed_w100000_s100000.frqShift.bed 


def return_file_relpath_by_sampname(sampname):


	if sample_by_name[sampname]["source"] in ["NCBI"]:
		subfolder = sample_by_name[sampname]["SRA"]
		path = "data/external/sequence/"

	else:
		subfolder = sampname
		path = "data/raw/sequence/"

	if sample_by_name[sampname]["paired"] :
		path = "%spaired_end/%s/" % (path, subfolder)

	else:
		path = "%ssingle_end/%s/" % (path,subfolder)

	filesin = return_filename_by_sampname(sampname)
	pathsout = ["".join([path, fq]) for fq in filesin]

	return pathsout

def return_file_relpath_by_sampname(sampname):


	pith = sample_by_name[sampname]["path"]

	filesin = return_filename_by_sampname(sampname)
	pathsout = ["".join([pith, fq]) for fq in filesin]

	return pathsout


rule fastp_clean_sample_se:
	input:
		fileIn = lambda wildcards: return_file_relpath_by_sampname(wildcards.samplename)
	output:
		fileOut = ["data/intermediate/sequence/{samplename}/{samplename}.clean.R0.fastq"],
#		fileOut = ["{pathprefix}/{samplename}.clean.R0.fastq"],
		jason = "data/intermediate/sequence/{samplename}/{samplename}.False.json"
	params:
		runmem_gb=8,
		runtime="3:00:00",
		cores=1,
		#--trim_front1 and -t, --trim_tail1
		#--trim_front2 and -T, --trim_tail2. 
		common_params = "--json data/intermediate/sequence/{samplename}/{samplename}.False.json",# --html meta/FASTP/{samplename}.html", 
		se_params = "",
	message:
		"FASTP QA/QC on single-ended reads ({wildcards.samplename}) in progress.... "
	run:
		shell(""" mkdir -p data/intermediate/sequence/{wildcards.samplename}/ """)
		shell(""" /nas/longleaf/home/csoeder/modules/fastp/fastp {params.common_params} {params.se_params} --in1 {input.fileIn[0]} --out1 {output.fileOut[0]} """)
		


rule fastp_clean_sample_pe:
	input:
		fileIn = lambda wildcards: return_file_relpath_by_sampname(wildcards.samplename)
	output:
		fileOut = ["data/intermediate/sequence/{samplename}/{samplename}.clean.R1.fastq","data/intermediate/sequence/{samplename}/{samplename}.clean.R2.fastq"],
		jason = "data/intermediate/sequence/{samplename}/{samplename}.True.json"
	params:
		runmem_gb=8,
		runtime="3:00:00",
		cores=1,
		#--trim_front1 and -t, --trim_tail1
		#--trim_front2 and -T, --trim_tail2. 
		common_params = "--json data/intermediate/sequence/{samplename}/{samplename}.True.json",# --html meta/FASTP/{samplename}.html", 
		pe_params = "--detect_adapter_for_pe --correction",
	message:
		"FASTP QA/QC on paired-ended reads ({wildcards.samplename}) in progress.... "
	run:
		shell(""" mkdir -p data/intermediate/sequence/{wildcards.samplename}/ """)
		shell(""" /nas/longleaf/home/csoeder/modules/fastp/fastp {params.common_params} {params.pe_params} --in1 {input.fileIn[0]} --out1 {output.fileOut[0]} --in2 {input.fileIn[1]} --out2 {output.fileOut[1]} """)


rule FASTP_summarizer:
	input: 
		jason = lambda wildcards: expand("data/intermediate/sequence/{samp}/{samp}.{pairt}.json", samp = wildcards.samplename, pairt = sample_by_name[wildcards.samplename]['paired'])
#		jason = lambda wildcards: expand("{path}{samp}.{pairt}.json", path=sample_by_name[wildcards.samplename]['path'], samp = wildcards.samplename, pairt = sample_by_name[wildcards.samplename]['paired'])
	output:
		jason_pruned = "data/summaries/intermediate/FASTP/{samplename}/{samplename}.json.pruned"
	params:
		runmem_gb=1,
		runtime="5:00",
		cores=1,
	message:
		"Summarizing reads for sample ({wildcards.samplename}) .... "	
	shell:
		"""
		mkdir -p data/summaries/intermediate/FASTP/{wildcards.samplename}/
		cp {input.jason} data/summaries/intermediate/FASTP/{wildcards.samplename}/{wildcards.samplename}.json
		python3 scripts/fastp_reporter.py {input.jason} {output.jason_pruned} -t {wildcards.samplename}
		"""

rule read_length_distribution:
	input: 
		reads = "data/{sauce}/sequence/{filepath}.fastq"
	output:
		lengths = "data/summaries/{sauce}/read_lengths/{filepath}.lengths"
	params:
		runmem_gb=1,
		runtime="60:00",
		cores=1,
	message:
		"  .... "	
	run:
		shell("""
		mkdir -p data/summaries/{wildcards.sauce}/read_lengths/{wildcards.filepath}; rm -rf data/summaries/{wildcards.sauce}/read_lengths/{wildcards.filepath}; 
		cat {input.reads} | sed -n '1~4s/^@/>/p;2~4p' |fasta_formatter -t | cut -f 2 |  awk '{{print length}}' | sort | uniq -c | tr -s " " | awk '{{print $2"\t"$1}}' > {output.lengths}
		""")

rule demand_FASTQ_analytics:	#forces a FASTP clean
	input:
		jasons_in = lambda wildcards: expand("data/summaries/intermediate/FASTP/{samplename}/{samplename}.json.pruned", samplename = sampname_by_group[wildcards.group]),
		lengths = lambda wildcards: expand("data/summaries/intermediate/read_lengths/{samplename}/{samplename}.clean.R{pairt}.lengths", samplename = sampname_by_group[wildcards.group], pairt = [1,2]),
		fresh_len = lambda wildcards: expand("data/summaries/raw/read_lengths/{infix}.lengths", infix = [sample_by_name[samp]["path"].removeprefix("data/raw/sequence/") + sample_by_name[samp][reeds].removesuffix(".fastq")  for samp in sampname_by_group[wildcards.group] for reeds in ["readsfile1","readsfile2"]])
	output:
		summary = "data/summaries/intermediate/FASTP/{group}.sequenced_reads.dat",
		all_len = "data/summaries/intermediate/read_lengths/{group}.sequenced_lengths.dat",
	params:
		runmem_gb=1,
		runtime="1:00",
		cores=1,
	message:
		"Collecting read summaries for all samples ...."
	run:
		shell("""cat {input.jasons_in} > {output.summary}""")
		shell("""rm -rf {output.all_len}""")
		for samp in sampname_by_group[wildcards.group]:
			for reed in [1,2]:
				shell("""cat data/summaries/intermediate/read_lengths/{samp}/{samp}.clean.R{reed}.lengths | awk '{{print"{samp}\t{reed}\t"$0}}' >> {output.all_len}""")
		


############################################################################  
#######		Map reads to reference genomes 	####
############################################################################  


rule bwa_align:
	input:
#		reads_in = lambda wildcards: expand("data/intermediate/FASTQs/{source}/{sample}/{sample}.clean.R{arr}.fastq", source=sample_by_name[wildcards.sample]['source'], sample=wildcards.sample, arr=[ [1,2] if sample_by_name[wildcards.sample]['paired'] else [0] ][0]),
		reads_in = lambda wildcards: expand("data/intermediate/sequence/{sample}/{sample}.clean.R{arr}.fastq", sample=wildcards.sample, arr=[ [1,2] if sample_by_name[wildcards.sample]['paired'] else [0] ][0]),
		ref_genome_file = lambda wildcards: ref_genome_by_name[wildcards.ref_genome]['path'],
	output:
		bam_out = "data/intermediate/mapped_reads/bwa/{sample}.vs_{ref_genome}.bwa.sort.bam",
	params:
		runmem_gb=96,
		runtime="64:00:00",
		cores=8,
	message:
		"aligning reads from {wildcards.sample} to reference_genome {wildcards.ref_genome} .... "
	run:
		shell("bwa aln {input.ref_genome_file} {input.reads_in[0]} > {input.reads_in[0]}.{wildcards.ref_genome}.sai ")
		if sample_by_name[wildcards.sample]['paired']:
			shell("bwa aln {input.ref_genome_file} {input.reads_in[1]} > {input.reads_in[1]}.{wildcards.ref_genome}.sai ")
			shell("bwa sampe {input.ref_genome_file} {input.reads_in[0]}.{wildcards.ref_genome}.sai {input.reads_in[1]}.{wildcards.ref_genome}.sai {input.reads_in[0]}  {input.reads_in[1]} | samtools view -Shb | samtools addreplacerg -r ID:{wildcards.sample} -r SM:{wildcards.sample} - | samtools sort -o {output.bam_out} - ")
		else:
			shell("bwa samse {input.ref_genome_file} {input.reads_in[0]}.{wildcards.ref_genome}.sai {input.reads_in[0]} | samtools view -Shb | samtools addreplacerg -r ID:{wildcards.sample} -r SM:{wildcards.sample} - | samtools sort -o {output.bam_out} - ")
		shell("samtools index {output.bam_out}")


#	request stats/idxstats/flagstats?  

rule bwa_uniq:
	input:
		bam_in = "data/intermediate/mapped_reads/bwa/{sample}.vs_{ref_genome}.bwa.sort.bam"
	output:
		bam_out = "data/intermediate/mapped_reads/bwaUniq/{sample}.vs_{ref_genome}.bwaUniq.sort.bam"
	params:
		quality="-q 20 -F 0x0100 -F 0x0200 -F 0x0300 -F 0x04",
		uniqueness="XT:A:U.*X0:i:1.*X1:i:0",
		runmem_gb=16,
		runtime="18:00:00",
		cores=4,
	message:
		"filtering alignment of {wildcards.sample} to {wildcards.ref_genome} for quality and mapping uniqueness.... "	
	run:
		ref_genome_file=ref_genome_by_name[wildcards.ref_genome]['path']
		#original; no dedupe
		#"samtools view {params.quality} {input.bam_in} | grep -E {params.uniqueness} | samtools view -bS -T {ref_genome} - | samtools sort -o {output.bam_out} - "
		shell("samtools view {params.quality} {input.bam_in} | grep -E {params.uniqueness} | samtools view -bS -T {ref_genome_file} - | samtools addreplacerg -r ID:{wildcards.sample} -r SM:{wildcards.sample} - | samtools sort -n - | samtools fixmate -m - - | samtools sort - | samtools markdup -r - {output.bam_out}")
		shell("samtools index {output.bam_out}")


rule mapsplice_builder:
	output:
		windowed='utils/MapSplice-v2.1.8/mapsplice.py.bak'
	params:
		runmem_gb=8,
		runtime="30:00",
		cores=1,
	run:
		shell("mkdir -p utils/")
		#roll back the compiler for this, eg module load gcc/4.1.2 

		shell(
			""" 
			cd utils;
			wget http://protocols.netlab.uky.edu/~zeng/MapSplice-v2.1.8.zip ;
			unzip MapSplice-v2.1.8.zip;
			2to3 -w MapSplice-v2.1.8/;
			cd MapSplice-v2.1.8/;
			make;
			cd ..;
			rm MapSplice-v2.1.8.zip;
			"""
		)		


rule mapsplice2_align_raw:
	input:
		reads_in = lambda wildcards: expand("data/intermediate/sequence/{sample}/{sample}.clean.R{arr}.fastq", sample=wildcards.sample, arr=[ [1,2] if sample_by_name[wildcards.sample]['paired'] else [0] ][0]),
#		ref_genome_file = lambda wildcards: ref_genome_by_name[wildcards.ref_genome]['path'],
		ref_genome_file = "data/external/reference_genomes/{ref_genome}.fa",
	output:
		raw_bam = "data/intermediate/mapped_reads/mapspliceRaw/{sample}.vs_{ref_genome}.mapspliceRaw.sort.bam",
	params:
		runmem_gb=16,
		runtime="168:00:00",
#		runtime="96:00:00",
		cores=8,
	message:
		"aligning reads from {wildcards.sample} to reference_genome {wildcards.ref_genome} .... "
	run:
		ref_genome_split = ref_genome_by_name[wildcards.ref_genome]['split'],
		ref_genome_bwt = ref_genome_by_name[wildcards.ref_genome]['bowtie'],
		shell(""" mkdir -p data/intermediate/mapped_reads/mapspliceRaw/{wildcards.sample}/ summaries/BAMs/""")
		shell(""" 
			python utils/MapSplice-v2.1.8/mapsplice.py  --qual-scale phred33 -c {ref_genome_split} -x {ref_genome_bwt} -1 {input.reads_in[0]} -2 {input.reads_in[1]} -o data/intermediate/mapped_reads/mapspliceRaw/{wildcards.sample}/ 
			""")
		shell(""" 
			samtools view -hb data/intermediate/mapped_reads/mapspliceRaw/{wildcards.sample}/alignments.sam | samtools sort - > {output.raw_bam};
			samtools index {output.raw_bam};
			rm -rf data/intermediate/mapped_reads/mapspliceRaw/{wildcards.sample}/;
			""")














####	STAR
#	file:///home/mayko/Research/Bio/bioinformatics/STARmanual.pdf
#	https://github.com/alexdobin/STAR


rule star_indexer:
	input:
		genome_in= lambda wildcards: ref_genome_by_name[wildcards.ref_genome]['path'],
	output:
		str_ndx = "utils/STAR_indicies/{ref_genome}/chrName.txt",
	params:
		runmem_gb=64,
		runtime="12:00:00",
		cores=8,
	message:
#		"building STAR index for {wildcards.ref_genome}, guided by {wildcards.annot} annotation.... "
		"building STAR index for {wildcards.ref_genome} .... "
	run:
		shell(""" mkdir -p utils/STAR_indicies/{wildcards.ref_genome}/  """)
		shell("""  star --runThreadN {params.cores} --runMode genomeGenerate --genomeDir utils/STAR_indicies/{wildcards.ref_genome}/ --genomeFastaFiles {input.genome_in}  """)
# #		shell("""  star --runThreadN {params.cores} --runMode genomeGenerate --genomeDir utils/STAR_indicies/{wildcards.ref_genome}/built_with_annotation/{wildcards.annot}/ --genomeFastaFiles {input.genome_in} --sjdbGTFfile {input.annotations_in} """)



rule star_mapper:
	input:
		reads_in = lambda wildcards: expand("data/intermediate/sequence/{sample}/{sample}.clean.R{arr}.fastq", sample=wildcards.sample, arr=[ [1,2] if sample_by_name[wildcards.sample]['paired'] else [0] ][0]),
		str_ndx = "utils/STAR_indicies/{ref_genome}/chrName.txt",
	output:
		rawStar_bam = "data/intermediate/mapped_reads/starRaw/{sample}.vs_{ref_genome}.starRaw.sort.bam",
	params:
		runmem_gb=32,
		runtime="8:00:00",
		cores=8,
	message:
		"filtering raw {wildcards.sample} alignment to {wildcards.ref_genome} to remove multimappers entirely.... "
	run:
		shell(""" mkdir -p data/intermediate/mapped_reads/starRaw/ """)
		shell(""" 

			star --runThreadN {params.cores} --runMode alignReads --genomeDir utils/STAR_indicies/{wildcards.ref_genome}/ --readFilesIn {input.reads_in} --outFileNamePrefix data/intermediate/mapped_reads/starRaw/{wildcards.sample}.vs_{wildcards.ref_genome}.starRaw
			samtools view -Shb data/intermediate/mapped_reads/starRaw/{wildcards.sample}.vs_{wildcards.ref_genome}.starRawAligned.out.sam | samtools sort - > {output.rawStar_bam}
			samtools index {output.rawStar_bam}
			""")


# rule star_mapper:
	# input:
		# reads_in = lambda wildcards: expand("data/intermediate/sequence/{sample}/{sample}.clean.R{arr}.fastq", sample=wildcards.sample, arr=[ [1,2] if sample_by_name[wildcards.sample]['paired'] else [0] ][0]),
# #		str_ndx = "utils/STAR_indicies/{wildcards.ref_genome}/built_with_annotation/{wildcards.annot}/chrName.txt",
		# str_ndx = "utils/STAR_indicies/{wildcards.ref_genome}/chrName.txt",
	# output:
		# rawStar_bam = "data/intermediate/mapped_reads/starRaw/{sample}.vs_{ref_genome}.starRaw.sort.bam",
	# params:
		# runmem_gb=8,
		# runtime="1:00:00",
		# cores=8,
	# message:
		# "filtering raw {wildcards.sample} alignment to {wildcards.ref_genome} to remove multimappers entirely.... "
	# run:
		# shell(""" mkdir -p data/intermediate/mapped_reads/starRaw/ """)
		# shell(""" 

			# star --runThreadN {params.cores} --runMode alignReads --genomeDir utils/STAR_indicies/{wildcards.ref_genome}/built_with_annotation/{wildcards.annot}/ --readFilesIn {input.reads_in} --outFileNamePrefix data/intermediate/mapped_reads/starRaw/{sample}.vs_{ref_genome}.starRaw
			# samtools view -Shb data/intermediate/mapped_reads/starRaw/{sample}.vs_{ref_genome}.starRaw | samtools sort - > {output.rawStar_bam}
			# samtools index {output.rawStar_bam}
			# """)


#		shell("""   """)








####	HISAT2
#	https://daehwankimlab.github.io/hisat2/manual/

rule hisat2_indexer:
	input:
		genome_in = "data/external/reference_genomes/{ref_genome}.fa",
	output:
		hst_ndx = "utils/HISAT2_indicies/{ref_genome}.1.ht2",
	params:
		runmem_gb=64,
		runtime="4:00:00",
		cores=8,
	message:
		"HISAT2 index of  {wildcards.ref_genome} building.... "
	run:
		shell(""" rm -rf utils/HISAT2_indicies/{wildcards.ref_genome}/  """)
		shell(""" mkdir -p utils/HISAT2_indicies/  """)
		shell(""" hisat2-build -p {params.cores} {input.genome_in} utils/HISAT2_indicies/{wildcards.ref_genome} """)


rule hisat2_mapper:
	input:
		hst_ndx = "utils/HISAT2_indicies/{ref_genome}.1.ht2",
		reads_in = lambda wildcards: expand("data/intermediate/sequence/{sample}/{sample}.clean.R{arr}.fastq", sample=wildcards.sample, arr=[ [1,2] if sample_by_name[wildcards.sample]['paired'] else [0] ][0]),
	output:
		rawHisat_bam = "data/intermediate/mapped_reads/hisatRaw/{sample}.vs_{ref_genome}.hisatRaw.sort.bam",
		summary = "data/intermediate/mapped_reads/hisatRaw/{sample}.vs_{ref_genome}.hisatRaw.summary",
	params:
		runmem_gb=64,
		runtime="8:00:00",
		cores=8,
	message:
		"filtering raw {wildcards.sample} alignment to {wildcards.ref_genome} to remove multimappers entirely.... "
	run:
		shell(""" mkdir -p mapped_reads/hisatRaw/{wildcards.sample}/ utils/HISAT2_indicies/{wildcards.ref_genome}/  """)
		if sample_by_name[wildcards.sample]['paired']:
			readsIn = " -1 %s -2 %s " % tuple(input.reads_in)
		else:
			readsIn = " -m %s " % tuple(input.reads_in)
			 
		shell(""" hisat2 -p {params.cores} -k 5 --new-summary --summary-file {output.summary} -x utils/HISAT2_indicies/{wildcards.ref_genome} {readsIn} -S data/intermediate/mapped_reads/hisatRaw/{wildcards.sample}.vs_{wildcards.ref_genome}.hisatRaw.sam """)
		shell(""" samtools view -Shb data/intermediate/mapped_reads/hisatRaw/{wildcards.sample}.vs_{wildcards.ref_genome}.hisatRaw.sam | samtools sort - > {output.rawHisat_bam} """)
		shell(""" samtools index {output.rawHisat_bam} """)
#--no-mixed


rule hisat2_lax:
	input:
		hst_ndx = "utils/HISAT2_indicies/{ref_genome}.1.ht2",
		reads_in = lambda wildcards: expand("data/intermediate/sequence/{sample}/{sample}.clean.R{arr}.fastq", sample=wildcards.sample, arr=[ [1,2] if sample_by_name[wildcards.sample]['paired'] else [0] ][0]),
	output:
		rawHisat_bam = "data/intermediate/mapped_reads/hisatLaxRaw/{sample}.vs_{ref_genome}.hisatLaxRaw.sort.bam",
		summary = "data/intermediate/mapped_reads/hisatLaxRaw/{sample}.vs_{ref_genome}.hisatLaxRaw.summary",
	params:
		runmem_gb=64,
		runtime="8:00:00",
		cores=8,
	message:
		"filtering raw {wildcards.sample} alignment to {wildcards.ref_genome} to remove multimappers entirely.... "
	run:
		shell(""" mkdir -p mapped_reads/hisatLaxRaw/{wildcards.sample}/ utils/HISAT2_indicies/{wildcards.ref_genome}/  """)
		if sample_by_name[wildcards.sample]['paired']:
			readsIn = " -1 %s -2 %s " % tuple(input.reads_in)
		else:
			readsIn = " -m %s " % tuple(input.reads_in)
			 
		shell(""" hisat2 --mp 4,1 --rfg 4,2 -p {params.cores} -k 5 --new-summary --summary-file {output.summary} -x utils/HISAT2_indicies/{wildcards.ref_genome} {readsIn} -S data/intermediate/mapped_reads/hisatLaxRaw/{wildcards.sample}.vs_{wildcards.ref_genome}.hisatLaxRaw.sam """)
		shell(""" samtools view -Shb data/intermediate/mapped_reads/hisatLaxRaw/{wildcards.sample}.vs_{wildcards.ref_genome}.hisatLaxRaw.sam | samtools sort - > {output.rawHisat_bam} """)
		shell(""" samtools index {output.rawHisat_bam} """)







rule multiFilter:
	input:
		raw_bam = "data/intermediate/mapped_reads/{aligner}Raw/{sample}.vs_{ref_genome}.{aligner}Raw.sort.bam",
	output:
		multi_bam = "data/intermediate/mapped_reads/{aligner}Multi/{sample}.vs_{ref_genome}.{aligner}Multi.sort.bam",
	params:
		runmem_gb=64,
		runtime="6:00:00",
		cores=8,
		dup_flg = "-rS ",#remove marked duplicates; remove secondary alignments of marked duplicates
		quality="-q 20 -F 0x0200 -F 0x04 -f 0x0002", # no QC fails, no duplicates, proper pairs only, mapping qual >20
	message:
		"filtering raw {wildcards.sample} alignment to {wildcards.ref_genome} for quality, duplication.... "
	run:
		shell(""" mkdir -p mapped_reads/mapsplice{wildcards.aligner}/{wildcards.sample}/ """)
		shell(""" 
			samtools sort -n {input.raw_bam} | samtools fixmate -m - - | samtools sort - | samtools markdup {params.dup_flg} - - | samtools view -bh {params.quality} | /nas/longleaf/home/csoeder/modules/bamaddrg/bamaddrg -b - -s {wildcards.sample}  > {output.multi_bam} ;
			samtools index {output.multi_bam} 
			""")



rule uniqFilt:
	input:
		multi_bam = "data/intermediate/mapped_reads/{aligner}Multi/{sample}.vs_{ref_genome}.{aligner}Multi.sort.bam",
	output:
		uniq_bam = "data/intermediate/mapped_reads/{aligner}Uniq/{sample}.vs_{ref_genome}.{aligner}Uniq.sort.bam",
	params:
		runmem_gb=8,
		runtime="1:00:00",
		cores=8,
	message:
		"filtering raw {wildcards.sample} alignment to {wildcards.ref_genome} to remove multimappers entirely.... "
	run:
		shell(""" mkdir -p mapped_reads/{wildcards.aligner}Uniq/{wildcards.sample}/  """)
		if wildcards.aligner == "mapsplice":
			shell(""" 
				samtools view {input.multi_bam} | grep -w "IH:i:1" | cat <( samtools view -H {input.multi_bam} ) - | samtools view -Sbh > {output.uniq_bam};
				samtools index {output.uniq_bam}
				""")
### filtering on uniqueness: MapSplice2 uses the IH:i:1 flag in the SAM specs. 

		elif wildcards.aligner in [ "star", "hisat"] :
			shell(""" 
				samtools view {input.multi_bam} | grep -w "NH:i:1" | cat <( samtools view -H {input.multi_bam} ) - | samtools view -Sbh > {output.uniq_bam};
				samtools index {output.uniq_bam}
				""")





rule spliced_alignment_reporter:
	input:
		bam_in = "data/intermediate/mapped_reads/{aligner}/{sample}.vs_{ref_genome}.{aligner}.sort.bam",
	output:
		report_out = "data/summaries/intermediate/BAMs/{aligner}/{sample}.vs_{ref_genome}.{aligner}.summary"
	params:
		runmem_gb=64,
		runtime="16:00:00",
		cores=1,
	message:
		"Collecting metadata for the {wildcards.aligner} alignment of {wildcards.sample} to {wildcards.ref_genome}.... "
	run:
 		ref_genome_idx=ref_genome_by_name[wildcards.ref_genome]['fai']
 		shell(""" which samtools """)
 		shell("samtools idxstats {input.bam_in} > {input.bam_in}.idxstats")
		shell("samtools flagstat {input.bam_in} > {input.bam_in}.flagstat")
		shell("bedtools genomecov -max 1 -i <( bedtools bamtobed -i {input.bam_in} | cut -f 1-3 ) -g {ref_genome_idx} > {input.bam_in}.span.genomcov")
		shell("bedtools genomecov -max 1 -i <( bedtools bamtobed -split -i {input.bam_in} | cut -f 1-3 ) -g {ref_genome_idx} > {input.bam_in}.split.genomcov")
# 		#change the -max flag as needed to set 
		shell(""" samtools depth -a {input.bam_in} | awk '{{sum+=$3; sumsq+=$3*$3}} END {{ print "average_depth\t",sum/NR; print "std_depth\t",sqrt(sumsq/NR - (sum/NR)**2)}}' > {input.bam_in}.dpthStats """)
# 		#https://www.biostars.org/p/5165/
# 		#save the depth file and offload the statistics to the bam_summarizer script?? 
		### filtering on uniqueness: MapSplice2 uses the IH:i:1 flag in the SAM specs. 
#		shell("""samtools view -F 4 {input.bam_in} | cut -f 13  | cut -f 3 -d ":" | sort | uniq -c | tr -s " " | awk -F " " '{{print$2"\t"$1}}' > {input.bam_in}.mapmult""")

		shell(""" samtools view -F 0x4 {input.bam_in} | cut -f 1 | sort | uniq | wc -l > {input.bam_in}.maptCount """)
		shell(""" samtools sort -n {input.bam_in} | samtools fixmate -m - -  | samtools sort - | samtools markdup -sS - - 1> /dev/null 2> {input.bam_in}.dupe """)# /dev/null 2> {input.bam_in}.dupe;""")
		shell(" python3 scripts/bam_summarizer.mapspliced.py -f {input.bam_in}.flagstat --mapped_count {input.bam_in}.maptCount -i {input.bam_in}.idxstats -g {input.bam_in}.split.genomcov -G {input.bam_in}.span.genomcov -d {input.bam_in}.dpthStats -D {input.bam_in}.dupe  -o {output.report_out} -t {wildcards.sample}")
#		shell(" python3 scripts/bam_summarizer.mapspliced.py -f {input.bam_in}.flagstat --mapped_count {input.bam_in}.maptCount -i {input.bam_in}.idxstats -g {input.bam_in}.split.genomcov -G {input.bam_in}.span.genomcov -d {input.bam_in}.dpthStats -D {input.bam_in}.dupe -m {input.bam_in}.mapmult -o {output.report_out} -t {wildcards.sample}")



rule alignment_insert_size_xtractor:
	input:
		bam_in = "data/intermediate/mapped_reads/{aligner}/{sample}.vs_{ref_genome}.{aligner}.sort.bam",
	output:
		insert_sizes = "data/summaries/intermediate/BAMs/{aligner}/{sample}.vs_{ref_genome}.{aligner}.insert_sizes"
	params:
		runmem_gb=8,
		runtime="6:00:00",
		cores=1,
	message:
		"Collecting metadata for the {wildcards.aligner} alignment of {wildcards.sample} to {wildcards.ref_genome}.... "
	run:

		shell("""  samtools view {input.bam_in} | cut -f 1,9,10 | awk '{{print sqrt($2^2)}}' | sort | uniq -c | tr -s " " | awk '{{print $2"\t"$1}}' > {output.insert_sizes} """)





# rule bam_reporter:
	# input:
		# bam_in = "data/intermediate/mapped_reads/{aligner}/{sample}.vs_{ref_genome}.{aligner}.sort.bam"
	# output:
		# report_out = "data/summaries/intermediate/BAMs/{aligner}/{sample}.vs_{ref_genome}.{aligner}.summary"
	# params:
		# runmem_gb=8,
		# runtime="4:00:00",
		# cores=1,
	# message:
		# "Collecting metadata for the {wildcards.aligner} alignment of {wildcards.sample} to {wildcards.ref_genome}.... "
	# run:
		# shell(""" mkdir -p data/summaries/intermediate/BAMs/{wildcards.aligner}/ """)
		# ref_genome_idx=ref_genome_by_name[wildcards.ref_genome]['fai']
		# shell("samtools idxstats {input.bam_in} > {input.bam_in}.idxstats")
		# shell("samtools flagstat {input.bam_in} > {input.bam_in}.flagstat")
		# shell("bedtools genomecov -max 1 -ibam {input.bam_in} -g {ref_genome_idx} > {input.bam_in}.genomcov")
		# #change the -max flag as needed to set 
		# shell("""samtools depth -a {input.bam_in} | awk '{{sum+=$3; sumsq+=$3*$3}} END {{ print "average_depth\t",sum/NR; print "std_depth\t",sqrt(sumsq/NR - (sum/NR)**2)}}' > {input.bam_in}.dpthStats""")
		# #https://www.biostars.org/p/5165/
		# #save the depth file and offload the statistics to the bam_summarizer script?? 
		# shell("python3 scripts/bam_summarizer.py -f {input.bam_in}.flagstat -i {input.bam_in}.idxstats -g {input.bam_in}.genomcov -d {input.bam_in}.dpthStats -o {output.report_out} -t {wildcards.sample}")


rule demand_BAM_analytics:
	input:
#		bam_reports = lambda wildcards: expand("data/summaries/intermediate/BAMs/{aligner}/{sample}.vs_{ref_genome}.{aligner}.summary", sample=sampname_by_group[wildcards.group], ref_genome=wildcards.ref_genome, aligner=[ x+y for x in ["hisat","star",] for y in ["Raw","Multi","Uniq"]]),
#		nsrts = lambda wildcards: expand("data/summaries/intermediate/BAMs/{aligner}/{sample}.vs_{ref_genome}.{aligner}.insert_sizes", sample=sampname_by_group[wildcards.group], ref_genome=wildcards.ref_genome, aligner=[ x+y for x in ["hisat","star",] for y in ["Raw","Multi","Uniq"]])
		bam_reports = lambda wildcards: expand("data/summaries/intermediate/BAMs/{aligner}/{sample}.vs_{ref_genome}.{aligner}.summary", sample=sampname_by_group[wildcards.group], ref_genome=wildcards.ref_genome, aligner=[ x+y for x in ["bwa","hisatRaw"] for y in [""]]),
		#nsrts = lambda wildcards: expand("data/summaries/intermediate/BAMs/{aligner}/{sample}.vs_{ref_genome}.{aligner}.insert_sizes", sample=sampname_by_group[wildcards.group], ref_genome=wildcards.ref_genome, aligner=[ x+y for x in ["bwa",] for y in [""]])
	output:
#		full_report = "data/summaries/intermediate/BAMs/{group}.vs_{ref_genome}.{aligner}.summary"
		full_report = "data/summaries/intermediate/BAMs/{group, \w+}.vs_{ref_genome}.summary"
	params:
		runmem_gb=1,
		runtime="1:00",
		cores=1,
	message:
		"collecting all alignment metadata.... "
	run:
		shell("rm -rf {output.full_report}")
#		for aligner in [ x+y for x in ["hisat","star"] for y in ["Raw","Multi","Uniq"]]:
		for aligner in [ x+y for x in ["bwa", "hisatRaw"] for y in [""]]:
			for sample in sampname_by_group[wildcards.group]:
				shell("""cat data/summaries/intermediate/BAMs/{aligner}/{sample}.vs_{wildcards.ref_genome}.{aligner}.summary | awk -v aln={aligner} '{{print aln"\t"$0}}' >> {output.full_report}""")

		
#	cat test.samtools.idxstats | sed \$d | awk '{print $1, $3/$2}' > per_contig_coverage_depth
#	echo  $( cat test.samtools.idxstats |  sed \$d | cut -f 2 | paste -sd+ | bc) $(cat test.samtools.idxstats |  sed \$d | cut -f 3 | paste -sd+ | bc) | tr  " " "\t" | awk '{print "total\t"$1/$2}'

#


rule count_features:
	input:
		alignments_in = lambda wildcards: expand("data/intermediate/mapped_reads/{aligner}/{sample}.vs_{ref_genome}.{aligner}.sort.bam", aligner = wildcards.aligner, sample=sampname_by_group[wildcards.group], ref_genome = wildcards.ref_genome  ),
		annot_in = lambda wildcards: annotation_by_name[wildcards.annot]["gtf_path"]
	output:
		counted_features = "data/intermediate/counts/{group}.vs_{ref_genome}.{annot}.{aligner}.{flags}.counts",
		count_stats = "data/intermediate/counts/{group}.vs_{ref_genome}.{annot}.{aligner}.{flags}.counts.summary",
	params:
		runmem_gb=8,
		runtime="64:00:00",
		cores=8,
		fc_params = " --countReadPairs -p -C -O ",#--verbose count multimappers, record junctions, count paired-end fragments, well-mapped   <- some of this is moved into the "flag" wildcard
		#-O ? -f? 
	message:
		"counting reads from {wildcards.group} aligned to {wildcards.ref_genome} with {wildcards.aligner} overlapping {wildcards.annot} .... "
	run:
		flug_str = wildcards.flags
		flug_lst = [ s for s in flug_str if s != "_"]
		if "z" in flug_lst:
#			flug_lst[flug_lst.index("z")] = "-countReadPairs"
			flug_lst.remove("z")
		flug_str = " -%s "*len(flug_lst) % tuple(flug_lst)


		sed_suff = ".vs_%s.%s.sort.bam" % tuple([wildcards.ref_genome, wildcards.aligner])		
		sed_cmd =  " sed -e 's/data\/intermediate\/mapped_reads\/[a-zA-Z0-9\/_]*\///g' | sed -e 's/%s//g' " % tuple([sed_suff])

		annot_gtf = annotation_by_name[wildcards.annot]["gtf_path"]
		shell(""" mkdir -p data/intermediate/counts/ """)
		shell("""
			featureCounts {flug_str} {params.fc_params} -t exon -g gene_id -F GTF -a <(cat {annot_gtf} | awk '{{print""$0}}') -o {output.counted_features}.tmp {input.alignments_in}
			""")
		# shell(""" cat {annot_gtf} | awk '{{print"chr"$0}}' >  {annot_gtf}.chr """)
		# shell("""
		# 	featureCounts {flug_str} {params.fc_params} -t exon -g gene_id -F GTF -a {annot_gtf}.chr -o {output.counted_features}.tmp {input.alignments_in}
		# 	""")
		shell("""
			cat data/intermediate/counts/{wildcards.group}.vs_{wildcards.ref_genome}.{wildcards.annot}.{wildcards.aligner}.{wildcards.flags}.counts.tmp | tail -n +2 | {sed_cmd} > {output.counted_features}
			cat data/intermediate/counts/{wildcards.group}.vs_{wildcards.ref_genome}.{wildcards.annot}.{wildcards.aligner}.{wildcards.flags}.counts.tmp.jcounts | {sed_cmd} > data/intermediate/counts/{wildcards.group}.vs_{wildcards.ref_genome}.{wildcards.annot}.{wildcards.aligner}.{wildcards.flags}.counts.jcounts
			cat data/intermediate/counts/{wildcards.group}.vs_{wildcards.ref_genome}.{wildcards.annot}.{wildcards.aligner}.{wildcards.flags}.counts.tmp.summary | {sed_cmd} > data/intermediate/counts/{wildcards.group}.vs_{wildcards.ref_genome}.{wildcards.annot}.{wildcards.aligner}.{wildcards.flags}.counts.summary
			rm data/intermediate/counts/{wildcards.group}.vs_{wildcards.ref_genome}.{wildcards.annot}.{wildcards.aligner}.{wildcards.flags}.counts.tmp* 
			""")


rule summarize_feature_counts:
	input:
		sum_in = "data/intermediate/counts/{group}.vs_{ref_genome}.{annot}.{aligner}.{flag}.counts.summary"
	output:
		count_sum = "data/summaries/intermediate/counts/{group}.vs_{ref_genome}.{annot}.{aligner}.{flag}.counts.stat",
	params:
		runmem_gb=1,
		runtime="15:00",
		cores=1,
	message:
		"consolidating read-counting summary of {wildcards.group} aligned to {wildcards.ref_genome} with {wildcards.aligner} overlapping {wildcards.annot} .... "
	run:
		shell("""
			head -n 1 {input.sum_in} > {output.count_sum};
			cat {input.sum_in} | grep -w "Assigned\|Unassigned_NoFeatures\|Unassigned_Ambiguity" >> {output.count_sum};
			""")




rule extract_problem_reads:
	input:
		bam_in = "data/intermediate/mapped_reads/{aligner}/{sample}.vs_hg38.{aligner}.sort.bam",
	output:
		read1 = "data/intermediate/sequence/{sample}/problematic/{aligner}/{sample}.problems.R1.fastq",
		read2 = "data/intermediate/sequence/{sample}/problematic/{aligner}/{sample}.problems.R2.fastq",
	params:
		runmem_gb=8,
		runtime="1:00:00",
		cores=1,
	message:
		" "
	run:
		uniquifier = subprocess.check_output(""" echo $(date +%N)*$(date +%N) | bc | md5sum | cut -f 1 -d " "  """  ,shell=True).decode().rstrip().upper()
		shell(""" mkdir -p data/intermediate/sequence/{wildcards.sample}/problematic/{wildcards.aligner}/ """)
		shell("""
			samtools view -hb -F 2 {input.bam_in} | samtools collate -O -u -@ {params.cores} - {uniquifier} | samtools fastq -N -1 {output.read1} -2 {output.read2}
			""")
		#-F 2 excludes proper pairs, ie, keeps unmapped and singleton




rule krakenate_problem_reads:
	input:
		read1 = "data/intermediate/sequence/{sample}/problematic/{aligner}/{sample}.problems.R1.fastq",
		read2 = "data/intermediate/sequence/{sample}/problematic/{aligner}/{sample}.problems.R2.fastq",
	output:
		krakenation = "data/intermediate/kraken/{aligner}/{sample}/{sample}.krakenated"
	params:
		runmem_gb=64,
		runtime="96:00:00",
		cores=8,
	message:
		" "
	run:
		db_ndx = "/proj/cdjones_lab/csoeder/kraken_ndx/"
		
		shell(""" mkdir -p data/intermediate/kraken/{wildcards.aligner}/{wildcards.sample}/""")
		shell("""
			kraken2 --memory-mapping --use-names --db {db_ndx} --report {output.krakenation} --paired {input.read1} {input.read2} > /dev/null 
			""")





rule krakenate_everything:	#forces a FASTP clean
	input:
		krakers = lambda wildcards: expand("data/intermediate/kraken/{aligner}/{sample}/{sample}.krakenated", sample = sampname_by_group[wildcards.group], aligner = wildcards.aligner),
	output:
		summary = "data/intermediate/kraken/{group}.{aligner,\w+}.krakenated"
	params:
		runmem_gb=1,
		runtime="1:00",
		cores=1,
	message:
		"gather krakenations for everything ...."
	run:
		shell(""" rm -rf  {output.summary} """)
		for samp in sampname_by_group[wildcards.group]:
			shell(""" cat data/intermediate/kraken/{wildcards.aligner}/{samp}/{samp}.krakenated | awk '{{print"{samp}\t"$0}}' >> {output.summary} """)



rule trinityHALP:
	input:
		read1 = "data/intermediate/sequence/{sample}/problematic/{aligner}/{sample}.problems.R1.fastq",
		read2 = "data/intermediate/sequence/{sample}/problematic/{aligner}/{sample}.problems.R2.fastq",
	output:
		assembly_out = "data/intermediate/trinity/{aligner}/{sample}/{sample}.trinity.fa",
	params:
		runmem_gb=64,
		runtime="48:00:00",
		cores=8,
		trin_params=" --seqType fq ",
	message:
		"Trinity is assembling {wildcards.sample} .... "
	run:
		shell(""" mkdir -p data/intermediate/trinity/{wildcards.aligner}/{wildcards.sample}/ """)

		trin_params = params.trin_params
		# shell(""" 
		# 	Trinity {trin_params} --full_cleanup --max_memory 50G --left {r1}  --right {r2} --include_supertranscripts --output assembled_transcripts/{wildcards.sample}/trinity/
		# 	""")
		shell(""" 
			Trinity {trin_params} --full_cleanup --max_memory 50G --left {input.read1}  --right {input.read2} --include_supertranscripts --output data/intermediate/trinity/{wildcards.aligner}/{wildcards.sample}/trinity/
			""")
		# shell(""" 
		# 	mv assembled_transcripts/{wildcards.sample}/trinity/Trinity.fasta {output.transcriptome_out};
		#  """)
		shell(""" 
			mv data/intermediate/trinity/{wildcards.aligner}/{wildcards.sample}/trinity.Trinity.fasta {output.assembly_out};
			rm -rf data/intermediate/trinity/{wildcards.aligner}/{wildcards.sample}/trinity/;
		 """)
		shell(""" 
			samtools faidx {output.assembly_out};
		 """)
#			rm -rf assembled_transcripts/{wildcards.sample}/trinity/read_partitions/ assembled_transcripts/{wildcards.sample}/trinity/both.fa* assembled_transcripts/{wildcards.sample}/trinity/jellyfish.kmers.fa* rm -rf assembled_transcripts/{wildcards.sample}/trinity/scaffolding_entries.sam; 




rule investigate_mycoplasma:	#forces a FASTP clean
	input:
		bam_in = "data/intermediate/mapped_reads/bwa/{sample}.vs_mycoG37.bwa.sort.bam",
	output:
		cov_bg = "data/intermediate/mycoplasma/{sample}.vs_mycoG37.bwa.cov.bg",
		gene_report = "data/intermediate/mycoplasma/{sample}.vs_mycoG37.bwa.geneReport.bed",
	params:
		runmem_gb=8,
		runtime="1:00:00",
		cores=1,
	message:
		"investigating mycoplasma in {wildcards.sample} ...."
	run:
		shell(""" rm -rf  {output} ; mkdir -p data/intermediate/mycoplasma/ """)
		shell(""" bedtools genomecov -split -bg -ibam {input.bam_in} | bedtools merge -d 0 -c 4 -o max -i - | sort -k 4 -g -r  > {output.cov_bg}""")
		myco_genes = "/proj/cdjones_lab/Genomics_Data_Commons/genomes/Mycoplasma/genitalium_G37/ncbi_dataset/data/GCF_000027325.1/genomic.gff"
		shell(""" bedtools intersect -loj -wa -wb -a {output.cov_bg} -b <( cat {myco_genes} | awk '{{if($3 == "gene")print;}}') | sed -e 's/ID=.*Name=//g' | sed -e 's/;gbkey=.*//g' | cut -f 1-4,13 | awk '{{print$0"\t{wildcards.sample}"}}' > {output.gene_report} """)



rule all_mycoplasma_investigations:	#forces a FASTP clean
	input:
		genes_in = lambda wildcards: expand("data/intermediate/mycoplasma/{sample}.vs_mycoG37.bwa.geneReport.bed", sample = sampname_by_group[wildcards.group]),
	output:
		full_report = "data/intermediate/mycoplasma/{group}.mycoG37_genes.full_report.bed"
	params:
		runmem_gb=1,
		runtime="1:00",
		cores=1,
	message:
		"investigating mycoplasma in {wildcards.group} ...."
	run:
		shell(""" cat {input} > {output} """)







rule write_report:
	input:
		reference_genome_summary = ["data/summaries/reference_genomes/reference_genomes.summary"],
#		reference_annotation_summary = [""],
		sequenced_reads_summary=["data/summaries/intermediate/FASTP/all.sequenced_reads.dat", "data/summaries/intermediate/read_lengths/all.sequenced_lengths.dat"],
		aligned_reads_summary = expand("data/summaries/intermediate/BAMs/all.vs_{genome}.summary", genome=["hg38","humanRibo","humanTrna","mycoG37","myco1654_15",]),#"mapspliceUniq","mapspliceRando"]),
		the_countz = expand("data/intermediate/counts/all.vs_hg38.NCBIrefSeq.{aligner}{filt}.{count_params}.counts.summary",aligner = ["star", "hisat"], filt = ["Raw", "Multi", "Uniq"], count_params = ["M","B","MB","z"] ),
		kraken = ["data/intermediate/kraken/all.hisatRaw.krakenated"],
		myco = ["data/intermediate/mycoplasma/all.mycoG37_genes.full_report.bed"],
	output:
		pdf_out="results/exRNA2023_results.pdf",
	params:
		runmem_gb=8,
		runtime="1:00:00",
		cores=2,
	message:
		"writing up the results.... "
	run:
		pandoc_path="/nas/longleaf/apps/rstudio/2021.09.2-382/bin/pandoc"
		pwd = subprocess.check_output("pwd",shell=True).decode().rstrip()+"/"
		shell("""mkdir -p results/figures/supp/ results/tables/supp/""")
		shell(""" R -e "setwd('{pwd}');Sys.setenv(RSTUDIO_PANDOC='{pandoc_path}')" -e  "peaDubDee='{pwd}'; rmarkdown::render('scripts/exRNA_riboDepletion.Rmd',output_file='{pwd}{output.pdf_out}')"  """)
#		shell(""" tar cf results.tar results/ """)



















