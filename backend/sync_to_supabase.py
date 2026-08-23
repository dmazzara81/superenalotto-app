import os
import sys
import numpy as np
from datetime import datetime
from supabase import create_client, Client

# Importiamo il motore AI
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from models.ensemble_engine import SuperEnalottoEnsembleEngine

# ==============================================================================
# CONFIGURAZIONE SUPABASE
# ==============================================================================
# Usa la tua VERA URL (la stessa di Flutter)
SUPABASE_URL = "https://fcokqyuccicfxqxughih.supabase.co"
# ATTENZIONE: Nel backend Python DEVI usare la "service_role key" (chiave segreta), 
# NON la anon key pubblica. La service_role bypassa le policy RLS in modo che 
# il server possa scrivere nel database.
# Puoi trovarla su Supabase: Project Settings -> API -> service_role secret
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjb2txeXVjY2ljZnhxeHVnaGloIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NzE1MzkxNCwiZXhwIjoyMTAyNzI5OTE0fQ.QP66z1Qe1L9zYI_6zUAl3Rt89H2xkzTrDRGCXpQZNPg"

def main():
    print("[*] Avvio Routine Sincronizzazione Supabase...")
    
    # Blocco sicurezza rimosso, assumiamo che la chiave configurata sia quella corretta (service_role)


    # 1. Connessione a Supabase
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # 2. Inizializzazione ed Esecuzione del Motore AI
    engine = SuperEnalottoEnsembleEngine()
    
    # Carichiamo i dati reali processati dal data pipeline
    print("[*] Caricamento dati storici reali...")
    try:
        matrix_path = os.path.join(os.path.dirname(__file__), 'data', 'nn_matrices.npz')
        loaded = np.load(matrix_path)
        real_history = loaded['X_sequences']
        real_history_ss = loaded['ohe_superstar_history']
    except Exception as e:
        print(f"[!] Errore nel caricamento dei dati reali ({e}). Assicurati di aver eseguito 'python backend/data_pipeline/importer.py'. Uso fallback.")
        real_history = np.zeros((100, 15, 90))
        real_history_ss = np.zeros((100, 90))
        
    print("[*] Esecuzione calcolo consenso Sestina...")
    consensus_probs = engine.compute_consensus(real_history)
    
    # Simulo lo storico separato del SuperStar (stesso range 1-90)
    print("[*] Calcolo probabilità separate per il Numero SuperStar...")
    # Per il SuperStar passiamo semplicemente lo storico delle sue uscite 
    ss_consensus_probs = engine.compute_consensus(np.expand_dims(real_history_ss, axis=1))
    
    # 3. Formattazione Dati per il Database
    # Creiamo il JSONB e le array richieste dalla tabella SQL `number_probabilities`
    probabilities_dict = {str(i + 1): float(consensus_probs[i]) for i in range(90)}
    ss_probabilities_dict = {str(i + 1): float(ss_consensus_probs[i]) for i in range(90)}
    
    # Estraiamo i 10 numeri più probabili ("Caldi") e i 10 meno probabili ("Freddi") per la Sestina
    sorted_indices = np.argsort(consensus_probs)
    cold_numbers = [int(idx + 1) for idx in sorted_indices[:10]]
    hot_numbers = [int(idx + 1) for idx in sorted_indices[::-1][:10]]
    
    # Estraiamo i numeri Caldi e Freddi per il SuperStar
    ss_sorted_indices = np.argsort(ss_consensus_probs)
    ss_cold_numbers = [int(idx + 1) for idx in ss_sorted_indices[:10]]
    ss_hot_numbers = [int(idx + 1) for idx in ss_sorted_indices[::-1][:10]]
    
    target_date = datetime.now().strftime("%Y-%m-%d")
    
    payload = {
        "target_date": target_date,
        "probabilities": probabilities_dict,
        "hot_numbers": hot_numbers,
        "cold_numbers": cold_numbers,
        "superstar_probabilities": ss_probabilities_dict,
        "superstar_hot": ss_hot_numbers,
        "superstar_cold": ss_cold_numbers
    }

    # 4. Inserimento (Upsert) nel Cloud
    print("[*] Salvataggio sul Cloud in corso...")
    try:
        # Se eseguiamo lo script più volte al giorno, usiamo un 'upsert' fittizio 
        # (cancelliamo prima quello della data odierna e poi inseriamo per evitare duplicati)
        supabase.table("number_probabilities").delete().eq("target_date", target_date).execute()
        
        response = supabase.table("number_probabilities").insert(payload).execute()
        print(f"[SUCCESS] Probabilità salvate su Supabase per la data: {target_date}")
    except Exception as e:
        print(f"[ERROR] Impossibile salvare su Supabase: {str(e)}")

if __name__ == "__main__":
    main()
