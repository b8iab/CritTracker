# CritTracker

Un addon para **Turtle WoW** (Vanilla 1.18) que rastrea tus golpes críticos más altos, DPS, kills y estadísticas de combate.

![WoW Version](https://img.shields.io/badge/WoW-1.12%20Vanilla-blue)
![Turtle WoW](https://img.shields.io/badge/Turtle%20WoW-Compatible-green)
![Version](https://img.shields.io/badge/Version-1.3-red)

## ✨ Características

### 📊 Tracking de Críticos
- **Record Global** - Tu crítico más alto de todos los tiempos
- **Record por Nivel** - El mejor crítico en cada nivel (1-60)
- **Record por Habilidad** - El mejor crítico de cada spell/ataque
- **Record de Sesión** - El mejor crítico desde que logueaste
- **Racha de Crits** - Mayor cantidad de críticos consecutivos

### ⚔️ DPS y Daño
- **Daño de Combate** - Daño acumulado en los combates recientes
- **DPS en Tiempo Real** - Se actualiza durante el combate
- **Auto-reset** - Se limpia después de 15 segundos sin actividad
- **Daño Total** - Estadísticas de sesión y totales

### 🎯 Estadísticas de Hit
- **Crit %** - Porcentaje de críticos (sesión y total)
- **Hit % Melee** - Porcentaje de aciertos melee
- **Tracking de Miss/Dodge/Parry/Block**
- **Spell Hit %** - Porcentaje de aciertos de spells

### 💀 Kills
- **Contador de Kills** - Enemigos eliminados por ti
- **Critters Separados** - Los critters se cuentan aparte
- **Detección inteligente** - Solo cuenta tus kills, no los de otros

### 🖱️ Widget Visual
- Muestra tus stats en tiempo real
- **Arrastrable** - click izquierdo para mover
- **Bloqueable** - click derecho para fijar posición
- **Tooltip detallado** - hover para más información

### 🔔 Notificaciones
- Sonido especial al romper tu **record global**
- Notificación al romper record de **nivel**
- Aviso al mejorar record de **habilidad**
- Alerta de **racha de crits** (3+)

## 📦 Instalación

1. Descarga o clona este repositorio
2. Copia la carpeta `CritTracker` a:
   ```
   Turtle WoW/Interface/AddOns/CritTracker/
   ```
3. Reinicia el juego o escribe `/reload`

## 🎮 Uso

| Acción | Resultado |
|--------|-----------|
| **Click izq + arrastrar** | Mover widget |
| **Click izq** | Ver resumen en chat |
| **Click derecho** | Bloquear/Desbloquear |
| **Hover** | Ver tooltip con estadísticas |

## 📝 Comandos

| Comando | Descripción |
|---------|-------------|
| `/crit` | Ver ayuda |
| `/crit show` | Mostrar widget |
| `/crit hide` | Ocultar widget |
| `/crit lock` | Bloquear/Desbloquear |
| `/crit announce` | Toggle notificaciones |
| `/crit stats` | Ver estadísticas completas |
| `/crit percent` | Ver % de crítico |
| `/crit hit` | Ver % de hit melee |
| `/crit spellhit` | Ver % de spell hit |
| `/crit damage` | Ver estadísticas de daño |
| `/crit kills` | Ver kills |
| `/crit streak` | Ver rachas de críticos |
| `/crit levels` | Ver records por nivel |
| `/crit spells` | Ver records por habilidad |
| `/crit reset` | Resetear posición del widget |
| `/crit clear` | Borrar todos los datos |
| `/crit debug` | Activar modo debug |

## 📊 Widget

El widget muestra:
```
CritTracker          [X]
Sesion: 1.2k
Global: 5.4k
Lvl 25: 890
Crit%: 12.5% (10.2%)
Hit%: 95.3%
Dmg: 15.6k | DPS: 125.4
Kills: 45 (+12 critters)
```

## 🔧 Configuración

Puedes ajustar el tiempo de reset del DPS editando esta línea en `CritTracker.lua`:
```lua
local COMBAT_RESET_DELAY = 15 -- Segundos sin combate para resetear
```

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
```

**Ver estadísticas de hit:**
```
/crit hit
=== Porcentaje de Hit (Melee) ===
Sesion: 94.50% hit (127 swings)
  Miss: 3 | Dodge: 2 | Parry: 2 | Block: 0
Total: 95.20% hit (1543 swings)
  Miss: 35 | Dodge: 22 | Parry: 17 | Block: 0
```

## 🌐 Idiomas Soportados

- Español
- Inglés

## 📜 Changelog

### v1.3
- Añadido DPS en tiempo real
- Daño de combate con auto-reset
- Mejor detección de kills (solo tus kills)
- Critters separados de kills normales
- Tracking de dodge/parry/block
- Racha de críticos
- Widget con mejor espaciado
- Muchas correcciones de bugs

### v1.2
- Añadido porcentaje de crit
- Añadido hit rating básico

### v1.0
- Versión inicial
- Tracking de críticos por nivel y habilidad

## 👨‍💻 Créditos

- **Autor:** b8iab con Claude (Anthropic)

## 📄 Licencia

MIT License - Siéntete libre de modificar y distribuir.

---

*¡Que tus críticos rompan records! ⚔️💥*
