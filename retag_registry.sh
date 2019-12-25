#!/bin/bash

if [ $# -ne 1 ];then
	echo "Usage: $(basename $0) tag"
	exit 2
fi

for image in $(docker images | awk '!/^REPOSITORY/{print $1":"$2}');do
	if [[ ${image} =~ / ]];then
		docker tag ${image} $(echo $image | sed "s/[^/]*/$1/")
	else
		docker tag ${image} $(echo $1/$image)
	fi
done
