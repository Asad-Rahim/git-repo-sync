# All variables a described below.
## Post your questions on https://github.com/it3xl/git-repo-sync/issues
## I will be glad to explain the ambiguities and to improve this instruction for others.


# url_a=https://your-repo1-url.org/git/my_repo.git
# url_b=https://git.your-repo2-url.org/my_repo.git

# victim_branches_prefix=@

# side_a_conventional_branches_prefix=a-
# side_b_conventional_branches_prefix=b-


# sync_enabling_branch=${victim_branches_prefix}test
# sync_enabling_branch=${side_a_conventional_branches_prefix}prod
# sync_enabling_branch=it3xl-git_repo_sync-enabled

# git_sync_project_folder=my-sync-project

# use_bash_git_credential_helper=1


#
##
### Descriptions
##
#


## This Configuration File
#
# All variables in this file configure the synchronization of two remote Git-repositories.
# You can define them in a parent process environment.
# Use the following options to configure.
#
# * Uncomment and modify required variables in this file.
#
## Create a copy of this file.
# * Pass the name of your copied file to git-sync.sh at the first parameter for every run.
# * In this case your config-file could be located in the following folders:
# ** git-repo-sync/repo_settings
# ** git-repo-sync/../git-repo-sync.repo_settings
# * Use a full path or relative path to "git-repo-sync" if you want to locate you config file in an arbitrary location.
# * Invocation example: $ ./git-sync.sh  my-sync-project.sh
#
## Declare config variables in your script and add git-sync.sh invocation.
# * The git_sync_project_folder variable is mandatory in this case.
#
# * Declare the variables in your environment and call git-sync.sh.
# * The git_sync_project_folder variable is mandatory in this case.

## url_a
## url_b
# Let's call your two synchronized remote Git repositories as sides A and B.
# Then url_a and url_b point to git remote repository of the A side and B side accordingly.
# It could be an URL or a path. SSH addresses wasn't tested yet.

## victim_branches_prefix
# Git-branches with a prefix from this variable will be updated under a Victim Syncing strategy.
# This means everybody can do whatever they want with such branches.
# And any last action will win in case of a conflict.
# You can relocate it to any position, move it back, delete, etc.
# The default value is empty that means this syncing strategy will be disabled.
# The most common value is "@".
# Examples: @dev, @dev-staging, @test, @test-staging

## side_a_conventional_branches_prefix
# Git-branches with a prefix from this variable will be owned by the A side.
#
## side_b_conventional_branches_prefix
# Git-branches with a prefix from this variable will be owned by the B side.
#
# Such branches will be updated under a Conventional Syncing strategy.
# You can do whatever you want with these branches from an owning side repository.
# And you can only do forward updating commits and merges from a non-owning side repository.
# There is no default value. The most common value is an abbreviation of a client or vendor companies.
# Omitted or empty values will disable Conventional Syncing strategy.
# Examples: client-uat, client-uat-staging; vendor-uat, vendor-uat-staging

## sync_enabling_branch
# This variable represents a special branch name.
# Your syncing remote Git-repositories must have such the branch to allow synchronization by git-repo-sync.
# Exception, if you're starting to synchronize an empty Git-repository with a repository that already has this branch.
# Existence of this branch protects you from synchronizing of unrelated Git-repositories, i.e. different projects.
# By default this branch will be updating under Victim Sync strategy. But you can add a conventional prefix to it.
# The default value is "it3xl-git_repo_sync-enabled".
# Examples: @test, client-prod, vendor-master, it3xl-git_repo_sync-enabled

## git_sync_project_folder
# This variable is a mandatory if you are configuring your sync project through a parent environment or script without a configuration file.
# Otherwise, this value is taken from the name of the configuration file, if specified.
# The git_sync_project_folder defines a folder in which your sync project artifacts will be stored inside of the "git-repo-sync/sync-projects/" folder.



## use_bash_git_credential_helper
# This variables enables using of git-cred, the "bash Git Credential Helper" from https://github.com/it3xl/bash-git-credential-helper
# 
# Git-cred allows you to use Git-credential values from environment variables
#  which are defined automatically by any Continues Integration (CI) tool.
#
# You can use git-cred as an external tool and tune everything manually.
# But configuring it here allows you to initialize git-cred only once.
# BTW, git-cred allows free relocation of an installation git-repo-sync folder.
#
# * Before using git-cred you must complete the following steps.
#
# ** Load Git sub-modules of git-repo-sync (https://github.com/it3xl/git-repo-sync)
#
# ** Before any call to git-sync.sh or request-git-sync.sh, define the following environment variables in your CI-server (tool)
#   For the repo in $url_a
# git_cred_username_repo_a=some-login
# git_cred_password_repo_a=some-password
#   For the repo in $url_b
# git_cred_username_repo_b=another-login
# git_cred_password_repo_b=another-password
#
# ** Assign use_bash_git_credential_helper variable to 1.


