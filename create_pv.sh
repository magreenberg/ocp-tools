#!/bin/bash

PROGNAME=$(basename "${0}")

USAGE="Usage: ${PROGNAME} [-h] [-a accessmodes] [-C cli] [-c storageclass] [-f from] [-n name] [-s size] [-t to]"
unset TO
unset STORAGECLASS

CLI="oc"
FROM="1"
unset NAME
SIZE="1Gi"
ACCESSMODE_ARG="ReadWriteOnce"

while getopts a:C:c:f:hn:t:s: c
do
	case $c in
	a) ACCESSMODE_ARG=${OPTARG};;
	C) CLI=${OPTARG};;
	c) STORAGECLASS="storageClassName: ${OPTARG}";;
	f) FROM=${OPTARG};;
	h) echo "${USAGE}";exit 0;;
	n) NAME=${OPTARG};;
	t) TO=${OPTARG};;
	s) SIZE=${OPTARG};;
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
  hostPath:
# may need selinux enforcement disabled
    type: DirectoryOrCreate
    path: "/mnt/${pvname}"
EOF
	then
		echo "${PROGNAME}: failed to create pv"
		exit 1
	fi
done
