# Conformance fixtures

These files are **independent interoperability fixtures**, copied unmodified
from the official PHP implementation at a pinned commit so that they cannot
change underneath this repository.

| File | Source |
| --- | --- |
| `pikaid-v1.json` | https://github.com/pikaid/pikaid-php/blob/e3f843edeb5157a5d2d25196cac0d69580810a95/tests/vectors/pikaid-v1.json |
| `pikaid-v1.schema.json` | https://github.com/pikaid/pikaid-php/blob/e3f843edeb5157a5d2d25196cac0d69580810a95/tests/vectors/pikaid-v1.schema.json |

Provenance: `pikaid/pikaid-php` tag `v1.2.0`, commit
`e3f843edeb5157a5d2d25196cac0d69580810a95`.

The `pikaid-v1` filename is historical. The pikaid identifier format is
immutable and unversioned; the fixture name does not imply a versioned wire
format. The normative reference remains
[specification revision 1.0.4](https://github.com/pikaid/pikaid-specs/tree/v1.0.4),
pinned at commit `17014d76f568c3ac9f9ce2927c1a018fdbc36d1d`. Where the fixture
and the specification disagree, the specification wins.

Checksums of the copies in this directory:

```text
b0c9dfdd063613424414fef5c9065fbd2f81d645d0ab42b34e27cde715613500  pikaid-v1.json
4441d4dbaa6c5450ae9cbfb2438c53bc0421bba2b7fcc9ef9b158e5d1de0759e  pikaid-v1.schema.json
```

`test/official_vectors_test.dart` also asserts that the fixture `meta` block
agrees with the constants exported by this package, so a silently altered
fixture cannot weaken the conformance suite.
