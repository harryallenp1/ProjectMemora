# 🧠 Project Memora

**Project Memora** is an AI-powered assistive mobile app built with Flutter, designed to support individuals with memory impairments by providing an intuitive, voice-enabled interface to manage reminders and important information.

---

## 🚀 Features

- 🎙️ **Voice Command Support**  
  Use your voice to add items — say “Add an item” and let Memora guide you.

- 🗣️ **Text-to-Speech Feedback**  
  Real-time audio feedback using `flutter_tts` for a more accessible experience.

- 🧾 **Add & View Items**  
  A simple, accessible UI to help users and caregivers manage essential items and tasks.

- 👤 **User Authentication**  
  Basic user session management and scoped data handling.

- 🔒 **Scoped Item Access**  
  Each user's data is kept separate and loaded based on their session.

---

## 📲 Getting Started

### 1. Clone the Repo

``bash
git clone https://github.com/harryallenp1/ProjectMemora.git
cd ProjectMemora``

**###🛠 Project Structure**
```
lib/
├── models/           # Data models (e.g., User, Item)
├── screens/          # App screens (dashboard, login, add item, etc.)
├── services/         # Database or backend interaction
├── widgets/          # Reusable UI widgets (includes voice command)
