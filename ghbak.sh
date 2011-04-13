#!/bin/bash

BACKUP_DIR='test-backups'
GITHUB_USER='fukawi2'
API_FORMAT='yaml'

[[ ! -d "$BACKUP_DIR" ]] && { mkdir -p $BACKUP_DIR || exit 1; }
absolute_backup_dir=$(cd $BACKUP_DIR && pwd)
[[ -z "$absolute_backup_dir" ]] && { echo "Failed to obtain absolute path for '$BACKUP_DIR'"; exit 1; }

repos=$(curl --silent -i http://github.com/api/v2/$API_FORMAT/repos/show/${GITHUB_USER} | grep -F ':name:')

# TODO: Handle multiple pages of repos:
# X-Next: http://github.com/api/v2/yaml/repos/show/schacon?page=2
# X-Last: http://github.com/api/v2/yaml/repos/show/schacon?page=3

for r in $repos ; do
	repo_name=${r##*:}
	[[ -z "$repo_name" ]] && continue

	clone_name="$repo_name"
	[[ ${repo_name:0:1} == '.' ]] && clone_name="${repo_name:1}"
	
	cd $absolute_backup_dir || exit 1
	if [[ ! -d "${clone_name}" ]] ; then
		# New Repo; Clone it
		echo "===> Found new repository '$repo_name'; Cloning to $absolute_backup_dir/$clone_name"
		git clone --mirror --quiet git://github.com/${GITHUB_USER}/${repo_name}.git $clone_name
	else
		# Existing; Pull Update
		echo "===> Fetching changes in existing backup for '$repo_name'"
		cd ${clone_name}.git && git fetch --quiet --all --prune
	fi
done

exit 0
