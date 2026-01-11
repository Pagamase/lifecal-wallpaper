# LifeCal Selector GUI (v12 git args fix)

Lo que pasaba:
- git status devolvia 'usage: git ...' (como si no se hubiera pasado ningun comando).
- En PowerShell, $args es una variable automatica. En v11, el parametro de Run-Git se llamaba $args.
- Resultado: dentro de Run-Git, $args podia ser el automatico => argumentos vacios => git sin comando.

Fix:
- Renombrado el parametro a $gitArgs.

Instalacion:
1) Copia select-route-gui.cmd y select-route-gui.ps1 a la raiz del repo (sobrescribe).
2) Ejecuta select-route-gui.cmd
