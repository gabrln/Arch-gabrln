#!/usr/bin/env python3
import json
import subprocess
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: ToggleScratchpad.py <app_id> <spawn_command...>")
        sys.exit(1)
        
    app_id = sys.argv[1]
    spawn_cmd = sys.argv[2:]
    
    # Query current windows from niri IPC
    try:
        res = subprocess.run(["niri", "msg", "-j", "windows"], capture_output=True, text=True, check=True)
        windows = json.loads(res.stdout)
    except Exception as e:
        # If niri is not running, we cannot execute compositor messages
        print(f"Error querying niri state: {e}")
        sys.exit(1)
        
    # Find matching window and current focused window
    target_window = None
    focused_window_id = None
    for win in windows:
        if win.get("app_id") == app_id:
            target_window = win
        if win.get("is_focused"):
            focused_window_id = win.get("id")
            
    if not target_window:
        # App is not running. Spawn it.
        subprocess.Popen(spawn_cmd)
    else:
        target_id = target_window.get("id")
        if target_id == focused_window_id:
            # Scratchpad is currently active and focused: hide it.
            # Move it to a background workspace named "scratchpad".
            subprocess.run(["niri", "msg", "action", "move-window-to-workspace", "scratchpad"], check=True)
        else:
            # Scratchpad is hidden or unfocused: move to current workspace and focus it.
            subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(target_id)], check=True)
            subprocess.run(["niri", "msg", "action", "move-window-to-workspace-here"], check=True)

if __name__ == "__main__":
    main()
