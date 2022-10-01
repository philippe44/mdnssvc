#!/bin/bash

list="x86_64-linux-gnu-gcc i686-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc"
declare -A alias=( [i686-linux-gnu-gcc]=x86-linux-gnu-gcc )
declare -a selected

IFS= read -ra offered <<< "$list"

# first check if it's just cleaning
for arg in $@
do
	if [ $arg == "clean" ]; then
		clean="clean"
	else 
		for cc in ${offered[@]}
		do
			if [[ ${alias[$cc]:-$cc} == *$arg* ]]; then 
				selected+=($cc)
			fi
		done
	fi	
done

selected=${selected:=$offered}

# then iterate selected platforms/compiler
for cc in ${selected[@]}
do
	if ! command -v $cc &> /dev/null; then
		echo $cc is not available
		continue
	fi	
	
	IFS=- read -r platform os dummy <<< ${alias[$cc]:-$cc}

	make CC=$cc PLATFORM=$platform $clean
	if [ $clean ]; then
		continue
	fi
	
	mkdir -p targets/$os/$platform
	cp lib/$platform/tinysvcmdns.a $_
done
