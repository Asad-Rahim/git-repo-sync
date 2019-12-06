set -euf +x -o pipefail

#echo
#echo Start `basename $0`

invoke_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$invoke_path/util/set_env.sh" "$@"



echo
source "$path_git_sync_util/repo_create.sh"
cd "$path_sync_repo"


rm -f "$env_notify_del_file"
rm -f "$env_notify_solving_file"

source "$path_git_sync_util/restore-after-crash.sh"

echo
if [[ ! -f "$env_modifications_signal_file" ]]; then
  source "$path_git_sync_util/change_detector.sh"

  if (( $changes_detected != 1 )); then
    echo '@' RESULT: Refs are the same. Exit.
    echo
    
    # !!! EXIT !!!
    exit
  fi
else
  echo '@' RESULT: Synchronization requested.
  
  remote_refs_1=$(<"$env_modifications_signal_file_1")
  remote_refs_2=$(<"$env_modifications_signal_file_2")
  
  rm -f "$env_modifications_signal_file"
  rm -f "$env_modifications_signal_file_1"
  rm -f "$env_modifications_signal_file_2"
fi


track_refs_1=$(git for-each-ref --format="%(objectname) %(refname)" "refs/remotes/$origin_1/")
track_refs_2=$(git for-each-ref --format="%(objectname) %(refname)" "refs/remotes/$origin_2/")

if(( 1 == 2 )); then
  echo
  echo remote_refs_1=
  echo "$remote_refs_1"

  echo remote_refs_2=
  echo "$remote_refs_2"

  echo track_refs_1=
  echo "$track_refs_1"

  echo track_refs_2=
  echo "$track_refs_2"
fi;

# The way we receive data from gawk we can't use new line char in the output. So we are using a substitution.
env_awk_newline_substitution='|||||'

state_to_refspec='state_to_refspec.gawk'
refspecs=$(awk \
  --file="$path_git_sync_util/$state_to_refspec" \
  `# --lint` \
  --assign must_exist_branch=$must_exist_branch \
  --assign origin_a="$origin_1" \
  --assign origin_b="$origin_2" \
  --assign prefix_a="$prefix_1" \
  --assign prefix_b="$prefix_2" \
  --assign prefix_victims="$prefix_victims" \
  --assign newline_substitution="$env_awk_newline_substitution" \
  --assign trace_on=1 \
  <(echo "$remote_refs_1") \
  <(echo "$remote_refs_2") \
  <(echo "$track_refs_1") \
  <(echo "$track_refs_2") \
)

# echo "$refspecs"
# exit;

mapfile -t refspec_list < <(echo "$refspecs")

del_spec="${refspec_list[0]}";
fetch_spec1="${refspec_list[1]}";
fetch_spec2="${refspec_list[2]}";
ff_vs_nff_push_data_1="${refspec_list[3]//$env_awk_newline_substitution/$'\n'}";
ff_vs_nff_push_data_2="${refspec_list[4]//$env_awk_newline_substitution/$'\n'}";
victim_data="${refspec_list[5]//$env_awk_newline_substitution/$'\n'}";
push_spec1="${refspec_list[6]}";
push_spec2="${refspec_list[7]}";
post_fetch_spec1="${refspec_list[8]}";
post_fetch_spec2="${refspec_list[9]}";
notify_del="${refspec_list[10]//$env_awk_newline_substitution/$'\n'}";
notify_solving="${refspec_list[11]//$env_awk_newline_substitution/$'\n'}";
end_of_results="${refspec_list[12]}";

end_of_results_expected='{[end-of-results]}';
# This comparison must have double quotes on the second operand. Otherwise it doesn't work.
if [[ $end_of_results != "$end_of_results_expected" ]]; then
  echo '@' ERROR: An unexpected internal processing results end. Exit.
  echo
  
  # !!! EXIT !!!
  exit 2002;
fi;

# echo "$ff_vs_nff_push_data_1"
# echo
# echo "$ff_vs_nff_push_data_2"
# exit;


mkdir -p "$path_async_output"

if [[ -n "$del_spec" ]]; then
  echo $'\n>' Delete branches
  #echo $del_spec
  git branch --delete --force --remotes $del_spec
fi;


if [[ $env_allow_async == 1 && -n "$fetch_spec1" && -n "$fetch_spec2" ]]; then
  echo $'\n>' Fetch Async

  git fetch --no-tags $origin_1 $fetch_spec1 > "$path_async_output/fetch1.txt" &
  pid_fetch1=$!
  git fetch --no-tags $origin_2 $fetch_spec2 > "$path_async_output/fetch2.txt" &
  pid_fetch2=$!
  
  fetch_report1="> Fetch $origin_1 "
  wait $pid_fetch1 && fetch_report1+="(async success)" || fetch_report1+="(async failure)"
  fetch_report2+="> Fetch $origin_2 "
  wait $pid_fetch2 && fetch_report2+="(async success)" || fetch_report2+="(async failure)"
  
  echo $fetch_report1
  echo $fetch_spec1
  cat < "$path_async_output/fetch1.txt"

  echo $fetch_report2
  echo $fetch_spec2
  cat < "$path_async_output/fetch2.txt"
