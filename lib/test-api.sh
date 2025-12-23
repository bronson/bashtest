#
#    The API available to tests...
#

_compare() {
    local op=$1 expected=$2 actual=$3

    tsk_test_assertions=$((tsk_test_assertions + 1))
    if [ ! x"$expected" "$op" x"$actual" ]; then
       _add_error "line $(_line_number 2): ${FUNCNAME[1]} $(_format_diff "$expected" "$actual")"
    fi
}

is_eq() { _compare '=' "$1" "$2"; }
is_neq() { _compare '!=' "$1" "$2"; }

# TODO: file_contains? stdout_contains?
stderr_contains() {
    local expected_text="$1"

    tsk_test_assertions=$((tsk_test_assertions + 1))
    tsk_stderr_checked=true

    if ! grep -q "$expected_text" "$tsk_root_dir/test-stderr"; then
        _add_error_with_stderr "stderr_contains line $(_line_number): stderr doesn't contain: '$expected_text'"
    fi
}

pause() {
    # TODO: make sure other tests aren't running simultaneously
    # TODO: export relevant variables and (export -f) functions
    # TODO: if the interactive shell exits with an error, stop testing.

    local prompt_msg="${1:-Test paused. Type 'exit' to continue.}"

    exec 5>&1 6>&2  # save the current test's stdout/stderr
    exec 1>&3 2>&4  # Restore original stdout/stderr for interactive use

    printf "\n\n\n=== PAUSED $tsk_test_name at line $(_line_number) ===\n"
    printf "$prompt_msg\n\n"
    PS1="[PAUSED] \w $ " bash --norc -i
    printf "=== RESUMING TEST ===\n\n"

    exec 1>&5 2>&6
}

# One trailing newline, if present, is trimmed from stdout before comparison.
# If you need to be pedantically correct about the presence of the final
# newline, you'll have to check for it outside of this function.
# TODO: this is not great.
file_is() {
    # TODO: this should be a utility function, then file_is calls it, matching stdout_is etc
    local expected_text="$1"
    local file_path="$2"
    local call_name="${3:-file_is}"
    local lineno="${4:-$(_line_number)}"

    # if the expected text isn't in the argument, it's on stdin
    if [ -z "$expected_text" ]; then
        if read -t 0; then    # don't hang if data isn't there
            expected_text="$(cat)"
        fi
    fi

    tsk_test_assertions=$((tsk_test_assertions + 1))

    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        _add_error "line $lineno: $call_name couldn't open '$file_path'"
        return
    fi

    local actual_text="$(cat "$file_path")"
    if [ "$expected_text" != "$actual_text" ]; then
        _add_error "line $lineno: $call_name $(_format_diff "$expected_text" "$actual_text")"
    fi
}

stdout_is() {
    file_is "$1" "$tsk_root_dir/test-stdout" stdout_is "$(_line_number)"
}

stderr_is() {
    file_is "$1" "$tsk_root_dir/test-stderr" stderr_is "$(_line_number)"
    tsk_stderr_checked=true
}

abort() {
    # TODO: could run all tests in a subshell that keeps testing until abort is called.
    # Abort exits the subshell and then the tests end normally.
    local errmsg="line $(_line_number): $1"
    printf "${CR} %02d ${RED}ABORT${NC} $tsk_testfile $errmsg\n" "$tsk_total_count" >&3
    printf "${RED}All testing aborted.${NC}\n" >&3
    exit 127
}

# Fails the test with the given message. NOTE: does not stop the test!
# Bash can't leap up the stack without invoking slow subshells.
#
# Example:
#     if [ ! -f myfile ]; then
#         fail "myfile must exist during test"
#         return
#     fi

fail() {    # TODO: test me!
    _add_error "line $(_line_number): $1"
}

mock() {
    local command="$1"
    local behavior="$2"
    local mock_dir="$tsk_root_dir/test-mocks"
    local executable="$mock_dir/$command"

    # Create the mock directory and add it to PATH if needed
    if [ ! -d "$mock_dir" ]; then
        mkdir -p "$mock_dir" 2>&4 || exit 1
    fi

    # Ensure we have an absolute path for the mock directory for PATH
    mock_dir="$(readlink -f "$mock_dir")"
    executable="$mock_dir/$command"

    # Add mock dir to PATH only when the first mock is created
    if [[ ":$PATH:" != *":$mock_dir:"* ]]; then
        export PATH="$mock_dir:$PATH"
    fi

    cat > "$executable" << EOF
#!/bin/bash
$behavior
EOF
    chmod +x "$executable"
}

# Returns the directory of the currently running testfile
testfile_dir() {
    if [ -z "$tsk_testfile" ]; then
        echo "Error: testfile_dir was called without a testfile!" >&4
        exit 1
    fi
    dirname "$tsk_testfile"
}

# Returns the directory of the run-tests script
framework_dir() {
    dirname "$tsk_framework_file"
}

# returns the directory that every test starts in (unless before:each changes it?)
# TODO: would there be a big speedup if these were variables instead of functions?
test_dir() {
    echo "$tsk_root_dir/run"
}

# call this when writing tests to dump its arguments immediately to the screen
debug() {
    echo "$@" >&3
}

# Called in a pre-hook or during the test, causes this test to be skipped.
# Note that it can't actually exit the test so `skip; return` is a useful idiom.
skip() {
    tsk_skip_test=true
}


