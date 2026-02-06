//  LegalContent.swift
//  Legal and support content for the app

import SwiftUI

struct LegalDetailView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalData {
    static let termsAndConditions = """
    Terms and Conditions

    1. Medical Disclaimer
    This application ("App") is designed as a support tool for medical image analysis. It is NOT intended to replace professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.

    2. Accuracy of Results
    While we strive for high accuracy, the AI models used in this App may produce errors, false positives, or false negatives. The results provided by the App should be verified by a qualified medical professional.

    3. User Responsibility
    You acknowledge that you are using this App at your own risk. The developers are not liable for any decisions made based on the App's analysis.

    4. Usage
    You agree to use this App only for lawful purposes and in accordance with these Terms.

    5. Updates
    We reserve the right to modify these Terms at any time. Continued use of the App constitutes acceptance of the modified Terms.
    """
    
    static let privacyPolicy = """
    Privacy Policy

    1. Data Collection
    This App processes medical images primarily on your device (Offline Mode). When using Online Mode, images are sent to a secure server for analysis and are not permanently stored unless explicitly stated.

    2. Personal Information
    We respect your privacy. The User Profile information (Name, Email, Institution) is stored locally on your device to personalize your experience and reports.

    3. Data Security
    We implement reasonable security measures to protect your data. However, no method of transmission over the internet or electronic storage is 100% secure.

    4. Third-Party Services
    We do not sell or share your personal data with third parties for marketing purposes.

    5. Changes to Policy
    We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.
    """
    
    static let qAndA = """
    Q&A (Questions & Answers)

    Q: How does the AI analysis work?
    A: The App uses advanced deep learning models (YOLOv8) to detect potential abnormalities in CT scans. It analyzes the image patterns to identify specific features associated with medical conditions.

    Q: What is the difference between Online and Offline Mode?
    A: 
    *   Offline Mode: Runs entirely on your device using a lightweight TFLite model. It is faster and works without internet but may be slightly less accurate.
    *   Online Mode: Sends the image to a powerful server for analysis. It may provide higher accuracy but requires an internet connection.

    Q: Can I use this for diagnosis?
    A: No. This App is a screening and support tool. It should NOT be used as the sole basis for a medical diagnosis. All results must be reviewed by a specialist.

    Q: How do I delete my data?
    A: You can go to Settings > Data Management and select "Delete Present Account". This will remove your profile and all local scan history.

    Q: Who can I contact for support?
    A: If you encounter issues, please contact your institution's IT support or the development team responsible for this deployment.
    """
}
