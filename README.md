# vps-db-tool

tools for working with virtualpinballspreadsheet.github.io

## Cookbook

```
swift run vps-db-tool report
```

```
swift run vps-db-tool explore duplicates > missing/dups.md
```

```
swift run vps-db-tool scan check-missing --site vpu --pages 85 --markdown > missing/VPU-tables.md ; swift run vps-db-tool scan check-missing --site vpf --pages 228 --markdown > missing/VPF-tables.md ; swift run vps-db-tool report ; git add report missing ; git commit -m update ; git push
```

## Ideas

- detect Edition in comment and no Edition set
    - move -- but we want to display the edition in the UI
- remove Edition from Edition
