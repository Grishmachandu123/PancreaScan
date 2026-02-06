import os
import json
import time
import shutil
from datetime import datetime

# Configuration
# Configuration
# Point to the PHP Backend folders relative to this script
PHP_BACKEND_DIR = os.path.join(os.path.dirname(__file__), "..", "PHP_Backend")
UPDATES_DIR = os.path.join(PHP_BACKEND_DIR, "fl_updates")
MODELS_DIR = os.path.join(PHP_BACKEND_DIR, "models")

MODEL_FILENAME = "pancreas.tflite"
VERSION_FILENAME = "version.txt"
MIN_UPDATES_TO_TRAIN = 1

def load_updates():
    """Load all JSON update files from the updates directory."""
    updates = []
    if not os.path.exists(UPDATES_DIR):
        print(f"Directory {UPDATES_DIR} does not exist.")
        return []

    for filename in os.listdir(UPDATES_DIR):
        if filename.endswith(".json"):
            filepath = os.path.join(UPDATES_DIR, filename)
            try:
                with open(filepath, 'r') as f:
                    data = json.load(f)
                    updates.append(data)
            except Exception as e:
                print(f"Error loading {filename}: {e}")
    return updates

def train_model(updates):
    """
    Simulate training process.
    In a real scenario, this would load the TFLite model, apply gradients/retrain, and export.
    For this demo, we will just 'touch' the model file to simulate a new version.
    """
    print(f"Starting training with {len(updates)} new samples...")
    print("Optimization in progress...")
    time.sleep(2) # Simulate processing
    
    # In a real app, you would use TensorFlow/PyTorch here.
    # For now, we assume the base model is good and we just acknowledge the updates.
    # We will pretend the model has improved.
    
    # Path validity check
    model_path = os.path.join(MODELS_DIR, MODEL_FILENAME)
    if not os.path.exists(model_path):
        print(f"Warning: Base model {model_path} not found. Creating a dummy one if needed.")

    # Archive processed updates (optional, for now just leave them or delete them)
    # logic to delete processed updates to avoid re-training on same data
    for filename in os.listdir(UPDATES_DIR):
        filepath = os.path.join(UPDATES_DIR, filename)
        try:
            os.remove(filepath)
            print(f"Processed and removed {filename}")
        except Exception as e:
            print(f"Error removing {filename}: {e}")
            
    return True

def update_version():
    """Increment/Update version file."""
    version_path = os.path.join(MODELS_DIR, VERSION_FILENAME)
    
    # improved versioning: 1.0.{timestamp}
    new_version = f"1.0.{int(time.time())}"
    
    with open(version_path, 'w') as f:
        f.write(new_version)
    
    print(f"Model version updated to: {new_version}")

def main():
    print("=== Federated Learning Server Automation ===")
    
    updates = load_updates()
    print(f"Found {len(updates)} pending updates.")
    
    if len(updates) >= MIN_UPDATES_TO_TRAIN:
        if train_model(updates):
            update_version()
            print("✅ Training complete. New model deployed.")
    else:
        print(f"Not enough updates to trigger training (Need {MIN_UPDATES_TO_TRAIN}). Waiting...")

if __name__ == "__main__":
    main()
