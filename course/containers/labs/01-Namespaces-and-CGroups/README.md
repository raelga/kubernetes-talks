# Container Primitives

## Namespaces

By defaut, any process inherits their parents namespace.

With unshare, you spawn a process contained in a different namespace.

```
UNSHARE(1)                                                 User Commands                                                UNSHARE(1)

NAME
       unshare - run program with some namespaces unshared from parent
```

For example:

```
sudo unshare --fork --pid --mount-proc bash
```

```
# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   8968  4044 pts/0    S    10:44   0:00 bash
root           9  0.0  0.0  10620  3272 pts/0    R+   10:45   0:00 ps aux
```

Without the `pid` namespace.

```
sudo unshare --fork --mount-proc bash
```

We can see the PID the entire host process list.

```
# ps aux | head -n5
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0 169580 12820 ?        Ss   06:34   0:02 /sbin/init
root           2  0.0  0.0      0     0 ?        S    06:34   0:00 [kthreadd]
root           3  0.0  0.0      0     0 ?        I<   06:34   0:00 [rcu_gp]
root           4  0.0  0.0      0     0 ?        I<   06:34   0:00 [rcu_par_gp]
# ps
    PID TTY          TIME CMD
  26078 pts/0    00:00:00 sudo
  26079 pts/0    00:00:00 unshare
  26080 pts/0    00:00:00 bash
  26114 pts/0    00:00:00 ps
```

## Control Groups

```
sudo apt-get install cgroup-tools
```

We can create a new control group with:

```
sudo cgcreate -g memory:upc
```

And this will create a new directory under /sys/fs/cgroup/memory/ with all the configuration files for this control group:

```
$ ls /sys/fs/cgroup/memory/upc/
cgroup.clone_children           memory.kmem.slabinfo                memory.memsw.failcnt             memory.soft_limit_in_bytes
cgroup.event_control            memory.kmem.tcp.failcnt             memory.memsw.limit_in_bytes      memory.stat
cgroup.procs                    memory.kmem.tcp.limit_in_bytes      memory.memsw.max_usage_in_bytes  memory.swappiness
memory.failcnt                  memory.kmem.tcp.max_usage_in_bytes  memory.memsw.usage_in_bytes      memory.usage_in_bytes
memory.force_empty              memory.kmem.tcp.usage_in_bytes      memory.move_charge_at_immigrate  memory.use_hierarchy
memory.kmem.failcnt             memory.kmem.usage_in_bytes          memory.numa_stat                 notify_on_release
memory.kmem.limit_in_bytes      memory.limit_in_bytes               memory.oom_control               tasks
memory.kmem.max_usage_in_bytes  memory.max_usage_in_bytes           memory.pressure_level
```

We can set a limit of 25Mb to the UPC cgroup memory with:

```
sudo sh -c 'echo 25000000 >  /sys/fs/cgroup/memory/upc/memory.limit_in_bytes'
```

Spawn a terminal:

```
sudo cgexec -g memory:upc bash
```

Run some memory intense program in the terminal:

```
# echo {1..1000000000}
Killed
```

And the OOMkiller will kick in:

```
rael@box:~$ sudo tail -n1 /var/log/syslog
Jun 21 11:14:06 box kernel: [  170.336256] Memory cgroup out of memory: Killed process 18407 (bash) total-vm:7840348kB, anon-rss:24000kB, file-rss:3280kB, shmem-rss:0kB, UID:0 pgtables:116kB oom_score_adj:0
```

## CGroups and Namespaces

Spawning a process with both features enabled.

```
$ sudo cgexec -g memory:upc unshare -uinpUrf --mount-proc --pid sh -c "/bin/hostname upc && bash"
```

Run some commands.

```
root@upc:/home/rael/upc# echo Hello from a Linux Container
Hello from a Linux Container
```
