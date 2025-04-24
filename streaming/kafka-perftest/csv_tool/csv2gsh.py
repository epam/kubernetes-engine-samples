import pandas as pd
import glob
import datetime
from pathlib import Path
import csv  # Import the built-in csv module
import gspread
from google.oauth2.service_account import Credentials

# --- Google Sheets Configuration ---
# Replace with the name of your Google Sheet
SPREADSHEET_NAME = "generated"

# Path to your Google Sheets API credentials JSON file
CREDENTIALS_FILE = "/Users/taras_rudko/Downloads/hl2-gogl-wopt-t1iylu-6400cc43fc7b.json"

# Define the list of target cells you want to create links to
# Now, each tuple contains a list of (row_index, col_index) and a summary_column_name prefix
target_link_cells = [
   

    ###### 3 Brockers/ # Loaders simultaneously
    ([(11, 0), (32, 0), (53,0)], 'average latency e2e, ms'),
    ([(18, 2), (39, 2), (60,2)], 'non-batched throughtput MB/s'),
    ([(18, 3), (39, 3), (60,3)], 'non-batched latency, ms'),
    ([(22, 2), (43, 2), (64,2)], 'batched throughtput MB/s'),
    ([(22, 3), (43, 3), (64,3)], 'batched latency, ms'),
    ([(29, 8), (50, 8), (71,8)], 'consumer fetch, MB/s'),




    ###### 1 Loader/ 1 Brocker ##### 
    # ([(14, 0), (38, 0), (62,0)], 'BL average latency e2e, ms'),
    # ([(94, 0), (115, 0), (136,0)], 'Tuned average latency e2e, ms'),
    # ([(21, 2), (45, 2), (69,2)], 'BL non-batched throughtput MB/s'),
    # ([(101, 2), (122, 2), (143,2)], 'Tuned non-batched throughtput MB/s'),
    # ([(21, 3), (45, 3), (69,3)], 'BL non-batched latency, ms'),
    # ([(101, 3), (122, 3), (143,3)], 'Tuned non-batched latency, ms'),    
    # ([(25, 2), (49, 2), (73,2)], 'BL batched throughtput MB/s'),
    # ([(105, 2), (126, 2), (147,2)], 'Tuned batched throughtput MB/s'),
    # ([(25, 3), (49, 3), (73,3)], 'BL batched latency, ms'),
    # ([(105, 3), (126, 3), (147,3)], 'Tuned batched latency, ms'),
    # ([(32, 8), (56, 8), (80,8)], 'BL consumer fetch, MB/s'),
    # ([(112, 8), (133, 8), (154,8)], 'Tuned consumer fetch, MB/s'),   


    # Add more lists of target cells as needed
]
# --- End Google Sheets Configuration ---

now = datetime.datetime.now()
extension = "csv"
all_filenames = [i for i in glob.glob(f"*.{extension}")]

summary_data = []

# Authenticate with Google Sheets API
scope = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]
creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
gc = gspread.authorize(creds)
spreadsheet = gc.open(SPREADSHEET_NAME)

try:
    # --- Delete all existing sheets (except the first one, which we'll keep as 'Summary') ---
    sheets_to_delete = spreadsheet.worksheets()
    summary_sheet = None
    if sheets_to_delete:
        summary_sheet = sheets_to_delete[0]
        # summary_sheet.title = 'Summary'  # Rename the first sheet to 'Summary'
        for sheet in sheets_to_delete[1:]:
            print(f"Deleting sheet: {sheet.title}")
            spreadsheet.del_worksheet(sheet)
    else:
        # Determine the initial number of columns for the Summary sheet
        num_summary_cols = 2  # For 'Filename' and 'Sheet'
        for item in target_link_cells:
            num_summary_cols += len(item[0])
        summary_sheet = spreadsheet.add_worksheet(title='Summary', rows=1, cols=num_summary_cols)
        print("Created initial 'Summary' sheet.")
    # --- End sheet deletion ---

    for csvfilename in all_filenames:
        print(f"Processing file: {csvfilename}")
        all_rows = []
        try:
            with open(csvfilename, 'r') as csvfile:
                reader = csv.reader(csvfile)
                all_rows = list(reader)  # Read all rows into a list

            if all_rows:
                df = pd.DataFrame(all_rows)
                sheet_name = Path(csvfilename).stem

                # Write DataFrame to a new worksheet
                try:
                    worksheet = spreadsheet.add_worksheet(title=sheet_name, rows=df.shape[0], cols=df.shape[1])
                    worksheet.update('A1', [df.columns.tolist()] + df.values.tolist(), value_input_option='USER_ENTERED')  # Write with header
                    print(f"Successfully processed {csvfilename} to sheet '{sheet_name}'")
                except gspread.exceptions.APIError as e:
                    print(f"Error creating or updating sheet '{sheet_name}': {e}")
                    continue  # Skip to the next file if sheet creation fails

                summary_entry = {'Filename': csvfilename, 'Sheet': sheet_name}
                for cell_list, summary_col_prefix in target_link_cells:
                    link_formulas = []
                    for row_index, col_index in cell_list:
                        if len(all_rows) > row_index-1 :
                            # Construct the Google Sheets A1 notation for the cell
                            col_letter = chr(ord('A') + col_index)
                            cell_address = f"'{sheet_name}'!${col_letter}${row_index + 1}"
                            link_formulas.append(f'={cell_address}')
                        else:
                            link_formulas.append(None)  # Or some other placeholder like ""
                            print("Skipped...")
                    summary_entry[summary_col_prefix] = link_formulas  # Store the list of links

                summary_data.append(summary_entry)
            else:
                print(f"Warning: {csvfilename} is empty.")

        except FileNotFoundError:
            print(f"Error: File not found - {csvfilename}")
        except Exception as e:
            print(f"An error occurred while processing {csvfilename}: {e}")

    # Create or update the summary sheet
    if summary_data and summary_sheet:
        print("Updating 'Summary' sheet.")
        summary_sheet.clear()
        header_row = ['Filename', 'Sheet']
        for item in target_link_cells:
            for i in range(len(item[0])):
                header_row.append(f"{item[1]} - {i+1}")
        summary_sheet.update('A1', [header_row], value_input_option='USER_ENTERED')

        summary_rows = []
        for entry in summary_data:
            row = [entry['Filename'], entry['Sheet']]
            for _, col_prefix in target_link_cells:
                links = entry.get(col_prefix, [])
                row.extend(links)
            summary_rows.append(row)

        if summary_rows:
            summary_sheet.update('A2', summary_rows, value_input_option='USER_ENTERED')

        print("'Summary' sheet updated with links in separate cells.")
    elif not summary_sheet:
        print("Error: Could not access or create the 'Summary' sheet.")
    elif not summary_data:
        print("No data to populate the 'Summary' sheet.")

except gspread.exceptions.GSpreadException as e:
    print(f"Google Sheets API error: {e}")
finally:
    print("Task completed")