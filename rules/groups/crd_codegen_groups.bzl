load("//rules:crd-to-cloudcoil.bzl", "python_codegen")

def crd_codegen_from_tree(
    *,
    name_prefix,
    srcs,
    namespace_prefix,
):
    """
    Split a flat list of CRD YAML files into multiple python_codegen targets
    based on their top-level directory.

    This is *deliberately* done at analysis time so Buck can:
      - parallelize code generation across CRD groups
      - cache each group independently
      - avoid one large CRD blocking all others

    Example:
      srcs = [
        "cert-manager/foo.yaml",
        "cert-manager/bar.yaml",
        "fluxcd-source/baz.yaml",
      ]

      =>
      python_codegen(
        name = "gen_cert_manager",
        srcs = [...],
        namespace = "generated.models.cert_manager",
      )

      python_codegen(
        name = "gen_fluxcd_source",
        srcs = [...],
        namespace = "generated.models.fluxcd_source",
      )
    """

    # Map of <top-level-dir> -> [list of yaml files]
    groups = {}

    for src in srcs:
        # src is a string path like "cert-manager/foo/bar.yaml"
        # We intentionally only look at the first path segment
        # to define a "CRD group".
        top = src.split("/")[0]
        groups.setdefault(top, []).append(src)

    targets = []

    for group, group_srcs in groups.items():
        # Buck target names and Python module names cannot contain '-'
        safe = group.replace("-", "_")

        # Use the CRD name directly as the target name
        name = safe

        python_codegen(
            name = name,
            srcs = group_srcs,
            namespace = safe,
        )

        targets.append(":{}".format(name))


    return targets
