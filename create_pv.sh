#!/bin/bash

PROGNAME=$(basename "${0}")

# Samples:
# ./create_pv.sh -f 1 -t 3 -s 5Gi -r /srv/nfs -S master.mg.local
USAGE="Usage: ${PROGNAME} [-h] [-a accessmodes] [-C cli] [-c storageclass] [-f from] [-n name] [-r root] [-S nfs-server] [-s size] [-t to]"
unset TO
unset STORAGECLASS

CLI="oc"
FROM="1"
unset NAME
SIZE="1Gi"
ACCESSMODE_ARG="ReadWriteOnce"
unset SERVER

VOLUME_TYPE="hostPath"
MOUNT_TYPE="type: DirectoryOrCreate"
MOUNT_ROOT="/mnt"

while getopts a:C:c:f:hn:r:S:s:t: c
do
	case $c in
	a) ACCESSMODE_ARG="${OPTARG}";;
	C) CLI="${OPTARG}";;
	c) STORAGECLASS="storageClassName: ${OPTARG}";;
	f) FROM="${OPTARG}";;
	h) echo "${USAGE}";exit 0;;
	n) NAME="${OPTARG}";;
	t) TO="${OPTARG}";;
	r) MOUNT_ROOT="${OPTARG}";;
	S) VOLUME_TYPE="nfs";MOUNT_TYPE="server: ${OPTARG}";;
	s) SIZE="${OPTARG}";;
	\?)	echo "${USAGE}"
		exit 2;;
	esac
done
shift $((OPTIND -1))

if [ -n "${NAME}" ];then
	if [ -n "${TO}" ];then
		echo "${PROGNAME}: \"-n\" option cannot be used with \"-t\" option"
		exit 2
	else
		FROM="1"
		TO="1"
	fi
elif [ -z "${TO}" ];then
	echo "\"-t\" option must be provided"
	echo "${USAGE}"
	exit 2
fi

ACCESSMODES="['${ACCESSMODE_ARG//,/\',\'}']"
for pv in $(seq "${FROM}" "${TO}");do
	if [ -n "${NAME}" ];then
		pvname="${NAME}"
	else
		pvname=$(printf "pv%03d" "${pv}")
	fi

	if ! ${CLI} create -f - <<EOF
apiVersion: "v1"
kind: PersistentVolume
metadata:
  name: ${pvname}
spec:
  ${STORAGECLASS}
  capacity:
    storage: ${SIZE}
  accessModes: ${ACCESSMODES}
  persistentVolumeReclaimPolicy: Recycle
  ${VOLUME_TYPE}:
# may need selinux enforcement disabled
    ${MOUNT_TYPE}
    path: "${MOUNT_ROOT}/${pvname}"
EOF
	then
		echo "${PROGNAME}: failed to create pv"
		exit 1
	fi
	if [ "${VOLUME_TYPE}" = "nfs" ];then
		# shellcheck disable=SC2029
		ssh root@"${MOUNT_TYPE/* /}" "mkdir -p ${MOUNT_ROOT}/${pvname} && chmod 777 ${MOUNT_ROOT}/${pvname} && chown nfsnobody:nfsnobody ${MOUNT_ROOT}/${pvname}"
	fi
	done
