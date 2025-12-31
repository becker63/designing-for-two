def _frp_schema_codegen_impl(ctx):
    out = ctx.actions.declare_output(ctx.label.name, dir=True)

    tool = ctx.attrs._tool[RunInfo]

    args = cmd_args(
        "--out-dir", out.as_output()
    )

    ctx.actions.run(
        cmd_args([tool, args]),
        category = "frp_schema_codegen",
    )

    return [DefaultInfo(default_outputs=[out])]


frp_schema_codegen = rule(
    impl = _frp_schema_codegen_impl,
    attrs = {
        "_tool": attrs.exec_dep(
            default = "toolchains//:go-schema-kcl",
        ),
    },
)
