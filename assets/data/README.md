# Data Import Folder

This folder contains data files for importing expenses into the app.

## Excel Sheet Location
Place your Excel file here: `assets/data/expenses.xlsx`

## Excel Format Expected
The Excel sheet should have the following columns:
- **Date** (Column A): Date in format YYYY-MM-DD or DD/MM/YYYY
- **Description** (Column B): Transaction description
- **Amount** (Column C): Amount (positive for income, negative for expenses)
- **Category** (Column D): Category (Food, Groceries, Purchase, Travel, Entertainment, Salary, Per Diem, Bonus, Advance, Other)
- **Type** (Column E): Transaction type (income/expense) - optional if using amount sign

## Auto-Import
- The app will automatically import expenses on startup for email: `prajeshiyer@gmail.com`
- Data will only be imported once (tracked by import status)
- Existing transactions won't be duplicated

## Sample Excel Format
```
Date        | Description      | Amount  | Category      | Type
2024-06-14  | Coffee           | -5.50   | Food          | expense
2024-06-15  | Salary           | 5000.00 | Salary        | income
2024-06-16  | Groceries        | -120.75 | Groceries     | expense
```
