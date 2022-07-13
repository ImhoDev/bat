REM comando para eliminar el indentificador de seguridad de windows y generear otro, util luego de clonar una instalación
REM ejecutar el bat como administrador, o abrir cmd como administrador y ejecutamos el comando
reg delete HKLM\SOFTWARE\MICROSOFT\SQMCLIENT /V MachineId /f
