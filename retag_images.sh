#!/bin/bash

PROGNAME=$(basename "$0")
USAGE="Usage: ${PROGNAME} [-p] [-l imagelist] -t tag"
unset PUSH
unset TAG
unset IMAGELIST

while getopts l:pt: c
do
	case $c in
	l)	IMAGELIST=$OPTARG;;
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

if [ -z "${IMAGELIST}" ];then
	IMAGELIST=$(docker images | awk '!/^REPOSITORY/{print $1":"$2}')
fi
for image in ${IMAGELIST};do
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
