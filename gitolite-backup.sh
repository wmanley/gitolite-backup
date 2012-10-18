gitolite_login=gitolite@git-dev.dev.youview.co.uk

list_repos() {
	ssh "$1" info 2>/dev/null | grep -P '\t' | cut -f2
}

create_repo() {
	mkdir -p "repos/$2" &&
	cd "repos/$2" &&
	git init --bare &&
	git remote add origin "$1:$2"
}

update_repo() {
	cd "repos/$repo" &&
	git fetch origin --prune &&
	git gc --auto
}

backup_repo() {
	cd "repos/$repo" &&
	git for-each-ref refs/remotes/origin --format='%(refname)' | while read ref
	do
		refname="${ref##refs/remotes/origin/}"
		echo git update-ref "refs/backup/$3/$refname" "$ref"
		git update-ref "refs/backup/$3/$refname" "$ref"
	done
	git pack-refs --all
}

# We run this twice to make it closer to a snapshot.  The first one may take
# some time but the second one should be very quick.  Really the way to
# guarantee a snapshot would be to run it in a loop and when we go through two
# iterations pulling down no changes we know it is a true snapshot.
for i in $(seq 2);
do
	list_repos "$gitolite_login" | while read repo
	do
		if [ ! -d "$repo" ]; then
			echo "Found new repo $repo"
			( create_repo "$gitolite_login" "$repo" )
		fi
		( update_repo "$gitolite_login" "$repo" )
	done
done

# TODO: Make the following safe even if we are interuppted by SIGINT, SIGTERM,
# etc.
date=$(date +%F)

if [ "$date" == "$(<last_backup)" ]
then
	echo "Have already done a backup today, exiting"
	exit 1
fi

echo "$date" > last_backup

ls repos/ | while read repo
do
	( backup_repo "$gitolite_login" "$repo" "$date" )
done

