import os
import pandas as pd
import numpy as np
from supabase import create_client, Client

SUPABASE_URL = "https://fcokqyuccicfxqxughih.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjb2txeXVjY2ljZnhxeHVnaGloIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NzE1MzkxNCwiZXhwIjoyMTAyNzI5OTE0fQ.QP66z1Qe1L9zYI_6zUAl3Rt89H2xkzTrDRGCXpQZNPg"


class SuperEnalottoDataPipeline:
    def __init__(self, output_dir=None):
        if output_dir is None:
            output_dir = os.path.join(os.path.dirname(__file__), "..", "data")
        self.output_dir = os.path.abspath(output_dir)
        os.makedirs(self.output_dir, exist_ok=True)
        self.raw_file = os.path.join(self.output_dir, "estrazioni_raw.parquet")
        self.matrix_file = os.path.join(self.output_dir, "nn_matrices.npz")
        
        # URL del Google Sheet pubblicato come CSV
        self.archive_url = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTR6n8qi3vliYpiRUltoCjO7TYLt0XFMtuzoM5u-wfmd8AcLhryYlGgde3AOgJI_EBNmfUWmPS2y9iR/pub?output=csv"

    def fetch_raw_data(self):
        """
        Scarica l'archivio storico delle estrazioni da Supabase.
        """
        print("[*] Avvio download dati grezzi da Supabase...")
        
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        # Effettuiamo una query per ottenere tutte le estrazioni, ordinate per data crescente
        response = supabase.table('historical_extractions').select('*').order('date', desc=False).execute()
        
        data = response.data
        if not data:
            print("[!] Nessun dato trovato in Supabase.")
            return pd.DataFrame()
            
        df = pd.DataFrame(data)
        
        # Rinominiamo la colonna date in data per compatibilità col resto dello script
        df = df.rename(columns={'date': 'data'})
        
        # Rimuoviamo eventuali righe vuote
        df = df.dropna(subset=['data', 'n1'])
        
        # Convertiamo la data in formato datetime
        df['data'] = pd.to_datetime(df['data'], errors='coerce')
        
        # Convertiamo le colonne dei numeri in interi
        cols_to_int = ['n1', 'n2', 'n3', 'n4', 'n5', 'n6', 'jolly', 'superstar']
        for col in cols_to_int:
            df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0).astype(int)
            
        print(f"[+] Scaricate {len(df)} estrazioni reali da Supabase.")
        return df

    def clean_and_normalize(self, df):
        """
        Pulisce i dati e assicura che il formato sia corretto per le analisi statistiche.
        """
        print("[*] Pulizia e normalizzazione dati...")
        
        # Assicuriamoci che i numeri estratti siano ordinati (N1 < N2 < N3...)
        # Questo è fondamentale per le reti neurali per evitare permutazioni inutili.
        estrazione_cols = ['n1', 'n2', 'n3', 'n4', 'n5', 'n6']
        
        # Ordinamento orizzontale dei 6 numeri base
        df[estrazione_cols] = np.sort(df[estrazione_cols].values, axis=1)
        
        # Salva in formato compresso e ottimizzato (Parquet)
        df.to_parquet(self.raw_file, engine='pyarrow')
        print(f"[+] Dati puliti salvati in: {self.raw_file}")
        
        return df

    def generate_neural_network_matrices(self, df, sequence_length=10):
        """
        Trasforma i dati grezzi in matrici One-Hot (OHE) e sequenze temporali
        per l'addestramento di reti LSTM / Transformer.
        """
        print("[*] Generazione matrici temporali per Ensemble Analytics...")
        
        estrazione_cols = ['n1', 'n2', 'n3', 'n4', 'n5', 'n6']
        num_estrazioni = len(df)
        
        # 1. Creazione della matrice One-Hot Encoding (OHE)
        # 90 colonne (da 1 a 90), 1 se il numero è uscito, 0 altrimenti
        ohe_matrix = np.zeros((num_estrazioni, 90), dtype=np.int8)
        
        for idx, row in df.iterrows():
            numeri_estratti = row[estrazione_cols].values.astype(int) - 1 # Indice 0-based
            ohe_matrix[idx, numeri_estratti] = 1
            
        # 2. Creazione del Dataset Time-Series (Finestre scorrevoli)
        # X: array 3D di shape (samples, sequence_length, 90)
        # y: array 2D di shape (samples, 90) - l'estrazione successiva
        X = []
        y = []
        
        for i in range(num_estrazioni - sequence_length):
            X.append(ohe_matrix[i : i + sequence_length])
            y.append(ohe_matrix[i + sequence_length])
            
        X = np.array(X, dtype=np.int8)
        y = np.array(y, dtype=np.int8)
        
        # 3. Creiamo anche la matrice OHE per il SuperStar (colonna 'superstar')
        # Il SuperStar va da 1 a 90. Mettiamo 0 dove non c'è.
        ohe_superstar = np.zeros((num_estrazioni, 90), dtype=np.int8)
        for idx, row in df.iterrows():
            ss = row['superstar']
            if ss > 0 and ss <= 90:
                ohe_superstar[idx, ss - 1] = 1
                
        # Salvataggio ottimizzato in formato binario NumPy (.npz)
        np.savez_compressed(
            self.matrix_file, 
            X_sequences=X, 
            y_targets=y, 
            ohe_full_history=ohe_matrix,
            ohe_superstar_history=ohe_superstar
        )
        print(f"[+] Matrici per Reti Neurali salvate in: {self.matrix_file}")
        print(f"    - Shape X (Sequenze Temporali): {X.shape}")
        print(f"    - Shape y (Target): {y.shape}")

    def run_pipeline(self):
        """Esegue l'intera pipeline."""
        df_raw = self.fetch_raw_data()
        df_clean = self.clean_and_normalize(df_raw)
        self.generate_neural_network_matrices(df_clean, sequence_length=15)
        print("\n[V] Pipeline completata con successo! Dati pronti per il Motore Ensemble.")

if __name__ == "__main__":
    pipeline = SuperEnalottoDataPipeline()
    pipeline.run_pipeline()
