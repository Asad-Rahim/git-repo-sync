set -euf +x -o pipefail

echo Start `basename "$BASH_SOURCE"`



if [[ -f "$path_sync_repo/.git/config" ]]; then
  exit
fi


function delete_project_repo_and_exit() {
    echo Deletion of "$path_sync_repo" to allow restart git-cred initializing.
    rm -rf "$path_sync_repo"
    
    echo Interruption on error.
    
    exit 1
}


mkdir -p "$path_sync_repo"
cd "$path_sync_repo"

git init

git config --local advice.pushUpdateRejected false
#git config --local core.logAllRefUpdates

git remote add $origin_1 "$url_1"
git remote add $origin_2 "$url_2"


[[ "$use_bash_git_credential_helper" == "1" ]] && {
  echo Initializing git-cred as use_bash_git_credential_helper is set to $use_bash_git_credential_helper

  if [[ ! -f "$git_cred" ]]; then
    echo Error! Exit! You have to update/download Git-submodules of git-sync project to use $git_cred
    echo Or delete "use_bash_git_credential_helper=1" from your sync project settings file.
    
    delete_project_repo_and_exit
  fi
  
  GIT_CRED_DO_NOT_EXIT=1
  
  source "$git_cred"  init  repo_1  $url_1
  [[ $GIT_CRED_FAILED ]] && delete_project_repo_and_exit
  
  source "$git_cred"  init  repo_2  $url_2
  [[ $GIT_CRED_FAILED ]] && delete_project_repo_and_exit
}


echo Repo created at $path_sync_repo


echo End `basename "$BASH_SOURCE"`






