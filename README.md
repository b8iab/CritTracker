# CritTracker

Un addon para **Turtle WoW** (Vanilla 1.12) que rastrea tus golpes críticos más altos.

![WoW Version](https://img.shields.io/badge/WoW-1.12%20Vanilla-blue)
![Turtle WoW](https://img.shields.io/badge/Turtle%20WoW-Compatible-green)
![Version](https://img.shields.io/badge/Version-1.0-red)

## ✨ Características

### 📊 Tracking Completo
- **Record Global** - Tu crítico más alto de todos los tiempos
- **Record por Nivel** - El mejor crítico en cada nivel (1-60)
- **Record por Habilidad** - El mejor crítico de cada spell/ataque
- **Record de Sesión** - El mejor crítico desde que logueaste

### 🎯 Para Todas las Clases
- Detecta críticos de **melee** (autoataque, habilidades físicas)
- Detecta críticos de **spells** (magia, habilidades a distancia)
- Funciona con cualquier clase

### 🖱️ Widget Visual
- Muestra tus records en tiempo real
- **Arrastrable** - click izquierdo para mover
- **Bloqueable** - click derecho para fijar posición
- **Tooltip** con información detallada

### 🔔 Notificaciones
- Sonido especial al romper tu **record global**
- Notificación al romper record de **nivel**
- Aviso al mejorar record de **habilidad**

## 📦 Instalación

1. Copia la carpeta `CritTracker` a:
   ```
   Turtle WoW/Interface/AddOns/CritTracker/
   ```
2. `/reload` en el juego

## 🎮 Uso

| Acción | Resultado |
|--------|-----------|
| **Click izq + arrastrar** | Mover widget |
| **Click izq** | Ver resumen en chat |
| **Click derecho** | Bloquear/Desbloquear |
| **Hover** | Ver tooltip con top habilidades |

## Comandos

| Comando | Descripción |
|---------|-------------|
| `/crit` | Ver ayuda |
| `/crit stats` | Ver estadísticas completas |
| `/crit levels` | Ver records por nivel |
| `/crit spells` | Ver records por habilidad |
| `/crit show` | Mostrar widget |
| `/crit hide` | Ocultar widget |
| `/crit lock` | Bloquear/Desbloquear |
| `/crit announce` | Toggle notificaciones |
| `/crit reset` | Resetear posición |
| `/crit clear` | Borrar todos los datos |

## 📊 Datos Guardados

El addon guarda:
- Daño del crítico
- Nombre de la habilidad
- Nivel del personaje
- Nombre del target
- Fecha del crítico

## 📁 Archivos

```
CritTracker/
├── CritTracker.toc
├── CritTracker.lua
└── README.md
```

## 💡 Ejemplos

**Ver records por nivel:**
```
/crit levels
=== Records por Nivel ===
  Lvl 10: 156 (Sinister Strike)
  Lvl 15: 289 (Eviscerate)
  Lvl 20: 445 (Backstab)
  ...
```

**Ver records por habilidad:**
```
/crit spells
=== Records por Habilidad ===
  Backstab: 1250 (Lvl 42)
  Eviscerate: 980 (Lvl 40)
  Sinister Strike: 654 (Lvl 38)
  Melee: 234 (Lvl 35)
```

## 📜 Créditos

- **Autor:** b8iab con Claude (Anthropic)

## 📄 Licencia

MIT License

---

*¡Que tus críticos rompan records! ⚔️💥*