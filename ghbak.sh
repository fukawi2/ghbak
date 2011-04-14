#!/bin/bash

# Copyright (c) 2011, Phillip Smith
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  - Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#  - Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#  - The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission from
#    the author.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

BACKUP_DIR='test-backups'
GITHUB_USER='fukawi2'
GITHUB_TOKEN=''	# Obtain your key from 'Account Settings' => 'Account Admin'
API_FORMAT='yaml'	# Do Not Change This

########################
# FUNCTIONS
########################

function warn() {
	local _msg="$*"
	[[ -z "$_msg" ]] && return 1
	echo "WARNING: $_msg" >&2
}

function bomb() {
	local _msg="$*"
	[[ -n "$_msg" ]] && echo "FATAL: $_msg" >&2
	exit 1
}

########################
# MAIN
########################

# Sanity Checks
[[ ! -d "$BACKUP_DIR" ]] && { mkdir -p $BACKUP_DIR || exit 1; }
absolute_backup_dir=$(cd $BACKUP_DIR && pwd)
[[ -z "$absolute_backup_dir" ]] && { echo "Failed to obtain absolute path for '$BACKUP_DIR'"; exit 1; }
[[ -z "$GITHUB_USER" ]]	&& bomb 'GitHub username not configured'
[[ -z "$GITHUB_TOKEN" ]]	&& warn 'User API Token not configured; Private Repositories will NOT be backed up'

# Fetch a list of repos for $GITHUB_USER
echo "Fetching list of repositories for user '$GITHUB_USER'"
github_uri="https://github.com/api/v2/$API_FORMAT/repos/show/${GITHUB_USER}"
repos=$(curl --silent -i $github_uri | grep -F ':name:' | awk '{ print $2 }')
# TODO: Login to list private repos
#github_auth="${GITHUB_USER}/token:${GITHUB_TOKEN}"
#repos=$(curl --silent -i -u $github_auth $github_uri | grep -F ':name:' | awk '{ print $2 }')

# TODO: Handle multiple pages of repos:
# X-Next: http://github.com/api/v2/yaml/repos/show/schacon?page=2
# X-Last: http://github.com/api/v2/yaml/repos/show/schacon?page=3

echo "Backup location is '$absolute_backup_dir/'"
echo "Found $(wc -w <<< $repos) repositories to backup"

# Loop through the found repos and 'clone' or 'fetch' as appropriate
#for r in $repos ; do
for repo_name in $repos ; do
	[[ -z "$repo_name" ]] && continue

	# We don't want backups in dotdirs (hidden)
	[[ ${repo_name:0:1} == '.' ]] && clone_name="${repo_name:1}" || clone_name="$repo_name"
	
	cd $absolute_backup_dir || exit 1
	if [[ ! -d "${clone_name}" ]] ; then
		# New Repo; Clone it
		echo "===> Found new repository '$repo_name'; Cloning to $clone_name/"
		git clone --mirror --quiet git://github.com/${GITHUB_USER}/${repo_name}.git $clone_name/
		# TODO: Clone private repos
		# git clone --mirror --quiet git@github.com:${GITHUB_USER}/${repo_name}.git $clone_name/
		[[ $? -ne 0 ]] && warn "Failed to clone '$repo_name' to '${clone_name}/'"
	else
		# Existing; Fetch changes
		echo "===> Fetching changes in existing backup for '$repo_name'"
		cd ${clone_name} && git fetch --quiet --all --prune
		[[ $? -ne 0 ]] && warn "Failed to fetch changes in '$repo_name' (Path: ${clone_name}/)"
	fi
done

exit 0
