import os, zipfile

parseScript = open("xvlog-parse-ip.prj", "w")
srcDir = "ip"

for f in os.listdir(srcDir):
    if f.endswith(".v"):
        parseScript.write("sv xil_defaultlib " + srcDir + "/" + f + "\n")

parseScript.close()