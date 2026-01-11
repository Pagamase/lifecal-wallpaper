# LifeCal – Backups de `route.tsx`

Estos archivos son “snapshots” de las distintas versiones de `app/year/route.tsx` que fuimos probando.

## Cómo probar una versión rápidamente
1) Abre tu proyecto: `C:\Users\pablo\lifecal-wallpaper`
2) Copia el contenido del archivo que quieras probar y pégalo en:
   `app\year\route.tsx`
3) Guarda
4) En la terminal:
   - si está corriendo: `Ctrl + C`
   - luego: `npm run dev`
5) Prueba en el navegador.

## Cómo actualizar Vercel
Usa tu .bat o:
```
git add -A
git commit -m "Switch route version"
git push
```

## Qué contiene cada archivo
- `01_route_year_19_and_birthdays_queryparam.tsx`  
  Versión “experimental” con lógica para marcar el día 19 y cumples por query param `b=...` (la que luego quitaste).
- `02_route_year_weekend_blue_variant.tsx`  
  Año normal sin cumples/19, findes en azul (primera prueba).
- `03_route_year_sat_dark_sun_red.tsx`  
  Año normal: sábado gris más oscuro, domingo rojo.
- `04_route_year_sat_light_sun_red.tsx`  
  Año normal: sábado gris más clarito (la que te gustó), domingo rojo.
- `05_route_year_sat_light_sun_red_footer_glued.tsx`  
  Igual que la 04 pero con el footer pegado al calendario + defaults 1179×2556.
- `06_route_year_progress_bar.tsx`  
  Añade barra de progreso + % (sin cumples).
- `07_route_year_progress_bar_birthdays_red_ring.tsx`  
  Barra + cumples con anillo rojo.
- `08_route_year_progress_bar_birthdays_today_halo.tsx`  
  Barra + cumples con anillo rojo + HOY con “halo” claro para diferenciarlo del domingo rojo.
