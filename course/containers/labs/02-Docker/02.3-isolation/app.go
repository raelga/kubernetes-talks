package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
)

const listenAddr = ":9999"

type user struct {
	name string
	uid  int
	gid  int
}

type proc struct {
	pid  int
	comm string
}

func readUsers() ([]user, error) {
	data, err := os.ReadFile("/etc/passwd")
	if err != nil {
		return nil, err
	}

	users := make([]user, 0, 32)
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.Split(line, ":")
		if len(fields) < 4 {
			continue
		}
		uid, err := strconv.Atoi(fields[2])
		if err != nil {
			continue
		}
		gid, err := strconv.Atoi(fields[3])
		if err != nil {
			continue
		}
		users = append(users, user{name: fields[0], uid: uid, gid: gid})
	}
	return users, nil
}

func readPIDs() ([]proc, error) {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil, err
	}

	procs := make([]proc, 0, len(entries))
	for _, entry := range entries {
		pid, err := strconv.Atoi(entry.Name())
		if err != nil {
			continue
		}
		comm, err := os.ReadFile(fmt.Sprintf("/proc/%d/comm", pid))
		if err != nil {
			procs = append(procs, proc{pid: pid})
			continue
		}
		procs = append(procs, proc{pid: pid, comm: strings.TrimSpace(string(comm))})
	}
	sort.Slice(procs, func(i, j int) bool { return procs[i].pid < procs[j].pid })
	return procs, nil
}

// Index - Summary of who this process runs as and what it can see.
func Index(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	users, usersErr := readUsers()
	procs, pidsErr := readPIDs()

	hostname, _ := os.Hostname()
	fmt.Fprintf(w, "uid=%d gid=%d hostname=%s\n", os.Getuid(), os.Getgid(), hostname)
	if usersErr != nil {
		fmt.Fprintf(w, "users=error (%v)\n", usersErr)
	} else {
		fmt.Fprintf(w, "users=%d\n", len(users))
	}
	if pidsErr != nil {
		fmt.Fprintf(w, "pids=error (%v)\n", pidsErr)
	} else {
		fmt.Fprintf(w, "pids=%d\n", len(procs))
	}
	fmt.Fprintf(w, "\nGET /users\taccounts from /etc/passwd\nGET /pids\tprocesses from /proc\n")
}

// Users - Lists the accounts found in /etc/passwd as uid, gid and name.
func Users(w http.ResponseWriter, r *http.Request) {
	users, err := readUsers()
	if err != nil {
		http.Error(w, "cannot read /etc/passwd: "+err.Error(), http.StatusInternalServerError)
		return
	}

	for _, u := range users {
		fmt.Fprintf(w, "%d\t%d\t%s\n", u.uid, u.gid, u.name)
	}
}

// PIDs - Lists the PIDs found in /proc. Inside a container this is the
// container's PID namespace, unless it was started with --pid=host.
func PIDs(w http.ResponseWriter, r *http.Request) {
	procs, err := readPIDs()
	if err != nil {
		http.Error(w, "cannot read /proc: "+err.Error(), http.StatusInternalServerError)
		return
	}

	for _, p := range procs {
		if p.comm == "" {
			fmt.Fprintf(w, "%d\n", p.pid)
			continue
		}
		fmt.Fprintf(w, "%d\t%s\n", p.pid, p.comm)
	}
}

func main() {
	http.HandleFunc("/", Index)
	http.HandleFunc("/users", Users)
	http.HandleFunc("/pids", PIDs)

	log.Println("Listening at " + listenAddr + "...")
	err := http.ListenAndServe(listenAddr, nil)

	if err != nil {
		log.Fatal("Server ended, reason: ", err)
	}
}
