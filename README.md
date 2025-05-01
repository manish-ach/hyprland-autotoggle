
# hyprland-autotoggle

**hyprland-autotoggle** is a Hyprland event-based script system to control visibility or execution of dock, widgets, or panels based on window activity in the current workspace.

This script, `nwg-dock-controller.sh`, specifically toggles the visibility of `nwg-dock-hyprland` to show it only when the active workspace has **no open windows**. It automatically hides the dock when a window exists and restores it when the workspace is empty.

It also uses socat to register workspace switches to avoid the functionality of the toggle due to workspace updates. The guide assumes you are on arch using the latest supported version of hyprland. For other distros use your distro specific package manager. The script is targeted for hyprland so it likely wont work on other WM but even if it somehow works it still is not supported for them outside hyprland.

---

## 🛠️ Setup Instructions

### 0. Install dependencies
```bash
sudo pacman -S socat
```

### 1. Installation
Clone or copy the script to your Hyprland configuration directory:
```bash
git clone git@github.com:manish-ach/hyprland-autotoggle.git
```

### 2. Create the scripts dir inside hypr
```bash
mkdir -p ~/.config/hypr/scripts
```

### 3. Copy or move the script to the script dir 
```bash
cp nwg-dock-controller.sh ~/.config/hypr/scripts/
```

### 4. Make the script executable
```bash
chmod +x ~/.config/hypr/scripts/nwg-dock-controller.sh
```

### 5. setup the autostart
In the hyprland.conf (or autostart.conf) file generally under autostart section write
```bash
exec-once = ~/.config/hypr/scripts/nwg-dock-controller.sh
```
