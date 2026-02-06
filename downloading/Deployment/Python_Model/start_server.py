import time
import server_train
import sys

def start_server():
    print("==================================================")
    print("   Federated Learning Training Server (Windows)")
    print("==================================================")
    print("Press Ctrl+C to stop the server.")
    print("")
    
    try:
        while True:
            print(f"[{time.strftime('%H:%M:%S')}] Checking for updates...")
            
            # Run the training logic
            try:
                server_train.main()
            except Exception as e:
                print(f"❌ Error during training cycle: {e}")
            
            # Wait before next check
            print("Waiting 30 seconds...")
            print("--------------------------------------------------")
            time.sleep(30)
            
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user.")
        sys.exit(0)

if __name__ == "__main__":
    start_server()
