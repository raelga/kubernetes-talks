# Linux Namespaces and Cgroups

Explore namespaces first, then cgroups, and finally combine them.

## Before you start

Use the course's [AWS Academy EC2 instance](../../../terraform/aws-academy-ec2-instance/README.md), with `sudo` and Python 3. Run these commands on the EC2 instance, not your laptop.

## 1. Namespaces

Linux namespaces give processes separate views of particular kernel resources. For example, a PID namespace isolates the process IDs a process can see. A namespace does not itself limit memory.

### `unshare`: run a program in new namespaces

Open the manual:

```bash
man unshare
```

The manual describes `unshare` as running a program with namespaces unshared from its parent.

### Example: isolate the PID namespace

First, run `ps aux` on the host to see its processes. Then start an isolated shell:

```bash
sudo unshare --fork --pid --mount-proc bash
```

- `--pid` creates a new PID namespace for child processes.
- `--fork` starts Bash as a child, so it enters that new PID namespace and becomes PID 1.
- `--mount-proc` creates a mount namespace and mounts a fresh `/proc` for the new PID namespace. Tools such as `ps` read `/proc` to show processes.

Inside the new shell, run:

```bash
ps aux
```

Bash is PID 1 in the new PID namespace; other host processes are not visible.

For example:

```text
USER   PID COMMAND
root     1 bash
root     9 ps aux
```

PIDs vary. Compare this with the host process list, then run `exit` to return to the host shell.

### Example: without PID namespace isolation

Create a mount namespace but keep the host PID namespace:

```bash
sudo unshare --fork --mount-proc bash
ps aux
exit
```

Here `ps aux` shows the host's processes because `--pid` was not specified.

## 2. Cgroups

After the cgroups slides, try the memory controller on its own. A cgroup accounts for and limits resources used by a group of processes; it does not create a PID namespace.

These commands use **cgroup v1** on the Academy instance. Cgroup v2 uses different paths and commands.

```bash
sudo apt-get update && sudo apt-get install -y cgroup-tools
```

### Create a memory cgroup

From the host shell, create a cgroup called `upc` under the memory controller:

```bash
sudo cgcreate -g memory:upc
```

Set its memory limit to 25,000,000 bytes (25 MB):

```bash
sudo sh -c 'echo 25000000 > /sys/fs/cgroup/memory/upc/memory.limit_in_bytes'
```

`sudo sh -c` runs both `echo` and the `>` redirection as root, so the shell can write to the cgroup control file.

Read the limit back:

```bash
cat /sys/fs/cgroup/memory/upc/memory.limit_in_bytes
```

Explore the control files with `ls /sys/fs/cgroup/memory/upc/`. For example, `memory.limit_in_bytes` sets the limit, `memory.usage_in_bytes` reports current usage and `memory.failcnt` counts failed charges.

The reported value can differ slightly because the kernel rounds to memory pages. The limit applies to the **whole cgroup**, including the runtime and other processes, not just the allocated array.

### Test the limit

Run two processes in the cgroup, without creating a namespace:

```bash
sudo cgexec -g memory:upc python3 -c 'x = bytearray(20_000_000)'
sudo cgexec -g memory:upc python3 -c 'x = bytearray(40_000_000)'
```

On the Academy instance, the first completed and the second was killed. The threshold depends on the runtime and other memory already charged to the group; a process can also handle an allocation failure rather than be killed.

Alternatively, start an interactive shell with `sudo cgexec -g memory:upc bash`. Run `ps aux` there: the shell shares the host PID namespace even though its memory is limited. Run `exit` to return to the host.

On this Ubuntu instance, the kernel may log OOM events in `/var/log/syslog`:

```bash
sudo grep -i 'out of memory\|killed process' /var/log/syslog
```

Log availability and messages depend on the system configuration.

## 3. Combine isolation and limits

```bash
sudo cgexec -g memory:upc unshare -uinpUrf --mount-proc --pid sh -c "/bin/hostname upc && bash"
```

The combined short flags configure `unshare`:

| Flag | Effect |
| --- | --- |
| `-u` | New UTS namespace for hostname and domain name |
| `-i` | New IPC namespace for interprocess communication resources |
| `-n` | New network namespace with its own network stack |
| `-p` | New PID namespace for child processes (also specified by `--pid`) |
| `-U` | New user namespace with separate user and group ID mappings |
| `-r` | Map the current user and group to root inside the new user namespace |
| `-f` | Fork before running the command |
| `--mount-proc` | Create a mount namespace and mount `/proc` for the PID view |

Inside the isolated shell:

```bash
hostname
ps aux
python3 -c 'x = bytearray(20_000_000)'
python3 -c 'x = bytearray(40_000_000)'
ps aux
```

- The hostname is `upc`. The first `sh -c` process is PID 1; Bash is its child.
- On the Academy instance, the 20 MB allocation completed and the 40 MB process was killed. The exact threshold depends on memory already charged to the cgroup.
- The shell survives when the Python child is killed. A process may instead handle an allocation failure itself; `Killed` is not guaranteed in every environment.

### Observe memory from another terminal

Connect to the same EC2 instance in a second terminal. While the isolated shell remains open, check:

```bash
cat /sys/fs/cgroup/memory/upc/memory.limit_in_bytes
cat /sys/fs/cgroup/memory/upc/memory.usage_in_bytes
cat /sys/fs/cgroup/memory/upc/memory.failcnt
```

Repeat the 40 MB allocation in the isolated shell, then read `memory.failcnt` again. It counts failed memory charges, **not** OOM kills.

### Inspect mounts

Inside the isolated shell, run `mount`. A mount namespace provides a separate view of mounts, but it does **not** by itself create a separate root filesystem: inherited host mounts remain visible. The next Docker filesystem lab explores image layers and container filesystems.

## Clean up

Exit the isolated shell, then from the host shell delete the cgroup:

```bash
exit
sudo cgdelete -g memory:upc
```
