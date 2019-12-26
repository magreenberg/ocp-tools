#!/bin/bash

PROGNAME=$(basename "$0")
USAGE="Usage: ${PROGNAME} [-p] -t tag"
unset PUSH
unset TAG

while getopts pt: c
do
	case $c in
	p)	PUSH="true";;
	t)	TAG=$OPTARG;;
	\?)	echo "${USAGE}"
		exit 2;;
	esac
done
shift $((OPTIND -1))

if [ -z "${TAG}" ];then
	echo "missing tag"
	echo "${USAGE}"
	exit 2
fi

for image in $(docker images | awk '!/^REPOSITORY/{print $1":"$2}');do
	if [[ ${image} =~ / ]];then
		NEWNAME=$(echo "$image" | sed "s/[^/]*/${TAG}/")
	else
		NEWNAME="${TAG}/${image}"
	fi
	docker tag "${image}" "${NEWNAME}"
	if [ -n "${PUSH}" ];then
		docker push "${NEWNAME}"
	fi
done
