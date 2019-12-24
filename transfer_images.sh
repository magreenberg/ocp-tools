#!/bin/bash

TAR_SUFFIX=".tar"

unset DOWNLOAD
unset RETAIN
unset TAG
unset UNBUNDLE
unset IMAGELIST
unset IMAGE
USTMPDIR="/tmp"

USAGE="Usage: $(basename $0) [-hr] [-l imagelist | -i image] [-d bundle.tar] [-t newtag] [-p tmpdir] [-u unbundle.tar]"
HELP="
-d bundle.tar - download container images and bundle them in a single tar file\n
-h - help\n
-i image - name of image to download\n
-l imagelist - name of file that contains the list of images to download\n
-p tmpdir\n
-t newtag - retag images\n
-u unbundle.tar - unbundle tar and load in container registry
"

while getopts d:hi:l:p:rt:u: c
do
	case $c in
	d) DOWNLOAD=${OPTARG};;
	h) echo ${USAGE};echo -e ${HELP};exit 0;;
	i) IMAGE=${OPTARG};;
	l) IMAGELIST=${OPTARG};;
	r) RETAIN="true";;
	p) USTMPDIR=${OPTARG};;
	t) TAG=${OPTARG};;
	u) UNBUNDLE=${OPTARG};;
	\?)	echo "${USAGE}"
		exit 2;;
	esac
done
shift `expr $OPTIND - 1`

if [ -n "${TAG}" -a -z "${UNBUNDLE}" ];then
	echo "\"-t\" option cannot be used with \"-u\" option"
	exit 2
elif [ -n "${IMAGE}" -a -n "${IMAGELIST}" ];then
	echo "\"-i\" option cannot be used with \"-l\" option"
	echo "${USAGE}"
	exit 2
elif [ -z "${DOWNLOAD}" -a -z "${UNBUNDLE}" ];then
	echo "\"-d\" or \"-u\" option must be used"
	echo "${USAGE}"
	exit 2
elif [ -n "${DOWNLOAD}" -a -z "${IMAGE}" -a -z "${IMAGELIST}" ];then
	echo "\"-i\" or \"-l\" option must be used"
	echo "${USAGE}"
	exit 2
fi

if [ -n "${IMAGE}" ];then
	NEEDED_IMAGES="${IMAGE}"
elif [ -n "${IMAGELIST}" ];then
	if [ ! -f "${IMAGELIST}" ];then
		echo "$(basename $0): ${IMAGELIST} file does not exits"
		exit 1
	fi
	NEEDED_IMAGES="$(grep -v "^#" ${IMAGELIST})"
fi

if [ -n "${DOWNLOAD}" ];then
	TMPDIR=$(mktemp -p ${USTMPDIR} -d --suffix=update_image)
	for image in ${NEEDED_IMAGES};do
		docker pull ${image}
		if [ $? -ne 0 ];then
			echo "Unable to download ${image}"
			rm -rf ${TMPDIR}
			exit 1
		fi
		docker save ${image} > ${TMPDIR}/$(echo ${image} | sed -e "s@/@_SLASH_@g" -e "s@\.@_DOT_@g")${TAR_SUFFIX}
		if [ $? -ne 0 ];then
			echo "Unable to save ${image}"
			rm -rf ${TMPDIR}
			exit 1
		fi
	done
	tar -C ${TMPDIR} -cf ${DOWNLOAD} .
	if [ $? -ne 0 ];then
		echo "Unable to create ${DOWNLOAD}"
		rm -rf ${TMPDIR}
		exit 1
	fi
	if [ -z "${RETAIN}" ];then
		for image in ${NEEDED_IMAGES};do
			[[ ${image} =~ ^#.* ]] && continue
			docker rmi ${image}
		done
	fi
elif [ -n "${UNBUNDLE}" ];then
	TMPDIR=$(mktemp -d --suffix=update_image)
	tar -C ${TMPDIR} -xf ${UNBUNDLE}
	cd ${TMPDIR}
	for i in *;do
		docker load < $i
	done
	if [ -n "${TAG}" ];then
		for i in *;do
			ORIGNAME=$(echo $i | sed -e "s@_SLASH_@/@g" -e "s@_DOT_@\.@g" -e "s@${TAR_SUFFIX}\$@@")
			docker tag ${ORIGNAME} $(echo ${ORIGNAME} | sed "s@[^/]*@${TAG}@")
			if [ -z "${RETAIN}" ];then
				docker rmi ${ORIGNAME}
			fi
		done
	fi
fi
rm -rf ${TMPDIR}
