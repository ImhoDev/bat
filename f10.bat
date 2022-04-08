REM instalar windows 10 en una sola partición
REM tener cuidad se eliminaran datos del disco
REM en la instalación de windows presionar shift + f10
diskpart
list disk
REM seleccionar disco
select disk 0
REM limpiar
clean
create partition primary
create partition primary size=500000
exit 
