# enetrypoint: _run_testfiles
# input:
# - testfiles: an array of testfiles to process
# - _tsk_root_dir
# calls: _run_tests

# given a testfile, ensure we return a unique name for this test
# (even if other testfiles have the same identical name)
_get_testfile_unique_dirname() {
    local testfile="$1"
    local filename="${testfile##*/}"     # remove leading directories
    filename="${filename%.test}"   # remove trailing ".test"
    echo "$filename--$testfile_count"
}

_run_testfiles() {
    local running_jobs=0   # TODO _tsk these?
    local testfile_count=0

    for testfile in "${testfiles[@]}"; do
        testfile_count=$((testfile_count + 1))
        if [ "$running_jobs" -ge "$max_jobs" ]; then
            wait -n
            running_jobs=$((running_jobs - 1))
        fi

        (
            tsk_root_dir="$tsk_root_dir/$(_get_testfile_unique_dirname "$testfile")"
            _run_testfile "$testfile"
            if [ "$tsk_fail_count" -gt 0 ]; then
                echo -e "  ${RED}✗${NC} $testfile: $tsk_fail_count $(pluralize $tsk_fail_count test) failed" >> "$tsk_root_dir/fail-results"
            fi
            if [ "$tsk_skip_count" -gt 0 ]; then
                echo -e "  ${YELLOW}○${NC} $testfile: $tsk_skip_count $(pluralize $tsk_skip_count test) skipped" >> "$tsk_root_dir/skip-results"
            fi
        ) &
        running_jobs=$((running_jobs + 1))
    done

    wait  # wait for the remaining jobs to finish
}
