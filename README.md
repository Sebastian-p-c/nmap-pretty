# 🛰️ nmap-pretty

**Tagline:**  
🎯 `nmap-pretty` — Una herramienta ligera en Bash para formatear, colorear y visualizar de forma clara los resultados de **Nmap**, ideal para entornos de **HackTheBox**, **TryHackMe**, auditorías y CTFs.

---

## 📖 Descripción general

`nmap-pretty` transforma la salida cruda de **Nmap** (formato texto o grepable `-oG`) en un formato **estructurado, legible y visualmente atractivo**, utilizando colores, alineación de columnas y resaltado de servicios críticos.  

Esta herramienta está pensada para quienes escanean múltiples objetivos y desean **entender resultados de un vistazo** sin perder tiempo entre líneas poco legibles de Nmap.

Diseñada para pentesters, analistas de ciberseguridad y entusiastas del hacking ético, `nmap-pretty` facilita el flujo de trabajo en laboratorios o entornos reales.

---

## ⚙️ Características principales

- 🧩 **Lectura directa de archivos** Nmap (`-oG`, `-sV`, `-sC`, etc.)
- 🎨**Colores dinámicos** según el estado del puerto (`open`, `filtered`, `closed`, etc.)
- 📊 **Tabla formateada** con columnas alineadas:  
  `PORT | STATE | PROTO | SERVICE | VERSION/EXTRA`
- 💾 **Salida JSON opcional** (`-j`) para integraciones y automatización
- 🔍 **Detección automática de secciones extra** (como `Ignored State`)
- 🧠 **Reconocimiento de servicios críticos** (LDAP, Kerberos, HTTP, SMB, RPC)
- 💡 **Listo para HackTheBox / TryHackMe / Auditorías**

---

## 📦 Instalación

### 🔹Instalación

git clone https://github.com/Sebastian-p-c/nmap-pretty.git

cd nmap-pretty

chmod +x nmap_pretty.sh

./nmap_pretty.sh path/to/nmap_output.txt

con la opción JSON:

./nmap_pretty.sh -j path/to/nmap_output.txt > salida.json
