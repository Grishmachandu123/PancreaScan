# 🛠️ Fixing Build Errors

I have **already fixed the code error** (the extra space) in the file.

The other errors you see are because **Xcode is trying to run the iOS app on your Mac**.

## 1. Fix "No such module 'UIKit'"
**Problem:** You are building for "My Mac".
**Solution:**
1.  Look at the **top bar** of Xcode (near the Play button).
2.  Click where it says **"FederatedMLApp > My Mac"**.
3.  Select an **iPhone Simulator** (e.g., "iPhone 15 Pro").

## 2. Fix "TensorFlowLiteSwift not found"
**Problem:** You might be in the wrong project file.
**Solution:**
1.  **Close Xcode** completely.
2.  Open the **white icon** file:
    ```
    FederatedMLApp.xcworkspace
    ```
    *(Do NOT open the blue .xcodeproj file)*

## 3. "Extraneous whitespace"
**Status:** ✅ **FIXED**
I removed the space in `intersection.width` in the previous step. It will go away when you build again.

---

### 🚀 Try Again
1.  Open `FederatedMLApp.xcworkspace`
2.  Select **iPhone 15 Pro**
3.  Press **Cmd + R**
