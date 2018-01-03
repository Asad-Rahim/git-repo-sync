
repo_path="$1"

if [[ -f "$repo_path/.git/config" ]]; then
  exit
fi

mkdir -p "$repo_path"
cd "$repo_path"

git init


git config --local advice.pushUpdateRejected false
#git config --local core.logAllRefUpdates

git remote add $origin_1 "$url_1"
git remote add $origin_2 "$url_2"


echo Repo created at $repo_path









