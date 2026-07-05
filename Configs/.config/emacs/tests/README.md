# Tests

Regression harness for the Studium Emacs config.

## universal-launcher

`test-universal-launcher.el` pins the timer regression that surfaced
as `(wrong-type-argument stringp nil)` every 20 s in `*Messages*`:

* `universal-launcher--get-system-commands` must tolerate PATH entries
  that `parse-colon-path` collapses to `nil` (i.e. PATH containing `::`).
* `universal-launcher--extract-domain` must accept non-string input.
* `universal-launcher--parse-org-bookmarks` must coalesce `nil`
  descriptions.
* `universal-launcher--get-agenda-tasks` must filter non-string tags.

### Run

```
./run-tests.sh
```

or directly:

```
emacs -Q --batch -l ~/.config/emacs/tests/test-universal-launcher.el
```

Exit code 0 means all assertions passed; non-zero indicates regression.
