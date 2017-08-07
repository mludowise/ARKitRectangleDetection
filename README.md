# ARKit + Vision for Rectangle Detection

This project demonstrates how to use Apple's Vision library to identify rectangles and model them in 3D using ARKit.

[![View Demo](screenshot.png)](https://youtu.be/57rLJlsp8YM)

[🎦 View Demo on YouTube](https://youtu.be/57rLJlsp8YM)

## Background
If you're not already familiar with the [ARKit](https://developer.apple.com/documentation/arkit/understanding_augmented_reality) and [Vision](https://developer.apple.com/documentation/vision) libraries, it's worth the time to read Apple's overviews on how to use them. There are also some great tutorials out there to get up to speed. I went through the following in a couple hours to get acquainted with them myself:
- [ARKit Tutorial: Simple Augmented Reality Game](https://www.youtube.com/watch?v=R8U8rGdMop4) by [Brian Advent](https://github.com/brianadvent/)
  - The basics of displaying items in space and performing hitTests.
- [ARKit By Example — Part 2: Plane Detection + Visualization](https://blog.markdaws.net/arkit-by-example-part-2-plane-detection-visualization-10f05876d53) by [Mark Dawson](https://github.com/markdaws)
  - How horizontal planes and feature points work in ARKit.
- [ARKit + Vision: An intriguing combination](https://dev.to/osterbergjordan/arkit--vision-an-intriguing-combination) by [Jordan Osterberg](https://github.com/JordanOsterberg)
  - Using Vision models to correlate them with realy objects in ARKit.
  - More information about horizontal planes & feature points in ARKit.

## How it Works
The `findRectangle(locationInScene location: CGPoint, frame currentFrame: ARFrame)` method inside of `ViewController.swift` uses the location the user touched on the screen and the current frame from ARKit to find any rectangles in the current frame.

The custom `PlaneRectangle` class converts the corners returned by the `VNRectangleObservation` into 2D coordinates inside of `sceneView` and performes a `hitTest` on each of the corners to find where they intersect with a plane inside of the scene and calculates the rectangles dimensions, position, and orientation on the plane.

The `RectangleNode` class creates a `SCNPlane` from dimensions calculated in `PlaneRectangle` which is then added to the scene.

It's worth noting that the rectangle's position and dimensions can only be calculated if ARKit has found a horizontal plane underneath the rectangle and if at least 3 corners of the rectangle are on that plane.

## To Run
1. Prerquisites: You must have a device running iOS 10 and XCode 9. Both of these are currently in beta but are available via the [Apple Developer portal](https://developer.apple.com/download/).
2. Download the source code for this project and open the project in XCode 9.
3. Change the Bundle Identifier and Team to your own unique identifier and team. Note that this project does not require a developer license to run on a phone, so you can use a personal team.
4. Run in XCode on your device.
