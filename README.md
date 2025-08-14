# 🎮 Glitch - v1.0

## 📌 Nombre del proyecto
**Glitch**

---
## 📁Descarga

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
Controla el jefe final: detección del jugador, ataques con tiempo de recarga, sistema de vida y fases de furia cuando su salud es baja, este tambien cuenta con el sistema para que pueda resibir daño.

### 📊 Canvas_layer.gd
Gestiona la barra de vida del jefe: reacciona al daño y activa un efecto de desaparición al ser derrotado.

### 💰 coin.gd
Controla la recolección de monedas: al colisionar con el jugador, se suman puntos y la moneda desaparece.

### 🎯 dummy.gd
Controla al dummy de prueba: reacciona a los ataques del jugador mostrando animación de impacto.

### 👾 enemy.gd
Controla enemigos comunes: detectan al jugador, lo persiguen y atacan para reducir la vida del jugador, este tambien cuenta con el sistema para que pueda resibir daño.

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
Gestiona el control del jugador: movimientos, ataques, dash, saltos y configuración editable desde el inspector de Godot, cuenta con una parte para poder aportar al guardado, este tambien cuenta en el scrip con un sistema en la cual nos ayuda a modificar los valores del jugador y de los sonidos desde el inspector.

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
Diseñar el juego y crear los diferentes niveles fue realmente divertido y todo fluyó bastante bien.
Lo que más me costó trabajo fue hacer que todas las partes del juego se comunicaran entre sí correctamente. Por ejemplo, lograr que el sistema de puntuación funcionara bien, añadir algunos efectos visuales que se vieran bonitos, y sobre todo hacer que el juego guardara el progreso del jugador. Esto último fue especialmente complicado cuando quería que recordara cuántas monedas había recogido o qué enemigos había vencido.
Aunque me topé con estos obstáculos, la verdad es que me la pasé muy bien desarrollándolo. Creo que para ser mi primer proyecto serio, el resultado quedó bastante decente y estoy contento con lo que logré.
Me encantaría seguir mejorando este juego más adelante, o tal vez aventurarme a crear algo completamente nuevo desde cero.

---
