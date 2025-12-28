// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "vox",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "vox",
      targets: ["vox"]
    )
  ],
  targets: [
    .executableTarget(
      name: "vox",
      path: "vox/vox",
      exclude: ["Info.plist"]
    ),
    .testTarget(
      name: "voxTests",
      dependencies: ["vox"],
      path: "vox/voxTests"
    )
  ]
)
