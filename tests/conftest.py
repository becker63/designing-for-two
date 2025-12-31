import pytest
from pytest import Metafunc

from lib.test_ext import (
    KFile,
    extract_kcl_metadata,
    find_kcl_files,
    infer_group_argnames,
    kfile_ids,
    select_named_group_cases,
    select_single_file_cases,
    validate_group_arity,
)

# -------------------------------------------------
# Pytest lifecycle hooks
# -------------------------------------------------


def pytest_configure(config):
    """
    Discover the universe of KCL files once per test session.
    """
    config._kcl_all_files = find_kcl_files()


def pytest_generate_tests(metafunc: Metafunc):
    """
    Expand tests based on decorators provided by lib.test_ext.
    """
    all_files: list[KFile] = getattr(metafunc.config, "_kcl_all_files", [])

    metadata = extract_kcl_metadata(metafunc.function)

    # ---------------------------------------------
    # Single-file expansion: one test per KCL file
    # ---------------------------------------------
    if metadata.use_single_file_tests and "kf" in metafunc.fixturenames:
        matched = select_single_file_cases(
            all_files,
            metadata.kcl_filter_fn,  # type: ignore[arg-type]
        )

        if not matched:
            raise ValueError(f"No KCL files matched for {metafunc.function.__name__}")

        metafunc.parametrize(
            "kf",
            matched,
            ids=kfile_ids(matched),
        )
        return

    # ---------------------------------------------
    # Named-group expansion: explicit file tuples
    # ---------------------------------------------
    if metadata.use_named_group_tests:
        matched = select_named_group_cases(
            all_files,
            metadata.kcl_group_filenames,  # type: ignore[arg-type]
            metadata.kcl_group_filter,  # type: ignore[arg-type]
        )

        argnames = infer_group_argnames(
            metafunc.function,
            metafunc.fixturenames,
        )[: len(matched)]

        validate_group_arity(
            metafunc.function.__name__,
            argnames,
            matched,
        )

        if len(argnames) == 1:
            metafunc.parametrize(
                argnames[0],
                matched,
                ids=[kf.path.name for kf in matched],
            )
        else:
            metafunc.parametrize(
                ",".join(argnames),
                [tuple(matched)],
                ids=[",".join(kf.path.name for kf in matched)],
            )
        return
