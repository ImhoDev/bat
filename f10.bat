REM instalar windows 10 en una sola partición
REM tener cuidad se eliminaran datos del disco
REM en la instalación de windows presionar shift + f10
diskpart
list disk
REM seleccionar disco
select disk 0
REM limpiar
REM tener encuenta que se perderán todos los datos del disco con este comando
clean
REM por defecto el sistema de partición es MBR
REM convertir a sistema a GPT
convert gpt
REM convertir a MBR
convert mbr
create partition primary
create partition primary size=500000
exit 
