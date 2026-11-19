# Cgroups v2: memory limits

This is the cgroups v2 alternative to [the cgroups v1 exercise](README.md#2-cgroups). Run it on the Kubernetes Academy EC2 instance, not your laptop. It uses systemd to create a temporary cgroup; it does not require `cgcreate` or `cgexec`.

## 1. Check the hierarchy

```bash
stat -fc %T /sys/fs/cgroup
```

`cgroup2fs` means this is the unified cgroups v2 hierarchy. In v1, controllers such as memory and CPU can have separate hierarchies; v2 uses one hierarchy and different control files.

## 2. Start a limited shell

```bash
sudo systemd-run --scope -p OOMPolicy=continue -p MemoryMax=50M -p MemorySwapMax=0 bash
```

`systemd-run --scope` puts the shell and its descendants in a temporary cgroup. `MemoryMax=50M` sets its total memory limit; `MemorySwapMax=0` disables swap for the group. `OOMPolicy=continue` keeps the scope running when a process is killed for exceeding the limit. The shell itself and Python both count towards the limit. This does not create a PID namespace.

Inside that shell, find its cgroup and read the limit:

```bash
CGROUP=$(awk -F: '$1 == "0" {print $3}' /proc/self/cgroup)
cat "/sys/fs/cgroup${CGROUP}/memory.max"
cat "/sys/fs/cgroup${CGROUP}/memory.current"
```

`memory.max` is the hard limit in bytes; `memory.current` is current usage. The cgroup path is relative to `/sys/fs/cgroup`.

## 3. Exercise the limit

Still inside the limited shell:

```bash
python3 -c 'x = bytearray(20_000_000)'
python3 -c 'x = bytearray(100_000_000)'
```

The smaller allocation should complete. The larger one exceeds the cgroup limit and may be killed or fail allocation. The exact threshold depends on all memory charged to the cgroup. Inspect events:

```bash
cat "/sys/fs/cgroup${CGROUP}/memory.events"
```

`max` counts attempts to exceed the limit; `oom` counts out-of-memory events and `oom_kill` counts killed processes. If the shell itself is killed, the scope disappears and these counters are no longer available.

## 4. Combine with namespaces

From the limited shell, start a child in a PID namespace:

```bash
unshare --fork --pid --mount-proc bash
ps aux
cat /proc/self/cgroup
exit
```

The child sees its own PID namespace but remains in the same memory cgroup. Namespace isolation and resource limits are independent. `--fork` starts Bash inside the new PID namespace; `--mount-proc` supplies the corresponding `/proc` view.

## 5. Clean up

```bash
exit
```

Exiting the limited shell releases the temporary systemd scope. This does not destroy the EC2 instance; follow its Terraform instructions when the lab is finished.
