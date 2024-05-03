#!/bin/bash

blockdev_getsz() {
    blockdev --getsz "$1"
}

is_devno() {
    local devno="$1"
    [[ "${devno}" =~ ^[0-9]+\:[0-9]+$ ]]
}

dm_device_exist() {
    local dm_name="$1"
    dmsetup info "${dm_name}" >/dev/null
}

dm_name_to_disk() {
    local dm_name="$1"
    local disk_name
    if ! disk_name=$(basename "$(readlink "/dev/mapper/${dm_name}" 2>/dev/null)"); then
        return 1
    fi
    echo "${disk_name}"
}

dm_disk_to_name() {
    local disk_name="$1"
    local dm_name
    cat "/sys/block/${disk_name}/dm/name" 2>/dev/null
}

dm_target_type() {
    local dev_name="$1"
    local target_type=$(
        dmsetup table "${dev_name}" 2>/dev/null | cut -d ' ' -f 3
        exit ${PIPESTATUS[0]}
    )
    if [ $? -ne 0 ] || [ ! ${target_type} ]; then
        return 1
    fi
    echo "${target_type}"
}

dm_devno_to_name() {
    local devno="$1"
    local disk_name
    if ! disk_name=$(dm_devno_to_disk_name "${devno}"); then
        return 1
    fi
    dm_disk_to_name ${disk_name}
}

dm_devno_to_disk_name() {
    local devno="$1"
    local dev_minor
    if ! is_devno "${devno}"; then
        return 1
    fi
    dev_minor=$(echo ${devno} | cut -d ':' -f 2)
    echo "dm-${dev_minor}"
}

dm_remove_device() {
    local dev_name="$1"
    dmsetup remove "${dev_name}" 2>/dev/null
}
