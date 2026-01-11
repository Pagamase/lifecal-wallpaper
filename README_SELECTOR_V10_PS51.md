# LifeCal Selector GUI (v10 PS5.1 compatible)

Tu error:
- "No se encuentra ningun parametro ... 'AsHashtable'"

Causa:
- ConvertFrom-Json -AsHashtable existe en PowerShell 6/7, pero NO en PowerShell 5.1 (el tipico de Windows).

Fix:
- Convertimos ConvertFrom-Json a Hashtable con una funcion To-Hashtable, compatible con PS 5.1.

Instalacion:
- Copia select-route-gui.cmd y select-route-gui.ps1 a la raiz del repo (sobrescribe).
- Ejecuta select-route-gui.cmd
