import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-i", "--kraken_in", help="kraken results to extract mycoplasmatota from")

args = parser.parse_args()

kraken_in = args.kraken_in

lions = []
phial_in = open(kraken_in, "r")
lions = [ lion.strip().split("\t") for lion in phial_in.readlines()]
for l in lions:
    l[-1]=l[-1].strip()

not_yeti = False

while not not_yeti:
    lion = lions.pop(0)
    if lion[-1] == "Mycoplasmatota":
        not_yeti = True

mycoplasmatotoa = []

while not_yeti:
    lion = lions.pop(0)
    #print(lion)
    if lion[3].startswith("S"):
        #print(lion)
        mycoplasmatotoa.append(lion)
    elif lion[3].startswith("P"):
        not_yeti = False


for myco in mycoplasmatotoa:
    print("%s   %s  %s" % (myco[0], myco[4], myco[5],))
