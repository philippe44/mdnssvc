#!/bin/bash

list="x86_64-linux-gnu-gcc i686-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc"
declare -A alias=( [i686-linux-gnu-gcc]=x86-linux-gnu-gcc )

IFS= read -ra compilers <<< "$list"

# do we have "clean" somewhere in parameters (assuming no compiler has "clean" in it...
if [[ $@[*]} =~ clean ]]; then
	clean="clean"
fi	

# first select platforms/compilers
for cc in ${compilers[@]}
do
	# check compiler first
	if ! command -v $cc &> /dev/null; then
		compilers=( "${compilers[@]/$cc}" )	
		continue
	fi

	# then loop through args to see if candidates should be kept
	if [[ $# > 1 || ($# == 1 && -z $clean) ]]; then
		for arg in $@
		do
			if [[ ${alias[$cc]:-$cc} =~ $arg ]]; then 
				found=y
			fi
		done
		if [[ -z $found ]]; then
			compilers=( "${compilers[@]/$cc}" )
		fi
			unset found			
	fi		
done

# then do the work
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< ${alias[$cc]:-$cc}

	make CC=$cc PLATFORM=$platform $clean
	if [[ -n $clean ]]; then
		continue
	fi
	
	mkdir -p targets/$host/$platform
	cp lib/$platform/tinysvcmdns.a $_
done
