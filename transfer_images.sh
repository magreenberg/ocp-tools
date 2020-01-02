#!/bin/bash

PROGNAME=$(basename "$0")
TAR_SUFFIX=".tar"

unset DOWNLOAD
unset GREEDY
unset IMAGELIST
unset IMAGE
unset PUSH
unset RETAIN
unset SPACE
unset TAG
unset TMPDIR
unset UNBUNDLE
USTMPDIR="/tmp"

USAGE="Usage: ${PROGNAME} [-ghprs] [-l imagelist | -i image] [-d bundle.tar] [-m tmpdir] [-t newtag] [-u unbundle.tar]"
HELP="
-d bundle.tar - download container images and bundle them in a single tar file
-g - greedy tag name
-h - help
-i image - name of image to download
-l imagelist - name of file that contains the list of images to download
-m tmpdir
-p - push
-s - optimize for space over time
-t newtag - retag images
-u unbundle.tar - unbundle tar and load in container registry
"

clean_exit() {
	if [ -n "${TMPDIR}" ] && [ -d "${TMPDIR}" ];then
		rm -rf "${TMPDIR}"
	fi
}

get_tmpdir() {
	mktemp -p "${USTMPDIR}" -d --suffix="_${PROGNAME}"
}

get_tag() {
	local NEWTAGNAME
	if [ -n "${GREEDY}" ];then
		NEWTAGNAME=${image/*\//${TAG}/}
	else
		NEWTAGNAME=$(echo "$image" | sed "s/[^/]*/${TAG}/")
	fi
	echo "${NEWTAGNAME}"
}

get_fs_agnostic_name() {
	echo "$1" | sed -e "s@/@_SLASH_@g" -e "s@\.@_DOT_@g" -e "s@:@_COLON_@g"
}

unget_fs_agnostic_name() {
	echo "$1" | sed -e "s@_SLASH_@/@g" -e "s@_DOT_@\.@g" -e "s@_COLON_@:@g"
}

while getopts d:ghi:l:m:psrt:u: c
do
	case $c in
	d) DOWNLOAD=${OPTARG};;
	g) GREEDY="true";;
	h) echo "${USAGE}";echo -e "${HELP}";exit 0;;
	i) IMAGE=${OPTARG};;
	l) IMAGELIST=${OPTARG};;
	m) USTMPDIR=${OPTARG};;
	p) PUSH="true";;
	r) RETAIN="true";;
	s) SPACE="true";;
	t) TAG=${OPTARG};;
	u) UNBUNDLE=${OPTARG};;
	\?)	echo "${USAGE}"
		exit 2;;
	esac
done
shift $((OPTIND -1))

if [ -n "${IMAGE}" ] && [ -n "${IMAGELIST}" ];then
	echo "\"-i\" option cannot be used with \"-l\" option"
	echo "${USAGE}"
	exit 2
elif [ -z "${DOWNLOAD}" ] && [ -z "${UNBUNDLE}" ];then
	echo "\"-d\" or \"-u\" option must be used"
	echo "${USAGE}"
	exit 2
elif [ -n "${DOWNLOAD}" ] && [ -z "${IMAGE}" ] && [ -z "${IMAGELIST}" ];then
	echo "\"-i\" or \"-l\" option must be used"
	echo "${USAGE}"
	exit 2
fi

if [ -n "${IMAGE}" ];then
	NEEDED_IMAGES="${IMAGE}"
elif [ -n "${IMAGELIST}" ];then
	if [ ! -f "${IMAGELIST}" ];then
		echo "${PROGNAME}: ${IMAGELIST} file does not exits"
		exit 1
	fi
	NEEDED_IMAGES="$(grep -v "^#" "${IMAGELIST}")"
fi

trap clean_exit INT

if [ -n "${DOWNLOAD}" ];then
	TMPDIR=$(get_tmpdir)
	for image in ${NEEDED_IMAGES};do
		if ! docker pull "${image}"
		then
			echo "Unable to download ${image}"
			rm -rf "${TMPDIR}"
			exit 1
		fi
		if [ -n "${TAG}" ];then
			IMAGENAME=$(get_tag "${image}")
			docker tag "${image}" "${IMAGENAME}"
		else
			IMAGENAME="${image}"
		fi
		if ! docker save "${IMAGENAME}" > "${TMPDIR}/$(get_fs_agnostic_name "${IMAGENAME}")${TAR_SUFFIX}"
		then
			echo "Unable to save ${image}"
			rm -rf "${TMPDIR}"
			exit 1
		fi
		if [ -z "${RETAIN}" ] && [ -n "${SPACE}" ];then
			docker rmi "${image}"
			if [ "${image}" != "${IMAGENAME}" ];then
				docker rmi "${IMAGENAME}"
			fi
		fi
	done
	if ! tar -C "${TMPDIR}" -cf "${DOWNLOAD}" .
	then
		echo "Unable to create ${DOWNLOAD}"
		rm -rf "${TMPDIR}"
		exit 1
	fi
	if [ -z "${RETAIN}" ] && [ -z "${SPACE}" ];then
		for image in ${NEEDED_IMAGES};do
			[[ ${image} =~ ^#.* ]] && continue
			docker rmi "${image}"
			IMAGENAME=$(get_tag "${image}")
			if [ "${image}" != "${IMAGENAME}" ];then
				docker rmi "${IMAGENAME}"
			fi
		done
	fi
elif [ -n "${UNBUNDLE}" ];then
	TMPDIR=$(get_tmpdir)
	tar -C "${TMPDIR}" -xf "${UNBUNDLE}"
	cd "${TMPDIR}" || (echo "${PROGNAME}: cd ${TMPDIR} failed";exit 1)
	for i in *;do
		LOADED_IMAGENAME=$(docker load < "${i}" | awk '/Loaded image:/{print $3}')
		if [ -z "${LOADED_IMAGENAME}" ];then
			echo "${PROGNAME}: failed to load ${i}"
			exit 1
		fi
		if [ -n "${TAG}" ];then
			IMAGENAME=$(get_tag "${LOADED_IMAGENAME}")
			docker tag "${LOADED_IMAGENAME}" "${IMAGENAME}"
			docker rmi "${LOADED_IMAGENAME}"
		else
			IMAGENAME="${LOADED_IMAGENAME}"
		fi
		if [ -n "${PUSH}" ];then
			docker push "${IMAGENAME}"
		fi
	done
fi
rm -rf "${TMPDIR}"
