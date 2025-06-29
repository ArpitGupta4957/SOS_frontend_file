
# 🚨 SOS Mobile App (Flutter)

This is the **user-side mobile application** for the SOS Emergency Response System. It allows users to instantly report fire, medical, or crime emergencies by capturing images and location data. The app uses AI to verify incidents and ensures fast and secure communication with emergency responders.

---

## 📱 Features

- 📸 **Image Capture & Upload**
- 🧠 **AI Verification (YOLOv8)**
- 📍 **Real-time GPS Tracking**
- 🗂️ **Emergency Categorization (Fire, Medical, Crime)**
- 🔐 **AES Encryption for Secure Upload**
- 📡 **Live Sync with Supabase**
- 📬 **Real-time Status Notifications**
- 👥 **Login, Register, and Session Management**

---

## 🏗 Project Structure

```
/lib/
├── main.dart                  # Entry point
├── screens/                   # UI screens (Login, Home, EmergencyForm, etc.)
├── services/                  # Supabase and AI-related logic
├── widgets/                   # Reusable widgets
├── models/                    # Data models
├── utils/                     # AES encryption, geolocation, etc.

/assets/
├── images/                    # App images
```

---

## ⚙️ Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/sos-flutter-app.git
cd sos-flutter-app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

Create a `.env` or use your `lib/services/supabase.dart` to add:

```dart
const supabaseUrl = "https://xyz.supabase.co";
const supabaseKey = "your-public-anon-key";
```

---

## ▶️ Run the App

```bash
flutter run
```

Make sure a device/emulator is running.

---

## 🔐 Security

- **AES encryption** is applied to images before uploading.
- Data is securely stored and transmitted via Supabase and HTTPS.
- Only verified officials can view and respond to emergency reports.

---

## 🧑‍⚕️ Emergency Flow

1. User captures an image (fire/medical/crime).
2. AI model (YOLOv8) verifies the emergency.
3. Data is AES encrypted and sent to Supabase.
4. Officials are notified and can view, accept or reject requests.

---

## 🧰 Tech Stack

- [Flutter](https://flutter.dev/)
- [Supabase](https://supabase.com/)
- [YOLOv8](https://docs.ultralytics.com/)
- [Google Maps API](https://developers.google.com/maps)
- AES Encryption (Dart Implementation)

---

## 🙋 Author

**Arpit Gupta**  
Developed as part of the SOS Emergency Management System.

---

## 📄 License

This project is licensed under the MIT License.
