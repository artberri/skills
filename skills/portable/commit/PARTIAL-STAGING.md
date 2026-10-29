# Staging part of a file

`git add -p` is interactive, so it isn't available. Stage an intermediate version of the file instead: the file as it would be with only the earlier commit's changes. The working tree stays untouched.

## Stage a hand-built version

Build the intermediate content, write it as a blob, and point the index at it:

```sh
blob="$(<command that prints the intermediate file> | git hash-object -w --stdin)"
git update-index --add --cacheinfo "100644,$blob,path/to/file"
```

Use `100755` for an executable file. The command can be:

- the full file with the later topic's lines removed, for example with `perl -0pe 's/<the later lines>//' path/to/file`;
- for a file that is new in the later commit, nothing: just don't stage it yet.

Check the result before committing:

```sh
git diff --cached -- path/to/file    # only the earlier topic's changes
git diff -- path/to/file             # only the later topic's changes
```

After the earlier commit, `git add path/to/file` stages the rest.

## Stage selected hunks

When the topics fall in separate hunks, apply a reduced patch to the index:

```sh
git diff -- path/to/file > <scratch dir>/full.patch
# copy full.patch to part.patch and delete the hunks of the later topic
git apply --cached <scratch dir>/part.patch
```

Delete whole hunks only; editing lines inside a hunk breaks its line counts. When the topics share a hunk, use the hand-built version above.
