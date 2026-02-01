
# 📁 Copy With Timestamp (PowerShell)

Organize files by **year/month** (YYYY/MM) based on their **LastWriteTime** or **CreationTime**.  
Supports **copy or move**, **GUI folder selection**, **progress bar**, **name collision handling**, optional **CSV report**, and preserving the **source directory structure**.

> **Tested on**: Windows PowerShell 5.1.  
> **Script**: `copy_with_date_stamp_new.ps1`

---

## ✨ Features

- Group files into `YYYY\MM` directories (configurable date field).
- Group files into `YYYY\` directories (configurable date field).
- Copy **or** move files.
- Optional **GUI** dialogs to select source/destination.
- **Unique filename** handling to avoid overwriting.
- **Progress bar** and end-of-run **summary** (processed/skipped/errors/time).
- **CSV report** of actions taken (optional).
- Validates that Source/Destination aren’t nested (prevents recursion).
- Preserves **relative source directory tree** under `YYYY\MM` (optional).

---

## 📦 Requirements

- **Windows PowerShell 5.1** (recommended), or PowerShell 7+ on Windows.
- Permissions to read Source and write to Destination.
- If using GUI selection (`-UseGui`), the script loads `System.Windows.Forms`.

---
