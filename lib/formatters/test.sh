_test_formatter_pre_test() { :; }

_test_formatter_post_test() {
    echo "$1 $tsk_test_name" >&3
    _print_test_error_messages
}

_test_formatter_test_summary() { :; }
