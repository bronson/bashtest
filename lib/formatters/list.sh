# called before each test starts
_list_formatter_pre_test() {
    # only do this if we're pretty-printing to a terminal
    if [ -n "$CR" ]; then
        # no newline on this line, end_test will back up and print the result
        printf " %02d ....   $tsk_test_name" "$tsk_total_count" >&3
    fi
}

# called after each test is complete
_list_formatter_post_test() {
    local result
    case "$1" in
        pass) result="${GREEN}pass${NC}" ;;
        skip) result="${YELLOW}skip${NC}" ;;
        fail) result="${RED}FAIL${NC}" ;;
        *) result="${RED}INTERNAL ERROR: ${result}${NC}" ;;
    esac

    local errmsg=''
    local num_fails="${#tsk_test_error_messages[@]}"
    if [ "$num_fails" -gt 0 ]; then
        errmsg=" ($num_fails $(pluralize "$num_fails" "error"))"
    fi

    printf "$CR %02d $result   $tsk_test_name$errmsg\n" "$tsk_total_count" >&3
    _print_test_error_messages
}

_list_formatter_test_summary() {
    local color="$GREEN"

    local skip_msg=""
    if [ $tsk_skip_count -gt 0 ]; then
        color="$YELLOW"
        skip_msg=", ${tsk_skip_count} skipped"
    fi

    if [ $tsk_fail_count -gt 0 ]; then
        color="$RED"
    fi

    local count="${tsk_total_count} $(pluralize "$tsk_total_count" "test")"
    local assertions="${tsk_total_assertions} $(pluralize "$tsk_total_assertions" "assertion")."
    echo -e "${color}$count: ${tsk_pass_count} passed, ${tsk_fail_count} failed${skip_msg}.   ${assertions}${NC}" >&3
}
