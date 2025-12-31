load("//rules:crd-to-kcl.bzl", "kcl_crd_import")

def kcl_codegen_from_tree(
    *,
    srcs,
):
    """
    Split CRDs by top-level directory and generate KCL schemas
    using `kcl import -m crd`.
    """

    groups = {}

    for src in srcs:
        top = src.split("/")[0]
        groups.setdefault(top, []).append(src)

    targets = []

    for group, group_srcs in groups.items():
        safe = group.replace("-", "_")

        kcl_crd_import(
            name = "{}_kcl".format(safe),
            srcs = group_srcs,
        )

        targets.append(":{}_kcl".format(safe))

    return targets
