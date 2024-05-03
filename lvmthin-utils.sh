#!/bin/bash

lvmthin_create_thin() {
    local vg_name="$1"
    local pool_lv="$2"
    local name="$3"
    local sectors="$4"
    lvcreate "${vg_name}" --type thin --thinpool "${pool_lv}" --name "${name}" --virtualsize "${sectors}s"
}

lvmthin_get_pool_lv() {
    local vg_name="$1"
    local lv_name="$2"
    lvs -o pool_lv --noheadings "${vg_name}/${lv_name}" | tr -d '[:space:]'
    return ${PIPESTATUS[0]}
}

lvmthin_get_dev_id() {
    local vg_name="$1"
    local lv_name="$2"
    lvs -o thin_id --noheadings "${vg_name}/${lv_name}" | tr -d '[:space:]'
    return ${PIPESTATUS[0]}
}

lvmthin_swap_poolmetadata() {
    local vg_name="$1"
    local pool_lv="$2"
    local meta_spare="$3"
    lvconvert "${vg_name}/${pool_lv}" --swapmetadata --poolmetadata "${meta_spare}" -y
}

lvmthin_deactivate_pool() {
    local vg_name="$1"
    local pool_lv="$2"

    local pool_dev="${vg_name}-${pool_lv}-tpool"
    if dm_device_exist "${pool_dev}" && ! thinpool_deactivate_thins "${pool_dev}"; then
        return 1
    fi
    if ! lvm_deactivate_lv "${vg_name}" "${pool_lv}"; then
        return 1
    fi
}
