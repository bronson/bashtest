#!/bin/bash

# Enable extended globbing for pattern matching

readarray message <<EOF
    : This should get unindented.
    : This code should stay indented:
    :      something() {
    :          echo It works, yo!;
    :      }
EOF

shopt -s extglob
printf '%s' "${message[@]#*( ): }"
shopt -u extglob
