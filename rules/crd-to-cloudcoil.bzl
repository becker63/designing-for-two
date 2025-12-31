def _python_codegen_impl(ctx):
    """
    Implementation of the python_codegen rule.

    This rule:
      - takes CRD YAML files as inputs
      - runs the codegen CLI exactly once
      - produces a directory of generated Python sources

    The rule is intentionally minimal and hermetic:
      - no Python toolchain
      - no implicit runtime deps
      - everything happens inside a single Buck action
    """

    # Each codegen target writes to its *own* output directory.
    # Using ctx.label.name avoids collisions when many generators exist.
    out = ctx.actions.declare_output(ctx.label.name, dir=True)

    # Executable tool (python_bootstrap_binary)
    codegen = ctx.attrs._codegen[RunInfo]

    # Ruff is only used to get its bin directory on PATH
    ruff = ctx.attrs._ruff[RunInfo]

    # Build CLI arguments for the codegen tool
    args = cmd_args()
    args.add(ctx.attrs.namespace)

    # Add each CRD file as --input <file>
    # Buck tracks these as action inputs automatically.
    for f in ctx.attrs.srcs:
        args.add("--input", f)

    # Tell the generator where to write files
    args.add("--output", out.as_output())

    # Ensure deterministic output by wiping the directory
    args.add("--clean")

    # We intentionally run through bash so we can:
    #   - prepend ruff to PATH
    #   - avoid Buck's stricter ctx.actions.run argument rules
    shell_cmd = cmd_args(
        [
            "bash",
            "-e",   # fail fast on errors
            "-c",
            cmd_args(
                [
                    # Put ruff on PATH, then invoke the codegen binary
                    "PATH=$(dirname ",
                    cmd_args(ruff, format="{}"),
                    "):$PATH;",
                    codegen,
                    args,
                ],
                delimiter=" "
            ),
        ]
    )

    # Register the action with Buck
    ctx.actions.run(
        shell_cmd,
        category="python_codegen"
    )

    # Expose the generated directory as the rule output
    return [DefaultInfo(default_outputs=[out])]


# Public rule wrapper
python_codegen = rule(
    impl = _python_codegen_impl,
    attrs = {
        # Input CRD YAML files
        "srcs": attrs.list(attrs.source(), default=[]),

        # Python namespace for generated models
        "namespace": attrs.string(),

        # Codegen executable (bootstrap binary)
        "_codegen": attrs.exec_dep(default="toolchains//:python-crd-cloudcoil"),

        # Ruff binary (used only for PATH injection)
        "_ruff": attrs.exec_dep(default="toolchains//:ruff"),
    },
)
