# 🎮 Glitch - GitHub Release v1.0

## 📌 Nombre del proyecto
**Glitch**

---

## 📝 Descripción
**Glitch** es un juego de plataformas 2D desarrollado en **Godot 4**, donde el protagonista, un "glitch", utiliza habilidades únicas de *glitcheo* para navegar por un mundo digital lleno de desafíos.  
La aventura comienza en una zona natural y culmina en una cueva oscura llena de enemigos más fuertes, que resguardan la puerta del jefe final.

---

## ⚙️ Mecánicas de juego
- Movimiento fluido
- Dash
- Ataques
- Sistema de vida (se reinicia al morir)
- Sistema de puntos (se reinicia según los puntos obtenidos al entrar a la escena)

---

## 🗡️ Habilidades de Glitcheo

**Ataques:**
1. Espadazo
2. Disparo
3. Disparo

**Especiales:**
1. Fluir
2. Glitch
3. Explosión

---

## 🖼️ Assets utilizados

### Sprites
- **Dummy:** Hited(NoArmor)1 → Hited(NoArmor)5, Idle(NoArmor)
- **Player:** player_1 → player_199
- **Enemigo:** NightBoerne
- **Boss:** attack 1, attack 2, idle, walk, free Smoke Fx pixel
- **Barras de vida:** Barradevidapersonal, Barradevidapersona2l, health_bar, health_bar_decoration
- **Monedas:** red_crystal_0000 → red_crystal_0003
- **Nivel:** BG_1, BG_2, BG_3, BG_3_alt, Free, Mockup, Terrain-and_Props-OLD, Terrain-and_Props, 0x72_16x16RobotTileset.v1, Fondo PNG, TileSet PNG

---

## 📜 Scripts utilizados

### 🎯 Boss.gd
Controla al jefe final: detección de jugador, ataques con cooldown, sistema de vida y fases de furia.

### 📊 Canvas_layer.gd
Controla la barra de vida del boss, reacción al daño y efecto al ser derrotado.

### 💰 coin.gd
Gestiona monedas: detección de colisión, recolección y suma de puntos.

### 🎯 dummy.gd
Controla al dummy, reacciona a ataques mostrando animación de golpe.

### 👾 enemy.gd
Controla enemigos: detección de jugador, persecución y ataques.

### ❤️ HealthManager.gd
Controla barra de vida del jugador, guarda y carga daño (con errores visuales).

### 🏷️ hudpuntos.gd
Muestra puntos obtenidos en pantalla en tiempo real.

### 📊 Labelpuntos.gd
Muestra puntos totales al final del juego.

### 🖥️ menu.gd
Controla el menú principal: nueva partida, cargar, salir.

### ⏸️ node.gd
Controla el *popup* de pausa, deteniendo el juego.

### 🛑 pausa.gd
Controla la pantalla de pausa: guardar partida, salir al menú o cerrar juego.

### 🕹️ player.gd
Controla al jugador: movimientos, ataques, dash, salto y personalización desde el inspector.

### 📈 PointSystem.gd
Sistema de puntos por enemigos y monedas.

### 💾 SaveSystem.gd
Sistema de guardado: vida, puntos, posición, escena y carga de datos.

---

## 💬 Comentarios finales
La creación de las mecánicas y escenarios fue relativamente sencilla, pero conectar nodos, manejar puntos, efectos visuales y el sistema de guardado fue un desafío.  
Tuve dificultades al guardar datos tras recolectar monedas o derrotar enemigos, pero disfruté mucho el proceso de desarrollo.  
Es posible que en el futuro cree un juego personal o mejore este proyecto.  
Para mi nivel actual de conocimiento, estoy satisfecho con el resultado.

---
