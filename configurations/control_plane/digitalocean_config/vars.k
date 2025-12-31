schema stepEnum:
    droplet: str = "droplet"
    image: str = "image"
    dns: str = "dns"

schema shared_schema:
    region: str
    imageName: str

shared: shared_schema = {
    region = "nyc3"
    imageName = "frps_nixos"
}

steps: stepEnum = {
    droplet = "droplet"
    image = "image"
    dns = "dns"
}
