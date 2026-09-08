"""Check the synthesized Nido contract; Terraform validates provider schemas in CI."""
import json
import sys

with open(sys.argv[1]) as source:
    config = json.load(source)
assert config["terraform"]["required_providers"]["docker"] == {
    "source": "kreuzwerker/docker", "version": "= 4.6.0"
}
resources = config["resource"]
app = resources["docker_container"]["app"]
migration = resources["docker_container"]["migration"]
assert app["depends_on"] == ["docker_container.migration"]
assert app["image"] == migration["image"] == "${docker_image.app.image_id}"
assert app["volumes"] == migration["volumes"]
assert app["volumes"][0]["volume_name"] == "${docker_volume.data.name}"
assert app["ports"][0]["ip"] == "127.0.0.1"
assert app["wait"] is True
assert migration["attach"] is True and migration["must_run"] is False
assert migration["lifecycle"]["postcondition"][0]["condition"] == "${self.exit_code == 0}"
assert "default" not in config["variable"]["image"]
print("Nido deployment contract verified")
