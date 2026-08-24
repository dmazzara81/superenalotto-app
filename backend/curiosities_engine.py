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
        client = genai.Client(api_key=api_key)
        
        prompt = f"""
        Sei un esperto statistico del gioco del SuperEnalotto italiano.
        Oggi è il {target_date}.
        I numeri storicamente più "Caldi" (frequenti) calcolati oggi sono: {hot_numbers}.
        I numeri storicamente più "Freddi" (ritardatari) calcolati oggi sono: {cold_numbers}.
        
        Genera esattamente 10 curiosità per gli utenti dell'app:
        - 5 devono essere curiosità "generali" o matematiche sul lotto/superenalotto (is_extraction_based = false).
        - 5 devono riguardare specificamente i numeri caldi o freddi di oggi, trend del periodo, o coincidenze con la data di oggi (is_extraction_based = true).
        
        Per ogni curiosità fornisci:
        - title: un titolo accattivante (max 4 parole) con un'emoji iniziale. Esempio: "🔥 I Super-Ritardatari"
        - description: un testo di massimo 2 frasi molto ingaggiante.
        - icon_name: un nome di un'icona Material Icons standard (es. "access_time_filled", "balance", "psychology", "star", "ac_unit").
        - color_hex: un colore esadecimale vivace (es. "#FF5252", "#448AFF", "#FFB300", "#00E676").
        - is_extraction_based: true per le 5 legate ad oggi, false per le 5 generali.
        """
        
        print("[*] Chiamata a Gemini in corso...")
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config={
                'response_mime_type': 'application/json',
                'response_schema': CuriositiesResponse,
                'temperature': 0.7
            },
        )
        
        parsed_data = json.loads(response.text)
        curiosities_list = parsed_data.get("curiosities", [])
        
        print(f"[*] Gemini ha generato {len(curiosities_list)} curiosità.")
        
        # Salvataggio su Supabase
        records = []
        for c in curiosities_list:
            records.append({
                "title": c["title"],
                "description": c["description"],
                "icon_name": c["icon_name"],
                "color_hex": c["color_hex"],
                "is_extraction_based": c["is_extraction_based"],
                "target_date": target_date if c["is_extraction_based"] else None
            })
            
        if records:
            supabase_client.table("daily_curiosities").insert(records).execute()
            print("[SUCCESS] Curiosità salvate su Supabase con successo!")
            
    except Exception as e:
        print(f"[ERROR] Errore durante la generazione delle curiosità: {e}")
