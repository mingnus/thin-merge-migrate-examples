#!/bin/bash

lvm_is_valid_display_name() {
    local display_name="$1"
    [[ ${display_name} =~ ^[A-Za-z0-9+_.-]+/[A-Za-z0-9+_.-]+$ ]]
}

lvm_parse_display_name() {
    local display_name="$1"
    if ! lvm_is_valid_display_name "${display_name}" || ! names=$(lvs -o vg_name,lv_name "${display_name}" --noheadings --separator ',' 2>/dev/null); then
        return 1
    fi
    echo "${names}" | tr ',' '\n'
}

lvm_create_lv() {
    local vg_name="$1"
    local lv_name="$2"
    local sectors="$3"
    lvcreate "${vg_name}" --name "${lv_name}" -L "${sectors}s"
}

lvm_remove_lv() {
    local vg_name="$1"
    local lv_name="$2"
    lvremove -f "${vg_name}/${lv_name}" 2>/dev/null
}

__lvm_activate_lv() {
    local vg_name="$1"
    shift
    local lv_name="$1"
    shift
    lvchange -ay "${vg_name}/${lv_name}" $@ 2>/dev/null >&2
}

lvm_activate_lv() {
    __lvm_activate_lv "$1" "$2"
}

lvm_activate_hidden_lv() {
    __lvm_activate_lv "$1" "$2" "-fy"
}

lvm_activate_shared_lv() {
    __lvm_activate_lv "$1" "$2" "--lockopt" "skiplv" "-fy"
}

lvm_deactivate_lv() {
    local vg_name="$1"
    local lv_name="$2"
    lvchange -an "${vg_name}/${lv_name}" 2>/dev/null
}

lvm_deactivate_lv_by_path() {
    local dev_path="$1"
    lvchange -an "${dev_path}" 2>/dev/null
}

lvm_get_lv_size() {
    local vg_name="$1"
    local lv_name="$2"
    lvs "${vg_name}/${lv_name}" -o lv_size --unit s --noheadings --nosuffix 2>/dev/null | tr -d '[:space:]'
    return ${PIPESTATUS[0]}
}

lvm_get_target_type() {
    local vg_name="$1"
    local lv_name="$2"
    lvs "${vg_name}/${lv_name}" -o segtype --noheadings 2>/dev/null | tr -d '[:space:]'
    return ${PIPESTATUS[0]}
}
