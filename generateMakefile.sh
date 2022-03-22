#!/bin/dash
print_help() {
    echo 'Usage : ./generateMakefile.sh [OPTION]...\n
Generates a Makefile from a project written in C language.\n
OPTIONS\r
\t--help \t\t\t Show help and exit.\r
\t-d ROOTDIR \t\t Set the root directory of the project.\r
\t\t\t\t\t Without this option, the current directory is used.\r
\t-o PROGNAME \t Set the name of executable binary file to produce.\r
\t\t\t\t\t Without this option, the name \"a.out\" is used.'
}

get_inclusion_guidelines() {
    DEPS=$DEPS' '$(grep -E '^#include ".*"$' $1 | sed 's/#include "//g' | sed 's/"/ /g' | tr -d '\n')
}

get_deps_from_string() {
    for i in $*; do
        if ! test -f $i; then
            echo "File $i doesn't exist." >&2
            rm -f Makefile
            exit 10
        fi
        get_inclusion_guidelines $i
    done
}

delete_duplicates() {
    var=$*
    var=$(echo $var | tr ' ' '\n' | sort | uniq | tr '\n' ' ')
    echo $var
}

verify_arguments() {
    counterD=0
    counterO=0
    for i in $(seq 1 $#); do
        if test "$1" = ''; then
            break
        fi
        if test "$1" = "--help"; then
            if test $# -ne 1; then
                echo 'Too much arguments.' >&2
                exit 1
            fi
            print_help
            exit 0
        elif test "$1" = "-d"; then
            counterD=$(($counterD + 1))
            if test $counterD -gt 1; then
                echo "Argument \"-d\" should be used a single time." >&2
                exit 4
            fi
            if test -d "$2"; then
                cd $2
            else
                echo "Folder $2 doesn't exist." >&2
                exit 6
            fi
            dirname=$2
            if ! ls *.c 2>/dev/null >/dev/null; then
                echo "Folder $dirname doesn't contain .c file." >&2
                exit 5
            fi
            shift
        elif test "$1" = "-o"; then
            counterO=$(($counterO + 1))
            if test $counterO -gt 1; then
                echo "Argument \"-o\" should be used a single time." >&2
                exit 4
            fi
            if echo "$2" | grep -Evq '^[a-zA-Z0-9_-][a-zA-Z0-9._-]*$'; then
                echo "$2 is not a valid name." >&2
                exit 2
            fi
            PROGNAME=$2
            shift
        else
            echo "Argument $1 is not valid." >&2
            exit 3
        fi
        shift
    done
}

get_deps() {
    get_inclusion_guidelines $1
    get_deps_from_string $DEPS
    DEPS=$(delete_duplicates $DEPS)

    while test "$OLD_DEPS" != "$DEPS"; do
        get_deps_from_string $DEPS
        DEPS=$(delete_duplicates $DEPS)
        OLD_DEPS=$DEPS
    done
}

generateMakefile() {

    PROGNAME='a.out'

    verify_arguments $*
    if ! ls *.c 2>/dev/null >/dev/null; then
        echo "Current folder doesn't contain .c file." >&2
        exit 5
    fi

    OUTPUTS=''
    for c in *.c; do
        OUTPUTS="$OUTPUTS $c"
    done
    OUTPUTS=$(echo $OUTPUTS | sed 's/\.c/\.o/g')

    echo '# Created by generateMakefile.sh' >Makefile
    echo "TARGET=$PROGNAME" >>Makefile
    echo "CC=$CC" >>Makefile
    echo "CFLAGS=$CFLAGS" >>Makefile
    echo "LDFLAGS=$LDFLAGS" >>Makefile
    echo "LDLIBS=$LDLIBS" >>Makefile
    echo '\nall: $(TARGET)\n' >>Makefile
    echo "\$(TARGET): $OUTPUTS" >>Makefile
    echo '\t$(CC) $(LDFLAGS) $^ -o $(TARGET)' >>Makefile

    for oFile in $OUTPUTS; do
        cFile=$(echo $oFile | sed 's/\.o/\.c/g')
        DEPS=''
        get_deps $cFile
        echo "$oFile: $cFile $DEPS" >>Makefile
        echo '\t$(CC) $(CFLAGS) -c -o $@ $<' >>Makefile
    done

    echo 'clean:\n\t rm -f *.o' >>Makefile
    echo 'mrproper: clean\n\t rm -f $(TARGET)' >>Makefile
    echo 'Makefile generated.'
}

generateMakefile $*
