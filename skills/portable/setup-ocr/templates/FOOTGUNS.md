# Footguns

Non-obvious pitfalls in this codebase: code that passes review and type checks but misbehaves at runtime. Each entry shows the wrong way, what happened, and the right way.

Add an entry when you lose real time to a subtle bug the next person would also hit. Keep each heading a short description of the trap, so a reviewer can scan the headings and read only the entries that match what a change touches.

## <The trap, as a short claim>

<What behaves unexpectedly, and why.>

**Wrong**

```
<the code that looks right>
```

<What happened because of it.>

**Right**

```
<the fix>
```
