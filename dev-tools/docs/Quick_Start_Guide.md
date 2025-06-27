# Z-Stage Control - Quick Start Guide

## 1. Launch the Application

```matlab
% Add src directory to MATLAB path (one time setup)
addpath('path/to/scanimage-zcontrol/src')

% Launch the application
app = ZStageControlApp();
```

## 2. Connection Status

- **Green "Connected to ScanImage"**: Ready for hardware control
- **Orange "Simulation Mode"**: Testing mode (no hardware needed)
- **Red messages**: Check ScanImage/Motor Controls setup

## 3. Basic Movement (Manual Control Tab)

1. **Select step size** from dropdown: 0.1, 0.5, 1, 5, 10, or 50 μm
2. **Click ▲** to move up or **▼** to move down
3. **Watch position display** update in real-time
4. **Click ZERO** to reset current position to 0 μm

## 4. Find Focus Automatically (Auto Step Tab)

1. **Set parameters**:
   - Step Size: 2 μm (good starting point)
   - Steps: 20 (covers 40 μm range)
   - Delay: 0.5 seconds
2. **Enable "Record Metrics"** checkbox ✓
3. **Choose direction**: ▲ (up) or ▼ (down)
4. **Click START** to begin scan
5. **Watch plot expand** automatically
6. **Find peak** in Standard Deviation (blue line) for best focus

## 5. Save Important Positions (Bookmarks Tab)

1. **Navigate to desired position** (manual or auto)
2. **Enter a label** (e.g., "Best Focus", "Sample Surface")
3. **Click MARK** to save
4. **Select from list** and **click GO TO** to return later

## 6. Metrics Information

- **Standard Deviation (blue)**: Best for focus detection - peaks at sharp focus
- **Mean (orange)**: Average brightness - useful for exposure checking  
- **Max (yellow)**: Peak brightness - useful for saturation detection

## 7. Plot Features

- **Automatically expands** during auto-stepping with metrics
- **Click Expand/Collapse** to manually toggle plot view
- **Clear** to reset plot data
- **Export** to save metrics data as .mat file

## 8. Common Workflows

### Quick Manual Focus
```
Manual Tab → Select 1 μm step → Use ▲/▼ → Watch Std Dev increase
```

### Automated Focus Search  
```
Auto Tab → 2 μm, 20 steps, ✓ Record → START → Find peak in plot
```

### Position Management
```
Navigate to focus → Bookmarks Tab → Label + MARK → Later: Select + GO TO
```

## 9. Troubleshooting

| Issue                             | Solution                                       |
| --------------------------------- | ---------------------------------------------- |
| Orange "Simulation Mode"          | Start ScanImage, open Motor Controls window    |
| "Motor Controls window not found" | Window → Motor Controls in ScanImage           |
| Stage not moving                  | Check ScanImage not busy/acquiring             |
| Poor focus detection              | Try different step sizes, ensure good lighting |

## 10. Tips for Best Results

- **Start with larger steps** (5-10 μm) for coarse positioning
- **Use smaller steps** (0.5-2 μm) near focus for precision
- **Standard Deviation metric** typically works best for focus
- **Save positions** before major movements to enable easy return
- **Enable metrics recording** to visualize focus quality vs position

---

**Need more help?** See the full README.md or Z-Stage_Control_Documentation.md for detailed information. 