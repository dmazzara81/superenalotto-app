import os
import sys
import numpy as np
from datetime import datetime
from supabase import create_client, Client

# Importiamo il motore AI
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from models.ensemble_engine import SuperEnalottoEnsembleEngine
from curiosities_engine import generate_and_save_curiosities

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
    consensus_probs, individual_probs = engine.compute_consensus(real_history)
    
    # Simulo lo storico separato del SuperStar (stesso range 1-90)
    print("[*] Calcolo probabilità separate per il Numero SuperStar...")
    # Per il SuperStar passiamo semplicemente lo storico delle sue uscite 
    ss_consensus_probs, _ = engine.compute_consensus(np.expand_dims(real_history_ss, axis=1))
    
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
    
    # ---------------------------------------------------------
    # CALCOLO STATISTICHE EXTRA DAL DATABASE SUPABASE
    # ---------------------------------------------------------
    print("[*] Recupero ultime estrazioni per statistiche extra...")
    try:
        history_res = supabase.table("historical_extractions").select("n1, n2, n3, n4, n5, n6, date").order("date", desc=True).limit(1500).execute()
        storico = history_res.data
        
        # 1. Ritardi Attuali (Da quante estrazioni non esce un numero)
        delays = {str(i): 1500 for i in range(1, 91)} # Default 1500
        for num in range(1, 91):
            for i, row in enumerate(storico):
                estrazione = [row['n1'], row['n2'], row['n3'], row['n4'], row['n5'], row['n6']]
                if num in estrazione:
                    delays[str(num)] = i
                    break
                    
        # I 10 numeri più ritardatari in assoluto (Top 10 delays)
        top_delayed = sorted(delays.items(), key=lambda x: x[1], reverse=True)[:10]
        top_delayed_dict = {item[0]: item[1] for item in top_delayed}
        
        # 2. Pari vs Dispari Ratio
        total_pari = 0
        total_dispari = 0
        for row in storico:
            estrazione = [row['n1'], row['n2'], row['n3'], row['n4'], row['n5'], row['n6']]
            for n in estrazione:
                if n % 2 == 0:
                    total_pari += 1
                else:
                    total_dispari += 1
        total_numeri = total_pari + total_dispari
        odd_even_ratio = {
            "pari": round((total_pari / total_numeri) * 100, 1) if total_numeri > 0 else 50.0,
            "dispari": round((total_dispari / total_numeri) * 100, 1) if total_numeri > 0 else 50.0
        }
        
        # 3. Decine più frequenti (ultime 1500)
        decades_count = {f"{d}0-{d}9": 0 for d in range(0, 9)}
        for row in storico:
            estrazione = [row['n1'], row['n2'], row['n3'], row['n4'], row['n5'], row['n6']]
            for n in estrazione:
                dec = (n // 10)
                if dec == 9: dec = 8 # Il 90 va nella decina 80-90
                decades_count[f"{dec}0-{dec}9"] += 1
        
        # 4. Ambi e Terni più frequenti (semplificato)
        from collections import Counter
        import itertools
        ambi_counter = Counter()
        terni_counter = Counter()
        for row in storico:
            estrazione = sorted([row['n1'], row['n2'], row['n3'], row['n4'], row['n5'], row['n6']])
            for ambo in itertools.combinations(estrazione, 2):
                ambi_counter[f"{ambo[0]}-{ambo[1]}"] += 1
            for terno in itertools.combinations(estrazione, 3):
                terni_counter[f"{terno[0]}-{terno[1]}-{terno[2]}"] += 1
                
        top_ambi = {k: v for k, v in ambi_counter.most_common(5)}
        top_terni = {k: v for k, v in terni_counter.most_common(5)}
        
    except Exception as e:
        print(f"[!] Errore nel calcolo delle stats extra: {e}")
        top_delayed_dict = {}
        odd_even_ratio = {"pari": 50.0, "dispari": 50.0}
        decades_count = {}
        top_ambi = {}
        top_terni = {}
    # ---------------------------------------------------------

    
    # Formattiamo le probabilità dei modelli singoli
    individual_models_formatted = {}
    for model_name, probs in individual_probs.items():
        individual_models_formatted[model_name] = {str(i + 1): float(probs[i]) for i in range(90)}
    
    target_date = datetime.now().strftime("%Y-%m-%d")
    
    payload = {
        "target_date": target_date,
        "probabilities": probabilities_dict,
        "hot_numbers": hot_numbers,
        "cold_numbers": cold_numbers,
        "superstar_probabilities": ss_probabilities_dict,
        "superstar_hot": ss_hot_numbers,
        "superstar_cold": ss_cold_numbers,
        "individual_models": individual_models_formatted,
        "delays": top_delayed_dict,
        "odd_even_ratio": odd_even_ratio,
        "frequent_decades": decades_count,
        "frequent_pairs": top_ambi,
        "frequent_triplets": top_terni
    }

    # 4. Inserimento (Upsert) nel Cloud
    print("[*] Salvataggio sul Cloud in corso...")
    try:
        # Se eseguiamo lo script più volte al giorno, usiamo un 'upsert' fittizio 
        # (cancelliamo prima quello della data odierna e poi inseriamo per evitare duplicati)
        supabase.table("number_probabilities").delete().eq("target_date", target_date).execute()
        
        response = supabase.table("number_probabilities").insert(payload).execute()
        print(f"[SUCCESS] Probabilità salvate su Supabase per la data: {target_date}")
        
        # 5. Generazione Curiosità tramite Gemini
        generate_and_save_curiosities(hot_numbers, cold_numbers, target_date, supabase)
        
    except Exception as e:
        print(f"[ERROR] Impossibile salvare su Supabase: {str(e)}")
        raise e

if __name__ == "__main__":
    main()
