variable "DOCKER_ORG" {
  default = "pmetpublic"
}

variable "VER" {
  default = "1.1"
}

target "default" {
  context = "."
  target = "final"
  tags = ["docker.io/${DOCKER_ORG}/nginx-with-pagespeed:${VER}"]
}

target "default-xplat" {
  inherits = ["default"]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
