#!/bin/bash

PROGNAME=$(basename $0)
USAGE="Usage: ${PROGNAME} -b backupdir"

unset IMAGESTREAMS
unset TEMPLATES
unset IMAGESTREAMTAGS

while getopts b:its c
do
	case $c in
	b)	BACKUPDIR=$OPTARG;;
	i)	IMAGESTREAMS="true";;
	t)	TEMPLATES="true";;
	s)	IMAGESTREAMTAGS="true";;
	\?)	echo "${USAGE}"
		exit 2;;
	esac
done
shift `expr $OPTIND - 1`

if [ -z "${BACKUPDIR}" ];then
	echo "missing backupdir"
	echo "${USAGE}"
	exit 2
fi

if [ -z "${IMAGESTREAMS}" -a -z "${TEMPLATES}" -a -z "${IMAGESTREAMTAGS}" ];then
	IMAGESTREAMS="true"
	TEMPLATES="true"
	IMAGESTREAMTAGS="true"
fi


oc project openshift
if [ $? -ne 0 ];then
	echo "${PROGNAME}: unable to set project to \"openshift\""
	exit 1
fi

rm -rf ${BACKUPDIR}
mkdir ${BACKUPDIR}
if [ $? -ne 0 ];then
	echo "${PROGNAME}: unable to create directory ${BACKUPDIR}"
	exit 1
fi

if [ "${TEMPLATES}" = "true" ];then
	# backup all Templates
	for template in $(oc get templates | awk '!/^NAME /{print $1}');do
		echo "=== template: ${template} ==="
		oc get template ${template} -o yaml > ${BACKUPDIR}/${template}.template.yaml
	done
fi

if [ "${IMAGESTREAMS}" = "true" ];then
	# backup all ImageStreams
	for is in $(oc get is | awk '!/^NAME /{print $1}');do
		echo "=== imagestream: ${is} ==="
		oc get is/${is} -o yaml > ${BACKUPDIR}/${is}.imagestream.yaml
	done
fi

if [ "${IMAGESTREAMTAGS}" = "true" ];then
	# backup ImageStreamTags
	for ist in $(oc get imagestreamtags | awk '!/^NAME /{print $1}');do
		echo "=== imagestreamtag: ${ist} ==="
		oc get imagestreamtag/${ist} -o yaml > ${BACKUPDIR}/${ist}.imagestreamtag.yaml
	done
fi
