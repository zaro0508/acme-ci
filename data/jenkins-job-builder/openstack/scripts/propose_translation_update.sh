#!/bin/bash -xe

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

PROJECT=$1
BRANCH=$2
JOBNAME=$3

# Replace /'s in the branch name with -'s because Zanata does not
# allow /'s in version names.
ZANATA_VERSION=${BRANCH//\//-}

source /usr/local/jenkins/slave_scripts/common_translation_update.sh

init_branch $BRANCH

function cleanup_module {
    local modulename=$1

    # Remove obsolete files.
    cleanup_po_files "$modulename"
    cleanup_pot_files "$modulename"

    # Compress downloaded po files, this needs to be done after
    # cleanup_po_files since that function needs to have information the
    # number of untranslated strings.
    compress_po_files "$modulename"
}

# Propose updates for manuals
function propose_manuals {

    # Pull updated translations from Zanata.
    pull_from_zanata "$PROJECT"

    # Compress downloaded po files
    case "$PROJECT" in
        openstack-manuals)
            # Cleanup po and pot files
            cleanup_module "doc"
            ;;
        api-site)
            # Cleanup po and pot files
            cleanup_module "api-quick-start"
            cleanup_module "firstapp"
            ;;
        security-doc)
            cleanup_module "security-guide"
            ;;
    esac

    # Add imported upstream translations to git
    for FILE in ${DocFolder}/*; do
        DOCNAME=${FILE#${DocFolder}/}
        if [ -d ${DocFolder}/${DOCNAME}/locale ] ; then
            git add ${DocFolder}/${DOCNAME}/locale/*
        fi
        if [ -d ${DocFolder}/${DOCNAME}/source/locale ] ; then
            git add ${DocFolder}/${DOCNAME}/source/locale/*
        fi
    done
}

# Propose updates for training-guides
function propose_training_guides {

    # Pull updated translations from Zanata.
    pull_from_zanata "$PROJECT"

    # Cleanup po and pot files
    cleanup_module "doc/upstream-training"

    # Add all changed files to git
    git add doc/upstream-training/source/locale/*
}


# Propose updates for python and django projects
function propose_python_django {
    local modulename=$1

    # Check for empty directory and exit early
    local content=$(ls -A $modulename/locale/)

    if [[ "$content" == "" ]] ; then
        return
    fi

    # Now add all changed files to git.
    # Note we add them here to not have to differentiate in the functions
    # between new files and files already under git control.
    git add $modulename/locale/*

    # Cleanup po and pot files
    cleanup_module "$modulename"

    # Check first whether directory exists, it might be missing if
    # there are no translations.
    if [[ -d "$modulename/locale/" ]] ; then

        # Some files were changed, add changed files again to git, so
        # that we can run git diff properly.
        git add $modulename/locale/
    fi
}


# Handle either python or django proposals
function handle_python_django {
    local project=$1
    # kind can be "python" or "django"
    local kind=$2
    local module_names

    module_names=$(get_modulename $project $kind)
    if [ -n "$module_names" ]; then
        setup_project "$project" "$ZANATA_VERSION" $module_names
        if [[ "$kind" == "django" ]] ; then
            install_horizon
        fi
        # Pull updated translations from Zanata
        pull_from_zanata "$project"
        propose_releasenotes "$ZANATA_VERSION"
        for modulename in $module_names; do
            # Note that we need to generate the pot files so that we
            # can calculate how many strings are translated.
            case "$kind" in
                django)
                    # Update the .pot file
                    extract_messages_django "$modulename"
                    ;;
                python)
                    # Extract all messages from project, including log messages.
                    extract_messages_python "$modulename"
                    ;;
            esac
            propose_python_django "$modulename"
        done
    fi
}


function propose_releasenotes {
    local version=$1

    # This function does not check whether releasenote publishing and
    # testing are set up in zuul/layout.yaml. If releasenotes exist,
    # they get pushed to the translation server.

    # Note that releasenotes only get translated on master.
    if [[ "$version" == "master" && -f releasenotes/source/conf.py ]]; then

        # Note that we need to generate these so that we can calculate
        # how many strings are translated.
        extract_messages_releasenotes

        # Cleanup files.
        cleanup_module "releasenotes"

        # Add all changed files to git - if there are
        # translated files at all.
        if [ -d releasenotes/source/locale/ ] ; then
            git add releasenotes/source/locale/
        fi
    fi

    # Remove any releasenotes translations from stable branches, they
    # are not needed there.
    if [[ "$version" != "master" && -d releasenotes/source/locale ]]; then
        git rm -rf releasenotes/source/locale
    fi
}


# Setup git repository for git review.
setup_git

# Check whether a review already exists, setup review commit message.
setup_review "$BRANCH"

# Setup venv - needed for all projects for subunit
setup_venv

case "$PROJECT" in
    api-site|openstack-manuals|security-doc)
        init_manuals "$PROJECT"
        setup_manuals "$PROJECT" "$ZANATA_VERSION"
        propose_manuals
        propose_releasenotes "$ZANATA_VERSION"
        ;;
    training-guides)
        setup_training_guides "$ZANATA_VERSION"
        propose_training_guides
        ;;
    *)
        # Common setup for python and django repositories
        setup_loglevel_vars
        handle_python_django $PROJECT python
        handle_python_django $PROJECT django
        ;;
esac

# Filter out commits we do not want.
filter_commits

# Propose patch to gerrit if there are changes.
send_patch "$BRANCH"

if [ $INVALID_PO_FILE -eq 1 ] ; then
    echo "At least one po file in invalid. Fix all invalid files on the"
    echo "translation server."
    exit 1
fi
# Tell finish function that everything is fine.
ERROR_ABORT=0
