#!/bin/bash

PROGNAME=$(basename "${0}")

USAGE="Usage: ${PROGNAME} [-h] [-C cli] [-c storageclass] [-f from] [-t to] [-s size]"
unset TO

CLI="oc"
FROM="1"
SIZE="1Gi"
STORAGECLASS="manual"

while getopts C:c:f:ht:s: c
do
	case $c in
	C) CLI=${OPTARG};;
	c) STORAGECLASS=${OPTARG};;
	f) FROM=${OPTARG};;
	h) echo "${USAGE}";exit 0;;
	t) TO=${OPTARG};;
	s) SIZE=${OPTARG};;
	\?)	echo "${USAGE}"
		exit 2;;
	esac
done
shift $((OPTIND -1))

for pv in $(seq "${FROM}" "${TO}");do
	pvname=$(printf "pv%03d" "${pv}")

	${CLI} create -f - <<EOF
apiVersion: "v1"
kind: PersistentVolume
metadata:
  name: ${pvname}
spec:
  storageClassName: ${STORAGECLASS}
  capacity:
    storage: ${SIZE}
  accessModes:
  - ReadWriteOnce
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Recycle
  hostPath:
# may need selinux enforcement disabled
    type: DirectoryOrCreate
    path: "/mnt/${pvname}"
EOF
done