else
  if [[ -n "$fetch_spec1" ]]; then
    echo $'\n>' Fetch $origin_1
    echo $fetch_spec1
    git fetch --no-tags $origin_1 $fetch_spec1
  fi;
  if [[ -n "$fetch_spec2" ]]; then
    echo $'\n>' Fetch $origin_2
    echo $fetch_spec2
    git fetch --no-tags $origin_2 $fetch_spec2
  fi;
fi;



victim_refspecs=$(awk \
  --file="$path_git_sync_util/select_refspec_after_fetching.gawk" \
  `# --lint` \
  --assign origin_1="$origin_1" \
  --assign origin_2="$origin_2" \
  --assign trace_on=1 \
  <(echo "$ff_vs_nff_push_data_1") \
  <(echo "$ff_vs_nff_push_data_2") \
  <(echo "$victim_data") \
)

mapfile -t victim_refspec_list < <(echo "$victim_refspecs")

push_victim_spec1="${victim_refspec_list[1]}";
push_victim_spec2="${victim_refspec_list[2]}";

push_spec1="$push_spec1$push_victim_spec1"
push_spec2="$push_spec2$push_victim_spec2"



if [[ -n "$notify_del" ]]; then
  echo $'\n>' Notify Deletion

  install -D /dev/null "$env_notify_del_file"
  
  echo > "$env_notify_del_file"
  echo "$notify_del" >> "$env_notify_del_file"
fi;
if [[ -n "$notify_solving" ]]; then
  echo $'\n>' Notify Solving

  install -D /dev/null "$env_notify_solving_file"
  
  echo > "$env_notify_solving_file"
  echo "$notify_solving" >> "$env_notify_solving_file"
fi;


if [[ $env_allow_async == 1 && -n "$push_spec1" && -n "$push_spec2" ]]; then
  echo $'\n>' Push Async

  { git push $origin_1 $push_spec1 || true; } > "$path_async_output/push1.txt" &
  pid_push1=$!
  { git push $origin_2 $push_spec2 || true; } > "$path_async_output/push2.txt" &
  pid_push2=$!
  
  push_report1="> Push $origin_1 "
  wait $pid_push1 && push_report1+="(async success)" || push_report1+="(async failure)"
  push_report2+="> Push $origin_2 "
  wait $pid_push2 && push_report2+="(async success)" || push_report2+="(async failure)"
  
  echo $push_report1
  echo $push_spec1
  cat < "$path_async_output/push1.txt"

  echo $push_report2
  echo $push_spec2
  cat < "$path_async_output/push2.txt"
else
  if [[ -n "$push_spec1" ]]; then
    echo $'\n>' Push $origin_1
    echo $push_spec1
    git push $origin_1 $push_spec1 || true
  fi;
  if [[ -n "$push_spec2" ]]; then
    echo $'\n>' Push $origin_2
    echo $push_spec2
    git push $origin_2 $push_spec2 || true
  fi;
fi;


if [[ $env_allow_async == 1 && -n "$post_fetch_spec1" && -n "$post_fetch_spec2" ]]; then
  echo $'\n>' Post-fetch Async

  git fetch --no-tags $origin_1 $post_fetch_spec1 > "$path_async_output/post_fetch1.txt" &
  pid_post_fetch1=$!
  git fetch --no-tags $origin_2 $post_fetch_spec2 > "$path_async_output/post_fetch2.txt" &
  pid_post_fetch2=$!
  
  post_fetch_report1="> Post-fetch $origin_1 "
  wait $pid_post_fetch1 && post_fetch_report1+="(async success)" || post_fetch_report1+="(async failure)"
  post_fetch_report2+="> Post-fetch $origin_2 "
  wait $pid_post_fetch2 && post_fetch_report2+="(async success)" || post_fetch_report2+="(async failure)"
  
  echo $post_fetch_report1
  echo $post_fetch_spec1
  cat < "$path_async_output/post_fetch1.txt"

  echo $post_fetch_report2
  echo $post_fetch_spec2
  cat < "$path_async_output/post_fetch2.txt"
  
else
  if [[ -n "$post_fetch_spec1" ]]; then
    echo $'\n>' Post-fetch $origin_1
    echo $post_fetch_spec1
    git fetch --no-tags $origin_1 $post_fetch_spec1
  fi;
  if [[ -n "$post_fetch_spec2" ]]; then
    echo $'\n>' Post-fetch $origin_2
    echo $post_fetch_spec2
    git fetch --no-tags $origin_2 $post_fetch_spec2
  fi;
fi;


#echo
#echo End `basename $0`
