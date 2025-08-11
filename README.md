# 🎮 Glitch - GitHub Release v1.0

## 📌 Nombre del proyecto
**Glitch**

---
##📁Descarga

https://www.mediafire.com/file/itsuliri1mec7iw/GlitchFinal.zip/file?dkey=wwc5o61zc7g&r=1043
---
## 📝 Descripción
**Glitch** es un juego de plataformas 2D desarrollado en **Godot 4**, protagonizado por un curioso "glitch" que utiliza habilidades únicas para atravesar un mundo digital lleno de retos.  
La aventura inicia en una zona natural y avanza hasta llegar a una cueva oscura habitada por enemigos más poderosos.  
En lo más profundo, se encuentra la puerta que custodia al jefe final.

---

## ⚙️ Mecánicas principales
- Movimiento fluido
- Dash
- Ataques cuerpo a cuerpo y a distancia
- Sistema de vida que se reinicia al morir
- Sistema de puntuación que se ajusta según los puntos obtenidos al entrar a cada escena

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

## 🖼️ Recursos visuales utilizados

### Sprites
- **Dummy:** Hited(NoArmor)1 a Hited(NoArmor)5, Idle(NoArmor)
- **Player:** player_1 a player_199
- **Enemigo:** NightBoerne
- **Boss:** attack 1, attack 2, idle, walk, free Smoke Fx pixel
- **Barras de vida:** Barradevidapersonal, Barradevidapersona2l, health_bar, health_bar_decoration
- **Monedas:** red_crystal_0000 a red_crystal_0003
- **Escenarios:** BG_1, BG_2, BG_3, BG_3_alt, Free, Mockup, Terrain-and_Props-OLD, Terrain-and_Props, 0x72_16x16RobotTileset.v1, Fondo PNG, TileSet PNG

---

## 📜 Scripts implementados

### 🎯 Boss.gd
Controla el jefe final: detección del jugador, ataques con tiempo de recarga, sistema de vida y fases de furia cuando su salud es baja.

### 📊 Canvas_layer.gd
Gestiona la barra de vida del jefe: reacciona al daño y activa un efecto de desaparición al ser derrotado.

### 💰 coin.gd
Controla la recolección de monedas: al colisionar con el jugador, se suman puntos y la moneda desaparece.

### 🎯 dummy.gd
Controla al dummy de prueba: reacciona a los ataques del jugador mostrando animación de impacto.

### 👾 enemy.gd
Controla enemigos comunes: detectan al jugador, lo persiguen y atacan para reducir su vida.

### ❤️ HealthManager.gd
Gestiona la barra de vida del jugador: guarda y carga el daño recibido (presenta algunos errores visuales pendientes de corregir).

### 🏷️ hudpuntos.gd
Actualiza en tiempo real la puntuación obtenida y la muestra en pantalla.

### 🖥️ menu.gd
Controla el menú principal: iniciar nueva partida, cargar partida guardada o salir del juego.

### ⏸️ node.gd
Controla la ventana emergente de pausa: detiene el juego mientras está activa.

### 🛑 pausa2.gd
Gestiona el menú de pausa: guardar partida, volver al menú principal o salir del juego.

### 🕹️ player.gd
Gestiona el control del jugador: movimientos, ataques, dash, saltos y configuración editable desde el inspector de Godot.

### 📈 PointSystem.gd
Sistema de puntos: otorga puntuación por derrotar enemigos, recoger monedas y vencer al jefe.

### 💾 SaveSystem.gd
Sistema de guardado: almacena vida, puntuación, posición, escena actual y permite cargar la partida.

---
### 📹Videosm Del Juego


https://github.com/user-attachments/assets/57a5d0ca-81a5-4360-a4dc-5c24747733da




https://github.com/user-attachments/assets/1970c15e-df61-4f13-9bac-514e53d74196





---

## 💬 Comentarios finales
Crear las mecánicas y los escenarios resultó una experiencia fluida y entretenida.  
Los mayores retos fueron conectar nodos, sincronizar el sistema de puntos, implementar algunos efectos visuales y configurar correctamente el sistema de guardado, especialmente al intentar registrar monedas recogidas o enemigos derrotados.  

A pesar de esas dificultades, disfruté mucho el proceso y considero que el resultado es satisfactorio para mi nivel actual de conocimiento.  
En el futuro, me gustaría mejorar este proyecto o desarrollar un juego completamente nuevo.

---
