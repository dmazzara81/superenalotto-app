from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
from datetime import datetime
import os
import sys

# Aggiungiamo il path per importare l'engine
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from models.ensemble_engine import SuperEnalottoEnsembleEngine

app = FastAPI(
    title="SuperEnalotto Ensemble API",
    description="API per servire le previsioni AI all'app Flutter",
    version="1.0.0"
)

# Configurazione CORS per permettere chiamate dal frontend Flutter/Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In produzione restringere ai domini dell'app
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inizializziamo l'engine all'avvio del server tenendolo in memoria
engine = SuperEnalottoEnsembleEngine()

class ConsensusResponse(BaseModel):
    target_date: str
    consensus_vector: dict
    top_numbers: list

@app.get("/")
def read_root():
    return {"status": "ok", "message": "SuperEnalotto API is running."}

@app.get("/api/consensus", response_model=ConsensusResponse)
def get_consensus_probabilities():
    """
    Ritorna il Vettore di Consenso calcolato dai 9 modelli.
    Normalmente, in produzione, il server leggerebbe questo dato da Supabase 
    o da una cache in memoria calcolata in background (cronjob notturno).
    Per ora simuliamo il run real-time.
    """
    try:
        # Simuliamo un dataset storico di input per far generare la previsione
        # Nella realtà preleveremmo il file 'data/nn_matrices.npz' generato dall'importer
        dummy_history = np.zeros((100, 15, 90)) 
        
        # 1. Calcolo Probabilità
        consensus_probs = engine.compute_consensus(dummy_history)
        
        # 2. Strutturiamo il dizionario: { numero (1-90) : probabilità_normalizzata }
        # Assicuriamoci che i valori siano float python standard, non numpy.float64
        consensus_dict = {
            str(i + 1): float(consensus_probs[i]) for i in range(90)
        }
        
        # 3. Individuiamo i Top 10 numeri "più caldi"
        top_indices = np.argsort(consensus_probs)[::-1][:10]
        top_numbers = [int(idx + 1) for idx in top_indices]

        return ConsensusResponse(
            target_date=datetime.now().strftime("%Y-%m-%d"),
            consensus_vector=consensus_dict,
            top_numbers=top_numbers
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore interno del motore: {str(e)}")

# NOTA SULLA SICUREZZA E SUPABASE:
# In uno scenario avanzato, potremmo aggiungere una Dependency in FastAPI 
# che verifica il JWT inviato da Flutter (tramite supabase.auth.admin) 
# per bloccare la chiamata API se l'utente non è PRO.
# 
# Esempio concettuale (non attivo):
# def verify_pro_user(token: str):
#    user = supabase.auth.get_user(token)
#    if non_è_pro(user):
#        raise HTTPException(403, "Devi essere utente PRO")
