import os
import json
from google import genai
from pydantic import BaseModel
from typing import List

class Curiosity(BaseModel):
    title: str
    description: str
    icon_name: str
    color_hex: str
    is_extraction_based: bool

class CuriositiesResponse(BaseModel):
    curiosities: List[Curiosity]

def generate_and_save_curiosities(hot_numbers: list, cold_numbers: list, target_date: str, supabase_client):
    print("[*] Inizializzazione Gemini Flash 1.5 per Curiosità Giornaliere...")
    
    # Preleviamo la API Key
    api_key = os.environ.get("GEMINI_API_KEY")
    
    if not api_key:
        print("[!] GEMINI_API_KEY non trovata. Impossibile generare curiosità.")
        return
        
    try:
        # Check if already generated for today
        existing = supabase_client.table("daily_curiosities").select("id").eq("target_date", target_date).execute()
        if existing.data and len(existing.data) > 0:
            print(f"[*] Curiosità già presenti per {target_date}. Salto la generazione Gemini per risparmiare API.")
            return
            
        client = genai.Client(api_key=api_key)
        
        prompt = f"""
        Sei un esperto statistico del gioco del SuperEnalotto italiano.
        Oggi è il {target_date}.
        I numeri storicamente più "Caldi" (frequenti) calcolati oggi sono: {hot_numbers}.
        I numeri storicamente più "Freddi" (ritardatari) calcolati oggi sono: {cold_numbers}.
        
        Genera esattamente 3 curiosità per gli utenti dell'app. 
        REGOLE FONDAMENTALI:
        1. Le 3 curiosità devono essere COMPLETAMENTE DIVERSE tra loro. Non ripetere mai lo stesso concetto, non dire la stessa cosa con parole diverse.
        2. Scegli 3 argomenti totalmente separati tra questi: Jackpot record, Analisi dei Ritardatari (Freddi), Analisi dei Frequenti (Caldi), Pari vs Dispari, Numeri Consecutivi, Decine più frequenti, Coincidenze storiche bizzarre.
        3. Una curiosità dovrebbe essere legata alla data di oggi ({target_date}) o ai numeri caldi/freddi attuali (is_extraction_based = true), mentre le altre due possono essere generiche o matematiche (is_extraction_based = false).
        
        Per ogni curiosità fornisci:
        - title: un titolo accattivante (max 4 parole) con un'emoji iniziale. Esempio: "🔥 I Super-Ritardatari"
        - description: un testo di massimo 2 frasi molto ingaggiante e specifico.
        - icon_name: un nome di un'icona Material Icons standard (es. "access_time_filled", "balance", "psychology", "star", "ac_unit", "trending_up").
        - color_hex: un colore esadecimale vivace (es. "#FF5252", "#448AFF", "#FFB300", "#00E676").
        - is_extraction_based: true o false a seconda del tipo.
        
        print("[*] Chiamata a Gemini in corso...")
        response = client.models.generate_content(
            model='gemini-3.6-flash',
            contents=prompt,
            config={
                'response_mime_type': 'application/json',
                'response_schema': CuriositiesResponse,
                'temperature': 0.7
            },
        )
        raw_text = response.text.strip()
        if raw_text.startswith("```json"):
            raw_text = raw_text.split("```json", 1)[1]
        if raw_text.endswith("```"):
            raw_text = raw_text.rsplit("```", 1)[0]
            
        parsed_data = json.loads(raw_text.strip())
        
        # Pydantic parsing can return dicts directly when parsed this way
        curiosities_list = parsed_data.get("curiosities", [])
        
        print(f"[*] Gemini ha generato {len(curiosities_list)} curiosità.")
        
        # Salvataggio su Supabase
        records = []
        for c in curiosities_list:
            records.append({
                "title": c.get("title", ""),
                "description": c.get("description", ""),
                "icon_name": c.get("icon_name", "star"),
                "color_hex": c.get("color_hex", "#FFFFFF"),
                "is_extraction_based": c.get("is_extraction_based", False),
                "target_date": target_date if c.get("is_extraction_based", False) else None
            })
            
        if records:
            supabase_client.table("daily_curiosities").insert(records).execute()
            print("[SUCCESS] Curiosità salvate su Supabase con successo!")
            
    except Exception as e:
        print(f"[ERROR] Errore durante la generazione delle curiosità: {e}")
        raise e
