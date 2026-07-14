# web-scanner
Auto ffuf command with 3 wordlists. Outputs to HTML in the end. For lazy, by lazy.

seclists must be installed beforehand.
```
sudo apt update
sudo apt install seclists
```

Usage:
```
./scan.sh URL
```

Example:
```
./scan.sh http://10.10.2.3
./scan.sh http://10.10.2.3/bin/
```

it will add FUZZ in the ffuf command at the end
```
http://10.10.2.3/FUZZ
http://10.10.2.3/bin/FUZZ
```

It will create a report directory with a report html file such as follows:
```
ffuf_192.168.133.112_3000_20260710_151902
  192.168.133.112_3000_common.txt            192.168.133.112_3000_raft_files.txt
  192.168.133.112_3000_raft_directories.txt  report_192.168.133.112_3000.html
```
These are the wordlists:
```
/usr/share/seclists/Discovery/Web-Content/common.txt
/usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt
/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt
(Note that raft-large-files search is made with the extensions: .html,.php,.log,.txt,.bak,.zip)
```
