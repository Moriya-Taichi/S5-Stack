import Nido

// S5's deployment adapter uses Nido's public provider API. Nido remains an independent package.
enum DockerImage: ResourceKind { static let terraformType = "docker_image" }
enum DockerVolume: ResourceKind { static let terraformType = "docker_volume" }
enum DockerContainer: ResourceKind { static let terraformType = "docker_container" }

// An attached one-shot container must succeed before dependent services are started.
struct SuccessfulMigration: Component {
    let container: Resource<DockerContainer>
    var blocks: [Block] {
        var block = container.block
        block.literalAttributes["lifecycle"] = .object([
            "postcondition": .array([.object([
                "condition": .string("${self.exit_code == 0}"),
                "error_message": .string("Database migration failed. Inspect the migration container logs before retrying.")
            ])])
        ])
        return [block]
    }
}

let imageName = Variable<String>("image", description: "Prebuilt image: use a unique tag per release or a registry digest.")
let docker = Provider(ProviderRequirement("docker", source: "kreuzwerker/docker", version: "= 4.6.0"))
let image = Resource<DockerImage>("app", attributes: [
    "name": imageName.value.erased,
    "keep_locally": .literal(true)
], provider: docker)
let data = Resource<DockerVolume>("data", attributes: [
    "name": .literal("__PROJECT_NAME__-data")
], provider: docker)
let volumes: AnyValue = .array([.object([
    "volume_name": data.unsafeAttribute("name", as: String.self).erased,
    "container_path": .literal("/data")
])])
let migration = Resource<DockerContainer>("migration", attributes: [
    "name": .literal("__PROJECT_NAME__-migration"),
    "image": image.unsafeAttribute("image_id", as: String.self).erased,
    "command": .literal(["migrate", "--env", "production", "--yes"]),
    "volumes": volumes,
    "must_run": .literal(false),
    "attach": .literal(true)
], provider: docker)
let app = Resource<DockerContainer>("app", attributes: [
    "name": .literal("__PROJECT_NAME__-app"),
    "image": image.unsafeAttribute("image_id", as: String.self).erased,
    "volumes": volumes,
    "restart": .literal("unless-stopped"),
    "ports": .array([.object([
        "internal": .literal(8080), "external": .literal(8080), "ip": .literal("127.0.0.1")
    ])]),
    "healthcheck": .array([.object([
        "test": .literal(["CMD", "curl", "--fail", "--silent", "http://127.0.0.1:8080/ready"]),
        "interval": .literal("5s"), "timeout": .literal("3s"), "retries": .literal(12)
    ])]),
    "wait": .literal(true),
    "wait_timeout": .literal(90)
], provider: docker, options: .init(dependsOn: [migration.dependency]))

try Stack("__PROJECT_NAME__") {
    imageName
    docker
    image
    data
    SuccessfulMigration(container: migration)
    app
    Output("url", value: Value<String>.literal("http://127.0.0.1:8080"))
}.export()
