import PackageDescription

let package = Package(
    name: "Parsey",
    dependencies: [
        .Package(url: "https://github.com/rxwei/Funky", majorVersion: 2)
    ]
)
