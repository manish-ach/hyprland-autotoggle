
#!/bin/bash

# Configuration
LOCK_FILE="/tmp/nwg-dock-hyprland-controller.lock"
LOG_FILE="/tmp/nwg-dock-hyprland-controller.log"
DEBOUNCE_TIME=0.2
STARTUP_DELAY=2  # Delay before starting dock to ensure Hyprland is ready

# Enable logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Clean up on exit
cleanup() {
    log "Script terminating, cleaning up"
    rm -f "$LOCK_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Initialize log
> "$LOG_FILE"
log "Starting nwg-dock-hyprland controller"

# Function to check if dock is running
is_dock_running() {
    pgrep -f "nwg-dock-hyprland" > /dev/null
    return $?
}

# Function to start the dock
start_dock() {
    if ! is_dock_running; then
        log "Starting nwg-dock-hyprland"
        nwg-dock-hyprland -r &
        sleep 1  # Give dock time to initialize
    else
        log "nwg-dock-hyprland is already running"
    fi
}

# Function to update dock visibility
update_dock_visibility() {
    # Acquire lock to prevent parallel execution
    if [ -e "$LOCK_FILE" ] && kill -0 $(cat "$LOCK_FILE") 2>/dev/null; then
        log "Another instance is running, skipping"
        return
    fi
    
    # Create lock with current PID
    echo $$ > "$LOCK_FILE"
    
    # Make sure dock is running
    if ! is_dock_running; then
        log "Dock not running, restarting it"
        start_dock
    fi
    
    # Small delay to let Hyprland update its state
    sleep "$DEBOUNCE_TIME"
    
    # Get the active workspace ID
    workspace_id=$(hyprctl activeworkspace -j | jq -r '.id' 2>/dev/null)
    if [ -z "$workspace_id" ] || [ "$workspace_id" = "null" ]; then
        log "Could not determine workspace ID"
        rm -f "$LOCK_FILE"
        return
    fi
    
    # Count windows in the active workspace
    window_count=$(hyprctl clients -j | jq "[.[] | select(.workspace.id == $workspace_id)] | length" 2>/dev/null)
    if [ -z "$window_count" ] || [ "$window_count" = "null" ]; then
        log "Could not count windows"
        rm -f "$LOCK_FILE"
        return
    fi
    
    # Check if dock should be visible
    if ! is_dock_running; then
        log "nwg-dock-hyprland is not running despite attempt to start it"
        rm -f "$LOCK_FILE"
        return
    fi
    
    # Update dock state
    if [ "$window_count" -eq 0 ]; then
        log "No windows in workspace $workspace_id, showing dock"
        pkill -RTMIN+2 -f "nwg-dock-hyprland"
    else
        log "Found $window_count windows in workspace $workspace_id, hiding dock"
        pkill -RTMIN+3 -f "nwg-dock-hyprland"
    fi
    
    # Release lock
    rm -f "$LOCK_FILE"
}

# Wait for Hyprland to initialize fully
log "Waiting $STARTUP_DELAY seconds before starting dock"
sleep "$STARTUP_DELAY"

# Start the dock initially
start_dock

# Initial visibility check
update_dock_visibility

# Listen for events
log "Starting event listener"
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    event_type=""
    if [[ "$line" == "workspace>>"* ]]; then
        event_type="workspace change"
    elif [[ "$line" == "focusedmon>>"* ]]; then
        event_type="monitor focus"
    elif [[ "$line" == "activewindow>>"* ]]; then
        event_type="window focus"
    elif [[ "$line" == "closewindow>>"* ]]; then
        event_type="window close"
    elif [[ "$line" == "createworkspace>>"* ]]; then
        event_type="workspace create"
    elif [[ "$line" == "destroyworkspace>>"* ]]; then
        event_type="workspace destroy"
    fi
    
    if [ -n "$event_type" ]; then
        log "Detected event: $event_type"
        # Run in the foreground to maintain event order
        update_dock_visibility
    fi
    
    # Monitor if dock is still running and restart if needed
    if ! is_dock_running; then
        log "Dock process died, restarting"
        start_dock
        update_dock_visibility
    fi
done
