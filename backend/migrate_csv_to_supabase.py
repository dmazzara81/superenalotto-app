import os
import pandas as pd
from datetime import datetime
from supabase import create_client, Client

# Usa la tua VERA URL (la stessa di Flutter)
SUPABASE_URL = "https://fcokqyuccicfxqxughih.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjb2txeXVjY2ljZnhxeHVnaGloIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NzE1MzkxNCwiZXhwIjoyMTAyNzI5OTE0fQ.QP66z1Qe1L9zYI_6zUAl3Rt89H2xkzTrDRGCXpQZNPg"
CSV_URL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTR6n8qi3vliYpiRUltoCjO7TYLt0XFMtuzoM5u-wfmd8AcLhryYlGgde3AOgJI_EBNmfUWmPS2y9iR/pub?output=csv"

def main():
    print("[*] Avvio Migrazione Dati Storici su Supabase...")
    
    # 1. Connessione a Supabase
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    print("[*] Download CSV da Google Sheets...")
    # Leggiamo il CSV dal link (header=1 perché la riga 0 contiene le intestazioni reali)
    df = pd.read_csv(CSV_URL, header=1)
    df.columns = ['concorso', 'data', 'n1', 'n2', 'n3', 'n4', 'n5', 'n6', 'jolly', 'superstar']
    df = df.dropna(subset=['data', 'n1'])
    
    print(f"[*] Trovate {len(df)} estrazioni. Preparazione payload...")
    
    records = []
    for _, row in df.iterrows():
        try:
            date_obj = datetime.strptime(str(row['data']), "%d/%m/%Y")
            records.append({
                "concorso": int(row['concorso']),
                "date": date_obj.strftime("%Y-%m-%d"),
                "n1": int(row['n1']),
                "n2": int(row['n2']),
                "n3": int(row['n3']),
                "n4": int(row['n4']),
                "n5": int(row['n5']),
                "n6": int(row['n6']),
                "jolly": int(row['jolly']) if pd.notna(row['jolly']) else 0,
                "superstar": int(row['superstar']) if pd.notna(row['superstar']) else 0
            })
        except Exception as e:
            print(f"Errore parsing riga: {row} -> {e}")
            continue

    # Suddividiamo in batch per evitare timeout/errori HTTP payload too large
    batch_size = 500
    for i in range(0, len(records), batch_size):
        batch = records[i:i + batch_size]
        try:
            supabase.table('historical_extractions').upsert(batch).execute()
            print(f"[*] Inserito batch {i // batch_size + 1} ({len(batch)} records)")
        except Exception as e:
            print(f"[!] Errore nell'inserimento del batch: {e}")

    print("[SUCCESS] Migrazione completata!")

if __name__ == "__main__":
    main()
