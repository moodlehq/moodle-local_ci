These patches recreate the prechecker test branches in a temporary local Git
repository. Their Moodle base commits are pinned in `remote_branch_checker.bats`.

The old-branch and many-problems cases adapt the original fixtures recovered in
[the fixture archive](https://github.com/cameron1729/moodle-ci-fixture-archive).
The other cases reproduce the conditions checked by the existing XML and regex
fixtures, using the component tests as references. They are equivalent test inputs,
not copies of the missing branch histories.
