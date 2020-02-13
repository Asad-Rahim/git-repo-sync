# echo
# echo Start `basename "$BASH_SOURCE"`


[[ ${git_sync_env_initialized:+var_is_not_empty} ]] || {

    function git_sync_env_run_settings_script(){

        file_name_repo_settings="${1-}"

        [[ $# -eq 0 ]] && {
            file_name_repo_settings="default_sync_project.sh"
        }

        relative_settings_file="$path_git_sync/$file_name_repo_settings"
        absolute_settings_file="$file_name_repo_settings"
        subfolder_settings_file="$path_git_sync/repo_settings/$file_name_repo_settings"
        if [[ -f "$relative_settings_file" ]]; then
            echo Settings. Using relative. $relative_settings_file
            source "$relative_settings_file"
        elif [[ -f "$absolute_settings_file" ]]; then
            echo Settings. Using absolute. $absolute_settings_file
            source "$absolute_settings_file"
        elif [[ -f "$subfolder_settings_file" ]]; then
            echo Settings. Using repo_settings subfolder. $subfolder_settings_file
            source "$subfolder_settings_file"
        else
            echo "Error! Exit! The first parameter must be an absolute path, relative path or a name of a file with your sync-project repo settings."
            echo The '"'$file_name_repo_settings'"' is not recognized as a file.
            
            exit 101;
        fi

        env_project_folder=$(basename ${file_name_repo_settings%.*})
    }

    function git_sync_env_init(){

        git_sync_env_initialized=$(date +%T)
        export git_sync_env_initialized

        export path_git_sync="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"
        export path_git_sync_util="$path_git_sync/util"

        # AWKPATH is env variable of GAWK that is used by the @include directive.
        # We need to set AWKPATH because our current directory commonly points points out to the sync Git repo, not our GAWK scripts.
        export AWKPATH="$path_git_sync_util/gawk"

        if [[ ${git_sync_project_folder:+1} ]]; then
            env_project_folder=$git_sync_project_folder
        elif [[ ${url_a:+1} || ${url_b:+1} ]]; then
            env_project_folder=default_env_sync_project
        else
            git_sync_env_run_settings_script "$@"
        fi

        if [[ ! ${url_a:+1} ]]; then missed_repo_settings+="url_a  "; fi
        if [[ ! ${url_b:+1} ]]; then missed_repo_settings+="url_b  "; fi

        if [[ ${missed_repo_settings:+1} ]]; then echo "Error! Exit! The following repo properties must be set:  $missed_repo_settings"; fi
        if [[ ! ${must_exist_branch:+1} ]]; then echo "Warning! The refs' deletion will not be working without setting the must_exist_branch property"; fi

        if [[ ${missed_repo_settings:+1} ]]; then
            exit 102;
        fi

        ${pref_a_link:+}
        ${pref_b_link:+}

        ${pref_a_conv:+}
        ${pref_b_conv:+}

        # If this var is empty, then we ignore the Victim branches functionality and its "The latest action wins" conflict solving strategy.
        ${pref_victim:+}

        conventional_prefixes_trace_values="
        pref_a_conv is '$pref_a_conv'
        pref_b_conv is '$pref_b_conv'"

        if [[ "$pref_a_conv" && "$pref_a_conv" == "$pref_b_conv" ]]; then
            echo "Error! Exit! We expect that you assign different letters for conventional ref prefixes. $conventional_prefixes_trace_values"

            exit 103;
        fi;

        prefixes_trace_values="
        pref_victim is '$pref_victim' $conventional_prefixes_trace_values"

        if [[ "$pref_victim" \
            && ( "$pref_a_conv" == "$pref_victim" \
            || "$pref_b_conv" == "$pref_victim" ) ]];
        then
            echo "Error! Exit! We expect that the victim ref prefix have letters different from conventional ref prefixes. $prefixes_trace_values"

            exit 104;
        fi;

        if [[ ( ! "$pref_a_conv" || ! "$pref_a_conv" ) || ! "$pref_victim" ]]; then
            echo "Error! Exit! You have to configure victim or both conventional ref prefixes. $prefixes_trace_values"

            exit 105;
        fi;
        sync_ref_specs="$pref_a_conv* $pref_b_conv* ${pref_victim:+${pref_victim}*}"
        export sync_ref_specs

        export pref_a_conv
        export url_a
        export pref_b_conv
        export url_b
        export pref_victim
        export must_exist_branch

        pref_a_conv_safe=${pref_a_conv: : -1}
        pref_a_conv_safe=${pref_a_conv_safe//\//-}
        export pref_a_conv_safe

        pref_b_conv_safe=${pref_b_conv: : -1}
        pref_b_conv_safe=${pref_b_conv_safe//\//-}
        export pref_b_conv_safe

        export origin_a=orig_1_$pref_a_conv_safe
        export origin_b=orig_2_$pref_b_conv_safe

        export use_bash_git_credential_helper=${use_bash_git_credential_helper-}

        export git_sync_pass_num=0
        export git_sync_pass_num_required=0

        # The way we receive data from gawk we can't use new line char in the output. So we are using a substitution.
        export env_awk_newline_substitution='|||||'

        env_allow_async=${env_allow_async:-1}
        # env_allow_async=0
        export env_allow_async

        env_trace_refs=${env_trace_refs:-0}
        # env_trace_refs=1
        export env_trace_refs
        
        export env_awk_trace_on=1
        export env_process_if_refs_are_the_same=0

        path_project_root="$path_git_sync/sync-projects/$env_project_folder"
        export path_sync_repo="$path_project_root/sync_repo"
        # Catches outputs of the fork-join async implementation.
        export path_async_output="$path_project_root/async_output"
        signal_files_folder=file-signals
        export env_modifications_signal_file="$path_project_root/$signal_files_folder/there-are-modifications"
        export env_modifications_signal_file_1="$path_project_root/$signal_files_folder/there-are-modifications_1"
        export env_modifications_signal_file_2="$path_project_root/$signal_files_folder/there-are-modifications_2"
        export env_notify_del_file="$path_project_root/$signal_files_folder/notify_del"
        export env_notify_solving_file="$path_project_root/$signal_files_folder/notify_solving"

        export git_cred="$path_git_sync_util/bash-git-credential-helper/git-cred.sh"

    }
    git_sync_env_init "$@"
}



# echo End `basename "$BASH_SOURCE"`
