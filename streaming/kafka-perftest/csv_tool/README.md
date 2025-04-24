This tool looks for csv files in current directory and imports them into Google sheet document

## Prerequisites and Assumptions
In order to use the tool it is required 
1. Create service account in GCP project and create/load json credentials file. No need to grant any roles in project. Edit path to credentials json file in csv2gsh.py line 14
2. Create  Google sheet, name it "generated" and share with the service account id (email). Document name is set in  csv2gsh.py line 11, can be changed upon need.
3. Rename sheet1 to "Summary"
4. Install required python libraries with command
```
    pip install -r requirements.txt
```
5. Copy csv files
6. target_link_cells in line 18 contains list of cell indexes, links for these sells will be created in Summary sheet. These values should be adjusted accordingly to needs
7. to run the script use command
```
    python csv2gsh.py
```
8. Check the Google Sheet doc. Adjust values in step 6 if needed and repeat step 7.

Limitations: Target cells in all csv files should be in same positions

