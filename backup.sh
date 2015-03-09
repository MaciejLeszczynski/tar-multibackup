#!/bin/bash

[ -n "$DEBUG" ] && set -x

###
# Configuration
###

. ${HOME}/.multibackup.conf

###
# Functions
###

# Color helpers
color_red=`tput setaf 1`
color_yellow=`tput setaf 3`
color_green=`tput setaf 2`
color_reset=`tput sgr0`


# Logging prefix helper
prefix(){
  echo "[${current_action}] [${current_task}/${total_tasks}]"
}

# Logging helpers
debug() {
  echo "$(prefix) [DEBUG] $@" 1>&2
}

success() {
  echo "$(prefix) ${color_green}[SUCCESS]${color_reset} $@" 1>&2
}

info() {
  echo "$(prefix) ${color_yellow}[INFO]${color_reset} $@" 1>&2
}

error() {
  echo "$(prefix) ${color_red}[ERROR]${color_reset} $@" 1>&2
}

# Strip all redundant slashes in file paths
strip_duplicate_slashes_in_path(){
  echo "${@}" | sed 's#//*#/#g'
}

# Replace all slashes with dashes
replace_slash_with_dash(){
    echo "${@}" | sed 's#/#-#g' | sed 's/^-//g' | sed 's/-$//g'
}

###
# Logic
###

# Set prefix variables for pre-commands
current_action="pre-command"
current_task=1
total_tasks=${#pre_commands[@]}

# Iterate through pre_commnads
if [ ${#pre_commands[@]} -ne 0 ]; then
  info "Found pre commands..."
  # Run each pre command
  for ((i=0; i < ${#pre_commands[@]}; i++)); do
    info "Running \"${pre_commands[$i]}\":"
    ${pre_commands[$i]}
    # Check return value to see if command ran successfully
    if [ $? -eq 0 ]; then
      success "Pre command \"${pre_commands[$i]}\" successfully completed!"
    else
      error "Pre command \"${pre_commands[$i]}\" failed..."
    fi
  done
fi

# Set prefix variables for backup
current_action="backup"
current_task=1
total_tasks=${#folders_to_backup[@]}

# Iterate through "$folders_to_backup"
for ((i=0; i < ${#folders_to_backup[@]}; i++)); do
  # Check if folder exists
  debug "Check if source folder \"${folders_to_backup[$i]}\" exists..."
  if [[ -d ${folders_to_backup[$i]} ]]; then
    # Exist => continue
    info "Source folder \"${folders_to_backup[$i]}\" exists!"
    # Make sure backup destination exists
    backup_basename=$(replace_slash_with_dash ${folders_to_backup[$i]})
    absolute_backup_destination=$(strip_duplicate_slashes_in_path ${backup_destination}/${backup_basename})
    if [[ ! -d "${absolute_backup_destination}" ]]; then
      info "Backup destination folder \"${absolute_backup_destination}\" doesn't exist. Creating..."
      mkdir -p ${absolute_backup_destination}
    fi

    # Check if backup already exists (to make sure)
    if [[ -f ${absolute_backup_destination}/${timestamp}.tar.gz ]]; then
      error "Backup \"${absolute_backup_destination}/${timestamp}.tar.gz\" already exists. Skipping..."
    else
      # Start backup
      info "Starting backup \"${absolute_backup_destination}/${timestamp}.tar.gz\""
      tar czf ${absolute_backup_destination}/${timestamp}.tar.gz ${folders_to_backup[$i]}
      if [ $? -eq 0 ]; then
        success "Backup \"${absolute_backup_destination}/${timestamp}.tar.gz\" successfully completed!"
      else
        error "Backup \"${absolute_backup_destination}/${timestamp}.tar.gz\" failed..."
      fi
    fi

    # Remove old backups
    if [ ! -z "${backup_retention}" ]; then
      find ${absolute_backup_destination}/ -maxdepth 1 -mtime ${backup_retention} -type d -exec rm -rf {} \;
    fi
  else
    # Doesn't exist => skip
    error "Folder \"${folders_to_backup[$i]}\" doesn't exist. Skipping..."
  fi
  # Increment $current_task variable
  current_task=$((current_task+1))
done

# Set prefix variables for pre-commands
current_action="post-command"
current_task=1
total_tasks=${#post_commands[@]}

# Iterate through post_commnads
if [ ${#post_commands[@]} -ne 0 ]; then
  info "Found post commands..."
  # Run each post command
  for ((i=0; i < ${#post_commands[@]}; i++)); do
    info "Running \"${post_commands[$i]}\":"
    ${post_commands[$i]}
    # Check return value to see if command ran successfully
    if [ $? -eq 0 ]; then
      success "Pre command \"${post_commands[$i]}\" successfully completed!"
    else
      error "Pre command \"${post_commands[$i]}\" failed..."
    fi
  done
fi