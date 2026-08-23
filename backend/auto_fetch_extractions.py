import os
import urllib.request
import re
from datetime import datetime
from bs4 import BeautifulSoup
from supabase import create_client, Client

# Configurazione Supabase
SUPABASE_URL = "https://fcokqyuccicfxqxughih.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjb2txeXVjY2ljZnhxeHVnaGloIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NzE1MzkxNCwiZXhwIjoyMTAyNzI5OTE0fQ.QP66z1Qe1L9zYI_6zUAl3Rt89H2xkzTrDRGCXpQZNPg"

def fetch_latest_extractions():
    url = "https://www.superenalotto.com/risultati"
    print(f"[*] Connessione a {url}...")
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    
    try:
        html = urllib.request.urlopen(req).read()
    except Exception as e:
        print(f"[!] Errore durante il download della pagina: {e}")
        return []

    soup = BeautifulSoup(html, 'html.parser')
    draws = []

    # Cerchiamo i blocchi delle estrazioni
    boxes = soup.find_all('div', class_='boxDraw')
    
    for box in boxes:
        title_tag = box.find('div', class_='boxDrawTitle')
        if not title_tag:
            # Forse è il boxDrawFirstTitle
            title_tag = box.find('div', class_='boxDrawFirstTitle')
            
        if not title_tag:
            continue
            
        title_text = title_tag.get_text(strip=True)
        # Esempio: "Estrazione SuperEnalotto n° 130 del 17/08/2026" o simile
        match = re.search(r'n[^\d]*(\d+)[^\d]+(\d{2}/\d{2}/\d{4})', title_text)
        if not match:
            continue
            
        concorso = int(match.group(1))
        date_str = match.group(2)
        date_obj = datetime.strptime(date_str, "%d/%m/%Y")
        date_formatted = date_obj.strftime("%Y-%m-%d")

        numbers_div = box.find('div', class_='boxDrawNumbers')
        if not numbers_div:
            continue
            
        # I primi 6 sono i numeri base
        num_tags = numbers_div.find_all('div', class_='boxDrawNumber')
        if len(num_tags) < 8:
            continue
            
        n1 = int(num_tags[0].get_text(strip=True))
        n2 = int(num_tags[1].get_text(strip=True))
        n3 = int(num_tags[2].get_text(strip=True))
        n4 = int(num_tags[3].get_text(strip=True))
        n5 = int(num_tags[4].get_text(strip=True))
        n6 = int(num_tags[5].get_text(strip=True))
        
        # Jolly è spesso contrassegnato o è il settimo
        jolly = int(num_tags[6].get_text(strip=True))
        
        # SuperStar è l'ottavo
        superstar = int(num_tags[7].get_text(strip=True))
        
        draws.append({
            "concorso": concorso,
            "date": date_formatted,
            "n1": n1,
            "n2": n2,
            "n3": n3,
            "n4": n4,
            "n5": n5,
            "n6": n6,
            "jolly": jolly,
            "superstar": superstar
        })
        
    return draws

def sync_to_supabase(draws):
    if not draws:
        print("[!] Nessuna estrazione trovata da parsare.")
        return
        
    print(f"[*] Trovate {len(draws)} estrazioni recenti.")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    try:
        response = supabase.table('historical_extractions').upsert(draws).execute()
        print(f"[SUCCESS] {len(draws)} estrazioni salvate/aggiornate in Supabase.")
    except Exception as e:
        print(f"[!] Errore durante l'inserimento in Supabase: {e}")

if __name__ == "__main__":
    print("--- AUTO FETCH SUPERENALOTTO ---")
    recent_draws = fetch_latest_extractions()
    sync_to_supabase(recent_draws)
    print("--- FINE ---")
