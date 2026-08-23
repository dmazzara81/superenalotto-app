import os
import urllib.request
import re
from datetime import datetime
from bs4 import BeautifulSoup
from supabase import create_client, Client

# Configurazione Supabase
SUPABASE_URL = "https://fcokqyuccicfxqxughih.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjb2txeXVjY2ljZnhxeHVnaGloIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NzE1MzkxNCwiZXhwIjoyMTAyNzI5OTE0fQ.QP66z1Qe1L9zYI_6zUAl3Rt89H2xkzTrDRGCXpQZNPg"

def get_supabase_client():
    return create_client(SUPABASE_URL, SUPABASE_KEY)

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
        # Esempio: "Estrazione del 22 agosto 2026 - concorso n. 135"
        match_concorso = re.search(r'concorso n\.\s*(\d+)', title_text)
        if not match_concorso:
            continue
            
        concorso = int(match_concorso.group(1))
        
        # Recuperiamo la data dal link "Vai alle quote e premi" che è nel formato dd-mm-yyyy
        date_formatted = ""
        link_tag = box.find('a', href=re.compile(r'/risultati-estrazione/\d{2}-\d{2}-\d{4}'))
        if link_tag:
            match_date = re.search(r'/risultati-estrazione/(\d{2}-\d{2}-\d{4})', link_tag['href'])
            if match_date:
                date_str = match_date.group(1) # es 22-08-2026
                date_obj = datetime.strptime(date_str, "%d-%m-%Y")
                date_formatted = date_obj.strftime("%Y-%m-%d")
        
        if not date_formatted:
            continue

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
        
        # Jolly è spesso contrassegnato o è il settimo (estraiamo solo i numeri)
        jolly_match = re.search(r'(\d+)', num_tags[6].get_text(strip=True))
        jolly = int(jolly_match.group(1)) if jolly_match else 0
        
        # SuperStar è l'ottavo (estraiamo solo i numeri)
        superstar_match = re.search(r'(\d+)', num_tags[7].get_text(strip=True))
        superstar = int(superstar_match.group(1)) if superstar_match else 0
        
        # Recupero del Jackpot
        jackpot_str = "0 €"
        footer_cell2 = box.find('div', class_='boxDrawFooterCell2')
        if footer_cell2:
            raw_text = footer_cell2.get_text(strip=True)
            # Estraiamo solo numeri e puntini per evitare problemi di codifica con il simbolo Euro
            match_jackpot = re.search(r'([\d\.]+)', raw_text)
            if match_jackpot:
                jackpot_str = match_jackpot.group(1) + " €"
        
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
            "superstar": superstar,
            "jackpot": jackpot_str
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
        
        # Dopo aver salvato le estrazioni, controlliamo le schedine generate dall'IA
        # per le estrazioni appena scaricate
        check_ai_global_wins(draws)
        
    except Exception as e:
        print(f"[ERROR] Errore durante il salvataggio su Supabase: {e}")

def check_ai_global_wins(recent_draws):
    print("[*] Avvio controllo vincite IA globali...")
    client = get_supabase_client()
    if not client:
        return
        
    for draw in recent_draws:
        target_date = draw["date"]
        try:
            # Recupera le schedine IA per questa data
            response = client.table("ai_global_generations").select("*").eq("target_date", target_date).execute()
            generations = response.data
            
            if not generations:
                continue
                
            winning_numbers = {draw["n1"], draw["n2"], draw["n3"], draw["n4"], draw["n5"], draw["n6"]}
            
            total_3 = 0
            total_4 = 0
            total_5 = 0
            total_6 = 0
            
            for gen in generations:
                sestine = gen.get("sestine", [])
                
                for sestina in sestine:
                    sestina_set = set(sestina)
                    matches = len(sestina_set.intersection(winning_numbers))
                    
                    if matches == 3: total_3 += 1
                    elif matches == 4: total_4 += 1
                    elif matches == 5: total_5 += 1
                    elif matches == 6: total_6 += 1
            
            if total_3 > 0 or total_4 > 0 or total_5 > 0 or total_6 > 0:
                print(f"[*] Trovate vincite per il {target_date}: 3={total_3}, 4={total_4}, 5={total_5}, 6={total_6}")
                
                # Salva in global_win_stats
                stat_data = {
                    "draw_date": target_date,
                    "total_3": total_3,
                    "total_4": total_4,
                    "total_5": total_5,
                    "total_6": total_6
                }
                client.table("global_win_stats").upsert(stat_data).execute()
                
        except Exception as e:
            print(f"[ERROR] Impossibile verificare vincite per {target_date}: {e}")

if __name__ == "__main__":
    print("--- AUTO FETCH SUPERENALOTTO ---")
    recent_draws = fetch_latest_extractions()
    sync_to_supabase(recent_draws)
    print("--- FINE ---")
