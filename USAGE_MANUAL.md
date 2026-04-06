# BIS Usage Manual

## Table of Contents

1. [Getting Started](#getting-started)
2. [Home Screen](#home-screen)
3. [Member Registration](#member-registration)
4. [Daily Member Registration](#daily-member-registration)
5. [Admin Login](#admin-login)
6. [Admin Dashboard](#admin-dashboard)
7. [Member Management](#member-management)
8. [Daily Member Management](#daily-member-management)
9. [Registration Reports](#registration-reports)
10. [Custom Tables](#custom-tables)
11. [User Management](#user-management)
12. [Export & Import](#export--import)
13. [App Settings (Theme, Language, Text Size)](#app-settings)

---

## Getting Started

Launch the BIS application. You will see the **Home Screen** with options to register members or access the admin area.

**Default admin login:**  
Username: `admin` / Password: `admin`  
⚠️ Change this password immediately after first login.

---

## Home Screen

The home screen is the public-facing page with:

- **"Welcome to bis"** headline
- **Member Registration** button → register a permanent member
- **Daily Member Registration** button → register a one-day member
- **Navigation bar** (top) with:
  - **aA** menu → adjust text size (increase / decrease / reset)
  - **🌙/☀️** icon → toggle dark/light theme
  - **PT/EN** button → switch between Portuguese and English
  - **Admin area** link (or **Logout** if logged in)

---

## Member Registration

1. Click **Member Registration** on the home screen (or navigate to `/register`).
2. Fill in:
   - **Name** (required)
   - **Email** (optional)
   - **Communication** checkbox — opt-in to receive BUS news/events
   - **Annual fee paid** checkbox
3. Click **Register**.
4. A success screen shows the auto-assigned **member number**.
5. Click **Back to Home** to return.

> Link at the top lets you switch to **Daily Member Registration** instead.

---

## Daily Member Registration

1. Click **Daily Member Registration** on the home screen.
2. Fill in:
   - **Name** (required)
   - **Notes** (optional)
3. Click **Register**.
4. A success screen shows the auto-assigned **daily member number**.

---

## Admin Login

1. Click **Admin area** in the navigation bar.
2. Enter your **username** and **password**.
3. Click **Log In**.
4. On success, you are redirected to the **Admin Dashboard**.

---

## Admin Dashboard

The dashboard is organized into sections:

### Registry
- **Members** — manage permanent members
- **Daily Members** — manage daily members
- **Registrations Report** — view registration statistics

### Custom Tables
- Shows all user-created tables with column counts
- Click a table to view/edit its data
- Click **+** to create a new custom table

### User Management
- **Users** — manage app user accounts

### Quick Actions
- **Add Member** — shortcut to the member add form
- **Add Daily Member** — shortcut to the daily member add form

### Database
- **Export Database** — save the entire database as a JSON backup
- **Import Database** — load records from a JSON backup file (appends, does not delete existing data)

---

## Member Management

Navigate via Admin → **Members**.

### Viewing Members
- Paginated table with columns: **#** (member number), **Name**, **Email**, **Comm.**, **Fee**, **ID**, **Created**
- Click column headers to **sort** (server-side sorting across all pages)
- Use the **search bar** to filter by name (default), email, or member number
- Change **rows per page** (10, 25, 50, 100) at the bottom

### Adding a Member
1. Click the **+** button (top-right).
2. Fill in the form fields.
3. Leave "Member number" empty for auto-assignment, or enter a specific number.
4. Click **Save**.

### Editing a Member
1. Click the **edit** (pencil) icon on a row.
2. Modify fields as needed.
3. Click **Save**.

### Deleting Members
- **Single**: click the **delete** (trash) icon on a row → confirm.
- **Bulk**: select checkboxes → **Delete selected** from the menu.
- **All**: use **Delete ALL** from the menu (requires confirmation).

### Exporting
- **CSV**: Export selected or all members to a `.csv` file.
- **PDF**: Export selected or all members to a paginated landscape `.pdf`.

### Importing
- Click **Import from CSV** in the menu.
- Select a `.csv` file with headers matching: `ID`, `member number`, `name`, `email`, `communication`, `annual fee`, `notes`, `Created (Lisbon)`.
- Existing members (matched by ID) are updated; new ones are created.

---

## Daily Member Management

Navigate via Admin → **Daily Members**.

Works identically to member management, but with simpler fields:
- **Daily #**, **Name**, **Notes**, **ID**, **Created**

---

## Registration Reports

Navigate via Admin → **Registrations Report**.

1. **Select a date range** using the date pickers, or use a **quick range** preset:
   - Today, Last 7 days, This month, This year, All time
2. The report shows two tables:
   - **Members** — new member registrations per day
   - **Daily Members** — new daily member registrations per day
3. Each table shows the **date** and **count** of registrations, with a total.

---

## Custom Tables

Allows creating additional data tables beyond Members and Daily Members.

### Creating a Custom Table
1. Navigate to Admin → **Manage Custom Tables**.
2. Click the **+** button.
3. Enter a **table name** (e.g., "Volunteers", "Equipment", "Events").
4. Add columns with:
   - **Column name**
   - **Type**: Text, Integer, Decimal, or Yes/No
5. Click **Create**.

### Managing Table Data
1. Click on a custom table from the list.
2. The data screen works like the member list: paginated, sortable, searchable.
3. **Add Row** → fill in values for each column.
4. **Edit/Delete** rows via action icons.
5. **Export to CSV** and **Import from CSV** are available.

### Editing Table Structure
- Click **Edit structure** on a table → modify name and columns.
- ⚠️ **Warning**: Changing the structure **deletes all existing data** in that table.

### Deleting a Table
- Click **Delete table** → confirm. This removes the table and all its data permanently.

---

## User Management

Navigate via Admin → **Users** (admin-only).

### Creating a User
1. Click the **+** button.
2. Enter **username** and **password**.
3. Toggle **Admin** switch if the user should have admin privileges.
4. Click **Create**.

### Changing a Password
- Click the **key** icon on a user → enter the new password → confirm.

### Changing a Role
- Click the **shield** icon to promote (normal → admin) or demote (admin → normal).

### Deleting a User
- Click the **delete** icon → confirm.

---

## Export & Import

### CSV Export
Available on member, daily member, and custom table screens.
- **Export selected to CSV** — only checked rows
- **Export ALL to CSV** — all records from the database

### PDF Export
Available on member and daily member screens.
- Generates a paginated **landscape A4** PDF with table formatting.

### JSON Database Backup
Available from the Admin Dashboard.
- **Export Database** → saves members + daily members as a `.json` file.
- **Import Database** → loads records from a backup (merges with existing data).

### CSV Import
- Select a `.csv` file from disk.
- Headers must match the expected format (same as the CSV export).
- Existing records (matched by ID) are updated; new records are created.

---

## App Settings

### Theme Toggle (🌙 / ☀️)
Click the moon/sun icon in the app bar to switch between **dark** and **light** themes.

### Language Toggle (PT / EN)
Click the **PT** or **EN** button in the app bar to switch the entire interface between Portuguese and English.

### Text Size (aA menu)
Click the **aA** button in the app bar to open a dropdown:
- **Increase** — makes all text larger (up to ~143%)
- **Decrease** — makes all text smaller (down to ~71%)
- **Reset** — returns to default size (100%)

The current percentage is shown next to "Reset".
