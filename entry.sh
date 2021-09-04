#!/bin/bash

# This command only works in privileged container
tmp_mount='/tmp/_inoa'
mkdir -p "$tmp_mount"
if mount -t devtmpfs none "$tmp_mount" &> /dev/null; then
	PRIVILEGED=true
	umount "$tmp_mount"
else
	PRIVILEGED=false
fi
rm -rf "$tmp_mount"

function mount_dev()
{
	tmp_dir='/tmp/tmpmount'
	mkdir -p "$tmp_dir"
	mount -t devtmpfs none "$tmp_dir"
	mkdir -p "$tmp_dir/shm"
	mount --move /dev/shm "$tmp_dir/shm"
	mkdir -p "$tmp_dir/mqueue"
	mount --move /dev/mqueue "$tmp_dir/mqueue"
	mkdir -p "$tmp_dir/pts"
	mount --move /dev/pts "$tmp_dir/pts"
	touch "$tmp_dir/console"
	mount --move /dev/console "$tmp_dir/console"
	umount /dev || true
	mount --move "$tmp_dir" /dev

	# Since the devpts is mounted with -o newinstance by Docker, we need to make
	# /dev/ptmx point to its ptmx.
	# ref: https://www.kernel.org/doc/Documentation/filesystems/devpts.txt
	ln -sf /dev/pts/ptmx /dev/ptmx
	mount -t debugfs nodev /sys/kernel/debug
}

function start_udev()
{
	if [ "$UDEV" == "on" ]; then
		if $PRIVILEGED; then
			mount_dev
			if command -v udevd &>/dev/null; then
				unshare --net udevd --daemon &> /dev/null
			else
				unshare --net /lib/systemd/systemd-udevd --daemon &> /dev/null
			fi
			udevadm trigger &> /dev/null
		else
			echo "Unable to start udev, container must be run in privileged mode to start udev!"
		fi
	fi
}

function set_uid_gid() {
    # Make the UID/GID in the container match the desired UID/GID from
    # the host
    USER=scanbd
    OLD_UID="$( id -u ${USER} )"
    OLD_GID="$( id -g ${USER} )"
    CHANGED=""

    if [ -z "${USER_UID}" ]; then
      USER_UID="${OLD_UID}"
    fi

    if [ -z "${USER_GID}" ]; then
      USER_GID="${OLD_GID}"
    fi

    ## Change GID for USER?
    if [ -n "${USER_GID}" ] && [ "${USER_GID}" != "${OLD_GID}" ]; then
        sed -i -e "s/^${USER}:\([^:]*\):[0-9]*/${USER}:\1:${USER_GID}/" /etc/group
        sed -i -e "s/^${USER}:\([^:]*\):\([0-9]*\):[0-9]*/${USER}:\1:\2:${USER_GID}/" /etc/passwd
        CHANGED="1"
    fi

    ## Change UID for USER?
    if [ -n "${USER_UID}" ] && [ "${USER_UID}" != "${OLD_UID}" ]; then
        sed -i -e "s/^${USER}:\([^:]*\):[0-9]*:\([0-9]*\)/${USER}:\1:${USER_UID}:\2/" /etc/passwd
        CHANGED="1"
    fi

    ## Change ownership of user's files
    if [ ! -z "$CHANGED" ]; then
        find / \
            \( -uid "${OLD_UID}" -o -gid "${OLD_GID}" \) -not \
            \( -path /proc\* -o -path /tmp\* \) \
            -exec chown "${USER_UID}:${USER_GID}" {} \;
    fi
}

run_as_other_user_if_needed() {
    if [[ "$(id -u)" == "0" ]]; then
        # If running as root, drop to specified UID and run command
        exec chroot --userspec=${USER_UID} / "${@}"
    else
        # Either we are running in Openshift with random uid and are a member of the root group
        # or with a custom --user
        exec "${@}"
    fi
}

function init()
{
    case "$SERVICE" in
        "scan-button")
            echo "Running scan-button daemon."
            ;;

        "scan-processor")
            echo "Running scan-processor daemon."
            ;;

        *)
            echo "Fatal: SERVICE environment variable must be 'scan-button' or 'scan-processor'" 1>&2
            exit 1
            ;;
    esac

    # Run the service. The container exits
    # when the service dies for any reason.
    cd "/srv/$SERVICE" && ./run
}

UDEV=$(echo "$UDEV" | awk '{print tolower($0)}')

case "$UDEV" in
	'1' | 'true')
		UDEV='on'
	;;
esac

set_uid_gid
start_udev
init "$@"



