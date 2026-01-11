# LifeCal v13 - Editor de estilo desde GUI

QUE TE DA:
- Boton "Editar estilo" en la GUI para cambiar SOLO estetica:
  - colores (domingo, sabado, hoy, pasado, futuro, etc.)
  - margenes y separaciones (porcentaje)
  - anillo de domingo on/off
  - lista de cumples (MM-DD)
- Boton "Git push cambios" para subir cualquier cambio (incluye style.json).
- En el editor: "Guardar + Push".

INSTALACION (1 vez):
1) Copia estos 2 archivos a la raiz del repo y sobrescribe:
   - select-route-gui.cmd
   - select-route-gui.ps1

2) Copia app/year/style.json a:
   C:\Users\pablo\lifecal-wallpaper\app\year\style.json

3) Para que el route use style.json necesitas aplicar la version 10:
   - Copia backups/10_route_year.tsx a tu carpeta de backups (la que usas en la GUI)
   - Selecciona 10_route_year.tsx en la GUI
   - "Aplicar (copiar a route.tsx)"
   - (opcional) tick push automatico

USO:
- Abre la GUI > "Editar estilo"
- Cambia colores/margenes/cumples
- "Guardar + Push"


FIX v13.1:
- Se ha subido el MAX de los porcentajes a 0.95 para permitir contentWidthPct=0.72 sin error.
