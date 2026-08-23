import os
import csv
import json
import requests
from supabase import create_client, Client
from dotenv import load_dotenv

# Carica variabili d'ambiente
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("ERRORE: Credenziali Supabase mancanti. Crea un file .env")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
CSV_URL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTR6n8qi3vliYpiRUltoCjO7TYLt0XFMtuzoM5u-wfmd8AcLhryYlGgde3AOgJI_EBNmfUWmPS2y9iR/pub?output=csv"

def get_latest_extraction():
    try:
        response = requests.get(CSV_URL)
        response.raise_for_status()
        
        lines = response.text.splitlines()
        reader = csv.reader(lines)
        next(reader) # skip header
        
        # Prendi l'ultima estrazione (prima riga di dati se decrescente, ma per sicurezza leggiamo l'ultima non vuota)
        for row in reader:
            if not row or len(row) < 10:
                continue
            
            date = row[1]
            numbers = {int(row[2]), int(row[3]), int(row[4]), int(row[5]), int(row[6]), int(row[7])}
            jolly = int(row[8]) if row[8].isdigit() else 0
            superstar = int(row[9]) if row[9].isdigit() else 0
            
            return {
                "date": date,
                "numbers": numbers,
                "jolly": jolly,
                "superstar": superstar
            }
            
    except Exception as e:
        print(f"Errore nel recupero dell'estrazione: {e}")
        return None

def verify_global_wins():
    extraction = get_latest_extraction()
    if not extraction:
        return
        
    target_date = extraction["date"]
    print(f"Estrazione più recente: {target_date} - Numeri: {extraction['numbers']} SS: {extraction['superstar']}")
    
    try:
        # Recupera tutte le generazioni IA dal cloud per questa data
        response = supabase.table("ai_global_generations").select("*").eq("target_date", target_date).execute()
        
        generations = response.data
        if not generations:
            print(f"Nessuna giocata trovata in DB per la data {target_date}.")
            return
            
        print(f"Trovate {len(generations)} giocate (incluse sestine e sistemi) da verificare.")
        
        # Contatori vincite
        total_3 = 0
        total_4 = 0
        total_5 = 0
        total_6 = 0
        total_ss = 0
        
        win_numbers = extraction["numbers"]
        win_ss = extraction["superstar"]
        
        for gen in generations:
            sestine = gen.get("sestine", [])
            ss = gen.get("superstar", None)
            
            # sestine può essere una lista di liste (Sistema o Sestina singola array [ [1,2,3,4,5,6] ])
            for ticket in sestine:
                ticket_set = set(ticket)
                matches = len(ticket_set.intersection(win_numbers))
                
                if matches == 3:
                    total_3 += 1
                elif matches == 4:
                    total_4 += 1
                elif matches == 5:
                    total_5 += 1
                elif matches == 6:
                    total_6 += 1
                    
                if ss is not None and ss == win_ss:
                    total_ss += 1
                    
        print(f"--- RISULTATI GLOBALI ---")
        print(f"Totale 3: {total_3}")
        print(f"Totale 4: {total_4}")
        print(f"Totale 5: {total_5}")
        print(f"Totale 6: {total_6}")
        print(f"Totale SuperStar Centrati: {total_ss}")
        
        # Salva in Supabase
        supabase.table("global_win_stats").upsert({
            "draw_date": target_date,
            "total_3": total_3,
            "total_4": total_4,
            "total_5": total_5,
            "total_6": total_6,
            "total_ss": total_ss
        }, on_conflict="draw_date").execute()
        
        print("Salvataggio completato su Supabase.")
        
    except Exception as e:
        print(f"Errore durante l'elaborazione globale: {e}")

if __name__ == "__main__":
    verify_global_wins()
