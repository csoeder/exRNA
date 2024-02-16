import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-f", "--flagstat_in", help="samtools flagstat report")
parser.add_argument("-i", "--idxstat_in", help="samtools idxstat report")
parser.add_argument("-g", "--split_coverage", help="bedtools genomecov report, with split reads")
parser.add_argument("-G", "--spanning_coverage", help="bedtools genomecov report, with spanning reads")
parser.add_argument("-d", "--depthstats_in", help="samtools depth report")
parser.add_argument("-D", "--dupestats_in", help="samtools markdup stats report")
parser.add_argument( "-m", "--mapping_multiplicity", help="histogram of mapping multiplicity scraped from the IH:: tags")
parser.add_argument( "-c", "--mapped_count", help="count of mapped reads")
parser.add_argument("-o", "--flat_out", help="flatfile summary")
parser.add_argument("-t", "--tag", help="line-name for the flatfile", default=None)
args = parser.parse_args()


summary_dict={}

flagstat = open(args.flagstat_in, 'r')
flagstat_lines = flagstat.readlines()
flagstat.close()

idxstat = open(args.idxstat_in, 'r')
idxstat_lines = idxstat.readlines()[:-1]
idxstat.close()

span = open(args.spanning_coverage, 'r')
span_lines = span.readlines()
span.close()

split = open(args.split_coverage, 'r')
split_lines = split.readlines()
split.close()

dpth = open(args.depthstats_in, 'r')
dpth_lines = dpth.readlines()
dpth.close()

dupe = open(args.dupestats_in, 'r')
dupe_lines = dupe.readlines()
dupe.close()
dupe_lines = [d.rstrip() for d in dupe_lines]
while "" in dupe_lines:
	dupe_lines.remove("")


mapt = open(args.mapped_count, 'r')
mapt_lines = mapt.readlines()
mapt.close()


if args.mapping_multiplicity != None:
	mapmult = open(args.mapping_multiplicity, 'r')
	mapmult_lines = mapmult.readlines()
	mapmult.close()
	mapmult_lines = [x.split("\t") for x in mapmult_lines]
	mapmult_lines = {int(f[0]):int(f[1]) for f in mapmult_lines}
	uniquely_mapped = mapmult_lines.pop(1)
	nonunique_locii = 0
	nonunique_reads = 0
	for key in mapmult_lines.keys():
		nonunique_locii += mapmult_lines[key]
		nonunique_reads += mapmult_lines[key]/key
	avg_mapping_multiplicity = (nonunique_locii + uniquely_mapped)/(nonunique_reads + uniquely_mapped)


summary_dict['total_record_count'] = int(flagstat_lines[0].split(" ")[0])
summary_dict['properly_paired_count'] = int(flagstat_lines[0].split(" ")[0])
#summary_dict['avg_depth'] = sum([float(p.split('\t')[2]) for p in idxstat_lines ])/sum([int(q.split('\t')[1]) for q in idxstat_lines ])
summary_dict['spanned_breadth'] = float(span_lines[-1].split()[-1])
summary_dict['split_breadth'] = float(split_lines[-1].split()[-1])
summary_dict['avg_depth'] = float(dpth_lines[0].split("\t")[1])
summary_dict['std_depth'] = float(dpth_lines[1].split("\t")[1])

summary_dict['duplicate_reads'] = int(dupe_lines[-1].split(" ")[-1])
if args.mapping_multiplicity != None:
	summary_dict['uniquely_mapped'] = uniquely_mapped
	summary_dict['nonunique_locii'] = nonunique_locii
	summary_dict['nonunique_reads'] = nonunique_reads
	summary_dict['avg_mapping_multiplicity']=avg_mapping_multiplicity
summary_dict['singleton_count'] = int(flagstat_lines[13].split(" ")[0])
summary_dict['total_mapped_count'] = int(mapt_lines[0].split("\n")[0])




#summary_dict['total_read_count'] = int(flagstat_lines[0].split(" ")[0])



phial_out = open(args.flat_out,'w')

keys = ['total_record_count','total_mapped_count', 'properly_paired_count','avg_depth', 'std_depth', 'singleton_count', 'spanned_breadth', 'split_breadth', 'duplicate_reads']

lines2write = [ [k, summary_dict[k]] for k in keys]
if args.tag:
	[ ell.insert(0, args.tag) for ell in lines2write ]

for preline in lines2write:
	field_count = len(preline)
	line = ("%s" + "\t%s"*(field_count-1) + "\n") % tuple(preline)
	phial_out.write(line)

phial_out.close()



