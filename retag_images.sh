#!/bin/bash

PROGNAME=$(basename "$0")
USAGE="Usage: ${PROGNAME} [-pg] [-l imagelist] -t tag"
unset PUSH
unset TAG
unset GREEDY
unset IMAGELIST

while getopts gl:pt: c
do
	case $c in
	g)	GREEDY="true";;
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

if [ -n "${IMAGELIST}" ];then
	if [ ! -f "${IMAGELIST}" ];then
		echo "${PROGNAME}: unable to find ${IMAGELIST}"
		exit 1
	fi
	IMAGES=$(cat "${IMAGELIST}")
else
	IMAGES=$(docker images | awk '!/^REPOSITORY/{print $1":"$2}')
fi
for image in ${IMAGES};do
	if [[ ${image} =~ / ]];then
		if [ -n "${GREEDY}" ];then
			NEWNAME=${image/*\//${TAG}/}
		else
			NEWNAME=$(echo "$image" | sed "s/[^/]*/${TAG}/")
		fi
	else
		NEWNAME="${TAG}/${image}"
	fi
	docker tag "${image}" "${NEWNAME}"
	if [ -n "${PUSH}" ];then
		docker push "${NEWNAME}"
	fi
done
