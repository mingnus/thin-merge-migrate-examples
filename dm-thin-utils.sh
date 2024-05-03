#!/bin/bash

source ./dm-utils.sh

dm_is_thin() {
    local dev_name="$1"
    local target_type
    if ! target_type=$(dm_target_type "${dev_name}") || [ "${target_type}" != "thin" ]; then
        return 1
    fi
    return 0
}

dm_activate_thin_pool() {
    local pool_name="$1"
    local meta_path="$2"
    local data_path="$3"

    local pool_size
    if ! pool_size=$(blockdev_getsz "${data_path}"); then
        return 1
    fi

    local data_block_size=$(
        thin_dump ${meta_path} --skip-mappings | grep -o 'data_block_size="[0-9]*"' | cut -d '"' -f 2
        exit ${PIPESTATUS[0]}
    )
    if [ $? -ne 0 ] || [ -z ${data_block_size} ]; then
        return 1
    fi

    dmsetup create "${pool_name}" --table "0 ${pool_size} thin-pool ${meta_path} ${data_path} ${data_block_size} 0"
}

dm_activate_thin() {
    local thin_name="$1"
    local thin_id="$2"
    local thin_size="$3"
    local pool_name="$4"
    dmsetup create "${thin_name}" --table "0 ${thin_size} thin /dev/mapper/${pool_name} ${thin_id}"
}

dm_activate_external_snapshot() {
    local thin_name="$1"
    local thin_id="$2"
    local thin_size="$3"
    local pool_name="$4"
    local origin_path="$5"
    dmsetup create "${thin_name}" --table "0 ${thin_size} thin /dev/mapper/${pool_name} ${thin_id} ${origin_path}"
}

# TODO: check target type
thin_get_mapped_sectors() {
    local thin_name="$1"
    local mapped_sectors=$(
        dmsetup status "${thin_name}" --noflush 2>/dev/null | cut -d ' ' -f 4
        exit ${PIPESTATUS[0]}
    )
    if [ $? -ne 0 ] || [ -z ${mapped_sectors} ]; then
        return 1
    fi
    echo "${mapped_sectors}"
}

thin_get_pool_name() {
    local thin_name="$1"
    local pool_devno=$(
        dmsetup table "${thin_name}" 2>/dev/null | cut -d ' ' -f 4
        exit ${PIPESTATUS[0]}
    )
    if [ $? -ne 0 ] || [ -z ${pool_devno} ]; then
        return 1
    fi
    dm_devno_to_name "${pool_devno}"
}

thin_get_dev_id() {
    local thin_name="$1"
    local dev_id=$(
        dmsetup table "${thin_name}" 2>/dev/null | cut -d ' ' -f 5
        exit ${PIPESTATUS[0]}
    )
    if [ $? -ne 0 ] || [ -z ${dev_id} ]; then
        return 1
    fi
    echo "${dev_id}"
}

# TODO: check target type
thinpool_get_block_size() {
    local pool_name="$1"
    block_size=$(
        dmsetup table "${pool_name}" 2>/dev/null | cut -d ' ' -f 6
        exit ${PIPESTATUS[0]}
    )
    if [ $? -ne 0 ] || [ -z ${block_size} ]; then
        return 1
    fi
    echo "${block_size}"
}

# TODO: check target type
thinpool_get_meta_name() {
    local pool_name="$1"
    local meta_devno=$(
        dmsetup table "${pool_name}" 2>/dev/null | cut -d ' ' -f 4
        exit ${PIPESTATUS[0]}
    )
    if [ $? -ne 0 ] || [ -z ${meta_devno} ]; then
        return 1
    fi
    dm_devno_to_name "${meta_devno}"
}

# TODO: merge with the above to reduce ioctl counts
thinpool_get_data_name() {
    local pool_name="$1"
    local data_devno=$(
        dmsetup table "${pool_name}" 2>/dev/null | cut -d ' ' -f 5
        exit ${PIPESTATUS[0]}
    )
    if [ $? -ne 0 ] || [ -z ${data_devno} ]; then
        return 1
    fi
    dm_devno_to_name "${data_devno}"
}

thinpool_deactivate_thins() {
    local pool_name="$1"
    local pool_disk=$(dm_name_to_disk ${pool_name})
    for holder in "/sys/block/${pool_disk}/holders/dm-*"; do
        local dm_name=$(dm_disk_to_name $(basename "${holder}"))
        if ! dm_is_thin "${dm_name}"; then
            continue
        fi
        dm_remove_device "${dm_name}"
    done
}

thinpool_estimate_metadata_size() {
    local block_size="$1"
    local pool_size="$2"
    thin_metadata_size --block-size "${block_size}s" --pool-size "${pool_size}s" -m 1 -n -u s
}

thinpool_dump_mappings() {
    local pool_name="$1"
    local snap_id="$2"
    local output_path="$3"

    local tmeta_name
    if ! tmeta_name=$(thinpool_get_meta_name "${pool_name}"); then
        return 1
    fi

    dmsetup message "${pool_name}" 0 reserve_metadata_snap &&
        thin_merge -i "/dev/mapper/${tmeta_name}" -o "${output_path}" --origin "${snap_id}" -m --io-engine async
    ret=$?
    # release metadata snapshot anyway
    dmsetup message "${pool_name}" 0 release_metadata_snap

    return ${ret}
}

thinpool_create_thin() {
    local pool_name="$1"
    local thin_id="$2"
    dmsetup message "${pool_name}" 0 "create_thin ${thin_id}"
}
