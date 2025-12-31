load("//rules:go-schema-kcl.bzl", "frp_schema_codegen")

def frp_codegen_groups():
    targets = []

    for name in [
        "frpc",
        "frps",
        "tcp_proxy",
    ]:
        frp_schema_codegen(
            name = "{}_kcl".format(name),
            # later you can pass args if needed
        )

        targets.append(":{}_kcl".format(name))

    return targets
