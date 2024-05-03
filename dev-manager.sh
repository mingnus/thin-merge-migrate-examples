#!/bin/bash

source ./dm-utils.sh
source ./dm-thin-utils.sh
source ./lvm-utils.sh

activate_thin_pool_alias() {
    local vg_name="$1"
    local meta_lv="$2"
    local data_lv="$3"
    local alias_name="$4"

    # The component LVs might have target type different than linear,
    # thus it's better to activate them through LVM.
    if ! lvm_activate_lv "${vg_name}" "${meta_lv}"; then
        echo "Failed to activate LV ${vg_name}/${meta_lv}" >&2
        return 1
    fi

    if ! lvm_activate_shared_lv "${vg_name}" "${data_lv}"; then
        echo "Failed to activate LV ${vg_name}/${data_lv}" >&2
        return 1
    fi

    meta_path="/dev/mapper/${vg_name}-${meta_lv}"
    data_path="/dev/mapper/${vg_name}-${data_lv}"
    dm_activate_thin_pool "${alias_name}" "${meta_path}" "${data_path}"
}

deactivate_thin_pool_alias() {
    local pool_dev="$1"

    local meta_dev
    if ! meta_dev=$(thinpool_get_meta_name "${pool_dev}"); then
        return 1
    fi

    local data_dev
    if ! data_dev=$(thinpool_get_data_name "${pool_dev}"); then
        return 1
    fi

    if dm_device_exist "${pool_dev}" && ! dm_remove_device "${pool_dev}"; then
        return 1
    fi

    local meta_path="/dev/mapper/${meta_dev}"
    local data_path="/dev/mapper/${data_dev}"
    if ! lvm_deactivate_lv_by_path "${meta_path}" || ! lvm_deactivate_lv_by_path "${data_path}"; then
        return 1
    fi
}

activate_thin_alias() {
    local vg_name="$1"
    local thin_lv="$2"
    local meta_lv="$3"

    # TODO: make it generic
    attrs=($(
        lvs -o thin_id,lv_size,pool_lv --units s --nosuffix --noheadings --separator ',' "${vg_name}/${thin_lv}" | tr ',' '\n'
        exit ${PIPESTATUS[0]}
    ))

    if [ $? -ne 0 ]; then
        echo "Cannot get LV ${thin_lv} attributes" >&2
        return 1
    fi

    local thin_id="${attrs[0]}"
    local lv_size="${attrs[1]}"
    local pool_name="${attrs[2]}"
    local data_lv="${pool_name}_tdata"

    # TODO: use a random name for the temporary thin-pool?
    if ! activate_thin_pool_alias "${vg_name}" "${meta_lv}" "${data_lv}" "${pool_name}"; then
        echo "Failed to activate thin-pool ${pool_name}" >&2
        return 1
    fi

    # TODO: use a random name for the temporary thin volume?
    if ! dm_activate_thin "${thin_lv}" "${thin_id}" "${lv_size}" "${pool_name}"; then
        echo "Failed to activate thin volume ${thin_lv}" >&2
        dm_remove_device "${pool_name}"
        return 1
    fi

    # We don't return the temporary pool name as it could be obtained from the thin table line
    echo "${thin_lv}"
}

deactivate_thin_alias() {
    local thin_dev="$1"

    local pool_dev
    if ! pool_dev=$(thin_get_pool_name "${thin_dev}"); then
        return 1
    fi

    if dm_device_exist "${thin_dev}" && ! dm_remove_device "${thin_dev}"; then
        echo "Failed to deactivate LV ${thin_lv}" >&2
        return 1
    fi

    if ! deactivate_thin_pool_alias "${pool_dev}"; then
        echo "Failed to deactivate thin-pool ${pool_dev}" >&2
        return 1
    fi
}
