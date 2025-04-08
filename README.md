# 🧠 Project Memora – Elaboration Release (Iteration 1)

## 📌 Overview

**Project Memora** is an AI-powered assistive mobile application designed to support individuals with memory impairments. The app enables users to set reminders, receive notifications, and will eventually include features like facial recognition and route guidance for daily support.

This iteration focuses on:
- Designing the software architecture
- Implementing a core, architecturally significant feature
- Building the foundation for future iterations

---

## 🚀 Features Implemented (Iteration 1)

### ✅ Reminder Creation
- Users can input a title and time to create a new reminder
- Reminder data is sent to a Python-based API and stored in **Firebase**
- A confirmation is shown upon success

---

## 🏗️ Architecture

- **Architecture Pattern**: Layered Architecture with Domain-Driven Design
- **Reference Application Architecture**: Information System
- **Subsystems Modeled**:
  - Reminder Service
  - Authentication (Planned)
  - Facial Recognition (Planned)
  - Database Integration
- **Design Tools**: Visual Paradigm (Design & Interaction Models), Figma (UI Prototyping)

---

## 🖥️ Tech Stack

| Layer         | Technology                      |
|---------------|---------------------------------|
| UI            | Figma (Prototype)               |
| Backend       | Python (FastAPI or Flask)       |
| Database      | Firebase (Firestore or Realtime DB) |
| Version Control | Git + Bitbucket               |
| DevOps        | Docker (optional), Git CLI      |

---

## 📂 Project Structure
---

## 🔧 Running the Backend (Locally)

### 1. Clone the Repo
```bash
git clone https://bitbucket.org/your-repo/project-memora.git
cd backend
