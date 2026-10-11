#!/usr/bin/env python3
"""Small read-only status label for Hyprlock."""
import subprocess


def status():
    parts=[]
    try:
        result=subprocess.run(['nmcli','-t','-f','TYPE,STATE','device','status'],capture_output=True,text=True,timeout=2)
        states=[line.split(':',1)[1] for line in result.stdout.splitlines() if line.startswith('wifi:')]
        if states:parts.append('' if 'connected' in states else '󰤭')
    except (OSError,subprocess.TimeoutExpired):pass
    return '   '.join(parts)


if __name__=='__main__':print(status())
