my simple script for base configuration of a VPC server on Ubuntu 22.04
This script performs a **basic server hardening + setup**:

User Setup

* Creates a new user
* Adds the user to the `sudo` group 
* Sets a password (for sudo usage)

SSH Hardening

* Adds your public SSH key
* Disables password authentication
* Disables root login
* Changes default SSH port
* Configures keepalive settings

Firewall (iptables)

* Allows:
  * SSH (custom port)
  * HTTP (80)
  * HTTPS (443)
* Blocks everything else by default

System

* Restarts SSH service
* Reboots server (after confirmation)

Variables (Interactive Input)

The script will **ask you to enter values** during execution:

| Variable    | Description                             |
| ----------- | --------------------------------------- |
| `NEW_USER`  | Name of the new user to create          |
| `USER_PASS` | Password for the user (used for `sudo`) |
| `SSH_PORT`  | Custom SSH port (default: `51532`)      |
| `PUB_KEY`   | Your public SSH key (paste it)          |

---

## 🛠️ Usage

Pretty simple, trust me. Here you are! 😄

```bash
nano setup_server.sh
```

Paste the script inside, then:

```bash
chmod +x setup_server.sh
sudo ./setup_server.sh
```

---

After script runs:

* SSH password login is **disabled**
* Only **SSH key authentication** works

Make sure your public key is correct!
Before Reboot

The script will remind you, but seriously:

**Open a new terminal and test SSH access BEFORE reboot**

```bash
ssh -p <your_port> <your_user>@<your_server_ip>
```

