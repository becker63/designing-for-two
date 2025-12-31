import regex

# True if not Undefined
is_defined = lambda v -> bool {
    v != Undefined
}

# Safe dot-path getter for dicts only.
get = lambda x: any, path: str, d: any -> any {
    p = regex.split(path, "\.")
    c = p[0]
    rest = ".".join(p[1::])

    _out = d

    if x != None and x != Undefined and typeof(x) == "dict" and c in x:
        _out = x[c] if len(p) == 1 else get(x[c], rest, d)

    _out
}

# Does the ocds dict contain a given step key?
exists = lambda ocds: any, step: str -> bool {
    (typeof(ocds) == "dict") and (step in ocds)
}

# Extract the composed resource (or None) from ocds[step]
resource = lambda ocds: any, step: str -> any {
    _out = None
    if exists(ocds, step):
        # ocd entry is typically a dict-ish object with "Resource"
        _out = get(ocds[step], "Resource", None)

    _out
}

# Crossplane-style readiness: condition type=Ready status=True
# (Works for most managed resources.)
ready = lambda ocds: any, step: str -> bool {
    r = resource(ocds, step)
    conds = r?.status?.conditions if r?.status?.conditions != Undefined else []
    any c in conds {c.type == "Ready" and c.status == "True"}
}
