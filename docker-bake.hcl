variable "REPO" {
	default = "tonistiigi/bpftool"
}

group "default" {
	targets = ["bpftool"]
}

target "bpftool" {
	output = ["."]
}

target "release" {
	platforms = ["linux/amd64", "linux/arm64", "linux/arm", "linux/ppc64le", "linux/riscv64", "linux/s390x"]
	tags = [REPO]
}