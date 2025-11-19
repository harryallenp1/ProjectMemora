<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=26&duration=3000&pause=1000&color=7CFFB2&center=true&vCenter=true&width=800&lines=Welcome+to+Project+Memora!;Your+AI+powered+Memory+Assistant+📱🧠" alt="Typing SVG" />

<br><br>

<img src="https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExdXg2c3dpZTY3eTIxOXgzY2ljYXZ3ampldm1zNTkyMWQ5eHdtcWg2ZCZlcD12MV9naWZzX3NlYXJjaCZjdD1n/DZmLyTjKJik4wMIeRD/giphy.gif" height="240" alt="Flutter AI App Animation"/>

<h3>🧠 Project Memora</h3>
<p><strong>Project Memora</strong> is an <em>AI-powered assistive mobile app</em> built with Flutter, designed to help individuals with memory impairments by offering an intuitive, voice-controlled platform for reminders and personal assistance.</p>

</div>

---

## 🚀 Features

| Feature | Description |
|--------|-------------|
| 🗣️ **Voice Command Support** | Add reminders and items hands-free |
| 🔊 **Text-to-Speech Feedback** | Real-time responses using `flutter_tts` |
| 📱 **Simple, Accessible UI** | Clear layouts tailored for elderly users |
| 🔐 **User Sessions & Scoped Access** | Only see your own data securely |
| 🧾 **Reminders + Items** | Manage important lists and tasks |

---

## 📸 Screenshots

| Dashboard | Voice Input | Confirmation |
|-----------|-------------|--------------|
| ![dashboard](https://github.com/yourusername/project-memora/assets/dashboard.gif) | ![voice](https://github.com/yourusername/project-memora/assets/voice.gif) | ![confirmation](https://github.com/yourusername/project-memora/assets/confirmation.gif) |

---

## 🧠 How It Works

```mermaid
graph TD
A[User Voice Command] --> B[Speech Recognizer]
B --> C[LLM Analysis (Mistral/GPT)]
C --> D[Clean Summary]
D --> E[Add to Firebase]
E --> F[User View Updated]
