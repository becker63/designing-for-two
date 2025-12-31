def _kcl_crd_import_impl(ctx):
    """
    Runs `kcl import -m crd` over a group of CRD YAML files and
    emits generated KCL schema files into a directory.
    """

    out = ctx.actions.declare_output(ctx.label.name, dir=True)

    kcl = ctx.attrs._kcl[RunInfo]

    args = cmd_args()
    args.add("import")
    args.add("-m", "crd")

    # Input CRDs
    for src in ctx.attrs.srcs:
        args.add(src)

    # Output directory
    args.add("--output", out.as_output())

    ctx.actions.run(
        cmd_args(kcl, args),
        category = "kcl_crd_import",
    )

    return [DefaultInfo(default_outputs = [out])]


kcl_crd_import = rule(
    impl = _kcl_crd_import_impl,
    attrs = {
        "srcs": attrs.list(attrs.source(), default=[]),

        # kcl executable
        "_kcl": attrs.exec_dep(default = "toolchains//:kcl"),
    },
)