pluralize() {
    local count=$1
    local singular=$2
    local plural=${3:-${singular}s}

    if [ "$count" -eq 1 ]; then
        echo "$singular"
    else
        echo "$plural"
    fi
}


# Returns TRUE if the given directory is empty, FALSE if not.
# Example: `is_empty $mydir || echo "$mydir is not empty"`
# see research/creating-files/benchmark_test-empty for notes on this implementation
is_empty() {
    # -G generates filenames matching the pattern
    compgen -G "$1/*" >/dev/null 2>&1 && return 1
    compgen -G "$1/.[!.]*" >/dev/null 2>&1 && return 1
    compgen -G "$1/.??*" >/dev/null 2>&1 && return 1
    return 0
}


# Creates a file in the current directory. Will be removed when the test finishes.
# Colon and whitespace at the beginning of the line are removed. This allows you
# to intend the file in your source code, and strip the indentation when it's used.
#
# Example: `create_file my_file.txt <<EOF`
#     : This code will stay indented:
#     :      something() {
#     :          echo it works yo
#     :      }
# EOF

create_file() {
    if [ ! -t 0 ]; then    # prevent hanging if no input supplied
        cat | sed 's/^[ \t]*: //'
    fi > "$1"
    at_cleanup "rm -f '$(realpath "$1")'"   # use absolute dir when cleaning up
}

# creates a directory that gets cleaned up when the test finishes.
# TODO: this function sucks. It doesn't even support -p.
create_dir() {
    mkdir "$1"    # can't use -p because when `rm $1` only the subdir would be removed.
    at_cleanup "rm -rf '$(realpath "$1")'"   # use absolute dir when cleaning up
}

# Add a custom cleanup action to be executed when the test finishes.
# Note that tests can change directories, so the cleanup action should
# be very careful what it relies upon.
at_cleanup() {
    tsk_cleanup_actions+=("$1")
}

# Execute all registered cleanup actions in reverse order (LIFO)
_run_cleanup() {
    local i
    for ((i=${#tsk_cleanup_actions[@]}-1; i>=0; i--)); do
        eval "${tsk_cleanup_actions[i]}" 2>/dev/null || true
    done
}


# Prevents the given testfiles and directories from automatically being included in test runs.
# (excluded files/dirs can still be run by naming them explicitly on the command line)
exclude_directory() {
    case "$1" in
        *[\*\?\[\]\\]*) abort "invalid filename: '$excluded_dir'" ;;
    esac
    tsk_excluded_dirs+=("$1")
}


# returns the line number of the caller of the given frame
# defaults to the caller of the function calling _line_number
_line_number() {
    local frame=${1:-1}
    local info=$(caller "$frame")
    echo "${info%% *}"
}

# used to quote large content in the test output, like stderr
_blockquote() {
    echo -n "$1" | sed 's/^/    | /'
}

_format_diff() {
    local expected="$1" actual="$2"

    # if the user asked for a diff, provide it
    if [ "$tsk_use_diff" = true ]; then
        local diff_output="$(diff -u <(echo "$expected") <(echo "$actual") | tail -n +4)"
        if [[ -n "$diff_output" ]]; then
            echo "diff:"$'\n'"$(_blockquote "$diff_output")"
            return
        fi
    fi

    # For short single-line content, use simple quoted format
    if [[ "$expected" != *$'\n'* && "$actual" != *$'\n'* &&
          ${#expected} -lt 30 && ${#actual} -lt 30 ]]; then
        echo "expected '$expected', got '$actual'"
        return
    fi

    # Otherwise, quote the full files
    echo "expected:"$'\n'"$(_blockquote "$expected")"$'\n'"    but got:"$'\n'"$(_blockquote "$actual")"
}

# todo? make line number and function name automatic?
_add_error() {
    tsk_test_error_messages+=("$1")
}

# same as _add_error, but includes a few lines of stderr after the message
_add_error_with_stderr() {
    local message="$1"
    local snippet="$(head -n 20 "$tsk_root_dir/test-stderr")"
    message="$message"$'\n'"$(_blockquote "$snippet")"
    _add_error "$message"
}

# used to test the API assertion calls: if an assertion failed,
# but was expected, then the failure is cleared and the test passes.
_expect_error() {
    local expected_message="$1"

    tsk_test_assertions=$((tsk_test_assertions + 1))

    # if nothing threw an error, that's an error.
    if [ ${#tsk_test_error_messages[@]} -eq 0 ]; then
        _add_error "line $(_line_number): _expect_error - expected error message: '$expected_message', but no errors were reported"
        return
    fi

    # Get the most recent error message
    local last_idx=$((${#tsk_test_error_messages[@]} - 1))
    local last_message="$(echo "${tsk_test_error_messages[last_idx]}" |
        sed -E 's/line [0-9]+:/line nnn:/g')"

    if [ "$expected_message" = "$last_message" ]; then
        # the error was expected so it gets cleared
        unset "tsk_test_error_messages[last_idx]"
    else
        # the error we expected was not the error we got
        tsk_test_error_messages[last_idx]="line $(_line_number): _expect_error $(_format_diff "$expected_message" "$last_message")"
    fi
}

# at the end of the test, all mocks are removed
# TODO: one day we might want to set up mocks once and
# then run them in multiple tests.
_cleanup_mocks() {
    rm -rf "$tsk_root_dir/test-mocks"/* "$tsk_root_dir/test-mocks"/.*
}
