#!/bin/bash

# Definir el directorio a analizar, usa PWD si no se proporciona un argumento
DIRECTORIO="${1:-$(pwd)}"
SALIDA_HTML="reporte_warnings.html"

# Expresión regular para detectar warnings (ajústala según tu formato)
PATRON_WARNING="(WARNING|Warning|warning).*"

# Encabezado del HTML
echo "<html>
<head>
    <title>Reporte de Warnings COBOL Unisys</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
<h2>Reporte de Warnings COBOL Unisys</h2>" > "$SALIDA_HTML"

echo "<h3>Archivos Analizados en: $DIRECTORIO</h3>" >> "$SALIDA_HTML"

# Tabla para mostrar el total de cada tipo de warning
echo "<table>
<tr><th>Tipo de Warning</th><th>Total</th></tr>" >> "$SALIDA_HTML"

# Diccionario asociativo para contar warnings por tipo
declare -A WARNINGS_TOTALES

# Procesar cada archivo en el directorio
for archivo in "$DIRECTORIO"/*; do
    if [[ -f "$archivo" ]]; then
        # Inicializar tabla para este archivo
        echo "<h3>Archivo: $(basename "$archivo")</h3>
        <table>
        <tr><th>Número de Línea</th><th>Mensaje de Warning</th></tr>" >> "$SALIDA_HTML"

        # Leer el archivo línea por línea
        while IFS= read -r linea || [[ -n "$linea" ]]; do
            if [[ "$linea" =~ $PATRON_WARNING ]]; then
                numero_linea=$(grep -n "$PATRON_WARNING" "$archivo" | grep "$linea" | cut -d: -f1)
                mensaje_warning="$linea"
                
                # Extraer tipo de warning (puedes ajustar esta parte según el formato del warning)
                tipo_warning=$(echo "$linea" | awk '{print $1}')

                # Contar este tipo de warning
                ((WARNINGS_TOTALES["$tipo_warning"]++))

                # Agregar fila a la tabla
                echo "<tr><td>$numero_linea</td><td>$mensaje_warning</td></tr>" >> "$SALIDA_HTML"
            fi
        done < "$archivo"

        echo "</table>" >> "$SALIDA_HTML"
    fi
done

# Completar la tabla con el total de cada tipo de warning
for tipo in "${!WARNINGS_TOTALES[@]}"; do
    echo "<tr><td>$tipo</td><td>${WARNINGS_TOTALES[$tipo]}</td></tr>" >> "$SALIDA_HTML"
done

echo "</table>" >> "$SALIDA_HTML"

# Cierre del HTML
echo "</body></html>" >> "$SALIDA_HTML"

echo "Reporte generado: $SALIDA_HTML"
