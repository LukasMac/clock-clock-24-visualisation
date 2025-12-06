# ClockClock24 Screensaver

A macOS screensaver that displays the current time using a grid of animated 3D clocks, inspired by the famous [ClockClock24](https://clockclock24.com/) installation by Humans since 1982.

![ClockClock24 Preview](preview-image.png)

## Features

- **3D Clock Grid**: 24 individual clocks arranged in a 3×8 grid, each with animated hour and minute hands
- **Real-time Display**: Shows the current time in HHMM format using clock positions to form digits
- **Photorealistic Rendering**: Uses ARKit/RealityKit with sophisticated lighting and materials
- **Smooth Animations**: Clocks transition smoothly between digits with easing functions
- **Performance Optimized**: Optimized for 60 FPS animation with efficient rendering

## How It Works

Each pair of columns in the clock grid represents one digit of the time (HHMM). The position of each clock's hands creates the visual representation of the digits 0-9. For example:

- **12:34** would show "1" "2" "3" "4" across the grid
- Each clock's hands are positioned at specific angles to form the digit shapes

The screensaver continuously updates every minute to display the current time.

## Performance Considerations

⚠️ **Note**: This screensaver requires significant GPU resources due to the 3D rendering and real-time lighting calculations. On some systems, it may cause:

- Increased CPU/GPU usage
- Higher power consumption
- Potential overheating on lower-end hardware

Consider this when deploying on multiple machines or in enterprise environments.

## Building and Installation

### Requirements

- macOS 11.0+
- Xcode 12.0+
- Swift 5.3+

### Building the Screensaver

1. Open `ClockClock24.xcodeproj` in Xcode
2. Select the "ClockClock24" target
3. Build the project (⌘B)
4. The screensaver will be built to `~/Library/Screen Savers/ClockClock24.saver`

### Building the Preview App

1. Open `ClockClock24.xcodeproj` in Xcode
2. Select the "Preview" target
3. Run the app (⌘R)

The Preview app allows you to test the screensaver functionality in a windowed environment with additional controls.

## Preview App Controls

When running the Preview app:

- **Number keys (0-9)**: Test digit animations by pressing number keys
- **= key**: Reset all clocks to 12 o'clock position

## Technical Architecture

### Core Components

- **`ClockScreenSaverView`**: Main screensaver view that handles animation timing and time updates
- **`ClockGridView`**: Manages the 3D scene with ARView, lighting, and camera setup
- **`ClockOrchestrator`**: Coordinates clock hand positions and animations across the grid
- **`ClockEntity`**: Individual 3D clock model with hand animation

### Rendering Pipeline

1. **3D Models**: Clocks are loaded from USDZ files with physically-based materials
2. **Lighting Setup**: Multi-light system with key, fill, and rim lights plus ray-traced shadows
3. **Animation**: 60 FPS updates with smooth easing transitions between time changes
4. **Performance**: Frame rate limiting and efficient scene management

### Lighting Configuration

The screensaver uses a carefully tuned lighting setup:

- **Key Light**: Main directional light with ray-traced shadows
- **Fill Light**: Soft frontal illumination
- **Rim Light**: Subtle edge definition
- **Spot Light**: Alternative high-quality shadow option

## Customization

The lighting and material properties can be adjusted in `ClockGridView.swift` in the `SceneConfig` struct. When running the Preview app, debug controls are available for real-time lighting adjustments.

## Troubleshooting

### High CPU/GPU Usage

If the screensaver uses too many resources:

1. Check your macOS version (11.0+ required)
2. Ensure your GPU drivers are up to date
3. Consider reducing the grid size in `ClockGridView.columns` and `ClockGridView.rows`
4. Try disabling ray-traced shadows by modifying the lighting setup

### Build Issues

- Ensure you're using Xcode 12.0 or later
- Check that ARKit/RealityKit frameworks are properly linked
- Verify USDZ model files are included in the bundle

## License

This project is provided as-is for educational and entertainment purposes.

## Credits

- Original ClockClock24 concept by Humans since 1982
- Screensaver implementation inspired by Robert Tolar Haining's blog post on [tolar.town](https://tolar.town/posts/2020/04/13/screensavers/)
- 3D clock models and rendering by the project contributors
