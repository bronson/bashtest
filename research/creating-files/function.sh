#!/bin/bash

# Enable extended globbing for pattern matching
create_file() {
    echo "created $1 with contents:"
    cat | sed 's/^[ \t]*: //'
}

create_file hiho <<EOF
    : This should get unindented.
    : This code should stay indented:
    :      something() {
    :          echo It works, yo!;
    :      }
EOF

cat --stdin=<(cat <<EOF
huh
EOF
)

# ensure "example command" \
#     --return-code=0
#     --stdin=<(file)
