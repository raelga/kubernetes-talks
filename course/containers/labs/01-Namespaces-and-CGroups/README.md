# Container Primitives

This lab introduces the foundational primitives used to implement containers in Linux: **Namespaces** and **Control Groups (cgroups)**.

---

## Namespaces

Namespaces provide isolation for processes. By default, any process inherits its parent's namespace. However, using the `unshare` command, we can create processes in isolated namespaces.

### `unshare` - Run Program with Unshared Namespaces

```bash
man unshare
```

Excerpt from the man page:

```
UNSHARE(1)                                                 User Commands                                                UNSHARE(1)

NAME
       unshare - run program with some namespaces unshared from parent
```

### Example: Isolating the PID Namespace

Run a process with an isolated PID and mount namespace:

```bash
sudo unshare --fork --pid --mount-proc bash
```

Inside the new shell:

```bash
# ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0   8968  4044 pts/0    S    10:44   0:00 bash
root         9  0.0  0.0  10620  3272 pts/0    R+   10:45   0:00 ps aux
```

Notice that the `bash` process is PID 1 — the first process in this isolated namespace.

### Without PID Namespace Isolation

```bash
sudo unshare --fork --mount-proc bash
```

Now, the process is not isolated in the PID namespace:

```bash
# ps aux | head -n5
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0 169580 12820 ?        Ss   06:34   0:02 /sbin/init
root         2  0.0  0.0      0     0 ?        S    06:34   0:00 [kthreadd]
root         3  0.0  0.0      0     0 ?        I<   06:34   0:00 [rcu_gp]
root         4  0.0  0.0      0     0 ?        I<   06:34   0:00 [rcu_par_gp]

# ps
    PID TTY          TIME CMD
  26078 pts/0    00:00:00 sudo
  26079 pts/0    00:00:00 unshare
  26080 pts/0    00:00:00 bash
  26114 pts/0    00:00:00 ps
```

---

## Control Groups (cgroups)

Control groups allow resource limitation and accounting for groups of processes.

### Installing cgroup tools

```bash
sudo apt-get install cgroup-tools
```

### Creating a Memory cgroup

```bash
sudo cgcreate -g memory:upc
```

This creates a new directory with tunables at:

```bash
ls /sys/fs/cgroup/memory/upc/
```

Sample output:

```
cgroup.procs                     memory.limit_in_bytes            memory.usage_in_bytes
memory.failcnt                  memory.max_usage_in_bytes        tasks
memory.kmem.limit_in_bytes      memory.oom_control
...
```

### Setting a Memory Limit

Set a 25MB memory limit:

```bash
sudo sh -c 'echo 25000000 > /sys/fs/cgroup/memory/upc/memory.limit_in_bytes'
```

### Running a Process in the cgroup

```bash
sudo cgexec -g memory:upc bash
```

Run a memory-intensive command to test the limit:

```bash
echo {1..1000000000}
```

That command will consume a lot of memory. If it exceeds the limit, you will see:

```
Killed
```

The process is terminated due to OOM (Out Of Memory). Check logs:

```bash
sudo tail -n1 /var/log/syslog
```

Example output:

```
Jun 21 11:14:06 box kernel: [  170.336256] Memory cgroup out of memory: Killed process 18407 (bash) total-vm:7840348kB, ...
```

---

## Combining cgroups and namespaces

You can isolate a process using both cgroups and namespaces:

```bash
sudo cgexec -g memory:upc unshare -uinpUrf --mount-proc --pid sh -c "/bin/hostname upc && bash"
```

Now inside the shell, test isolation and hostname:

```bash
echo Hello from a Linux Container
```

Expected output:

```
Hello from a Linux Container
```

```bash
hostname
```

Expected output:

```
upc
```

---

## Summary

- **Namespaces** isolate process views of the system (e.g., PIDs, mount points, networking).
- **cgroups** restrict resource usage (e.g., memory, CPU).
- These primitives are the foundation of containers.

---

```

```
