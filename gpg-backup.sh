#! /bin/bash
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

function error() {
    error="Unknown error."
    case $1 in
    1)
        error="Not valid action provided."
        ;;
    2)
        error="Not valid src_dir provided."
        ;;
    3)
        error="Cannot override destination folder. Delete it first."
        ;;
    4)
        error="Not valid gpg_key provided."
        ;;
    esac
    echo "[E:$1] $error"
    echo "
    Usage:
        $0 action src_dir dst_dir [gpg_key]

            action: backup/restore
            src_dir: source dir [used for backup && restore]
            dst_dir: destination dir [used for backup && restore]
            gpg_key: GPG key [used just for backup]
    "
    exit $1
}

function encrypt() {
    local SRC="$1" # Source folder
    local DST="$2" # Destination folder
    local KEY="$3" # GPG key

    # Delete DST folder
    rm -rf $DST

    # Clone folder structure
    rsync -avt --include='*/' --exclude='*' ${SRC}/ ${DST}/

    # Backup files keeping permissions, owner and timestamps
    cd $SRC
    for file in $(find . -type f)
    do
        #tar -cvpf - $file | gpg -o ${DST}/${file}.tar.gpg --encrypt --recipient ${KEY}
        pax -w $file | gpg -o ${DST}/${file}.tar.gpg --encrypt --recipient ${KEY}
    done
}

function decrypt() {
    local SRC="$1" # Source folder
    local DST="$2" # Destination folder

    # Delete DST folder
    rm -rf $DST

    # Clone folder structure
    rsync -avt --include='*/' --exclude='*' ${SRC}/ ${DST}/

    # Backup files keeping permissions, owner and timestamps
    cd $DST
    FILES=$(find $SRC -type f)
    for file in $FILES
    do
        #gpg --decrypt $file | tar --same-owner -xvpf -
        gpg --decrypt $file | pax -r -p e
    done
}

#################
# VALIDATE DATA
#################
ACTION=$1
SRC_DIR=$(readlink -f $2)
DST_DIR=$(readlink -f $3)
GPG_KEY=$4

test -n "$ACTION" && [ "$ACTION" == "backup" -o "$ACTION" == "restore" ] || error 1
[ -d "$SRC_DIR" ] || error 2
[ ! -d "$DST_DIR" ] || error 3
[ "$ACTION" == "backup" -a -n "$GPG_KEY" ] && gpg --list-keys |\
    grep -q -w $GPG_KEY 2> /dev/null || error 4
#################
# MAIN
#################
if [ "$ACTION" == "backup" ] ; then
    encrypt "$SRC_DIR" "$DST_DIR" "$GPG_KEY"
fi
if [ "$ACTION" == "restore" ] ; then
    decrypt "$SRC_DIR" "$DST_DIR"
fi
