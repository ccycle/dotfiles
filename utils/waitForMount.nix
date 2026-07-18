# Shell snippet that blocks until `mountPoint` is an actual mount point.
# A bare `[ -d ... ]` test is not sufficient: if a service once started
# while the volume was absent, a stale directory of the same name exists
# on the internal disk and would pass the -d test.
mountPoint: ''
  until /sbin/mount | /usr/bin/grep -q " on ${mountPoint} ("; do
    echo "Waiting for volume ${mountPoint} to be mounted..."
    sleep 10
  done
  echo "Volume ${mountPoint} is mounted."
''
