# ScanImage Z-Control (Foilview)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2020b+-blue.svg)](https://www.mathworks.com/products/matlab.html)

A MATLAB-based microscope stage control application with real-time focus metric calculation and automated Z-stepping capabilities for ScanImage integration.

## Overview

Foilview is a comprehensive Z-control system designed for microscopy applications that provides:

- **Real-time stage control** with precise X, Y, Z positioning
- **Focus metric calculation** with live visualization
- **Automated Z-stepping** with configurable parameters
- **MJC3 joystick integration** for intuitive manual control
- **ScanImage connectivity** for seamless microscopy workflow
- **Bookmark management** for position tracking and metadata logging
- **Comprehensive UI** with tabbed interface and real-time plotting

## Features

### Core Functionality
- **Position Management**: Real-time X, Y, Z position display and control
- **Focus Metrics**: Advanced focus metric calculation and visualization
- **Auto-stepping**: Automated Z-stepping with customizable parameters
- **Manual Controls**: Precise manual stage movement capabilities
- **Status Monitoring**: Connection status and system health monitoring

### Hardware Integration
- **ScanImage Integration**: Direct connection to ScanImage microscopy software
- **MJC3 Joystick Support**: Hardware joystick control with calibration
- **Stage Control**: Compatible with various microscope stage systems

### User Interface
- **Tabbed Interface**: Organized UI with dedicated tabs for different functions
- **Real-time Plotting**: Live visualization of metrics during auto-stepping
- **Tools Window**: Additional utilities and advanced features
- **Bookmark System**: Save and recall important positions

## Installation

### Prerequisites
- MATLAB R2020b or later
- ScanImage software (for microscopy integration)
- Compatible microscope stage hardware
- Optional: MJC3 joystick for manual control

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/guitarbeat/scanimage-zcontrol.git
   cd scanimage-zcontrol
   ```

2. Add the application to your MATLAB path:
   ```matlab
   addpath(genpath('src'))
   ```

3. Launch the application:
   ```matlab
   foilview
   ```

## Usage

### Basic Operation
1. **Start the application**: Run `foilview` in MATLAB
2. **Connect to ScanImage**: Use the connection controls to establish ScanImage link
3. **Manual Control**: Use the position controls or MJC3 joystick for manual positioning
4. **Auto-stepping**: Configure and run automated Z-stepping sequences
5. **Monitor Metrics**: View real-time focus metrics and plots

### Key Components

#### Position Display
- Real-time X, Y, Z coordinate display
- Current focus metric value
- Connection status indicators

#### Manual Controls
- Step size configuration
- Directional movement buttons
- Direct position input

#### Auto Controls
- Z-step range and increment settings
- Start/stop automated stepping
- Progress monitoring

#### HID Controls
- MJC3 joystick calibration
- Sensitivity adjustments
- Enable/disable joystick control

## Architecture

The application follows a layered architecture pattern:

```
UI Layer (Views) → Controllers → Services → Managers → Hardware
```

### Directory Structure
- `src/foilview.m` - Main application entry point
- `src/controllers/` - Application controllers and orchestration
- `src/services/` - Business logic and service layer
- `src/managers/` - Data and resource management
- `src/hardware/` - Hardware interface abstraction
- `src/views/` - UI components and views
- `src/ui/` - UI factory and component system
- `src/utils/` - Utility functions and helpers
- `src/config/` - Configuration files

For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Development

### Getting Started
1. Review the [ARCHITECTURE.md](ARCHITECTURE.md) for system design
2. Check [LESSONS_LEARNED.mdc](LESSONS_LEARNED.mdc) for development insights
3. See [todo.md](todo.md) for current development priorities

### Development Tools
The `dev-tools/` directory contains utilities for:
- Code analysis and linting
- Development workflow automation
- Testing and validation tools

### Testing
- Unit tests for core components
- Integration tests for hardware interfaces
- UI component validation

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:
- Code style and conventions
- Development workflow
- Testing requirements  
- Pull request process

## Roadmap

Current development priorities (see [todo.md](todo.md) for complete list):
- [ ] Architecture refactoring for improved modularity
- [ ] Enhanced testing framework
- [ ] Configuration-driven UI system
- [ ] Comprehensive documentation
- [ ] Performance optimizations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For questions, issues, or contributions:
- Open an [issue](https://github.com/guitarbeat/scanimage-zcontrol/issues) for bug reports or feature requests
- Check existing issues for known problems and solutions
- Review the documentation and architecture guides

## Acknowledgments

- ScanImage team for microscopy software integration
- MATLAB community for development tools and libraries
- Contributors and users who provide feedback and improvements