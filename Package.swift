// swift-tools-version: 5.8
import PackageDescription
let package = Package(
    name: "MCPlus", platforms: [.macOS(.v13)],
    products: [.executable(name:"MCPlus",targets:["MCPlus"])],
    dependencies: [.package(url:"https://github.com/sparkle-project/Sparkle",exact:"2.10.0")],
    targets: [.executableTarget(name:"MCPlus",dependencies:[.product(name:"Sparkle",package:"Sparkle")])]
)
