_dot_formatter_pre_test() { :; }

_dot_formatter_post_test() {
    case "$1" in
        pass) echo -n '.' >&3 ;;
        skip) echo -n 's' >&3 ;;
        fail) echo -n 'F' >&3 ;;
        *) echo -n 'E' >&3 ;;
    esac
}

_dot_formatter_test_summary() {
    echo # _dot_formatter_post_test doesn't print a final newline so here it is

    # if any failure results exist, print them
    local fail_files=("$tsk_root_dir"/*/fail-results)
    if [ -f "${fail_files[0]}" ]; then
        echo -e "${RED}Failed tests:${NC}" >&3
        cat "${fail_files[@]}" >&3
    fi

    # if any skip results exist, print them
    local skip_files=("$tsk_root_dir"/*/skip-results)
    if [ -f "${skip_files[0]}" ]; then
        echo -e "${YELLOW}Skipped tests:${NC}" >&3
        cat "${skip_files[@]}" >&3
    fi
}
