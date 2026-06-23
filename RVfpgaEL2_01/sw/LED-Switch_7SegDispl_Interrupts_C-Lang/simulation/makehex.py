# Based on free software.
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#2023 Oct Alex Grinshpun modifications
#Provided AS IS without WARRANTIES of any kind nor explicit neither implied
import sys
import os
from os.path import join
import xml.etree.ElementTree as ET
import time


 
if (len(sys.argv) < 4 ): 
    print ("Usage: makehex.py <Location of SEGGER emProject file> <location of compiled bin file> <location of Programming Source files dir>")
    sys.exit()
    
ProjectPath = sys.argv[1] # Location of emProject
BinFilePath = sys.argv[2] #"..\Output\Debug\Exe" Path to compiled dir containing bin file
SourceFilePath = sys.argv[3] #"..\Source" Path to SW source dir

#Lets locate SEGGER ES project file *.emProject
for item in os.scandir(ProjectPath):
    #print (item.name)
    # extract the file name and extension
    split_tup = os.path.splitext(item.name)
    file_name = split_tup[0]
    file_extension = split_tup[1]
    if (file_extension == ".emProject"):
        ProjectFile = ProjectPath + item.name
        print ("item name", item)
        
from datetime import datetime, timedelta        
#ProjectFileIsExist = os.path.exists(ProjectFile)
#if (not ProjectFileIsExist):
#    print ("Project file doesnt exist. exiting")
#    sys.exit()

# Lets find project name in SEGGER ES emProject file.  There should be only one project. The name of binary is ProjectName.bin
# Check that bin file exists and its timestape, later on be checked to SW Source files timestamp. Assuming bin file shall be younger then Source -> its compiled               
BinFile = []
with open(ProjectFile, 'r') as file:
    tree = ET.parse(ProjectFile)
    root = tree.getroot() 
    for child in root:
        if (child.tag == "project"):
            print(child.tag, child.attrib) 
            print("bin file name",child.attrib['Name'])
            BinFile = child.attrib['Name']
            BinFileFullNamePath = BinFilePath + "\\" + BinFile + ".bin"
            print ("bin file name", BinFileFullNamePath )
            BinIsExist = os.path.exists(BinFileFullNamePath)
            if (BinIsExist):
                BinFileTimeStamp = os.path.getmtime(BinFileFullNamePath)
                print ("Binfile timestamp", BinFileTimeStamp)
            else:
                print ("Binfile doesnt exist. Compile the SW in SEGGER ES")
                sys.exit(1)
print("*****************") 
local_time = datetime.fromtimestamp(BinFileTimeStamp) 
print("BinFileTimeStamp Date (Local time):", local_time)


#Lets check SW Source files time, assuming ALL files *.c,*h, *.S, *.s are in the same dir and picking youngest timestamp
source_time_list=[]  
ff =[]  
for item in os.scandir(SourceFilePath):
    print (item.name)
    # extract the file name and extension
    split_tup = os.path.splitext(item.name)
    file_name = split_tup[0]
    file_extension = split_tup[1]
    print("File Name: ", file_name)
    print("File Extension: ", file_extension)
    if (file_extension == ".c" or file_extension == ".h" or file_extension == ".S" or file_extension == ".s"):
        print ("add and sort", item.name)
        ff.append(item)
        source_time_list.append(int(item.stat().st_mtime))
        #source_time_list.append(os.path.getctime(item)
        SourceFilesOldestTimeStamp = max(source_time_list)
        print(item.name, item.path, item.stat().st_size, item.stat().st_ctime)
        file_mod_time = datetime.fromtimestamp(os.stat(item.path).st_ctime) 
print("*****************")        
print("SourceFilesOldestTimeStamp:",SourceFilesOldestTimeStamp)
print("source_time_list:",ff )

print("SourceFilesOldestTimeStamp Date (Local time):", file_mod_time)
#*************************************************************************
# Now checking if SW was compiled, bin file is "younger" then source file
#************************************************************************* 
if (SourceFilesOldestTimeStamp > BinFileTimeStamp):
    print("Exiting run SEGGER BUILD FIRST")
    sys.exit(1)

#******************************************************************
# Create .vh file from .bin fileutf-8
# Assumption: SW name match the Project  name
#******************************************************************

vhFile = BinFile + ".vh"
print ("vhFile ===> ",vhFile)

outputfile = open(vhFile, 'w', encoding='utf-8')   # File will be written in UTF-8
vhFileNamefile = open("vhFileName", 'w', encoding='utf-8')   # File will be written in UTF-8
vhFileNamefile.write(vhFile)
vhFileNamefile.close

with open(BinFileFullNamePath, "rb") as f:
    cnt = 7
    s = ["00"]*8
    while True:
        data = f.read(1)
        if not data:
            WriteData = ''.join(s)
            outputfile.write(WriteData)
            outputfile.write("\n")
            exit(0)
        s[cnt] = "{:02X}".format(data[0])
        if cnt == 0:
            WriteData = ''.join(s)
            outputfile.write(WriteData)
            outputfile.write("\n")
            s = ["00"]*8
            cnt = 8
        cnt -= 1


f.close	
outputfile.close

